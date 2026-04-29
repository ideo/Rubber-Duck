"""Convai webhook target. Three GET tools the LLM can call mid-conversation."""
from __future__ import annotations

import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException

from bambu_state import BambuState

load_dotenv()

state: BambuState | None = None


@asynccontextmanager
async def lifespan(_app: FastAPI):
    global state
    state = BambuState(
        host=os.environ.get("BAMBU_HOST", "mock"),
        access_code=os.environ.get("BAMBU_ACCESS_CODE", "mock"),
        serial=os.environ.get("BAMBU_SERIAL", "mock"),
    )
    if os.environ.get("MOCK") == "1":
        # Mock mode: don't connect to a broker, let mock_printer.py drive state via injection.
        from mock_printer import drive_in_thread
        drive_in_thread(state)
    else:
        state.start()
    yield
    if os.environ.get("MOCK") != "1":
        state.stop()


app = FastAPI(lifespan=lifespan)


def _auth(secret: str | None) -> None:
    expected = os.environ.get("RELAY_SHARED_SECRET")
    if expected and secret != expected:
        raise HTTPException(401, "bad shared secret")


@app.get("/health")
def health():
    return {"ok": True, "connected": state is not None and bool(state.snapshot())}


@app.get("/tools/printer_state")
def printer_state(x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return state.snapshot()


@app.get("/tools/temperatures")
def temperatures(x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return state.temperatures()


@app.get("/tools/print_history")
def print_history(n: int = 5, x_relay_secret: str | None = Header(default=None)):
    _auth(x_relay_secret)
    return {"history": state.history(max(1, min(n, 20)))}
