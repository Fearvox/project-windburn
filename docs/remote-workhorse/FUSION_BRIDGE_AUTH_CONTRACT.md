# Fusion Bridge Auth Contract

Status: `v0 contract`

This is the account boundary for the Fusion Bridge before full SaaS auth exists.
It keeps the public edge API useful without widening write access.

## Roles

| Role | Can do | Cannot do in v0 |
| --- | --- | --- |
| `viewer` | Read redacted status, read OpenAPI | Stage tasks, see raw hosts, see provider config |
| `operator` | Stage bounded tasks after authentication and explicit confirmation | Configure providers, webhooks, or auth |
| `admin` | Configure provider, webhook, and auth settings | Bypass stream safety or secret redaction |

## Route Guard

| Route | Methods | Min role | Status |
| --- | --- | --- | --- |
| `/healthz` | `GET`, `HEAD` | `viewer` | enabled |
| `/api/status` | `GET`, `HEAD` | `viewer` | enabled |
| `/api/superruntime` | `GET`, `HEAD` | `viewer` | enabled |
| `/openapi.json` | `GET`, `HEAD` | `viewer` | enabled |
| `/api/tasks/stage` | `POST` | `operator` | disabled |
| `/api/admin/*` | `GET`, `HEAD`, `POST` | `admin` | disabled |

## Implementation Notes

- The public Worker currently resolves every request as `viewer`.
- Viewer responses must remain stream-safe: no raw hosts, local paths, SSH
  targets, provider tokens, or credential paths.
- Mutating methods return `405` until signed command envelopes exist.
- Admin routes return disabled-route responses until provider and auth config
  have a real authenticated control plane.
- The code skeleton lives in
  `packages/fusion-bridge-api/src/auth-contract.mjs` and is surfaced in
  `/api/status` as `auth`.

## Next Slice

1. Add authenticated operator sessions.
2. Add a staged-task queue that stores intent, not raw secrets.
3. Add admin-only provider/webhook config with audit events.
4. Keep public viewer mode as the default for livestream and docs surfaces.
