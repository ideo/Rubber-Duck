"""
Shared config loader for the Rubber Duck eval service.
Reads runtime values from ~/.duck/config (written by the widget on launch).
Environment variables override the config file, matching DuckConfig.swift behavior.
Falls back to hardcoded defaults if neither exists.
"""

import os
import pathlib

_CONFIG_PATH = pathlib.Path.home() / ".duck" / "config"
_cache = None


def _load():
    global _cache
    if _cache is not None:
        return _cache
    cfg = {}
    if _CONFIG_PATH.exists():
        for line in _CONFIG_PATH.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, _, v = line.partition("=")
                cfg[k.strip()] = v.strip()
    _cache = cfg
    return cfg


def get(key, default=None):
    """Get a config value. Env vars take priority over the file."""
    env_val = os.environ.get(key)
    if env_val:
        return env_val
    return _load().get(key, default)


# Convenience accessors
port = int(get("DUCK_SERVICE_PORT", "3333"))
service_url = get("DUCK_SERVICE_URL", f"http://localhost:{port}")
tmux_session = get("DUCK_TMUX_SESSION", "duck")
tmux_window = get("DUCK_TMUX_WINDOW", "claude")
pid_file = pathlib.Path(get("DUCK_PID_FILE", str(pathlib.Path(__file__).parent / ".pid")))
voice = get("DUCK_VOICE", "Boing")
