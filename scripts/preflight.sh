#!/usr/bin/env sh
set -eu

cargo run -p runtimectl -- preflight \
  --target . \
  --evidence-dir docs/remote-workhorse/preflight/evidence/current \
  --report docs/remote-workhorse/preflight/REMOTE_NIXOS_PREFLIGHT.md

