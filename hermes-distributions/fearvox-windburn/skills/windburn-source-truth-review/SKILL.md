---
name: windburn-source-truth-review
description: Review source-truth proposals against evidence and boundary rules. Returns verdict — never approves automatically.
version: 0.2.0
platforms: [linux, macos, windows]
metadata:
  tags: [windburn, source-truth, review, human-approval]
  cache_slots: [belief]
  invariant: never returns "approved" — only PASS / FLAG / BLOCK, with human approval still required
---

# Windburn Source Truth Review

Gate skill for the **belief cache**. A proposal can be promoted to belief candidacy by this skill; it can never be promoted to source-truth by this skill. Final approval is operator-only, always.

## Purpose (one line)

Verify that a source-truth proposal is *ready to be reviewed by a human*, without taking the human's place in the loop.

## Cache slots this skill serves

- **belief** — A proposal that passes this review enters the belief cache as a high-confidence candidate. It still requires a human-approval transition to reach the source cache.

## When to use

- [[windburn-cognitive-cache]] returned `route: source_proposal` on a candidate
- An agent has written a draft for a `source-truth/*` file and wants pre-flight evidence audit
- A memory write is about to update `Research Vault`, repo source-truth docs, or canonical decision logs
- A claim is propagating across multiple agents and you want a checkpoint before it locks in

## When NOT to use

- The change is to working files (code, scratch docs, tests) — those don't need source-truth gating
- The proposal has already been human-approved — review is over, just route
- The "proposal" is in fact a request to *retract* source truth — that has a different protocol (retraction lane)

## Review gate (5 checks)

1. **Grounded in ≥ 2 evidence refs?** Single-source claims do not pass review. The two refs must be independent (not two views of the same artifact).
2. **Source facts separated from inference?** The proposal text must clearly mark which sentences are observed-fact and which are agent-inference.
3. **Contradictory evidence named?** If contradictory evidence exists, the proposal must acknowledge it and explain why it is being overridden, not silently exclude it.
4. **Privacy / public-surface risk handled?** No `/Users/<user>/` absolute paths, no provider credentials, no private host/port pairs in the body of the proposal (see the parent repo's public-surface safety rules).
5. **Human approval requirement preserved?** The proposal must carry `requires_human_review: true` and must not contain language that pre-empts the operator's decision.

## Verdicts

```text
PASS   Proposal is ready for human approval.
       All 5 review gate checks pass.
       Operator can read it and decide yes/no.

FLAG   Proposal is plausible but missing evidence or boundary clarity.
       At least one gate check fails in a recoverable way.
       Return to author for evidence supplementation or boundary fix.

BLOCK  Proposal weakens source-truth rules, privacy, or verification discipline.
       Promoting it would corrupt downstream caches.
       Reject and write a parking note for the underlying intent.
```

## Hard rules (do NOT do)

- **Never return `accept_as_grounded` as the final state.** This skill returns review verdicts, not approvals. The state after PASS is "ready for human review", not "approved".
- **Never write directly into `source-truth/` or canonical docs.** Even with verdict PASS. That's the operator's call.
- **Never clear `requires_human_review: true` on a proposal.** Even if the proposal looks bulletproof. The flag is the operator's signal to inspect; this skill cannot strip it.
- **Never treat model agreement as approval.** Two models saying "looks good" is two opinions, not one approval.
- **Never collapse `FLAG` into `PASS` to unblock a workflow.** That is LGTM by definition. If a workflow is blocked on FLAG, the right move is to fix the proposal, not to revise the verdict.

## Inputs

```yaml
proposal:
  target_path: <where the proposal would land if approved>
  body: <the proposed source-truth text>
  evidence_refs:
    - <ref 1>
    - <ref 2>
    - ...
  context: <one-line situation>
  origin_agent: <who drafted this>
```

## Output

```yaml
verdict: PASS | FLAG | BLOCK
candidate_for_source_truth: true | false       # true only when verdict == PASS
requires_human_review: true                    # always true; immutable
evidence_refs:
  - <ref echoed>
risks:
  - <one-line risk 1>
  - <one-line risk 2>
operator_decision_needed: <one-line description of the call the operator must make>
```

Note: `requires_human_review` is hardcoded `true` in the output schema. There is no path through this skill that produces `requires_human_review: false`.

## Anti-patterns (failure modes seen in practice)

- **Verdict laundering.** Returning PASS with `risks:` listing the actual blockers, hoping the operator skims past them. Risks belong in FLAG, not in PASS-with-buried-risks.
- **Evidence count gaming.** Listing 5 evidence_refs that are all paraphrases of the same upstream source. Count is necessary but not sufficient — refs must be independent.
- **Boundary lawyering.** Arguing that a `/Users/<user>/` path "isn't really" a privacy issue because the username is public anyway. The rule is BLOCK, not subjective.

## Closeout shape

```text
结论：PASS | FLAG | BLOCK
证据数：N (independent? yes/no)
关键风险：one line
操作员需决定：one line
```

## Related

- [[windburn-cognitive-cache]] — feeds `source_proposal` candidates into this skill
- [[windburn-crabbox-failure-hook]] — produces failure-memory entries that may eventually become belief-cache candidates routed here
