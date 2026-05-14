# Trifecta Desktop UX Probe — 2026-05-12

**Subject:** [pkyanam/trifecta](https://github.com/pkyanam/trifecta) — cross-platform coding agent platform (Codex / Claude / OpenCode wrapper) exposing local agents via WebSocket to native iOS / Android / desktop clients.

**Test surface:** Desktop client (alpha label visible in UI).

**Method:** 6 structured probes against an isolated `/tmp/trifecta-ux` git repo (no Windburn mutations during probes 1-6); 1 screenshot during synthesis exposed UI details not visible from the agent side.

---

## Probes & Findings

### Probe 1+2 — Tool visualization + approval granularity
- Sequence: `Read README.md` → `Edit README.md` → `Bash: cat README.md`.
- Each tool produces a distinct output shape on the agent side (line-numbered text, diff-style confirmation, raw stdout) — Trifecta has enough signal to render them differently.
- **No approval prompt fired** for the Edit or Bash call. Investigation showed this is `Full access` mode (set in client footer), not a Trifecta capability gap. Re-test under a lower tier is needed to characterize approval UI properly.

### Probe 3 — Streaming markdown payload
- Payload: fenced Python block + 4×5 table + 3-level nested list, deliberately stressing renderer.
- Screenshot evidence: Trifecta renders nested lists with precise indentation, inline `code` with subtle background, emoji, bold, mixed CJK + Latin punctuation — all clean. **Visual quality is on par with a polished editor, well above terminal.**
- Not directly verified: token-level streaming vs message-level buffering (would need to watch live).

### Probe 4 — Session lifecycle under interruption
- Ran 5 tool calls (4 Bash + 1 Read) over ~19 seconds with `sleep 2` between steps to give the user time to minimize/restore the Trifecta window.
- Side observation: mixing Bash + Read in a labeled "step N/5" sequence breaks if Trifecta tries to parse stdout for progress (Read can't echo its own step number) — implication: progress visualization should key off **tool-call events**, not text patterns inside stdout.
- Full session-survival behavior on minimize/restore: pending user report.

### Probe 5 — Git interaction
- `git diff` → `git add && git commit` → `git log` all succeeded.
- Trifecta's value-add here is rendering the unified diff — terminal-equivalent shows it as monospace text with `+`/`-` prefixes. Whether Trifecta colorizes or layouts side-by-side is a UI detail visible only on screen (not verified in this probe).

### Probe 6 — Error recovery
- `ls /nonexistent/path/12345` → exit code 1 + stderr returned cleanly, agent continued without dead-state.
- Wrapper layers commonly swallow non-zero exit codes or merge stderr/stdout silently; Trifecta did neither. **Win.**

---

## Calibration from screenshot

The user shared a screenshot mid-test which exposed three details the agent side could not observe:

1. **Right-side PLAN panel** — `TodoWrite` calls are extracted into a persistent right column with ✅ / 🔵 step states and timestamps, scoped to a collapsible group title. This is **structural visualization native Claude Code lacks entirely**. Implication: todo granularity should be coarser in Trifecta than in terminal — each state change has UI presence (attention cost), not just token cost.

2. **`Full access` mode banner in footer** — explains why probes 1+2 saw no approval prompt. Approval granularity is therefore parameterized by client mode, not absent. Tier dropdown (`Build`, `Plan`, etc.) visible but its behaviors uncharacterized.

3. **`CHANGED FILES (2) • +647/-0` block scoped to Windburn only** — Trifecta's git surface watches the **bound project repo**, blind to `/tmp/trifecta-ux` work. Consistent with single-project-rooted UI philosophy, but means any cross-directory workflow (sandbox experiments, multi-repo refactor) drops below the UI surface. This is the most product-shaping observation: **Trifecta assumes "one agent, one repo."**

### Other screenshot details worth noting

- Top bar: `+ Add action`, `Open ▼`, `Commit & push ▼` — common git actions promoted to toolbar; implies the product model is "agent and human share a git workflow," not "agent runs commands, human reads stdout."
- Input placeholder: `Ask anything, @tag files/folders, $use skills, or / for commands` — `$use skills` is a Trifecta-specific syntax distinct from native CC's `/skill`. Behavior uncharacterized.
- Footer: `Claude Opus 4.7` model selector + `Extra High · 1M` thinking budget + `Build` mode toggle + `Plan` toggle + `100` ring (token budget). **All knobs from native CC are surfaced visually, not hidden behind `/config`.**
- `Trifecta repo runtime` thread title — "runtime" framing strongly suggests Trifecta sees itself as a persistent agent process bound to a repo, not a transient chat.
- `ALPHA` label — feedback window is open.

---

## Wins (synthesized)

1. **Tool output shapes are semantically distinct** on the agent side, giving Trifecta enough signal to render Read / Edit / Bash / Grep with differentiated UI affordances.
2. **Error transparency** — non-zero exit codes and stderr survive the wrapper without being eaten.
3. **PLAN panel** — TodoWrite hoisted to dedicated persistent UI is a clear visualization win over native CC.
4. **Markdown rendering quality** — beats terminal across all tested elements.

## Gaps (synthesized)

1. **Project-rooted UI blindness** — sandbox or cross-directory work invisible to the change-files panel; `Commit & push` button can't reach it.
2. **`Shell cwd was reset` noise** — Claude Code harness prints this after every Bash call; Trifecta either shows it (UX noise + reveals local paths) or filters it (protocol-level metadata classification needed). Unclear which.
3. **No native "context cwd" affordance** — multi-step Bash sequences must chain `cd /path && cmd` or use absolute paths; Trifecta could surface "agent currently working in X" as a chip.

## Surprise

The `Shell cwd was reset to /Users/<user>/Windburn` line in every Bash output trail is harness metadata, not command output. If Trifecta surfaces it raw, every Bash card in the UI ends with this footer — and on a remote client (phone, shared screen) it leaks the local user's directory layout. Worth checking how Trifecta classifies harness-emitted stdout suffixes.

---

## Follow-up probes (pending)

- **Probe 7 (Approval UI)** — user lowers access tier; agent re-runs Read / Edit / Bash; observe approval surface.
- **Probe 8 (`$use skills` syntax)** — user types `$` / `$use` in input box; observe Trifecta menu and what arrives in agent context.
- **Probe 9 (Top-bar `Commit & push`)** — this very file is the bait; user clicks toolbar `Commit & push ▼` instead of asking agent to `git commit`; observe diff UI, commit message editor, push confirmation flow.

## Open questions for upstream

1. Is harness metadata (`Shell cwd was reset...`) filtered or surfaced raw?
2. Does the PLAN panel debounce TodoWrite changes, or re-render on every mutation?
3. What is the protocol contract for "tool started / progressing / done" events — text-pattern-derived or first-class event types?
4. How does the bound-project model handle a single thread that intentionally crosses repos (e.g. comparing two codebases)?
5. Approval tier semantics — what differs between `Build` / `Plan` / `Full access` beyond name?

---

## Addendum — Probes 7 / 8 / 9 (2026-05-13)

### Cautionary tale: user-in-the-loop is invisible to the agent

Twice during follow-up probes, the agent (Claude inside Trifecta) inferred a Trifecta capability from a tool-call outcome, then a screenshot revealed the user had quietly changed experiment conditions:

1. **Probe 7** — `cat /tmp/trifecta-ux/README.md` returned cleanly while the footer showed `Supervised` mode. Agent inferred "Trifecta parses Bash commands and only intercepts mutations." **Falsified by screenshot:** the user had manually pressed approve on every read-only tool call. Supervised mode asks for *all* commands; there is no read/write parsing on Trifecta's side.

2. **Probe 9** — `⌘⇧F` triggering `just fmt` ran with no approval prompt. Agent inferred "user-defined actions are pre-approved at definition time." **Falsified by screenshot:** the user had silently switched back to `Full access` mode for ergonomics before running the action.

**Lesson for any agent running inside a UI wrapper:** outcomes are joint outputs of `(your tool call) × (user-side configuration / approval)`. You cannot observe the second factor. Treat "tool succeeded" as compatible with multiple explanations until you've independently verified the user-controlled state. **Whenever a result looks like good news about the wrapper's capabilities, ask first whether the user could have produced the same result manually.**

### Probe 7 — Approval UI (verified)

- Tier menu in footer dropdown: **🔒 Supervised** (ask before everything) / **✏️ Auto-accept edits** (auto-approve edits, ask others) / **🔓 Full access** (zero prompts).
- The two axes — *edits* and *commands* — are cleanly orthogonalized. Useful middle tier.
- Approve / Deny both return cleanly to the agent: success on approve, `User declined tool execution` error on deny.
- Footer pill (`🔒 Supervised ▼`) is the canonical place to read current tier; user can change it at any time mid-session.
- **Unverified**: whether Supervised + Action keybinding requires approval, or whether Save-action click acts as one-time pre-approval (next-session probe).

### Probe 7 surprise — `WORK LOG (N)` event panel

A separate event-stream view (collapsed by default, expandable) renders structured log entries: `Plan updated`, `File change - <ToolName>: <args>`, `File-change approval requested`, `Approval resolved`. **TodoWrite is classified as a `File change` event** — a curious ontological choice suggesting Trifecta treats todo state as part of the mutation/audit surface, not a separate UI concern. This is a third representation layer beyond prose chat and the right-side Plan panel.

### Probe 8 — Command palette syntax

- `/` opens a fuzzy command palette populated from the user's Claude Code slash commands. **Full inheritance** — `/gsd-*`, `/open-gstack-browser`, `/benchmark-presentation-review`, all visible. Entries include description and `(user)` scope tag.
- `$` opens a separate **SKILLS** panel. Currently empty (`"No skills found. Try / to browse provider commands."`). Trifecta reserves the `$`-namespace for a future Trifecta-native skills surface, parallel to `/`-namespace inherited from Claude Code. **Namespace partition is intentional** — they do not want to fork CC's command system.
- **Multimodal**: dragging an image into the input box previews a thumbnail above the text. Image attachments are first-class.
- **Minor bug candidate**: typing `/<space><query>` (slash + space + word) appears to leave the full command list visible instead of narrowing. Worth filing.

### Probe 9 — Toolbar git surface + Add Action

`Commit & push ▼` is a **dropdown of three independent atoms**, not a composite:

- **Commit** (stage + commit)
- **Push** (push to remote)
- **Create PR** (open GitHub PR)

No one-click compound — by design, the user can pause between commit and push to review the staged result. Human-friendly, agent-unfriendly.

`+ Add action` opens a richer dialog: project-scoped, keybinding-bindable, worktree-aware user-defined shell commands:

| Field | Meaning |
|-------|---------|
| Name | Label shown in toolbar / palette |
| **Icon** | One of **6 preset categories**: Play / Test / Lint / Configure / Build / Debug |
| Keybinding | Global shortcut while Trifecta window focused |
| Command | Shell command string |
| Run automatically on worktree creation | Toggle — fires per new worktree |

The 6-icon set encodes **Trifecta's IDE ontology**: actions are assumed to be Run / Test / Lint / Config / Build / Debug flavored. Missing slots: **Format**, **Generate**, **Migrate**, **Deploy**, **Docs**, **Clean** — categories common in Rust / Python / docs-heavy projects but unrepresented. The `fmt` action we created defaulted to the `Play` icon for lack of a Format slot.

**Verified live**: created Action `fmt` (command `just fmt`, keybinding `⌘⇧F`, worktree-auto OFF). The button registered in the top bar as `▶ fmt ▼` (the chevron implies a hidden per-action sub-menu for run/edit/delete, unverified). Pressing `⌘⇧F` ran `just fmt` → `cargo fmt`. **Output rendered in a separate pseudo-terminal panel below the main chat** with shell-prompt-style header (`Windburn ⎇ main `) — a third presentation layer alongside main prose, right-side Plan panel, and Work log.

### Final architecture picture

Trifecta is most accurately described as:

```
Agent (Claude / Codex / OpenCode)
  + WebSocket transport
  + Worktree orchestration (git worktree = first-class isolation unit)
  + Per-project Actions (custom shell commands, 6-icon ontology, keybindable)
  + Approval tier gating (Supervised / Auto-accept edits / Full access)
  + Git workflow primitives (Commit / Push / Create PR atoms in toolbar)
  + Native multi-platform clients (iOS / Android / desktop)
  + Plan panel (TodoWrite hoisted to persistent right column)
  + Work log (structured event audit panel)
  + Pseudo-terminal panel (Action output isolation, terminal-prompt formatted)
  + Slash-command compatibility (full inheritance of CC user commands)
  + Reserved $-namespace for future Trifecta skills marketplace
```

**Not "phone-side Claude Code."** A workspace-orchestration platform organized around the git worktree as the unit of agent work, exposing the same agent across native multi-platform clients.

### Updated open questions for upstream

1. Add a **Format** category (and possibly **Deploy**, **Docs**, **Clean**) to the Action icon set — the current 6-bucket IDE ontology under-fits many projects.
2. Make Approval tier per-action / per-command-class addressable — right now mode is global; common need is "always allow `just fmt`" without going Full access globally.
3. Filter `Shell cwd was reset to ...` harness-metadata suffixes from rendered Bash output (privacy + noise).
4. Document the agent-vs-Action trust model explicitly — agent calls navigate Supervised mode; do user-defined Actions also? Either answer is reasonable but should be in the docs.
5. Investigate `/` fuzzy filter behavior after a space — appears not to narrow.
6. Consider exposing an "audit summary" derived from the Work Log — TodoWrite-as-File-change suggests Trifecta could synthesize "agent did X mutations across Y files, asked Z approvals" per session as a deliverable.
