# Windburn Fusion Bridge API

Read-only API package for the Windburn Superruntime bridge.

It is designed to run in two places:

- local Node HTTP, for Fusion Chat and operator smoke tests;
- Cloudflare Workers, for the public edge API shell.

The package intentionally exposes only stream-safe data. It does not accept
provider webhooks yet, does not dispatch runtime work, and does not mutate
Superconductor.

Auth contract v0 is role-shaped but not SaaS-shaped: public requests are
`viewer`, future authenticated staging is `operator`, and provider/webhook/auth
configuration is `admin`. See
`docs/remote-workhorse/FUSION_BRIDGE_AUTH_CONTRACT.md`.

## Endpoints

- `GET /healthz`
- `GET /api/status`
- `GET /api/superruntime`
- `GET /openapi.json`

## Local Run

```sh
scripts/fusion-bridge-api.sh
```

Node mode prefers runner evidence over the legacy Superruntime fixture. By
default it checks the remote-workhorse evidence path; for local smoke tests or
synced artifacts, point it at a redacted runner JSON file:

```sh
WINDBURN_RUNNER_EVIDENCE_PATH=/path/to/current.json scripts/fusion-bridge-api.sh
```

The `/api/superruntime` response keeps the source as `runner-evidence` and
exposes only browser-safe summary fields: runner status, tmux presence, boolean
credential presence, lease readiness, provider-smoke state, and the redacted
`hermes_yolo`, `codex_cli`, and `codex_tui` status surfaces. These surfaces
expose PASS/FLAG/BLOCK or UNAVAILABLE, command presence, pane liveness, process
count, timer state when present, an operator surface label, and
`command: "redacted"` only.

## Smoke

```sh
scripts/fusion-bridge-api-smoke.sh
```

Optional Cloudflare Worker bundle dry-run:

```sh
scripts/fusion-bridge-worker-dry-run.sh
```

## Cloudflare Worker

```sh
cp packages/fusion-bridge-api/wrangler.toml.example packages/fusion-bridge-api/wrangler.toml
cd packages/fusion-bridge-api
wrangler deploy
```

Cloudflare MCP is expected to be configured locally as `cloudflare-api` with
the remote endpoint `https://mcp.cloudflare.com/mcp`. The package itself does
not require Cloudflare credentials for local smoke tests.

Deployment remains read-only until provider webhook verification and signed
runtime envelopes are implemented.
