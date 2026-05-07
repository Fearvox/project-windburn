# Workhorse Hermes Runtime Proof

Generated: `2026-05-06T11:30:00Z`

Status: `PASS`

This document records the first durable Hermes runtime closure on the NixOS
remote workhorse. The goal was to fix the gap where runner evidence could pass
while the host still had no executable `hermes` command.

## Scope

The runtime layer adds:

- `remote-workhorse-hermes.nix`,
- pinned Hermes Agent package from `github:NousResearch/hermes-agent`,
- `uv` in the NixOS system closure,
- `windburn-hermes-runtime-status` command,
- `/srv/windburn/evidence/hermes-runtime/current.json`,
- `windburn-hermes-runtime-status.service`,
- `windburn-hermes-runtime-status.timer`,
- runner evidence gating on real `hermes` and `uv` command presence.

The layer does not open public ports, add webhook ingress, expose provider
tokens, or run mutating task cards.

## Root Cause

The upstream installer assumed an FHS-style Linux host:

```text
Code:    /usr/local/lib/hermes-agent
Command: /usr/local/bin/hermes
Data:    /root/.hermes
```

On this NixOS host, `/usr/local` did not exist and `uv` was not installed in the
system closure. The installer returned without a usable `hermes` command.

The fix is declarative NixOS packaging, not another ad-hoc installer run.

## Rebuild Proof

Both activation modes completed:

```sh
scripts/nixos-remote-rebuild.sh --apply --mode test --confirm-remote-nixos-rebuild
scripts/nixos-remote-rebuild.sh --apply --mode switch --confirm-remote-nixos-rebuild
```

The first test attempt failed safely because the status service tried to write a
temporary file under read-only `/tmp`. The service now writes temporary probe
output inside its owned evidence directory.

Final switch proof:

```text
system_state=running
failed_units=0
hermes_version=Hermes Agent v0.12.0 (2026.4.30)
python=3.12.13
openai_sdk=2.24.0
windburn-hermes-runtime-status.timer=active
windburn-runner-status.timer=active
windburn-health.timer=active
```

## Evidence

Hermes runtime evidence:

```json
{
  "schema_version": 1,
  "runner_id": "windburn-hermes-runtime-v0",
  "status": "PASS",
  "reason": "hermes_runtime_ready",
  "hermes": {
    "source": "github:NousResearch/hermes-agent",
    "rev": "6f2dab248a6cc8591af46e5deb2dc939c2b43146",
    "command_present": true,
    "version_probe": {
      "status": "PASS",
      "exit_code": 0
    }
  },
  "uv": {
    "command_present": true
  },
  "remote_mutation": false,
  "secret_values_recorded": false,
  "redacted_public_safe": true
}
```

Runner evidence now includes the runtime gate:

```json
{
  "status": "PASS",
  "reason": "runner_foundation_ready",
  "failed_units": 0,
  "hermes_runtime": {
    "present": true,
    "status": "PASS",
    "reason": "hermes_runtime_ready",
    "hermes_command_present": true,
    "uv_command_present": true
  },
  "latest_hermes_codex_smoke": {
    "run_id": "20260506T112940Z-hermes-codex-smoke",
    "verdict": "PASS",
    "reason": "HERMES_CODEX_PROVIDER_OK",
    "generated_at_utc": "2026-05-06T11:29:58Z"
  },
  "capabilities": [
    "read-only-status",
    "timer-evidence",
    "hermes-codex-smoke-readback",
    "hermes-runtime-command",
    "uv-package-manager"
  ]
}
```

## Operator Notes

`colima` and `brew` are local macOS tools and are not expected inside this NixOS
workhorse. For the workhorse, use NixOS modules plus guarded rebuilds.

To inspect the current runtime without exposing private host details:

```sh
ssh "$WINDBURN_REMOTE_USER@$WINDBURN_REMOTE_HOST" \
  'hermes --version && uv --version && windburn-runner-status'
```

## Follow-On Gate

The follow-on interactive Hermes tmux lane is now recorded in
`WORKHORSE_HERMES_YOLO_LANE_PROOF.md`:

- create or restart a fixed tmux session/window,
- run `hermes --yolo` from the system command,
- record stream-safe process/window evidence,
- keep public UI fields spoiler/redacted.
