#!/usr/bin/env sh
set -eu

if [ -f .env.local ]; then
  set -a
  . ./.env.local
  set +a
fi

: "${WINDBURN_REMOTE_HOST:=24.144.113.25}"
export WINDBURN_REMOTE_HOST

cargo run -p runtimectl -- preflight \
  --target . \
  --evidence-dir docs/remote-workhorse/preflight/evidence/current \
  --report docs/remote-workhorse/preflight/REMOTE_NIXOS_PREFLIGHT.md
