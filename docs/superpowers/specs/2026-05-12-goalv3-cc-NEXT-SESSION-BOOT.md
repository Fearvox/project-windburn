# goalv3-cc Implementation — Next Session Boot Dossier

- **Date**: 2026-05-12
- **Operator**: 0xvox
- **Purpose**: This file is the FIRST thing the next CC session reads. Designed to prevent hallucination by anchoring claims to evidence files on disk. The next session's job is to invoke `superpowers:writing-plans`, then execute the plan, then dogfood via Phase 2.

---

## Read these FIRST (in order, before anything else)

1. **Spec (source of truth for design)**:
   `/Users/0xvox/Windburn/docs/superpowers/specs/2026-05-12-goalv3-cc-fusion-design.md`

2. **Decision log (why design choices were made)**:
   `/Users/0xvox/Windburn/docs/superpowers/specs/2026-05-12-goalv3-cc-fusion-decisions.md`

3. **This file (procedural anchor)**:
   `/Users/0xvox/Windburn/docs/superpowers/specs/2026-05-12-goalv3-cc-NEXT-SESSION-BOOT.md`

If any next-session claim conflicts with spec or decision log, **trust spec + decision log**. This boot file is procedural only.

---

## What this session does (sequenced)

### Phase 1: Implementation plan
1. Invoke `superpowers:writing-plans` skill (per brainstorming flow terminal state)
2. Provide spec + decision log as input
3. Output: implementation plan at `docs/superpowers/plans/2026-05-12-goalv3-cc-implementation.md`
4. Plan covers: skill scaffold creation, 4 scripts, 4 references, 12 SKILL.md body sections, 7 dogfood tests

### Phase 2: Execute the plan
5. Create `~/.claude/skills/goalv3-cc/` directory + files per plan
6. Write SKILL.md (~550 lines, 12 sections)
7. Write 4 scripts: `state-init.sh`, `dispatch.sh`, `verdict-parse.sh`, `closeout-validate.sh`
8. Write 4 references: `decision-packet-template.md`, `self-awareness-template.md`, `closeout-template.md`, `codex-emergent-pattern.md`

### Phase 3: Dogfood (Phase 1 verification — 7 success criteria)
9. Test 1: Skill loading — operator says "use goalv3-cc to ..." → skill body appears
10. Test 2: Fast tier dogfood — trivial goal (git status summary)
11. Test 3: Standard tier dogfood — 200-word commit summary
12. Test 4: Heavy tier dogfood — audit learnings dir, propose 3 prunes
13. Test 5: Anti-LGTM override case — induce false PASS, verify skill overrides to FLAG
14. Test 6: `--bg` opt-in — packet with `cc_dispatch_mode: bg`, verify OPERATOR_NEEDED + agent view guidance
15. Test 7: Resume protocol — interrupt session in OBSERVING, verify next invoke detects lost in_flight

### Phase 4: Recursive dogfood (Phase 2 = use goalv3-cc to eat codex)
16. Operator invokes goalv3-cc with goal: `absorb-codex-into-cc`
17. Skill produces 4 Decision Packets (DP1 OpenChronicle / DP2 hooks / DP3 mcp / DP4 agents)
18. Operator approves DPs (or modifies them)
19. Skill dispatches via `--bg` for parallel domain work
20. Each `--bg` session writes evidence to `.goal/absorb-codex-into-cc/dispatch-bg-<task-id>-evidence.md`
21. Skill collects evidence, applies verdicts, produces closeout
22. **Phase 1 + Phase 2 complete** = goalv3-cc operational + codex absorbed + recursive dogfood proven

---

## Evidence anchors (truth sources, paths verified 2026-05-12)

### Design source files (operator's V2 work)
- `/Users/0xvox/multica-ultimate-workbench/skills/workbench-goal-mode-v2/SKILL.md` — V2 source design (9039 bytes, May 3)
- `/Users/0xvox/multica-ultimate-workbench/autopilots/goal-conductor.md` — V2 autopilot side (100 lines)
- `/Users/0xvox/multica-ultimate-workbench/docs/self-awareness-infra-layer.md` — Bootstrap prereq (132 lines)
- `/Users/0xvox/multica-ultimate-workbench/issue-templates/goal-mode-v2.md` — V2 issue template (size unknown, exists)

### Codex emergent pattern evidence
- `/Users/0xvox/.codex/memories/MEMORY.md` — 235KB, multiple task groups including "Bounded Supervisor Review Gate v0" with concrete config (mode=create_issue, max review targets=2)
- `/Users/0xvox/.codex/config.toml` — 16KB, contains 44 `agents.gsd-*` definitions + 10+ MCP servers + `[memories]` section
- `/Users/0xvox/.codex/hooks.json` — 1937 bytes (PermissionRequest / PreToolUse / SessionStart / Stop / UserPromptSubmit)
- `/Users/0xvox/.codex/extensions/chronicle/resources/` — 1195 10-min memory summary files (~38KB directory listing)

### CC v2.1.139 capabilities (verify still current via release notes if any claim is load-bearing)
- `claude agents` command — fleet view, Research Preview, three states (waiting on input / working / done)
- `claude --bg [task]` command — background launch, isolated session
- `/goal` command — cross-turn completion condition with live overlay
- Blog: https://claude.com/blog/agent-view-in-claude-code (re-fetch if claim affects implementation)

### Phase 2 DP1 dependency
- https://github.com/Einsia/OpenChronicle — v0.1.0 alpha, macOS only, MIT, Python (uv), AX-tree-first + Markdown + SQLite
- Verify before integration: latest release, install method, MCP integration path

### Prior brainstorm artifacts (related work, do not require touching)
- `/Users/0xvox/Windburn/docs/superpowers/specs/2026-05-11-windburn-adaptive-skill-architecture-design.md` — adaptive skill arch spec (operator-paused, future goalv3-cc target)
- `/Users/0xvox/Windburn/docs/superpowers/specs/2026-05-11-windburn-adaptive-skill-architecture-decisions.md` — companion decision log

---

## What's settled (DO NOT re-litigate)

| # | Decision | Source |
|---|---|---|
| D1 | Scope = narrow (Goal V3 only, Phase 2 = absorb codex separately) | Decision log D1 |
| D2 | Implementation = CC skill (not plugin command, not hook overlay) | D2 |
| D3 | Skill scope = Contract + dispatch (not contract-only) | D3 |
| D4 | V2 → CC mapping = Task tool synchronous waves, single session A mode | D4 |
| D5 | State location = `.goal/<goal-id>/` in CWD (project-local) | D5 |
| D6 | State machine = V2 full 9 states (no simplification) | D6 |
| D7 | Friction Tier = auto-routed by skill (operator override available via packet) | D7 |
| D8 | Decision Packet = V2 14 + CC 3 fields | D8 |
| D9 | Dispatch primitive = Task default + `--bg` opt-in per packet | D9 |
| D10 | Observability = 6 layers including L0 agent view | D10 |
| D11 | Phase 2 DP1 = OpenChronicle integration (not reinvent) | D11 |
| D12 | Anti-LGTM override = system invariant (verdict-override on claimed-PASS-missing-evidence) | D12 |

All approved by operator during brainstorming. Implementation plan should encode each as concrete steps.

---

## What's open (decide during plan/build, may become blocking)

| # | Question | When it becomes blocking |
|---|---|---|
| 1 | Subagent type unavailability fallback (e.g. `feature-dev:code-architect` disabled) | If dogfood Test 4 (heavy tier) fails because primary subagent missing |
| 2 | Cooldown timer accuracy across system clock drift | If dogfood reveals false cooldown triggers within first 5min |
| 3 | Long `--bg` session exceeding context window | If Phase 2 DP1 (OpenChronicle integration) takes >context limit |
| 4 | Anti-LGTM verdict override formal behavioral test (beyond dogfood) | If dogfood Test 5 is unstable / operator wants reproducible coverage |
| 5 | OpenChronicle Linux compatibility (v0.1.0 macOS only) | Only if operator switches to Linux dev — not currently |
| 6 | goalv3-cc within agent view (Task subagents not visible) | If operator wants statusline annotation for in-flight subagents — UX polish |
| 7 | Recursive skill chain depth limit (default 2 hops, may need 3) | If heavy goal needs >2 skill hops to satisfy |

---

## Don't trust these assumptions (verify FIRST before acting)

These are claims I made during brainstorming that should be re-verified at implementation time:

1. **Agent view UX details** (re-fetch blog if any UX claim drives implementation):
   - Three states (waiting on input / working / done)
   - `/bg` in-session background toggle
   - `claude --bg [task]` syntax

2. **OpenChronicle current state** (visit repo before integration):
   - Latest release/version (was v0.1.0 alpha on 2026-05-12)
   - Install method (`install.sh` per repo)
   - MCP integration path (claim: "MCP clients work especially well today" per README)
   - macOS-only constraint still applies

3. **Subagent type availability** (check enabled plugins before relying on subagent in skill):
   - `feature-dev:code-architect` / `:code-explorer` / `:code-reviewer` / `:fullstack-developer` — verify `feature-dev` plugin enabled
   - `voltagent-*` subagents — verify which voltagent plugins enabled (some disabled per current settings.json: `voltagent-data-ai`, `voltagent-qa-sec`, `voltagent-dev-exp` were disabled on 2026-05-11 — re-check if those re-enabled before relying)
   - `codex:codex-rescue` — verify `codex` plugin enabled
   - `gsd-*` subagents — verify gstack plugin/skill chain available

4. **CC release notes for `/goal` mechanics** (verify if changed since 2.1.139):
   - Run `claude --version` to check current
   - Check release notes at GitHub releases for any v2.1.139+ changes affecting `/goal` semantics
   - If `/goal` API changed, adjust skill's invocation pattern

5. **Operator project context** (verify before assuming):
   - Current CWD (skill assumes `.goal/<goal-id>/` is in operator's chosen project, not blindly `~/Windburn/`)
   - Operator's project-local conventions (e.g. .gitignore for `.goal/`, git-tracked closeout.md vs gitignored everything)

6. **State.json schema fields** (re-verify against spec before generating in skill body):
   - `seen_dedupe_keys` may be empty array vs missing on first init
   - `cooldowns` keyed by dedupe_key, value object with `last_dispatch` + `cooldown_until`
   - `history` array append-only — verify implementation does not truncate

---

## Skip these in this session (out of scope per operator)

- **Windburn adaptive skill architecture** spec (2026-05-11) → operator wants to use goalv3-cc to drive that, AFTER Phase 1. Do not start unless operator explicitly requests during this session.
- **ScheduleRemote / CronCreate cross-session cadence** (V2 autopilot 15min/60min mode) → defer to v2.
- **RV-coupled state persistence** (state.json in Research Vault note) → defer to v1.5, only after RV upgrade independently lands.
- **Multi-goal single-session parallel** (each invocation handles single goal) → defer to v2.
- **Skill self-evolution / auto-prune dispatch-log** → defer to v2.
- **Cross-machine conductor sync** (Hermes / Pi role distribution) → out of CC scope, MUW concern. **Operator has explicitly locked the MUW autopilot lane: do not modify anything in `/Users/0xvox/multica-ultimate-workbench/autopilots/` or `/Users/0xvox/.codex/` configuration**.

---

## Procedural reminders

1. **Brainstorming skill terminal state = invoke `superpowers:writing-plans`**. Do NOT invoke `frontend-design`, `mcp-builder`, or any other implementation skill. `writing-plans` is the next step.
2. **HARD-GATE**: No implementation action until plan is written, self-reviewed, and operator-approved.
3. **Spec self-review pattern**: after writing implementation plan, do quick inline check (placeholders / consistency / scope / ambiguity), then ask operator to review.
4. **Commit pattern**: write artifacts, present for operator review with file paths, ask operator to confirm commit. **NEVER auto-commit per operator's CLAUDE.md**.
5. **Anti-LGTM as conversational discipline**: if you find yourself about to claim "PASS" or "DONE" on any phase, verify evidence file exists + content matches expectations BEFORE claiming. This is V3 codified at the meta-level (you the operator-of-this-skill applying anti-LGTM to your own work).

---

## Final invocation hint for operator (when starting next session)

Operator can say something like:

> Resume goalv3-cc implementation. Spec + decision log + boot dossier at `Windburn/docs/superpowers/specs/2026-05-12-goalv3-cc-*.md`. Invoke `superpowers:writing-plans` skill using spec as input. Then execute the plan to build the goalv3-cc skill at `~/.claude/skills/goalv3-cc/`. Then dogfood the 7 Phase 1 success criteria. Then use goalv3-cc to drive Phase 2 (absorb codex).

Or shorter:

> /superpowers:writing-plans for goalv3-cc, spec at Windburn/docs/superpowers/specs/2026-05-12-goalv3-cc-fusion-design.md, then execute + dogfood + Phase 2.

---

End of boot dossier. Spec + decision log + this file = 3-anchor evidence base for next session.
