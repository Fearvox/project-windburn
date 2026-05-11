# Windburn Adaptive Skill Architecture — Decision Log

- **Date**: 2026-05-11
- **Spec**: `2026-05-11-windburn-adaptive-skill-architecture-design.md`
- **Session**: brainstorming chat (Claude terminal), spans 2026-05-09 → 2026-05-11

This log records the design decisions made during brainstorming. Each entry
includes context, what was chosen, what was rejected, and consequences. Use
this when re-evaluating choices later: don't re-litigate without new evidence.

---

## D1: Axis prioritization (A primary, C secondary, B+D deferred)

**Context**: Methodology can adapt along 4 axes — A (per-task cost-benefit),
B (per-context risk), C (per-operator-state), D (long-horizon evolution).

**Decision**: A primary, C systematic, B+D deferred.

**Rationale**: A is most pressing because anti-LGTM tax on trivial work is the
visible daily friction. C is secondary because operator-state-aware degradation
is happening informally already (chat-mode anchor) but is not systematic. B is
partially absorbed into A (touched surface = task weight signal). D is a future
re-design trigger, not a v1 concern.

**Rejected**: All-axis simultaneous adaptation (combinatorial explosion).
Per-context risk as own dimension (collapses into A).

**Consequences**: Detection focuses on task-classification + operator-state.
Future addition of D (long-horizon) implies revisiting axis prioritization,
not retrofitting onto current architecture.

---

## D2: Shape = profile menu (re-cast as "skill menu")

**Context**: Adaptation expression can be (A) discrete tiers, (B) profile menu,
(C) compositional vector.

**Decision**: Profile menu. Then re-cast as "skill menu" per Perplexity's
agent skill model.

**Rationale**: Profiles are not monotonic-ordered (feature is not "more rigor"
than chat — different shape). Profile has narrative; vector does not.
Perplexity skill model gives directory-based primitive with frontmatter
routing, validated by Garry Tan's gbrain (34 skills in production).

**Rejected**: Discrete tiers (T0/T1/T2) — too linear, assumes single rigor
axis. Compositional vector (rigor 1-5 × evidence 1-5 × ...) — state explosion.

**Consequences**: Implementation uses skill directory pattern per Perplexity,
RESOLVER.md index per gbrain. "Profile" disappears as a separate primitive —
it is a skill.

---

## D3: Composition via `depends:` (core + overlay)

**Context**: Skill rules need a way to inherit universal invariants.

**Decision**: Core + overlay. Non-core skills declare `depends: [core]`.
Recursive auto-load.

**Rationale**: Universal invariants (anti-LGTM, redaction, layer model) must
not be silently overridable by a skill. Core + overlay makes invariants
explicit and architecturally guarded. Flat list would duplicate rules across
skills and risk drift.

**Rejected**: Flat list — duplication and drift risk. Inheritance chains
deeper than 1 level — unnecessary complexity, YAGNI.

**Consequences**: Core cannot be overridden by other skills. If a skill
"needs" to override core, that is a design bug — re-evaluate core or the
skill, not add an escape hatch.

---

## D4: Operator state lives in core (Option C)

**Context**: Where do operator-state modifiers (fresh/tired/rushed) reside?
A: per-skill parameters. B: state-as-own-skills (state-tired, state-rushed).
C: state in core.

**Decision**: C — state modifier rules live in `core/SKILL.md`.

**Rationale**: State is cross-cutting concern. Per-skill (A) duplicates rules
across N skills. State-as-skills (B) overloads the skill primitive — state is
a parameter shift, not a workflow. Core (C) keeps state in the cross-cutting
location, single source of truth.

**Rejected**: A (duplication). B (skill primitive overload — would lose the
property that skills are workflows).

**Consequences**: All state modifier rules live in one place. Skills reference
modifier names. Changes to state modifiers touch one file. Adding a new state
flavor (e.g. `caffeinated-unsupervised`) is a single edit in core.

---

## D5: Detection = semantic description matching

**Context**: How does the system identify which skill applies to a task?

**Decision**: Description-based semantic matching primary, with 3-tier
fallback (operator explicit > semantic match > default chat). Pattern signals
optional auxiliary, never primary.

**Rationale**: Per Perplexity, description IS the routing trigger — the LLM
does routing natively at the Index tier. Building pattern-match infrastructure
duplicates work LLMs do well. YAGNI applies until precision degrades.
Operator declaration as override-only preserves agency without forcing
manual classification every task ("systematic DAA" goal).

**Rejected**: Manual operator declaration per task (defeats systematic goal,
operator burden). Pattern-match-only (brittle to surface novelty, can't
handle nuance). LLM classification without operator override (loss of agency,
no escape hatch when LLM misroutes).

**Consequences**: Skill descriptions must be precise routing triggers, not
documentation. Maintenance focuses on description tuning + gotcha appending.
Eval suite (deferred to Phase 2) measures description precision/recall.

---

## D6: Enforcement phase plan (L0+L1 v1, L2 v2, L3 conditional)

**Context**: Enforcement options range from markdown discipline (L0) to
Claude Code hooks intercepting tool calls (L3).

**Decision**: v1 = L0 (markdown) + L1 (skill-internal scripts). v2 = L2
(cross-tool verification chains). v3 = L3 (hooks) ONLY if observed need.

**Rationale**: YAGNI on hook infrastructure. Most enforcement value comes
from L0+L1. Adding L2 next gives cross-tool evidence (RV MCP, gh CLI, etc.).
L3 only justified when observed failure modes demand harder gates — operator
bypassing L0/L1 in ways that cause incidents.

**Rejected**: L3 from start — premature engineering, hook maintenance
burden. L0 only — too soft for infra-mutation invariants.

**Consequences**: v1 implementation is markdown + scripts only. No hook code
to maintain. Failure observations drive v2/v3 escalation, not anticipation.

---

## D7: Default skill = chat (permissionless chat, deliberate work)

**Context**: When no skill matches, what is the fallback?

**Decision**: Default to `chat`. Work skills require explicit declaration or
strong semantic match.

**Rationale**: Inverts the current default-strict assumption (every session
assumed in-work, casual-chat exemption needed). New default: permissive chat,
escalate to work explicitly. Aligns with cost-aware swarm intuition —
default is "do not burn budget"; burning budget is a deliberate decision.

**Rejected**: Default-strict (current AGENTS.md state) — produces friction in
chat sessions, forces operator to anchor exemptions manually. Default-feature
— assumes work intent that may not be there.

**Consequences**: Operator must explicitly escalate (or strong signals must
match) to enter work mode. Chat is genuinely zero-friction. Casual-chat
exemption mechanism (currently in AGENTS.md) becomes redundant — chat is the
default, not the exception.

---

## D8: Darwin self-evolution into core, not separate skill

**Context**: Where do Darwin self-evolution rules (currently in AGENTS.md) go?
Same question for Superconductor session intake.

**Decision**: Both go into `core/SKILL.md`. Darwin as a gated section
(applies only when creator-visual-path work is active). Superconductor intake
as universal session-start anchor.

**Rationale**: Per operator (citing gbrain pattern alignment, where
always-load skills like `signal-detector` and `brain-ops` carry universal
discipline regardless of task), these rules function as universal-when-
applicable. Not workflow changes, but discipline applied when relevant signals
fire. Same pattern Garry Tan's gbrain uses.

**Rejected**: Separate `darwin-creator-visual` skill (would require
description that says "load when doing creator visual work" — overlaps with
feature/research and creates routing ambiguity). Separate
`superconductor-intake` skill (would not match the "always" semantic;
intake is session-init, not on-demand).

**Consequences**: Core SKILL.md has gated sections that activate on specific
signals (capsule files, p5/remotion paths, browser-qa invocation for Darwin;
session start for intake). Core grows but skills stay clean.

---

## Decision Stability

These decisions are **stable** unless:

- New failure mode appears that cannot be addressed by gotcha-appending
- Operator adds a 7th-9th skill that exposes catalog tension
- v1 dogfood reveals semantic-match precision < 80%
- Funding shifts substantially (re-evaluate axis D priority — D1)
- Multi-operator workflows enter scope (revisit D4, D7)
- Hook infrastructure becomes necessary (revisit D6)

Re-evaluation triggers should themselves be logged here as future decisions
(D9, D10, …) with reference to the original decision being revisited.

## How to read this log

Decisions are numbered in design-time order. A decision can be **superseded**
by a later decision — when that happens, mark the original with a status
header (`Status: superseded by Dn`) but keep the body intact. Never delete a
decision; the rejected options + rationale are load-bearing for future
re-evaluations.

If you arrive here trying to make a similar decision: read the matching
decision first. If new evidence supports a different choice, log D_n+1 with
explicit reference to which decision is being superseded and what changed.
