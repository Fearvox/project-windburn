# CANARY-read-only-repo-review-health

Generated: `2026-05-03T04:13:33.671412Z`

Target: `/Users/0xvox/Windburn/.`

Host: `deMacBook-Pro.local`

VERDICT: `FLAG`

## Verdict Reasons

- frontier/runtime tool not installed locally yet: nix_version
- frontier/runtime tool not installed locally yet: just_version
- frontier/runtime tool not installed locally yet: doctl_version

## Evidence

- Git repo: `/Users/0xvox/Windburn` branch `main` run-time head `227a3a6`
- tool inventory: /Users/0xvox/Windburn/./docs/remote-workhorse/phase1/TOOL_INVENTORY.json
- Research Vault proof: /Users/0xvox/Windburn/./docs/remote-workhorse/phase1/RESEARCH_VAULT_PROOF.json
- code-review-graph proof: /Users/0xvox/Windburn/./docs/remote-workhorse/phase1/CODE_REVIEW_GRAPH_PROOF.json
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
- `just_version`: `missing` exit `None`
- `doctl_version`: `missing` exit `None`

## Next Repair Cards

- Install or remote-provision Nix/just/doctl before claiming full remote workhorse readiness.
