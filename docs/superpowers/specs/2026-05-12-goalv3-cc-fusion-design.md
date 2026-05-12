# goalv3-cc: V2 + CC /goal + Codex Emergent Pattern — Fusion Design

- **Date**: 2026-05-12
- **Author**: 0xvox + Claude (brainstorming session, spans 2026-05-11 → 2026-05-12)
- **Status**: Design — awaiting operator review
- **Skill location** (post-implementation): `~/.claude/skills/goalv3-cc/`
- **Related artifacts**:
  - `/Users/0xvox/multica-ultimate-workbench/skills/workbench-goal-mode-v2/SKILL.md` — V2 source design
  - `/Users/0xvox/multica-ultimate-workbench/autopilots/goal-conductor.md` — V2 autopilot-side realization
  - `/Users/0xvox/multica-ultimate-workbench/docs/self-awareness-infra-layer.md` — Bootstrap prereq
  - `/Users/0xvox/.codex/memories/MEMORY.md` — Codex MEMORY task groups showing emergent self-dispatch + self-anti-LGTM pattern (Bounded Supervisor Review Gate v0 mentions DAS-2648/2650, max review targets=2, mode=create_issue)
  - `https://claude.com/blog/agent-view-in-claude-code` — CC v2.1.139 agent view
  - `https://github.com/Einsia/OpenChronicle` — Phase 2 DP1 chronicle backend dependency
  - Prior brainstorm spec: `docs/superpowers/specs/2026-05-11-windburn-adaptive-skill-architecture-design.md`

---

## Context

### The three sources being fused

**V2 (operator)**: `workbench-goal-mode-v2` skill in Multica Ultimate Workbench. Two-layer autonomous conductor (Design / Dispatch) with 9-state machine, 14-field Decision Packet, 11-field Self-Awareness Bootstrap, 9-field Closeout Contract. Dispatches Multica issues, uses dedupe/cooldown/max_active for noise prevention, has explicit operator-call vs autonomy guards. Composed with Friction Tier Router, SDD, L2 Pressure Gate, Auto Review Sweeper.

**CC `/goal` (Anthropic, v2.1.139, 2026-05-11)**: Cross-turn execution with completion condition, live elapsed/turns/tokens overlay panel, works in interactive, `-p`, and Remote Control. Single completion condition per invocation. Released same day as `claude agents` (agent view) which gives fleet visibility for parallel CC sessions including `claude --bg [task]` background launches.

**Codex GPT-5.5 emergent pattern (operator finding, 2026-05-12)**: Codex (gpt-5.5) on Windburn/MUW sessions has been observed self-dispatching gsd-* subagents in spec → plan → review sequences, then self-applying PASS/FLAG/BLOCK verdicts at every stage transition. Documented in `~/.codex/memories/MEMORY.md` task group "Bounded Supervisor Review Gate v0" with concrete config (`mode=create_issue`, `max review targets=2`, allowed targets list, operator approval gate intentionally open). Operator characterized this as "GPT-5.5 self-aware moment" — meta-finding.

### Why fuse

V2 gives the schema rigor (Decision Packet, Bootstrap, Closeout). CC `/goal` gives the execution mechanics (cross-turn, telemetry overlay, Remote Control). Codex emergent pattern gives the anti-LGTM-at-every-stage-transition discipline. None alone has all three. Fused = operator-grade autonomous goal mode native to CC, captures V2 lessons, leverages CC primitives, codifies the emergent V3 discipline.

### Bootstrap purpose

Phase 1 ships goalv3-cc skill. Phase 2 (separate brainstorm + plan in a new session) **uses goalv3-cc to drive codex absorption** — the recursive dogfood. The fused tool eats the prior stack.

---

## Goals

### Primary

- Port V2 architecture to CC single-session execution (Task tool replaces Multica issue dispatch)
- Codify the Codex V3 emergent pattern: anti-LGTM verdict override at every stage transition
- Leverage CC native primitives: Task tool, Agent tool, Skill tool, `claude --bg`, `claude agents`, TodoWrite/TaskCreate
- Self-contained skill (~550 lines main body + 4 script files + 4 reference templates)
- **Enable Phase 2 (recursive dogfood)**: goalv3-cc must be powerful enough to self-drive the codex-absorption task in a new session, with 4 parallel `--bg` Decision Packets (chronicle / hooks / mcp / agents)

### Secondary

- Surface OpenChronicle integration path as Phase 2 DP1 dependency (avoid reinventing memory layer)
- Document the cross-tool agent ops grammar that has been emerging across CC + codex + MUW
- Preserve all V2 invariants (no-fake-PASS, dedupe, cooldown, operator-call conditions, autonomy guards)

### Out of Goals (v1 explicitly excludes)

- ScheduleRemote / CronCreate cross-session cadence (V2 autopilot 15min/60min mode) — defer to v2
- RV-coupled state persistence (state.json in Research Vault note) — defer to v1.5 (depends on RV upgrade)
- Multi-goal single-session parallel — each invocation handles single goal — defer to v2
- Skill self-evolution / auto-prune dispatch-log — defer to v2
- Cross-machine conductor synchronization (Hermes / Pi role distribution) — out of CC scope, MUW concern
- Any automatic modification to codex-side `/Users/0xvox/.codex/` configuration — operator has explicitly locked this lane

---

## Architecture

### Pattern

Skill directory following Perplexity skill model + gbrain RESOLVER pattern (per prior brainstorm spec):

```
~/.claude/skills/goalv3-cc/
├── SKILL.md                                    # ~550-line main body
├── scripts/
│   ├── state-init.sh                          # mkdir .goal/<id>/, write state.json initial template
│   ├── dispatch.sh                            # wrap Task / --bg dispatch + dedupe + cooldown check
│   ├── verdict-parse.sh                       # extract PASS/FLAG/BLOCK from subagent stdout (4-source ladder)
│   └── closeout-validate.sh                   # pre-DONE 5-item validation
└── references/
    ├── decision-packet-template.md            # V2 14-field + CC 3-field schema
    ├── self-awareness-template.md             # V2 11-field schema
    ├── closeout-template.md                   # V2 9-field + CC 3-field schema
    └── codex-emergent-pattern.md              # V3 finding documentation (anti-LGTM-at-stage-transition codified)
```

### State Machine (V2 full 9 states, no simplification)

```
GOAL_CAPTURED
   ↓
DESIGNING  ← Self-Awareness Bootstrap (heavy path only)
   ↓
DECISION_PACKET (verdict: READY_TO_DISPATCH | NEEDS_DESIGN | OPERATOR_NEEDED)
   ↓
DISPATCHING → spawn Task subagent(s), max 2 in-flight (per Bounded Supervisor Gate v0)
   ↓
OBSERVING → block on Task return (or yield to operator if --bg dispatch mode)
   ↓
REVIEWING → parse stdout for PASS/FLAG/BLOCK
   ├── PASS  → LEARNING/ARCHIVING → NEXT_GOAL or DONE
   ├── FLAG  → DISPATCHING (re-route with new packet)
   └── BLOCK → BLOCKER_CLASSIFIED
                  ├── operator-call → OPERATOR_NEEDED (skill yields)
                  ├── external      → COOLDOWN → DESIGNING (re-design after cooldown elapses)
                  └── permanent     → ARCHIVED → DONE
```

### Per-goal state directory layout

```
.goal/<goal-id>/                # project-local (in CWD), not global ~/.claude/
├── state.json                  # main state file (single source of truth)
├── decision-packet.md          # current packet (snapshot to history/ on transition)
├── self-awareness.md           # heavy path only (DESIGNING prereq)
├── dispatch-log.jsonl          # append-only audit log
├── closeout.md                 # final contract (only at DONE state)
├── history/
│   ├── packet-v1.md            # historical packet snapshots
│   └── ...
└── operator-notes.md           # optional: operator-written context (skill auto-reads)
```

### Two-layer in CC

- **Layer 1 (Design)**: skill main thread in primary session, maintains state machine, produces Decision Packets
- **Layer 2 (Dispatch)**: skill uses `Task` tool to synchronously spawn subagents, each Task = one Decision Packet execution slot. `Agent` tool selects specialist subagent type per stage. Optional escape to `claude --bg` for parallel independent heavy work.

---

## Schemas

### Decision Packet (V2 14 + CC 3 fields)

```yaml
# V2 core (14)
goal_id: <slug>
intent: <one-sentence objective>
route: <human-readable execution path>
owner: <primary subagent for execution>
reviewer: <subagent for verdict, ideally different from owner>
constraints: <hard non-negotiables>
evidence_expectations: <exact artifacts or checks>
non_goals: <explicit exclusions>
blocker_conditions: <what blocks this route>
tier: fast | standard | heavy
dedupe_key: <canonical key — format "<goal_id>/<route-hash>">
max_active: 2          # default per Bounded Supervisor Gate v0
cooldown_minutes: 15   # default standard; 30 for heavy
verdict: READY_TO_DISPATCH | NEEDS_DESIGN | OPERATOR_NEEDED

# CC-native additions (3)
cc_task_descriptors:
  - description: <2-5 word task title>
    subagent_type: <from Agent tool registry>
    prompt: <full prompt for subagent>
cc_specialist_chains:                # multi-stage chains, e.g. architect→reviewer
  - stage: design
    subagent: feature-dev:code-architect
  - stage: review
    subagent: feature-dev:code-reviewer
expected_artifacts:                  # used by verdict-parse 4-source ladder
  - path: <file path>
  - stdout_pattern: "VERDICT: (PASS|FLAG|BLOCK)"

# Optional dispatch primitive override
cc_dispatch_mode: task | bg           # default: task
```

### Self-Awareness Bootstrap (V2 11 fields, full, heavy path only)

```yaml
runtime_identity: <CC version + model + effort + bare-mode-status>
role_boundary: <what this skill owns, what it must not take over>
repo_anchor: <cwd, branch, authoritative source>
tool_envelope: <relevant tools available + verified>
mcp_envelope: <MCP servers visible + connected>
memory_sources_checked: <auto-memory paths, .learnings, RV state>
current_state_proof: <git status, recent commits, fixed state>
risk_envelope: <public/private surface, destructive ops, runtime mutation, cost>
routing_decision: <inline / SDD / Task wave / specialist-chain / Supervisor>
success_metric: <the artifact that counts at DONE>
operator_call_conditions: <small list of MUST-stop conditions>
verdict: READY | FLAG | BLOCK
```

### Closeout Contract (V2 9 + CC 3 fields)

```yaml
goal_id:
objective:
state_machine_path: <state-transition trace>
decision_packets_produced: <count>
tasks_dispatched: <count + Task descriptors>
evidence_harvested: <summary>
noise_cancelled: <skipped-via-dedupe count>
operator_calls: <count + reasons>
residual_risk:
archive_actions_taken:
verdict: PASS | FLAG | BLOCK

# CC additions (3)
subagent_chain: [<order of specialist subagents that ran>]
total_tokens_estimate: <from transcripts>
final_artifacts: [<file paths created/modified>]
```

### state.json (per-goal runtime state)

```json
{
  "goal_id": "absorb-codex-into-cc",
  "current_state": "OBSERVING",
  "tier": "heavy",
  "started_at": "2026-05-12T07:30Z",
  "last_transition_at": "2026-05-12T08:15Z",
  "in_flight": [
    {"task_id": "T1", "subagent_type": "feature-dev:code-architect", "started_at": "..."}
  ],
  "seen_dedupe_keys": ["absorb-codex/chronicle-port/d4f8a1c"],
  "cooldowns": {
    "absorb-codex/chronicle-port/d4f8a1c": {"last_dispatch": "...", "cooldown_until": "..."}
  },
  "frozen_lanes": [],
  "operator_overrides": {},
  "history": [
    {"from": "GOAL_CAPTURED", "to": "DESIGNING", "at": "...", "trigger": "skill-load"},
    {"from": "DESIGNING", "to": "DECISION_PACKET", "at": "...", "verdict": "READY_TO_DISPATCH"}
  ],
  "operator_calls": [],
  "verdict": null
}
```

### dispatch-log.jsonl (append-only audit)

```jsonl
{"task_id":"T1","subagent_type":"feature-dev:code-architect","stage":"design","started_at":"...","completed_at":"...","verdict":"PASS","verdict_source":"explicit","evidence_summary":"3-page design doc...","artifact_paths":["docs/foo.md"],"prev_state":"DISPATCHING","next_state":"REVIEWING","tokens_estimate":1500,"mode":"task"}
```

---

## Dispatch Protocol

### Friction Tier Router (auto-classify, inline in skill body)

Skill runs inline classifier in DESIGNING state using rubric:

```
fast    — 1-step answer / lookup / simple patch / info question
          (signals: short goal, no cross-module touch, no external system)
          → skip Self-Awareness, inline execute or 1 subagent

standard — single module with clear spec, no external mutation
          (signals: scope=1 module, evidence=clear, blast=low)
          → skip Self-Awareness, Task spawn 1-2 sequential subagents

heavy   — multi-domain / cross-system / high-stakes / "absorb·migrate·port"
          (signals: ≥2 modules touched, external system involved, mutation risk,
           operator phrases like "完整 / thorough / 全量 / carefully")
          → Self-Awareness Bootstrap MANDATORY, ≥3 specialist chain
```

Tier persisted in state.json + Decision Packet. Operator override via packet `tier` field.

### Per-tier dispatch behavior

| Tier | Self-Awareness | Task spawns | Specialist chain | Max parallel |
|---|---|---|---|---|
| fast | skip | 0–1 | inline or 1 | 1 |
| standard | skip | 1–2 sequential | 2 (do + review) | 1 |
| heavy | **required** | 3+ | architect → builder → reviewer → second-opinion | 2 |

### Agent tool subagent registry (per stage, default mapping)

| Stage | Primary subagent | Fallback / second opinion |
|---|---|---|
| Design / architecture | `feature-dev:code-architect` | `pua:tech-lead-p9` |
| Research / explore | `feature-dev:code-explorer` / `Explore` | `general-purpose` |
| Implementation | `feature-dev:fullstack-developer` | `voltagent-core-dev:backend-developer` |
| Code review | `feature-dev:code-reviewer` | `voltagent-qa-sec:code-reviewer` |
| Verification | `gsd-verifier` / `superpowers:verification-before-completion` skill | `gsd-plan-checker` |
| Second opinion | `codex:codex-rescue` | `general-purpose` |
| Debug | `gsd-debugger` | `voltagent-qa-sec:debugger` |

Operator overrides per packet via `cc_specialist_chains`.

### Recursive Skill tool calls

Subagent context allowed to invoke other skills (depth limit 2 hops):
- `superpowers:test-driven-development` — write tests first
- `superpowers:verification-before-completion` — closeout verify
- `superpowers:requesting-code-review` — trigger review pass
- `pua:pua` — quality enforcement when slipping

### Two dispatch primitives

| `cc_dispatch_mode: task` (default) | `cc_dispatch_mode: bg` (opt-in heavy/parallel) |
|---|---|
| Skill uses `Task` synchronously to spawn subagent | Skill uses `Bash` to run `claude --bg "<prompt>"` |
| Conductor blocks waiting for return | Conductor transitions to OPERATOR_NEEDED + provides agent view guidance |
| Verdict parsed directly from Task return | Verdict via file hand-off (subagent writes `.goal/<id>/dispatch-bg-<task-id>-evidence.md`) |
| Single session, transcript-only obs | Multi-session, agent view shows all |
| Suits fast + standard + most heavy | Suits heavy + independent + long-running (Phase 2 "absorb codex" multi-domain parallel) |

### Verdict detection (4-source priority ladder)

1. **Structured explicit**: subagent return contains `VERDICT: PASS|FLAG|BLOCK` line → use it (highest trust)
2. **Stdout pattern**: per-packet `expected_artifacts.stdout_pattern` match → derive verdict
3. **Artifact existence + content**: check `expected_artifacts.path` exists + content sanity check
4. **Default heuristic**: no errors + completion claim → PASS; errors/timeout/unclear → FLAG; explicit abort/refuse → BLOCK

Verdict + evidence summary written to dispatch-log.jsonl with `verdict_source` field.

---

## Bounded Supervisor Review Gate

### max_active enforcement

- state.json maintains `in_flight: [task_id, ...]` array
- Before each dispatch: `if len(in_flight) ≥ max_active (default 2): block-and-wait OR queue`
- Single-session A mode: block-and-wait (Task tool synchronous, natural serialization or small batch parallel)

### Dedupe

- In-memory set `seen_dedupe_keys` per skill invocation
- Cross-session: load historical dispatch-log.jsonl dedupe_keys
- Three handling cases:
  - Same key + still active → skip + post status note
  - Same key + already PASS → skip unless `evidence_expectations` changed
  - Same key + already BLOCK → check if blocker changed, otherwise skip

### Cooldown

- Per dedupe_key, last_dispatch timestamp tracked in state.json
- Before re-dispatch: `if (now - last_dispatch) < cooldown_minutes: skip + log cooldown note`
- Default: 15min standard / 30min heavy
- Operator override: packet adds `cooldown_skip: true` for one-time bypass

### Operator-call conditions (MUST stop, V2 full preservation)

Skill transitions to OPERATOR_NEEDED and yields when:

1. Design trade-off needs human taste judgment (not more context)
2. Permission / secret / payment / runtime mutation required
3. Blocked lane is the only viable route
4. Same sub-task failed twice with different approaches (V2 dogfood pattern)
5. Dedupe key matches active issue but Decision Packet conflicts (route conflict)
6. Validation gate (pre-DONE 5 checks) any failure with no auto-remediation
7. **`cc_dispatch_mode: bg` triggered** — conductor cannot auto-receive result, must yield

### Autonomy guards (MAY proceed, V2 full preservation)

Skill acts autonomously (no operator confirm) when:

1. Decision Packet verdict = READY_TO_DISPATCH
2. None of the 7 operator-call conditions triggered
3. Dedupe confirms no duplicate
4. Route does not touch frozen lanes (operator-declared via `frozen_lanes` config)
5. Operator hasn't explicitly halted in recent messages

### State transition rules

```
DISPATCHING → OBSERVING:        at least 1 Task in_flight
OBSERVING → REVIEWING:          in_flight drains to empty (current wave done)
REVIEWING → DISPATCHING (FLAG): re-route with new packet
REVIEWING → BLOCKER_CLASSIFIED (BLOCK): trigger operator-call classification
REVIEWING → LEARNING (PASS):    evidence_expectations satisfied
LEARNING → ARCHIVING → DONE:    validation gate 5 checks all pass
```

---

## State Persistence + Observability

### 6-layer observability stack

| Layer | Mechanism | Operator visibility |
|---|---|---|
| **L0: Agent View** | `claude agents` shows all CC sessions including goalv3-cc main session + any `--bg` spawned subagents | Fleet view: running/blocked/done states across parallel sessions |
| L1: HUD / statusline | TaskCreate per state transition | Current state + tier on statusline |
| L2: Transcript | skill prints status line each transition | Real-time in main chat |
| L3: state.json | persistent, machine-readable | `cat .goal/X/state.json \| jq` anytime |
| L4: dispatch-log.jsonl | append-only audit | Full trail, jq-filterable |
| L5: history/ | packet snapshots, time-series | Git-friendly diff history |

**Critical invariant**: Task tool subagents are **not visible** in agent view (they are in-process). Only `--bg` spawned sessions appear. Skill body documents this distinction explicitly.

### Resume protocol (post-interrupt recovery)

Single-session A mode can be interrupted (`/exit`, Ctrl+C) or context-compacted. Resume sequence:

1. Skill re-invoked (operator says "resume goalv3-cc on goal <id>")
2. Read `.goal/<goal-id>/state.json`
3. Read `.goal/<goal-id>/decision-packet.md`
4. Replay `history` array (rebuild in-memory state, no side effects)
5. Check `in_flight`: any in_flight Tasks treated as **lost** (previous session dead, Task results unrecoverable)
6. Operator chooses: continue (re-dispatch lost tasks) / abandon (transition to ARCHIVED) / re-design (back to DESIGNING)

### Multi-goal coexistence

```
.goal/
├── absorb-codex-chronicle/
├── upgrade-rv-public-safe/
└── ship-substack-launch-note/
```

Each goal independent directory. Skill single-invoke handles single goal. Operator switches goal by specifying `goal_id` on invoke.

---

## Error Handling + Edge Cases

### Top 12 cases (probability descending)

| # | Scenario | Handling |
|---|---|---|
| 1 | Subagent return has no explicit VERDICT | 4-source ladder fallthrough; worst case heuristic → FLAG |
| 2 | Subagent Task timeout | BLOCKER_CLASSIFIED, blocker_type=external, COOLDOWN 30min retry; second timeout → OPERATOR_NEEDED |
| 3 | Subagent error / refuse | dispatch-log records error; verdict=BLOCK; classify by message: "I cannot..." → permanent / "tool unavailable" → external / "needs permission" → operator |
| 4 | **Verdict claim PASS but evidence missing** (anti-LGTM trigger) | **Override verdict → FLAG**, log "claimed PASS evidence absent", re-dispatch with stronger evidence_expectations. **This is V3 emergent pattern codified.** |
| 5 | Operator interrupt mid-flight (`/exit`, Ctrl+C) | Cleanup unreliable → resume detects lost in_flight, ask operator |
| 6 | state.json corrupted / missing | Skill detects → OPERATOR_NEEDED with diagnostic, operator decides rebuild from dispatch-log.jsonl or abandon |
| 7 | Cooldown timer clock drift (system clock changed) | Use monotonic timestamps where possible; ±5min tolerance; otherwise log warning + operator override available |
| 8 | Dedupe key collision across goals | dedupe_key embeds `<goal_id>/...` prefix → cross-goal naturally non-conflicting |
| 9 | Subagent crash / Task tool returns error | Same as #2, verdict=BLOCK external, COOLDOWN retry once |
| 10 | Subagent internal permission denied (tool not allowed) | Log + verdict=BLOCK operator-call, transition OPERATOR_NEEDED with "need to grant <tool>" message |
| 11 | Frozen lane config stale (operator wants to use path they previously froze) | Check `frozen_lanes` fresh every dispatch, operator can add `unfreeze_lanes: [...]` in packet for one-time bypass |
| 12 | Skill own bug / unhandled exception | Skill body wraps main loop in try/catch (instructions explicit); on exception write state.json `error: ...` + transition OPERATOR_NEEDED, no state loss |

### 4 anti-LGTM invariants

1. **No fake PASS**: case 4 above is core. Skill body explicit instruction: "if subagent claims PASS but evidence incomplete, override to FLAG. This is V3 emergent pattern codified."
2. **state.json append-only history**: history array never truncated, only appended. Full trail in dispatch-log.jsonl + history/.
3. **Operator override audit**: every operator override (`cooldown_skip: true`, `unfreeze_lanes`) written to state.json `operator_overrides: {...timestamp...}` + dispatch-log entry marked `override: true`.
4. **Validation gate (pre-DONE) 5 checks** (V2 full preservation):
   1. Every dispatched task has verdict or properly cancelled
   2. No duplicate active dedupe_keys
   3. Self-cancel condition satisfied (this goal has no in-flight + no pending)
   4. Evidence written to closeout.md (not scattered across dispatch-log only)
   5. OPERATOR_NEEDED was raised in all lacked-authority cases (audit history)

### 3 recovery patterns

| Scenario | Recovery |
|---|---|
| Session crash in OBSERVING | Resume protocol (replay history + treat in_flight as lost) |
| Validation gate fail | Transition back to LEARNING/ARCHIVING; operator decides force-DONE vs fix-then-retry |
| All routes cooldown-blocked | Transition to OPERATOR_NEEDED, ask operator whether to `cooldown_skip` globally |

---

## Phase 1 Deliverables

### Skill scaffold (~550 lines main body + scripts + references)

See Architecture section above for directory layout.

### SKILL.md body sections (12)

| # | Section | Content | Line estimate |
|---|---|---|---|
| 1 | When to activate | Positive examples + NOT-this-skill boundaries | ~30 |
| 2 | Architecture overview | State machine diagram + 2-layer + file layout | ~60 |
| 3 | Friction Tier Router | Auto-classify rubric (fast/standard/heavy) | ~40 |
| 4 | Self-Awareness Bootstrap | Heavy path prereq, 11-field schema | ~50 |
| 5 | Decision Packet | 14+3 field schema, template ref | ~60 |
| 6 | Dispatch protocol | Task vs --bg, specialist registry, max_active | ~80 |
| 7 | Verdict detection | 4-source ladder, anti-LGTM override | ~40 |
| 8 | Bounded Supervisor Gate | Dedupe + cooldown + operator-call + autonomy guards | ~70 |
| 9 | Observability | 6-layer stack | ~40 |
| 10 | Validation + Closeout | 5 pre-DONE checks + 9+3 field schema | ~50 |
| 11 | Refuses to do | Negative space (anti-LGTM) | ~20 |
| 12 | Gotchas | Append-mostly (initially empty) | ~10 |

### SKILL.md frontmatter

```yaml
---
name: goalv3-cc
description: |
  Load when operator says "/goal" + V3 contract / "goalv3-cc" / wants persistent
  multi-stage autonomous work with Bounded Supervisor Review Gate. Two-layer
  conductor produces Decision Packets, dispatches subagents via Task or --bg,
  enforces anti-LGTM verdicts at every stage transition. Self-Awareness
  Bootstrap on heavy path. State at .goal/<goal-id>/.
depends: [core]   # if/when goalv3-cc skill ecosystem adopts core+overlay per prior brainstorm
metadata:
  version: 0.1.0
  closeout_layers: [0, 1, 2, 3]
  inspired_by:
    - Multica Workbench Goal Mode v2 (operator design)
    - Codex GPT-5.5 emergent self-dispatch + self-anti-LGTM pattern (operator finding)
    - CC /goal (Anthropic, v2.1.139)
    - CC agent view (Anthropic, v2.1.139)
---
```

### Phase 1 success criteria (7 dogfood tests)

1. Skill loading: operator says "use goalv3-cc to ..." → skill body appears in transcript
2. Fast tier dogfood: trivial goal ("check git status and summarize") → fast path, no Task spawn, return verdict
3. Standard tier dogfood: mid-size goal ("write a 200-word summary of the last 5 commits") → 1 Task spawn, verdict PASS, closeout written
4. Heavy tier dogfood: multi-stage goal ("audit `~/.claude/learnings/` for stale entries, propose 3 prunes") → Self-Awareness Bootstrap + multi-stage Task chain + closeout
5. Anti-LGTM override case: goal that induces false PASS (subagent claims PASS but evidence missing) → skill overrides to FLAG, re-dispatches
6. `--bg` opt-in: packet with explicit `cc_dispatch_mode: bg` → conductor transitions to OPERATOR_NEEDED with agent view guidance
7. Resume protocol: interrupt session in OBSERVING → next invoke detects lost in_flight + asks operator

---

## Phase 2 Hook (eating codex)

Phase 2 ≡ goalv3-cc self-drives one big invocation, target = absorb codex full stack into CC.

### Goal definition (operator writes once)

```yaml
goal_id: absorb-codex-into-cc
intent: Port codex chronicle + hooks + mcp + agent registry into CC analogs
tier: heavy   # operator-overridable but auto-classifier will choose heavy
cc_dispatch_mode: bg   # 4 domains parallel
```

### Pre-sketched Decision Packets (skill auto-produces in DESIGNING)

| Domain | DP intent | Owner subagent | Reviewer |
|---|---|---|---|
| **DP1: Chronicle** *(revised)* | **Integrate OpenChronicle (v0.1.0) as canonical chronicle backend** on macOS. Set up MCP wiring so goalv3-cc and other CC tools can query OpenChronicle's Markdown memory + SQLite. Optionally migrate codex's 1195 chronicle resource files INTO OpenChronicle Markdown format. | `voltagent-dev-exp:tooling-engineer` | `feature-dev:code-reviewer` + `codex:codex-rescue` |
| **DP2: Hooks** | Diff codex hooks.json vs ~/.claude/settings.json hooks, identify unique (herdr-agent-state.sh, etc.), port + dedupe | `voltagent-dev-exp:dx-optimizer` | `feature-dev:code-reviewer` |
| **DP3: MCP** | Diff codex config.toml mcp_servers vs ~/.claude/mcp.json + plugins, port unique (computer-use-mcp-wrapper, openaiDeveloperDocs), unify | `voltagent-dev-exp:tooling-engineer` | `voltagent-qa-sec:security-auditor` |
| **DP4: Agents** | Check 44 codex agent .toml vs CC voltagent + ~/.claude/agents/, prune overlap, port unique | `feature-dev:code-explorer` | `feature-dev:code-reviewer` |

### Phase 2 deliverables (skill produces, operator approves)

- OpenChronicle installed + configured + auto-running on macOS
- MCP wiring so any CC tool can query OpenChronicle memory layer
- Consolidated hooks.json (single source of truth across CC + ported codex hooks)
- Unified ~/.claude/mcp.json with codex-unique MCPs ported
- Pruned agent registry (overlap with voltagent removed, codex-unique kept)
- `.goal/absorb-codex-into-cc/closeout.md` with full V2 closeout + per-domain verdict

### Phase 2 expected duration

1 long CC session (~2-4 hours wall clock with 4 `--bg` parallel domains + operator approval gates between waves).

---

## Open Questions / Parking Lot

1. **Subagent type unavailability fallback**: if operator has disabled `feature-dev:code-architect`, what does skill do? Default proposal: fall back to next in registry; if no fallback, transition OPERATOR_NEEDED with "need to enable <subagent_type>".
2. **Cooldown timer accuracy across system clock drift**: edge case, current design uses monotonic timestamps where available + ±5min tolerance + operator override.
3. **Long `--bg` session exceeds context window**: handled by the bg session itself, not conductor concern; conductor needs to recognize truncated evidence in hand-off file.
4. **Anti-LGTM verdict override needs formal behavioral test** (beyond dogfood): defer test suite design to Phase 1 implementation plan.
5. **OpenChronicle Linux compatibility**: v0.1.0 is macOS only. If operator runs on Linux (future), DP1 needs alternative or upstream contribution.
6. **goalv3-cc within agent view**: main skill session is visible in agent view, Task tool subagents are not. Operator may want statusline annotation indicating "X subagents in-flight". Defer to v1.5.
7. **Recursive skill chain depth limit**: default 2 hops, but heavy goals may need 3. Defer tuning to dogfood feedback.

---

## Design Notes

### Anti-LGTM as system invariant codification

The core insight from codex GPT-5.5 emergent pattern: anti-LGTM applied at every stage transition is what makes the agent self-correcting. V2 implicitly had this via reviewer subagent. V3 codifies it: the conductor itself overrides claimed-PASS-with-missing-evidence to FLAG, automatically. This converts a discipline (operator habit) into a guardrail (system invariant).

### Two-layer conductor vs single-thread

V1 of any goal mode tends to be single-thread persistence wrapper. V2 splits into Design / Dispatch precisely because mixing them produces noise (Design re-runs at every Dispatch trigger, Dispatch re-routes based on stale Design). Two layers means each has clear ownership: Design owns scoping + taste, Dispatch owns mechanics + state. goalv3-cc preserves this split inside a single CC session via state machine separation rather than separate processes.

### Why depend on Multica → CC primitive remap

V2's primary work unit was Multica issue. Multica issues persist, are queryable, can have comments and state changes. CC's Task tool is in-process synchronous spawn. They are not interchangeable: Multica is more durable, Task is more immediate. The remap is: drop the durable aspect (we have file-system state.json instead), keep the dispatch + verdict aspect (Task spawn + return = same conceptual unit). For Phase 2 multi-domain parallel work, `--bg` adds back some durability (sessions persist across operator absence) at cost of automated monitoring.

### Cross-tool agent ops grammar (the emerging meta-architecture)

The operator has been running CC + codex + MUW in parallel for months. Each tool has its own agent ecosystem (CC: plugins + skills + Task tool; codex: agents .toml + chronicle + sessions; MUW: workbench-skills + autopilots + multica issues). goalv3-cc is the first explicit CC-side codification of the operator's cross-tool grammar. It captures: tier-based routing, self-anti-LGTM verdicts, bounded supervisor gate, dedupe/cooldown discipline, Self-Awareness Bootstrap, full closeout contract. These are the same patterns showing up across CC + codex + MUW because they are operator patterns, not tool patterns.

---

End of design. Implementation plan to follow via `superpowers:writing-plans` skill after operator review.
