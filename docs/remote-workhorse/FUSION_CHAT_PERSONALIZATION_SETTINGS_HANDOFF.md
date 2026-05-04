# Fusion Chat Personalization Settings Handoff

Status: draft handoff for future Workbench swarm maintenance.
Local consumer: `apps/fusion-chat-terminal/app.js` setup assistant.

## Primary Sources

- `https://docs.zonicdesign.art/pages/getting-started.html`
- `https://docs.zonicdesign.art/pages/guides/agent-pipeline.html`
- `https://docs.zonicdesign.art/pages/reference/config.html`
- `https://commitmono.com/`

## Contract

Treat `docs.zonicdesign.art` as public operator guidance only. Do not infer,
mirror, or store secrets, private runtime bindings, bearer tokens, emails,
webhook URLs, or live deployment state.

Only mirror non-secret personalization and settings metadata needed by Fusion
Chat Terminal.

## Maintained Fields

Track:

- setup topic id
- public docs URL
- user-facing label
- expected config category
- whether the field is local-only, public-doc-derived, or operator-owned
- verification command or manual proof

Initial topics:

| Topic | Route | Ownership |
| --- | --- | --- |
| `dash` | `https://docs.zonicdesign.art/pages/getting-started.html` | public-doc-derived |
| `agentPipeline` | `https://docs.zonicdesign.art/pages/guides/agent-pipeline.html` | public-doc-derived |
| `configuration` | `https://docs.zonicdesign.art/pages/reference/config.html` | public-doc-derived |
| `font` | `https://commitmono.com/` | public prerequisite |

## Update Workflow

1. Verify the current `docs.zonicdesign.art` URLs are reachable.
2. Compare public docs headings and config names against `setupWindows` in
   `apps/fusion-chat-terminal/app.js`.
3. Update only labels, routes, and help text that are public and non-secret.
4. Keep mutation and remote-action wording behind explicit operator gates.
5. Run `scripts/fusion-chat-preview.sh`, inspect the setup assistant, then run
   `scripts/check.sh` and `git diff --check`.

## Setup Agent Lane

The current `xAI setup lane` has a local smoke gate at
`scripts/xai-setup-agent.sh`. It should help users finish dull prerequisite work
by:

- detecting missing local pieces such as fonts or docs access
- opening the correct public setup window
- rewriting vague setup asks into bounded operator prompts
- returning `PASS`, `FLAG`, or `BLOCK`

The bridge must preserve the current rule: browser surfaces receive no secrets
and perform no remote mutation.

Credential candidates are operator-owned and must stay out of git:

- `/Users/0xvox/.openclaw/credentials/xai-windburn_actual.rtf`
- `/Users/0xvox/Windburn/_local-cred/xai-windburn_local.rtf`
- `/Users/0xvox/.openclaw/credentials/xai-windburn.rtf`

Run:

```sh
scripts/xai-setup-agent.sh
scripts/xai-setup-agent.sh --call --confirm-xai-setup-agent --out docs/remote-workhorse/preflight/XAI_SETUP_AGENT_SMOKE.md
```

Latest observed API state:

- `scripts/xai-setup-agent.sh` inspect: `PASS`
- canonical credential selected:
  `/Users/0xvox/.openclaw/credentials/xai-windburn_actual.rtf`
- API smoke: `PASS`, chat endpoint HTTP `200`, models endpoint HTTP `200`
- previous wrong-team candidates reproduced HTTP `403` and are no longer
  canonical
- secret values recorded in repo: `false`

## Current Repo Facts

Verified on `2026-05-04` from
`/Users/0xvox/Windburn/.worktrees/fusion-chat-terminal`:

- branch: `codex/fusion-chat-terminal`
- `origin`: missing
- Superconductor binding for this worktree: missing
- canonical parent repo: `/Users/0xvox/Windburn`

Before publish or merge, re-run:

```sh
scripts/superconductor-codex-intake.sh
git remote -v
git status --short --branch
```
