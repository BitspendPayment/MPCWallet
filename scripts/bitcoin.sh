#!/usr/bin/env bash
#
# Bitcoin regtest helper script for MPC Wallet development.
# Uses docker exec to call bitcoin-cli inside the mpc_bitcoind container.
#
# Usage:
#   ./scripts/bitcoin.sh init              # Mine 150 blocks to initialize
#   ./scripts/bitcoin.sh send <address> <amount_btc>
#   ./scripts/bitcoin.sh balance
#   ./scripts/bitcoin.sh mine [count]      # Default: 1 block
#   ./scripts/bitcoin.sh newaddr
#   ./scripts/bitcoin.sh txinfo <txid>
#   ./scripts/bitcoin.sh mempool
#   ./scripts/bitcoin.sh utxos <address>
#   ./scripts/bitcoin.sh address <address>

set -euo pipefail

CONTAINER="mpc_bitcoind"
RPC_USER="admin1"
RPC_PASS="123"

bcli_no_wallet() {
  docker exec "$CONTAINER" bitcoin-cli -regtest -rpcuser="$RPC_USER" -rpcpassword="$RPC_PASS" "$@"
}

bcli() {
  docker exec "$CONTAINER" bitcoin-cli -regtest -rpcuser="$RPC_USER" -rpcpassword="$RPC_PASS" -rpcwallet="default" "$@"
}

cmd_init() {
  echo "Initializing regtest chain..."

  # Create default wallet if it doesn't exist, or load it if it does
  if ! bcli_no_wallet listwallets 2>/dev/null | grep -q '"default"'; then
    echo "Creating 'default' wallet..."
    bcli_no_wallet createwallet "default" > /dev/null 2>&1 || bcli_no_wallet loadwallet "default" > /dev/null 2>&1 || true
  fi

  local addr
  addr=$(bcli getnewaddress "" bech32m)
  echo "Mining 150 blocks to $addr..."
  bcli generatetoaddress 150 "$addr" > /dev/null
  echo "Done. Chain height: $(bcli getblockcount)"
  echo "Wallet balance: $(bcli getbalance) BTC"
}

cmd_send() {
  local address="${1:?Usage: bitcoin.sh send <address> <amount_btc>}"
  local amount="${2:?Usage: bitcoin.sh send <address> <amount_btc>}"

  echo "Sending $amount BTC to $address..."
  local txid
  txid=$(bcli sendtoaddress "$address" "$amount")
  echo "TX: $txid"

  # Mine 1 block to confirm
  local miner_addr
  miner_addr=$(bcli getnewaddress "" bech32m)
  bcli generatetoaddress 1 "$miner_addr" > /dev/null
  echo "Confirmed (1 block mined)"
}

cmd_balance() {
  echo "Wallet balance: $(bcli getbalance) BTC"
}

cmd_mine() {
  local count="${1:-1}"
  local addr
  addr=$(bcli getnewaddress "" bech32m)
  echo "Mining $count block(s)..."
  bcli generatetoaddress "$count" "$addr" > /dev/null
  echo "Done. Chain height: $(bcli getblockcount)"
}

cmd_newaddr() {
  bcli getnewaddress "" bech32m
}

cmd_address() {
  local address="${1:?Usage: bitcoin.sh address <address>}"
  echo "Address: $address"
  echo ""
  echo "--- UTXO Scan ---"
  bcli scantxoutset start "[{\"desc\": \"addr($address)\"}]"
  echo ""
  echo "--- Received Transactions ---"
  bcli listreceivedbyaddress 0 true false "$address" 2>/dev/null || echo "(address not in wallet)"
}

cmd_txinfo() {
  local txid="${1:?Usage: bitcoin.sh txinfo <txid>}"
  bcli getrawtransaction "$txid" true
}

cmd_mempool() {
  echo "Mempool contents:"
  bcli getrawmempool
}

cmd_utxos() {
  local address="${1:?Usage: bitcoin.sh utxos <address>}"
  bcli scantxoutset start "[{\"desc\": \"addr($address)\"}]"
}

cmd_help() {
  echo "Bitcoin regtest helper for MPC Wallet"
  echo ""
  echo "Commands:"
  echo "  init                        Mine 150 blocks to initialize the chain"
  echo "  send <address> <amount>     Send BTC and auto-confirm with 1 block"
  echo "  balance                     Show wallet balance"
  echo "  mine [count]                Mine blocks (default: 1)"
  echo "  newaddr                     Generate a new bech32m address"
  echo "  txinfo <txid>               Show transaction details"
  echo "  mempool                     Show mempool contents"
  echo "  utxos <address>             Scan UTXO set for an address"
  echo "  address <address>           Show UTXOs and received txs for an address"
}

case "${1:-help}" in
  init)    cmd_init ;;
  send)    cmd_send "${2:-}" "${3:-}" ;;
  balance) cmd_balance ;;
  mine)    cmd_mine "${2:-}" ;;
  newaddr) cmd_newaddr ;;
  txinfo)  cmd_txinfo "${2:-}" ;;
  mempool) cmd_mempool ;;
  utxos)   cmd_utxos "${2:-}" ;;
  address) cmd_address "${2:-}" ;;
  help|*)  cmd_help ;;
esac
