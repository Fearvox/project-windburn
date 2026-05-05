# Runner Foundation Proof

Generated: `2026-05-05T05:24:00Z`

Status: `RUNNER_SWITCH_VERIFIED`

This document records the first durable read-only runner evidence layer on the
remote NixOS workhorse.

## Scope

The runner layer adds:

- `windburn-runner-status` command,
- `/srv/windburn/evidence/runner/current.json`,
- `windburn-runner-status.service`,
- `windburn-runner-status.timer`,
- post-rebuild checks in `scripts/nixos-remote-rebuild.sh`,
- stream-safe readiness fields for future Fusion Bridge/Superruntime intake.

The layer does not add public ports, execute task cards, mutate remote worktrees,
or print secret values.

## Rebuild Commands

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
/root/windburn-nixos/backups/etc-nixos-20260505T052010Z.tar.gz
/root/windburn-nixos/backups/etc-nixos-20260505T052242Z.tar.gz
/root/windburn-nixos/backups/etc-nixos-20260505T052336Z.tar.gz
```

## Root Cause Captured

The first `test` activation built successfully but failed to start
`windburn-runner-status.service`.

Cause: the service used `PrivateTmp=true`, so it could not see the root tmux
socket. Under the generated shell application's strict pipe handling,
`tmux ls | wc -l` exited non-zero and failed the oneshot service.

Fix:

- tolerate absent tmux output before counting sessions,
- set `PrivateTmp=false` for this read-only evidence service so it can inspect
  the real tmux socket.

## Switch Proof

```text
system_state=running
failed_units=0
windburn-runner-status.timer=active
runner_status=PASS
runner_reason=runner_foundation_ready
tmux_session_present=true
latest_hermes_codex_smoke=PASS
current_system=/nix/store/zf5g5vhx8n50crax0js30q1im2fl8rrc-nixos-system-windburn-workhorse-nyc1-25.11.10031.755f5aa91337
```

The switch proof wrote:

```text
/srv/windburn/evidence/runner/current.json
```

with:

```json
{
  "schema_version": 1,
  "runner_id": "windburn-workhorse-runner-status-v0",
  "runner_kind": "read-only-evidence",
  "status": "PASS",
  "reason": "runner_foundation_ready",
  "system_state": "running",
  "failed_units": 0,
  "tmux": {
    "session_present": true,
    "session_count": 1
  },
  "credentials": {
    "codex_auth_present": true,
    "hermes_auth_present": true,
    "provider_env_present": false
  },
  "latest_hermes_codex_smoke": {
    "verdict": "PASS",
    "reason": "HERMES_CODEX_PROVIDER_OK"
  },
  "remote_mutation": false,
  "secret_values_recorded": false,
  "redacted_public_safe": true
}
```

`provider_env_present=false` is expected for this layer. The proven Hermes path
uses the OpenAI Codex provider auth store recorded in
`docs/remote-workhorse/preflight/HERMES_CODEX_RUNTIME_PROOF.md`.

## Next Gate

The next safe slice is to make Fusion Bridge read this runner evidence through a
redacted Superruntime source instead of relying on local fixture state.
