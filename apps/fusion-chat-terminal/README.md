# Windburn Fusion Chat Terminal

Zero-dependency browser surface for a unified remote chat entrance.

## Run

```sh
scripts/fusion-chat-preview.sh
```

Then open `http://127.0.0.1:5178`.

## Current Slice

- Dot-matrix web terminal UI.
- Nous Psyche-inspired run board density: global status first, route details
  second, few operator moves.
- Local CommitMono variable font embedded from
  `/Users/0xvox/Downloads/CommitMonovoxV143`.
- Sticky setup assistant that detects CommitMono loading, links users to the
  right setup windows, and rewrites raw setup asks into bounded operator tasks.
- Remote route registry for Hermes, Windburn NixOS workhorse, CCR, local Codex,
  and Superconductor.
- Command parser for `/status`, `/route`, `/attach tmux`, `/broadcast`, and
  `/explain flags`.
- Codex-style command reference for slash commands, `$` skill instructions, and
  browser-safe MCP connection contracts.
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
