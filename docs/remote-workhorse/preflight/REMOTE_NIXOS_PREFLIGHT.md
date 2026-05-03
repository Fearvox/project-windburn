# REMOTE_NIXOS_PREFLIGHT

Generated: `2026-05-03T04:59:41.02628Z`

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
| Required files | `PASS` | `8/8 present` |
| DigitalOcean read auth | `fail` | `doctl_account_status` |
| DigitalOcean read-only inventory | `PENDING` | `0/11 probes passed` |
| DigitalOcean managed-service reconnaissance | `PENDING` | `0/21 advisory probes passed` |
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
- `doctl_projects`: `fail` exit `Some(1)`
- `doctl_apps`: `fail` exit `Some(1)`
- `doctl_databases`: `fail` exit `Some(1)`
- `doctl_vpcs`: `fail` exit `Some(1)`
- `doctl_load_balancers`: `fail` exit `Some(1)`
- `doctl_reserved_ips`: `fail` exit `Some(1)`
- `doctl_tags`: `fail` exit `Some(1)`
- `doctl_registries`: `fail` exit `Some(1)`
- `doctl_monitoring_alerts`: `fail` exit `Some(1)`
- `doctl_uptime_checks`: `fail` exit `Some(1)`
- `doctl_gradient_regions`: `fail` exit `Some(1)`
- `doctl_gradient_models`: `fail` exit `Some(1)`
- `doctl_gradient_agents`: `fail` exit `Some(1)`
- `doctl_gradient_knowledge_bases`: `fail` exit `Some(1)`
- `doctl_dedicated_inference_endpoints`: `fail` exit `Some(1)`
- `doctl_dedicated_inference_sizes`: `fail` exit `Some(1)`
- `doctl_dedicated_inference_model_config`: `fail` exit `Some(1)`
- `doctl_serverless_namespaces`: `fail` exit `Some(1)`
- `doctl_nfs_atl1`: `fail` exit `Some(1)`
- `doctl_nfs_nyc2`: `fail` exit `Some(1)`
- `doctl_nfs_ams3`: `fail` exit `Some(1)`

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

## DigitalOcean Managed-Service Reconnaissance

These probes are read-only and advisory. They map DigitalOcean's managed services into the workhorse plan without creating, updating, or deleting resources.

- Projects: `doctl projects list --format ID,Name,Purpose,Environment,IsDefault --no-header`
- App Platform: `doctl apps list --format ID,Spec.Name,DefaultIngress,ActiveDeployment.ID,Updated --no-header`
- Managed Databases: `doctl databases list --format ID,Name,Engine,Version,Region,Status,Size,StorageMib --no-header`
- VPCs: `doctl vpcs list --format ID,Name,IPRange,Region,Default --no-header`
- Load Balancers: `doctl compute load-balancer list --format ID,Name,IP,IPv6,Status,Region,VPCUUID,DropletIDs,HealthCheck --no-header`
- Reserved IPs: `doctl compute reserved-ip list --format IP,Region,DropletID,DropletName,ProjectID --no-header`
- Tags: `doctl compute tag list --format Name,DropletCount --no-header`
- Container Registry: `doctl registries list --format Name,Endpoint,Region --no-header`
- Monitoring alerts: `doctl monitoring alert list --format UUID,Type,Description,Entities,Tags,Emails,Enabled --no-header`
- Uptime checks: `doctl monitoring uptime list --format ID,Name,Type,Target,Regions,Enabled --no-header`
- Gradient regions: `doctl gradient list-regions --format Region,ServesInference,ServesBatch --no-header`
- Gradient models: `doctl gradient list-models --format Id,Name,isFoundational,Version --no-header`
- Gradient agents: `doctl gradient agent list --format Id,Name,Region,Model-id,Project-id --no-header`
- Gradient knowledge bases: `doctl gradient knowledge-base list --format UUID,Name,Region,ProjectId,DatabaseId,IsPublic,LastIndexingJob --no-header`
- Dedicated inference endpoints: `doctl dedicated-inference list --format ID,Name,Region,Status,VPCUUID,PublicEndpoint,PrivateEndpoint --no-header`
- Dedicated inference sizes: `doctl dedicated-inference get-sizes --format GPUSlug,PricePerHour,CPU,Memory,GPUCount,GPUVramGB,GPUModel,Regions --no-header`
- Dedicated inference model fit: `doctl dedicated-inference get-gpu-model-config --format ModelSlug,ModelName,IsModelGated,GPUSlugs --no-header`
- Serverless namespaces: `doctl serverless namespaces list --format Label,Region,ID,Host --no-header`
- Network File Storage by candidate region: `doctl nfs list --region <region> --format ID,Name,Size,Region,Status,VpcIDs --no-header`
- Spaces bucket inventory is not covered by this `doctl 1.155.0` gate because the local CLI only exposes Spaces access-key commands; use S3-compatible tooling or MCP/API after explicit scope selection.

## Auth Boundary

- `runtimectl preflight` uses the first non-empty token from `DIGITALOCEAN_ACCESS_TOKEN`, `DIGITALOCEAN_TOKEN`, or `DOCTL_ACCESS_TOKEN` for read-only `doctl` probes, and records only the variable name in evidence.
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
