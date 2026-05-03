# Remote Host Proof

Generated: `2026-05-03T08:31:29Z`

Status: `BASE_HOST_SNAPSHOT_PROVED_AND_NIXOS_STAGED`

This document records the read-only proof for the first Windburn remote
workhorse candidate. It contains no DigitalOcean token value.

## Droplet

| Field | Value |
| --- | --- |
| Droplet ID | `568689911` |
| Name | `windburn-workhorse-nyc1` |
| Region | `nyc1` |
| Size | `s-4vcpu-8gb` |
| Memory | `8192 MiB` |
| vCPUs | `4` |
| Disk | `160 GiB` |
| Image | `Ubuntu 24.04 (LTS) x64` |
| VPC UUID | `60f72853-fb82-47dd-ba03-f309a9011d08` |
| Public IPv4 | `24.144.113.25` |
| Private IPv4 | `10.116.0.3` |
| Public IPv6 | `2604:a880:400:d1:0:4:5b60:a001` |
| Status | `active` |
| Tags | `nixos-candidate`, `remote-workhorse`, `windburn` |
| Features | `monitoring`, `droplet_agent`, `ipv6`, `private_networking` |

## Host Key Fingerprints

Captured with `ssh-keyscan -4 -T 10 24.144.113.25` and
`ssh-keygen -lf <temp-known-hosts>`.

| Type | Fingerprint |
| --- | --- |
| RSA | `SHA256:ruZTnOW2gisMAvR6pQzHO6ooj3MT6tgJXODE43DkJ0k` |
| ECDSA | `SHA256:pOo+X9F1CSScjBut9HkYc1BDWphM5PgISAmXtoCRPfU` |
| ED25519 | `SHA256:rSIiRQxHWwPSqisftkocqHHn9/IfFCqUHX/zu+1q/Ag` |

## Strict SSH Proof

The SSH proof used `~/.ssh/id_ed25519`, `BatchMode=yes`,
`IdentitiesOnly=yes`, a temporary `UserKnownHostsFile`, and
`StrictHostKeyChecking=yes`.

```text
whoami=root
hostname=windburn-workhorse-nyc1
os=Ubuntu 24.04.3 LTS
kernel=Linux 6.8.0-71-generic x86_64 GNU/Linux
cloud_init=status: done
root_fs=/dev/vda1       154G  2.0G  152G   2% /
memory=           7.8Gi       440Mi       6.8Gi       4.0Mi       760Mi       7.3Gi
cpu_count=4
eth0             UP             24.144.113.25/19 10.10.0.6/16 2604:a880:400:d1:0:4:5b60:a001/64 fe80::2062:92ff:fe34:6c3c/64
eth1             UP             10.116.0.3/20 fe80::b4d3:77ff:fe6a:7c11/64
nix_bin=absent
nixos_rebuild=absent
nix_root=absent
```

## Preflight

`WINDBURN_REMOTE_HOST=24.144.113.25 scripts/preflight.sh` completed with
`PASS`.

Generated evidence:

- `docs/remote-workhorse/preflight/REMOTE_NIXOS_PREFLIGHT.md`
- `docs/remote-workhorse/preflight/evidence/current/doctor.json`
- `docs/remote-workhorse/preflight/evidence/current/preflight.json`

## Snapshot Proof

The base-host snapshot was created after action-time operator confirmation.

| Field | Value |
| --- | --- |
| Action ID | `3168282573` |
| Action status | `completed` |
| Snapshot ID | `227115138` |
| Snapshot name | `windburn-workhorse-nyc1-base-20260503-0830Z` |
| Snapshot created at | `2026-05-03T08:30:44Z` |
| Action completed at | `2026-05-03T08:31:11Z` |
| Resource ID | `568689911` |
| Resource type | `droplet` |
| Region | `nyc1` |
| Min disk size | `160 GiB` |
| Snapshot size | `2.07 GiB` |

Guarded command:

```sh
scripts/digitalocean-snapshot.sh --apply --confirm-billable-snapshot
```

Post-snapshot preflight:

```text
preflight: PASS
- all Phase 1 canary checks passed
```

## Next Gate

The NixOS conversion stage has completed without reboot. The next gate is the
reboot-only lustration step:

```sh
scripts/nixos-lustrate-reboot.sh
```

Full stage proof:

- `docs/remote-workhorse/preflight/NIXOS_STAGE_PROOF.md`
