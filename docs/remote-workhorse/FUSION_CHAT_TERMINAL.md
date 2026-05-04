# Fusion Chat Terminal

Generated: `2026-05-04`

## Intent

Build one Windburn-owned chat entrance for all remote lanes:

- Hermes yolo tmux lane on `hermes-nyc1`.
- NixOS workhorse foundation on `windburn-workhorse-nyc1`.
- CCR embedding/review lane.
- Local Codex control plane.
- Superconductor workspace shell.

The first slice is a zero-dependency web terminal so it can run immediately
without package installation or another provider credential step.

## Upstream Inputs

- `jcode`: `https://github.com/1jehuang/jcode`
  - Current observed upstream head: `6f15a8e0586bc30c5b551a17bc4866065095d1cb`
  - Useful ideas: multi-session harness, side panel rendering, swarm/session
    routing, low-latency terminal UX.
- Dot Matrix usage: `https://dotmatrix.zzzzshawn.cloud/getting-started/usage`
  - Registry pattern: `@dotmatrix` -> `https://dotmatrix.zzzzshawn.cloud/r/{name}.json`
  - Loader family: `dotm-square-3`, `dotm-circular-5`, `dotm-triangle-2`.
- Nous Psyche runs board: `https://psyche.network/runs`
  - Useful ideas: global run counters first, thin-line panels, capacity meter,
    status-filtered cards, and minimal operator moves.
- CommitMono pack: operator-owned local font pack path hidden
  - Embedded file: `apps/fusion-chat-terminal/assets/fonts/CommitMonoVariable.woff2`
  - License copy: `apps/fusion-chat-terminal/assets/fonts/LICENSE-CommitMono.txt`
- DASH Docs personalization/settings: `https://docs.zonicdesign.art`
  - Setup routes are maintained through
    `FUSION_CHAT_PERSONALIZATION_SETTINGS_HANDOFF.md`.

## Current Implementation

Path: `apps/fusion-chat-terminal/`

- `index.html`: accessible three-pane shell.
- `styles.css`: dot-matrix terminal treatment with Zonic-flavored dense ops UI
  and local CommitMono font loading.
- `app.js`: local route model and command parser.
- `upstream.json`: provenance and later fork contract.
- Sticky setup assistant: frontend contract for the `xAI setup lane`, including
  CommitMono readiness, correct-window links, and raw prompt polishing.
- Codex-style command reference: visible `/` slash commands, `$` skill
  instruction contracts, and MCP connection cards. These are browser-safe
  display surfaces only; the local agent runtime still owns actual tool
  execution and evidence.
- Streaming display classifier: noisy hook and thinking lines render as
  human-readable status cards. `PostToolUse:* hook error` is explicit error
  state, `Async hook ... completed` is low-risk completion noise, and model
  thinking/tool-call lines are marked as progress only, not proof. A future
  bridge can call `addMessage("stream", line)` or
  `window.FusionChatStream.addLine(line)` to reuse the same classifier.
- `bridge.mjs`: local read-only bridge that serves the app and exposes live
  repo/proof endpoints under `/api/*`.
- `scripts/xai-setup-agent.sh`: local xAI setup lane smoke gate that reads
  operator-owned credentials and writes redacted proof only.
- `preflight/XAI_SETUP_AGENT_SMOKE.md`: current xAI API proof. Latest verdict
  is `PASS` using the actual OpenClaw Windburn xAI credential; chat and models
  probes both returned HTTP `200`, with no secret values recorded.
- Livestream privacy: the browser surface is stream-safe by default. Public IPs,
  local absolute paths, SSH/tmux attach targets, operator script commands, and
  credential file paths render as spoiler or redacted labels instead of raw
  values.

Preview:

```sh
scripts/fusion-chat-preview.sh
```

Read-only bridge preview:

```sh
scripts/fusion-chat-bridge.sh
```

## Bridge Contract

The UI starts with static fallback data, then hydrates from Fusion Bridge v0
when served by `scripts/fusion-chat-bridge.sh`. The first bridge is read-only
and exposes:

```text
GET  /api/status
GET  /api/remotes
GET  /api/preflight
POST /api/setup/xai/inspect
```

The next bridge should add Hermes transcript streaming before any mutating
action. Every mutating route must stay behind an explicit operator gate. Secret
values, emails, webhook URLs, and bearer tokens must never be returned to the
browser.

The bridge also keeps stream-sensitive infrastructure details out of API
payloads. It may use raw host/path values server-side for read-only probes, but
`/api/status`, `/api/remotes`, and setup inspect responses must return
browser-safe labels.

## Current Route Model

| Route | Transport | Status Source |
| --- | --- | --- |
| `hermes` | SSH tmux `windburn-hermes-runtime:hermes-yolo` | `scripts/hermes-yolo-loop.sh` |
| `workhorse` | SSH NixOS rebuild/proof scripts | `scripts/nixos-remote-rebuild.sh` |
| `ccr` | SSH plus internal embedding route | `scripts/droplet-engagement-review.sh` |
| `codex` | Local Windburn shell | `scripts/check.sh` |
| `superconductor` | Repo anchor link | `scripts/superconductor-codex-intake.sh` |

## Next Hardening

1. Add websocket or Server-Sent Events for Hermes tmux transcript tailing.
2. Add Superconductor CLI pipeline intake once that CLI lands.
3. Add signed command envelopes for gated mutating actions.
4. Replace CSS-native dot loader with local Dot Matrix registry components once
   package installation is approved.
5. Import the useful `jcode` harness pieces intentionally instead of vendoring
   the whole upstream tree.
