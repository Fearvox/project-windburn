# Workhorse Herdr Cockpit Proof

Date: 2026-05-07

## Verdict

`PASS` remote NixOS switch proof.

Herdr is being added as the human cockpit layer for the remote NixOS workhorse.
It does not replace the durable `tmux` and `systemd` lanes. The contract is:

- `systemd` keeps the cockpit server alive,
- existing `tmux` lanes keep Hermes and Codex runtime durability,
- Herdr adds a socket API and human-friendly pane/workspace operations,
- runner evidence and Fusion Bridge expose only redacted status.

## Compatibility Probe

The upstream release asset is pinned:

- version: `0.5.5`
- asset: `herdr-linux-x86_64`
- hash: `sha256-DaVGmZv6hAnZzgXmc/BZHExvfWB5OCJ3d05p+aH5LQI=`

Remote temporary compatibility probe result:

```text
herdr 0.5.5
server.status=not running
```

The asset is static enough for the NixOS workhorse path; it does not require an
FHS installer or `/usr/local` writes.

Remote `nixos-rebuild test` and `nixos-rebuild switch` both completed with the
Herdr cockpit module enabled. The final switch post-probe verified:

- `herdr 0.5.5` exists in `/run/current-system/sw/bin`,
- `windburn-herdr-server.service` is active,
- the Herdr socket API reports `PASS`,
- `windburn-herdr-status` writes public-safe redacted evidence,
- `windburn-runner-status` remains `PASS` with `herdr_cockpit.status=PASS`.

## Shipped Contract

The NixOS module adds:

- `herdr` pinned package,
- `windburn-herdr-server.service`,
- `windburn-herdr-status`,
- `windburn-herdr-status.service`,
- `windburn-herdr-status.timer`,
- `/srv/windburn/evidence/herdr/current.json`.

The runner evidence gains a redacted `herdr_cockpit` section:

```json
{
  "status": "PASS",
  "reason": "herdr_cockpit_ready",
  "command_present": true,
  "server_active": true,
  "socket_present": true,
  "socket_api_status": "PASS",
  "operator_surface": "herdr",
  "attach_target_redacted": true,
  "command_redacted": true
}
```

Fusion Bridge exposes the same state at `/api/superruntime` without raw socket
paths, hostnames, SSH targets, tmux targets, or commands.

## Why This Is The Right Layer

Herdr is excellent for the operator surface: workspaces, panes, API control,
agent status, and wait primitives. `tmux` remains better as the primitive
survival layer for fixed Hermes/Codex lanes. Together they form the intended
shape: a pleasant cockpit on top of a boring runtime spine.

## Verification Commands

```sh
node --check packages/fusion-bridge-api/src/superruntime.mjs
bash -n scripts/nixos-remote-rebuild.sh
scripts/check.sh
git diff --check
scripts/nixos-remote-rebuild.sh
scripts/nixos-remote-rebuild.sh --apply --mode test --confirm-remote-nixos-rebuild
scripts/nixos-remote-rebuild.sh --apply --mode switch --confirm-remote-nixos-rebuild
```
