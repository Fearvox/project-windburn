# REMOTE_NIXOS_PREFLIGHT

Generated: `2026-05-03T04:43:47.654946Z`

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
| DigitalOcean read-only inventory | `PENDING` | `0/11 probes passed` |
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
- `doctl_account_ratelimit`: `fail` exit `Some(1)`
- `doctl_regions`: `fail` exit `Some(1)`
- `doctl_sizes`: `fail` exit `Some(1)`
- `doctl_droplets`: `fail` exit `Some(1)`
- `doctl_gpu_droplets`: `fail` exit `Some(1)`
- `doctl_ssh_keys`: `fail` exit `Some(1)`
- `doctl_snapshots`: `fail` exit `Some(1)`
- `doctl_images_private`: `fail` exit `Some(1)`
- `doctl_images_public`: `fail` exit `Some(1)`
- `doctl_firewalls`: `fail` exit `Some(1)`
- `doctl_volumes`: `fail` exit `Some(1)`

## DigitalOcean Read-Only Command Set

These commands are intentionally non-mutating and were cross-checked against the local `doctl 1.155.0` help output after consulting DigitalOcean Ask Docs.

- Auth context list: `doctl auth list`
- Account status: `doctl account get --format Status --no-header`
- API rate limit: `doctl account ratelimit --format Remaining,Reset --no-header`
- Regions: `doctl compute region list --format Slug,Available --no-header`
- Sizes: `doctl compute size list --format Slug,Memory,VCPUs,Disk,PriceMonthly --no-header`
- Droplets: `doctl compute droplet list --format ID,Name,PublicIPv4,PrivateIPv4,Region,Image,Status,Tags,Features,Volumes --no-header`
- GPU Droplets: `doctl compute droplet list --gpus --format ID,Name,PublicIPv4,Region,Image,Status,Features --no-header`
- SSH keys: `doctl compute ssh-key list --format ID,Name,FingerPrint --no-header`
- Snapshots: `doctl compute snapshot list --format ID,Name,CreatedAt,Regions,ResourceId,ResourceType,MinDiskSize,Size,Tags --no-header`
- Private images: `doctl compute image list --format ID,Name,Type,Distribution,Slug,Public,MinDisk --no-header`
- Public images: `doctl compute image list --public --format ID,Name,Distribution,Slug,Public,MinDisk --no-header`
- Firewalls: `doctl compute firewall list --format ID,Name,Status,DropletIDs,Tags,PendingChanges --no-header`
- Volumes: `doctl compute volume list --format ID,Name,Size,Region,DropletIDs,Tags --no-header`
- Host key proof, after a host is selected: `ssh-keyscan -T 5 <host>` and optional `ssh-keygen -F <host>` lookup.

## Auth Boundary

- `doctl auth init --context <name>` stores a persistent local context and requires action-time confirmation before we run it.
- `doctl --access-token <token> ...` can run one command without initializing a context, but the token must never be pasted into chat or evidence.
- Current preflight artifacts may contain cloud inventory such as Droplet IDs and IPs once auth works; keep them local unless explicitly redacted for sharing.

## DigitalOcean Rollback Gotchas

- Rebuilds can change SSH host keys; capture the new key with `ssh-keyscan`, and only clean stale `known_hosts` entries deliberately.
- Firewall rules must preserve SSH and outbound HTTPS for Nix downloads before attaching them to the host.
- Snapshot/image/volume evidence must exist before persistent NixOS mutation; never delete snapshot candidates during preflight.
- Size, region, GPU image, backups, monitoring agent, private networking, and volume limits should be checked from read-only inventory before create/update operations.

## Computer Use Entry Rules

- Start read-only: host identity, OS release, kernel, uptime, disk, memory, users, services.
- Capture command, exit status, and artifact path for every step.
- Take cloud snapshot/backout evidence before any persistent NixOS mutation.
- Use `nixos-rebuild test` before `switch`; preserve rollback path.
- Stop on unknown credentials, missing target host, dirty repo, or absent backout plan.
