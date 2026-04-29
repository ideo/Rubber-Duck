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
        host=os.environ["BAMBU_HOST"],
        access_code=os.environ["BAMBU_ACCESS_CODE"],
        serial=os.environ["BAMBU_SERIAL"],
    )
    state.start()
    yield
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
