set shell := ["sh", "-eu", "-c"]

check:
    scripts/check.sh

superconductor-intake:
    scripts/superconductor-codex-intake.sh

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

remote-secret-dry-run:
    scripts/remote-secret-sync.sh

remote-secret-apply:
    scripts/remote-secret-sync.sh --apply --confirm-remote-secret-sync

remote-provider-smoke:
    scripts/remote-provider-smoke.sh --apply --confirm-provider-smoke

remote-codex-auth-dry-run:
    scripts/remote-codex-auth-sync.sh

remote-codex-auth-apply:
    scripts/remote-codex-auth-sync.sh --apply --confirm-remote-codex-auth-sync

remote-hermes-codex-smoke:
    scripts/remote-hermes-codex-smoke.sh --apply --confirm-remote-hermes-codex-smoke

droplet-engagement-review:
    scripts/droplet-engagement-review.sh --out docs/remote-workhorse/preflight/DROPLET_ENGAGEMENT_REVIEW.md

do-observability:
    scripts/digitalocean-observability.sh --out docs/remote-workhorse/preflight/DIGITALOCEAN_OBSERVABILITY_GATE.md

do-observability-apply:
    scripts/digitalocean-observability.sh --apply --confirm-do-observability --out docs/remote-workhorse/preflight/DIGITALOCEAN_OBSERVABILITY_GATE.md

hermes-health:
    scripts/hermes-health-gate.sh --out docs/remote-workhorse/preflight/HERMES_HEALTH_GATE.md

hermes-maintenance-inspect:
    scripts/hermes-maintenance.sh --out docs/remote-workhorse/preflight/HERMES_MAINTENANCE.md

hermes-maintenance-apply:
    scripts/hermes-maintenance.sh --apply-update --ensure-tmux --confirm-hermes-maintenance --out docs/remote-workhorse/preflight/HERMES_MAINTENANCE.md

hermes-yolo-inspect:
    scripts/hermes-yolo-loop.sh --out docs/remote-workhorse/preflight/HERMES_YOLO_LOOP_PROOF.md

hermes-yolo-apply:
    scripts/hermes-yolo-loop.sh --ensure --restart --smoke --confirm-hermes-yolo-loop --out docs/remote-workhorse/preflight/HERMES_YOLO_LOOP_PROOF.md

fusion-chat-preview:
    scripts/fusion-chat-preview.sh

fusion-chat-bridge:
    scripts/fusion-chat-bridge.sh

xai-setup-inspect:
    scripts/xai-setup-agent.sh

xai-setup-smoke:
    scripts/xai-setup-agent.sh --call --confirm-xai-setup-agent --out docs/remote-workhorse/preflight/XAI_SETUP_AGENT_SMOKE.md

multica-cache-dry-run:
    scripts/multica-codex-cache-janitor.sh

multica-cache-apply:
    scripts/multica-codex-cache-janitor.sh --apply

fmt:
    cargo fmt

test:
    cargo test
