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
```

## Repo Map

- `docs/remote-workhorse/` - approved design, Phase 1 artifacts, canary report.
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
- `docs/ops/` - local reliability guards such as Multica Codex cache pruning.

## Current Boundary

This repo now has a DigitalOcean workhorse booted as NixOS 25.11:
`windburn-workhorse-nyc1` (`568689911`, `24.144.113.25`) plus base snapshot
`227115138` and foundation snapshot `227116767`. Remote NixOS changes go
through `nixos-rebuild test` before `switch`. Provider smoke is intentionally
gated behind root-only allowlisted secret sync and currently reports
`REMOTE_PROVIDER_SECRET_MISSING` until usable provider credentials are installed.
The Codex EDU path is separately proven through Hermes `openai-codex` with
artifact `/srv/windburn/runs/hermes-codex-smoke/20260503T124810Z-hermes-codex-smoke/result.json`.
Phase 1 still succeeds only when a new agent can rerun the proof path, see which
tools are usable, and return `PASS`, `FLAG`, or `BLOCK` without guesswork.
For Superconductor sessions, begin with `scripts/superconductor-codex-intake.sh`
so the agent proves whether `/Users/0xvox/Windburn` is attached, linked, or still
external to `/Users/0xvox/superconductor/projects/`.
Current Superconductor binding is
`/Users/0xvox/superconductor/projects/Windburn -> /Users/0xvox/Windburn`.
