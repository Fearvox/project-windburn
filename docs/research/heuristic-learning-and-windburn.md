# Heuristic Learning And Windburn

Status: research distillation
Date: 2026-05-11
Source: `Trinkle23897/learning-beyond-gradients` local scouting clone

## Core Translation

Learning Beyond Gradients reframes learning as something a coding agent can do
to a maintained software system:

```text
environment feedback / test failure / log anomaly
-> coding agent reads context
-> edits policy / test / memory
-> reruns
-> writes results back into trials and summaries
-> continues
```

Windburn's translation:

```text
tool feedback / browser failure / remote-run failure / human correction
-> agent reads perception + belief + failure memory
-> changes action policy, test, route, or source-truth proposal
-> verifies delta
-> writes durable learning
-> compresses local patches into reusable memory
```

## Heuristic System

A Heuristic System is not one rule. It is the maintained object around a rule.

For Windburn:

```text
HS =
  policy
  state representation
  perception intake
  belief registry
  failure ledger
  verification fixtures
  replay/golden traces
  memory routing
  compression mechanism
```

The object being improved is not model weights. It is the operational system
that lets future agents act differently.

## Why This Matters

Current agents often do this:

```text
observe -> guess -> act -> fail -> explain -> try same thing again
```

Windburn wants:

```text
observe -> predict -> act -> compare -> update failure/belief -> choose differently
```

The second loop is Heuristic Learning applied to agent runtime.

## Mapping To Windburn Objects

| Heuristic Learning concept | Windburn object |
| --- | --- |
| environment state | perception object |
| rule/policy | action policy hint |
| trial log | episodic event |
| failure video/replay | evidence ref |
| regression case | verification fixture |
| memory | belief/failure/procedural cache |
| code patch | route or skill update |
| compression | source-truth proposal or simplified rule |

## Absorb And Compress

Heuristic Learning has two required operations:

```text
absorb feedback
compress history
```

Windburn should make both explicit.

Absorb:

- write the failed prediction;
- preserve actual observed delta;
- attach evidence refs;
- lower or challenge beliefs;
- create retry conditions.

Compress:

- merge repeated local failures into one rule;
- convert a pile of session observations into a stable belief only after
  verification;
- propose source-truth updates for human approval;
- delete or archive obsolete avoid rules when evidence changes.

## Coupling Complexity

The article's most useful bottleneck is coupling complexity:

```text
how many interdependent states, rules, tests, feedback signals, and historical
constraints an update must account for at once
```

Windburn can lower coupling complexity by pushing memory out of the model and
into structured objects:

- `Perception`: what the world/tool reported.
- `Belief`: what the agent currently thinks is true.
- `FailureMemory`: what action failed and under what condition.
- `SourceTruthProposal`: what may become canonical after human approval.
- `VerificationFixture`: what must keep passing.

This lets the model reason over smaller, typed packets instead of re-reading a
whole transcript.

## Oncology Trial Sandbox Mapping

The same framework applies to the planned oncology-trial sandbox:

```text
trial fixtures
-> simulated patient-state updates
-> eligibility/adverse-event/lab/scan state changes
-> agent actions
-> predicted vs actual trial state
-> failure memory
-> no-repeat benchmark
```

Physical AI here does not require robotics. It means:

```text
agent acts in a medically constrained operational world
```

Trial-state fixtures behave like an environment. Labs update, scans arrive,
adverse events emerge, and eligibility changes. The agent must perceive these
updates and adjust without touching real patient data.

## Benchmark Shape

Benchmark name:

`windburn_no_repeat_failed_action`

Minimum fixture:

```yaml
episode:
  state_before: "page still on eligibility form; red warning visible"
  predicted: "submit moves to next section"
  action: "click submit"
  actual: "page unchanged; red warning persists"
  failure_memory: "missing required field; submit is invalid until field is filled"
  next_attempt:
    pass_condition: "agent fills required field or asks for missing data before submit"
    fail_condition: "agent clicks submit again without changing state"
```

Score:

- `PASS`: action changed and retry condition was satisfied.
- `FLAG`: agent recognized the failure but stopped for human input.
- `BLOCK`: agent repeated the failed action.

## Design Rule

Windburn memory should be judged by behavior change, not only retrieval quality.

Retrieval metric:

```text
Did the context include the right failure?
```

Causality metric:

```text
Did the included failure change the next action?
```

The second metric is the moat.

## First Build Slice

1. Pick one local repeat-failure fixture.
2. Write a failure object.
3. Compile a context pack that includes it.
4. Ask an agent to plan the next action.
5. Score whether it repeats the failure.
6. Store the result as a regression fixture.

No model training required. No provider lock-in required. This is a software
learning loop.
