#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

node --check packages/fusion-bridge-api/src/redaction.mjs
node --check packages/fusion-bridge-api/src/superruntime.mjs
node --check packages/fusion-bridge-api/src/openapi.mjs
node --check packages/fusion-bridge-api/src/api.mjs
node --check packages/fusion-bridge-api/src/node-server.mjs
node --check packages/fusion-bridge-api/worker.mjs
node --check packages/fusion-bridge-api/bin/windburn-fusion-bridge-api.mjs
node packages/fusion-bridge-api/test/smoke.mjs
