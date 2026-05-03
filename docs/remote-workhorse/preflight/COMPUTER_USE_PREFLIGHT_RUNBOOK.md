# Computer Use Preflight Runbook

Use this before touching the remote NixOS workhorse through Computer Use.

## Goal

Make remote configuration boring: prove target, tools, rollback path, and
read-only Nix state before changing anything.

## Local Gates

Run from `/Users/0xvox/Windburn`:

```sh
scripts/check.sh
scripts/preflight.sh
uvx code-review-graph status --repo /Users/0xvox/Windburn
```

Required local truth before remote work:

- Git worktree is clean.
- Research Vault proof is searchable.
- code-review-graph has `windburn` registered and fresh enough for the current commit.
- `doctl account get --format Status --no-header` succeeds, or cloud snapshot/firewall work is repair-carded.
- DigitalOcean read-only inventory is captured: account ratelimit, regions, sizes, droplets, GPU droplets, SSH keys, snapshots, private/public images, firewalls, and volumes.
- `WINDBURN_REMOTE_HOST` or `--remote-host` is set before launching a Computer Use mutation session.
- `ssh-keyscan -T 5 <host>` captures the host key after a remote host is selected.

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

`doctl auth init --context <name>` creates or updates a persistent local auth
context, so get explicit action-time confirmation before running it. For a
single command, `doctl --access-token <token> ...` avoids storing a context, but
the token must stay out of chat, logs, and evidence.

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
