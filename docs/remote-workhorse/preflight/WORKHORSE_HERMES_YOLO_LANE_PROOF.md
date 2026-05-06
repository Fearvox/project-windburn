# Workhorse Hermes Yolo Lane Proof

Generated: `2026-05-06T13:38:30Z`

Status: `PASS`

This document records the first durable fixed tmux lane for interactive Hermes
on the NixOS remote workhorse.

## Scope

The lane adds:

- `windburn-hermes-yolo-ensure`,
- `windburn-hermes-yolo-status`,
- `windburn-hermes-yolo-ensure.service`,
- `windburn-hermes-yolo-ensure.timer`,
- `windburn-hermes-yolo-status.service`,
- `windburn-hermes-yolo-status.timer`,
- redacted yolo lane evidence,
- runner evidence gating on the yolo lane.

The lane does not expose a public port, create a webhook, write provider
secrets, or publish raw SSH/tmux attach targets.

## Rebuild Proof

Both activation modes completed:

```sh
scripts/nixos-remote-rebuild.sh --apply --mode test --confirm-remote-nixos-rebuild
scripts/nixos-remote-rebuild.sh --apply --mode switch --confirm-remote-nixos-rebuild
```

Final switch proof:

```text
system_state=running
failed_units=0
windburn-hermes-yolo-ensure.timer=active
windburn-hermes-yolo-status.timer=active
windburn-hermes-runtime-status.timer=active
windburn-runner-status.timer=active
windburn-health.timer=active
```

## Evidence

Hermes yolo lane evidence:

```json
{
  "schema_version": 1,
  "runner_id": "windburn-hermes-yolo-lane-v0",
  "status": "PASS",
  "reason": "hermes_yolo_lane_ready",
  "tmux": {
    "present": true,
    "version": "tmux 3.6a"
  },
  "lane": {
    "fixed_session_present": true,
    "yolo_window_present": true,
    "pane_alive": true,
    "yolo_process_count": 1,
    "command_kind": "hermes-yolo",
    "command_redacted": true
  },
  "remote_mutation": false,
  "secret_values_recorded": false,
  "redacted_public_safe": true
}
```

Runner evidence now includes the yolo lane gate:

```json
{
  "status": "PASS",
  "reason": "runner_foundation_ready",
  "hermes_runtime": {
    "status": "PASS",
    "hermes_command_present": true,
    "uv_command_present": true
  },
  "hermes_yolo": {
    "status": "PASS",
    "reason": "hermes_yolo_lane_ready",
    "fixed_session_present": true,
    "yolo_window_present": true,
    "pane_alive": true,
    "yolo_process_count": 1,
    "command_redacted": true
  },
  "latest_hermes_codex_smoke": {
    "verdict": "PASS",
    "reason": "HERMES_CODEX_PROVIDER_OK"
  },
  "capabilities": [
    "read-only-status",
    "timer-evidence",
    "hermes-codex-smoke-readback",
    "hermes-runtime-command",
    "uv-package-manager",
    "hermes-yolo-tmux-lane"
  ]
}
```

## Operator Notes

The lane is self-repairing by timer. If the fixed pane exits, the ensure timer
recreates or respawns it. Public-facing surfaces should keep session, window,
transport, and command values redacted; use the boolean evidence fields for
status display.

## Next Gate

The next slice is not another manual tmux setup. The next useful gate is the
Fusion Bridge stream adapter reading this lane through a redacted transcript or
event stream.
