---
name: windburn-cognitive-cache
description: Classify agent memory into Windburn cognitive-cache objects and route writes safely. Source cache + episodic cache + parking lane.
version: 0.2.0
platforms: [linux, macos, windows]
metadata:
  tags: [windburn, memory, belief, perception, failure, source-truth]
  cache_slots: [source, episodic]
  holding_lanes: [parking]
  invariant: source-truth requires human approval
---

# Windburn Cognitive Cache

Classify and route incoming memory objects into the Windburn 7-cache substrate. This is the **steward** skill: nothing becomes canonical without passing through it, and it never promotes anything to canonical by itself.

## Purpose (one line)

Take an unclassified memory candidate (a perception, a belief, a fact, a guess, a partial conclusion) and emit a routing decision that preserves the source-vs-inference boundary.

## Cache slots and holding lanes this skill routes

- **source** — when the candidate is a verified fact from a trusted origin (Research Vault, repo doc, source-truth file)
- **episodic** — when the candidate is "what happened, in order" with timestamp + actor
- **parking** — a holding lane, not one of the seven canonical cache slots, for candidates that are plausible but not yet ground-truth-eligible

This skill does NOT directly populate `belief`, `failure`, `procedural`, or `perception` caches; those live in dedicated skills or parent-repo substrates ([[windburn-source-truth-review]] for belief promotion, [[windburn-crabbox-failure-hook]] for failure capture, and the parent perception bus for perception events). It routes candidates TO those surfaces.

## When to use

- A task surfaces a memory write candidate (Research Vault claim, repo doc update, agent conclusion, parking note)
- A retrieved memory may be acted upon and you need to know its trust level first
- A human or upstream agent says "remember that..." and you must decide where it lands
- Words like *memory, belief, perception, source truth, parking, failure, continuity, Research Vault, learning* appear in the task

## When NOT to use

- The write is already classified and approved (route directly, this is overhead)
- The candidate is a code change (use normal review skills, not this one)
- The candidate is a downstream artifact of an already-approved source-truth update (no re-classification needed)

## Object types (full taxonomy)

```text
perception        grounded observation from human / tool / repo / browser / API call
belief            current hypothesis with evidence and stated scope
failure           attempted action plus predicted/actual mismatch + avoid/retry rule
procedure         reusable action pattern, repo route, or tool-use template
parking           plausible idea, insufficient evidence — preserved without promotion
source_proposal   candidate source-truth update requiring explicit human approval
reject            does not qualify for any cache; do not write
```

## Routing rules (invariants)

1. **Source facts go to the source-facts section.** Don't mix with inference.
2. **Inference goes to the inference section.** Label clearly: "Codex inferred", "Hermes inferred", "operator stated".
3. **A perception can support a belief, but it is not a belief by itself.** Trust level must rise through evidence accumulation, not category renaming.
4. **A belief can request promotion via [[windburn-source-truth-review]], but cannot approve itself.**
5. **A failure must include an `avoid_rule` OR `retry_condition`.** A failure without one is just a complaint, not learning.
6. **Source truth requires explicit human approval.** No exceptions, no "the model is highly confident", no batch-approval shortcuts.

## Inputs

A free-form memory candidate. Recommended structure:

```yaml
candidate: <the claim, write, or observation>
origin: <human | tool-name | repo | api | browser | inference>
evidence_refs:
  - <pointer 1>
  - <pointer 2>
context: <one-line situation>
```

If `origin` is `inference`, the cache routing must downgrade trust accordingly.

## Outputs (routing decision)

Return exactly one routing decision in this shape:

```yaml
route: perception | belief | failure | procedure | parking | source_proposal | reject
trust_level: ungrounded | partially_grounded | grounded
requires_human_review: true | false
evidence_count: <number>
reason: <one-sentence justification tying evidence to route>
next_action: <one concrete next action — e.g. "write to perception cache, no human review needed">
```

### Hard rule

```text
If route is source_proposal, requires_human_review MUST be true.
```

Any output that violates this rule should be treated as a skill bug and re-emitted.

## Anti-patterns (do NOT do)

- **Promoting a perception to belief silently.** A perception is what the tool said; a belief is what the agent now claims about reality. The category change is a state mutation and deserves an explicit `source_proposal` route.
- **Routing inference as `perception`.** Inference is hypothesis. Perception is observation. Crossing the line corrupts the source cache downstream.
- **Returning `route: reject` without a reason.** Reject is a verdict; it needs the same evidence-shape as any other route.
- **Auto-approving a `source_proposal` because all evidence_refs are present.** Two refs are necessary, not sufficient. Human approval is the final gate, always.
- **Compounding routes** ("perception AND parking"). One candidate, one route. If it's ambiguous, route to `parking` and explain in `reason`.

## Closeout shape (when this skill drives a task to completion)

```text
结论：PASS | FLAG | BLOCK
写入建议：route + reason
需要人审：yes | no
下一步：one concrete action
```

## Related

- [[windburn-source-truth-review]] — gates `source_proposal` routes toward (but never to) approval
- [[windburn-crabbox-failure-hook]] — produces the prediction/delta packets that this skill classifies as `failure` route
