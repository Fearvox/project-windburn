---
name: windburn-crabbox-failure-hook
description: Wrap remote workhorse runs with prediction, observed delta, and failure-memory objects.
version: 0.1.0
platforms: [linux, macos, windows]
metadata:
  tags: [windburn, crabbox, remote-workhorse, failure-memory, verification]
---

# Windburn Crabbox Failure Hook

Use this skill before and after a remote workhorse run, including Crabbox-style
lease/sync/run/release loops or Windburn's current remote scripts.

## Before Run

Write a prediction packet:

```yaml
run_id:
repo:
action:
expected_delta:
success_criteria:
preconditions:
relevant_beliefs:
relevant_failures:
```

Search for matching prior failures. If one matches, do not repeat the action
unless the retry condition is satisfied.

## After Run

Write an observed delta:

```yaml
run_id:
exit_code:
verdict: PASS | FLAG | BLOCK
actual_delta:
evidence_refs:
redacted_summary:
```

If `expected_delta` and `actual_delta` disagree, write failure memory:

```yaml
state_before:
action_tried:
predicted:
actual:
inferred_reason:
avoid_rule:
retry_condition:
evidence_refs:
```

## Benchmark

Score `no_repeat_failed_action`:

- `1.0`: matching failure retrieved and action changed.
- `0.5`: matching failure retrieved and operator asked.
- `0.0`: same action repeated under same failed preconditions.

## Closeout Shape

```text
结论：PASS/FLAG/BLOCK.
预测：one line.
实际：one line.
失败记忆：written/not-needed.
下一步：one concrete action.
```
