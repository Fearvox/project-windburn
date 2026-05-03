# NixOS Stage Proof

Generated: `2026-05-03T09:10:20Z`

Status: `SUPERSEDED_BY_NIXOS_BOOT_PROOF`

This document records the first successful NixOS conversion stage for the
Windburn remote workhorse. The later lustrate reboot succeeded; see
`docs/remote-workhorse/preflight/NIXOS_BOOT_PROOF.md`.

## Stage Command

```sh
scripts/nixos-conversion.sh \
  --apply \
  --confirm-destructive-nixos-conversion \
  --confirm-snapshot-id 227115138
```

The command exited `0` and ended with:

```text
stage_complete=1
```

The command used pinned `nixos-infect` with:

- Commit: `40f62a680bb0e8f2f607d79abfaaecd99d59401c`
- Script SHA-256:
  `4354bd68773b41da65c0e815202c43c8549713b3ed3ff6381c71fbc0b0a840ab`
- Channel: `nixos-25.11`
- Environment: `PROVIDER=digitalocean`, `NO_REBOOT=1`,
  `NIXOS_IMPORT=./windburn-workhorse.nix`

## DigitalOcean Proof

```text
droplet_id=568689911
name=windburn-workhorse-nyc1
public_ipv4=24.144.113.25
private_ipv4=10.116.0.3
region=nyc1
image=Ubuntu 24.04 (LTS) x64
status=active
tags=nixos-candidate,remote-workhorse,windburn
features=monitoring,droplet_agent,ipv6,private_networking

snapshot_id=227115138
snapshot_name=windburn-workhorse-nyc1-base-20260503-0830Z
snapshot_resource=568689911
snapshot_region=nyc1
snapshot_min_disk=160
snapshot_size=2.07 GiB
```

## Strict SSH Proof After Stage

The proof used `~/.ssh/id_ed25519`, `BatchMode=yes`, `IdentitiesOnly=yes`, a
temporary `UserKnownHostsFile`, and `StrictHostKeyChecking=yes`.

```text
whoami=root
hostname=windburn-workhorse-nyc1
os=Ubuntu 24.04.3 LTS
kernel=Linux 6.8.0-71-generic x86_64 GNU/Linux
uptime=up 1 hour, 1 minute
boot_id=ceac26e8-da89-4b21-9aed-335063d9499d
etc_NIXOS=present
lustrate=present
system_profile=present
system_profile_target=/nix/store/ld2nxfda2l2yjnrgdq5q5nx33bb6c0yx-nixos-system-windburn-workhorse-nyc1-25.11.10031.755f5aa91337
system_nixos_rebuild=present
/etc/nixos/configuration.nix:5:    ./windburn-workhorse.nix
root_fs=/dev/vda1       154G  4.4G  150G   3% /
memory=           7.8Gi       542Mi       4.3Gi       4.0Mi       3.2Gi       7.2Gi
```

Interpretation:

- The host is still running Ubuntu, so no lustrate reboot occurred.
- `/etc/NIXOS` and `/etc/NIXOS_LUSTRATE` are present.
- The NixOS system profile exists and points at the built Windburn system.
- The staged system includes `nixos-rebuild`.
- The generated `/etc/nixos/configuration.nix` imports the project host module.
- Root disk and memory have ample headroom for the first NixOS boot.

## Next Gate

The reboot-only guard completed successfully. Historical command:

Dry-run:

```sh
scripts/nixos-lustrate-reboot.sh
```

Apply command:

```sh
scripts/nixos-lustrate-reboot.sh \
  --apply \
  --confirm-lustrate-reboot \
  --confirm-snapshot-id 227115138
```

Post-reboot proof:

- SSH returns on `24.144.113.25`.
- `/etc/os-release` reports `ID=nixos`.
- `nixos-version` succeeds.
- `sshd` is active.
- The script records whether the SSH host key stayed stable or changed.

Full proof: `docs/remote-workhorse/preflight/NIXOS_BOOT_PROOF.md`
