# Computer Use Preflight Runbook

Use this before touching the remote NixOS workhorse through Computer Use.

## Goal

Make remote configuration boring: prove target, tools, rollback path, and
read-only Nix state before changing anything.

## Local Gates

Run from `/Users/0xvox/Windburn`:

```sh
scripts/check.sh
WINDBURN_REMOTE_HOST=24.144.113.25 scripts/preflight.sh
scripts/remote-host-proof.sh
scripts/digitalocean-snapshot.sh
uvx code-review-graph status --repo /Users/0xvox/Windburn
```

Required local truth before remote work:

- Git worktree is clean.
- Research Vault proof is searchable.
- code-review-graph has `windburn` registered and fresh enough for the current commit.
- `doctl account get --format Status --no-header` succeeds, or cloud snapshot/firewall work is repair-carded.
- DigitalOcean read-only inventory is captured: account ratelimit, regions, sizes, droplets, GPU droplets, SSH keys, snapshots, private/public images, firewalls, and volumes.
- DigitalOcean managed-service reconnaissance is captured or repair-carded:
  projects, apps, databases, VPCs, load balancers, reserved IPs, tags,
  registries, monitoring alerts, uptime checks, Gradient/Inference, serverless,
  and candidate Network File Storage regions.
- `docs/remote-workhorse/preflight/DIGITALOCEAN_CAPABILITY_MAP.md` has been
  read before selecting sidecars beyond the Droplet itself.
- `WINDBURN_REMOTE_HOST` or `--remote-host` is set before launching a Computer Use mutation session.
- `ssh-keyscan -T 5 <host>` captures the host key after a remote host is selected.
- `scripts/remote-host-proof.sh` passes against the selected host with strict
  host-key checking and read-only OS/Nix probes.
- Snapshot `227115138`
  (`windburn-workhorse-nyc1-base-20260503-0830Z`) exists before NixOS
  conversion.

## DigitalOcean Read-Only Cloud Checks

These are allowed preflight checks. They do not create, update, or delete cloud
objects.

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

## DigitalOcean Managed-Service Reconnaissance

These checks map available sidecars without mutating cloud state.

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

These probes are advisory. Core Droplet inventory remains the hard cloud gate
before host selection or mutation. Spaces bucket/object inventory is out of this
`doctl` gate because the local CLI only exposes Spaces access-key commands.

`doctl auth init --context <name>` creates or updates a persistent local auth
context, so get explicit action-time confirmation before running it. For a
single command, `doctl --access-token <token> ...` avoids storing a context, but
the token must stay out of chat, logs, and evidence.

`runtimectl preflight` also supports one-shot read-only auth from local shell
environment without storing a context. It checks the first non-empty value from:

```sh
DIGITALOCEAN_ACCESS_TOKEN
DIGITALOCEAN_TOKEN
DOCTL_ACCESS_TOKEN
```

When one is set, evidence records `doctl --access-token $VARIABLE_NAME ...`, not
the token value. Never paste the token into chat or commit it into repo files.

## Computer Use Read-Only First Commands

First remote session commands must only observe:

```sh
hostnamectl
cat /etc/os-release
uname -a
uptime
df -h
free -h || vm_stat
id
systemctl --failed || true
nix --version
nix flake metadata --json 2>&1 | sed -n '1,80p'
```

Capture command, exit status, stdout/stderr, and timestamp into the run digest.

## Snapshot Gate

Default snapshot command is dry-run:

```sh
scripts/digitalocean-snapshot.sh
```

Creating a snapshot requires action-time operator confirmation, then both
mutation flags:

```sh
scripts/digitalocean-snapshot.sh --apply --confirm-billable-snapshot
```

This uses Droplet `568689911` by default and names the snapshot
`windburn-workhorse-nyc1-base-<UTC timestamp>` unless `--name` or
`WINDBURN_SNAPSHOT_NAME` is provided.

Current base snapshot:

- Snapshot ID: `227115138`
- Name: `windburn-workhorse-nyc1-base-20260503-0830Z`
- Resource: Droplet `568689911`
- Created: `2026-05-03T08:30:44Z`

## Mutation Gate

Do not run persistent mutation until all are true:

- Remote host identity is proven.
- Remote Nix is callable.
- Target repo/ref is proven on the remote or deployment source is explicit.
- Cloud snapshot or rollback plan is proven.
- `nixos-rebuild test` command is prepared before any `switch`.
- Operator can find the latest run digest and backout path.
- Host-key drift has a written plan: rebuilds can change host keys; only clean
  stale `known_hosts` entries deliberately after capturing the new key.
- Firewall posture is known: SSH and outbound HTTPS for Nix downloads remain
  allowed before attaching or editing a cloud firewall.
- Snapshot/image/volume candidates are identified before persistent changes;
  preflight never deletes snapshot candidates.

## Stop Conditions

Return `BLOCK` instead of continuing if:

- remote host is ambiguous;
- credentials are missing or stale;
- cloud read auth fails and snapshot proof is required;
- NixOS identity cannot be proven;
- the working repo is dirty for unrelated reasons;
- any command would overwrite secrets, shell profiles, or broad filesystem roots without a written repair card.
