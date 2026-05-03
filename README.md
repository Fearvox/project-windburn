# Windburn

Windburn is the local-first control plane for shipping reliable remote agent
workhorses. The first active slice is Remote Workhorse Phase 1: contract-first
evidence, tool truth, and a read-only canary before remote provisioning.

## Fast Path

```sh
scripts/check.sh
```

If `just` is installed:

```sh
just check
```

## Repo Map

- `docs/remote-workhorse/` - approved design, Phase 1 artifacts, canary report.
- `crates/runtimectl/` - Rust CLI for local doctor and canary evidence.
- `config/tool-registry.toml` - required, optional, and disabled tool policy.
- `docs/external-indexes/` - generated GitHub indexes for frontier stack repos.
- `flake.nix` - Nix dev shell/build scaffold for the later remote workhorse cell.

## Current Boundary

This repo does not yet provision a remote host. Phase 1 succeeds when a new
agent can rerun the same local proof path, see which tools are usable, and
return `PASS`, `FLAG`, or `BLOCK` without guesswork.

