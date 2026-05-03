# NixOS Foundation Proof

Generated: `2026-05-03T10:54:58Z`

Status: `FOUNDATION_SWITCH_REBOOT_SNAPSHOT_VERIFIED`

This document records the first higher-level Windburn foundation layer on the
remote NixOS workhorse.

## Scope

The foundation layer adds:

- guarded remote `nixos-rebuild test|switch` deployment,
- `/srv/windburn` runtime/evidence/worktree/cache directory layout,
- root-only `/srv/windburn/secrets`,
- `/etc/windburn/secrets.env.example`,
- `windburn-health` command,
- `windburn-health.service` and `windburn-health.timer`,
- persistent journald retention limits,
- operator packages: `just`, `gh`, `sops`, `age`, `nvd`, `nom`, `node`,
  `python3`, `rg`, `fd`, `jq`, `git`, and `rsync`.

The layer does not add new public ports and does not store real secrets.

## Rebuild Commands

Dry-run:

```sh
scripts/nixos-remote-rebuild.sh
```

Test activation:

```sh
scripts/nixos-remote-rebuild.sh \
  --apply \
  --confirm-remote-nixos-rebuild \
  --mode test
```

Persistent switch:

```sh
scripts/nixos-remote-rebuild.sh \
  --apply \
  --confirm-remote-nixos-rebuild \
  --mode switch
```

Remote `/etc/nixos` backups were created before each mutation:

```text
/root/windburn-nixos/backups/etc-nixos-20260503T105318Z.tar.gz
/root/windburn-nixos/backups/etc-nixos-20260503T105351Z.tar.gz
/root/windburn-nixos/backups/etc-nixos-20260503T105428Z.tar.gz
```

The first test attempt failed before activation because ShellCheck flagged
`. /etc/os-release` inside the generated `windburn-health` shell application.
The module was fixed with a targeted `SC1091` suppression, then test and switch
both passed.

## Switch Proof

```text
id=nixos
os=NixOS 25.11 (Xantusia)
hostname=windburn-workhorse-nyc1
kernel=Linux 6.12.84 x86_64 GNU/Linux
nixos_version=25.11.10031.755f5aa91337 (Xantusia)
system_state=running
failed_units=0
current_system=/nix/store/d9w4ccbvil5plxx5sqjfr1cx7p8xh5g3-nixos-system-windburn-workhorse-nyc1-25.11.10031.755f5aa91337
windburn-health.timer=enabled active
```

The switch proof wrote:

```text
/srv/windburn/evidence/health/current.json
```

with:

```json
{
  "schema_version": 1,
  "generated_at_utc": "2026-05-03T10:54:44Z",
  "hostname": "windburn-workhorse-nyc1",
  "os": "NixOS 25.11 (Xantusia)",
  "kernel": "Linux 6.12.84 x86_64 GNU/Linux",
  "system_state": "running",
  "failed_units": 0,
  "disk_root": "/dev/vda1       154G  4.6G  150G   3% /",
  "memory": "Mem:           7.8Gi       491Mi       6.9Gi       6.9Mi       684Mi       7.3Gi",
  "swap": "Swap:          3.9Gi          0B       3.9Gi"
}
```

## Boot Persistence Proof

After `nixos-rebuild switch`, the host was rebooted through DigitalOcean action
`3168422967`. SSH returned and proved that both `current_system` and
`booted_system` point at the new foundation generation:

```text
id=nixos
os=NixOS 25.11 (Xantusia)
hostname=windburn-workhorse-nyc1
kernel=Linux 6.12.84 x86_64 GNU/Linux
nixos_version=25.11.10031.755f5aa91337 (Xantusia)
system_state=running
failed_units=0
current_system=/nix/store/d9w4ccbvil5plxx5sqjfr1cx7p8xh5g3-nixos-system-windburn-workhorse-nyc1-25.11.10031.755f5aa91337
booted_system=/nix/store/d9w4ccbvil5plxx5sqjfr1cx7p8xh5g3-nixos-system-windburn-workhorse-nyc1-25.11.10031.755f5aa91337
windburn-health.timer=active
```

Post-reboot health evidence:

```json
{
  "schema_version": 1,
  "generated_at_utc": "2026-05-03T10:55:58Z",
  "hostname": "windburn-workhorse-nyc1",
  "os": "NixOS 25.11 (Xantusia)",
  "kernel": "Linux 6.12.84 x86_64 GNU/Linux",
  "system_state": "running",
  "failed_units": 0,
  "disk_root": "/dev/vda1       154G  4.6G  150G   3% /",
  "memory": "Mem:           7.8Gi       381Mi       7.5Gi       6.9Mi       138Mi       7.4Gi",
  "swap": "Swap:          3.9Gi          0B       3.9Gi"
}
```

## Runtime Layout Proof

```text
/srv/windburn                         windburn:windburn 0755
/srv/windburn/bin                     windburn:windburn 0755
/srv/windburn/cache                   windburn:windburn 0755
/srv/windburn/evidence                windburn:windburn 0755
/srv/windburn/evidence/health         windburn:windburn 0755
/srv/windburn/runs                    windburn:windburn 0755
/srv/windburn/state                   windburn:windburn 0755
/srv/windburn/tmp                     windburn:windburn 0755
/srv/windburn/worktrees               windburn:windburn 0755
/srv/windburn/secrets                 root:root         0700
```

## Snapshot Proof

Post-foundation snapshot:

```text
action_id=3168424022
status=completed
type=snapshot
started_at=2026-05-03 10:56:22 +0000 UTC
completed_at=2026-05-03 10:56:54 +0000 UTC
resource_id=568689911
region=nyc1
snapshot_id=227116767
snapshot_name=windburn-workhorse-nyc1-nixos-foundation-20260503-1056Z
snapshot_size=5.20 GiB
```

The previous clean Ubuntu base snapshot remains:

```text
snapshot_id=227115138
snapshot_name=windburn-workhorse-nyc1-base-20260503-0830Z
snapshot_size=2.07 GiB
```

## Next Gate

Next work should provision the provider/runtime layer without breaking this
foundation:

- secret injection path for OpenAI/Codex/Hermes provider credentials,
- remote clone/worktree policy under `/srv/windburn/worktrees`,
- first Hermes/Codex smoke that writes a run artifact under
  `/srv/windburn/runs`,
- DigitalOcean monitoring or uptime policies after the service shape is known.
