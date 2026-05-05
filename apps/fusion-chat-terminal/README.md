# Windburn Fusion Chat Terminal

Zero-dependency browser surface for a unified remote chat entrance.

## Run

```sh
scripts/fusion-chat-preview.sh
```

Then open `http://127.0.0.1:5178`.

For live read-only repo/proof state, run:

```sh
scripts/fusion-chat-bridge.sh
```

If the static preview is already using `5178`, choose another port:

```sh
WINDBURN_FUSION_CHAT_PORT=5179 scripts/fusion-chat-bridge.sh
```

## Current Slice

- Dot-matrix web terminal UI.
- Nous Psyche-inspired run board density: global status first, route details
  second, few operator moves.
- Local CommitMono variable font embedded from an operator-owned font pack.
- Sticky setup assistant that detects CommitMono loading, links users to the
  right setup windows, and rewrites raw setup asks into bounded operator tasks.
- Remote route registry for Hermes, Windburn NixOS workhorse, CCR, local Codex,
  and Superconductor.
- Command parser for `/status`, `/route`, `/attach tmux`, `/broadcast`, and
  `/explain flags`.
- Codex-style command reference for slash commands, `$` skill instructions, and
  browser-safe MCP connection contracts.
- Prompt provenance suggestions in the composer: clipboard paths, URLs,
  commands, and current-route prompts render as non-committed chips with
  visible source labels, explicit Use/Dismiss controls, and Tab-to-accept.
  Credential-like local paths are ignored, and suggestion ids never contain the
  raw clipboard value.
- Human-readable stream cards for hook errors, async hook completions, model
  thinking states, and tool-call lines. Use `/stream sample` to smoke-test the
  classifier.
- Read-only local bridge endpoints for route state, repo status, preflight
  proofs, runner-evidence-backed Superruntime state at `/api/superruntime`,
  and xAI setup inspect. The UI falls back to static stream-safe data when the
  bridge is not running.
- Runner evidence intake prefers `WINDBURN_RUNNER_EVIDENCE_PATH`, then the
  default remote-workhorse evidence path. Browser responses summarize readiness,
  tmux presence, and credential presence as redacted booleans only.
- Stream-safe privacy by default: remote hosts, local paths, attach targets,
  operator commands, and credential paths render as spoiler blocks or redacted
  labels. This protects screenshots and Discord livestreams before account
  controls exist.
- No secret loading and no remote mutation from the browser.

## Setup Assistant Lane

The `xAI setup lane` has a local smoke gate at
`scripts/xai-setup-agent.sh`. The browser still never receives secrets. The
script reads the operator-owned credential file, calls xAI only when explicitly
confirmed, and records redacted proof in
`docs/remote-workhorse/preflight/XAI_SETUP_AGENT_SMOKE.md`.

## Ownership

`upstream.json` records the `jcode` and Dot Matrix sources used to shape this
slice. The full upstream `jcode` tree is not vendored here yet; the first
Windburn-owned artifact is the web terminal control surface plus bridge
contracts.
