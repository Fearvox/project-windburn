set shell := ["sh", "-eu", "-c"]

check:
    scripts/check.sh

doctor:
    cargo run -p runtimectl -- doctor --target . --evidence-dir docs/remote-workhorse/phase1/evidence/current

canary:
    cargo run -p runtimectl -- canary --target . --evidence-dir docs/remote-workhorse/phase1/evidence/current --report docs/remote-workhorse/phase1/CANARY-read-only-repo-review-health.md

fmt:
    cargo fmt

test:
    cargo test

