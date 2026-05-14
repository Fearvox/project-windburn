# Gbrain Read-Only Provider Pressure Test

Date: 2026-05-11

## Verdict

FLAG for semantic provider integration.

PASS for literal read-only retrieval.

The pressure test found a sharp boundary: Gbrain can serve as a literal memory
lookup substrate in the current sandbox, but it is not ready to act as a
semantic Windburn provider. The failure mode is retrieval recall, not process
stability.

## Test Shape

- isolated sandbox home;
- PGLite local brain;
- two seeded pages: Windburn cognitive cache and Crabbox failure hook;
- no global brain writes;
- no Windburn source-truth writes;
- no Research Vault source-truth writes;
- 104 literal checks;
- 104 natural-language semantic checks;
- burst concurrency capped at 4.

## Results

| Suite | Result | Pass Rate | Latency p50 | Latency p95 | Meaning |
| --- | --- | ---: | ---: | ---: | --- |
| literal | PASS | 100.00% | 269 ms | 1776 ms | exact titles and phrases route reliably |
| semantic | FLAG | 12.50% | 258 ms | 1310 ms | natural-language queries mostly return no results |

Recurring warning:

```text
google_recipe_max_batch_tokens_warning
```

## Windburn Interpretation

This confirms the current integration boundary:

```text
Gbrain result
  -> perception
  -> parking or belief proposal
  -> source-truth proposal only after separate evidence and human approval
```

Do not treat Gbrain output as durable belief by itself. In the current state,
it is a retrieval signal, not a trusted cognition layer.

## Decision

Allowed:

- read-only literal lookup experiments;
- provider adapter prototypes with no write method;
- citation capture into parking;
- comparison against Windburn `.learning` retrieval.

Blocked:

- semantic provider claims;
- automatic belief promotion;
- direct source-truth writes;
- long-running Gbrain daemon/autopilot;
- hiding doctor warnings from operator review.

## Retest Gate

Before Gbrain can be considered for provider use:

1. embeddings or alias expansion must be enabled;
2. semantic pressure pass rate should reach at least 90%;
3. doctor warnings must be either fixed or intentionally accepted in a scoped
   risk note;
4. source-truth promotion must remain proposal-only and human-reviewed.
