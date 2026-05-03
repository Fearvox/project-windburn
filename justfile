set shell := ["sh", "-eu", "-c"]

check:
    scripts/check.sh

doctor:
    cargo run -p runtimectl -- doctor --target . --evidence-dir docs/remote-workhorse/phase1/evidence/current

canary:
    cargo run -p runtimectl -- canary --target . --evidence-dir docs/remote-workhorse/phase1/evidence/current --report docs/remote-workhorse/phase1/CANARY-read-only-repo-review-health.md

preflight:
    scripts/preflight.sh

remote-proof:
    WINDBURN_REMOTE_HOST="${WINDBURN_REMOTE_HOST:-24.144.113.25}" WINDBURN_DROPLET_ID="${WINDBURN_DROPLET_ID:-568689911}" scripts/remote-host-proof.sh

snapshot-dry-run:
    scripts/digitalocean-snapshot.sh

snapshot-apply:
    scripts/digitalocean-snapshot.sh --apply --confirm-billable-snapshot

nixos-conversion-dry-run:
    scripts/nixos-conversion.sh

nixos-conversion-apply:
    scripts/nixos-conversion.sh --apply --confirm-destructive-nixos-conversion --confirm-snapshot-id 227115138

nixos-rebuild-dry-run:
    scripts/nixos-remote-rebuild.sh

nixos-rebuild-test:
    scripts/nixos-remote-rebuild.sh --apply --confirm-remote-nixos-rebuild --mode test

nixos-rebuild-switch:
    scripts/nixos-remote-rebuild.sh --apply --confirm-remote-nixos-rebuild --mode switch

multica-cache-dry-run:
    scripts/multica-codex-cache-janitor.sh

multica-cache-apply:
    scripts/multica-codex-cache-janitor.sh --apply

fmt:
    cargo fmt

test:
    cargo test
