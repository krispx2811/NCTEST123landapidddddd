#!/usr/bin/env bash
set -euo pipefail

# 1) Prerequisites
for cmd in git make cargo; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is not installed. Please install it first." >&2
    exit 1
  fi
done

# 2) Ensure 'choo' (Hoon compiler) is installed
if ! command -v choo &>/dev/null; then
  echo "🔧 'choo' not found — installing from zorp-corp/nockapp..."
  TMPDIR=$(mktemp -d)
  git clone https://github.com/zorp-corp/nockapp.git "$TMPDIR"
  if [ -d "$TMPDIR/apps/choo" ]; then
    pushd "$TMPDIR/apps/choo" >/dev/null
      cargo build --release
      sudo install -m 755 target/release/choo /usr/local/bin/choo
    popd >/dev/null
    rm -rf "$TMPDIR"
    echo "✅ choo installed to /usr/local/bin/choo"
  else
    echo "Error: 'apps/choo' not found in nockapp repo." >&2
    exit 1
  fi
fi

# 3) Ask for your mining pubkey (or use default)
DEFAULT_PUBKEY="EHmKL2U3vXfS5GYAY5aVnGdukfDWwvkQPCZXnjvZVShsSQi3UAuA4tQQpVwGJMzc9FfpTY8pLDkqhBGfWutiF4prrCktUH9oAWJxkXQBzAavKDc95NR3DjmYwnnw8GuugnK"
read -rp "Enter your mining pubkey (leave blank for default): " MINING_PUBKEY
MINING_PUBKEY="${MINING_PUBKEY:-$DEFAULT_PUBKEY}"

# 4) Ask for UDP ports
read -rp "Enter leader UDP port to peer to [3005]: " LEADER_PORT
LEADER_PORT="${LEADER_PORT:-3005}"
read -rp "Enter follower UDP port [3006]: " FOLLOWER_PORT
FOLLOWER_PORT="${FOLLOWER_PORT:-3006}"

# 5) Clone or update Nockchain
if [ -d nockchain ]; then
  echo "🔄 Updating existing nockchain repo..."
  git -C nockchain pull
else
  echo "🌱 Cloning nockchain repo..."
  git clone https://github.com/zorp-corp/nockchain.git
fi

# 6) Build Nockchain (runs build-trivial-new, etc.)
echo "🛠️  Building nockchain…"
pushd nockchain >/dev/null
  make build-hoon-all
  make build
popd >/dev/null

# 7) Start follower node
echo "🚀 Launching follower on UDP port ${FOLLOWER_PORT}, peering to leader:${LEADER_PORT}…"
cd nockchain
RUST_BACKTRACE=1 cargo run --release --bin nockchain -- \
  --fakenet \
  --genesis-watcher \
  --npc-socket nockchain.sock \
  --mining-pubkey "${MINING_PUBKEY}" \
  --bind "/ip4/0.0.0.0/udp/${FOLLOWER_PORT}/quic-v1" \
  --peer "/ip4/127.0.0.1/udp/${LEADER_PORT}/quic-v1" \
  --new-peer-id \
  --no-default-peers
