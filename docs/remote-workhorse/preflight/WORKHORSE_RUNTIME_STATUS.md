# WORKHORSE_RUNTIME_STATUS

Generated: `2026-05-08T10:02:05.37288Z`

VERDICT: `PASS`

## Verdict Reasons

- all Phase 1 canary checks passed

## Evidence Checks

| Check | Required | Exists | Status | Safety | Evidence |
| --- | --- | --- | --- | --- | --- |
| Phase 1 local doctor | `true` | `true` | `PASS` | `n/a` | `docs/remote-workhorse/phase1/evidence/current/doctor.json` |
| Remote NixOS preflight | `true` | `true` | `PASS` | `n/a` | `docs/remote-workhorse/preflight/evidence/current/preflight.json` |
| Remote health evidence | `false` | `true` | `PASS` | `sanitized` | `docs/remote-workhorse/preflight/evidence/current/remote/health/current.json` |
| Remote Codex runtime evidence | `false` | `true` | `PASS` | `sanitized` | `docs/remote-workhorse/preflight/evidence/current/remote/codex-runtime/current.json` |
| Remote Hermes runtime evidence | `false` | `true` | `PASS` | `sanitized` | `docs/remote-workhorse/preflight/evidence/current/remote/hermes-runtime/current.json` |
| Remote Hermes yolo evidence | `false` | `true` | `PASS` | `sanitized` | `docs/remote-workhorse/preflight/evidence/current/remote/hermes-yolo/current.json` |
| Remote runner aggregate evidence | `false` | `true` | `PASS` | `sanitized` | `docs/remote-workhorse/preflight/evidence/current/remote/runner/current.json` |

## Boundary

- This command reads local/imported JSON evidence only.
- Missing remote runtime evidence is a `FLAG`, not proof that the remote lane is broken.
- Secret-bearing or non-redacted runtime evidence is a `BLOCK` before any public sharing.
