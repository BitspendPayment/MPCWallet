#!/usr/bin/env bash
#
# Set up "Bob" — an external `ark-client-sample` wallet (from ~/rust-sdk) used
# as the counter-party in the Flutter integration test. Run after
# `make software-ark` (or equivalent) has brought up arkd + electrs/Esplora +
# bitcoind.
#
#   1. Builds ark-client-sample if needed.
#   2. Generates Bob's seed + ark.config.toml in BOB_DIR (default /tmp/bob_ark).
#   3. Funds Bob's boarding address with 0.005 BTC + mines confirmations.
#   4. Runs `ark-client-sample settle` to convert the boarding output → VTXO.
#   5. Writes Bob's ark address to $BOB_DIR/address.txt.
#
# Idempotent — re-running with an existing BOB_DIR skips seed/config creation.
# We use ark-client-sample (rust-sdk) instead of ark-sample (ark-rs) because
# the latter's proto schema doesn't match the arkd image we're running.

set -euo pipefail

# Default to the vendored submodule; override RUST_SDK_DIR to use a local checkout.
_REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "$0")/..")"
RUST_SDK_DIR="${RUST_SDK_DIR:-$_REPO_ROOT/third_party/rust-sdk}"
BOB_DIR="${BOB_DIR:-/tmp/bob_ark}"
ARK_SERVER_URL="${ARK_SERVER_URL:-http://127.0.0.1:7070}"
ESPLORA_URL="${ESPLORA_URL:-http://127.0.0.1:30000}"
FUND_BTC="${FUND_BTC:-0.005}"
CONFIRMATIONS="${CONFIRMATIONS:-6}"

if [ ! -d "$RUST_SDK_DIR/ark-client-sample" ]; then
  echo "ERROR: ark-client-sample not found at $RUST_SDK_DIR/ark-client-sample. Set RUST_SDK_DIR." >&2
  exit 1
fi

ARK_BIN="$RUST_SDK_DIR/target/release/ark-client-sample"

echo "==> Building ark-client-sample (if needed)..."
if [ ! -x "$ARK_BIN" ] || [ "$RUST_SDK_DIR/ark-client-sample/src/main.rs" -nt "$ARK_BIN" ]; then
  (cd "$RUST_SDK_DIR" && cargo build --release --manifest-path ark-client-sample/Cargo.toml)
fi

mkdir -p "$BOB_DIR"

if [ ! -f "$BOB_DIR/ark.seed" ]; then
  echo "==> Generating Bob seed..."
  printf '%s' "$(openssl rand -hex 32)" > "$BOB_DIR/ark.seed"
fi

cat > "$BOB_DIR/ark.config.toml" <<EOF
ark_server_url = "$ARK_SERVER_URL"
esplora_url = "$ESPLORA_URL"
swap_storage_path = "$BOB_DIR/swap_storage.sqlite"
boltz_url = "http://127.0.0.1:9001"
EOF

ASAMPLE() { "$ARK_BIN" --config "$BOB_DIR/ark.config.toml" --seed "$BOB_DIR/ark.seed" "$@"; }

echo "==> Bob's boarding address:"
boarding_addr=$(ASAMPLE boarding-address | jq -r .address)
if [ -z "$boarding_addr" ] || [ "$boarding_addr" = "null" ]; then
  echo "ERROR: failed to get boarding address" >&2
  exit 1
fi
echo "    $boarding_addr"

echo "==> Bob's ark (offchain) address:"
ark_addr=$(ASAMPLE offchain-address | jq -r .address)
if [ -z "$ark_addr" ] || [ "$ark_addr" = "null" ]; then
  echo "ERROR: failed to get ark address" >&2
  exit 1
fi
echo "    $ark_addr"
echo "$ark_addr" > "$BOB_DIR/address.txt"

current_offchain=$(ASAMPLE balance | jq -r '.offchain_confirmed // 0' | sed 's/[^0-9]//g')
if [ -n "$current_offchain" ] && [ "$current_offchain" -gt 0 ]; then
  echo "==> Bob already has VTXOs (offchain_confirmed=$current_offchain); skipping fund + settle."
  exit 0
fi

echo "==> Ensuring bitcoind 'default' wallet is loaded..."
docker exec mpc_bitcoind bitcoin-cli -regtest -rpcuser=admin1 -rpcpassword=123 \
  loadwallet default >/dev/null 2>&1 || true

echo "==> Funding Bob's boarding output with $FUND_BTC BTC..."
"$(dirname "$0")/bitcoin.sh" send "$boarding_addr" "$FUND_BTC"

echo "==> Mining $CONFIRMATIONS confirmations..."
"$(dirname "$0")/bitcoin.sh" mine "$CONFIRMATIONS"

echo "==> Settling Bob's boarding output into VTXOs (this may take ~30s for the ASP round)..."
ASAMPLE settle

echo "==> Final balance:"
ASAMPLE balance

echo
echo "Bob is ready. Ark address written to $BOB_DIR/address.txt"
