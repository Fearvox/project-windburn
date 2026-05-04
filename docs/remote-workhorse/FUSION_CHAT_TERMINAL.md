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
- CommitMono pack: `/Users/0xvox/Downloads/CommitMonovoxV143`
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
- `scripts/xai-setup-agent.sh`: local xAI setup lane smoke gate that reads
  operator-owned credentials and writes redacted proof only.
- `preflight/XAI_SETUP_AGENT_SMOKE.md`: current xAI API proof. Latest verdict
  is `PASS` using the actual OpenClaw Windburn xAI credential; chat and models
  probes both returned HTTP `200`, with no secret values recorded.

Preview:

```sh
scripts/fusion-chat-preview.sh
```

## Bridge Contract

The UI deliberately starts in local mock mode. A later bridge should expose a
small, auditable API:

```text
GET  /api/remotes
POST /api/remotes/:id/messages
POST /api/remotes/:id/commands/status
POST /api/remotes/:id/commands/attach
```

Every mutating route must stay behind an explicit operator gate. Secret values,
emails, webhook URLs, and bearer tokens must never be returned to the browser.

## Current Route Model

| Route | Transport | Status Source |
| --- | --- | --- |
| `hermes` | SSH tmux `windburn-hermes-runtime:hermes-yolo` | `scripts/hermes-yolo-loop.sh` |
| `workhorse` | SSH NixOS rebuild/proof scripts | `scripts/nixos-remote-rebuild.sh` |
| `ccr` | SSH plus internal embedding route | `scripts/droplet-engagement-review.sh` |
| `codex` | Local Windburn shell | `scripts/check.sh` |
| `superconductor` | Repo anchor link | `scripts/superconductor-codex-intake.sh` |

## Next Hardening

1. Add a tiny local bridge process with read-only status endpoints.
2. Add a websocket stream for Hermes tmux transcript tailing.
3. Add signed command envelopes for gated mutating actions.
4. Replace CSS-native dot loader with local Dot Matrix registry components once
   package installation is approved.
5. Import the useful `jcode` harness pieces intentionally instead of vendoring
   the whole upstream tree.
