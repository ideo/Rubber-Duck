"""SQLite-backed multi-tenant duck registry.

Single `ducks` table keyed by duck_id (chip MAC, lowercase, no separators).
One row per duck. Holds Bambu cloud creds + ElevenLabs config + cloud
broker host so the relay can stand up a per-duck BambuState on startup.

Why SQLite (vs Postgres / Supabase): for the project's actual scale —
a self-hoster running 1-3 ducks, or our shared relay running 3-4 — a
single file with WAL is plenty. Litestream (or just a nightly tar)
handles backups. If we ever outgrow it the schema is small enough to
move to Postgres in an afternoon. See bambu/docs/MULTI-TENANT-REQ.md.

Concurrency model: one shared connection with a threading.Lock() around
writes. Reads are unsynchronized (SQLite handles MVCC under WAL). The
MQTT thread (paho callback) and FastAPI's event loop both go through
this DAO; the lock + check_same_thread=False is the right shape per
yesterday's decision (see chat).
"""
from __future__ import annotations

import json
import logging
import os
import sqlite3
import threading
import time
from pathlib import Path
from typing import Any

logger = logging.getLogger("db")
logger.setLevel(logging.INFO)
if not logger.handlers:
    _h = logging.StreamHandler()
    _h.setFormatter(logging.Formatter("%(levelname)s:db: %(message)s"))
    logger.addHandler(_h)
    logger.propagate = False


_SCHEMA = """
CREATE TABLE IF NOT EXISTS ducks (
    duck_id           TEXT PRIMARY KEY,
    bambu_user_id     TEXT,
    account_email     TEXT,
    access_token      TEXT,
    refresh_token     TEXT,
    -- Legacy single-printer fields (pre-#41). Kept populated as the
    -- first element of serials/printer_names for back-compat reads
    -- by anything that hasn't been multi-printer-aware'd. New code
    -- reads `serials` (JSON array) directly.
    serial            TEXT,
    printer_name      TEXT,
    -- Multi-printer (#41): JSON arrays of strings, parallel order.
    -- serials[i] corresponds to printer_names[i]. Added in user_version=1.
    serials           TEXT,
    printer_names     TEXT,
    cloud_host        TEXT NOT NULL DEFAULT 'us.mqtt.bambulab.com',
    elevenlabs_key    TEXT,
    elevenlabs_agent  TEXT,
    created_at        INTEGER NOT NULL,
    last_seen_at      INTEGER NOT NULL
);

-- Index for "list by recency" — used by /admin/list_ducks and the
-- "default duck" resolver (oldest is the singleton's heir).
CREATE INDEX IF NOT EXISTS ducks_created_at ON ducks(created_at);
"""


class Database:
    """Wraps a sqlite3 connection with a write-lock and the duck DAO.

    One instance per process, created in main.py's lifespan startup.
    Connection uses check_same_thread=False because paho-mqtt callbacks
    fire on a non-asyncio thread and will eventually call back here for
    last_seen_at updates and (later) auth_failed flag persistence.
    """

    def __init__(self, path: str | os.PathLike) -> None:
        self.path = Path(path)
        # WAL mode + check_same_thread=False so the MQTT thread and the
        # asyncio loop can both call DAO methods. Writes are serialized
        # via self._wlock; reads are SQLite-MVCC-safe.
        self._conn = sqlite3.connect(
            self.path, check_same_thread=False, isolation_level=None,
        )
        self._conn.row_factory = sqlite3.Row
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._conn.execute("PRAGMA synchronous=NORMAL")
        self._conn.execute("PRAGMA foreign_keys=ON")
        self._wlock = threading.Lock()
        self._init_schema()

    def _init_schema(self) -> None:
        with self._wlock:
            self._conn.executescript(_SCHEMA)
            self._migrate_to_v1_multiprinter()
        logger.info("db open at %s (sqlite WAL)", self.path)

    def _migrate_to_v1_multiprinter(self) -> None:
        """v1: multi-printer support (#41). Adds `serials` and
        `printer_names` JSON-array columns. Backfills from the legacy
        `serial`/`printer_name` single-value columns so existing rows
        seamlessly become one-element-array rows. Idempotent — uses
        PRAGMA user_version as the version cursor.

        Held under self._wlock by the caller.
        """
        cur = self._conn.execute("PRAGMA user_version")
        version = cur.fetchone()[0]
        if version >= 1:
            return

        # The columns are already declared in _SCHEMA above (which
        # uses CREATE TABLE IF NOT EXISTS — safe to run repeatedly).
        # For DBs that pre-date this change the columns won't exist,
        # so add them defensively.
        existing_cols = {row[1] for row in self._conn.execute(
            "PRAGMA table_info(ducks)").fetchall()}
        if "serials" not in existing_cols:
            self._conn.execute("ALTER TABLE ducks ADD COLUMN serials TEXT")
        if "printer_names" not in existing_cols:
            self._conn.execute(
                "ALTER TABLE ducks ADD COLUMN printer_names TEXT")

        # Backfill rows that have legacy serial/printer_name but no
        # serials JSON. One-element arrays preserving the old binding.
        cur = self._conn.execute(
            "SELECT duck_id, serial, printer_name FROM ducks "
            "WHERE serial IS NOT NULL AND serials IS NULL"
        )
        for duck_id, serial, printer_name in cur.fetchall():
            self._conn.execute(
                "UPDATE ducks SET serials = ?, printer_names = ? "
                "WHERE duck_id = ?",
                (json.dumps([serial]),
                 json.dumps([printer_name or ""]),
                 duck_id),
            )

        self._conn.execute("PRAGMA user_version = 1")
        logger.info("db migrated to v1 (multi-printer #41)")

    # ---- duck CRUD -------------------------------------------------------

    def upsert_duck(self, duck_id: str, **fields: Any) -> None:
        """Insert or update a duck row. Only non-None fields in `fields` are
        written; existing values are preserved otherwise. created_at is set
        on first insert; last_seen_at is bumped on every call.

        Allowed fields match the schema: bambu_user_id, account_email,
        access_token, refresh_token, serial, printer_name, serials (list),
        printer_names (list), cloud_host, elevenlabs_key, elevenlabs_agent.

        `serials` and `printer_names` accept Python lists and get
        JSON-serialized. Pass them as the canonical multi-printer
        binding; the singular `serial`/`printer_name` legacy fields
        get auto-populated from list[0] for back-compat readers.

        Unknown fields raise KeyError so typos surface immediately
        (we'd rather a stack trace than silently dropped writes).
        """
        allowed = {
            "bambu_user_id", "account_email", "access_token", "refresh_token",
            "serial", "printer_name", "serials", "printer_names",
            "cloud_host", "elevenlabs_key", "elevenlabs_agent",
        }
        unknown = set(fields) - allowed
        if unknown:
            raise KeyError(f"unknown duck fields: {sorted(unknown)}")
        # Drop None values so partial updates don't NULL out other columns.
        fields = {k: v for k, v in fields.items() if v is not None}

        # Auto-derive legacy singular fields from the array if the
        # caller passed serials/printer_names. Means callers can
        # always write the multi-printer shape and forget about the
        # legacy columns; old code that reads `serial` keeps working.
        if isinstance(fields.get("serials"), list):
            if fields["serials"] and "serial" not in fields:
                fields["serial"] = fields["serials"][0]
            fields["serials"] = json.dumps(fields["serials"])
        if isinstance(fields.get("printer_names"), list):
            if fields["printer_names"] and "printer_name" not in fields:
                fields["printer_name"] = fields["printer_names"][0]
            fields["printer_names"] = json.dumps(fields["printer_names"])

        now = int(time.time())
        with self._wlock:
            cur = self._conn.execute(
                "SELECT duck_id FROM ducks WHERE duck_id = ?", (duck_id,)
            )
            row = cur.fetchone()
            if row is None:
                # Fresh insert: created_at = last_seen_at = now.
                cols = ["duck_id", "created_at", "last_seen_at"] + list(fields)
                vals = [duck_id, now, now] + [fields[k] for k in fields]
                placeholders = ",".join("?" * len(cols))
                self._conn.execute(
                    f"INSERT INTO ducks ({','.join(cols)}) VALUES ({placeholders})",
                    vals,
                )
                logger.info("duck inserted: %s (%s)", duck_id,
                            fields.get("printer_name") or fields.get("account_email") or "")
            else:
                # Update path: only set non-None fields, bump last_seen_at.
                set_parts = ["last_seen_at = ?"]
                vals: list[Any] = [now]
                for k, v in fields.items():
                    set_parts.append(f"{k} = ?")
                    vals.append(v)
                vals.append(duck_id)
                self._conn.execute(
                    f"UPDATE ducks SET {','.join(set_parts)} WHERE duck_id = ?",
                    vals,
                )

    def touch_duck(self, duck_id: str) -> None:
        """Bump last_seen_at without modifying any other field. Cheap call
        from anywhere we observe the duck doing something (WS handshake,
        MQTT message arrival)."""
        now = int(time.time())
        with self._wlock:
            self._conn.execute(
                "UPDATE ducks SET last_seen_at = ? WHERE duck_id = ?",
                (now, duck_id),
            )

    def get_duck(self, duck_id: str) -> dict | None:
        cur = self._conn.execute(
            "SELECT * FROM ducks WHERE duck_id = ?", (duck_id,)
        )
        row = cur.fetchone()
        return dict(row) if row else None

    def list_ducks(self) -> list[dict]:
        cur = self._conn.execute(
            "SELECT * FROM ducks ORDER BY created_at ASC"
        )
        return [dict(r) for r in cur.fetchall()]

    def default_duck_id(self) -> str | None:
        """Used by the un-scoped compat shim. Returns the oldest duck's id
        if exactly one duck exists (the migration heir of tokens.json), or
        the oldest duck if multiple exist and no caller specified an id.
        Returns None if the DB is empty."""
        cur = self._conn.execute(
            "SELECT duck_id FROM ducks ORDER BY created_at ASC LIMIT 1"
        )
        row = cur.fetchone()
        return row["duck_id"] if row else None

    def delete_duck(self, duck_id: str) -> bool:
        with self._wlock:
            cur = self._conn.execute(
                "DELETE FROM ducks WHERE duck_id = ?", (duck_id,)
            )
        return cur.rowcount > 0

    def rename_duck(self, old_id: str, new_id: str) -> bool:
        """Change the primary key of an existing row. Used by the
        legacy-adoption flow: tokens.json migration creates a row keyed
        "legacy" because we don't know the chip's MAC at migration time;
        the first chip to announce itself with a real MAC takes over
        that row instead of creating a duplicate orphan.

        Returns True if the rename happened, False if the source row
        didn't exist or the destination id was already taken (in which
        case caller should fall back to "treat as a separate duck")."""
        with self._wlock:
            # Don't clobber an existing destination — that'd be data loss.
            cur = self._conn.execute(
                "SELECT 1 FROM ducks WHERE duck_id = ?", (new_id,)
            )
            if cur.fetchone() is not None:
                return False
            cur = self._conn.execute(
                "UPDATE ducks SET duck_id = ? WHERE duck_id = ?",
                (new_id, old_id),
            )
        renamed = cur.rowcount > 0
        if renamed:
            logger.info("renamed duck_id %s → %s", old_id, new_id)
        return renamed

    # ---- migration -------------------------------------------------------

    def migrate_from_tokens_json(
        self, tokens_path: Path, default_duck_id: str
    ) -> bool:
        """One-shot migration from the legacy tokens.json. Idempotent —
        if the DB already has any rows we skip; if tokens.json doesn't
        exist we skip; otherwise we insert one row keyed by
        `default_duck_id` (caller picks — usually env var DUCK_ID or the
        chip MAC printed in support docs).

        Returns True if a migration happened, False if it was a no-op.

        SAFETY PROMISE: this never touches tokens.json on disk. The
        cleanup decision is manual, after the operator verifies the new
        code path works. See docs/MULTI-TENANT-REQ.md.
        """
        # Skip if any duck already exists in the DB. Multiple-call-safe.
        if self.list_ducks():
            return False
        if not tokens_path.exists():
            return False
        try:
            tokens = json.loads(tokens_path.read_text())
        except Exception as e:
            logger.warning("tokens.json unreadable, skipping migration: %s", e)
            return False

        # Cloud-host pulls from env so a pre-existing operator override
        # (BAMBU_CLOUD_HOST) gets carried into the DB row instead of
        # falling back to us-mqtt.
        cloud_host = os.environ.get("BAMBU_CLOUD_HOST", "us.mqtt.bambulab.com")

        # ElevenLabs creds are still env-only in the legacy single-tenant
        # setup. Pull them across so the row is fully self-describing
        # going forward — env vars become a fallback only.
        eleven_key = os.environ.get("ELEVENLABS_API_KEY")
        eleven_agent = os.environ.get("BAMBU_DUCK_AGENT_ID")

        self.upsert_duck(
            default_duck_id,
            bambu_user_id=tokens.get("user_id"),
            account_email=tokens.get("account_email"),
            access_token=tokens.get("access_token"),
            refresh_token=tokens.get("refresh_token"),
            serial=tokens.get("serial"),
            printer_name=tokens.get("printer_name"),
            cloud_host=cloud_host,
            elevenlabs_key=eleven_key,
            elevenlabs_agent=eleven_agent,
        )
        logger.info(
            "migrated tokens.json into DB as duck_id=%s "
            "(printer=%r, account=%s); tokens.json left in place for safety",
            default_duck_id,
            tokens.get("printer_name") or "(unknown)",
            tokens.get("account_email") or "(unknown)",
        )
        return True

    def close(self) -> None:
        with self._wlock:
            self._conn.close()


# Module-level handle, set by main.py's lifespan startup.
_db: Database | None = None


def init(path: str | os.PathLike) -> Database:
    """Create the singleton Database instance. main.py calls this once."""
    global _db
    if _db is not None:
        return _db
    _db = Database(path)
    return _db


def get() -> Database:
    """Fetch the singleton. Raises if init() wasn't called first."""
    if _db is None:
        raise RuntimeError("db.init() must be called before db.get()")
    return _db
