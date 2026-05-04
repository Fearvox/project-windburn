#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUTDIR="${WINDBURN_FUSION_BRIDGE_WORKER_OUTDIR:-/tmp/windburn-fusion-bridge-api-worker}"
rm -rf "$OUTDIR"

npx --yes wrangler@latest deploy packages/fusion-bridge-api/worker.mjs \
  --dry-run \
  --name windburn-fusion-bridge-api \
  --compatibility-date 2026-05-04 \
  --outdir "$OUTDIR"
