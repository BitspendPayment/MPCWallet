#!/usr/bin/env python3
"""Smoke test for HW Signer firmware over USB HID.

Sends JSON commands using the same chunking protocol as the Flutter app.
Requires: pip install hidapi

Usage:
    python scripts/test_hwsigner.py              # just get_info
    python scripts/test_hwsigner.py --full-dkg   # run full DKG + sign with signer-server as 2nd participant
"""

import argparse
import json
import os
import signal
import socket
import struct
import subprocess
import sys
import time

try:
    import hid
except ImportError:
    print("Install hidapi: pip install hidapi")
    sys.exit(1)

VID = 0x1209
PID = 0x0001
REPORT_SIZE = 64
CHANNEL = bytes([0x01, 0x01])
CMD_MSG = 0x05
FIRST_PAYLOAD = 57  # 64 - 5 header - 2 length
CONT_PAYLOAD = 59   # 64 - 5 header

# Path to signer-server binary
SIGNER_SERVER = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "e2e", "signer-server", "target", "release", "signer-server"
)

# ---------------------------------------------------------------------------
# HID chunking (same protocol as Flutter app)
# ---------------------------------------------------------------------------

def chunk_message(data: bytes) -> list[bytes]:
    """Split a message into 64-byte HID reports."""
    reports = []
    offset = 0
    seq = 0

    # First report: header + total length + payload
    report = bytearray(REPORT_SIZE)
    report[0:2] = CHANNEL
    report[2] = CMD_MSG
    struct.pack_into(">H", report, 3, seq)
    struct.pack_into(">H", report, 5, len(data))
    chunk = min(len(data), FIRST_PAYLOAD)
    report[7:7 + chunk] = data[offset:offset + chunk]
    offset += chunk
    reports.append(bytes(report))
    seq += 1

    # Continuation reports
    while offset < len(data):
        report = bytearray(REPORT_SIZE)
        report[0:2] = CHANNEL
        report[2] = CMD_MSG
        struct.pack_into(">H", report, 3, seq)
        chunk = min(len(data) - offset, CONT_PAYLOAD)
        report[5:5 + chunk] = data[offset:offset + chunk]
        offset += chunk
        reports.append(bytes(report))
        seq += 1

    return reports


def reassemble(device) -> bytes:
    """Read HID reports and reassemble into a complete message."""
    buf = bytearray()
    expected_len = 0
    next_seq = 0

    while True:
        report = device.read(REPORT_SIZE, timeout_ms=30000)
        if not report:
            raise TimeoutError("No response from device (30s timeout)")

        report = bytes(report)
        if len(report) < REPORT_SIZE:
            report = report + b'\x00' * (REPORT_SIZE - len(report))

        seq = struct.unpack_from(">H", report, 3)[0]

        if seq == 0:
            expected_len = struct.unpack_from(">H", report, 5)[0]
            chunk = min(expected_len, FIRST_PAYLOAD)
            buf = bytearray(report[7:7 + chunk])
            next_seq = 1
        else:
            if seq != next_seq:
                raise ValueError(f"Unexpected seq {seq}, expected {next_seq}")
            remaining = expected_len - len(buf)
            chunk = min(remaining, CONT_PAYLOAD)
            buf.extend(report[5:5 + chunk])
            next_seq += 1

        if len(buf) >= expected_len:
            return bytes(buf[:expected_len])


def hid_command(device, cmd: dict) -> dict:
    """Send a JSON command to Pico via HID and return the JSON response."""
    data = json.dumps(cmd).encode()
    reports = chunk_message(data)

    for report in reports:
        device.write(b'\x00' + report)  # prepend report ID 0

    resp_bytes = reassemble(device)
    resp = json.loads(resp_bytes)

    if "error" in resp:
        raise RuntimeError(f"Pico error: {resp['error']}")
    return resp


# ---------------------------------------------------------------------------
# TCP transport (length-prefixed JSON for signer-server)
# ---------------------------------------------------------------------------

class TcpSigner:
    """Communicate with signer-server over TCP (4-byte BE length + JSON)."""

    def __init__(self, host: str, port: int):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(30)
        self.sock.connect((host, port))

    def send_command(self, cmd: dict) -> dict:
        data = json.dumps(cmd).encode()
        self.sock.sendall(struct.pack(">I", len(data)) + data)

        # Read 4-byte length prefix
        len_buf = self._recv_exact(4)
        msg_len = struct.unpack(">I", len_buf)[0]

        # Read JSON payload
        resp_bytes = self._recv_exact(msg_len)
        resp = json.loads(resp_bytes)

        if "error" in resp:
            raise RuntimeError(f"Server error: {resp['error']}")
        return resp

    def _recv_exact(self, n: int) -> bytes:
        buf = bytearray()
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("Server disconnected")
            buf.extend(chunk)
        return bytes(buf)

    def close(self):
        self.sock.close()


# ---------------------------------------------------------------------------
# DKG + Sign test
# ---------------------------------------------------------------------------

def run_full_dkg(device):
    """Run a 2-of-2 DKG between Pico (HID) and signer-server (TCP), then sign."""

    # Find a free port
    with socket.socket() as s:
        s.bind(('', 0))
        port = s.getsockname()[1]

    # Start signer-server subprocess
    if not os.path.exists(SIGNER_SERVER):
        print(f"ERROR: signer-server not found at {SIGNER_SERVER}")
        print("Build it first: cd e2e/signer-server && cargo build --release")
        sys.exit(1)

    print(f"Starting signer-server on port {port}...")
    server_proc = subprocess.Popen(
        [SIGNER_SERVER, "--port", str(port)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    time.sleep(0.5)  # let it start

    if server_proc.poll() is not None:
        print("ERROR: signer-server failed to start")
        sys.exit(1)

    try:
        tcp = TcpSigner("127.0.0.1", port)

        # ---- Round 1: dkg_init on both participants ----
        print("\n[2] DKG Round 1 (dkg_init)")

        print("    Pico: dkg_init(2, 2)...", end=" ", flush=True)
        pico_r1 = hid_command(device, {
            "cmd": "dkg_init",
            "max_signers": 2,
            "min_signers": 2,
        })
        pico_id = pico_r1["identifier_hex"]
        pico_r1_pkg = pico_r1["round1_package_json"]
        print(f"OK (id={pico_id[:16]}...)")

        print("    Server: dkg_init(2, 2)...", end=" ", flush=True)
        server_r1 = tcp.send_command({
            "cmd": "dkg_init",
            "max_signers": 2,
            "min_signers": 2,
        })
        server_id = server_r1["identifier_hex"]
        server_r1_pkg = server_r1["round1_package_json"]
        print(f"OK (id={server_id[:16]}...)")

        # ---- Round 2: exchange round1 packages ----
        print("\n[3] DKG Round 2 (dkg_round2)")

        print("    Pico: dkg_round2 (with server's r1)...", end=" ", flush=True)
        pico_r2 = hid_command(device, {
            "cmd": "dkg_round2",
            "round1_packages": {server_id: server_r1_pkg},
        })
        pico_r2_pkgs = pico_r2["round2_packages"]
        print("OK")

        print("    Server: dkg_round2 (with pico's r1)...", end=" ", flush=True)
        server_r2 = tcp.send_command({
            "cmd": "dkg_round2",
            "round1_packages": {pico_id: pico_r1_pkg},
        })
        server_r2_pkgs = server_r2["round2_packages"]
        print("OK")

        # ---- Round 3: exchange round2 packages and finalize ----
        # round2 output is keyed by RECIPIENT id.
        # round3 expects round2_packages keyed by SENDER id.
        # So we re-key: for Pico's round3, take server's r2[pico_id] and key it as server_id.
        print("\n[4] DKG Round 3 (dkg_round3)")

        print("    Pico: dkg_round3...", end=" ", flush=True)
        pico_r3 = hid_command(device, {
            "cmd": "dkg_round3",
            "round1_packages": {server_id: server_r1_pkg},
            "round2_packages": {server_id: server_r2_pkgs[pico_id]},
        })
        print(f"OK (public_key={pico_r3['public_key_hex'][:16]}...)")

        print("    Server: dkg_round3...", end=" ", flush=True)
        server_r3 = tcp.send_command({
            "cmd": "dkg_round3",
            "round1_packages": {pico_id: pico_r1_pkg},
            "round2_packages": {pico_id: pico_r2_pkgs[server_id]},
        })
        print(f"OK (public_key={server_r3['public_key_hex'][:16]}...)")

        # Verify both got the same public key
        assert pico_r3["public_key_hex"] == server_r3["public_key_hex"], \
            f"Public key mismatch!\n  Pico:   {pico_r3['public_key_hex']}\n  Server: {server_r3['public_key_hex']}"
        print(f"\n    Public keys match: {pico_r3['public_key_hex']}")

        # ---- Verify get_info shows key ----
        print("\n[5] Verify get_info (post-DKG)")
        pico_info = hid_command(device, {"cmd": "get_info"})
        assert pico_info["has_key_package"] is True, "Pico should have key_package after DKG"
        print(f"    Pico: has_key_package={pico_info['has_key_package']}, "
              f"identifier={pico_info['identifier_hex'][:16]}...")

        # ---- Generate nonces ----
        print("\n[6] Generate nonces")

        print("    Pico: generate_nonce...", end=" ", flush=True)
        pico_nonce = hid_command(device, {"cmd": "generate_nonce"})
        print(f"OK (hiding={pico_nonce['hiding_hex'][:16]}...)")

        print("    Server: generate_nonce...", end=" ", flush=True)
        server_nonce = tcp.send_command({"cmd": "generate_nonce"})
        print(f"OK (hiding={server_nonce['hiding_hex'][:16]}...)")

        # ---- Sign a test message ----
        print("\n[7] Sign test message")
        test_message = "deadbeef" * 8  # 32-byte message as hex

        # Build commitments map with both participants
        commitments = {
            pico_id: {
                "hiding": pico_nonce["hiding_hex"],
                "binding": pico_nonce["binding_hex"],
            },
            server_id: {
                "hiding": server_nonce["hiding_hex"],
                "binding": server_nonce["binding_hex"],
            },
        }

        print("    Pico: sign...", end=" ", flush=True)
        pico_sig = hid_command(device, {
            "cmd": "sign",
            "message_hex": test_message,
            "commitments": commitments,
            "apply_tweak": False,
        })
        print(f"OK (share={pico_sig['share_hex'][:16]}...)")

        print("    Server: sign...", end=" ", flush=True)
        server_sig = tcp.send_command({
            "cmd": "sign",
            "message_hex": test_message,
            "commitments": commitments,
            "apply_tweak": False,
        })
        print(f"OK (share={server_sig['share_hex'][:16]}...)")

        print(f"\n    Pico share:   {pico_sig['share_hex']}")
        print(f"    Server share: {server_sig['share_hex']}")

        tcp.close()

    finally:
        server_proc.send_signal(signal.SIGTERM)
        server_proc.wait(timeout=5)
        print("\n    signer-server stopped.")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Test HW Signer firmware")
    parser.add_argument("--full-dkg", action="store_true",
                        help="Run full 2-of-2 DKG + sign with signer-server as 2nd participant")
    args = parser.parse_args()

    print(f"Looking for HW Signer (VID=0x{VID:04x} PID=0x{PID:04x})...")

    device = hid.device()
    try:
        device.open(VID, PID)
    except OSError:
        print("Device not found. Is the Pico connected and firmware flashed?")
        print("\nConnected HID devices:")
        for d in hid.enumerate():
            print(f"  VID=0x{d['vendor_id']:04x} PID=0x{d['product_id']:04x} "
                  f"{d['product_string']} ({d['path'].decode()})")
        sys.exit(1)

    info = device.get_product_string()
    print(f"Connected: {info}\n")

    # Test 1: get_info
    print("[1] get_info")
    resp = hid_command(device, {"cmd": "get_info"})
    print(f"    has_key_package: {resp.get('has_key_package')}")
    print(f"    has_pending_nonce: {resp.get('has_pending_nonce')}")
    print(f"    identifier_hex: {resp.get('identifier_hex')}")

    if args.full_dkg:
        run_full_dkg(device)
    else:
        print()

    print("\nAll tests passed!")
    device.close()


if __name__ == "__main__":
    main()
