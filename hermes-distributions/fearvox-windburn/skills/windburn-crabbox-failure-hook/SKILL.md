---
name: windburn-crabbox-failure-hook
description: Wrap remote workhorse runs with prediction → observed-delta → failure-memory packets. Captures the failure cache.
version: 0.2.0
platforms: [linux, macos, windows]
metadata:
  tags: [windburn, crabbox, remote-workhorse, failure-memory, verification]
  cache_slots: [failure]
  invariant: a failure with no avoid_rule or retry_condition is not learning
---

# Windburn Crabbox Failure Hook

Pre-/post-run hook that turns a remote workhorse execution into a failure-cache contribution. Forces the agent to predict before running and to compare delta after, so failures become reusable learning instead of noise.

## Purpose (one line)

Make every remote run leave a usable trace in the failure cache: predicted-vs-actual delta, root cause hypothesis, and an `avoid_rule` or `retry_condition` for the next attempt.

## Cache slots this skill serves

- **failure** — Direct producer. Each run that disagrees with prediction emits a failure-memory object.
- **episodic** (indirect) — Prediction and observed-delta packets are episodic by nature; they should also be archived in episodic order downstream.

## When to use

Before AND after any of:

- Crabbox-style lease / sync / run / release loops
- Windburn's remote workhorse scripts (`scripts/remote-*.sh`)
- Hermes runtime maintenance / yolo / canary flows
- Any tool call where "prediction" is meaningful (i.e. you have an expected delta to compare against)

## When NOT to use

- Pure read-only operations (no delta possible)
- Local dev-loop runs where prediction overhead exceeds task value
- Operations whose only "delta" is a stdout summary the operator reads anyway

## Three-stage protocol

### Stage 1 — Before run: write prediction packet

```yaml
run_id: <stable identifier>
repo: <repo or system under change>
action: <one-line description of what's about to be attempted>
expected_delta:
  - <observable change 1>
  - <observable change 2>
success_criteria:
  - <verifiable assertion 1>
  - <verifiable assertion 2>
preconditions:
  - <state that must hold before run>
relevant_beliefs:
  - <belief-cache ref>
relevant_failures:
  - <failure-cache ref — see below>
```

**Mandatory lookup**: Search the failure cache for entries whose `state_before` matches the current preconditions. If a matching failure exists:

- If its `retry_condition` is satisfied → proceed, record that the retry condition was satisfied.
- If its `retry_condition` is NOT satisfied → do NOT repeat the action. Escalate to operator OR change the action.
- If no `retry_condition` was recorded → operator decision required.

### Stage 2 — After run: write observed delta

```yaml
run_id: <same as prediction>
exit_code: <integer>
verdict: PASS | FLAG | BLOCK
actual_delta:
  - <observed change 1>
  - <observed change 2>
evidence_refs:
  - <log path or evidence pointer — redacted if public surface>
redacted_summary: <one paragraph, public-surface-safe>
```

### Stage 3 — On mismatch: write failure memory

If `expected_delta` and `actual_delta` disagree (even partially):

```yaml
state_before: <preconditions snapshot>
action_tried: <action field from prediction>
predicted: <expected_delta snapshot>
actual: <actual_delta snapshot>
inferred_reason: <one-line hypothesis>
avoid_rule: <when to NOT repeat this action — required if no retry_condition>
retry_condition: <state that must change before retrying — required if no avoid_rule>
evidence_refs:
  - <evidence pointer>
```

**Hard invariant**: at least one of `avoid_rule` or `retry_condition` MUST be non-empty. A failure entry without either is not learning; it is a complaint. Reject such entries.

## Benchmark — `no_repeat_failed_action`

Score every subsequent run that hits a precondition matching a known failure:

| Score | Behavior |
|-------|----------|
| 1.0   | Matching failure retrieved AND action changed (per `avoid_rule`) OR retry condition explicitly satisfied |
| 0.5   | Matching failure retrieved AND operator asked before retrying |
| 0.0   | Same action repeated under same failed preconditions (regression) |

A `0.0` score is a system-level FLAG worth surfacing to the operator immediately — the failure cache is being ignored.

## Anti-patterns (do NOT do)

- **Skipping the prediction packet because "this run is obviously going to succeed".** Predictions are cheap; surprise findings are how the failure cache actually grows.
- **Writing a failure entry with `inferred_reason: unknown`.** Unknown is an honest answer for a moment, but the entry should be re-visited and updated before it's filed permanently — otherwise it pollutes the cache with un-actionable junk.
- **Padding `success_criteria` to be unfalsifiable.** Criteria like "the command completed" make the verdict always PASS even when the actual change failed. Criteria must be observation-shaped.
- **Reusing a prior `run_id`.** Each run gets a fresh identifier; reuse corrupts the audit trail.
- **Treating `verdict: PASS` as "no failure entry needed" without comparing deltas.** PASS-on-verdict + delta-mismatch is exactly the case the failure cache is for — disagreement between prediction and reality even when nothing crashed.

## Public-surface safety

`evidence_refs` may point at local logs containing absolute paths, secrets, or host identifiers. Those are operator-private. The `redacted_summary` field is the **public-safe surface** — write it as if anyone could read it.

Before any `git commit` that includes failure-cache artifacts:

```sh
grep -E "/Users/<user>/|sk-|ghp_|Bearer " <file>   # expect: 0 matches
```

## Closeout shape

```text
结论：PASS | FLAG | BLOCK
预测：one line
实际：one line
失败记忆：written | not-needed (delta matched) | rejected (missing avoid/retry rule)
下一步：one concrete action
```

## Related

- [[windburn-cognitive-cache]] — classifies the failure entries this skill emits
- [[windburn-source-truth-review]] — gates any failure-memory promotion to belief / source-truth status

## Origin

Named "crabbox" after the Crabbox lease/sync/run/release pattern from the broader Multica ecosystem. The hook shape generalizes to any remote-execution loop where prediction-and-comparison is meaningful.
