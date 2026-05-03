# Bambu Duck relay — multi-tenant FastAPI server.
# Runs on Fly.io (or any container host). Persistent state lives at
# /data/ducks.db on a Fly volume (mounted via fly.toml). Container
# itself is stateless — restart-safe.

FROM python:3.13-slim

# Install only what we need at runtime. python-dotenv is on the
# requirements list but unused in container deploys (Fly secrets do the
# job); harmless to leave installed.
WORKDIR /app

# Layer cache — copy requirements first so the deps install survives
# any subsequent app-only edits.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App code
COPY *.py ./

# DB lives on a Fly volume. The path is parameterized so it works
# locally too (override DUCKS_DB_PATH if you want a different path).
ENV DUCKS_DB_PATH=/data/ducks.db

# Make sure /data exists at image build time so the first boot before
# the volume mounts doesn't fail. fly.toml mounts a real volume on top
# of this directory at runtime.
RUN mkdir -p /data

EXPOSE 8088

# uvicorn directly — gunicorn would add another layer for nothing at
# this scale. --proxy-headers because Fly's edge terminates TLS and
# forwards plain HTTP with X-Forwarded-* headers.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8088", \
     "--proxy-headers", "--forwarded-allow-ips", "*", \
     "--log-level", "info"]
