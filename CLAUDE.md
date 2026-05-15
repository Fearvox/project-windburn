# CLAUDE.md — Windburn agent grounding

This file is loaded automatically by Claude Code (and similar harnesses) when a session opens in the Windburn repo. It is the working contract for any AI agent acting inside this codebase. Read it as the first source of truth, not the last.

## Project identity (one paragraph)

Windburn is a **memory-native agent substrate**. It is not a new base model; it is a cognitive cache layer above the model-serving layer that turns observation, tool feedback, failures, and source-truth evidence into durable future-self cognition. The canonical design intent lives in MUW (Multica Ultimate Workbench) at `docs/windburn-cognitive-cache-direction.md`, dated 2026-05-03. This repository is the build-state; MUW is the orchestration layer that depends on this substrate.

The shape of the loop:

```text
observe reality → update belief → choose action → verify delta → preserve learning
```

If you find yourself optimizing for "task complete under reward proxy," you are in the wrong loop. The Windburn loop preserves a stable world model across failures.

## Cognitive cache mental model

Seven cache slots. When you touch this repo, you are working at, near, or below one of them. Knowing which one orients design choices.

| Slot | Role | Current status (2026-05-15) |
|---|---|---|
| **source** | Research Vault, repo docs, source-of-truth files | ✅ shipped (proposal layer) |
| **episodic** | What happened, in order | ✅ shipped (proposal layer) |
| **perception** | Grounded observations from tools and humans | ✅ shipped (`scripts/windburn-side-lane-perception-bus.mjs`) |
| **failure** | Actions attempted, observed deltas, avoid/retry rules | ✅ shipped (failure hook doc + distribution skill) |
| **procedural** | Reusable skills, repo routes, tool patterns | ✅ shipped (`goalv3-cc` skill production-ready) |
| **belief** | Hypotheses with evidence and confidence | ⚠️ skeleton (`windburn-source-truth-review` skill scaffold) |
| **working** | Current session focus + task stack | ❌ gap (no formal substrate yet) |

Full cross-source sync record: [`docs/research/2026-05-14-muw-windburn-cognitive-cache-sync.md`](docs/research/2026-05-14-muw-windburn-cognitive-cache-sync.md). Update this table when status changes.

## Workbench discipline

Borrowed from MUW (`SYNTHESIS.md`, "Closeout Integrity"). All status-changing closeout in this repo follows the **5-field block**:

```text
CHANGED:
VERIFIED:
REMAINING:
PRS / LINKS:
VERDICT: PASS | FLAG | BLOCK
```

`REMAINING:` is mandatory even when `(none)`. `VERDICT:` is sacred evidence language: do not rewrite, upgrade, or collapse it into prose (no "PASS, moving to Done"). Status and verdict are independent — status describes lifecycle position; verdict describes residual risk.

PR / commit / comment references must identify whether they `contains` the implementation, served as a `dogfood-platform`, were `discovered-via` the work, or are a `cross-issue-side-effect`.

### Public logging rules

- Keep operational lessons and architecture decisions.
- Exclude live IDs, local paths, private device names, raw payloads, screenshots.
- Record verification shape, not private evidence payloads.
- Private command transcripts → ignored local files.
- Large temporary artifacts → temp directories or private storage.

## Anti-LGTM invariant (V3, asymmetric)

This is system-level, not optional.

- ✅ A conductor / reviewer **may** override a sub-agent's `PASS` to `FLAG` when evidence is missing, empty, or subagent self-qualifies the verdict.
- ❌ A conductor / reviewer **may never** override a sub-agent's `FLAG` to `PASS`. That is LGTM by definition.

Operator-triggered revisions with verification evidence may transition `FLAG → PASS`, but they must be logged as `verdict_source: operator-resolved`, never as `conductor-override`. Audit trails preserve the original `FLAG` record append-only.

The procedural cache that embodies this rule is the `goalv3-cc` skill (filesystem-only at `~/.claude/skills/goalv3-cc/`). See `references/codex-emergent-pattern.md` in that skill for the V3 finding origin.

## Eight captured lessons (load-bearing — read before non-trivial work)

These came out of the goalv3-cc rollout and its own delivery PR pipeline. Each is the result of a real failure caught in-flight. Distilled from [`docs/superpowers/plans/2026-05-12-goalv3-cc-PLAN-CLOSEOUT.md`](docs/superpowers/plans/2026-05-12-goalv3-cc-PLAN-CLOSEOUT.md).

1. **Plan is a design contract, not an implementation contract.** Operators iterate on interfaces during build; that iteration is a feature, not a bug. Re-read plans for intent, not for prescribed syntax.

2. **V3 anti-LGTM applies to plans too.** A plan that prescribes synthetic dogfood is itself a hedge against real-world validation. If a recursive bootstrap goal is available, use it — stronger evidence than any unit test.

3. **Divergence ≠ failure.** When build diverges from plan but Phase 1 dogfood passes 7/7, the right move is "close out divergence as intentional," not "rebuild to match plan."

4. **Sequencing matters.** Build → real-work dogfood → close-out divergence. NOT plan → unit tests → real-work. The latter wastes one cycle on a layer that gets superseded anyway.

5. **PR-scope blind spot.** Self-stat of the last commit ≠ PR diff. Anti-LGTM self-check must compare PR head against PR base, not commit against parent. Run `gh pr view <N> --json files,additions` before claiming "PR ready to merge".

6. **Local-vs-origin ref blind spot.** `git log` defaults to HEAD (local). Anti-LGTM checks involving remote state must use `git rev-parse origin/<branch>` for the real remote tip. Local refs lie about remote state.

7. **Spec-and-implementation co-landing must self-audit.** When spec and implementation co-land in one PR, the spec applies retroactively to the implementation in the same PR. PR introducing a new lint / metric / threshold / BLOCK gate adds a self-check: "Do the implementation files in this same PR pass the rule I just introduced?" If no, sanitize before push.

8. **Sanitization pattern.** For single-file surgical rewrite across N commits: `git rebase origin/main --exec '<sed-or-tool>; git diff --quiet || git commit -a --amend --no-edit'`. Tag pre-sanitize state as `<branch>-pre-sanitize-YYYYMMDD` for audit safety net before pushing.

## Operator-locked lanes (do NOT touch)

Even if a goal or task description routes near these paths, refuse the route and emit `OPERATOR_NEEDED` with the reason.

- `~/.codex/` — operator's separate Codex runtime tree, frozen by operator directive
- `~/multica-ultimate-workbench/autopilots/` — MUW autopilots, separate lifecycle
- `~/dash-verse/`, `~/.dashpersona/`, `~/workspace/dash-shatter-vault/` — separate projects per operator directive

When in doubt: the only paths an agent should freely write inside this session are inside the current repo's checkout (or a worktree of it under `.claude/worktrees/`), plus the per-goal state at `.goal/<goal-id>/` (gitignored).

## Dry-Run Gate

Any operation that mutates external state requires preview-then-confirm:

- Sending messages, editing shared docs, modifying calendars, updating DBs, deploying, `rm`/`drop`/overwriting tracked files outside the current diff
- Use `--dry-run` if the underlying tool supports it; otherwise describe the projected outcome in conversation and wait for explicit confirmation
- Never combine discovery and mutation in a single tool call without an explicit go-ahead

This supersedes any per-section "deploy" or "push" convention. Dry-Run Gate is the canonical rule.

## CLI-first

Every new capability — feature, skill, tool integration — must be a standalone CLI command before any wrapper layer (MCP, REST, SDK). CLI contract:

- `--help` with examples
- `--format json` for structured output where downstream parsing is plausible
- All params as flags or stable positional args — zero interactive prompts
- Composable: `command --flag value | jq` works

If it can't be invoked from a script without human attention, it isn't ready for an agent.

## Environment tiers (default lowest)

| Tier | When to choose | How | Never |
|------|----------------|-----|-------|
| 1 | File ops, code, builds, data, APIs | Headless (subprocess, Docker, SSH) | computer-use, screen interaction |
| 2 | Web scraping, forms, deploy dashboards | Headless browser (Playwright `headless: true`) | Desktop session |
| 3 | Native GUI app with NO CLI/API alternative | computer-use, target window only | System UI (Dock, menu bar, system dialogs, shutdown) |

Before reaching for Tier 3, search for a CLI/API alternative first. Known GUI-only exception: Logic Pro.

## Public-surface safety rules

Per `docs/goals/2026-05-12-side-lane-goal-metrics-v0.md` (dimension 6, `public_surface_safety`):

- Absolute home directory paths in `docs/*.md` and `*.html`: **BLOCK**
- Provider credential-shaped strings (`sk-...`, `ghp_...`, `sk-ant-...`, `Bearer ...`, `AKIA...`): **BLOCK**
- Local queue filenames, socket paths, hook paths in public surface: **FLAG**
- Public host/port combinations: **BLOCK**

`scripts/` is operator-only surface and may contain local paths. Top-level `*.md`, `docs/`, and `*.html` are public surfaces and are scanned against these rules.

Before any `git push origin main`, run:

```sh
git diff origin/main..main | grep -c "/Users/"   # expect: 0
```

## Recommended workflow

### Starting a Superconductor / fresh session

```sh
scripts/superconductor-codex-intake.sh
```

This proves whether the canonical Windburn repo is attached through the expected binding without copying raw operator-local paths into shared docs.

### Non-trivial work → use a worktree

```sh
git worktree add .claude/worktrees/<task-name> -b worktree-<task-name>
```

Or invoke the EnterWorktree harness tool. Worktrees isolate the user's main checkout from agent edits and allow clean abandonment. ExitWorktree with `action: keep` preserves work for review; `remove` discards.

### Goal-mode work (multi-stage autonomous)

Use the `goalv3-cc` skill. Heavy-tier goals trigger Self-Awareness Bootstrap before producing a Decision Packet. Per-goal state at `.goal/<goal-id>/` (gitignored). The skill enforces the anti-LGTM invariant at every state transition.

### Append-only history

State files (`state.json`, `dispatch-log.jsonl`) are append-only. History fields are append-only. Closeout artifacts (`closeout.md`, `PLAN-CLOSEOUT.md`) are the artifact summary and may be overwritten on revision, but the log entries that fed them are not. Backup tags (`<branch>-pre-<reason>-YYYYMMDD`) for any history-rewriting operation (rebase / sanitize / amend).

## Relationship to MUW

- **MUW** (`~/superconductor/projects/multica-ultimate-workbench-main`) is the orchestration / agent runtime layer. Coordinates Codex / Claude Code / Hermes agents. Holds the canonical design direction for this repo.
- **Windburn** (this repo) is the cognitive cache substrate MUW envisions. Build-state lives here.
- **One-sided edits across projects.** Do not edit MUW from inside a Windburn session, and vice versa. Cross-link through committed docs instead. If a build-time discovery contradicts MUW direction, write a closeout entry under `docs/research/` and cross-link it from MUW separately.

## Documentation index (frequently-needed paths)

- [`README.md`](README.md) — public project entry point
- [`docs/research/2026-05-14-muw-windburn-cognitive-cache-sync.md`](docs/research/2026-05-14-muw-windburn-cognitive-cache-sync.md) — 7-cache slot status
- [`docs/superpowers/plans/2026-05-12-goalv3-cc-PLAN-CLOSEOUT.md`](docs/superpowers/plans/2026-05-12-goalv3-cc-PLAN-CLOSEOUT.md) — full text of the 8 lessons
- [`docs/goals/2026-05-12-side-lane-goal-metrics-v0.md`](docs/goals/2026-05-12-side-lane-goal-metrics-v0.md) — public-surface safety scheme
- [`docs/protocols/2026-05-12-codex-side-lane-perception-bus-v0.md`](docs/protocols/2026-05-12-codex-side-lane-perception-bus-v0.md) — perception bus protocol
- [`hermes-distributions/fearvox-windburn/`](hermes-distributions/fearvox-windburn/) — distribution package (3 skills + manifests)
- [`docs/remote-workhorse/`](docs/remote-workhorse/) — substrate / runtime layer evidence

## What to do when stuck

1. Re-read this file.
2. Check `.goal/<active-goal>/state.json` if a goal-mode session is in-flight.
3. Run the Self-Awareness Bootstrap section of the `goalv3-cc` skill (heavy-tier prerequisite — 11-field schema that anchors all claims to verified facts).
4. If still stuck after the above: emit `OPERATOR_NEEDED` with a clean 5-field block (`CHANGED:` what was tried, `VERIFIED:` what holds, `REMAINING:` the question, `PRS / LINKS:` what was touched, `VERDICT: BLOCK`).

Do not invent answers. Do not silently widen scope. Do not skip the Dry-Run Gate. Do not push without anti-LGTM check.
