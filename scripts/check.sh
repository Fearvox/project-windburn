#!/usr/bin/env sh
set -eu

TMP_SPOOL_DIR="$(mktemp -d "${TMPDIR:-/tmp}/windburn-runtime-check.XXXXXX")"
PHASE1_CHECK_EVIDENCE_DIR="$TMP_SPOOL_DIR/phase1-evidence"
PHASE1_CHECK_CANARY_REPORT="$TMP_SPOOL_DIR/CANARY-read-only-repo-review-health.md"
cleanup() {
  rm -rf "$TMP_SPOOL_DIR"
}
trap cleanup EXIT INT TERM

cargo fmt --check
cargo test
scripts/research-run-card-verify.sh
cat docs/remote-workhorse/fixtures/research-run-card-v0.json | scripts/research-run-card-verify.sh -
scripts/research-appliance-smoke.sh
scripts/superruntime-fixture-verify.sh
scripts/multica-runtime-card-verify.sh
cat docs/remote-workhorse/fixtures/multica-runtime-card-v0.json | scripts/multica-runtime-card-verify.sh -
scripts/multica-runtime-card-verify.sh docs/remote-workhorse/fixtures/multica-hermes-autoresearch-card-v0.json
cat docs/remote-workhorse/fixtures/multica-hermes-autoresearch-card-v0.json | scripts/multica-runtime-card-verify.sh -
WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card docs/remote-workhorse/fixtures/multica-runtime-card-v0.json --action status
WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card docs/remote-workhorse/fixtures/multica-runtime-card-v0.json --action superruntime-status
WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card docs/remote-workhorse/fixtures/multica-runtime-card-v0.json --action run-card
cat docs/remote-workhorse/fixtures/multica-runtime-card-v0.json | WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card - --action verify-card
cat docs/remote-workhorse/fixtures/multica-runtime-card-v0.json | WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card - --action status
cat docs/remote-workhorse/fixtures/multica-runtime-card-v0.json | WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card - --action superruntime-status
cat docs/remote-workhorse/fixtures/multica-runtime-card-v0.json | WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card - --action run-card
WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card docs/remote-workhorse/fixtures/multica-hermes-autoresearch-card-v0.json --action hermes-autoresearch
WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card docs/remote-workhorse/fixtures/multica-hermes-autoresearch-card-v0.json --action run-card
cat docs/remote-workhorse/fixtures/multica-hermes-autoresearch-card-v0.json | WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card - --action verify-card
cat docs/remote-workhorse/fixtures/multica-hermes-autoresearch-card-v0.json | WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card - --action hermes-autoresearch
cat docs/remote-workhorse/fixtures/multica-hermes-autoresearch-card-v0.json | WINDBURN_RUNTIME_SPOOL_DIR="$TMP_SPOOL_DIR/runtime-spool" scripts/windburn-captain-runtime.sh --card - --action run-card
scripts/fusion-bridge-api-smoke.sh
cargo run -p runtimectl -- doctor --target . --evidence-dir "$PHASE1_CHECK_EVIDENCE_DIR"
cargo run -p runtimectl -- canary --target . --evidence-dir "$PHASE1_CHECK_EVIDENCE_DIR" --report "$PHASE1_CHECK_CANARY_REPORT"
cargo run -p runtimectl -- workhorse-status --target . --output "$TMP_SPOOL_DIR/workhorse-status.json" --report "$TMP_SPOOL_DIR/WORKHORSE_RUNTIME_STATUS.md"
git diff --check
