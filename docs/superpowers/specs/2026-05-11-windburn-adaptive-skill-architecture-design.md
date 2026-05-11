# Windburn Adaptive Skill Architecture — Design

- **Date**: 2026-05-11
- **Author**: 0xvox + Claude (brainstorming session, Windburn terminal)
- **Status**: Design — awaiting operator review
- **Related**: `AGENTS.md`, `docs/codex-desktop-communication-profile.md`, `docs/memory-anchor-reports/2026-05-09-unreasonable-effectiveness-of-html.html`

## Context

Windburn's current operator contract (`AGENTS.md`) is **single-form**: one tone,
one verification list, one redaction default, one closeout discipline. This
works because the operator (0xvox) is a single individual operating under
uniform high-rigor constraints — no PI, no lab QA, no slack budget for
hallucinated work. The methodology was forced into existence by scarcity.

But the constraint shape has visible failure modes:

1. **Anti-LGTM tax on trivial work** — 5-minute boilerplate tasks pay the full
   evidence pipeline cost.
2. **Pressure-driven gate skipping** — when operator is tired/rushed, gates get
   bypassed silently because there's no graceful degradation path.
3. **Casual chat drift** — chat ↔ work boundary is fuzzy; gates engage when not
   needed (or fail to engage when needed).
4. **Onboarding tax limits collaboration surface** — second operator must
   absorb entire grammar before contributing.
5. **Long-horizon brittleness** — if funding shifts or agent capability jumps,
   single-form grammar becomes either over- or under-engineered.

The methodology needs to **adapt to context** without operator manually
re-anchoring each session, while preserving the invariants (anti-LGTM,
redaction default, layered closeout) that make it work.

## Goals

**Primary axis** (per discussion):

- Per-task cost-benefit adaptation: trivial tasks get light gates; critical
  tasks get full pipeline.
- Systematic detection-and-adjust (DAA): operator does not manually declare
  context each time.

**Secondary axis**:

- Per-operator-state modifiers: when operator is tired/rushed/fresh, grammar
  compensates.

**Invariants** (NEVER adapted):

- Anti-LGTM (no fake PASS, no claimed evidence without artifact)
- Public-surface redaction default
- Layer 0/1/2/3 closeout model existence (which layers apply varies; the model
  itself does not)
- Worktree-based isolation for slice work

## Non-Goals (this design)

- Replacing `AGENTS.md` overnight. AGENTS.md becomes a thin pointer + invariants
  summary; skills carry the body.
- Auto-detecting operator state via biometric or behavioral inference. Deferred
  to Phase 2.
- Building Claude Code hook infrastructure. Deferred to Phase 3, only if
  observed need.
- Multi-operator team workflows. Current scope is single-operator.
- Eval suite for skill-loading precision. Deferred to Phase 2.

## Architecture

### Pattern: skill directories per Perplexity + RESOLVER index per gbrain

The architectural primitive is **skill** (directory), following Perplexity's
agent skill design[^1] and Garry Tan's gbrain `RESOLVER.md` routing pattern[^2].

```
.windburn/skills/
├── RESOLVER.md                    # gbrain-style routing index
├── core/                          # always-load (invariants)
│   ├── SKILL.md
│   ├── references/
│   │   ├── proof-rules.md
│   │   ├── public-surface.md
│   │   └── layer-closeout.md
│   └── scripts/
│       └── check.sh               # universal verification
├── chat/                          # default operating mode
│   └── SKILL.md
├── feature/                       # standard work
│   ├── SKILL.md
│   └── scripts/run-checks.sh
├── infra-mutation/                # high-stakes
│   ├── SKILL.md
│   └── scripts/preflight.sh
├── research/                      # exploratory
│   └── SKILL.md
└── verification-loop/             # meta: anti-LGTM evidence work
    └── SKILL.md
```

[^1]: <https://research.perplexity.ai/articles/designing-refining-and-maintaining-agent-skills-at-perplexity>
[^2]: <https://github.com/garrytan/gbrain> — see `skills/RESOLVER.md`

### Composition: core + overlay via `depends:`

Non-core skills declare `depends: [core]` in frontmatter. Loading a skill
recursively pulls its dependencies (gbrain pattern). Core invariants always
load first; specific skill rules layer on top.

Core cannot be overridden by other skills. If a skill needs to relax a core
rule, that is a design bug — not a feature. The override mechanism is reserved
for transition rules (see "Transition Rules"), not for invariant relaxation.

### Three-tier loading (per Perplexity)

| Tier  | Content                                          | Budget               | When                |
| ----- | ------------------------------------------------ | -------------------- | ------------------- |
| Index | RESOLVER.md + each skill's `name + description`  | ~600 tokens (6 skills) | Every session, always |
| Load  | Activated skill's full SKILL.md body             | ~5k tokens each      | When skill activated |
| Files | scripts/, references/                            | Unbounded            | When agent reads them |

### Anti-articulation-tax property

Skills are **append-mostly**. Description and active gates rarely change once
stable. New observed failures become entries in the skill's `## Gotchas`
section. We do not re-articulate the contract; we append the boundary cases.

Per Perplexity guidance: "If you're changing the description after your Skill
has been merged, you are off track."

## Initial Skill Catalog

Six skills. Descriptions are ≤50 words and start with "Load when…" per
Perplexity convention. Body sections expand operator-facing behavior.

| Skill             | Mode        | Description (frontmatter, ≤50 words)                                                                                                                            |
| ----------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `core`            | always-load | Universal invariants. Not directly activated — always loaded as dependency of every other skill. Carries anti-LGTM, redaction default, transition rules, state modifiers, layer model.                |
| `chat`            | default     | Load when operator is brainstorming, exploring methodology, or explicitly indicating no concrete action is wanted yet.                                          |
| `feature`         | on-demand   | Load when operator is building or modifying a feature within an existing module — refactors, bug fixes, feature additions that do not touch infra or schema. |
| `infra-mutation`  | on-demand   | Load when operator is deploying, mutating remote NixOS, changing schema, or any prod-touching action. Locked until layers 0-3 close.                            |
| `research`        | on-demand   | Load when operator is exploring frontier work without commitment to ship — reading papers, drafting RV notes, building one-off experiments.                   |
| `verification-loop` | on-demand | Load when operator is producing anti-LGTM evidence work itself — RV MCP dogfood, proof refresh, canary, verification of verification.                         |

## SKILL.md Template

### Frontmatter (YAML)

```yaml
---
name: <matches directory name>
description: <≤50 words, operator-intent, starts with "Load when…">
depends: [<parent skill names, usually [core]>]
metadata:
  version: <semver>
  closeout_layers: [<which layer numbers apply, e.g. [0,1,2,3] or [0]>]
---
```

### Body sections

```markdown
## When to activate
- Positive example: "<intent phrase 1>"
- Positive example: "<intent phrase 2>"

NOT this skill if: <boundary cases — escalate or downshift accordingly>

## Active gates
- Verification: <which scripts run at closeout>
- Evidence: <artifact types required>
- Tone: <direct | conservative | exploratory | casual>
- Worktree: <required | optional | n/a>
- Redaction: <full | partial | n/a — full is default>
- Dual-agent check: <true | false>
- Commit cadence: <atomic | exploratory>

## Closeout layers
- Layer 0 (PR): <required | optional | n/a>
- Layer 1 (Conductor): <required | optional | n/a>
- Layer 2 (Linear): <required | optional | n/a>
- Layer 3 (Dashpit): <required | optional | n/a>

## Refuses to do (negative space)
- <action that operator must escalate to a different skill>
- <action that violates this skill's discipline>

## Gotchas (append-mostly)
- <observed failure 1>
- <observed failure 2>
```

The body sections are stable structure. Skill evolution happens via:

1. Append to `## Gotchas` (most common)
2. Adjust `## Refuses to do` boundary (occasional)
3. Tighten frontmatter description (rare — only if routing precision degrades)

## Detection

### Primary: semantic description matching

Every session loads the Index tier (RESOLVER.md + each skill's name +
description). When operator starts a task, the agent reads descriptions and
routes by best-match. Agent **announces choice with reasoning**; operator may
correct.

This is per Perplexity's model: description IS the routing trigger.

### Fallback ladder

```
1. Operator explicit:    "switch to infra-mutation skill" / "we're in chat mode"
                          → load that skill, override semantic match
2. Semantic match:        agent picks best description match
                          → if low confidence, asks operator to confirm
3. Default:               ambiguous or no clear match → chat
                          → "permissionless chat, deliberate work" pattern
```

### Pattern signals (optional auxiliary)

Cheap signals that bump confidence but do not replace semantic matching:

- `.worktrees/*` open → bias toward `feature` or `infra-mutation`
- Current branch == `main` + write operations → bias toward `infra-mutation`
- File path starts with `docs/memory-anchor-reports/` or
  `docs/superpowers/specs/` → bias toward `research`

Pattern signals only fire if description match is ambiguous. They never override
semantic matching alone — they nudge.

### Why no full pattern-match infrastructure

Per Perplexity, description IS the routing trigger. The LLM does routing
natively. Building pattern-match scripts duplicates work LLMs already do well.
YAGNI applies until description-match precision drops below acceptable
threshold (no current evidence it does).

## Operator State Modifiers

**Decision (Option C from discussion)**: State modifiers live in
`core/SKILL.md`, not as separate skills.

**Rationale**: State is cross-cutting concern; should live in cross-cutting
(core) location. State as separate skills (Option B) would overload the skill
primitive — state is a parameter shift, not a workflow. State as per-skill
parameters (Option A) duplicates rules across skills.

### State catalog (in `core/SKILL.md`)

```yaml
operator_state_modifiers:
  fresh:
    # no overrides — baseline gates apply
  tired:
    dual_agent_check: true             # bump on
    redaction_level: bump_up_one_tier  # extra caution
    closeout_layers: required_all      # do not let layers drift
  rushed:
    commit_cadence: atomic             # forced atomic, no batching
    anti_lgtm_gates: non_skippable     # hard enforce
    verification_scripts: full_list    # no skipping checks
```

### Declaration mechanism (v1)

Operator declares state at session start or mid-session via anchor in
conversation:

```
operator: "state: fresh"
operator: "state: tired now"
operator: "state: rushed, infra-mutation only"
```

Anchor is written to `.windburn/state/current-session.md` (transient,
gitignored). Agent reads at session start; honors current declared state for
the duration.

### Phase 2: optional auto-detection

If v1 manual-declare proves insufficient, add suggestion-only inference:

- Time of day (late-night → tired bias)
- Session length (>3 hours continuous → tired bias)
- Retry count / error frequency (high → tired or rushed bias)
- Multi-context-switch frequency (high → rushed bias)

Auto-detection is **suggestion only** — operator override always wins.
Auto-detection ships only when v1 evidence shows manual declaration breaks down.

## Transition Rules (in core)

```
chat → feature/research:        free, explicit declaration ok
chat → infra-mutation:           requires worktree clean + explicit declaration
feature → infra-mutation:        requires uncommitted-work check pass
infra-mutation → anything:       BLOCKED until layers 0-3 closed
                                 (override = explicit anchor + reason)
anything → chat:                 requires git status clean
                                 OR explicit "stash work" anchor
research → anything:             free (research is permissive but dead-end —
                                 must declare new skill before doing work)
```

Transition rules are invariants in `core/SKILL.md`. Individual skills cannot
override transition discipline.

### Operator override mechanism

If operator must transition against rules (e.g. drop infra-mutation mid-deploy
for legitimate reason), operator declares explicit override + reason:

```
operator: "override: infra-mutation → chat. reason: false start, no mutation occurred"
```

Override is logged to `.windburn/state/transitions.md` (append-only,
gitignored — local audit trail). Pattern: Anti-LGTM applied to discipline drift
itself — override happens, but it leaves a trace.

## Enforcement Ladder

| Layer | Mechanism                  | Example                                                |
| ----- | -------------------------- | ------------------------------------------------------ |
| L0    | Markdown discipline        | Operator + agent read SKILL.md, follow rules. Current AGENTS.md pattern. |
| L1    | Skill-internal scripts     | Skill body says "run `./scripts/check.sh` before closeout". Agent cites output. |
| L2    | Verification chains        | Scripts call gh CLI, RV MCP, verify-loop output. Cross-tool evidence. |
| L3    | Claude Code hooks          | PreToolUse hook intercepts `git commit` if state forbids. Hard invariant enforcement. |

### Phase plan for enforcement

- **v1**: L0 + L1. Markdown discipline + skill-internal scripts.
- **v2**: Add L2. Cross-tool verification chains (RV MCP integration, etc.)
- **v3**: Conditionally add L3. Only if observed failures show operator
  bypassing L0/L1 in ways that cause incidents.

YAGNI: do not build hook infrastructure until observed need.

## Phase Scope

### v1 Deliverables (this design's implementation plan)

1. `.windburn/skills/` directory structure
2. `RESOLVER.md` index listing 6 initial skills
3. `core/SKILL.md` with: invariants, state modifiers, transition rules,
   Darwin self-evolution section (gated on creator-visual-path work — applies
   only when active skill body invokes it; otherwise dormant), Superconductor
   intake anchor
4. `core/references/` with: proof-rules, public-surface, layer-closeout
   (factored from current AGENTS.md)
5. `core/scripts/check.sh` (universal verification — initial version)
6. 5 on-demand skill SKILL.md files: `chat`, `feature`, `infra-mutation`,
   `research`, `verification-loop`
7. `feature/scripts/run-checks.sh` and `infra-mutation/scripts/preflight.sh`
   (initial versions)
8. `AGENTS.md` update: thin pointer to `.windburn/skills/RESOLVER.md` +
   retention of high-level invariants summary
9. `.windburn/state/` gitignored directory for transient state declarations
10. `.gitignore` update to exclude `.windburn/state/`

### v2 (future, separate plan)

- L2 verification chains
- Optional auto-detection of operator state
- Eval suite for skill-loading precision
- `agent_roles` slot (executor / reviewer / observer)

### v3 (conditional, separate plan)

- L3 Claude Code hooks
- Multi-operator extensions

### Explicitly out of scope (this design)

- Replacing AGENTS.md entirely (it becomes pointer + invariants summary)
- Migrating `docs/codex-desktop-communication-profile.md` (separate concern:
  that is channel profile, not work profile)
- Darwin self-evolution as a SEPARATE skill (out of scope; will be encoded as
  conditional content within `core/SKILL.md` instead per operator decision)
- Multi-operator team workflows
- Hook infrastructure
- Auto-detection of operator state

## Open Questions / Parking Lot

1. **AGENTS.md fate** — design assumes thin pointer + invariants summary.
   Confirm during implementation plan whether to retain full content as
   transition layer or strip aggressively.
2. **Skill activation observability** — design assumes agent announces active
   skill on activation + transition only, silent during steady-state. Confirm
   noise vs visibility trade-off during dogfood.
3. **Eval suite priority** — Phase 2 default. If operator observes frequent
   off-target loading early in v1, accelerate.
4. **codex-desktop-communication-profile.md relationship** — channel profile is
   defended as a separate concern. Confirm during v1 dogfood whether it should
   eventually be absorbed.
5. **Public-surface skill catalog** — skill names probably safe for livestream;
   descriptions might leak strategy. Confirm during v1 whether descriptions need
   redaction surface.

## Design Notes

This architecture is intentionally **append-mostly** for skill bodies. The
expensive operations are: writing initial descriptions, defining transition
rules, defining invariants. After those stabilize, evolution happens via gotcha
appending and occasional new skill addition.

This addresses the "articulation tax" failure mode: we do not rewrite contracts
each session. We append observed boundary cases as gotchas.

This architecture is also intentionally **portable across agents**. Codex /
Claude / Hermes / OpenCode all read the same skills directory. Cross-tool agent
ops becomes systematic because the grammar is externalized.

The design honors the operator's underlying intuition (surfaced during
brainstorming): **don't trust any single signal source**. Skills + invariants
in core + transition rules in core + enforcement ladder all express the same
pattern at different layers — layered escalation rather than single-form
discipline.

---

End of design. Implementation plan to follow via `superpowers:writing-plans`
skill after operator review.
