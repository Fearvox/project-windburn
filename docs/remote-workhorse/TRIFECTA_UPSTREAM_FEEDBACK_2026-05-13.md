# Trifecta Upstream Feedback — 2026-05-13

Source: [`TRIFECTA_DESKTOP_PROBE_2026-05-12.md`](./TRIFECTA_DESKTOP_PROBE_2026-05-12.md) — 9-probe desktop UX session against [pkyanam/trifecta](https://github.com/pkyanam/trifecta) on 2026-05-12.

Six issues distilled and reformatted as GitHub-issue-shaped reports. Each is independently filable.

---

## Issue 1 — Action icon ontology under-fits non-IDE projects

**Type:** Enhancement
**Component:** Top-bar Actions / `+ Add action` dialog
**Severity:** Minor (cosmetic + categorical)

### Summary

The Action icon selector offers 6 fixed categories — **Play / Test / Lint / Configure / Build / Debug** — which encode an IDE-centric workflow model. Several common task families have no fitting slot, forcing arbitrary fallback (typically `Play`).

### Missing slots observed

| Action family | Common in | Currently must use |
|---|---|---|
| **Format** | Rust (`cargo fmt`), JS (`prettier`), Python (`black`) | `Play` (created `fmt` Action defaulted here) |
| **Deploy** | Web / cloud / CI projects | `Play` or `Build` |
| **Docs** | Repo-heavy / library projects (`mkdocs serve`, `cargo doc`) | `Play` or `Build` |
| **Clean** | All build systems (`make clean`, `cargo clean`) | `Configure` (misleading) |
| **Migrate** | Rails / Django / Prisma / Knex | `Configure` or `Play` |
| **Generate** | Codegen / scaffolding (`prisma generate`, `protoc`) | `Build` or `Play` |

### Proposal

Either:
- (a) Extend the preset set to ~10–12 categories covering the table above, OR
- (b) Allow a custom icon / glyph per Action, with the current 6 as the recommended defaults.

Option (b) is more flexible long-term; option (a) is the lower-effort fix.

### Evidence

Probe 9 of the 2026-05-12 session, while creating a `just fmt` Action via the `+ Add action` dialog.

---

## Issue 2 — Approval tier is global; needs per-action / per-command allowlist

**Type:** Enhancement
**Component:** Footer access-tier selector (Supervised / Auto-accept edits / Full access)
**Severity:** Friction (security vs. ergonomics tradeoff)

### Summary

The access tier is set at the **session level**, applying uniformly to every tool call the agent makes. The common operator need is finer:

> "Always allow `just fmt`, `git status`, `npm test` — but keep Supervised mode for everything else."

Today the only options are:
- **Supervised** — prompts on every tool call (slow for trusted recurring commands)
- **Full access** — no prompts at all (gives up the safety net entirely)

### Proposal

Add an **allowlist tier**, or extend Supervised mode with a per-command "always allow this exact command" toggle in the approval prompt. This is the model `git`, `sudo`, and most password managers already use — confirm once, remember.

UI sketch:

```
[Approval prompt]
  Tool: Bash
  Command: just fmt
  
  [ Allow once ]  [ Allow always for this command ]  [ Deny ]
```

The "always" list would be persisted per-project and visible/editable from settings.

### Why this matters

- Operators who set `Full access` to escape Supervised friction lose visibility into all destructive operations.
- A per-command allowlist preserves the safety net for risky calls while collapsing friction on safe recurring ones.

### Evidence

Probe 1+2 + Probe 9. The session ran the entire 6-probe sequence in Full access mode after one early prompt got dismissed — exactly the failure mode this issue addresses.

---

## Issue 3 — `Shell cwd was reset to <path>` harness suffix leaks local paths

**Type:** Bug / Privacy
**Component:** Bash tool output rendering
**Severity:** Moderate (information disclosure on shared screens / remote clients)

### Summary

After every Bash call, Claude Code's harness emits a metadata footer like:

```
Shell cwd was reset to /Users/<user>/Windburn
```

This is **not** stdout from the user's command — it is harness telemetry indicating the working directory was restored. Trifecta currently appears to render this line as if it were part of the command output, embedded at the bottom of every Bash card in the UI.

### Why this matters

1. **On remote clients (phone, AirPlay, screen-share, recordings)**, every Bash card now ends with an absolute path that leaks the operator's macOS username and directory layout.
2. **Visual noise** — the footer is redundant on every single Bash card, since the cwd is almost always the same throughout a session.
3. **No semantic value to the user** — they already know which repo they're in.

### Proposal

Treat any trailing `Shell cwd was reset to <path>` line in Bash stdout as **harness metadata** and either:
- (a) Strip it entirely from the rendered card, OR
- (b) Render it as a subtle gray chip / footer separate from the command output, only when cwd actually differs from the agent's bound project root.

Option (a) is safest; option (b) preserves the (rare) signal when cwd genuinely drifts.

### Detection

The pattern is stable across Claude Code releases:

```regex
\nShell cwd was reset to .+$
```

Always at the very end of stdout, always preceded by a newline.

### Evidence

Probes 1, 2, 4, 5, 6, 9 of the 2026-05-12 session — every Bash call surfaced this footer.

---

## Issue 4 — `/` command palette doesn't narrow after a space

**Type:** Bug
**Component:** Slash-command palette
**Severity:** Minor (usability)

### Summary

Typing `/` opens the fuzzy command palette as expected. Typing `/<query>` (e.g., `/gsd`) narrows the list correctly. But typing `/<space><query>` (e.g., `/ gsd`) **leaves the full command list visible** instead of narrowing — the space is not treated as a no-op preamble.

### Reproduction

1. Click into the input box
2. Type `/`
3. Press space
4. Type any command substring (e.g., `gsd`)

**Expected:** Palette narrows as if the leading space wasn't there, OR closes (signalling space invalidates the slash).
**Observed:** Palette stays open with full list visible regardless of query characters typed after the space.

### Proposal

Either:
- (a) Trim leading whitespace in the palette's filter input — `/ gsd` behaves identically to `/gsd`
- (b) Close the palette when a space immediately follows `/` — signals "user is typing prose, not a command"

Option (a) is more forgiving; option (b) is more deterministic.

### Evidence

Probe 8 of the 2026-05-12 session.

---

## Issue 5 — Agent-vs-Action trust model is implicit; document explicitly

**Type:** Documentation
**Component:** Approval tier docs + Actions docs
**Severity:** Minor (clarity)

### Summary

Trifecta currently has two parallel ways for shell commands to execute:

1. **Agent-initiated Bash calls** — go through the access tier (Supervised / Auto-accept / Full).
2. **User-defined Actions** in the top bar — bound to keybindings and project-scoped, command pre-set by the operator.

It is **not documented** whether user-defined Actions also go through the access tier or bypass it. Both answers are defensible:

- **Bypass:** "The operator literally typed this command into the Action dialog — pre-trusted." (Matches IDE convention; matches the keybinding affordance.)
- **Gated:** "Even pre-defined commands could be dangerous if the operator's intent has changed since creation." (Matches paranoid security posture.)

### Observed behavior

In Probe 9, the user-created `fmt` Action ran `cargo fmt` via `⌘⇧F` without an approval prompt. Whether this is because:
- (a) Actions bypass the access tier entirely, or
- (b) Actions are gated but the session was in `Full access`, masking the gate,

...is **not distinguishable from agent-side observation**.

### Proposal

Add one paragraph to the Actions / Approval tier docs stating which model is in effect. If the answer is "currently bypass, may change," say so — operators making security decisions need to know.

### Evidence

Probes 1, 2, and 9 + screenshot calibration of the access-tier UI.

---

## Issue 6 — Expose a session-end Work Log audit summary

**Type:** Enhancement
**Component:** Work Log panel
**Severity:** Feature suggestion

### Summary

Trifecta's Work Log panel records structured events (tool calls, approvals, file changes) during a session. This data is rich enough to synthesize a useful end-of-session deliverable that native Claude Code lacks entirely:

> Agent ran **N** Bash calls (M unique commands), edited **F** files (+L/-D lines), requested **A** approvals (G granted / D denied), opened **P** PRs. Total wall clock: **T**. Token budget consumed: **B%**.

### Proposal

At session pause / window close / on-demand, render a one-screen "Audit Summary" view aggregating the Work Log entries. Optional: exportable as Markdown for handoff or post-mortem documentation.

### Why this matters

- **Operator review** — quickly verify "did the agent touch anything I didn't expect?"
- **Compliance trail** — for shared environments, an at-a-glance "what did the agent do this session?" is a recurring need.
- **Trust calibration** — over multiple sessions, operators learn the agent's footprint patterns. The summary surfaces that signal.

This is **structural visualization unique to Trifecta's UI position** — neither the agent nor a terminal client can synthesize this cleanly from inside.

### Evidence

Probes 4 + 9 calibration. The Work Log panel is already visible in the right sidebar; this proposal just adds an aggregation surface on top of existing data.

---

## Filing notes

- Each issue is independently filable in https://github.com/pkyanam/trifecta/issues.
- If filing as a batch, suggested title: **"Operator UX feedback — 6 issues from 2026-05-12 desktop probe session"** with each issue body as a section.
- Probe-session context document: [`TRIFECTA_DESKTOP_PROBE_2026-05-12.md`](./TRIFECTA_DESKTOP_PROBE_2026-05-12.md) — link from each issue back to it for full reproduction context.
