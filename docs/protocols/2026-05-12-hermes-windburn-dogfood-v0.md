# Hermes x Windburn Dogfood v0

Status: experimental learning and dogfood contract
Created: 2026-05-12

## Purpose

Turn Hermes Agent from an adjacent runtime into a bounded Windburn dogfood lane:

```text
Hermes official docs
  -> Windburn learning map
  -> Hermes side-lane run
  -> explicit relay artifact
  -> Windburn perception/belief parking
  -> human-gated source-truth proposal only
```

This document is not source-truth for Hermes internals. It is a Windburn
operator artifact distilled from the official Hermes docs and must cite the
official docs when used externally.

## Official Source Facts

Sources:

- https://hermes-agent.nousresearch.com/docs
- https://hermes-agent.nousresearch.com/docs/llms.txt
- https://hermes-agent.nousresearch.com/docs/llms-full.txt
- https://hermes-agent.nousresearch.com/docs/developer-guide/architecture
- https://hermes-agent.nousresearch.com/docs/developer-guide/agent-loop
- https://hermes-agent.nousresearch.com/docs/developer-guide/prompt-assembly
- https://hermes-agent.nousresearch.com/docs/developer-guide/context-compression-and-caching
- https://hermes-agent.nousresearch.com/docs/user-guide/features/goals
- https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks
- https://hermes-agent.nousresearch.com/docs/user-guide/features/skills
- https://hermes-agent.nousresearch.com/docs/user-guide/features/memory
- https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server
- https://hermes-agent.nousresearch.com/docs/user-guide/features/delegation
- https://hermes-agent.nousresearch.com/docs/user-guide/security
- https://hermes-agent.nousresearch.com/docs/user-guide/checkpoints-and-rollback

From the docs, Hermes is best treated as an agent OS stack, not only a CLI:

```text
entry surfaces
  CLI / TUI / gateway / API server / ACP / batch / Python library

agent kernel
  AIAgent loop
  prompt builder
  provider runtime
  tool dispatch
  context compression
  session persistence

context and memory
  SOUL.md
  AGENTS.md / CLAUDE.md / .hermes.md
  @file / @folder / @diff / @url references
  MEMORY.md / USER.md
  session_search
  external memory providers

autonomy
  /goal standing objective
  cron jobs
  subagent delegation
  kanban
  batch trajectories

safety and extension
  approvals
  checkpoints / rollback
  context file scanning
  skills
  plugins
  hooks
  MCP
```

## Windburn Interpretation

Hermes already has many primitives that match Windburn's current direction:

| Windburn concept | Hermes primitive | Use |
| --- | --- | --- |
| side-lane cockpit | CLI/TUI/gateway/API surfaces | run adjacent lanes without forcing the parent thread to own all chatter |
| perception bus | hooks + API runs/events + explicit artifacts | carry bounded artifacts instead of transcript dumps |
| durable goal loop | `/goal` | keep work alive without repeated "continue" prompts |
| skill graph | skills progressive disclosure | avoid prompt-dump skills; load detailed instructions only on demand |
| context cache | context engine + compression | manage long sessions, but treat compression as lossy unless verified |
| collaborator continuity | SOUL + context files + memory + session search | keep agent stable without claiming fake personhood |
| evidence gate | checkpoints + approvals + session receipts | require proof before PASS/source-truth |

Windburn should not simply copy Hermes memory semantics. Hermes memory is a
compact personal/profile memory. Windburn needs a stricter cognitive ledger:

```text
incoming signal
  -> perception candidate
  -> belief update proposal
  -> source-truth proposal
  -> human approval

or

incoming signal
  -> parking / fuzzy / rejected
```

## Dogfood Contract

Hermes may act as a side-lane collaborator when all of these are true:

1. The task is bounded and has an explicit artifact target.
2. The prompt forbids full transcript export.
3. The output includes one of:
   - `PARK_TO_PARENT:`
   - `DISTILL_TO_PARENT:`
   - `RETURN_TO_PARENT:`
4. The output classifies its own confidence and evidence.
5. The output does not claim source-truth status.
6. Any source-truth promotion remains human-gated.

### Allowed Artifact Shape

```yaml
artifact_type: PARKING_NOTE | DISTILL | RETURN
source_agent: hermes
source_surface: cli | tui | gateway | api
origin_task:
relay_payload:
evidence:
  - type: official_docs | local_file | command_output | operator_observation
    ref:
confidence: low | medium | high
windburn_destination: parking | perception_candidate | belief_candidate | source_truth_candidate
requires_human_review: true
boundary_note: bounded artifact only; not full transcript truth
```

### Disallowed

- Treating a Hermes final answer as direct `source-truth/`.
- Forwarding full side-chat transcript into the parent.
- Storing hidden reasoning or scratchpad content as evidence.
- Letting `/goal` judge completion replace Windburn verification.
- Letting `/goal` continue executing validation after it has emitted the
  requested bounded artifact, unless the operator explicitly asks for that.
- Running remote mutations or credential sync from a learning dogfood lane.

## Minimal Local Dogfood

Read-only Hermes critique of this file:

```bash
hermes chat -Q \
  --max-turns 3 \
  --toolsets file \
  --source windburn-dogfood \
  -q 'Read @file:docs/protocols/2026-05-12-hermes-windburn-dogfood-v0.md. Return exactly one bounded artifact. Begin with DISTILL_TO_PARENT:. Include: strongest useful idea, biggest risk, one concrete next verification gate. Do not edit files. Do not promote anything to source-truth.'
```

If the run returns an explicit `DISTILL_TO_PARENT:` artifact, it can be fed into
the existing side-lane relay hook or manually parked by the operator.

### First Dogfood Result

Observed on 2026-05-12 with local Hermes Agent v0.13.0:

```text
verdict: FLAG/PROMISING
```

The one-shot Hermes run did produce a useful `DISTILL_TO_PARENT:` artifact, but
it also emitted pre-marker analysis text and a `session_id` before the artifact.
That means the strict "begin with marker" rule failed even though the bounded
artifact was recoverable.

Contract update from this dogfood:

- valid relay ingestion should require a recognized marker;
- any pre-marker text should be flagged as `pre_marker_chatter`;
- the parser may extract the first valid marker payload for parking or
  perception-candidate review;
- pre-marker chatter must not be promoted or treated as evidence;
- if a downstream step requires machine-perfect artifact shape, this result is
  `FLAG`, not `PASS`.

### Second Dogfood Result

Observed on 2026-05-12 with local Hermes Agent v0.13.0 through `/goal`:

```text
verdict: PASS_WITH_SCOPE_FLAG
```

This run proved the Windburn bus path:

- Hermes produced a marker-first `DISTILL_TO_PARENT:` artifact.
- Windburn side-lane perception bus dry-run accepted the artifact:
  `2 valid / 0 flagged`.
- Windburn side-lane perception bus live verify succeeded:
  `model_visible=true`.
- The deterministic relay id was confirmed:
  `windburn-relay-1-bb066121563d`.
- The relay inbox was restored after the temporary smoke artifact.
- No source-truth write was allowed.

The scope flag is important: after Hermes emitted a valid artifact, `/goal`
continued because its judge returned non-JSON and the loop failed open into the
next action. Hermes then ran bus validation itself. That produced useful proof,
but it also shows `/goal` cannot be the boundary owner.

Contract update from this dogfood:

- `/goal` is a good execution loop, not a source-truth or verification owner;
- the parent Windburn/Codex lane should validate artifacts after emission;
- future goal prompts should explicitly forbid relay inbox writes and
  validation tool calls unless requested;
- if the goal loop asks to continue after the artifact, the side lane should
  answer only `GOAL_COMPLETE`.

## Stronger Dogfood Path

1. Start a Hermes side lane in the Windburn repo.
2. Give it the goal prompt in:
   `docs/goals/2026-05-12-hermes-windburn-dogfood-goal.md`
3. Hermes reads this protocol plus the existing side-lane perception bus v0 doc.
4. Hermes produces only a bounded `DISTILL_TO_PARENT:` or `PARK_TO_PARENT:`
   artifact.
5. Windburn's perception bus validates and injects the artifact.
6. Parent agent classifies it as:
   - parking;
   - perception candidate;
   - belief candidate;
   - source-truth candidate requiring human review.

## Verification Gates

Before claiming this lane works:

```bash
git diff --check -- docs/protocols/2026-05-12-hermes-windburn-dogfood-v0.md docs/goals/2026-05-12-hermes-windburn-dogfood-goal.md
node --check scripts/windburn-side-lane-perception-bus.mjs
node scripts/windburn-side-lane-perception-bus.mjs --dry-run
```

Optional live gate:

```bash
node scripts/windburn-side-lane-perception-bus.mjs --live --verify
```

Live verification is optional because local app-server/model auth can be
unavailable. If it runs, it must prove the model can return the deterministic
`relay_id`, not merely generic prompt words.

## Fuzzies

- Should Hermes `/goal` be used as a planning loop, or only as an execution loop
  after Windburn has already written the decision packet?
- Can Hermes `ContextEngine` plugins host a Windburn cognitive cache without
  making Hermes memory itself the source of truth?
- Should Windburn emit Apps-SDK-like public/private result surfaces:
  model-visible artifact versus private side-lane metadata?
- What is the smallest artifact schema that survives Hermes, Codex, Claude Code,
  and MUW without per-tool adapters?

## Current Verdict

`PASS_WITH_SCOPE_FLAG`: Hermes is a strong substrate for Windburn side-lane
dogfood and the Windburn perception bus path is verified. The remaining flag is
control-plane scope: source-truth and final verification boundaries must stay
outside Hermes memory and `/goal`.
