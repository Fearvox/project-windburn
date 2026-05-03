#!/usr/bin/env sh
set -eu

cargo fmt --check
cargo test
cargo run -p runtimectl -- doctor --target . --evidence-dir docs/remote-workhorse/phase1/evidence/current
cargo run -p runtimectl -- canary --target . --evidence-dir docs/remote-workhorse/phase1/evidence/current --report docs/remote-workhorse/phase1/CANARY-read-only-repo-review-health.md
git diff --check

