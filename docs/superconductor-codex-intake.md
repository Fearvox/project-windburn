# Superconductor Codex Intake

This is the entry card for running Codex against Windburn from the
Superconductor control surface.

## Current Anchor

- Canonical local repo: `/Users/0xvox/Windburn`
- Current role: local-first control plane for Remote Workhorse Phase 1
- Remote workhorse target: `windburn-workhorse-nyc1`
- Default remote host: `24.144.113.25`
- Default droplet id: `568689911`
- Current Superconductor binding:
  `/Users/0xvox/superconductor/projects/Windburn -> /Users/0xvox/Windburn`

Superconductor may start a Codex session from another project directory. Treat
`/Users/0xvox/Windburn` as the repo anchor until the operator explicitly imports
or links a Windburn project under `/Users/0xvox/superconductor/projects/`.

## Intake Command

Run this first in any Superconductor-launched Windburn session:

```sh
scripts/superconductor-codex-intake.sh
```

The command is read-only. It reports:

- repo path, branch, remote, and dirty state;
- whether the repo is already visible under Superconductor projects;
- safe presence checks for Windburn env keys without printing secret values;
- required local entry files;
- first safe commands and operator-call boundaries;
- `PASS` or `FLAG`.

`PASS` is expected when that symlink binding exists and points at the canonical
repo. `FLAG` is expected if Windburn remains outside the Superconductor projects
directory. That is not a failure of the repo. It means Superconductor has not
yet attached this local anchor.

## Binding Options

Use one of these routes, in order of preference:

1. Attach `/Users/0xvox/Windburn` directly in Superconductor if the app supports
   external project roots.
2. Link the existing repo into `/Users/0xvox/superconductor/projects/` while
   preserving `/Users/0xvox/Windburn` as the canonical checkout.
3. Create a project-local worktree under `/Users/0xvox/Windburn/.worktrees/`
   for a bounded implementation slice, then attach that worktree.

Do not duplicate or move the repository just to satisfy UI shape. If a managed
copy becomes necessary, record the reason and the source-of-truth path before
editing.

## Agent Start Checklist

```sh
pwd
git status --short --branch
git remote -v
scripts/superconductor-codex-intake.sh
```

Then read, only as needed:

1. `AGENTS.md`
2. `README.md`
3. `docs/remote-workhorse/README.md`
4. `docs/superconductor-codex-intake.md`

## Safe First Commands

```sh
scripts/check.sh
scripts/remote-host-proof.sh
scripts/digitalocean-snapshot.sh
scripts/nixos-remote-rebuild.sh
git diff --check
git status --short --branch
```

`scripts/remote-host-proof.sh` is read-only. `scripts/digitalocean-snapshot.sh`
and `scripts/nixos-remote-rebuild.sh` default to guarded dry-run behavior unless
explicit apply and confirmation flags are passed.

## Stop And Ask

Stop for explicit operator approval before:

- remote NixOS mutation;
- provider secret sync;
- Codex or Hermes auth sync;
- provider smoke in apply mode;
- snapshot creation with billable apply flags;
- destructive cleanup;
- changing the Superconductor project binding or moving the repo.

## Closeout Shape

Use this compact closeout for Superconductor work:

```text
WINDBURN_SUPERCONDUCTOR_CLOSEOUT
changed:
verified:
remote_mutation:
residual_risk:
next_action:
verdict: PASS | FLAG | BLOCK
```
