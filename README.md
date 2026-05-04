# Windburn

Windburn is the local-first control plane for shipping reliable remote agent
workhorses. The first active slice is Remote Workhorse Phase 1: contract-first
evidence, tool truth, and a read-only canary before remote provisioning.

## Fast Path

```sh
scripts/superconductor-codex-intake.sh
scripts/check.sh
scripts/preflight.sh
scripts/remote-host-proof.sh
scripts/digitalocean-snapshot.sh
scripts/nixos-conversion.sh
scripts/nixos-remote-rebuild.sh
scripts/remote-secret-sync.sh
scripts/remote-provider-smoke.sh
scripts/remote-codex-auth-sync.sh
scripts/remote-hermes-codex-smoke.sh
scripts/droplet-engagement-review.sh
scripts/digitalocean-observability.sh
scripts/hermes-health-gate.sh
scripts/hermes-maintenance.sh
scripts/hermes-yolo-loop.sh
scripts/fusion-chat-preview.sh
scripts/fusion-chat-bridge.sh
scripts/multica-runtime-card-verify.sh
scripts/windburn-captain-runtime.sh
scripts/xai-setup-agent.sh
scripts/multica-codex-cache-janitor.sh
```

For one-shot DigitalOcean read-only preflight without storing a `doctl` context,
export `DIGITALOCEAN_ACCESS_TOKEN`, `DIGITALOCEAN_TOKEN`, or
`DOCTL_ACCESS_TOKEN` in your local shell before `scripts/preflight.sh`. Evidence
records only the variable name, not the token value.

If `just` is installed:

```sh
just superconductor-intake
just check
just remote-proof
just snapshot-dry-run
just nixos-conversion-dry-run
just nixos-rebuild-dry-run
just remote-secret-dry-run
just remote-provider-smoke
just remote-codex-auth-dry-run
just remote-hermes-codex-smoke
just droplet-engagement-review
just do-observability
just hermes-health
just hermes-maintenance-inspect
just hermes-yolo-inspect
just fusion-chat-preview
just fusion-chat-bridge
just multica-runtime-card-verify
just windburn-captain-runtime-status
just xai-setup-inspect
just xai-setup-smoke
```

## Repo Map

- `docs/remote-workhorse/` - approved design, Phase 1 artifacts, canary report,
  and the v1 Multica/gstack bootstrap runtime-queue handshake docs.
- `docs/superconductor-codex-intake.md` - Superconductor-side Codex handoff and
  read-only intake contract.
- `crates/runtimectl/` - Rust CLI for local doctor and canary evidence.
- `config/tool-registry.toml` - required, optional, and disabled tool policy.
- `docs/external-indexes/` - generated GitHub indexes for frontier stack repos.
- `flake.nix` - Nix dev shell/build scaffold for the later remote workhorse cell.
- `docs/remote-workhorse/preflight/` - gates before Computer Use touches remote NixOS.
- `nixos/hosts/windburn-workhorse-nyc1/` - first-boot NixOS host import.
- `scripts/nixos-remote-rebuild.sh` - guarded remote NixOS test/switch deploy.
- `scripts/remote-secret-sync.sh` - allowlisted root-only provider secret sync.
- `scripts/remote-provider-smoke.sh` - remote provider smoke and repair card.
- `scripts/remote-codex-auth-sync.sh` - root-only Codex CLI plus Hermes
  `openai-codex` auth sync.
- `scripts/remote-hermes-codex-smoke.sh` - pinned Hermes `openai-codex`
  remote model-call smoke.
- `scripts/droplet-engagement-review.sh` - read-only DO/CCR/Hermes/Windburn
  engagement gate for remote pre-flight.
- `scripts/digitalocean-observability.sh` - dry-run first DO uptime/alert
  desired-state gate.
- `scripts/hermes-health-gate.sh` - read-only Hermes service, task, update, and
  tmux runtime-entry health gate.
- `scripts/hermes-maintenance.sh` - guarded Hermes update and fixed tmux
  runtime-entry maintenance path.
- `scripts/hermes-yolo-loop.sh` - guarded `hermes --yolo` tmux runtime loop
  and `openai-codex` one-shot proof.
- `apps/fusion-chat-terminal/` - dot-matrix web terminal for the unified remote
  chat entrance.
- `scripts/fusion-chat-preview.sh` - static preview server for the fusion chat
  terminal.
- `scripts/fusion-chat-bridge.sh` - local read-only bridge server for live
  repo/proof hydration in the fusion chat terminal.
- `scripts/multica-runtime-card-verify.sh` - local verifier for the redacted
  Multica runtime-card contract.
- `scripts/windburn-captain-runtime.sh` - forced-command-friendly Captain
  runtime wrapper for stdin cards, bounded `run-card` queue execution, lease
  slots, spool status JSON, and compact redacted summaries.
- `scripts/xai-setup-agent.sh` - local xAI setup lane smoke gate using
  operator-owned credentials with redacted evidence.
- `docs/ops/` - local reliability guards such as Multica Codex cache pruning.

## Current Boundary

This repo now has a DigitalOcean-backed NixOS workhorse reachable through the
`remote-workhorse` route label. Public docs stay redacted: host details,
snapshot ids, SSH targets, and local absolute paths belong in operator-private
proof surfaces, not shared repo docs. Remote NixOS changes still go through
`nixos-rebuild test` before `switch`. Provider smoke remains intentionally gated
behind root-only allowlisted secret sync and may return
`REMOTE_PROVIDER_SECRET_MISSING` until usable operator-owned provider profiles
exist on the runtime host. The Codex-on-Hermes runtime path is proven in the
remote-workhorse preflight docs through redacted evidence refs. Phase 1 still
succeeds only when a new agent can rerun the proof path, see which tools are
usable, and return `PASS`, `FLAG`, or `BLOCK` without guesswork.

For Superconductor sessions, begin with `scripts/superconductor-codex-intake.sh`
so the agent proves whether the canonical Windburn repo is attached through the
expected Superconductor binding without copying raw operator-local paths into
shared docs.
