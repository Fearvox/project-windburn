#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${WINDBURN_FUSION_CHAT_PORT:-5178}"
HOST="${WINDBURN_FUSION_CHAT_HOST:-127.0.0.1}"

cd "$ROOT"

echo "fusion_chat_url=http://$HOST:$PORT"
echo "serving=apps/fusion-chat-terminal"
echo "mode=read-only-bridge"
echo "mutation_bridge_enabled=false"

exec node apps/fusion-chat-terminal/bridge.mjs
