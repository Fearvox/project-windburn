# DigitalOcean Capability Map

Updated: 2026-05-03

Purpose: turn the current DigitalOcean docs and Ask Docs conversation into a
preflight map for the remote NixOS workhorse. This file is not a provisioning
plan. It is the capability inventory that must stay ahead of any Computer Use
session that mutates the remote host.

## Source Boundary

Use three levels of authority:

1. Official docs and current local CLI help are source of truth.
2. DigitalOcean Ask Docs output is useful as ideation, but every command must
   be checked against `doctl 1.155.0` or official API docs before use.
3. Any command that creates, updates, deletes, authenticates persistently, or
   changes billing requires action-time operator confirmation.

Official pages checked:

- [Launchpad Starter Kits](https://docs.digitalocean.com/products/launchpad/):
  RAG Assistant, Data Workflow, and Observability kits; private preview; as of
  the current docs, command-line deployment goes through Terraform and direct
  `doctl` Launchpad integration is not available.
- [DigitalOcean AI Inference](https://docs.digitalocean.com/products/inference/):
  model catalog, serverless inference, dedicated inference endpoints, inference
  router, batch inference, and Agent Platform.
- [DigitalOcean MCP Tools](https://docs.digitalocean.com/reference/mcp/mcp-tools/):
  MCP access to AI Platform, accounts, apps, DBaaS, droplets, networking,
  insights, NFS, Spaces keys, and volumes.
- [Trace Agent Responses](https://docs.digitalocean.com/products/ai-platform/how-to/trace-agents/):
  traces expose token usage, processing times, session/trace IDs, accessed
  knowledge bases, routes, and functions.
- [Route to Multiple Agents](https://docs.digitalocean.com/products/ai-platform/how-to/route-agents/):
  parent agents can route work to child agents via API or control panel.
- [Private Droplets](https://docs.digitalocean.com/products/droplets/details/private-droplets/):
  VPC-only droplets have no direct public connectivity and rely on VPC/NAT
  shape for outbound access.

## Target Shape

Keep the remote workhorse split into four planes:

| Plane | Role | DigitalOcean surface | Local preflight proof |
| --- | --- | --- | --- |
| Execution cell | NixOS host for heavy agent work, builds, evidence capture, and controlled remote shell | Droplet or Private Droplet, SSH key, image/snapshot, size, volume, firewall, VPC | `doctl compute *` inventory plus `ssh-keyscan` once host exists |
| AI sidecar | Retrieval, model routing, traceable agent behavior, and optional RV sidecar | Agent Platform, Knowledge Bases, Serverless Inference, Dedicated Inference | `doctl gradient *` and `doctl dedicated-inference *` reconnaissance |
| App/control surface | Public or operator-facing UI/API when needed | App Platform, Launchpad RAG Assistant, Functions, serverless namespaces | `doctl apps list`, `doctl serverless namespaces list`, Launchpad docs |
| Safety and evidence | Rollback, audit, alerts, storage, private traffic | Projects, VPCs, Firewalls, Monitoring, Uptime, Logs, Managed DBs, Spaces, NFS, Volumes | managed-service reconnaissance probes and run digest links |

The NixOS host should remain the deterministic execution cell. DO managed
services are sidecars that reduce things the host has to own: public HTTPS,
database operations, object storage, uptime probes, agent tracing, and scalable
inference.

## What The Ask Docs Thread Added

Useful ideas to keep:

- Use a Knowledge Base as a sidecar Research Vault substrate for selected
  project docs, run digests, and approved memory packs.
- Use Agent Platform tracing as an evidence layer for RAG lookups, model
  routing, token use, and function/tool calls.
- Use RAG Assistant as a starter path for an operator-facing assistant, but only
  after accepting that Launchpad is private preview and Terraform-first.
- Use Observability-style resources for the log/search plane if DO-hosted
  observability becomes worth the extra cost.
- Treat App Platform as the public surface, not as the full heavy-work runtime.

Corrections from local `doctl 1.155.0` help:

- `doctl account view` is not valid locally; use `doctl account get`.
- `doctl account quota view` is not valid locally.
- `doctl compute size list --region <region>` is not valid locally; collect
  full size inventory and filter after capture.
- `doctl compute image list --distribution nixos --region <region>` is not
  valid locally; collect public/private image inventory and filter after capture.
- `doctl launchpad deploy ...` is not available locally; Launchpad CLI workflow
  is Terraform according to the current docs.
- `doctl ai ...` is an alias family for `doctl gradient ...`; use canonical
  `doctl gradient ...` in repo artifacts.

## Read-Only Preflight Commands

Core droplet and rollback inventory:

```sh
doctl auth list
doctl account get --format Status --no-header
doctl account ratelimit --format Remaining,Reset --no-header
doctl compute region list --format Slug,Available --no-header
doctl compute size list --format Slug,Memory,VCPUs,Disk,PriceMonthly --no-header
doctl compute droplet list --format ID,Name,PublicIPv4,PrivateIPv4,Region,Image,Status,Tags,Features,Volumes --no-header
doctl compute droplet list --gpus --format ID,Name,PublicIPv4,Region,Image,Status,Features --no-header
doctl compute ssh-key list --format ID,Name,FingerPrint --no-header
doctl compute snapshot list --format ID,Name,CreatedAt,Regions,ResourceId,ResourceType,MinDiskSize,Size,Tags --no-header
doctl compute image list --format ID,Name,Type,Distribution,Slug,Public,MinDisk --no-header
doctl compute image list --public --format ID,Name,Distribution,Slug,Public,MinDisk --no-header
doctl compute firewall list --format ID,Name,Status,DropletIDs,Tags,PendingChanges --no-header
doctl compute volume list --format ID,Name,Size,Region,DropletIDs,Tags --no-header
```

Managed-service reconnaissance:

```sh
doctl projects list --format ID,Name,Purpose,Environment,IsDefault --no-header
doctl apps list --format ID,Spec.Name,DefaultIngress,ActiveDeployment.ID,Updated --no-header
doctl databases list --format ID,Name,Engine,Version,Region,Status,Size,StorageMib --no-header
doctl vpcs list --format ID,Name,IPRange,Region,Default --no-header
doctl compute load-balancer list --format ID,Name,IP,IPv6,Status,Region,VPCUUID,DropletIDs,HealthCheck --no-header
doctl compute reserved-ip list --format IP,Region,DropletID,DropletName,ProjectID --no-header
doctl compute tag list --format Name,DropletCount --no-header
doctl registries list --format Name,Endpoint,Region --no-header
doctl monitoring alert list --format UUID,Type,Description,Entities,Tags,Emails,Enabled --no-header
doctl monitoring uptime list --format ID,Name,Type,Target,Regions,Enabled --no-header
doctl gradient list-regions --format Region,ServesInference,ServesBatch --no-header
doctl gradient list-models --format Id,Name,isFoundational,Version --no-header
doctl gradient agent list --format Id,Name,Region,Model-id,Project-id --no-header
doctl gradient knowledge-base list --format UUID,Name,Region,ProjectId,DatabaseId,IsPublic,LastIndexingJob --no-header
doctl dedicated-inference list --format ID,Name,Region,Status,VPCUUID,PublicEndpoint,PrivateEndpoint --no-header
doctl dedicated-inference get-sizes --format GPUSlug,PricePerHour,CPU,Memory,GPUCount,GPUVramGB,GPUModel,Regions --no-header
doctl dedicated-inference get-gpu-model-config --format ModelSlug,ModelName,IsModelGated,GPUSlugs --no-header
doctl serverless namespaces list --format Label,Region,ID,Host --no-header
doctl nfs list --region atl1 --format ID,Name,Size,Region,Status,VpcIDs --no-header
doctl nfs list --region nyc2 --format ID,Name,Size,Region,Status,VpcIDs --no-header
doctl nfs list --region ams3 --format ID,Name,Size,Region,Status,VpcIDs --no-header
```

Spaces note: local `doctl 1.155.0` exposes `doctl spaces keys`, not bucket
listing. Bucket/object inventory should use S3-compatible tooling, MCP/API, or a
later explicitly scoped script.

## Architecture Decisions For The Upcoming Droplet

- Prefer a small, boring public surface first: SSH only, explicit firewall, and
  outbound HTTPS intact for Nix downloads. Add App Platform or a private
  ingress later when operator flow is proven.
- Pick public Droplet versus Private Droplet deliberately. Private Droplets
  remove direct public connectivity, but require the VPC/NAT path to be proven
  before expecting Nix, GitHub, Spaces, or model downloads to work.
- Keep `nixos-rebuild test` before `switch`; snapshot or image candidate must
  exist before persistent mutation.
- Do not rely on Launchpad RAG Assistant as a hidden deploy primitive. If used,
  treat it as a separate Terraform-backed starter kit with its own project and
  cost review.
- Treat Knowledge Base as curated RV sidecar, not raw full memory import. Only
  upload approved docs, run digests, and public-safe memory packs.
- Prefer Agent Platform traces for AI behavior evidence; prefer local run
  digests and journald/systemd evidence for host behavior.
- Use Dedicated Inference only if model/control requirements justify dedicated
  GPUs. Serverless Inference is the default reconnaissance path.

## Mutation Gates

Before any DO mutation:

- `scripts/check.sh` and `scripts/preflight.sh` have run from
  `/Users/0xvox/Windburn`.
- `doctl account get` passes through either a safe local env token or a
  confirmed persistent context.
- Core inventory and managed-service reconnaissance have been captured or
  explicitly repair-carded.
- Target region, size, image, SSH key, firewall, VPC, snapshot, and cost posture
  are written into the run digest.
- If Computer Use will operate the remote shell, remote host identity and first
  read-only OS/Nix probes are captured before mutation.

## Next Planning Output

When auth and host are available, the preflight should produce a short deploy
card with:

- chosen region and reason;
- selected Droplet or Private Droplet shape;
- SSH key fingerprint;
- image or snapshot candidate;
- firewall and VPC posture;
- rollback object;
- optional sidecars from this capability map;
- exact first `nixos-rebuild test` command.
