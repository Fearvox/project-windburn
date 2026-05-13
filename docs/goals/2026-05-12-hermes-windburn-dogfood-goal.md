# Goal: Hermes x Windburn Dogfood v0

Use this as a `/goal` prompt for a fresh Hermes side lane inside
the Windburn repo root.

```text
/goal Dogfood Hermes against Windburn side-lane protocol without writing source-truth.

Context:
- Work inside the Windburn repo root.
- Read first:
  - docs/protocols/2026-05-12-hermes-windburn-dogfood-v0.md
  - docs/protocols/2026-05-12-codex-side-lane-perception-bus-v0.md
- The operator wants Hermes to act as a bounded side-lane collaborator.
- Do not inspect or export full side-chat transcript.
- Do not write to source-truth.
- Do not change credentials, global config, hooks, or remote runtime state.

Goal:
Produce one bounded relay artifact that helps Windburn decide how to use Hermes.

Required output:
1. The first substantive output token must be exactly one marker:
   DISTILL_TO_PARENT:
2. Include these fields:
   - artifact_type: DISTILL
   - source_agent: hermes
   - strongest_useful_idea
   - biggest_risk
   - next_verification_gate
   - evidence_refs
   - confidence
   - requires_human_review: true
   - boundary_note: bounded artifact only; not transcript truth
3. Separate official Hermes facts from Hermes inference.
4. Do not claim source-truth status.
5. Stop after the artifact. Do not keep chatting unless the operator asks.
6. Do not write relay inbox directly.
7. Do not run validation tools directly.
8. Do not use /goal completion judgment as Windburn verification.

Strict stop contract:
- Your job is to emit the bounded artifact, not to validate it.
- Windburn parent will run the perception bus separately.
- If the goal loop asks you to continue after emitting the artifact, reply only:
  GOAL_COMPLETE
- Do not take additional tool calls after the artifact unless the operator
  explicitly asks.

Verification expectation:
- The artifact should be safe to pass through Windburn side-lane perception bus.
- The artifact must be useful even if no transcript is forwarded.
- Verification is performed by the parent Windburn/Codex lane, not by this goal.
```
