#!/bin/sh
# Container entrypoint. If Litestream is configured (LITESTREAM_BUCKET
# set), run uvicorn under `litestream replicate -exec` so the SQLite
# WAL streams to S3-compatible storage in the background and any
# pre-existing replica is restored on cold start. Otherwise just
# exec uvicorn directly.

set -e

if [ -n "$LITESTREAM_BUCKET" ]; then
    echo "[entrypoint] Litestream enabled — bucket=$LITESTREAM_BUCKET"
    # Restore from S3 if the DB doesn't exist yet (first boot of a
    # replacement machine, or empty volume after a Fly volume reset).
    # No-op if the local DB is already current. Litestream's restore
    # is idempotent + safe to run on every boot.
    litestream restore -if-replica-exists -if-db-not-exists \
        -config /app/litestream.yml /data/ducks.db || true
    # Replicate exec'd command — Litestream supervises uvicorn and
    # streams WAL changes as they land.
    exec litestream replicate -config /app/litestream.yml -exec \
        "uvicorn main:app --host 0.0.0.0 --port 8088 \
         --proxy-headers --forwarded-allow-ips * --log-level info"
else
    echo "[entrypoint] Litestream NOT configured — running uvicorn directly"
    exec uvicorn main:app --host 0.0.0.0 --port 8088 \
        --proxy-headers --forwarded-allow-ips '*' --log-level info
fi
