---
name: windburn-source-truth-review
description: Review source-truth proposals without approving them automatically.
version: 0.1.0
platforms: [linux, macos, windows]
metadata:
  tags: [windburn, source-truth, review, human-approval]
---

# Windburn Source Truth Review

Use this skill when a memory write, document update, or agent conclusion may
become canonical source truth.

## Review Gate

Check:

1. Is the claim grounded in at least two evidence refs?
2. Are source facts separated from inference?
3. Is contradictory evidence named?
4. Is privacy/public-surface risk handled?
5. Is the human approval requirement preserved?

## Verdicts

```text
PASS  proposal is ready for human approval
FLAG  proposal is plausible but missing evidence or boundary clarity
BLOCK proposal weakens source-truth rules, privacy, or verification
```

## Hard Rules

- Never return `accept_as_grounded` as final truth.
- Never write directly into `source-truth/`.
- Never clear `requires_human_review`.
- Never treat model agreement as approval.

## Output

```yaml
verdict: PASS | FLAG | BLOCK
candidate_for_source_truth: true | false
requires_human_review: true
evidence_refs:
  - string
risks:
  - string
operator_decision_needed: string
```
