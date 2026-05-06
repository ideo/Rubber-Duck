# Bambu Duck relay — multi-tenant FastAPI server.
# Runs on Fly.io (or any container host). Persistent state lives at
# /data/ducks.db on a Fly volume (mounted via fly.toml). Container
# itself is stateless — restart-safe.

FROM python:3.13-slim

WORKDIR /app

# Install Litestream (continuous SQLite replication to S3). Tiny static
# Go binary (~12MB). The entrypoint only invokes it when
# LITESTREAM_BUCKET is set, so an unconfigured deploy pays only the
# image-size cost. Pinned to a known-good release; bump deliberately.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates wget \
    && ARCH=$(dpkg --print-architecture) \
    && wget -q "https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-linux-${ARCH}.deb" \
        -O /tmp/litestream.deb \
    && dpkg -i /tmp/litestream.deb \
    && rm /tmp/litestream.deb \
    && apt-get purge -y wget \
    && rm -rf /var/lib/apt/lists/*

# Layer cache — copy requirements first so the deps install survives
# any subsequent app-only edits.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App code + entrypoint + litestream config
COPY *.py ./
COPY entrypoint.sh litestream.yml ./
RUN chmod +x entrypoint.sh

# DB lives on a Fly volume. Path is parameterized so it works locally
# too (override DUCKS_DB_PATH if you want a different path).
ENV DUCKS_DB_PATH=/data/ducks.db

# Make sure /data exists at image build time so the first boot before
# the volume mounts doesn't fail. fly.toml mounts a real volume on top
# of this directory at runtime.
RUN mkdir -p /data

EXPOSE 8088

# Entrypoint inspects LITESTREAM_BUCKET; runs uvicorn under litestream
# if set, else uvicorn directly. See entrypoint.sh for the conditional.
CMD ["/app/entrypoint.sh"]
