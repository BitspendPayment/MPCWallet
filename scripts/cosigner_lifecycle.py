#!/usr/bin/env python3
"""
Tiny HTTP service that owns the cosigner-runtime subprocess for UI
integration tests. Emulator-side tests POST to this helper (via
`adb reverse tcp:7099 tcp:7099`) to start, stop, or restart cosigner
between test phases — useful for verifying persistence rehydration,
delegate-survives-restart, and cold-spawn auto-settle scenarios.

The cosigner's data_dir (sled) is kept across restarts so persisted
state (vtxo_store, ark_tx_history, delegate_sessions, device_tokens)
is preserved. Killing the helper itself doesn't touch the data_dir;
operator can clear it manually if a clean slate is wanted.

Endpoints:
  POST /start    -> {"running": true, "pid": 12345}        idempotent
  POST /kill     -> {"running": false}                     idempotent
  POST /restart  -> {"running": true, "pid": 12346}        kill + start
  GET  /status   -> {"running": bool, "pid": int|null}

Config (env vars, all optional with the defaults used by the Makefile):
  COSIGNER_RUNTIME_BIN  default: ../cosigner-runtime/target/release/cosigner-runtime
  COSIGNER_WASM_PATH    default: ../cosigner/target/wasm32-wasip1/release/cosigner.wasm
  PORT                  default: 7074  (passed to cosigner-runtime --port)
  COSIGNER_DATA_DIR     default: /tmp/cosigner_lifecycle_data
  LIFECYCLE_PORT        default: 7099  (this helper's port)
  ELECTRUM_URL, ELECTRUM_PORT, BITCOIN_RPC_USER, BITCOIN_RPC_PASSWORD,
  ASP_URL, BITCOIN_NETWORK, AUTO_SETTLE_SAFETY_MARGIN_SECS,
  FCM_SERVICE_ACCOUNT_JSON, FCM_BASE_URL  — passed through to the cosigner

Usage from a test:
    POST http://10.0.2.2:7099/restart
    (wait for GET /status to report running:true; ~1-2s)
"""

import json
import os
import signal
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[1]

COSIGNER_BIN = Path(
    os.environ.get(
        "COSIGNER_RUNTIME_BIN",
        str(_REPO_ROOT / "cosigner-runtime" / "target" / "release" / "cosigner-runtime"),
    )
)
WASM_PATH = Path(
    os.environ.get(
        "COSIGNER_WASM_PATH",
        str(_REPO_ROOT / "cosigner" / "target" / "wasm32-wasip1" / "release" / "cosigner.wasm"),
    )
)
COSIGNER_PORT = os.environ.get("PORT", "7074")
DATA_DIR = Path(os.environ.get("COSIGNER_DATA_DIR", "/tmp/cosigner_lifecycle_data"))
LIFECYCLE_PORT = int(os.environ.get("LIFECYCLE_PORT", "7099"))

# Subset of env vars the cosigner-runtime cares about. Read at request time
# (not at module import) so the test can override before each /start by
# setting them in the lifecycle helper's parent shell — useful for swapping
# FCM_BASE_URL between tests.
PASSTHROUGH_ENV_KEYS = [
    "ELECTRUM_URL",
    "ELECTRUM_PORT",
    "BITCOIN_RPC_USER",
    "BITCOIN_RPC_PASSWORD",
    "ASP_URL",
    "BITCOIN_NETWORK",
    "AUTO_SETTLE_SAFETY_MARGIN_SECS",
    "FCM_SERVICE_ACCOUNT_JSON",
    "FCM_BASE_URL",
    "ACTOR_IDLE_THRESHOLD_SECS",
    "DKG_SESSION_TTL_SECS",
]


class CosignerState:
    """Singleton wrapping the subprocess. Not thread-safe by itself; we serialize
    state mutations via a single ThreadingHTTPServer thread per request and a
    Python-level lock."""

    def __init__(self) -> None:
        self.proc: subprocess.Popen | None = None
        import threading
        self._lock = threading.Lock()

    def is_running(self) -> bool:
        return self.proc is not None and self.proc.poll() is None

    def pid(self) -> int | None:
        return self.proc.pid if self.is_running() else None

    def start(self) -> None:
        with self._lock:
            if self.is_running():
                return
            DATA_DIR.mkdir(parents=True, exist_ok=True)
            env = os.environ.copy()
            # HOME drives the cosigner's sled `data_dir` default
            # (`$HOME/.mpc_wallet/server`). Persisting state across restarts
            # means pointing HOME at a known path that survives the helper's
            # subprocess lifecycle.
            env["HOME"] = str(DATA_DIR)
            for k in PASSTHROUGH_ENV_KEYS:
                if k in os.environ:
                    env[k] = os.environ[k]
            cmd = [
                str(COSIGNER_BIN),
                "--wasm",
                str(WASM_PATH),
                "--port",
                COSIGNER_PORT,
            ]
            print(f"[lifecycle] starting: {' '.join(cmd)} (HOME={env['HOME']})")
            self.proc = subprocess.Popen(cmd, env=env)
            # Tiny grace so the next /status call doesn't fire before the
            # process has actually entered its tokio runtime.
            time.sleep(0.5)

    def kill(self) -> None:
        with self._lock:
            if not self.is_running():
                return
            assert self.proc is not None
            print(f"[lifecycle] killing pid={self.proc.pid}")
            self.proc.send_signal(signal.SIGTERM)
            try:
                self.proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                print("[lifecycle] SIGTERM timed out; SIGKILL")
                self.proc.kill()
                self.proc.wait(timeout=5)
            self.proc = None

    def restart(self) -> None:
        self.kill()
        self.start()


_state = CosignerState()


class Handler(BaseHTTPRequestHandler):
    def _json(self, code: int, body: dict) -> None:
        payload = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _status_body(self) -> dict:
        return {"running": _state.is_running(), "pid": _state.pid()}

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/status":
            self._json(200, self._status_body())
            return
        self._json(404, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802
        try:
            if self.path == "/start":
                _state.start()
                self._json(200, self._status_body())
                return
            if self.path == "/kill":
                _state.kill()
                self._json(200, self._status_body())
                return
            if self.path == "/restart":
                _state.restart()
                self._json(200, self._status_body())
                return
            self._json(404, {"error": "not found"})
        except Exception as e:  # noqa: BLE001
            self._json(500, {"error": str(e)})

    def log_message(self, fmt: str, *args) -> None:  # noqa: D401
        # Be a bit chattier than the default — these requests are infrequent
        # and the operator wants to know what's happening.
        print(f"[lifecycle] {self.address_string()} {fmt % args}")


def main() -> None:
    if not COSIGNER_BIN.exists():
        raise SystemExit(
            f"cosigner-runtime binary not found at {COSIGNER_BIN}. "
            f"Run `make runtime-build` (or set COSIGNER_RUNTIME_BIN env var)."
        )
    if not WASM_PATH.exists():
        raise SystemExit(
            f"cosigner WASM not found at {WASM_PATH}. "
            f"Run `make cosigner-build` (or set COSIGNER_WASM_PATH env var)."
        )
    server = ThreadingHTTPServer(("0.0.0.0", LIFECYCLE_PORT), Handler)
    print(
        f"[lifecycle] listening on 0.0.0.0:{LIFECYCLE_PORT} | "
        f"cosigner port={COSIGNER_PORT} data_dir={DATA_DIR}"
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        _state.kill()


if __name__ == "__main__":
    main()
