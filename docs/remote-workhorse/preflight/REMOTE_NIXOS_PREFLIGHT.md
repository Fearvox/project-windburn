# REMOTE_NIXOS_PREFLIGHT

Generated: `2026-05-03T04:27:53.175833Z`

Target: `/Users/0xvox/Windburn/.`

Remote Host: `unset`

VERDICT: `FLAG`

## Verdict Reasons

- remote host not selected; set WINDBURN_REMOTE_HOST or pass --remote-host before Computer Use
- DigitalOcean account read probe failed; refresh doctl auth before cloud snapshot/firewall checks

## Gates

| Gate | Status | Evidence |
| --- | --- | --- |
| Local conductor doctor | `PASS` | `docs/remote-workhorse/preflight/evidence/current/doctor.json` |
| Required files | `PASS` | `7/7 present` |
| DigitalOcean read auth | `fail` | `doctl_account_status` |
| Remote host selected | `FLAG` | `unset` |
| Computer Use mutation gate | `PENDING` | Run only after this preflight is PASS or consciously accepted. |
| Remote NixOS mutation gate | `PENDING` | First remote command must be read-only host/OS/Nix proof. |

## Local Probe Summary

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
- `colima_status`: `pass` exit `Some(0)`
- `just_version`: `pass` exit `Some(0)`
- `doctl_version`: `pass` exit `Some(0)`

## Cloud Probe Summary

- `just_list`: `pass` exit `Some(0)`
- `doctl_auth_list`: `pass` exit `Some(0)`
- `doctl_account_status`: `fail` exit `Some(1)`

## Computer Use Entry Rules

- Start read-only: host identity, OS release, kernel, uptime, disk, memory, users, services.
- Capture command, exit status, and artifact path for every step.
- Take cloud snapshot/backout evidence before any persistent NixOS mutation.
- Use `nixos-rebuild test` before `switch`; preserve rollback path.
- Stop on unknown credentials, missing target host, dirty repo, or absent backout plan.
