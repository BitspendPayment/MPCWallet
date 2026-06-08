#!/usr/bin/env python3
"""
Minimal content-addressed store standing in for a Warg registry's content API.

The cosigner's lean `WargRegistry` fetches a contract component straight from the
registry's content endpoint by digest and re-hashes to verify, deliberately
skipping Warg's transparency-log/provenance checks (see
cosigner-runtime/src/contract/registry.rs). This server speaks exactly that
content slice — nothing more — so the e2e never needs a full warg-server.

Endpoints (in-memory, no auth):
  PUT /content            body = component bytes
                          -> 201 {"digest": "sha256:<hex>"}  (stored under its own sha256)
  GET /content/sha256:<hex>
                          -> 200 octet-stream (the stored bytes) | 404
  GET /health             -> 200 {"ok": true}

No third-party deps, so `python:3.12-slim` runs it as-is.
"""

import hashlib
import json
import os
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("WARG_PORT", "7079"))

# digest hex (lowercase) -> component bytes
_STORE: dict[str, bytes] = {}

_CONTENT_RE = re.compile(r"^/content/sha256:([0-9a-fA-F]{64})$")


class Handler(BaseHTTPRequestHandler):
    # Quieter logs; still surface each request line.
    def log_message(self, fmt, *args):
        print("warg %s - %s" % (self.address_string(), fmt % args), flush=True)

    def _send(self, code, body=b"", content_type="application/octet-stream"):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj).encode(), "application/json")

    def do_PUT(self):
        if self.path != "/content":
            self._json(404, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        data = self.rfile.read(length) if length else b""
        digest = hashlib.sha256(data).hexdigest()
        _STORE[digest] = data
        self._json(201, {"digest": "sha256:%s" % digest, "size": len(data)})

    def do_GET(self):
        if self.path == "/health":
            self._json(200, {"ok": True, "items": len(_STORE)})
            return
        m = _CONTENT_RE.match(self.path)
        if not m:
            self._json(404, {"error": "not found"})
            return
        data = _STORE.get(m.group(1).lower())
        if data is None:
            self._json(404, {"error": "unknown digest"})
            return
        self._send(200, data)


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print("warg content server listening on 0.0.0.0:%d" % PORT, flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
