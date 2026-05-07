#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CARD_PATH="${1:-"$ROOT_DIR/docs/remote-workhorse/fixtures/research-run-card-v0.json"}"

"$ROOT_DIR/scripts/research-run-card-verify.sh" "$CARD_PATH"

echo "PASS research_appliance_smoke"
echo "card=$CARD_PATH"
echo "remote_mutation=false"
echo "secret_values_recorded=false"
echo "redacted_public_safe=true"
