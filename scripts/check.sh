#!/usr/bin/env sh
set -eu

cargo fmt --check
cargo test
scripts/superruntime-fixture-verify.sh
cargo run -p runtimectl -- doctor --target . --evidence-dir /tmp/windburn-phase1-doctor-check
cargo run -p runtimectl -- canary --target . --evidence-dir docs/remote-workhorse/phase1/evidence/current --report docs/remote-workhorse/phase1/CANARY-read-only-repo-review-health.md
git diff --check
