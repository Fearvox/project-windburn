# DigitalOcean Host Selection Card

Updated: 2026-05-03

Status: `READY_FOR_OPERATOR_CONFIRMATION`

This card is generated from read-only DigitalOcean inventory after
`DIGITALOCEAN_ACCESS_TOKEN` became available through local `.env.local`. It
contains no token value.

## Current Account Shape

Core gate:

- `doctl_account_status`: pass.
- Droplet/region/size/SSH key/snapshot/image/firewall/volume inventory: 11/11
  read-only probes passed.
- Managed-service reconnaissance: 19/21 probes passed.
- Advisory tool bugs: `doctl_gradient_agents` and
  `doctl_gradient_knowledge_bases` hit a `doctl 1.155.0` pagination panic; use
  API/MCP or a newer `doctl` before depending on those two inventories.

Existing Droplets:

| Name | Region | Shape | Image | Tags | Decision |
| --- | --- | --- | --- | --- | --- |
| `ccr-droplet` | `sfo3` | 4 vCPU, 8 GiB, 240 GiB | Ubuntu 24.04 | `CCR`, `DS`, `Evensong`, `Research-Vault-MCP` | Do not convert; this already carries CCR/RV work. |
| `hermes-nyc1` | `nyc1` | 2 vCPU, 4 GiB, 80 GiB | Ubuntu 24.04 | `hermes` | Do not convert; this is the existing Hermes lane and too small for the workhorse. |

Other resources:

- SSH key: `SSH-RV-MCP-EVENSONG`, fingerprint
  `bd:bf:8a:04:ac:cc:1a:c7:d2:b1:6e:d0:36:ee:9b:af`.
- Project: `first-project`.
- VPCs: `default-nyc1` and `default-sfo3`.
- Snapshots: none.
- Firewalls: none.
- Volumes: none.
- Apps, managed DBs, container registries, and serverless namespaces: none.
- Public NixOS image: none found in the public image inventory.
- Public Ubuntu base image: `ubuntu-24-04-x64` is available.

## Decision

Create a new candidate host instead of mutating an existing Droplet.

Recommended first host:

| Field | Value |
| --- | --- |
| Name | `windburn-workhorse-nyc1` |
| Region | `nyc1` |
| Size | `s-4vcpu-8gb-240gb-intel` |
| Image | `ubuntu-24-04-x64` |
| Project | `first-project` |
| SSH key | `SSH-RV-MCP-EVENSONG` fingerprint |
| Networking | public networking, IPv6, private networking in default `nyc1` VPC |
| Monitoring | DigitalOcean monitoring and droplet agent enabled |
| Tags | `windburn`, `remote-workhorse`, `nixos-candidate` |

Reasoning:

- `nyc1` keeps it near the existing Hermes lane.
- The available `s-4vcpu-8gb-240gb-intel` shape has the best disk headroom in
  the current non-GPU size inventory.
- Existing droplets remain untouched and recoverable.
- Since no NixOS image is available in the account, the first safe path is
  Ubuntu base host -> read-only SSH proof -> snapshot -> NixOS conversion
  attempt.

## Proposed Mutation Command

Do not run until the operator confirms the mutation.

```sh
set -a
source .env.local
set +a

doctl compute droplet create windburn-workhorse-nyc1 \
  --region nyc1 \
  --size s-4vcpu-8gb-240gb-intel \
  --image ubuntu-24-04-x64 \
  --ssh-keys bd:bf:8a:04:ac:cc:1a:c7:d2:b1:6e:d0:36:ee:9b:af \
  --project-id 621e2718-6f76-449b-ac63-551cbda7cab1 \
  --enable-monitoring \
  --enable-ipv6 \
  --enable-private-networking \
  --droplet-agent=true \
  --tag-names windburn,remote-workhorse,nixos-candidate \
  --wait \
  --format ID,Name,PublicIPv4,PrivateIPv4,Memory,VCPUs,Disk,Region,Image,VPCUUID,Status,Tags,Features \
  --no-header
```

## Immediate Post-Create Read-Only Proof

After creation:

```sh
doctl compute droplet list \
  --format ID,Name,PublicIPv4,PrivateIPv4,Region,Image,Status,Tags,Features \
  --no-header

ssh-keyscan -T 5 <public-ip>
ssh-keygen -F <public-ip> || true
```

Then set:

```sh
export WINDBURN_REMOTE_HOST=<public-ip>
set -a
source .env.local
set +a
scripts/preflight.sh
```

## Rollback Before NixOS Conversion

Before any NixOS conversion or filesystem mutation:

1. Prove SSH login and host identity with read-only commands.
2. Power off or snapshot only when the host is in a known state.
3. Create a base-host snapshot:

```sh
doctl compute droplet-action snapshot <droplet-id> \
  --snapshot-name windburn-workhorse-nyc1-base-YYYYMMDD-HHMM \
  --wait \
  --format ID,Status,Type,StartedAt,CompletedAt,ResourceID,Region \
  --no-header
```

## NixOS Path

There is no public NixOS image in the captured DigitalOcean image inventory.
The two viable NixOS paths are:

1. Convert the fresh Ubuntu candidate using the NixOS lustrate/infect path after
   snapshot proof.
2. Build or obtain a NixOS custom image, upload it with
   `doctl compute image create --image-url ... --region nyc1`, then create the
   Droplet from that custom image.

The current recommendation is path 1 for speed, with a snapshot gate before
conversion. Path 2 is cleaner long-term but requires a build/hosting pipeline
for the image first.

Official references:

- DigitalOcean custom images can create Droplets by setting `image` to the
  custom image ID:
  <https://docs.digitalocean.com/products/custom-images/how-to/create-droplets/>
- `doctl compute image create` imports an image URL into a region:
  <https://docs.digitalocean.com/reference/doctl/reference/compute/image/create/>
- NixOS manual notes that lustrate/nixos-infect can convert DigitalOcean
  droplets from another distribution:
  <https://nixos.org/manual/nixos/stable/index.html>
