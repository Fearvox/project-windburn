# goalv3-cc Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `goalv3-cc` Claude Code skill that fuses Multica Workbench Goal Mode V2 schemas + CC `/goal` execution primitives + Codex GPT-5.5 emergent self-anti-LGTM pattern into one operator-grade autonomous goal mode native to CC, then validate it by self-driving codex absorption (recursive dogfood).

**Architecture:** Skill directory at `~/.claude/skills/goalv3-cc/` containing a ~550-line SKILL.md (12 sections) + 4 bash scripts (state-init, dispatch, verdict-parse, closeout-validate) + 4 reference templates. Two-layer in-session conductor (Design + Dispatch) using CC Task tool synchronously by default, `claude --bg` opt-in for parallel heavy work, per-goal state in `.goal/<goal-id>/` in CWD. 4-source verdict ladder with anti-LGTM override codified as system invariant.

**Tech Stack:** CC skill format (markdown frontmatter + body), bash 3.2+ scripts, `jq` for state.json manipulation, `.goal/<id>/` project-local state directories, Task tool / Agent tool / claude --bg / claude agents as dispatch primitives.

**Source artifacts (read these alongside this plan):**
- Spec: `docs/superpowers/specs/2026-05-12-goalv3-cc-fusion-design.md` (582 lines, design source of truth)
- Decisions: `docs/superpowers/specs/2026-05-12-goalv3-cc-fusion-decisions.md` (12 design decisions with rejected alternatives)
- Boot dossier: `docs/superpowers/specs/2026-05-12-goalv3-cc-NEXT-SESSION-BOOT.md` (anchors + don't-trust list + out-of-scope)

**HARD-GATE invariants (operator's CLAUDE.md):**
- NEVER auto-commit. Every commit step in this plan is "present to operator + propose message + wait for explicit go".
- NEVER modify `~/multica-ultimate-workbench/autopilots/` or `~/.codex/` (operator-locked lanes per boot dossier).
- ANTI-LGTM: before claiming PASS on any task, verify the artifact exists + content matches expectations.

---

## Pre-flight assumptions to verify (boot dossier "don't trust" list)

Run these **once** before Task 1 — they're not per-task gates, but if any fails, stop and tell operator:

```bash
# Verify CC version >= 2.1.140 (boot dossier said 2.1.139 was current; we observed 2.1.140 in attach screenshot)
claude --version

# Verify ~/.claude/skills/ exists (skill home)
ls -ld ~/.claude/skills/

# Verify no existing goalv3-cc (clean install)
test ! -e ~/.claude/skills/goalv3-cc/ && echo "OK: clean install possible" || echo "WARN: exists already"

# Verify jq + bash available (script dependencies)
which jq bash

# Verify Windburn root .gitignore exists (will edit it)
ls -la ~/Windburn/.gitignore
```

Expected: CC ≥ 2.1.140, skills dir exists, no existing goalv3-cc, jq + bash on PATH, Windburn .gitignore exists. Any miss → halt and surface to operator.

---

## Task 1: Scaffold skill directory + Windburn .gitignore entry

**Files:**
- Create: `~/.claude/skills/goalv3-cc/scripts/.keep`
- Create: `~/.claude/skills/goalv3-cc/references/.keep`
- Modify: `~/Windburn/.gitignore` (add `.goal/` line if absent)

- [ ] **Step 1: Create skill directory structure**

```bash
mkdir -p ~/.claude/skills/goalv3-cc/scripts ~/.claude/skills/goalv3-cc/references
touch ~/.claude/skills/goalv3-cc/scripts/.keep ~/.claude/skills/goalv3-cc/references/.keep
ls -la ~/.claude/skills/goalv3-cc/
```

Expected: directory tree exists with scripts/ + references/ subdirs.

- [ ] **Step 2: Verify Windburn `.gitignore` ignores `.goal/`**

```bash
cd ~/Windburn
grep -q '^\.goal/' .gitignore || echo ".goal/" >> .gitignore
tail -5 .gitignore
```

Expected: last line(s) include `.goal/`. State directories never get committed.

- [ ] **Step 3: Present + propose commit (HARD-GATE: wait for operator go)**

Stage:
```bash
cd ~/Windburn
git add .gitignore
git status
git diff --cached
```

Propose commit message:
```
chore: gitignore .goal/ for goalv3-cc per-goal state directories

State for goalv3-cc skill lives in CWD .goal/<goal-id>/ (per spec D5).
This entry prevents runtime state from polluting Windburn repo.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Wait for operator: `commit ok` / `change message` / `skip commit`. Skill files at `~/.claude/skills/goalv3-cc/` are separate (not in Windburn) — operator decides separately whether to version-control `~/.claude/`.

---

## Task 2: Reference template — Decision Packet schema

**Files:**
- Create: `~/.claude/skills/goalv3-cc/references/decision-packet-template.md`

Spec source: lines 132-167 (V2 14 + CC 3 fields + optional cc_dispatch_mode).

- [ ] **Step 1: Write the template**

Write file `~/.claude/skills/goalv3-cc/references/decision-packet-template.md` with this content:

````markdown
# Decision Packet Template

A Decision Packet is the conductor's plan for one dispatch wave. Skill produces it in DESIGNING state, operator may modify, then it gates transition to DISPATCHING.

Schema: V2 14 fields (preserved verbatim) + CC-native 3 fields + optional `cc_dispatch_mode`.

## Schema

```yaml
# === V2 core (14 fields, all required) ===
goal_id: <slug>                           # e.g. "absorb-codex-into-cc"
intent: <one-sentence objective>          # what this packet achieves
route: <human-readable execution path>    # e.g. "explore /.codex/extensions/chronicle → port to OpenChronicle MD format"
owner: <primary subagent for execution>   # from Agent tool registry, e.g. "feature-dev:code-architect"
reviewer: <subagent for verdict>          # ideally different from owner
constraints: <hard non-negotiables>       # e.g. "no modify ~/.codex/"
evidence_expectations: <exact artifacts>  # e.g. "file at path X with section Y exists"
non_goals: <explicit exclusions>          # what this packet does NOT do
blocker_conditions: <what blocks route>   # e.g. "OpenChronicle install fails on macOS Sequoia"
tier: fast | standard | heavy             # auto-classified, operator-overridable
dedupe_key: <canonical key>               # format: "<goal_id>/<route-hash>"
max_active: 2                             # default per Bounded Supervisor Gate v0
cooldown_minutes: 15                      # default standard; 30 for heavy
verdict: READY_TO_DISPATCH | NEEDS_DESIGN | OPERATOR_NEEDED

# === CC-native additions (3 fields) ===
cc_task_descriptors:                      # one or more Task tool invocations this packet will spawn
  - description: <2-5 word task title>
    subagent_type: <Agent tool registry name, e.g. "feature-dev:code-architect">
    prompt: <full prompt for subagent>

cc_specialist_chains:                     # multi-stage chains, sequential
  - stage: design
    subagent: feature-dev:code-architect
  - stage: review
    subagent: feature-dev:code-reviewer

expected_artifacts:                       # used by verdict-parse 4-source ladder
  - path: <file path created/modified>
  - stdout_pattern: "VERDICT: (PASS|FLAG|BLOCK)"

# === Optional dispatch primitive override ===
cc_dispatch_mode: task | bg               # default: task. bg = parallel via claude --bg
```

## Field Notes

- **`dedupe_key`**: must be stable across re-design — same route → same key. Use `<goal_id>/<route-hash>` where route-hash is SHA-256 first 7 chars of `route` field.
- **`max_active`**: skill enforces this in dispatch.sh. Default 2 per Bounded Supervisor Review Gate v0.
- **`cooldown_minutes`**: skipped re-dispatch if `now - last_dispatch < cooldown_minutes`. Operator one-time bypass: add field `cooldown_skip: true`.
- **`cc_dispatch_mode: bg`**: triggers operator-call condition #7 (conductor cannot auto-monitor `--bg` sessions). Skill transitions to OPERATOR_NEEDED + provides agent view guidance.
- **`expected_artifacts.stdout_pattern`**: regex applied to subagent return; if matched, verdict ladder source 2 fires.

## Example (filled, fast tier)

```yaml
goal_id: summarize-recent-commits
intent: Produce a 200-word summary of the last 5 commits on main
route: git log -5 → general-purpose subagent → write summary
owner: general-purpose
reviewer: general-purpose
constraints: no external network, output <= 200 words
evidence_expectations: file at .goal/summarize-recent-commits/artifact.md, word count 150-200
non_goals: do not analyze diffs, do not propose changes
blocker_conditions: git log empty, repo not initialized
tier: standard
dedupe_key: summarize-recent-commits/log5-3a2f1c8
max_active: 1
cooldown_minutes: 15
verdict: READY_TO_DISPATCH
cc_task_descriptors:
  - description: summarize 5 commits
    subagent_type: general-purpose
    prompt: "Read `git log -5 --stat`. Write 200-word summary of changes. Save to .goal/summarize-recent-commits/artifact.md. End with line: VERDICT: PASS"
cc_specialist_chains:
  - stage: do
    subagent: general-purpose
expected_artifacts:
  - path: .goal/summarize-recent-commits/artifact.md
  - stdout_pattern: "VERDICT: (PASS|FLAG|BLOCK)"
cc_dispatch_mode: task
```
````

- [ ] **Step 2: Verify content matches spec schema**

```bash
grep -c "^[a-z_]*:" ~/.claude/skills/goalv3-cc/references/decision-packet-template.md
```

Expected: count >= 17 (14 V2 + 3 CC fields, plus example fields). Also: open file, eyeball it covers all 17 fields from spec lines 134-167.

---

## Task 3: Reference template — Self-Awareness Bootstrap

**Files:**
- Create: `~/.claude/skills/goalv3-cc/references/self-awareness-template.md`

Spec source: lines 169-184 (11 fields, heavy-tier prereq).

- [ ] **Step 1: Write the template**

Write file with this content:

````markdown
# Self-Awareness Bootstrap Template

Prerequisite for HEAVY tier goals. Skill runs the bootstrap in DESIGNING state before producing a Decision Packet. Output anchors all subsequent claims to verified facts (anti-hallucination at design time).

Skip for FAST and STANDARD tiers — they don't justify the overhead.

## Schema (V2 11 fields, all required for heavy)

```yaml
runtime_identity:
  cc_version: <output of `claude --version`>
  model: <e.g. claude-opus-4-7>
  effort: <e.g. high / medium>
  bare_mode_status: <yes/no — affects available primitives>

role_boundary:
  owns: <what this skill is authorized to do, e.g. "design + dispatch within .goal/X/">
  must_not_take_over: <e.g. "operator's MUW autopilot lane / codex config">

repo_anchor:
  cwd: <output of pwd>
  branch: <output of `git branch --show-current`>
  authoritative_source: <e.g. "spec at docs/superpowers/specs/2026-05-12-goalv3-cc-fusion-design.md">

tool_envelope:
  - tool: <name>
    verified: <yes/no — verified via mini smoke or just listed>
  # e.g. Task, Agent, Skill, Bash, Read, Write, Edit, TodoWrite

mcp_envelope:
  - server: <name>
    connected: <yes/no>
  # e.g. context7, playwright, research-vault

memory_sources_checked:
  - path: <e.g. ~/.claude/learnings/>
    purpose: <e.g. "prior gotchas">
  - path: <e.g. .learnings/>
    purpose: <e.g. "project-specific lessons">

current_state_proof:
  git_status: <output snippet>
  recent_commits: <last 3 commit hashes + subjects>
  fixed_state_files: <key state.json contents if resuming>

risk_envelope:
  surface: <public / private / mixed>
  destructive_ops_possible: <list — e.g. "rm -rf, force-push">
  runtime_mutation: <e.g. "edits ~/.claude/ which is shared across projects">
  cost_estimate: <tokens / wall-clock>

routing_decision:
  pattern: <inline | SDD | Task wave | specialist-chain | Supervisor>
  rationale: <one sentence>

success_metric:
  artifact: <the file/output that counts at DONE>
  verification: <how to confirm artifact valid>

operator_call_conditions:
  - <small list of MUST-stop conditions specific to this goal>
  # ALWAYS include the 7 generic ones from SKILL.md section 8

verdict: READY | FLAG | BLOCK
```

## Field Notes

- **`tool_envelope`**: verify ≥ the tools you'll actually use. Don't list everything — list what this goal needs.
- **`mcp_envelope`**: only list MCP servers the route depends on. Mark unconnected ones explicitly.
- **`current_state_proof`**: this is the anti-hallucination anchor. Skill body's first action in DESIGNING (heavy) is to write this section.
- **`risk_envelope`**: if `destructive_ops_possible` is non-empty AND `surface: public`, escalate to operator before DISPATCHING.
- **`operator_call_conditions`**: goal-specific stop conditions. Add to the 7 generic ones from SKILL.md; do not replace them.
- **`verdict`**: gates progression. `FLAG` → re-do bootstrap with missing info. `BLOCK` → escalate to OPERATOR_NEEDED.

## Example (filled, heavy-tier — absorbing codex chronicle)

```yaml
runtime_identity:
  cc_version: 2.1.140
  model: claude-opus-4-7
  effort: high
  bare_mode_status: no

role_boundary:
  owns: design + dispatch absorb-codex-into-cc/chronicle lane
  must_not_take_over: codex ~/.codex/ (operator-locked), MUW autopilots

repo_anchor:
  cwd: ~/Windburn
  branch: main
  authoritative_source: docs/superpowers/specs/2026-05-12-goalv3-cc-fusion-design.md

tool_envelope:
  - tool: Task
    verified: yes
  - tool: Bash
    verified: yes
  - tool: Read
    verified: yes

mcp_envelope:
  - server: research-vault
    connected: yes
  - server: context7
    connected: yes

memory_sources_checked:
  - path: ~/.claude/learnings/
    purpose: prior CC + chronicle integration lessons
  - path: .learnings/
    purpose: Windburn-specific design log

current_state_proof:
  git_status: clean tree on main
  recent_commits: cc8e23d Park agent social reality receipt / 796bc02 docs: design goalv3-cc fusion / 809be7e docs: substack launch
  fixed_state_files: .goal/absorb-codex-into-cc/state.json (current_state: GOAL_CAPTURED)

risk_envelope:
  surface: private
  destructive_ops_possible: []
  runtime_mutation: installs OpenChronicle to ~/openchronicle/, modifies ~/.claude/mcp.json (additive)
  cost_estimate: ~50K tokens across 4 --bg sessions, ~2 hours wall clock

routing_decision:
  pattern: Supervisor (4 parallel --bg Decision Packets)
  rationale: 4 independent domains (chronicle/hooks/mcp/agents), --bg gives agent view visibility, operator-gate between waves

success_metric:
  artifact: .goal/absorb-codex-into-cc/closeout.md with all 4 DP verdicts PASS, OpenChronicle MCP queryable
  verification: `mcp list | grep openchronicle` returns connected; closeout.md exists with verdict line PASS

operator_call_conditions:
  - all 7 generic conditions from SKILL.md section 8
  - any DP triggers cc_dispatch_mode: bg (always operator-call per condition #7)
  - OpenChronicle install requires sudo (would touch system state beyond ~/)

verdict: READY
```
````

- [ ] **Step 2: Verify field coverage**

```bash
# All 11 V2 fields should appear as top-level keys in the schema section
for f in runtime_identity role_boundary repo_anchor tool_envelope mcp_envelope memory_sources_checked current_state_proof risk_envelope routing_decision success_metric operator_call_conditions verdict; do
  grep -q "^${f}:" ~/.claude/skills/goalv3-cc/references/self-awareness-template.md && echo "  ok: $f" || echo "  MISSING: $f"
done
```

Expected: 12 "ok:" lines (11 fields + verdict).

---

## Task 4: Reference template — Closeout Contract

**Files:**
- Create: `~/.claude/skills/goalv3-cc/references/closeout-template.md`

Spec source: lines 186-205 (V2 9 + CC 3 fields).

- [ ] **Step 1: Write the template**

Write file with this content:

````markdown
# Closeout Contract Template

Written by skill at DONE state, after all 5 pre-DONE validation checks pass. Single artifact summarizing the whole goal lifecycle. Operator-readable + machine-parseable (YAML).

Located at `.goal/<goal-id>/closeout.md`.

## Schema (V2 9 + CC 3 fields)

```yaml
# === V2 core (9 fields) ===
goal_id: <slug>
objective: <one-sentence original goal>
state_machine_path: <trace of state transitions, e.g. "GOAL_CAPTURED → DESIGNING → DECISION_PACKET → DISPATCHING → OBSERVING → REVIEWING → LEARNING → ARCHIVING → DONE">
decision_packets_produced: <count + brief list>
tasks_dispatched: <count + Task descriptors used>
evidence_harvested: <summary of artifacts collected>
noise_cancelled: <skipped-via-dedupe count + reasons>
operator_calls: <count + reasons, e.g. "1 — DP2 needed mcp.json review">
residual_risk: <known follow-ups>
archive_actions_taken: <state moved to ARCHIVED, files preserved, etc.>
verdict: PASS | FLAG | BLOCK

# === CC additions (3 fields) ===
subagent_chain: [<order of specialist subagents that actually ran>]
total_tokens_estimate: <from transcripts, approximate>
final_artifacts: [<file paths created/modified>]
```

## Field Notes

- **`state_machine_path`**: must be exact trace from state.json `history`. Generated by closeout-validate.sh script.
- **`decision_packets_produced`**: count includes re-designs (FLAG → DISPATCHING → re-dispatched). Each historical packet snapshot lives in `history/`.
- **`evidence_harvested`**: aggregate of every dispatch-log.jsonl entry's evidence_summary field. Not raw — summarized.
- **`noise_cancelled`**: count of dispatches skipped via dedupe + cooldown. If zero, suspect dedupe is broken; if very high, suspect packet route is unstable.
- **`operator_calls`**: every transition to OPERATOR_NEEDED. Document the reason classification.
- **`residual_risk`**: what's left unaddressed. Empty is suspicious for heavy goals.
- **`verdict`** at closeout level: aggregate across all DPs. If any DP is BLOCK and not resolved, closeout verdict is BLOCK. If any DP is FLAG and not resolved, closeout verdict is FLAG. All PASS → PASS.

## Example (filled — fast tier, simple goal)

```yaml
goal_id: summarize-recent-commits
objective: Produce a 200-word summary of the last 5 commits on main
state_machine_path: GOAL_CAPTURED → DESIGNING → DECISION_PACKET → DISPATCHING → OBSERVING → REVIEWING → LEARNING → ARCHIVING → DONE
decision_packets_produced: 1 (summarize-recent-commits/log5-3a2f1c8)
tasks_dispatched: 1
  - general-purpose: "summarize 5 commits"
evidence_harvested: 187-word summary at .goal/summarize-recent-commits/artifact.md covering 5 commits cc8e23d..0654971
noise_cancelled: 0
operator_calls: 0
residual_risk: none
archive_actions_taken: state.json final_state=DONE, history preserved, no cleanup needed
verdict: PASS
subagent_chain: [general-purpose]
total_tokens_estimate: 2500
final_artifacts:
  - .goal/summarize-recent-commits/artifact.md
  - .goal/summarize-recent-commits/state.json
  - .goal/summarize-recent-commits/closeout.md
```

## Pre-DONE Validation Gate (5 checks)

closeout-validate.sh enforces these BEFORE writing closeout.md. Any fail → transition back to LEARNING (operator decides force-DONE or fix).

1. Every dispatched task in dispatch-log.jsonl has a `verdict` field OR an explicit `cancelled: true` flag.
2. No duplicate active `dedupe_key` entries in state.json (`in_flight` array unique).
3. Self-cancel condition met: `in_flight` empty AND no pending packets in DESIGNING.
4. Evidence is in closeout.md (not only in dispatch-log.jsonl).
5. Every "needed-authority" case in state.json history was raised as OPERATOR_NEEDED (audit completeness).

If any check fails, write `.goal/<goal-id>/validation-failure.md` listing which checks failed, transition to LEARNING, and emit OPERATOR_NEEDED.
````

- [ ] **Step 2: Verify schema coverage**

```bash
for f in goal_id objective state_machine_path decision_packets_produced tasks_dispatched evidence_harvested noise_cancelled operator_calls residual_risk archive_actions_taken verdict subagent_chain total_tokens_estimate final_artifacts; do
  grep -q "^${f}:" ~/.claude/skills/goalv3-cc/references/closeout-template.md && echo "  ok: $f" || echo "  MISSING: $f"
done
```

Expected: 14 "ok:" lines (9 V2 + 3 CC + bonus verdict + bonus subagent_chain = covers all).

---

## Task 5: Reference doc — Codex emergent pattern (V3 finding documentation)

**Files:**
- Create: `~/.claude/skills/goalv3-cc/references/codex-emergent-pattern.md`

Spec source: lines 562-578 (Design Notes — Anti-LGTM as system invariant), plus context from lines 26-30, 423-424, 433-444, 566-578.

- [ ] **Step 1: Write the doc**

Write file with this content:

````markdown
# Codex GPT-5.5 Emergent Pattern — V3 Anti-LGTM Codified

This document records the operator finding (2026-05-12) that motivated codifying anti-LGTM verdict override as a system invariant in goalv3-cc.

## The Finding

Codex (GPT-5.5) running on Windburn / MUW sessions was observed self-dispatching `gsd-*` subagents in `spec → plan → review` sequences, and at every stage transition self-applying PASS/FLAG/BLOCK verdicts. Documented in `~/.codex/memories/MEMORY.md` task group "Bounded Supervisor Review Gate v0" with concrete config:

```
mode = create_issue
max review targets = 2
allowed targets = [DAS-2648, DAS-2650, ...]
operator approval gate = intentionally open
```

Operator characterized this as a **"GPT-5.5 self-aware moment"** — meta-finding. The agent was self-correcting at every transition, applying anti-LGTM discipline that normally requires human review.

## Why It's Load-Bearing

Most agent loops fail in the "claimed PASS but evidence missing" mode:
- Subagent finishes its turn
- Says "Done" or emits PASS-shaped output
- But the artifact does not exist OR the content is wrong
- Outer loop trusts the claim → propagates fake PASS upward
- By DONE state, the goal is "complete" but the work is bad

V2 mitigated this implicitly: it used a separate reviewer subagent (different from owner). If reviewer was honest, fake PASS got caught. But reviewer is just another subagent — same failure mode applies.

The Codex V3 emergent pattern is structurally different: **the conductor itself**, not a reviewer, does the verdict check. It does it at every stage transition, automatically, based on the original Decision Packet's `evidence_expectations`.

## The Codification

In goalv3-cc:

1. Each Decision Packet has `evidence_expectations` — exact artifacts or stdout patterns the dispatch must produce.
2. When a dispatched subagent returns, skill runs verdict-parse.sh via 4-source ladder:
   - source 1: explicit `VERDICT: PASS|FLAG|BLOCK` in subagent return
   - source 2: stdout pattern match per packet
   - source 3: artifact existence + content sanity check
   - source 4: heuristic (errors → FLAG, refuse → BLOCK, otherwise PASS)
3. **If source 1 says PASS but source 3 says artifact missing/empty → conductor OVERRIDES verdict to FLAG.** This is automatic, no operator intervention. Log entry: `"claimed PASS evidence absent"`.
4. FLAG triggers re-DISPATCHING with strengthened `evidence_expectations`.

## Why Override Instead of FLAG-By-Default

If source 1 (subagent's own verdict) is `BLOCK` or `FLAG`, conductor accepts it. Subagents that self-flag are honest — punishing them would harm calibration.

If source 1 is `PASS` AND source 3 confirms artifact → trust the PASS.

Only the specific combo `PASS-claimed + evidence-absent` triggers override. This is the falsehood we're catching.

## Where This Differs from V2

| V2 (implicit) | V3 (codified) |
|---|---|
| Reviewer subagent catches fake PASS | Conductor catches fake PASS |
| Discipline depends on reviewer quality | Discipline depends on `evidence_expectations` quality |
| Failure mode: lazy reviewer signs off | Failure mode: poorly-written packet |
| Lever for improvement: better reviewer prompts | Lever for improvement: better packet templates |

V3 shifts the failure point earlier (packet design time) where operator review is cheaper.

## Where This Differs from Codex Behavior

Codex emergent pattern was observed but not specified — it could regress with model updates. goalv3-cc makes it explicit instruction in skill body, so it survives session restarts, context compactions, and operator absence.

## Operator's Meta-Discipline (Reflected at Skill Body Level)

The skill body section 11 ("Refuses to do") includes:

> When you (the skill body operator, in any conductor iteration) are about to claim PASS or DONE for a transition, verify the artifact exists AND the content matches `evidence_expectations` BEFORE writing the verdict. This is V3 codified at the meta-level: you are applying anti-LGTM to your own work.

This means: even in conductor mode (operator-of-the-skill), the anti-LGTM check applies. Self-application of the discipline is the V3 finding's logical extension.

## See Also

- Spec: `docs/superpowers/specs/2026-05-12-goalv3-cc-fusion-design.md` — Edge Case #4 (line 423-424), Anti-LGTM Invariant #1 (line 435), Design Note "Anti-LGTM as system invariant codification" (line 564-566)
- Decision log: D12 (V3 emergent pattern codified as system invariant)
- Codex source: `~/.codex/memories/MEMORY.md` — task group "Bounded Supervisor Review Gate v0"
````

- [ ] **Step 2: Verify presence**

```bash
test -f ~/.claude/skills/goalv3-cc/references/codex-emergent-pattern.md && wc -l ~/.claude/skills/goalv3-cc/references/codex-emergent-pattern.md
```

Expected: file exists, line count ~70-90.

---

## Task 6: Script — `state-init.sh` (TDD)

**Files:**
- Create: `~/.claude/skills/goalv3-cc/scripts/state-init.sh`
- Test: `/tmp/goalv3-cc-test-state-init.sh` (ephemeral, deleted after pass)

Purpose: Initialize `.goal/<goal-id>/` directory with starting `state.json` template, set first history entry (GOAL_CAPTURED → DESIGNING with timestamp + trigger).

Spec source: lines 108-121 (per-goal directory layout) + lines 209-232 (state.json schema).

- [ ] **Step 1: Write the failing test**

Write `/tmp/goalv3-cc-test-state-init.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

# Call the script under test (takes goal_id as $1, tier as $2)
bash ~/.claude/skills/goalv3-cc/scripts/state-init.sh "test-goal-123" "standard"

# Assert directory exists
test -d ".goal/test-goal-123" || { echo "FAIL: .goal/test-goal-123 not created"; exit 1; }
test -d ".goal/test-goal-123/history" || { echo "FAIL: history/ not created"; exit 1; }

# Assert state.json valid + correct fields
STATE=".goal/test-goal-123/state.json"
test -f "$STATE" || { echo "FAIL: state.json not written"; exit 1; }

jq -e '.goal_id == "test-goal-123"' "$STATE" >/dev/null || { echo "FAIL: goal_id mismatch"; exit 1; }
jq -e '.current_state == "GOAL_CAPTURED"' "$STATE" >/dev/null || { echo "FAIL: initial state wrong"; exit 1; }
jq -e '.tier == "standard"' "$STATE" >/dev/null || { echo "FAIL: tier mismatch"; exit 1; }
jq -e '.in_flight == []' "$STATE" >/dev/null || { echo "FAIL: in_flight not empty"; exit 1; }
jq -e '.seen_dedupe_keys == []' "$STATE" >/dev/null || { echo "FAIL: seen_dedupe_keys not empty"; exit 1; }
jq -e '.cooldowns == {}' "$STATE" >/dev/null || { echo "FAIL: cooldowns not empty"; exit 1; }
jq -e '.history | length == 1' "$STATE" >/dev/null || { echo "FAIL: history should have 1 entry"; exit 1; }
jq -e '.history[0].to == "GOAL_CAPTURED"' "$STATE" >/dev/null || { echo "FAIL: history[0].to wrong"; exit 1; }
jq -e '.history[0].trigger == "skill-load"' "$STATE" >/dev/null || { echo "FAIL: history[0].trigger wrong"; exit 1; }

# Assert idempotent: second invocation should detect existing state and NOT clobber
sleep 1
bash ~/.claude/skills/goalv3-cc/scripts/state-init.sh "test-goal-123" "standard" 2>&1 | grep -q "already initialized" || { echo "FAIL: second run should warn about existing state"; exit 1; }

# Cleanup
cd - >/dev/null
rm -rf "$WORKDIR"

echo "PASS: state-init.sh tests"
```

- [ ] **Step 2: Run test to verify it fails (script doesn't exist yet)**

```bash
bash /tmp/goalv3-cc-test-state-init.sh
```

Expected: FAIL with "No such file" or similar (script not yet written).

- [ ] **Step 3: Write `state-init.sh`**

Write `~/.claude/skills/goalv3-cc/scripts/state-init.sh`:

```bash
#!/usr/bin/env bash
# state-init.sh — initialize .goal/<goal-id>/ with starting state.json
# Usage: state-init.sh <goal_id> <tier>
# Idempotent: if state.json exists, prints warning + exits 0 without clobbering.

set -euo pipefail

GOAL_ID="${1:?goal_id required}"
TIER="${2:?tier required (fast|standard|heavy)}"

case "$TIER" in
  fast|standard|heavy) ;;
  *) echo "ERROR: tier must be fast|standard|heavy, got '$TIER'"; exit 2 ;;
esac

GOAL_DIR=".goal/${GOAL_ID}"
STATE_FILE="${GOAL_DIR}/state.json"

if [ -f "$STATE_FILE" ]; then
  echo "WARN: state already initialized at $STATE_FILE (skipping re-init)"
  exit 0
fi

mkdir -p "${GOAL_DIR}/history"
touch "${GOAL_DIR}/dispatch-log.jsonl"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$STATE_FILE" <<EOF
{
  "goal_id": "${GOAL_ID}",
  "current_state": "GOAL_CAPTURED",
  "tier": "${TIER}",
  "started_at": "${NOW}",
  "last_transition_at": "${NOW}",
  "in_flight": [],
  "seen_dedupe_keys": [],
  "cooldowns": {},
  "frozen_lanes": [],
  "operator_overrides": {},
  "history": [
    {"from": null, "to": "GOAL_CAPTURED", "at": "${NOW}", "trigger": "skill-load"}
  ],
  "operator_calls": [],
  "verdict": null
}
EOF

# Validate JSON
jq empty "$STATE_FILE" || { echo "ERROR: produced invalid JSON"; exit 3; }

echo "OK: initialized $STATE_FILE (tier=$TIER)"
```

```bash
chmod +x ~/.claude/skills/goalv3-cc/scripts/state-init.sh
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash /tmp/goalv3-cc-test-state-init.sh
```

Expected: `PASS: state-init.sh tests`.

- [ ] **Step 5: Cleanup test artifact**

```bash
rm /tmp/goalv3-cc-test-state-init.sh
```

(Test is ephemeral; we keep the proven script only.)

---

## Task 7: Script — `dispatch.sh` (TDD)

**Files:**
- Create: `~/.claude/skills/goalv3-cc/scripts/dispatch.sh`
- Test: `/tmp/goalv3-cc-test-dispatch.sh` (ephemeral)

Purpose: Pre-dispatch gate. Checks (1) max_active not exceeded, (2) dedupe_key not currently in-flight or already PASS-completed, (3) cooldown elapsed. Returns 0 (proceed) or non-zero (skip + log). Does NOT actually invoke Task tool — that's the skill body's job; this script gives a yes/no.

Spec source: lines 316-371 (Bounded Supervisor Review Gate) + lines 324-338 (max_active + dedupe + cooldown).

- [ ] **Step 1: Write the failing test**

Write `/tmp/goalv3-cc-test-dispatch.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

# Setup: initial state.json with one in_flight, one prior PASS dedupe, one cooldown
mkdir -p .goal/test-dispatch/history
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PAST=$(date -u -v-30M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '30 minutes ago' +"%Y-%m-%dT%H:%M:%SZ")
RECENT=$(date -u -v-5M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '5 minutes ago' +"%Y-%m-%dT%H:%M:%SZ")

cat > .goal/test-dispatch/state.json <<EOF
{
  "goal_id": "test-dispatch",
  "current_state": "DISPATCHING",
  "tier": "standard",
  "in_flight": [{"task_id": "T1", "dedupe_key": "test-dispatch/route-a-aaaaa"}],
  "seen_dedupe_keys": ["test-dispatch/route-b-bbbbb"],
  "cooldowns": {
    "test-dispatch/route-b-bbbbb": {"last_dispatch": "${RECENT}", "cooldown_until": "$(date -u -v+10M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '+10 minutes' +"%Y-%m-%dT%H:%M:%SZ")"},
    "test-dispatch/route-c-ccccc": {"last_dispatch": "${PAST}", "cooldown_until": "${PAST}"}
  },
  "frozen_lanes": [],
  "history": []
}
EOF

SCRIPT=~/.claude/skills/goalv3-cc/scripts/dispatch.sh

# Test 1: dedupe collision — already in_flight
OUT=$(bash "$SCRIPT" test-dispatch test-dispatch/route-a-aaaaa standard 2 15 2>&1 || true)
echo "$OUT" | grep -q "skip-in-flight" || { echo "FAIL test1: expected skip-in-flight, got: $OUT"; exit 1; }

# Test 2: dedupe collision — already PASS (in seen)
OUT=$(bash "$SCRIPT" test-dispatch test-dispatch/route-b-bbbbb standard 2 15 2>&1 || true)
echo "$OUT" | grep -q "skip-already-pass" || { echo "FAIL test2: expected skip-already-pass, got: $OUT"; exit 1; }

# Test 3: cooldown active
OUT=$(bash "$SCRIPT" test-dispatch test-dispatch/route-b-bbbbb-2 standard 2 15 2>&1 || true)
# route-b-bbbbb-2 is fresh key, but we'll add cooldown for it dynamically
jq '.cooldowns["test-dispatch/route-b-bbbbb-2"] = {"last_dispatch":"'${RECENT}'","cooldown_until":"'$(date -u -v+10M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '+10 minutes' +"%Y-%m-%dT%H:%M:%SZ")'"}' .goal/test-dispatch/state.json > /tmp/s.json && mv /tmp/s.json .goal/test-dispatch/state.json
OUT=$(bash "$SCRIPT" test-dispatch test-dispatch/route-b-bbbbb-2 standard 2 15 2>&1 || true)
echo "$OUT" | grep -q "skip-cooldown" || { echo "FAIL test3: expected skip-cooldown, got: $OUT"; exit 1; }

# Test 4: max_active exceeded
# Bump in_flight to 2 items, max_active=2 → next dispatch must skip
jq '.in_flight += [{"task_id":"T2","dedupe_key":"test-dispatch/route-d-ddddd"}]' .goal/test-dispatch/state.json > /tmp/s.json && mv /tmp/s.json .goal/test-dispatch/state.json
OUT=$(bash "$SCRIPT" test-dispatch test-dispatch/route-e-eeeee standard 2 15 2>&1 || true)
echo "$OUT" | grep -q "skip-max-active" || { echo "FAIL test4: expected skip-max-active, got: $OUT"; exit 1; }

# Test 5: clean dispatch allowed (cooldown elapsed, no collision, in_flight under max)
jq '.in_flight = [] | .seen_dedupe_keys = []' .goal/test-dispatch/state.json > /tmp/s.json && mv /tmp/s.json .goal/test-dispatch/state.json
OUT=$(bash "$SCRIPT" test-dispatch test-dispatch/route-fresh-fffff standard 2 15 2>&1)
echo "$OUT" | grep -q "proceed" || { echo "FAIL test5: expected proceed, got: $OUT"; exit 1; }

cd - >/dev/null
rm -rf "$WORKDIR"

echo "PASS: dispatch.sh tests"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash /tmp/goalv3-cc-test-dispatch.sh
```

Expected: FAIL (script not yet written).

- [ ] **Step 3: Write `dispatch.sh`**

Write `~/.claude/skills/goalv3-cc/scripts/dispatch.sh`:

```bash
#!/usr/bin/env bash
# dispatch.sh — pre-dispatch gate for goalv3-cc
# Usage: dispatch.sh <goal_id> <dedupe_key> <tier> <max_active> <cooldown_minutes>
# Outputs: "proceed" + exit 0, OR "skip-<reason>" + exit non-zero (does not abort caller, caller decides)
# Reasons: skip-in-flight, skip-already-pass, skip-cooldown, skip-max-active, skip-frozen-lane

set -euo pipefail

GOAL_ID="${1:?goal_id required}"
DEDUPE_KEY="${2:?dedupe_key required}"
TIER="${3:?tier required}"
MAX_ACTIVE="${4:?max_active required}"
COOLDOWN_MIN="${5:?cooldown_minutes required}"

STATE=".goal/${GOAL_ID}/state.json"
test -f "$STATE" || { echo "skip-no-state"; exit 4; }

# Check 1: dedupe_key in in_flight?
IN_FLIGHT_HIT=$(jq -r --arg k "$DEDUPE_KEY" '.in_flight[] | select(.dedupe_key == $k) | .task_id' "$STATE" | head -1)
if [ -n "$IN_FLIGHT_HIT" ]; then
  echo "skip-in-flight (task=$IN_FLIGHT_HIT, key=$DEDUPE_KEY)"
  exit 1
fi

# Check 2: dedupe_key in seen (already PASS)?
SEEN_HIT=$(jq -r --arg k "$DEDUPE_KEY" '.seen_dedupe_keys[] | select(. == $k)' "$STATE" | head -1)
if [ -n "$SEEN_HIT" ]; then
  echo "skip-already-pass (key=$DEDUPE_KEY)"
  exit 1
fi

# Check 3: cooldown active?
COOLDOWN_UNTIL=$(jq -r --arg k "$DEDUPE_KEY" '.cooldowns[$k].cooldown_until // empty' "$STATE")
if [ -n "$COOLDOWN_UNTIL" ]; then
  NOW_EPOCH=$(date -u +%s)
  # Try GNU date, then BSD date
  COOL_EPOCH=$(date -u -d "$COOLDOWN_UNTIL" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$COOLDOWN_UNTIL" +%s 2>/dev/null || echo 0)
  if [ "$NOW_EPOCH" -lt "$COOL_EPOCH" ]; then
    REMAIN=$((COOL_EPOCH - NOW_EPOCH))
    echo "skip-cooldown (key=$DEDUPE_KEY, remaining=${REMAIN}s, until=$COOLDOWN_UNTIL)"
    exit 1
  fi
fi

# Check 4: frozen_lanes — extract route prefix from dedupe_key (everything before final /-hash)
LANE_PREFIX="${DEDUPE_KEY%/*}"
FROZEN_HIT=$(jq -r --arg l "$LANE_PREFIX" '.frozen_lanes[] | select(. == $l)' "$STATE" | head -1)
if [ -n "$FROZEN_HIT" ]; then
  echo "skip-frozen-lane (lane=$LANE_PREFIX)"
  exit 1
fi

# Check 5: max_active not exceeded
IN_FLIGHT_COUNT=$(jq -r '.in_flight | length' "$STATE")
if [ "$IN_FLIGHT_COUNT" -ge "$MAX_ACTIVE" ]; then
  echo "skip-max-active (in_flight=$IN_FLIGHT_COUNT, max=$MAX_ACTIVE)"
  exit 1
fi

# All checks passed
echo "proceed (key=$DEDUPE_KEY, in_flight=$IN_FLIGHT_COUNT/$MAX_ACTIVE)"
exit 0
```

```bash
chmod +x ~/.claude/skills/goalv3-cc/scripts/dispatch.sh
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash /tmp/goalv3-cc-test-dispatch.sh
```

Expected: `PASS: dispatch.sh tests`.

- [ ] **Step 5: Cleanup test**

```bash
rm /tmp/goalv3-cc-test-dispatch.sh
```

---

## Task 8: Script — `verdict-parse.sh` (TDD)

**Files:**
- Create: `~/.claude/skills/goalv3-cc/scripts/verdict-parse.sh`
- Test: `/tmp/goalv3-cc-test-verdict.sh` (ephemeral)

Purpose: Apply 4-source verdict ladder to a subagent's return. Output: `VERDICT|SOURCE|EVIDENCE_NOTE`. **Critical**: this is where anti-LGTM override happens. If source 1 says PASS but source 3 says artifact missing, output FLAG with override note.

Spec source: lines 305-312 (4-source priority ladder) + line 423-424 (Edge Case #4 anti-LGTM trigger) + line 435 (Invariant #1).

- [ ] **Step 1: Write the failing test**

Write `/tmp/goalv3-cc-test-verdict.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

WORKDIR=$(mktemp -d)
cd "$WORKDIR"
SCRIPT=~/.claude/skills/goalv3-cc/scripts/verdict-parse.sh

# Test 1: explicit VERDICT in stdout (source 1) + artifact exists → PASS
mkdir -p .goal/t/
echo "Some content" > .goal/t/artifact.md
cat > /tmp/subagent-out-1.txt <<EOF
Did the thing.
VERDICT: PASS
EOF
OUT=$(bash "$SCRIPT" /tmp/subagent-out-1.txt "VERDICT: (PASS|FLAG|BLOCK)" .goal/t/artifact.md)
echo "$OUT" | grep -q "^PASS|source-1" || { echo "FAIL test1: $OUT"; exit 1; }

# Test 2: CRITICAL — claimed PASS but artifact MISSING → override to FLAG
cat > /tmp/subagent-out-2.txt <<EOF
Did the thing! All done.
VERDICT: PASS
EOF
OUT=$(bash "$SCRIPT" /tmp/subagent-out-2.txt "VERDICT: (PASS|FLAG|BLOCK)" .goal/t/missing-artifact.md)
echo "$OUT" | grep -q "^FLAG|override-anti-lgtm" || { echo "FAIL test2 ANTI-LGTM OVERRIDE BROKEN: $OUT"; exit 1; }

# Test 3: no explicit VERDICT, stdout pattern match (source 2)
cat > /tmp/subagent-out-3.txt <<EOF
Some output
RESULT: PASS - completed successfully
EOF
OUT=$(bash "$SCRIPT" /tmp/subagent-out-3.txt "RESULT: (PASS|FLAG|BLOCK)" .goal/t/artifact.md)
echo "$OUT" | grep -q "^PASS|source-2" || { echo "FAIL test3: $OUT"; exit 1; }

# Test 4: no explicit, no pattern, artifact present + non-empty (source 3)
cat > /tmp/subagent-out-4.txt <<EOF
Did the work without a verdict line.
EOF
OUT=$(bash "$SCRIPT" /tmp/subagent-out-4.txt "VERDICT: (PASS|FLAG|BLOCK)" .goal/t/artifact.md)
echo "$OUT" | grep -q "^PASS|source-3" || { echo "FAIL test4: $OUT"; exit 1; }

# Test 5: heuristic — has "error" in output (source 4 → FLAG)
cat > /tmp/subagent-out-5.txt <<EOF
Something happened.
error: file not found
EOF
OUT=$(bash "$SCRIPT" /tmp/subagent-out-5.txt "VERDICT: (PASS|FLAG|BLOCK)" .goal/t/missing.md)
echo "$OUT" | grep -q "^FLAG|source-4" || { echo "FAIL test5: $OUT"; exit 1; }

# Test 6: explicit refuse → BLOCK
cat > /tmp/subagent-out-6.txt <<EOF
I cannot do this task because it requires permission.
VERDICT: BLOCK
EOF
OUT=$(bash "$SCRIPT" /tmp/subagent-out-6.txt "VERDICT: (PASS|FLAG|BLOCK)" .goal/t/missing.md)
echo "$OUT" | grep -q "^BLOCK|source-1" || { echo "FAIL test6: $OUT"; exit 1; }

# Test 7: explicit FLAG → accepted (no override needed)
cat > /tmp/subagent-out-7.txt <<EOF
I'm not sure if this is right.
VERDICT: FLAG
EOF
OUT=$(bash "$SCRIPT" /tmp/subagent-out-7.txt "VERDICT: (PASS|FLAG|BLOCK)" .goal/t/missing.md)
echo "$OUT" | grep -q "^FLAG|source-1" || { echo "FAIL test7: $OUT"; exit 1; }

# Cleanup
cd - >/dev/null
rm -rf "$WORKDIR"
rm -f /tmp/subagent-out-*.txt

echo "PASS: verdict-parse.sh tests"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash /tmp/goalv3-cc-test-verdict.sh
```

Expected: FAIL.

- [ ] **Step 3: Write `verdict-parse.sh`**

Write `~/.claude/skills/goalv3-cc/scripts/verdict-parse.sh`:

```bash
#!/usr/bin/env bash
# verdict-parse.sh — 4-source priority ladder for subagent verdict extraction
# Usage: verdict-parse.sh <subagent-output-file> <stdout-pattern-regex> <expected-artifact-path>
# Output: VERDICT|source-N|note  (one line)
#   VERDICT in {PASS, FLAG, BLOCK}
#   source-N in {source-1, source-2, source-3, source-4, override-anti-lgtm}
#   note: free-text justification
#
# Source ladder (priority descending):
#   1. Explicit VERDICT: line in subagent output
#   2. Custom stdout pattern match
#   3. Artifact existence + non-empty
#   4. Heuristic on output text
#
# Anti-LGTM override: if source-1 says PASS but artifact missing/empty → override to FLAG.

set -euo pipefail

OUT_FILE="${1:?subagent output file required}"
PATTERN="${2:?stdout pattern regex required}"
ARTIFACT="${3:-/dev/null}"

test -f "$OUT_FILE" || { echo "BLOCK|source-error|output file missing: $OUT_FILE"; exit 1; }

OUTPUT=$(cat "$OUT_FILE")

# Source 1: explicit VERDICT: PASS|FLAG|BLOCK line
EXPLICIT=$(echo "$OUTPUT" | grep -oE "VERDICT: (PASS|FLAG|BLOCK)" | head -1 | awk '{print $2}' || true)

# Check artifact existence + non-empty (used by source 3 AND anti-LGTM override)
ARTIFACT_OK=false
if [ -f "$ARTIFACT" ] && [ -s "$ARTIFACT" ]; then
  ARTIFACT_OK=true
fi

if [ -n "$EXPLICIT" ]; then
  # Anti-LGTM override: explicit PASS but artifact missing/empty → FLAG
  if [ "$EXPLICIT" = "PASS" ] && [ "$ARTIFACT_OK" = "false" ]; then
    echo "FLAG|override-anti-lgtm|claimed PASS but artifact missing or empty at: $ARTIFACT"
    exit 0
  fi
  echo "${EXPLICIT}|source-1|explicit VERDICT line in subagent output"
  exit 0
fi

# Source 2: custom stdout pattern
PATTERN_MATCH=$(echo "$OUTPUT" | grep -oE "$PATTERN" | head -1 || true)
if [ -n "$PATTERN_MATCH" ]; then
  # Extract verdict word from match (last word)
  V=$(echo "$PATTERN_MATCH" | grep -oE "(PASS|FLAG|BLOCK)" | head -1)
  if [ -n "$V" ]; then
    # Same anti-LGTM override
    if [ "$V" = "PASS" ] && [ "$ARTIFACT_OK" = "false" ]; then
      echo "FLAG|override-anti-lgtm|pattern matched PASS but artifact missing: $ARTIFACT"
      exit 0
    fi
    echo "${V}|source-2|stdout pattern match: $PATTERN"
    exit 0
  fi
fi

# Source 3: artifact exists and non-empty
if [ "$ARTIFACT_OK" = "true" ]; then
  echo "PASS|source-3|artifact present at $ARTIFACT (no explicit verdict)"
  exit 0
fi

# Source 4: heuristic on output text
if echo "$OUTPUT" | grep -qiE "^I cannot|I refuse|I won't"; then
  echo "BLOCK|source-4|heuristic: refusal phrase detected"
  exit 0
fi
if echo "$OUTPUT" | grep -qiE "error|fail|timeout|exception"; then
  echo "FLAG|source-4|heuristic: error/fail/timeout/exception in output"
  exit 0
fi
if echo "$OUTPUT" | grep -qiE "done|complete|finished"; then
  echo "PASS|source-4|heuristic: completion claim without artifact (weak signal — operator should review)"
  exit 0
fi

echo "FLAG|source-4|heuristic: no verdict, no pattern match, no artifact, no clear signal"
exit 0
```

```bash
chmod +x ~/.claude/skills/goalv3-cc/scripts/verdict-parse.sh
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash /tmp/goalv3-cc-test-verdict.sh
```

Expected: `PASS: verdict-parse.sh tests`. **Pay special attention to Test 2 (anti-LGTM override)** — if that one fails, the V3 invariant is broken.

- [ ] **Step 5: Cleanup test**

```bash
rm /tmp/goalv3-cc-test-verdict.sh
```

---

## Task 9: Script — `closeout-validate.sh` (TDD)

**Files:**
- Create: `~/.claude/skills/goalv3-cc/scripts/closeout-validate.sh`
- Test: `/tmp/goalv3-cc-test-closeout.sh` (ephemeral)

Purpose: Pre-DONE validation gate. Runs 5 checks from spec invariant #4. Returns exit 0 + "OK" on all-pass, non-zero + list of failures otherwise.

Spec source: lines 438-444 (5 validation checks).

- [ ] **Step 1: Write the failing test**

Write `/tmp/goalv3-cc-test-closeout.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

WORKDIR=$(mktemp -d)
cd "$WORKDIR"
SCRIPT=~/.claude/skills/goalv3-cc/scripts/closeout-validate.sh

mkdir -p .goal/t/history

# Test 1: all 5 checks pass
cat > .goal/t/state.json <<'EOF'
{
  "goal_id": "t",
  "current_state": "ARCHIVING",
  "in_flight": [],
  "seen_dedupe_keys": ["t/route-a"],
  "history": [
    {"to": "GOAL_CAPTURED", "at": "t1"},
    {"to": "DESIGNING", "at": "t2"}
  ],
  "operator_calls": []
}
EOF
cat > .goal/t/dispatch-log.jsonl <<'EOF'
{"task_id":"T1","dedupe_key":"t/route-a","verdict":"PASS","evidence_summary":"did the thing"}
EOF
cat > .goal/t/closeout.md <<'EOF'
evidence_harvested: did the thing successfully
verdict: PASS
EOF

OUT=$(bash "$SCRIPT" t 2>&1)
echo "$OUT" | grep -q "^OK" || { echo "FAIL test1: expected OK, got: $OUT"; exit 1; }

# Test 2: check 1 fails — dispatched task has no verdict
cat > .goal/t/dispatch-log.jsonl <<'EOF'
{"task_id":"T1","dedupe_key":"t/route-a","verdict":"PASS"}
{"task_id":"T2","dedupe_key":"t/route-b"}
EOF
OUT=$(bash "$SCRIPT" t 2>&1 || true)
echo "$OUT" | grep -q "check-1-FAIL" || { echo "FAIL test2: expected check-1-FAIL, got: $OUT"; exit 1; }

# Test 3: check 2 fails — duplicate in_flight dedupe_key
cat > .goal/t/dispatch-log.jsonl <<'EOF'
{"task_id":"T1","dedupe_key":"t/route-a","verdict":"PASS"}
EOF
jq '.in_flight = [{"task_id":"T9","dedupe_key":"t/dup"},{"task_id":"T10","dedupe_key":"t/dup"}]' .goal/t/state.json > /tmp/s.json && mv /tmp/s.json .goal/t/state.json
OUT=$(bash "$SCRIPT" t 2>&1 || true)
echo "$OUT" | grep -q "check-2-FAIL" || { echo "FAIL test3: expected check-2-FAIL, got: $OUT"; exit 1; }

# Test 4: check 3 fails — in_flight not empty
jq '.in_flight = [{"task_id":"T9","dedupe_key":"t/still-going"}]' .goal/t/state.json > /tmp/s.json && mv /tmp/s.json .goal/t/state.json
OUT=$(bash "$SCRIPT" t 2>&1 || true)
echo "$OUT" | grep -q "check-3-FAIL" || { echo "FAIL test4: expected check-3-FAIL, got: $OUT"; exit 1; }

# Test 5: check 4 fails — closeout.md missing evidence_harvested
jq '.in_flight = []' .goal/t/state.json > /tmp/s.json && mv /tmp/s.json .goal/t/state.json
cat > .goal/t/closeout.md <<'EOF'
verdict: PASS
EOF
OUT=$(bash "$SCRIPT" t 2>&1 || true)
echo "$OUT" | grep -q "check-4-FAIL" || { echo "FAIL test5: expected check-4-FAIL, got: $OUT"; exit 1; }

# Test 6: check 5 fails — operator_calls history claims BLOCK but no OPERATOR_NEEDED entry
cat > .goal/t/closeout.md <<'EOF'
evidence_harvested: did things
verdict: PASS
EOF
jq '.history += [{"to":"BLOCKER_CLASSIFIED","at":"tX","blocker_type":"permission"}]' .goal/t/state.json > /tmp/s.json && mv /tmp/s.json .goal/t/state.json
OUT=$(bash "$SCRIPT" t 2>&1 || true)
echo "$OUT" | grep -q "check-5-FAIL" || { echo "FAIL test6: expected check-5-FAIL, got: $OUT"; exit 1; }

cd - >/dev/null
rm -rf "$WORKDIR"

echo "PASS: closeout-validate.sh tests"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash /tmp/goalv3-cc-test-closeout.sh
```

Expected: FAIL.

- [ ] **Step 3: Write `closeout-validate.sh`**

Write `~/.claude/skills/goalv3-cc/scripts/closeout-validate.sh`:

```bash
#!/usr/bin/env bash
# closeout-validate.sh — pre-DONE 5-check validation gate for goalv3-cc
# Usage: closeout-validate.sh <goal_id>
# Output: "OK" + exit 0, OR list of "check-N-FAIL: reason" lines + exit non-zero

set -euo pipefail

GOAL_ID="${1:?goal_id required}"
GOAL_DIR=".goal/${GOAL_ID}"
STATE="${GOAL_DIR}/state.json"
LOG="${GOAL_DIR}/dispatch-log.jsonl"
CLOSEOUT="${GOAL_DIR}/closeout.md"

test -f "$STATE" || { echo "check-pre-FAIL: state.json missing"; exit 2; }
test -f "$LOG" || { echo "check-pre-FAIL: dispatch-log.jsonl missing"; exit 2; }
test -f "$CLOSEOUT" || { echo "check-pre-FAIL: closeout.md missing"; exit 2; }

FAILS=()

# Check 1: every dispatched task has verdict OR cancelled:true
while IFS= read -r line; do
  [ -z "$line" ] && continue
  VERDICT=$(echo "$line" | jq -r '.verdict // empty')
  CANCELLED=$(echo "$line" | jq -r '.cancelled // false')
  TASK_ID=$(echo "$line" | jq -r '.task_id')
  if [ -z "$VERDICT" ] && [ "$CANCELLED" != "true" ]; then
    FAILS+=("check-1-FAIL: task $TASK_ID has no verdict and not cancelled")
  fi
done < "$LOG"

# Check 2: no duplicate dedupe_keys in in_flight
DUP_COUNT=$(jq -r '.in_flight | group_by(.dedupe_key) | map(select(length > 1)) | length' "$STATE")
if [ "$DUP_COUNT" -gt 0 ]; then
  DUPS=$(jq -r '.in_flight | group_by(.dedupe_key) | map(select(length > 1) | .[0].dedupe_key) | join(",")' "$STATE")
  FAILS+=("check-2-FAIL: duplicate dedupe_keys in_flight: $DUPS")
fi

# Check 3: in_flight is empty (self-cancel condition)
INFLIGHT_COUNT=$(jq -r '.in_flight | length' "$STATE")
if [ "$INFLIGHT_COUNT" -gt 0 ]; then
  FAILS+=("check-3-FAIL: in_flight still has $INFLIGHT_COUNT tasks (not self-cancelled)")
fi

# Check 4: closeout.md has evidence_harvested
if ! grep -q "evidence_harvested:" "$CLOSEOUT"; then
  FAILS+=("check-4-FAIL: closeout.md missing 'evidence_harvested:' field")
fi

# Check 5: every BLOCKER_CLASSIFIED history entry has a matching OPERATOR_NEEDED transition
BLOCKER_COUNT=$(jq -r '[.history[] | select(.to == "BLOCKER_CLASSIFIED")] | length' "$STATE")
OPERATOR_COUNT=$(jq -r '[.history[] | select(.to == "OPERATOR_NEEDED")] | length' "$STATE")
# Each blocker should produce at least one operator-needed (loose check — equality not strict)
if [ "$BLOCKER_COUNT" -gt 0 ] && [ "$OPERATOR_COUNT" -lt 1 ]; then
  FAILS+=("check-5-FAIL: $BLOCKER_COUNT BLOCKER_CLASSIFIED entries but no OPERATOR_NEEDED transitions")
fi

if [ "${#FAILS[@]}" -eq 0 ]; then
  echo "OK: all 5 checks passed for goal=$GOAL_ID"
  exit 0
fi

for f in "${FAILS[@]}"; do
  echo "$f"
done
exit 1
```

```bash
chmod +x ~/.claude/skills/goalv3-cc/scripts/closeout-validate.sh
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash /tmp/goalv3-cc-test-closeout.sh
```

Expected: `PASS: closeout-validate.sh tests`.

- [ ] **Step 5: Cleanup test**

```bash
rm /tmp/goalv3-cc-test-closeout.sh
```

---

## Task 10: SKILL.md — frontmatter + Section 1 (When to activate) + Section 2 (Architecture overview)

**Files:**
- Create: `~/.claude/skills/goalv3-cc/SKILL.md`

Spec source: frontmatter lines 480-499 + section 1 (~30 lines) + section 2 (~60 lines from spec lines 65-127).

- [ ] **Step 1: Write frontmatter + sections 1-2**

Create `~/.claude/skills/goalv3-cc/SKILL.md` starting with this content (subsequent tasks append more sections):

````markdown
---
name: goalv3-cc
description: |
  Load when operator says "/goal" with V3 contract / "goalv3-cc" / "use goalv3-cc to ..."
  / wants persistent multi-stage autonomous work with Bounded Supervisor Review Gate +
  anti-LGTM verdict override at every stage transition. Two-layer conductor (Design +
  Dispatch) produces Decision Packets, dispatches subagents via Task tool synchronously
  by default, claude --bg opt-in for parallel heavy work. Self-Awareness Bootstrap on
  heavy path. State at .goal/<goal-id>/. Anti-LGTM is system invariant — if subagent
  claims PASS but evidence missing, conductor overrides to FLAG automatically.
metadata:
  version: 0.1.0
  closeout_layers: [0, 1, 2, 3]
  inspired_by:
    - Multica Workbench Goal Mode v2 (operator design)
    - Codex GPT-5.5 emergent self-dispatch + self-anti-LGTM pattern (operator finding 2026-05-12)
    - CC /goal (Anthropic, v2.1.139)
    - CC agent view (Anthropic, v2.1.139)
---

# goalv3-cc — Two-Layer Autonomous Conductor with Anti-LGTM as System Invariant

## 1. When to activate

**Activate when operator:**
- Says "use goalv3-cc to <X>" or "/goal X with V3 contract"
- Has a multi-stage goal that benefits from explicit Decision Packets + verdict gating
- Wants Bounded Supervisor Review Gate (max_active, dedupe, cooldown) for noisy domains
- Wants the conductor to enforce anti-LGTM at every stage transition (not just at human review)
- Is dogfooding the V3 pattern (this skill driving its own implementation tests)

**Do NOT activate when:**
- Operator wants a single-shot lookup or trivial answer (use direct tools — no conductor needed)
- Operator is in a different skill's flow (e.g. inside `superpowers:writing-plans` finishing a plan — finish that flow first)
- The goal is purely UI / design feedback (use design-* skills)
- The goal touches `~/multica-ultimate-workbench/autopilots/` or `~/.codex/` — these are operator-locked lanes; abort with operator-call

**Refuse to activate during these states:**
- Operator just said "stop" / "pause" / "halt" within the last 2 messages
- A higher-priority skill is mid-flow (gsd-* execution, ralph-loop iteration)
- `frozen_lanes` in any existing `.goal/<id>/state.json` of the current goal includes the route this invocation would touch

## 2. Architecture overview

### State Machine (V2 full 9 states)

```
GOAL_CAPTURED
   ↓
DESIGNING  ← Self-Awareness Bootstrap (heavy path only)
   ↓
DECISION_PACKET (verdict: READY_TO_DISPATCH | NEEDS_DESIGN | OPERATOR_NEEDED)
   ↓
DISPATCHING → spawn Task subagent(s), max 2 in-flight (Bounded Supervisor Gate v0)
   ↓
OBSERVING → block on Task return (or yield to operator if --bg dispatch mode)
   ↓
REVIEWING → parse stdout for PASS/FLAG/BLOCK via 4-source ladder
   ├── PASS  → LEARNING → ARCHIVING → DONE
   ├── FLAG  → DISPATCHING (re-route with new packet)
   └── BLOCK → BLOCKER_CLASSIFIED
                  ├── operator-call → OPERATOR_NEEDED (skill yields)
                  ├── external      → COOLDOWN → DESIGNING (re-design after cooldown)
                  └── permanent     → ARCHIVED → DONE
```

### Two-layer in single CC session

- **Layer 1 (Design)**: skill main thread in primary session, maintains state machine, produces Decision Packets. The conductor.
- **Layer 2 (Dispatch)**: skill uses `Task` tool synchronously to spawn subagents. Each Task = one Decision Packet execution slot. `Agent` tool selects specialist subagent type per stage. Optional escape to `claude --bg` for parallel independent heavy work.

### Per-goal state directory layout (in CWD, NOT global)

```
.goal/<goal-id>/                    # project-local — gitignored
├── state.json                      # main state file, single source of truth
├── decision-packet.md              # current packet (snapshot to history/ on transition)
├── self-awareness.md               # heavy path only (DESIGNING prereq)
├── dispatch-log.jsonl              # append-only audit log
├── closeout.md                     # final contract (only at DONE state)
├── history/
│   ├── packet-v1.md                # historical packet snapshots
│   └── ...
└── operator-notes.md               # optional: operator-written context (skill auto-reads)
```

Multi-goal coexistence: `.goal/goal-A/`, `.goal/goal-B/`, etc. Each independent. Skill single-invoke handles single goal — operator specifies `goal_id` on invoke.

### Files this skill uses

- `scripts/state-init.sh <goal_id> <tier>` — initialize per-goal directory + state.json
- `scripts/dispatch.sh <goal_id> <dedupe_key> <tier> <max_active> <cooldown_min>` — pre-dispatch gate (max_active + dedupe + cooldown + frozen_lane checks)
- `scripts/verdict-parse.sh <subagent-out-file> <stdout-pattern> <expected-artifact>` — 4-source ladder + anti-LGTM override
- `scripts/closeout-validate.sh <goal_id>` — pre-DONE 5-check validation
- `references/decision-packet-template.md` — V2 14 + CC 3 field schema
- `references/self-awareness-template.md` — V2 11 field schema (heavy only)
- `references/closeout-template.md` — V2 9 + CC 3 field schema
- `references/codex-emergent-pattern.md` — V3 finding doc (the why)
````

- [ ] **Step 2: Verify line count + frontmatter + sections**

```bash
wc -l ~/.claude/skills/goalv3-cc/SKILL.md
head -1 ~/.claude/skills/goalv3-cc/SKILL.md  # should be ---
grep -c "^## " ~/.claude/skills/goalv3-cc/SKILL.md  # should be 2 after this task
```

Expected: ~110-130 lines, frontmatter starts with `---`, 2 section headers.

---

## Task 11: SKILL.md — Section 3 (Friction Tier Router)

**Files:**
- Modify: `~/.claude/skills/goalv3-cc/SKILL.md` (append)

Spec source: lines 244-272 (Friction Tier Router rubric + per-tier table).

- [ ] **Step 1: Append section 3**

Use Edit tool to add this section to the end of SKILL.md:

```markdown

## 3. Friction Tier Router

The skill auto-classifies every goal into one of three tiers in the DESIGNING state. Operator can override via Decision Packet `tier` field.

### Rubric

```
FAST     — 1-step answer / lookup / simple patch / info question
           Signals:
             • short goal text (< 20 words)
             • no cross-module touch (single file or no file)
             • no external system involvement
             • operator phrasing: "quick", "just", "tell me"
           Path: skip Self-Awareness Bootstrap, inline execute or 1 subagent.

STANDARD — single module with clear spec, no external mutation
           Signals:
             • scope = 1 module / 1 area
             • evidence_expectations = clear (specific file / pattern)
             • blast radius = low (no destructive ops)
           Path: skip Self-Awareness Bootstrap, Task spawn 1-2 sequential subagents.

HEAVY    — multi-domain / cross-system / high-stakes / migration / absorption
           Signals:
             • ≥ 2 modules touched
             • external system involved (codex, MCP, runtime)
             • mutation risk (file writes, config changes)
             • operator phrasing: "完整", "thorough", "全量", "carefully", "absorb",
               "migrate", "port", "consolidate"
           Path: Self-Awareness Bootstrap MANDATORY,
                 ≥ 3 specialist chain (architect → builder → reviewer + second-opinion).
```

### Per-tier dispatch behavior

| Tier | Self-Awareness | Task spawns | Specialist chain | Max parallel |
|---|---|---|---|---|
| fast | skip | 0–1 | inline or 1 | 1 |
| standard | skip | 1–2 sequential | 2 (do + review) | 1 |
| heavy | **required** | 3+ | architect → builder → reviewer → second-opinion | 2 |

### Tier persistence

Tier is persisted in `state.json` (top-level field) AND in the Decision Packet (`tier:` field). On re-design (FLAG → DISPATCHING), tier carries forward unless operator changes it explicitly.

### Operator override

If operator's Decision Packet specifies a tier different from auto-classification, **use the operator's choice**. Log the override in `dispatch-log.jsonl` with `tier_overridden: true` and the auto-classified tier in `tier_auto:`.
```

- [ ] **Step 2: Verify**

```bash
grep -c "^## " ~/.claude/skills/goalv3-cc/SKILL.md
grep -q "^## 3. Friction Tier Router" ~/.claude/skills/goalv3-cc/SKILL.md && echo OK || echo MISSING
```

Expected: section count = 3, section 3 present.

---

## Task 12: SKILL.md — Section 4 (Self-Awareness Bootstrap)

**Files:**
- Modify: `~/.claude/skills/goalv3-cc/SKILL.md` (append)

Spec source: lines 169-184 (11-field schema) + lines 261 (heavy-only).

- [ ] **Step 1: Append section 4**

Use Edit tool to append:

```markdown

## 4. Self-Awareness Bootstrap (heavy tier only)

Prerequisite for HEAVY tier goals. Written in `.goal/<goal-id>/self-awareness.md` during DESIGNING state, BEFORE producing the Decision Packet. Anchors all subsequent claims to verified facts (anti-hallucination at design time).

Skipped for FAST and STANDARD tiers — they don't justify the overhead.

### 11-field schema (V2 full)

See `references/self-awareness-template.md` for the schema + example. The 11 fields:

1. `runtime_identity` — CC version, model, effort, bare-mode status
2. `role_boundary` — what this skill owns + what it must not take over
3. `repo_anchor` — cwd, branch, authoritative source
4. `tool_envelope` — relevant tools available + verified
5. `mcp_envelope` — MCP servers visible + connected
6. `memory_sources_checked` — auto-memory paths, .learnings, RV state
7. `current_state_proof` — git status, recent commits, fixed state files
8. `risk_envelope` — public/private surface, destructive ops, runtime mutation, cost
9. `routing_decision` — inline / SDD / Task wave / specialist-chain / Supervisor
10. `success_metric` — the artifact that counts at DONE + how to verify
11. `operator_call_conditions` — small list of MUST-stop conditions (goal-specific + 7 generic)

Plus `verdict: READY | FLAG | BLOCK` gating progression to Decision Packet phase.

### Bootstrap execution

1. Skill reads `references/self-awareness-template.md` for schema reference.
2. Skill runs verification commands inline (`claude --version`, `git status`, `pwd`, etc.) — output goes into `current_state_proof`.
3. Skill writes filled YAML to `.goal/<goal-id>/self-awareness.md`.
4. If `verdict: FLAG` — re-bootstrap with missing info (e.g. unconnected MCP needs operator).
5. If `verdict: BLOCK` — transition to OPERATOR_NEEDED.
6. If `verdict: READY` — proceed to DECISION_PACKET state.

### Why heavy-only

Bootstrap is ~50 lines of YAML. For fast tier (1-step lookup), it's overhead. For heavy tier (multi-domain absorption), it's the anti-hallucination guarantee — every claim downstream cites it.

For standard tier: skill should produce a *mini* bootstrap inline (3-5 fields max — runtime_identity + repo_anchor + risk_envelope), but not write a separate file. This is implicit, not enforced.
```

- [ ] **Step 2: Verify**

```bash
grep -c "^## " ~/.claude/skills/goalv3-cc/SKILL.md
```

Expected: 4.

---

## Task 13: SKILL.md — Section 5 (Decision Packet)

**Files:**
- Modify: `~/.claude/skills/goalv3-cc/SKILL.md` (append)

Spec source: lines 132-167 (V2 14 + CC 3 fields).

- [ ] **Step 1: Append section 5**

```markdown

## 5. Decision Packet (V2 14 + CC 3 fields)

Decision Packet is the conductor's plan for one dispatch wave. Skill produces it in DESIGNING state, operator may modify, then it gates transition to DISPATCHING.

### Schema

See `references/decision-packet-template.md` for the full template + example. The 17 fields:

**V2 core (14)**:
`goal_id`, `intent`, `route`, `owner`, `reviewer`, `constraints`, `evidence_expectations`,
`non_goals`, `blocker_conditions`, `tier`, `dedupe_key`, `max_active`, `cooldown_minutes`,
`verdict` (READY_TO_DISPATCH | NEEDS_DESIGN | OPERATOR_NEEDED)

**CC-native (3)**:
`cc_task_descriptors`, `cc_specialist_chains`, `expected_artifacts`

**Optional override**:
`cc_dispatch_mode: task | bg` (default: `task`)

### dedupe_key format

`<goal_id>/<route-hash>` where route-hash = first 7 chars of SHA-256(route field). Stable across re-design.

### evidence_expectations

This field is load-bearing for the anti-LGTM override (section 7). It must specify EXACT artifacts or stdout patterns. Vague evidence_expectations defeat the verdict-parse 4-source ladder.

Good:
```
evidence_expectations:
  - file at .goal/X/artifact.md, contains section "Summary", word count 150-200
  - stdout pattern: "VERDICT: PASS"
```

Bad:
```
evidence_expectations: works correctly
```

### Packet lifecycle

1. **DESIGNING**: skill drafts packet using template, fills auto-inferable fields, leaves operator-required fields blank if heavy.
2. **Operator review** (heavy + ambiguous standard): operator reads packet, optionally edits.
3. **DISPATCHING gate**: skill runs `dispatch.sh <goal_id> <dedupe_key> <tier> <max_active> <cooldown_min>` to check Bounded Supervisor Gate.
4. **DISPATCHING execute**: if gate says `proceed`, skill spawns Task per `cc_task_descriptors[]` (or `claude --bg` if `cc_dispatch_mode: bg`).
5. **Packet history**: on transition out of REVIEWING, snapshot current packet to `.goal/<goal-id>/history/packet-v<N>.md`.

### Refreshing on FLAG

If REVIEWING produces FLAG, skill returns to DISPATCHING with a **new** packet that strengthens `evidence_expectations` and may change `owner` or `reviewer`. Old packet snapshotted; new packet gets new version number.
```

- [ ] **Step 2: Verify**

```bash
grep -c "^## " ~/.claude/skills/goalv3-cc/SKILL.md
```

Expected: 5.

---

## Task 14: SKILL.md — Section 6 (Dispatch protocol)

**Files:**
- Modify: `~/.claude/skills/goalv3-cc/SKILL.md` (append)

Spec source: lines 273-313 (Agent registry + dual primitive + recursive Skill calls).

- [ ] **Step 1: Append section 6**

```markdown

## 6. Dispatch protocol

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

### Verifying subagent availability

Before dispatch, verify subagent type is available:
1. Check if plugin enabled: `cat ~/.claude/settings.json | jq '.plugins // {}'`
2. Try a dry probe (Task with subagent_type, expect "not registered" error if missing)
3. If unavailable: try fallback from table above; if no fallback works → OPERATOR_NEEDED with "need to enable `<plugin>`".

### Two dispatch primitives

| `cc_dispatch_mode: task` (DEFAULT) | `cc_dispatch_mode: bg` (opt-in) |
|---|---|
| Skill uses `Task` synchronously | Skill uses `Bash` to run `claude --bg "<prompt>"` |
| Conductor blocks waiting for return | Conductor transitions OPERATOR_NEEDED + provides agent view guidance |
| Verdict parsed directly from Task return | Verdict via file hand-off (`.goal/<id>/dispatch-bg-<task-id>-evidence.md`) |
| Single session, transcript-only observability | Multi-session, `claude agents` shows all |
| Suits fast + standard + most heavy | Suits heavy + independent + long-running |

### When to use `--bg` (opt-in heavy/parallel)

- Phase 2-style multi-domain work where each lane is independent (chronicle / hooks / mcp / agents in absorb-codex)
- Each lane expected to take > 30 minutes wall clock
- Operator wants agent view (`claude agents`) visibility across lanes
- Operator-mediated approval gates between waves are acceptable (cannot auto-monitor)

### Recursive Skill tool calls (depth limit 2 hops)

Subagent context may invoke other skills:
- `superpowers:test-driven-development` — write tests first
- `superpowers:verification-before-completion` — closeout verify
- `superpowers:requesting-code-review` — trigger review pass
- `pua:pua` — quality enforcement when slipping

Hard limit: 2 hops (skill A → skill B → ... stop). If a sub-skill wants to invoke a third skill, that's a SDD/Plan-and-execute concern, not goalv3-cc.

### Bounded Supervisor Review Gate v0 enforcement

Before every Task spawn (and every `--bg` launch), skill runs:

```bash
bash ~/.claude/skills/goalv3-cc/scripts/dispatch.sh "$GOAL_ID" "$DEDUPE_KEY" "$TIER" "$MAX_ACTIVE" "$COOLDOWN_MIN"
```

Output:
- `proceed (...)` exit 0 → spawn subagent
- `skip-<reason>` exit 1 → log to `dispatch-log.jsonl`, do NOT spawn, post status note in transcript

Reasons + responses:
- `skip-in-flight`: same dedupe_key currently running → wait for completion (block in OBSERVING) or queue
- `skip-already-pass`: same dedupe_key already PASS → unless `evidence_expectations` changed, skip permanently
- `skip-cooldown`: within cooldown window → wait until elapsed, then retry
- `skip-max-active`: at max parallel → wait for one to complete
- `skip-frozen-lane`: operator-declared frozen → escalate OPERATOR_NEEDED
- `skip-no-state`: state.json missing → skill bug, escalate OPERATOR_NEEDED
```

- [ ] **Step 2: Verify**

```bash
grep -c "^## " ~/.claude/skills/goalv3-cc/SKILL.md
```

Expected: 6.

---

## Task 15: SKILL.md — Section 7 (Verdict detection + anti-LGTM override)

**Files:**
- Modify: `~/.claude/skills/goalv3-cc/SKILL.md` (append)

Spec source: lines 305-313 (4-source ladder) + line 423-424 + line 435 (anti-LGTM as system invariant).

- [ ] **Step 1: Append section 7**

```markdown

## 7. Verdict detection — 4-source ladder + anti-LGTM override

**This is the V3 finding codified.** Source: `references/codex-emergent-pattern.md`.

### 4-source priority ladder (descending trust)

| # | Source | When fires |
|---|---|---|
| 1 | Explicit `VERDICT: PASS\|FLAG\|BLOCK` line in subagent return | Highest trust — subagent self-reports |
| 2 | Custom stdout pattern match (from packet `expected_artifacts.stdout_pattern`) | Pattern-defined verdict word |
| 3 | Artifact exists at `expected_artifacts.path` + non-empty + content sanity check | File-based evidence |
| 4 | Heuristic on output text: refuse phrase → BLOCK, error/fail → FLAG, completion → weak PASS | Last resort |

Skill runs: `bash scripts/verdict-parse.sh <subagent-out-file> "<pattern>" "<expected-artifact-path>"`.

Output format: `VERDICT|source-N|note` — written to `dispatch-log.jsonl` with `verdict_source` field.

### Anti-LGTM override (THE INVARIANT)

If source-1 says `PASS` **but** artifact (per `expected_artifacts.path`) is missing or empty:

→ **Conductor OVERRIDES verdict to FLAG.**

This is automatic. No operator intervention required. Log entry: `claimed PASS evidence absent`. Re-dispatch with strengthened `evidence_expectations`.

This codifies the Codex GPT-5.5 emergent pattern (operator finding 2026-05-12): the conductor itself, not just a reviewer subagent, enforces evidence-backed verdicts at every stage transition.

### What the override catches

- Subagent that confidently claims PASS but skipped the actual work
- Subagent that wrote the wrong path or got the artifact name wrong
- Subagent that hit a token limit mid-write and only the verdict line made it out

### What it doesn't catch (limitations)

- Wrong content in the artifact (override only checks existence + non-empty; semantic correctness requires a reviewer subagent or operator review)
- Artifact exists from a *prior* run that wasn't cleaned up (mitigation: skill should `rm` expected_artifacts.path before dispatch in deterministic re-runs; current behavior leaves this to packet author)

### Self-application (conductor-level)

The same discipline applies to the conductor itself: when the SKILL writes the closeout.md and is about to claim PASS at goal level, it MUST first run `closeout-validate.sh` to verify the 5 pre-DONE checks. If any check fails, the goal-level verdict is FLAG, not PASS. (See section 10.)

This is V3 codified at the meta-level: anti-LGTM applied to the operator-of-the-skill's own work.
```

- [ ] **Step 2: Verify the override invariant is present verbatim**

```bash
grep -q "OVERRIDES verdict to FLAG" ~/.claude/skills/goalv3-cc/SKILL.md && echo OK || echo MISSING
grep -c "^## " ~/.claude/skills/goalv3-cc/SKILL.md  # should be 7
```

Expected: OK + 7.

---

## Task 16: SKILL.md — Section 8 (Bounded Supervisor Gate — dedupe / cooldown / operator-call / autonomy)

**Files:**
- Modify: `~/.claude/skills/goalv3-cc/SKILL.md` (append)

Spec source: lines 316-371 (full Bounded Supervisor Gate + operator-call conditions + autonomy guards + state transition rules).

- [ ] **Step 1: Append section 8**

```markdown

## 8. Bounded Supervisor Review Gate

### `max_active` enforcement

- State.json maintains `in_flight: [{task_id, dedupe_key}, ...]` array.
- Before each dispatch: `if len(in_flight) >= max_active (default 2): block-and-wait` (single-session A mode; Task tool synchronous gives natural serialization).
- Operator can override per-packet via `max_active` field (e.g. set to 1 for sensitive lanes, 4 for trivial batches).

### Dedupe

- In-session set: `seen_dedupe_keys` (per skill invocation).
- Cross-session: load historical `dispatch-log.jsonl` entries to rebuild.
- Three handling cases:
  - Same key + currently in_flight → skip + post status note ("already running as T<id>")
  - Same key + already PASS in seen_dedupe_keys → skip UNLESS `evidence_expectations` has changed (compare current vs historical packet — if different, treat as new key)
  - Same key + already BLOCK → check if blocker changed; if not, skip + log; if yes, treat as new key

### Cooldown

- Per `dedupe_key`, `cooldowns[<key>] = {last_dispatch, cooldown_until}` in state.json.
- Before re-dispatch: `if now < cooldown_until: skip-cooldown`.
- Defaults: 15min standard, 30min heavy.
- Operator override: add `cooldown_skip: true` to packet for one-time bypass. Logged as `override: true` in `dispatch-log.jsonl`.

### Operator-call conditions (7 — MUST stop)

Skill transitions to OPERATOR_NEEDED + yields when:

1. Design trade-off needs human taste judgment (not more context — judgment, not data)
2. Permission / secret / payment / runtime mutation required
3. Blocked lane is the only viable route
4. Same sub-task failed twice with different approaches (V2 dogfood pattern)
5. Dedupe key matches active issue but Decision Packet conflicts (route conflict)
6. Validation gate (pre-DONE 5 checks) any failure with no auto-remediation path
7. **`cc_dispatch_mode: bg` triggered** — conductor cannot auto-monitor `--bg` sessions, MUST yield

Each transition writes an entry to `state.json operator_calls: [{reason, at, context}]`.

### Autonomy guards (5 — MAY proceed)

Skill acts autonomously (no operator confirm) when ALL of:

1. Decision Packet verdict = `READY_TO_DISPATCH`
2. None of the 7 operator-call conditions triggered
3. Dedupe confirms no duplicate
4. Route does NOT touch frozen_lanes
5. Operator hasn't explicitly halted in recent messages (last 5 user turns)

If any of the 5 fails → operator-call.

### Frozen lanes

`state.json frozen_lanes: ["<route-prefix>", ...]`. Set by operator (e.g. via direct edit or future operator command). Any dispatch whose `dedupe_key` route-prefix matches a frozen lane → skip-frozen-lane → OPERATOR_NEEDED.

Frozen lanes are the **operator's hard veto** mechanism. Skill never auto-unfreezes. Operator must edit state.json or pass `unfreeze_lanes: [...]` in packet for one-time bypass.

### State transition rules

```
GOAL_CAPTURED → DESIGNING:        skill load completes
DESIGNING → DECISION_PACKET:      packet drafted, verdict not OPERATOR_NEEDED
DECISION_PACKET → DISPATCHING:    packet approved (auto if autonomy guards pass) + Bounded Gate proceed
DISPATCHING → OBSERVING:          at least 1 Task in_flight
OBSERVING → REVIEWING:            in_flight drains to empty (current wave done)
REVIEWING → DISPATCHING (FLAG):   re-route with new packet
REVIEWING → BLOCKER_CLASSIFIED (BLOCK): trigger blocker classification
REVIEWING → LEARNING (PASS):      evidence_expectations satisfied
LEARNING → ARCHIVING → DONE:      validation gate 5 checks all pass
BLOCKER_CLASSIFIED → OPERATOR_NEEDED: operator-call blocker
BLOCKER_CLASSIFIED → COOLDOWN:    external blocker (system, rate limit, etc.)
COOLDOWN → DESIGNING:             cooldown elapsed
BLOCKER_CLASSIFIED → ARCHIVED:    permanent blocker
ARCHIVED → DONE:                  archive actions complete
```

Each transition appended to `state.json history: [{from, to, at, trigger}]`.
```

- [ ] **Step 2: Verify**

```bash
grep -c "^## " ~/.claude/skills/goalv3-cc/SKILL.md  # 8
grep -q "Operator-call conditions" ~/.claude/skills/goalv3-cc/SKILL.md && echo OK
```

Expected: 8 + OK.

---

## Task 17: SKILL.md — Section 9 (Observability — 6-layer stack)

**Files:**
- Modify: `~/.claude/skills/goalv3-cc/SKILL.md` (append)

Spec source: lines 376-388 (6-layer table + critical invariant about Task subagents not in agent view).

- [ ] **Step 1: Append section 9**

```markdown

## 9. Observability — 6-layer stack

| Layer | Mechanism | Operator visibility |
|---|---|---|
| **L0: Agent View** | `claude agents` shows all CC sessions including this skill's main session + any `--bg` spawned subagents | Fleet view: running/blocked/done states across parallel sessions |
| L1: HUD / statusline | `TaskCreate` per state transition | Current state + tier on statusline |
| L2: Transcript | Skill prints status line each transition | Real-time in main chat |
| L3: state.json | Persistent, machine-readable | `cat .goal/<id>/state.json \| jq` anytime |
| L4: dispatch-log.jsonl | Append-only audit | Full trail, jq-filterable |
| L5: history/ | Packet snapshots, time-series | Git-friendly diff history (when `.goal/` is locally tracked, not Windburn-tracked) |

### Critical invariant: Task tool subagents are NOT in agent view

`Task` tool subagents are **in-process** (same parent CC session). They do not appear in `claude agents` fleet view.

Only `claude --bg [task]` spawned sessions appear as separate agents.

This means: if operator wants real-time fleet observability across N concurrent subagents, the dispatch primitive must be `--bg`, not Task. Skill documents this distinction explicitly in section 6 ("Two dispatch primitives" table).

### Per-layer artifact ownership

| Layer | Writer | Reader |
|---|---|---|
| L0 | CC runtime (out of skill's control) | operator via `claude agents` |
| L1 | skill (via TaskCreate per transition) | operator's IDE / terminal statusline |
| L2 | skill (printf to stdout each transition) | operator in transcript |
| L3 | skill writes (state-init.sh + skill body updates) | skill reads on resume; operator reads ad-hoc |
| L4 | skill appends (one line per dispatch + per verdict) | post-mortem via jq |
| L5 | skill snapshots (on transition out of REVIEWING) | operator via diff |

### L1 status line format

```
goalv3-cc:<goal_id>[<tier>] state=<current_state> in_flight=<N>/<max_active>
```

Example: `goalv3-cc:absorb-codex-into-cc[heavy] state=OBSERVING in_flight=2/2`

### L2 transcript format

```
[goalv3-cc] <from> → <to> (trigger: <reason>) [at <ISO timestamp>]
```

Example: `[goalv3-cc] DISPATCHING → OBSERVING (trigger: spawned T1 T2) [at 2026-05-12T08:32Z]`
```

- [ ] **Step 2: Verify**

```bash
grep -c "^## " ~/.claude/skills/goalv3-cc/SKILL.md
```

Expected: 9.

---

## Task 18: SKILL.md — Section 10 (Validation + Closeout)

**Files:**
- Modify: `~/.claude/skills/goalv3-cc/SKILL.md` (append)

Spec source: lines 186-205 (closeout schema) + lines 438-444 (5 validation checks) + lines 461-477 (SKILL.md body sections table for context).

- [ ] **Step 1: Append section 10**

```markdown

## 10. Validation + Closeout

### Pre-DONE validation gate (5 checks)

Run `bash scripts/closeout-validate.sh <goal_id>` BEFORE writing closeout.md. All 5 must pass.

1. **Every dispatched task in `dispatch-log.jsonl` has a `verdict` field OR an explicit `cancelled: true` flag.** No silent drops.
2. **No duplicate active `dedupe_key` entries in `in_flight`.** Single-occupancy invariant.
3. **Self-cancel condition met:** `in_flight` empty AND no pending packets in DESIGNING. Goal has no live work.
4. **Evidence is in closeout.md, not just dispatch-log.jsonl.** Aggregated narrative, not raw audit.
5. **Every BLOCKER_CLASSIFIED history entry has at least one OPERATOR_NEEDED transition.** Audit completeness — no silent escalations.

Any fail → transition back to LEARNING, write `.goal/<goal-id>/validation-failure.md` listing failed checks, emit OPERATOR_NEEDED for operator decision (force-DONE vs fix-then-retry).

### Closeout contract schema

See `references/closeout-template.md` for full schema + example. 12 fields total:

**V2 core (9)**: `goal_id`, `objective`, `state_machine_path`, `decision_packets_produced`, `tasks_dispatched`, `evidence_harvested`, `noise_cancelled`, `operator_calls`, `residual_risk`, `archive_actions_taken`, `verdict` (PASS|FLAG|BLOCK).

**CC additions (3)**: `subagent_chain`, `total_tokens_estimate`, `final_artifacts`.

### Closeout writing sequence

1. Skill detects REVIEWING returned PASS, transitions to LEARNING.
2. LEARNING aggregates: read all `dispatch-log.jsonl` entries, summarize evidence into closeout.md `evidence_harvested` field.
3. Transition LEARNING → ARCHIVING.
4. Run `closeout-validate.sh <goal_id>`. If FAIL → back to LEARNING; if PASS → continue.
5. Write final closeout.md (overwrite any partial draft).
6. Transition ARCHIVING → DONE.
7. Print final transcript line: `[goalv3-cc] <goal_id> DONE (verdict: PASS, artifacts: <N>, dispatches: <M>, noise_cancelled: <K>)`.

### Goal-level verdict aggregation

If multiple Decision Packets per goal (heavy + multi-domain like absorb-codex):

- All DPs PASS → goal verdict PASS
- Any DP FLAG (unresolved at DONE attempt) → goal verdict FLAG, transition LEARNING (re-design FLAG packets)
- Any DP BLOCK (operator-classified permanent) → goal verdict BLOCK, transition ARCHIVED

### Anti-LGTM at goal level

The closeout-validate check 4 ("evidence in closeout.md") is the goal-level anti-LGTM gate: a goal cannot DONE without an aggregated evidence narrative. The skill cannot just write `verdict: PASS` and call it done — the narrative is the artifact, and it has to be there.
```

- [ ] **Step 2: Verify**

```bash
grep -c "^## " ~/.claude/skills/goalv3-cc/SKILL.md
```

Expected: 10.

---

## Task 19: SKILL.md — Sections 11 (Refuses) + 12 (Gotchas)

**Files:**
- Modify: `~/.claude/skills/goalv3-cc/SKILL.md` (append)

Spec source: lines 461-477 (section 11 + 12 line estimates) + lines 415-451 (error handling top 12 + anti-LGTM invariants for section 11 substance).

- [ ] **Step 1: Append sections 11 and 12**

```markdown

## 11. Refuses to do (negative space)

The skill explicitly refuses to:

1. **Auto-commit.** Per operator's CLAUDE.md, all commits are operator-confirmed. Skill stages, suggests message, waits.
2. **Modify operator-locked lanes.** `~/multica-ultimate-workbench/autopilots/` and `~/.codex/` are frozen by operator directive. Any packet whose route touches these → OPERATOR_NEEDED immediately.
3. **Claim PASS when evidence missing.** This is the V3 invariant codified in section 7. Even if a subagent's return contains `VERDICT: PASS`, if the artifact is missing or empty, conductor overrides to FLAG. Self-applied: skill never writes `verdict: PASS` in closeout.md without `closeout-validate.sh` returning OK.
4. **Skip Self-Awareness Bootstrap for heavy tier.** Even when operator expresses urgency, bootstrap is the anti-hallucination prereq for heavy work.
5. **Re-dispatch within cooldown without operator override.** Cooldowns exist to prevent flapping; skipping them requires explicit `cooldown_skip: true` in packet (logged as override).
6. **Truncate state.json history.** History is append-only. Compaction is a v2 concern.
7. **Spawn subagents for goals smaller than tier=fast warrants.** If the rubric says inline-execute, skill does it inline — no ceremony for trivial work.
8. **Substitute a different `subagent_type` than the packet specifies without operator approval.** If the requested subagent is unavailable, skill tries the fallback from registry table, and if that fails, escalates OPERATOR_NEEDED — does not silently pick "any nearby" subagent.

## 12. Gotchas (append-mostly)

Discovered during dogfood, append-only.

- *(empty at v0.1.0 — populate after Phase 1 dogfood tests)*
```

- [ ] **Step 2: Verify final SKILL.md structure**

```bash
SKILL=~/.claude/skills/goalv3-cc/SKILL.md
wc -l "$SKILL"
grep -c "^## " "$SKILL"
grep -E "^## [0-9]+\." "$SKILL"
head -3 "$SKILL"  # frontmatter start
```

Expected: line count 500-650, section count = 12, sections 1-12 present in order, file starts with `---`.

---

## Task 20: Skill smoke test — frontmatter + load behavior

**Files:**
- Test: `/tmp/goalv3-cc-smoke.sh` (ephemeral)

Purpose: Verify SKILL.md is well-formed and discoverable.

- [ ] **Step 1: Write + run smoke test**

```bash
cat > /tmp/goalv3-cc-smoke.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SKILL=~/.claude/skills/goalv3-cc/SKILL.md

# Frontmatter starts with ---
head -1 "$SKILL" | grep -q "^---$" || { echo "FAIL: no opening frontmatter"; exit 1; }

# Frontmatter has required keys
grep -q "^name: goalv3-cc$" "$SKILL" || { echo "FAIL: name missing or wrong"; exit 1; }
grep -q "^description:" "$SKILL" || { echo "FAIL: description missing"; exit 1; }

# 12 sections present
for n in 1 2 3 4 5 6 7 8 9 10 11 12; do
  grep -q "^## ${n}\." "$SKILL" || { echo "FAIL: section $n missing"; exit 1; }
done

# Anti-LGTM invariant present verbatim
grep -q "OVERRIDES verdict to FLAG" "$SKILL" || { echo "FAIL: anti-LGTM override invariant missing"; exit 1; }
grep -q "claimed PASS evidence absent" "$SKILL" || { echo "FAIL: anti-LGTM log entry phrase missing"; exit 1; }

# All 4 scripts referenced + executable
for s in state-init dispatch verdict-parse closeout-validate; do
  test -x ~/.claude/skills/goalv3-cc/scripts/${s}.sh || { echo "FAIL: script $s.sh missing or not executable"; exit 1; }
  grep -q "${s}.sh" "$SKILL" || { echo "FAIL: SKILL.md does not reference $s.sh"; exit 1; }
done

# All 4 references present
for r in decision-packet-template self-awareness-template closeout-template codex-emergent-pattern; do
  test -f ~/.claude/skills/goalv3-cc/references/${r}.md || { echo "FAIL: reference $r.md missing"; exit 1; }
done

echo "PASS: goalv3-cc smoke test"
EOF
bash /tmp/goalv3-cc-smoke.sh
rm /tmp/goalv3-cc-smoke.sh
```

Expected: `PASS: goalv3-cc smoke test`.

- [ ] **Step 2: Present scaffold to operator + propose first big commit**

Show operator the full file tree:
```bash
find ~/.claude/skills/goalv3-cc -type f | sort
wc -l ~/.claude/skills/goalv3-cc/SKILL.md
wc -l ~/.claude/skills/goalv3-cc/references/*.md
wc -l ~/.claude/skills/goalv3-cc/scripts/*.sh
```

Since `~/.claude/skills/` may or may not be git-tracked by operator, ASK first:
> "Skill files live at ~/.claude/skills/goalv3-cc/. Is your ~/.claude/ git-tracked? If yes, I'll propose a commit there. If no, the files are simply in place — no commit needed for skill itself. Either way, the Windburn-side .gitignore update from Task 1 is the only Windburn commit so far."

If operator says yes (commit there): present a suggested commit message:
```
feat(skills): add goalv3-cc — two-layer autonomous conductor with anti-LGTM as system invariant

Fuses Multica Workbench Goal Mode V2 schemas (Decision Packet 14 fields,
Self-Awareness Bootstrap 11 fields, Closeout Contract 9 fields) + CC v2.1.139
/goal + agent view primitives + Codex GPT-5.5 emergent self-anti-LGTM pattern.

Skill location: ~/.claude/skills/goalv3-cc/
  SKILL.md           # 12 sections, ~550 lines
  scripts/           # state-init, dispatch, verdict-parse, closeout-validate
  references/        # 4 templates + V3 finding doc

V3 invariant codified: conductor overrides claimed-PASS-with-evidence-missing to
FLAG automatically (verdict-parse.sh source-1 → anti-LGTM override).

Phase 1 deliverable per docs/superpowers/specs/2026-05-12-goalv3-cc-fusion-design.md.
Phase 2 (absorb codex via this skill) is recursive dogfood, tracked in same plan.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Wait for operator: `commit ok` / `change message` / `skip`.

---

## Task 21: Phase 1 dogfood Test 1 — Skill loading

Purpose: Operator says "use goalv3-cc to ..." → skill body should appear in transcript (skill auto-discovered + loaded).

- [ ] **Step 1: Operator invokes skill in a fresh CC session (or current session)**

Operator types one of:
- `use goalv3-cc to summarize the last 5 commits on main`
- `/goal with V3 contract: count my .learnings/ entries`
- Any phrasing that activates the skill description triggers

- [ ] **Step 2: Verify skill body loads**

Expected behavior in transcript:
- Skill announces "Using goalv3-cc skill" or similar marker
- Skill body content from SKILL.md sections 1-2 appears OR skill description is recognized as match
- Skill proceeds to GOAL_CAPTURED → DESIGNING state, runs state-init.sh

Operator confirms: "skill loaded as expected" / "did not trigger — check description match".

If fails: check `cat ~/.claude/skills/goalv3-cc/SKILL.md | head -20` — frontmatter description must include trigger phrases. Adjust description as needed (no implementation change, just description tuning).

---

## Task 22: Phase 1 dogfood Test 2 — Fast tier

Purpose: Trivial goal → fast path, no Task spawn, inline execute, closeout written.

- [ ] **Step 1: Operator invokes fast-tier goal**

Operator says: `use goalv3-cc on goal "git-status-summary": check git status of current repo and summarize in one sentence`

- [ ] **Step 2: Verify fast path behavior**

Expected:
- `state-init.sh git-status-summary fast` runs → `.goal/git-status-summary/state.json` created
- Skill skips Self-Awareness Bootstrap (fast tier rule)
- Skill produces minimal Decision Packet inline (NOT written to file for fast tier — single-line route)
- Skill runs `git status` directly (no Task spawn) — fast tier inline-execute path
- Skill writes closeout.md with verdict PASS, evidence_harvested = the summary itself
- `closeout-validate.sh git-status-summary` → OK

- [ ] **Step 3: Inspect artifacts**

```bash
ls -la .goal/git-status-summary/
cat .goal/git-status-summary/state.json | jq '.current_state, .verdict, .history | length'
cat .goal/git-status-summary/closeout.md
```

Expected:
- `current_state: "DONE"`
- `verdict: "PASS"`
- history length ≥ 7 (GOAL_CAPTURED → DESIGNING → DECISION_PACKET → DISPATCHING → OBSERVING → REVIEWING → LEARNING → ARCHIVING → DONE)
- closeout.md has all required fields per `references/closeout-template.md`

Operator confirms: PASS / FAIL with diagnostic.

---

## Task 23: Phase 1 dogfood Test 3 — Standard tier

Purpose: Mid-size goal with 1 Task spawn, verdict PASS, full closeout.

- [ ] **Step 1: Operator invokes standard-tier goal**

Operator says: `use goalv3-cc on goal "summarize-last-5-commits": write a 150-200 word summary of the last 5 commits to .goal/summarize-last-5-commits/artifact.md`

- [ ] **Step 2: Verify standard path behavior**

Expected:
- Skill classifies as STANDARD (specific artifact, single module, no external)
- Decision Packet written to `.goal/summarize-last-5-commits/decision-packet.md` with full 17 fields filled
- `dispatch.sh` proceeds (no cooldown / dedupe collision on first run)
- Skill spawns 1 Task with `general-purpose` subagent (do stage) + 1 with reviewer if owner+reviewer differ
- Subagent writes artifact.md
- `verdict-parse.sh` sees PASS + artifact exists → source-1 or source-2 PASS
- LEARNING aggregates, closeout.md written
- `closeout-validate.sh` → OK

- [ ] **Step 3: Verify anti-LGTM did NOT trigger (artifact is present)**

```bash
cat .goal/summarize-last-5-commits/dispatch-log.jsonl | jq '.verdict_source'
```

Expected: source-1 or source-2 (NOT override-anti-lgtm). Source-3 would mean the subagent skipped the VERDICT line — note for tuning but acceptable.

Operator confirms.

---

## Task 24: Phase 1 dogfood Test 4 — Heavy tier

Purpose: Multi-stage goal with Self-Awareness Bootstrap, specialist chain, full closeout.

- [ ] **Step 1: Operator invokes heavy-tier goal**

Operator says: `use goalv3-cc on goal "learnings-audit": carefully audit ~/.claude/learnings/ for stale entries, propose 3 candidates for pruning to .goal/learnings-audit/proposals.md, with rationale per candidate`

- [ ] **Step 2: Verify heavy path behavior**

Expected:
- Skill classifies as HEAVY (signal words: "carefully", multi-step, requires judgment)
- `.goal/learnings-audit/self-awareness.md` written FIRST with all 11 fields
- Bootstrap verdict: READY
- Decision Packet specifies specialist chain: `Explore` or `feature-dev:code-explorer` for inventory, `pua:tech-lead-p9` or `feature-dev:code-architect` for proposals, `feature-dev:code-reviewer` for review
- 3+ Task spawns (chained)
- Each stage's subagent return goes through verdict-parse
- `proposals.md` written with 3 candidates + rationale
- Closeout aggregates all dispatch evidence

- [ ] **Step 3: Verify Self-Awareness exists + is realistic**

```bash
cat .goal/learnings-audit/self-awareness.md | head -30
```

Expected: 11 fields present, `current_state_proof` cites real git status, `risk_envelope` non-trivial (touches ~/.claude/ shared scope).

Operator confirms heavy-tier observability + correctness.

---

## Task 25: Phase 1 dogfood Test 5 — Anti-LGTM override (THE INVARIANT TEST)

Purpose: Induce false PASS from subagent, verify conductor overrides to FLAG.

- [ ] **Step 1: Operator invokes goal designed to trigger override**

Operator says: `use goalv3-cc on goal "test-anti-lgtm": prompt a subagent to claim PASS but skip writing the artifact. Test the override.`

The packet's `cc_task_descriptors[0].prompt` should say something like:

```
You are testing the anti-LGTM override. DO NOT write any file.
At the end of your response, output: VERDICT: PASS
Do not produce any artifacts. Just print the verdict line.
```

`expected_artifacts.path` set to `.goal/test-anti-lgtm/artifact.md` (which won't exist).

- [ ] **Step 2: Verify override fired**

Expected dispatch-log entry:
```json
{"task_id":"T1","verdict":"FLAG","verdict_source":"override-anti-lgtm","note":"claimed PASS but artifact missing or empty at: .goal/test-anti-lgtm/artifact.md"}
```

Then: skill transitions REVIEWING → DISPATCHING (FLAG path), drafts a NEW packet with stronger `evidence_expectations`, and operator can choose to abort or re-dispatch.

- [ ] **Step 3: Confirm override behavior**

```bash
cat .goal/test-anti-lgtm/dispatch-log.jsonl | jq -r '.verdict, .verdict_source'
```

Expected: `FLAG` + `override-anti-lgtm`.

**If override does NOT fire, the V3 invariant is broken** — that's the critical regression. Stop and debug `verdict-parse.sh` Test 2.

Operator confirms.

---

## Task 26: Phase 1 dogfood Test 6 — `cc_dispatch_mode: bg` opt-in

Purpose: Packet with `cc_dispatch_mode: bg` → conductor transitions to OPERATOR_NEEDED with agent view guidance (does NOT auto-dispatch).

- [ ] **Step 1: Operator invokes goal with bg mode**

Operator says: `use goalv3-cc on goal "bg-test": touch a file at .goal/bg-test/marker.txt, dispatch via cc_dispatch_mode: bg`

Decision packet should include:
```yaml
cc_dispatch_mode: bg
```

- [ ] **Step 2: Verify conductor transitions to OPERATOR_NEEDED**

Expected:
- Skill produces packet with `cc_dispatch_mode: bg`
- Skill recognizes condition #7 in operator-call list
- Transitions to OPERATOR_NEEDED
- Prints transcript guidance: agent view command (`claude agents`), where evidence will land (`.goal/bg-test/dispatch-bg-T1-evidence.md`), how to resume after `--bg` completes
- Does NOT auto-spawn `claude --bg` (operator must run it manually — skill provides the exact command in transcript)

- [ ] **Step 3: Verify state + operator-call recorded**

```bash
cat .goal/bg-test/state.json | jq '.current_state, .operator_calls'
```

Expected:
- `current_state: "OPERATOR_NEEDED"`
- `operator_calls: [{"reason":"cc_dispatch_mode: bg","at":"<iso>","context":"..."}]`

Operator confirms guidance message is clear + actionable.

---

## Task 27: Phase 1 dogfood Test 7 — Resume protocol

Purpose: Interrupt a session mid-OBSERVING, verify next invoke detects lost in_flight + asks operator.

- [ ] **Step 1: Operator starts a standard-tier goal**

Operator: `use goalv3-cc on goal "resume-test": find all .md files in docs/ and count them, write count to .goal/resume-test/count.txt`

When state reaches OBSERVING (skill spawned Task, waiting on return), operator either:
- Hits Ctrl+C in terminal, OR
- Says `/exit`, OR
- Closes the CC session

- [ ] **Step 2: Operator re-invokes skill on same goal**

Operator (in new session): `use goalv3-cc on goal "resume-test": resume`

- [ ] **Step 3: Verify resume detection**

Expected:
- Skill reads `.goal/resume-test/state.json`
- Detects `current_state: "OBSERVING"` + `in_flight` non-empty
- Recognizes prior session is dead (this is a new session)
- Treats in_flight tasks as LOST
- Prompts operator: "Previous session left T1 in_flight. Options: (1) re-dispatch T1, (2) abandon (transition to ARCHIVED), (3) re-design (back to DESIGNING). Which?"
- Operator picks an option, skill proceeds accordingly

- [ ] **Step 4: Verify history records the interrupt + resume**

```bash
cat .goal/resume-test/state.json | jq '.history | map(select(.trigger | contains("resume") or contains("interrupt")))'
```

Expected: history has entry like `{"from":"OBSERVING","to":"<chosen>","trigger":"operator-resume-decision"}`.

Operator confirms resume behavior matches design.

---

## Task 28: Phase 1 closeout — aggregate test results + commit

**Files:**
- Create: `.goal/.phase1-closeout.md` (if .goal/ is gitignored at root, place ad-hoc here OR `docs/superpowers/closeouts/2026-05-12-goalv3-cc-phase1-dogfood.md`)

- [ ] **Step 1: Aggregate Phase 1 dogfood results**

Write a closeout file `docs/superpowers/closeouts/2026-05-12-goalv3-cc-phase1-dogfood.md` (create directory if absent):

```markdown
# goalv3-cc Phase 1 Dogfood Closeout

- Date: 2026-05-12
- Spec: docs/superpowers/specs/2026-05-12-goalv3-cc-fusion-design.md
- Skill: ~/.claude/skills/goalv3-cc/
- Phase 1 success criteria: 7 dogfood tests (see spec line 502-509)

## Results

| # | Test | Result | Notes |
|---|---|---|---|
| 1 | Skill loading | PASS / FAIL | <observation> |
| 2 | Fast tier | PASS / FAIL | <observation> |
| 3 | Standard tier | PASS / FAIL | <observation> |
| 4 | Heavy tier | PASS / FAIL | <observation> |
| 5 | Anti-LGTM override | PASS / FAIL | <CRITICAL — must pass> |
| 6 | --bg opt-in | PASS / FAIL | <observation> |
| 7 | Resume protocol | PASS / FAIL | <observation> |

## Gotchas discovered (to backport into SKILL.md section 12)

- <list of dogfood findings>

## Verdict for Phase 1

PASS / FLAG / BLOCK based on aggregate (especially Test 5 = anti-LGTM, which is must-pass).

## Next: Phase 2 recursive dogfood

If Phase 1 PASS → proceed to Task 29 (use goalv3-cc to absorb codex).
If Phase 1 FLAG → fix the failing test before Phase 2.
If Phase 1 BLOCK → escalate, do not Phase 2.
```

- [ ] **Step 2: Backport any gotchas into SKILL.md section 12**

If dogfood revealed surprises, append to SKILL.md section 12 ("Gotchas") with one-line bullet each.

- [ ] **Step 3: Present + propose commit**

Stage:
```bash
git add docs/superpowers/closeouts/2026-05-12-goalv3-cc-phase1-dogfood.md
# Plus any SKILL.md gotcha updates (operator decides whether ~/.claude/ is tracked)
```

Propose commit message:
```
docs(goalv3-cc): Phase 1 dogfood closeout — 7/7 tests <PASS|FAIL count>

Anti-LGTM override (Test 5) <PASSED|FAILED> — the V3 invariant <holds|broken>.

Gotchas captured for SKILL.md section 12 backport.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Wait for operator: `commit ok` / `change` / `skip`.

---

## Task 29: Phase 2 recursive dogfood — invoke goalv3-cc on `absorb-codex-into-cc`

**This task is "use the skill, don't write new code".** The whole point of Phase 2 is that goalv3-cc drives the absorb-codex work via 4 parallel Decision Packets. The plan task is just: invoke skill, let it run, operator approves DPs, eventually closeout.

Spec source: lines 514-547 (Phase 2 Hook).

- [ ] **Step 1: Operator invokes Phase 2**

Operator says:
```
use goalv3-cc on goal "absorb-codex-into-cc": port codex chronicle + hooks + mcp + agent registry into CC analogs

  tier: heavy
  cc_dispatch_mode: bg
  evidence_expectations:
    - OpenChronicle installed + MCP queryable (DP1)
    - Consolidated hooks.json (DP2)
    - Unified ~/.claude/mcp.json with codex-unique MCPs ported (DP3)
    - Pruned agent registry, codex-unique kept (DP4)
    - closeout.md with all 4 DP verdicts PASS
  constraints:
    - DO NOT modify ~/.codex/ (operator-locked)
    - DO NOT modify ~/multica-ultimate-workbench/autopilots/ (operator-locked)
```

- [ ] **Step 2: Verify skill produces Self-Awareness Bootstrap (heavy)**

Skill writes `.goal/absorb-codex-into-cc/self-awareness.md`. Operator reviews.

- [ ] **Step 3: Verify skill produces 4 Decision Packets**

| DP | Domain | Owner | Reviewer |
|---|---|---|---|
| DP1 | OpenChronicle integration | `voltagent-dev-exp:tooling-engineer` (or fallback) | `feature-dev:code-reviewer` + `codex:codex-rescue` |
| DP2 | Hooks diff + dedupe | `voltagent-dev-exp:dx-optimizer` (or fallback) | `feature-dev:code-reviewer` |
| DP3 | MCP diff + port | `voltagent-dev-exp:tooling-engineer` | `voltagent-qa-sec:security-auditor` |
| DP4 | Agent registry diff | `feature-dev:code-explorer` | `feature-dev:code-reviewer` |

Each packet has `cc_dispatch_mode: bg`. Each has its own `dedupe_key`.

Operator reviews packets, edits if needed, approves.

- [ ] **Step 4: Verify --bg launches (after operator approval)**

Skill enters OPERATOR_NEEDED (because cc_dispatch_mode: bg per condition #7). Skill provides operator the exact commands:

```
claude --bg "<DP1 prompt>" --description "DP1: OpenChronicle integration"
claude --bg "<DP2 prompt>" --description "DP2: hooks dedupe"
claude --bg "<DP3 prompt>" --description "DP3: mcp port"
claude --bg "<DP4 prompt>" --description "DP4: agents prune"
```

Operator runs commands. Each `--bg` session writes evidence to `.goal/absorb-codex-into-cc/dispatch-bg-<task-id>-evidence.md`.

- [ ] **Step 5: Operator returns to main session, says "resume"**

Skill reads evidence files, runs verdict-parse on each, transitions REVIEWING.

For any FLAG, skill re-designs that DP. For BLOCK, classifies + escalates.

- [ ] **Step 6: Closeout aggregation**

When all 4 DPs PASS, skill runs LEARNING → ARCHIVING → DONE:
- `closeout-validate.sh absorb-codex-into-cc` → OK
- `.goal/absorb-codex-into-cc/closeout.md` written with all 4 DP verdicts + per-domain evidence + final artifacts list

- [ ] **Step 7: Operator review of Phase 2 closeout**

Operator confirms:
- OpenChronicle is installed + queryable via MCP
- Hooks consolidated (no destructive changes to existing CC hooks)
- MCP unified (no broken existing MCPs)
- Agent registry pruned (no orphan agents referenced from skills)
- `.goal/absorb-codex-into-cc/closeout.md` accurate

- [ ] **Step 8: Present + propose final commit**

Stage:
```bash
git add docs/superpowers/closeouts/  # if Phase 2 closeout was copied here
# Any other Phase 2 artifacts as operator directs
```

Propose:
```
feat: goalv3-cc Phase 2 complete — codex absorbed via recursive dogfood

Phase 2 used goalv3-cc itself to drive absorption of codex chronicle/hooks/mcp/agents
into CC analogs. 4 parallel Decision Packets, --bg dispatch, anti-LGTM verdict
override held across all 4 lanes.

Closeout: .goal/absorb-codex-into-cc/closeout.md
Artifacts: <list of files modified by --bg subagents>

The fused tool ate the prior stack. Both Phase 1 (skill works) + Phase 2 (skill
drives real absorption) verified.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Wait for operator confirmation.

---

## Self-Review (writing-plans skill checklist)

### 1. Spec coverage

| Spec section | Plan task(s) |
|---|---|
| Architecture: skill scaffold + directories | Task 1 |
| Schemas: Decision Packet, Self-Awareness, Closeout, state.json | Tasks 2, 3, 4 |
| Anti-LGTM finding documentation | Task 5 |
| state-init.sh | Task 6 |
| dispatch.sh (Bounded Supervisor Gate enforcement) | Task 7 |
| verdict-parse.sh (4-source ladder + anti-LGTM override) | Task 8 |
| closeout-validate.sh (5 pre-DONE checks) | Task 9 |
| SKILL.md section 1 (When to activate) | Task 10 |
| SKILL.md section 2 (Architecture overview) | Task 10 |
| SKILL.md section 3 (Friction Tier Router) | Task 11 |
| SKILL.md section 4 (Self-Awareness Bootstrap) | Task 12 |
| SKILL.md section 5 (Decision Packet) | Task 13 |
| SKILL.md section 6 (Dispatch protocol) | Task 14 |
| SKILL.md section 7 (Verdict detection + anti-LGTM) | Task 15 |
| SKILL.md section 8 (Bounded Supervisor Gate) | Task 16 |
| SKILL.md section 9 (Observability 6-layer) | Task 17 |
| SKILL.md section 10 (Validation + Closeout) | Task 18 |
| SKILL.md section 11 (Refuses) | Task 19 |
| SKILL.md section 12 (Gotchas — empty initial) | Task 19 |
| Smoke load test | Task 20 |
| 7 dogfood tests (Phase 1 success criteria) | Tasks 21–27 |
| Phase 1 closeout aggregation | Task 28 |
| Phase 2 recursive dogfood (absorb-codex via skill) | Task 29 |

All spec sections covered. Decision log items D1-D12 represented across tasks (D1 scope, D2 skill primitive, D3 contract+dispatch, D4 Task synchronous, D5 .goal/ project-local, D6 9 states, D7 auto-tier, D8 14+3 schema, D9 dual primitive, D10 6-layer, D11 OpenChronicle Phase 2, D12 anti-LGTM invariant).

### 2. Placeholder scan

Searched plan for: TBD, TODO, "implement later", "fill in", "appropriate error", "etc.":
- ✅ No "TBD" / "TODO" / "implement later"
- ✅ Every shell script has full bash body
- ✅ Every SKILL.md section task has full prose content
- ⚠️ Tasks 21-27 contain `PASS / FAIL` placeholders in the closeout TABLE — that's expected, those are filled by operator after running each test. Not a plan failure; the table structure is the artifact.
- ⚠️ Task 28 closeout template has `<observation>` placeholders — again, filled by operator post-test. Same justification.

### 3. Type consistency

- `dedupe_key` format `<goal_id>/<route-hash>`: consistent across spec, packet template, dispatch.sh, anti-LGTM doc ✓
- `verdict` values `PASS|FLAG|BLOCK` (subagent level) vs `READY_TO_DISPATCH|NEEDS_DESIGN|OPERATOR_NEEDED` (packet level) vs `PASS|FLAG|BLOCK` (goal level closeout): spec uses these consistently ✓
- script names match across plan + SKILL.md: state-init / dispatch / verdict-parse / closeout-validate (no rename collisions) ✓
- state.json field names: `current_state`, `tier`, `in_flight`, `seen_dedupe_keys`, `cooldowns`, `frozen_lanes`, `history`, `operator_calls`, `verdict` — all match spec lines 209-232 ✓

### 4. Known gaps to flag for operator approval

- **`~/.claude/` git-tracking unknown**: Task 20 asks operator. Plan accommodates both.
- **Test 5 (anti-LGTM) is critical-path** — if it fails, Phase 2 cannot proceed safely. Plan emphasizes this in Task 25.
- **Test 7 (resume) requires session interrupt** — operator must manually interrupt + restart. Plan documents the steps but operator must cooperate with the interrupt.
- **`--bg` subagent prompts in Task 29 are not pre-written** — they'll be generated by skill at runtime per Decision Packet. Plan trusts the skill (validated by Tasks 21-27) to do this.
- **OpenChronicle install in Phase 2 DP1** may require sudo or fail on macOS Sequoia — boot dossier flagged this as don't-trust item. Plan trusts DP1 subagent to escalate OPERATOR_NEEDED if blocked.

### Resolution

Plan is complete and internally consistent. No edits to apply.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-12-goalv3-cc-implementation.md`.**

**Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. The subagent gets one task at a time from this plan + the spec + decision log as reading material. Two-stage review (implementer + reviewer subagent) per task.

**2. Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`. Batch execution with checkpoints at Task 9 (scripts complete), Task 19 (SKILL.md complete), Task 28 (Phase 1 closeout). Operator reviews at each checkpoint.

**Which approach?**

(HARD-GATE: no implementation begins until operator approves the plan + picks an execution approach.)
