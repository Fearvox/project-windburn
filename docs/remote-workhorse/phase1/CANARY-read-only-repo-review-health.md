# CANARY-read-only-repo-review-health

Generated: `2026-05-05T03:11:51.890264Z`

Target: `/Users/0xvox/Windburn/.worktrees/fusion-websocket/.`

Host: `deMacBook-Pro.local`

VERDICT: `PASS`

## Verdict Reasons

- all Phase 1 canary checks passed

## Evidence

- Git repo: `/Users/0xvox/Windburn/.worktrees/fusion-websocket` branch `codex/fusion-websocket` run-time head `2b811e9`
- tool inventory: /Users/0xvox/Windburn/.worktrees/fusion-websocket/./docs/remote-workhorse/phase1/TOOL_INVENTORY.json
- Research Vault proof: /Users/0xvox/Windburn/.worktrees/fusion-websocket/./docs/remote-workhorse/phase1/RESEARCH_VAULT_PROOF.json
- code-review-graph proof: /Users/0xvox/Windburn/.worktrees/fusion-websocket/./docs/remote-workhorse/phase1/CODE_REVIEW_GRAPH_PROOF.json
- Generated doctor JSON: `docs/remote-workhorse/phase1/evidence/current/doctor.json`

## Probe Summary

- `codex_version`: `pass` exit `Some(0)`
- `codex_mcp_list`: `pass` exit `Some(0)`
- `cargo_version`: `pass` exit `Some(0)`
- `rustc_version`: `pass` exit `Some(0)`
- `bun_version`: `pass` exit `Some(0)`
- `node_version`: `pass` exit `Some(0)`
- `gh_version`: `pass` exit `Some(0)`
- `hermes_version`: `pass` exit `Some(0)`
- `nix_version`: `missing` exit `None`
- `nix_root_mount`: `fail` exit `Some(1)`
- `nix_store_volume`: `pass` exit `Some(0)`
- `nix_profile_volume`: `pass` exit `Some(0)`
- `colima_list`: `pass` exit `Some(0)`
- `colima_status`: `fail` exit `Some(1)`
- `just_version`: `pass` exit `Some(0)`
- `doctl_version`: `pass` exit `Some(0)`

## Next Repair Cards

- None.
