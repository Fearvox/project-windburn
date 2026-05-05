# Fusion Bridge v0

Generated: `2026-05-04`

## Verdict

Fusion Bridge v0 is the first non-mock connection between the browser shell and
local Windburn state. It is read-only and binds to `127.0.0.1` by default.

## Run

```sh
scripts/fusion-chat-bridge.sh
```

If the static preview already owns `5178`:

```sh
WINDBURN_FUSION_CHAT_PORT=5179 scripts/fusion-chat-bridge.sh
```

## Endpoints

| Endpoint | Method | Purpose | Mutation |
| --- | --- | --- | --- |
| `/api/status` | `GET` | repo branch/head/dirty state and bridge mode | no |
| `/api/remotes` | `GET` | live route ledger hydrated from proof files | no |
| `/api/preflight` | `GET` | current proof verdicts for the stack | no |
| `/api/superruntime` | `GET` | runner-evidence-backed Superruntime summary, with fixture fallback | no |
| `/api/setup/xai/inspect` | `POST` | runs `scripts/xai-setup-agent.sh` inspect only | no remote mutation |

The xAI endpoint never performs the confirmed API call. It only returns the
redacted local credential-shape inspection that the shell script already
prints.

## API Package

`packages/fusion-bridge-api/` packages the Superruntime read-only surface for
local Node HTTP and Cloudflare Workers. It is intentionally smaller than the
Fusion Chat bridge: only `/healthz`, `/api/status`, `/api/superruntime`, and
`/openapi.json` are exposed, and all mutation methods return `405`.

Node HTTP mode now prefers runner evidence from
`WINDBURN_RUNNER_EVIDENCE_PATH` or the default remote-workhorse evidence path.
The browser-safe response uses `source=runner-evidence`, boolean credential
presence, `runner-ready` lease status, and `codex-provider-ok` harness status.
It does not expose raw hosts, SSH targets, local paths, remote paths, commands,
or secret values. If runner evidence is absent, it falls back to the historical
fixture contract so local smoke tests still run.

Run it locally with:

```sh
scripts/fusion-bridge-api.sh
```

Verify it with:

```sh
scripts/fusion-bridge-api-smoke.sh
```

Dry-run the Cloudflare Worker bundle without deploying:

```sh
scripts/fusion-bridge-worker-dry-run.sh
```

## Review Synthesis

- GPT-5.5 review was right: the previous surface was a frontend shell plus
  local proof, not a live web chat terminal.
- Claude Code review was right: the current command and setup surface is a good
  shell, but the run ledger and setup lane need real read-only backing before
  more UI is added.
- Superconductor's stream-card additions are kept; Bridge v0 gives that UI a
  live state source without opening mutating commands.

## Next

1. Add Hermes tmux transcript tail as a stream endpoint.
2. Consume Superconductor CLI pipeline mode as another read-only intake source
   once it lands.
3. Add signed command envelopes only after the read-only flow is stable.
