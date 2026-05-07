# Hermes Main Canary

This document records the canary-only Hermes Agent upgrade lane for the remote
NixOS workhorse.

## Target

- Previous pinned rev: `6f2dab248a6cc8591af46e5deb2dc939c2b43146`
- Canary target rev: `49c3c2e0d37c96dc593a807a5e81fdf4f0aa3d85`
- Upstream source: `github:NousResearch/hermes-agent`
- Upstream commit: <https://github.com/NousResearch/hermes-agent/commit/49c3c2e0d37c96dc593a807a5e81fdf4f0aa3d85>
- Latest release at selection time: `v2026.4.30`
- Release URL: <https://github.com/NousResearch/hermes-agent/releases/tag/v2026.4.30>

## Selection Rationale

This is not a stable production release bump. The remote workhorse already runs
the latest tagged Hermes release at selection time. The target is a main-branch
canary selected because the latest upstream commit is maintainer-authored and
Teknium is actively curating post-release fixes into `main`.

The delta from the previous pin to the canary target is intentionally treated as
high risk:

- compare status: `ahead`
- commits ahead: `479`
- files changed: `300`

## Canary Boundary

Allowed:

- update the Nix Hermes pin;
- run `nixos-rebuild test` through the guarded workhorse script;
- run the existing redacted smoke checks;
- collect PASS, FLAG, or BLOCK evidence.

Not allowed in this canary:

- no `nixos-rebuild switch`;
- no provider secret sync;
- no raw tmux pane transcript capture;
- no public host, SSH target, or private command disclosure.

## Verification

Commands:

```bash
# guarded dry-run
scripts/nixos-remote-rebuild.sh

# package canary test
scripts/nixos-remote-rebuild.sh --apply --mode test --confirm-remote-nixos-rebuild

# rev-aware yolo restart gate test
scripts/nixos-remote-rebuild.sh --apply --mode test --confirm-remote-nixos-rebuild
```

The second `test` run was intentional. The first run proved the target Hermes
package and existing runtime evidence. It also exposed a canary gap: the
already-running tmux yolo pane could stay alive on the previous package after a
pin bump. The NixOS module now records the expected Hermes rev in
`/srv/windburn/state/hermes-yolo.rev`, respawns the yolo pane when the rev
changes, and makes the runner aggregate require `ensured_rev_matches=true`.

Remote test evidence from the final run:

- `nixos-rebuild test`: `PASS`
- system state: `running`
- failed units: `0`
- Hermes command evidence: `PASS`
- Hermes rev in command evidence: `49c3c2e0d37c96dc593a807a5e81fdf4f0aa3d85`
- Hermes yolo lane: `PASS`
- Hermes yolo `ensured_rev_matches`: `true`
- Hermes yolo process readback: current `hermes-agent-env` path, no stale
  pre-canary env path
- Herdr cockpit: `PASS`
- runner aggregate: `PASS`
- secret values recorded: `false`
- redacted public safe: `true`

## Verdict

`PASS`: main-branch Hermes canary passed `nixos-rebuild test`, command evidence,
rev-aware yolo lane evidence, Herdr cockpit evidence, and runner aggregate
evidence.

This is still a canary branch, not a production `switch` record. No
`nixos-rebuild switch` was run in this lane.
