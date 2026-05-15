#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CARD_PATH="${1:-"$ROOT_DIR/docs/remote-workhorse/fixtures/research-run-card-v0.json"}"

"$ROOT_DIR/scripts/research-run-card-verify.sh" "$CARD_PATH"

if [ "$#" -eq 0 ]; then
  for fixture in "$ROOT_DIR"/docs/remote-workhorse/fixtures/research-run-card-m*-p1-public-surface-safety-v0.json; do
    [ -f "$fixture" ] || continue
    "$ROOT_DIR/scripts/research-run-card-verify.sh" "$fixture"
  done
fi

echo "PASS research_appliance_smoke"
echo "card=$CARD_PATH"
echo "remote_mutation=false"
echo "secret_values_recorded=false"
echo "redacted_public_safe=true"
