#!/usr/bin/env sh
set -eu

TMP_SPOOL_DIR="$(mktemp -d "${TMPDIR:-/tmp}/windburn-runtime-check.XXXXXX")"
cleanup() {
  rm -rf "$TMP_SPOOL_DIR"
}
trap cleanup EXIT INT TERM

cargo fmt --check
cargo test
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
cargo run -p runtimectl -- doctor --target . --evidence-dir /tmp/windburn-phase1-doctor-check
cargo run -p runtimectl -- canary --target . --evidence-dir docs/remote-workhorse/phase1/evidence/current --report docs/remote-workhorse/phase1/CANARY-read-only-repo-review-health.md
git diff --check
