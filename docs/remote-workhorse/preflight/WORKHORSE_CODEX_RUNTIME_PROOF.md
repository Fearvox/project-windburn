# Workhorse Codex Runtime Proof

Generated: `2026-05-07`

## Verdict

PASS. The remote NixOS workhorse now has a boot-persistent standalone Codex CLI
runtime lane and a fixed tmux entry for operator use.

This is not a browser chat stream yet. It is the durable runtime substrate:
Codex is installed declaratively, the tmux lane is repaired by systemd, and the
runner evidence exposes only redacted, stream-safe status fields for Fusion
Bridge.

## Scope

This slice adds:

- `remote-workhorse-codex.nix`;
- pinned `nixpkgs#codex` package, currently proving `codex-cli 0.128.0`;
- `windburn-codex-yolo-ensure`;
- `windburn-codex-runtime-status`;
- `/srv/windburn/evidence/codex-runtime/current.json`;
- runner evidence fields `codex_cli` and `codex_tui`;
- Fusion Bridge `/api/superruntime` readback for Codex CLI/TUI status.

The browser/API surface does not expose raw host values, SSH targets, tmux
targets, commands, local paths, remote paths, or secret values.

## Remote Evidence

`windburn-codex-runtime-status` after NixOS `switch`:

```json
{
  "status": "PASS",
  "reason": "codex_runtime_ready",
  "codex": {
    "model": "gpt-5.5",
    "command_present": true,
    "version_probe": {
      "status": "PASS",
      "head": "codex-cli 0.128.0"
    },
    "command_redacted": true
  },
  "lane": {
    "fixed_session_present": true,
    "codex_window_present": true,
    "pane_alive": true,
    "process_count": 2,
    "command_kind": "codex-yolo",
    "command_redacted": true
  },
  "secret_values_recorded": false,
  "redacted_public_safe": true
}
```

Runner evidence after the same `switch`:

```json
{
  "status": "PASS",
  "reason": "runner_foundation_ready",
  "codex_cli": {
    "present": true,
    "status": "PASS",
    "reason": "codex_runtime_ready",
    "codex_command_present": true,
    "version_status": "PASS"
  },
  "codex_tui": {
    "present": true,
    "status": "PASS",
    "reason": "codex_runtime_ready",
    "fixed_session_present": true,
    "codex_window_present": true,
    "pane_alive": true,
    "process_count": 2,
    "command_redacted": true
  },
  "hermes_yolo": {
    "present": true,
    "status": "PASS",
    "reason": "hermes_yolo_lane_ready",
    "command_redacted": true
  },
  "secret_values_recorded": false,
  "redacted_public_safe": true
}
```

## Fusion Bridge Readback

With `WINDBURN_RUNNER_EVIDENCE_PATH` pointed at the synced runner evidence:

```json
{
  "status": 200,
  "source": "runner-evidence",
  "codex_cli": {
    "status": "PASS",
    "command_present": true,
    "version_status": "PASS",
    "command": "redacted",
    "command_redacted": true
  },
  "codex_tui": {
    "status": "PASS",
    "pane_alive": true,
    "process_count": 2,
    "operator_surface": "tmux",
    "command": "redacted",
    "command_redacted": true,
    "stream": {
      "status": "stubbed",
      "redacted": true,
      "bounded": true,
      "reason": "raw_codex_pane_content_not_exposed"
    }
  }
}
```

## Verification

Fresh commands run on `2026-05-07`:

```sh
scripts/nixos-remote-rebuild.sh --apply --confirm-remote-nixos-rebuild --mode switch
WINDBURN_RUNNER_EVIDENCE_PATH=/tmp/windburn-runner-current.json scripts/fusion-bridge-api-smoke.sh
scripts/check.sh
git diff --check
scripts/digitalocean-snapshot.sh
```

Results:

- NixOS `switch`: PASS, warning-free final run, `rebuild_complete=1`.
- Codex CLI: PASS, `codex-cli 0.128.0`.
- Codex fixed tmux lane: PASS, pane alive, command redacted.
- Runner evidence: PASS, includes `codex_cli` and `codex_tui`.
- Fusion Bridge API smoke: PASS against synced runner evidence.
- Rust tests: PASS, 8/8.
- Doctor/canary: PASS.
- DigitalOcean snapshot script: PASS in dry-run mode, no billable snapshot
  created.

## Next

The next safe slice is a read-only transcript bridge. It should expose a
bounded, redacted stream view only after the raw pane tailer can prove that it
does not leak host, command, path, token, or provider payload material.
