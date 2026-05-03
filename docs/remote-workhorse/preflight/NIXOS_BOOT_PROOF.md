# NixOS Boot Proof

Generated: `2026-05-03T09:27:15Z`

Status: `NIXOS_BOOT_VERIFIED`

This document records the reboot-only lustration of the staged Windburn
DigitalOcean workhorse into NixOS.

## Reboot Command

```sh
scripts/nixos-lustrate-reboot.sh \
  --apply \
  --confirm-lustrate-reboot \
  --confirm-snapshot-id 227115138
```

The script first reproved the staged state, then triggered only a DigitalOcean
reboot. It did not rerun `nixos-infect`.

## DigitalOcean Action Proof

```text
action_id=3168332769
status=completed
type=reboot
started_at=2026-05-03 09:26:32 +0000 UTC
completed_at=2026-05-03 09:26:33 +0000 UTC
resource_id=568689911
region=nyc1
```

DigitalOcean Droplet metadata still reports the original source image:

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
```

The live OS proof below is authoritative for the actual booted system.

## Post-Reboot SSH Proof

The proof used `~/.ssh/id_ed25519`, `BatchMode=yes`, `IdentitiesOnly=yes`, a
temporary `UserKnownHostsFile`, and `StrictHostKeyChecking=yes`.

```text
whoami=root
hostname=windburn-workhorse-nyc1
id=nixos
os=NixOS 25.11 (Xantusia)
kernel=Linux 6.12.84 x86_64 GNU/Linux
boot_id=49a44caf-f8f0-4d1c-8b31-3e964f891103
nixos_version=25.11.10031.755f5aa91337 (Xantusia)
system_profile_target=/nix/store/ld2nxfda2l2yjnrgdq5q5nx33bb6c0yx-nixos-system-windburn-workhorse-nyc1-25.11.10031.755f5aa91337
system_state=running
sshd_state=active
nix=/run/current-system/sw/bin/nix
nixos_rebuild=/run/current-system/sw/bin/nixos-rebuild
etc_NIXOS=present
lustrate=absent
/etc/nixos/configuration.nix:5:    ./windburn-workhorse.nix
root_fs=/dev/vda1       154G  4.4G  150G   3% /
memory=           7.8Gi       347Mi       7.5Gi       6.9Mi       138Mi       7.4Gi
swap=          3.9Gi          0B       3.9Gi
failed_units=0
```

Interpretation:

- The machine is now booted as NixOS 25.11.
- `systemctl is-system-running` reports `running`.
- `sshd` is active, and strict SSH proof works.
- `/etc/NIXOS_LUSTRATE` is gone, which means the lustration step completed.
- `/etc/NIXOS` remains present, marking the system as NixOS.
- The current system profile matches the staged Windburn NixOS build.
- No failed systemd units were reported.

## SSH Host Keys

Pre-reboot `ssh-keyscan` advertised RSA, ECDSA, and ED25519. The reboot guard
reported the post-reboot advertised key set as RSA and ED25519:

```text
RSA     SHA256:ruZTnOW2gisMAvR6pQzHO6ooj3MT6tgJXODE43DkJ0k
ED25519 SHA256:rSIiRQxHWwPSqisftkocqHHn9/IfFCqUHX/zu+1q/Ag
```

The NixOS host still has the same ECDSA key file on disk:

```text
ECDSA   SHA256:pOo+X9F1CSScjBut9HkYc1BDWphM5PgISAmXtoCRPfU
```

There was no fingerprint rotation for the captured host keys; the advertised
set changed during the OS transition.

## Next Gate

The remote base OS is now ready for higher-level workhorse provisioning:

- harden NixOS service modules for the actual agent stack,
- wire Hermes/Codex provider secrets through a guarded secret path,
- add monitoring, snapshot, and rollback routines,
- run the first remote Hermes/Codex smoke.

The reboot guard is idempotent after success: if run again, it detects
`remote_state=already_nixos` and exits without triggering another reboot.
