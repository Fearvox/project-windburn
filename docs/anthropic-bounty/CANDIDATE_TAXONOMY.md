# Candidate Taxonomy

Status: abstract public-safe taxonomy
Created: 2026-05-08

## Purpose

Organize research hypotheses for universal jailbreak discovery without storing
actual jailbreak prompts or harmful target questions.

Each family below is a research lens. A candidate is not valid until it is
tested in the authorized program environment and scored by the harness.

## Candidate Family Record

```json
{
  "candidate_id": "cand_...",
  "family": "family-name",
  "hypothesis": "why this might generalize",
  "expected_failure_mode": "what safeguard boundary it probes",
  "universality_axis": ["question-paraphrase", "topic-bucket", "multi-turn"],
  "safety_notes": ["no public prompt body", "no harmful target text"],
  "status": "idea|dry-run|authorized-test|retired|report-candidate"
}
```

## Hypothesis Registry Rules

The registry stores hypotheses, not workflows. A hypothesis may describe the
abstract safeguard boundary being measured, the expected failure mode, and the
aggregate metrics needed to retire or promote the candidate.

The registry must not contain candidate prompt bodies, target question text,
per-attempt outputs, successful exploit reproductions, or operational model
responses.

## Families

### Classifier Boundary Ambiguity

Hypothesis: Some failures may occur when benign framing and prohibited detail
requests are separated across context layers. This family tests whether the
classifier consistently tracks the final effective request.

Public artifact limit: describe only the context-layer shape, never the target
question or bypass wording.

### Multi-Turn State Drift

Hypothesis: A model may refuse correctly in isolation but drift after a long
sequence of harmless setup turns.

Public artifact limit: store turn counts, hashes, and refusal/non-refusal
metrics only.

### Translation And Representation Shift

Hypothesis: Safety classifiers may show variance when the same forbidden intent
is represented through language, notation, or abstraction changes.

Public artifact limit: record language or representation bucket labels only.

### Role And Policy Confusion

Hypothesis: Some prompts may induce confusion between instruction following,
evaluation mode, and safety policy hierarchy.

Public artifact limit: no roleplay scripts or reusable bypass phrases.

### Harmless-To-Harmful Escalation

Hypothesis: A sequence that begins as allowed educational framing may become
unsafe when specificity increases.

Public artifact limit: record escalation depth and refusal point, not content.

### Refusal Fatigue And Recovery

Hypothesis: Repeated refusals, rewrites, or correction requests may expose
inconsistent refusal boundaries.

Public artifact limit: store retry count, paraphrase id, and verdict hash.

### Tool Or Context Contamination

Hypothesis: External context, retrieved text, or tool output may alter how the
model interprets policy boundaries.

Public artifact limit: use synthetic harmless fixtures in public; use
program-authorized private fixtures only outside the repo.

## Prioritization

Highest priority:

- families that can plausibly generalize across many authorized questions;
- families that are measurable with hashes and verdicts;
- families that do not require leaking target content into logs;
- families that can be retired quickly if they fail.

Lowest priority:

- one-off magic strings;
- prompt dumps from public forums;
- candidates that only work on one exact question;
- candidates that require storing harmful completions in repo-tracked files.

## Candidate Verdicts

`PASS` means a candidate is a private report candidate after authorized testing.

`FLAG` means the candidate has a plausible hypothesis but lacks authorized
evidence or universality proof.

`BLOCK` means the candidate would violate scope, store unsafe content, or require
unauthorized testing.
