# Windburn Agent Operating Contract

Windburn is the local-first control surface for the Remote Workhorse program.
The first active design is:

- `docs/remote-workhorse/0xvox-unknown-design-20260502-222759.md`

## Current Scope

Phase 1 is contract-first infrastructure plus the first proven DigitalOcean
base host. Build artifacts, evidence templates, local canaries, and operator
docs must let a new agent rerun the same workflow. Remote mutation is gated:
base-host snapshot requires explicit confirmation, and NixOS conversion requires
its own later confirmation.

## Worktree Convention

Use project-local git worktrees under `.worktrees/` for implementation slices.
Keep `.worktrees/` ignored. Merge verified work back to `main` only after the
slice passes its local checks.

## Proof Rules

- Read live repo/tool state before making success claims.
- If a required tool is missing, write a repair card and return `FLAG` or
  `BLOCK`; do not fake `PASS`.
- Research Vault and code-review-graph claims require fresh proof artifacts.
- Preserve existing routes unless the design explicitly replaces them.
- Never store secrets in this repository. Use examples and operator-owned env
  files for provider credentials.

## Default Verification

Run these before closeout when the relevant tooling exists:

```sh
scripts/check.sh
git diff --check
scripts/digitalocean-snapshot.sh
git status --short --branch
```
