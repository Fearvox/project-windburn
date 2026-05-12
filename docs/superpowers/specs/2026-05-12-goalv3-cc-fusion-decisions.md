# goalv3-cc Fusion — Decision Log

- **Date**: 2026-05-12
- **Spec**: `2026-05-12-goalv3-cc-fusion-design.md`
- **Session**: brainstorming chat (Claude terminal, MUW + Windburn + ~/.codex exploration)

This log records 12 design decisions made during brainstorming. Each entry
includes context, what was chosen, what was rejected, and consequences. Use
this when re-evaluating choices later: don't re-litigate without new evidence.

---

## D1: Scope = narrow start (Goal V3 → CC /goal fusion only)

**Context**: Wild idea spans 4-5 subsystems (goal upgrade + memory absorption + hooks consolidation + MCP unification + agent registry sync).

**Decision**: Start with goalv3-cc skill only. Defer codex absorption to Phase 2 in a separate brainstorm + new session.

**Rationale**: Goal V3 is most pressing (CC `/goal` shipped 2026-05-11, fusion timing is now). Memory chronicle is biggest subsystem (bundling makes spec unwieldy). Hooks/MCP have 80%+ overlap (sweep, not redesign). Each absorption deserves its own design cycle.

**Rejected**: One mega-spec (Operator Stack Unification — too bloated). Decompose into 4 separate brainstorms (loses recursive-dogfood pattern where goalv3-cc itself drives codex absorption).

**Consequences**: Phase 1 = goalv3-cc skill. Phase 2 = goalv3-cc self-drives codex absorption. Two-step bootstrap pattern.

---

## D2: Implementation primitive = CC skill

**Context**: Where does goalv3-cc live in CC? Plugin command / skill / hook overlay?

**Decision**: CC skill at `~/.claude/skills/goalv3-cc/` per Perplexity skill model + gbrain RESOLVER pattern.

**Rationale**: Aligns with prior adaptive-skill-architecture work. Skill body carries contract templates + workflow + reference docs. Skill calls native `/goal` rather than re-implementing CC mechanics. Portable across projects, easy to version, easy to dogfood for Phase 2.

**Rejected**: Plugin command (buries structure in manifest, harder to evolve). Hook overlay (invisible at decision points, weaker anti-LGTM surface).

**Consequences**: Implementation = SKILL.md + scripts/ + references/ standard structure. Leverages skill description as routing trigger.

---

## D3: Skill scope = Contract + supervised dispatch (not contract-only)

**Context**: Should goalv3-cc just produce V3-shaped contract, or also orchestrate subagent dispatch?

**Decision**: Skill produces contract AND auto-dispatches gsd-style subagents via Task tool with PASS/FLAG/BLOCK verdicts. Bounded Supervisor Review Gate enforces limits. Optional v1.5: Research Vault wiring.

**Rationale**: Contract-only misses the load-bearing magic — the "self-anti-LGTM at every stage transition" IS the V3 finding. RV bundling deserves Phase 1.5 (sequencing risk).

**Rejected**: Contract-only (A) — too thin. Contract + dispatch + RV (C) — RV upgrade deserves its own pass.

**Consequences**: Skill body includes Decision Packet + dispatch logic + verdict ladder + bounded gate. ~550-line body.

---

## D4: V2 → CC primitive mapping = Task tool synchronous waves (single session A mode)

**Context**: V2 dispatches Multica issues for work units. CC has Task tool (synchronous subagent spawn) but no Multica.

**Decision**: Conductor uses `Task` tool synchronously, blocks until result, then dispatches next wave. Sequential or small batches (max 2 concurrent). State persists in `.goal/<id>/state.json`. Single CC session handles full goal lifecycle.

**Rationale**: "Use goalv3-cc to eat codex" is one big multi-stage task, can be done in single session. V2's Multica autopilot cross-goal parallel is more complexity than Phase 1 needs. ScheduleRemote cross-session adds restart resilience but is v2 evolution.

**Rejected**: B (CC ScheduleRemote cross-session cadence — defer to v2). C (Hybrid Task + ScheduleRemote — too many mechanisms for v1).

**Consequences**: A mode = in-session synchronous. Single source of truth = state.json in CWD. No cron, no daemons. Resume protocol handles interrupt cases.

---

## D5: State location = project-local `.goal/<goal-id>/` in CWD

**Context**: Where does conductor state persist? CWD project-local, global ~/.claude/, or Research Vault?

**Decision**: `.goal/<goal-id>/` in current working directory (project-local).

**Rationale**: Project-bound, git-friendly (gitignored but accessible), easy to inspect (`cat .goal/X/state.json | jq`), consistent with GOAL_V3_PUBLISH_READINESS.md pattern living inside Windburn. Avoids cross-project confusion.

**Rejected**: Global `~/.claude/goalv3-state/` (couples cross-project history but loses project context). RV note (adds RV upgrade dependency, defer to v1.5).

**Consequences**: Each project has its own `.goal/` directory. Multi-goal coexistence via `.goal/<goal-id-1>/`, `.goal/<goal-id-2>/`, etc.

---

## D6: State machine = V2 full 9 states (no simplification)

**Context**: Simplify V2's 9-state machine to 5 states for ease, or keep full?

**Decision**: V2 full 9 states preserved: `GOAL_CAPTURED → DESIGNING → DECISION_PACKET → DISPATCHING → OBSERVING → REVIEWING → (PASS|FLAG|BLOCK) → LEARNING/ARCHIVING → DONE` plus `BLOCKER_CLASSIFIED → OPERATOR_NEEDED / COOLDOWN→DESIGNING / ARCHIVED`.

**Rationale**: V2 dogfooded design earned each state. Simplification risks re-introducing failure modes V2 already learned (e.g. losing FLAG → DISPATCHING re-route distinction). "Big-as-needed beats simple-but-fragile."

**Rejected**: Simplified 5-state machine (loses cooldown semantics, FLAG/BLOCK distinction, archival pathway).

**Consequences**: Skill body includes full state machine documentation. State transitions audited in state.json `history` array.

---

## D7: Friction Tier = auto-routed by skill (operator does not manually select)

**Context**: How does skill decide fast / standard / heavy tier per goal?

**Decision**: Skill auto-classifies in DESIGNING state using inline rubric (goal text signals, scope, blast radius, operator phrasing). Operator can override via Decision Packet `tier` field.

**Rationale**: Operator: "skill should detect my workloads and route". Manual tier selection adds friction without value. Auto-classifier good enough for v1, can tune via dogfood.

**Rejected**: Operator manual selection per goal (friction). Hardcoded tier (loses adaptive value).

**Consequences**: Skill body includes Friction Tier Router rubric (3-5 criteria per tier). Override field documented in Decision Packet schema. Tier informs Self-Awareness Bootstrap (heavy only), Task spawn count, specialist chain depth.

---

## D8: Decision Packet schema = V2 14 fields + 3 CC-native fields

**Context**: Decision Packet schema design — preserve V2 fully, simplify, or extend?

**Decision**: Keep V2's 14 fields verbatim (goal_id, intent, route, owner, reviewer, constraints, evidence_expectations, non_goals, blocker_conditions, tier, dedupe_key, max_active, cooldown_minutes, verdict). Add 3 CC-native: `cc_task_descriptors`, `cc_specialist_chains`, `expected_artifacts`. Optional 4th: `cc_dispatch_mode`.

**Rationale**: V2 schema captures dogfood lessons (DAS-741/743 noise prevention). CC additions surface specialist subagent selection + artifact-based verdict detection. No V2 field is wasted in CC context.

**Rejected**: Simplified 8-field schema (loses noise prevention). Pure V2 (misses CC-specific dispatch surface).

**Consequences**: Decision Packet template in `references/decision-packet-template.md`. Operator writes packet, skill validates schema, skill enriches with CC-native fields during DESIGNING.

---

## D9: Dual dispatch primitive = Task default + `--bg` opt-in (per-packet)

**Context**: How does conductor dispatch subagents? Task tool only? Or also `claude --bg` (CC v2.1.139 agent view)?

**Decision**: Task tool default (conductor monitors synchronously). `claude --bg` opt-in via `cc_dispatch_mode: bg` field for parallel independent heavy work. `bg` triggers OPERATOR_NEEDED (conductor cannot auto-monitor bg sessions).

**Rationale**: Task tool gives conductor full automation (V2 pattern). `--bg` adds true parallel + agent view visibility for Phase 2 multi-domain work. Dual primitive lets operator choose per packet without changing architecture.

**Rejected**: Task tool only (no parallel for Phase 2). `--bg` only (loses auto-conductor for routine work).

**Consequences**: Skill body documents both primitives + trade-offs. `cc_dispatch_mode: bg` triggers operator-call condition #7. File-based evidence hand-off for `--bg` mode (`.goal/<id>/dispatch-bg-<task-id>-evidence.md`).

---

## D10: Observability = 6-layer stack (L0 agent view newly recognized)

**Context**: How does operator observe goalv3-cc progress?

**Decision**: 6-layer observability:
- L0: `claude agents` (agent view) — fleet view of CC sessions
- L1: HUD / statusline (via TaskCreate per state transition)
- L2: Transcript (skill prints status lines)
- L3: state.json (persistent machine-readable)
- L4: dispatch-log.jsonl (append-only audit)
- L5: history/ (packet snapshots)

**Rationale**: Found via operator pointing at Anthropic blog about agent view — meta-discovery that v2.1.139's agent view is the dispatch observability layer we had been missing. Critical invariant: Task tool subagents are NOT in agent view (in-process), only `--bg` spawned sessions are.

**Rejected**: 4-layer stack without agent view (loses fleet visibility for `--bg` mode).

**Consequences**: Skill body documents the in-process vs spawned distinction. Operator can mentally model "what's where" without surprise.

---

## D11: OpenChronicle for Phase 2 DP1 (prior art, don't reinvent)

**Context**: Phase 2's Chronicle absorption — design CC-side chronicle mechanism, or use existing?

**Decision**: Use OpenChronicle (v0.1.0, MIT, macOS, AX-tree-first + Markdown + SQLite, model-agnostic). Phase 2 DP1 = install + configure + MCP-wire OpenChronicle as canonical chronicle backend. Optionally migrate codex's 1195 chronicle resource files INTO OpenChronicle Markdown format.

**Rationale**: Operator pointed at https://github.com/Einsia/OpenChronicle mid-design. Anti-LGTM applied to design itself: check prior art before reinventing. OpenChronicle matches operator's local-first + inspectable + markdown-on-disk preferences. Active development, has external contributors.

**Rejected**: Build CC-side chronicle from scratch (reinvent wheel). Port codex chronicle pipeline to CC directly (codex pipeline is integrated, not standalone).

**Consequences**: Phase 2 DP1 simpler than originally planned. Owner = `voltagent-dev-exp:tooling-engineer` (integrate) instead of `feature-dev:code-architect → fullstack-developer` (design + build). Reviewer adds `codex:codex-rescue` for second opinion on integration choices.

---

## D12: Anti-LGTM verdict override = system invariant (V3 emergent pattern codified)

**Context**: What makes goalv3-cc different from V2 + CC `/goal` separately?

**Decision**: Codify the Codex V3 emergent pattern as Edge Case #4 + Invariant #1: "If subagent claims PASS but evidence_expectations not satisfied, conductor MUST override verdict to FLAG and re-dispatch." This is automatic, not operator-triggered.

**Rationale**: V2 implicitly had this via reviewer subagent. Codex GPT-5.5 emergent behavior shows the agent doing this self-anti-LGTM check at every stage transition. Operator's meta-finding: "this is what self-aware looks like in production." Codifying it converts an emergent discipline into a system guardrail.

**Rejected**: Leave override to reviewer subagent only (V2 pattern, less reliable). Operator-only override (high friction, defeats automation).

**Consequences**: Skill body has explicit instruction: "On verdict claim PASS, verify evidence_expectations satisfied. If not, override to FLAG, log 'claimed PASS evidence absent', re-dispatch." Validation gate (pre-DONE 5 checks) is the same pattern at a different scale.

---

## Decision Stability

These decisions are **stable** unless:

- New CC release fundamentally changes dispatch primitives (e.g. `Task` tool gets monitoring API, or `--bg` gets programmatic state query)
- OpenChronicle has breaking changes between v0.1.0 and v1.0.0 (affects Phase 2 DP1)
- Operator gains team-level scope (revisit D5 project-local state)
- ScheduleRemote / CronCreate gains primitives V2 autopilot 15min cadence needed (revisit D4)
- V3 emergent pattern (D12) turns out to over-trigger in dogfood (need rubric tuning, not architectural change)

Re-evaluation triggers should be logged here as D13+, with explicit reference to which decision is being superseded and what changed.

## How to read this log

Decisions are numbered in design-time order. A decision can be **superseded**
by a later decision — when that happens, mark the original with a status
header (`Status: superseded by Dn`) but keep the body intact. Never delete a
decision; the rejected options + rationale are load-bearing for future
re-evaluations.

If you arrive here trying to make a similar decision: read the matching
decision first. If new evidence supports a different choice, log D_n+1 with
explicit reference to which decision is being superseded and what changed.
