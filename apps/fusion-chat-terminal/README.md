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
- Remote route registry for Hermes, Windburn NixOS workhorse, CCR, local Codex,
  and Superconductor.
- Command parser for `/status`, `/route`, `/attach tmux`, `/broadcast`, and
  `/explain flags`.
- No secret loading and no remote mutation from the browser.

## Ownership

`upstream.json` records the `jcode` and Dot Matrix sources used to shape this
slice. The full upstream `jcode` tree is not vendored here yet; the first
Windburn-owned artifact is the web terminal control surface plus bridge
contracts.
