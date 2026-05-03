# Windburn Agent Operating Contract

Windburn is the local-first control surface for the Remote Workhorse program.
The first active design is:

- `docs/remote-workhorse/0xvox-unknown-design-20260502-222759.md`

## Current Scope

Phase 1 is contract-first infrastructure plus the first proven DigitalOcean
NixOS workhorse. Build artifacts, evidence templates, local canaries, and
operator docs must let a new agent rerun the same workflow. Remote NixOS
mutations go through `scripts/nixos-remote-rebuild.sh`, with `test` before
`switch`. The first foundation layer is proven in
`docs/remote-workhorse/preflight/NIXOS_FOUNDATION_PROOF.md`.

## Superconductor Session

When launched from Superconductor, start by proving the repo anchor instead of
trusting the shell cwd:

```sh
scripts/superconductor-codex-intake.sh
```

Current canonical local repo is `/Users/0xvox/Windburn`. If Superconductor
starts in another project, use explicit `workdir` or `git -C /Users/0xvox/Windburn`
for every repo claim. Do not move, duplicate, or relink this repo without an
explicit operator request.

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
scripts/superconductor-codex-intake.sh
scripts/check.sh
git diff --check
scripts/digitalocean-snapshot.sh
scripts/nixos-remote-rebuild.sh
git status --short --branch
```
