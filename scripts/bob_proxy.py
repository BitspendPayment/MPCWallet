#!/usr/bin/env python3
"""
Tiny HTTP shim that proxies the Flutter integration test's requests to Bob's
ark-client-sample CLI. Bob is set up by bob_setup.sh; this server runs on the
host and the emulator reaches it at 10.0.2.2:7090.

Endpoints:
  GET  /ark-address    -> {"address": "tark1..."}
  GET  /balance        -> {"spendable_sats": 12345, ...raw...}
  POST /send           body {"address": "...", "amount_sats": 30000}
                       -> {"ok": true, ...raw_stderr...}
"""

import json
import os
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

RUST_SDK_DIR = Path(os.environ.get("RUST_SDK_DIR", str(Path.home() / "rust-sdk")))
BOB_DIR = Path(os.environ.get("BOB_DIR", "/tmp/bob_ark"))
PORT = int(os.environ.get("BOB_PROXY_PORT", "7090"))

ARK_BIN = RUST_SDK_DIR / "target" / "release" / "ark-client-sample"
SEED = BOB_DIR / "ark.seed"
CONFIG = BOB_DIR / "ark.config.toml"
ADDRESS_FILE = BOB_DIR / "address.txt"


def ark_cli(*args: str) -> subprocess.CompletedProcess:
    cmd = [str(ARK_BIN), "--config", str(CONFIG), "--seed", str(SEED), *args]
    return subprocess.run(cmd, capture_output=True, text=True, check=True, cwd=str(BOB_DIR))


def parse_amount(value) -> int:
    """Coerce ark-client-sample's Amount serialization into integer sats."""
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        m = re.search(r"\d+", value)
        return int(m.group(0)) if m else 0
    if isinstance(value, dict):
        for k in ("sat", "sats", "satoshi", "value"):
            if k in value:
                return parse_amount(value[k])
    return 0


class Handler(BaseHTTPRequestHandler):
    def _json(self, code: int, body: dict) -> None:
        payload = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt: str, *args) -> None:
        return  # quiet

    def do_GET(self) -> None:
        try:
            if self.path == "/ark-address":
                addr = ADDRESS_FILE.read_text().strip()
                return self._json(200, {"address": addr})
            if self.path == "/balance":
                out = ark_cli("balance")
                parsed = json.loads(out.stdout)
                # Treat received-but-pre-confirmed VTXOs as part of the
                # balance — they're delivered to the recipient but won't show
                # under offchain_confirmed until the next ASP settle round.
                confirmed = parse_amount(parsed.get("offchain_confirmed", 0))
                pre = parse_amount(parsed.get("offchain_pre_confirmed", 0))
                return self._json(
                    200,
                    {
                        "spendable_sats": confirmed + pre,
                        "confirmed_sats": confirmed,
                        "pre_confirmed_sats": pre,
                        "raw": parsed,
                    },
                )
            self._json(404, {"error": "not found"})
        except subprocess.CalledProcessError as e:
            self._json(500, {"error": "ark-client-sample failed", "stderr": e.stderr})
        except Exception as e:
            self._json(500, {"error": str(e)})

    def do_POST(self) -> None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(length) or b"{}")
            if self.path == "/send":
                addr = body["address"]
                amount = int(body["amount_sats"])
                out = ark_cli("send-to-ark-addresses", f"{addr},{amount}")
                return self._json(200, {"ok": True, "stderr": out.stderr, "stdout": out.stdout})
            self._json(404, {"error": "not found"})
        except subprocess.CalledProcessError as e:
            self._json(500, {"error": "ark-client-sample failed", "stderr": e.stderr})
        except Exception as e:
            self._json(500, {"error": str(e)})


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"bob_proxy: listening on 0.0.0.0:{PORT}")
    print(f"  ARK_BIN={ARK_BIN}")
    print(f"  BOB_DIR={BOB_DIR}")
    print(f"  Address: {ADDRESS_FILE.read_text().strip() if ADDRESS_FILE.exists() else '(missing)'}")
    server.serve_forever()


if __name__ == "__main__":
    main()
