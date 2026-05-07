# Windburn Research Workhorse Appliance v0

Status: implementation slice
Created: 2026-05-07

## North Star

The remote NixOS workhorse should be able to run small, reproducible academic
research loops without becoming a full MUW clone.

The v0 target is the Agent Memory Causality program:

> Agent memory is not storage. It is a causal control surface.

## What v0 Is

`windburn-research-runner` is a narrow research appliance on the existing NixOS
workhorse. It validates and stages research run cards, writes redacted evidence,
and keeps the operator-facing status legible.

It exists to make this loop repeatable:

```text
research question
→ run card
→ isolated runner envelope
→ memory condition
→ pressure condition
→ decision output
→ judge/verifier
→ evidence hash
→ RV sync
→ Linear summary
```

## What v0 Is Not

- Not a full MUW deployment.
- Not a public SaaS surface.
- Not a multi-tenant runtime.
- Not an automatic provider-calling system.
- Not a browser automation lane by default.
- Not a secret manager.
- Not a remote mutation path into production repos.

## Allowed Actions

Research run cards may request:

- `verify-card`: validate schema and public-surface safety.
- `stage-run`: create a dry-run/staged evidence record.
- `status`: report appliance readiness.

All v0 actions are non-mutating outside `/srv/windburn/research` and
`/srv/windburn/evidence/research-appliance`.

## Forbidden Actions

The appliance must not:

- run arbitrary shell from a card;
- read provider tokens;
- write to GitHub, Linear, Hugging Face, or remote repos without a separate
  operator-approved lane;
- render raw hosts, public IPs, SSH targets, credential paths, or secret values;
- claim experiment `PASS` from a staged card alone.

## Evidence Contract

Every run must eventually produce:

- run card;
- memory-state hash;
- prompt text or public-safe prompt reference;
- decision output;
- verification result;
- causal trace notes;
- counterfactual pairing pointer;
- secret/public-surface flags:
  - `secret_values_recorded=false`
  - `redacted_public_safe=true`

## PASS / FLAG / BLOCK

`PASS`:

- card schema is valid;
- action is allowed;
- safety guardrails are false for mutation/secret/provider writeback;
- evidence target is inside the Agent Memory Causality RV program;
- no secret-like or raw endpoint strings are present.

`FLAG`:

- card is valid but only staged/dry-run;
- Hugging Face publication is requested but still gated;
- remote runner exists but no completed experiment evidence exists yet.

`BLOCK`:

- malformed JSON;
- unknown action;
- raw secret-like value;
- raw host/IP/private path;
- remote mutation requested;
- provider writeback requested;
- evidence target outside the approved research program.

## Hugging Face Lane

Hugging Face is useful here, but only as a later export/publication target:

- v0 may prepare `jsonl`, `markdown`, or `parquet` artifacts.
- v0 must not upload datasets automatically.
- dataset publication requires a separate review that proves redaction and
  consent boundaries.
- Jobs are not part of v0. If used later, the job payload must be generated from
  a reviewed artifact, not from raw private run state.

## Remote NixOS Shape

The NixOS module creates:

```text
/srv/windburn/research/specs
/srv/windburn/research/runs
/srv/windburn/research/evidence
/srv/windburn/research/outbox
/srv/windburn/evidence/research-appliance/current.json
```

Installed commands:

- `windburn-research-appliance-status`
- `windburn-research-runner`

The status command is safe to stream. The runner is v0 stage-only.

## First Useful Experiment

Use the RV program:

```text
research-programs/agent-memory-causality/
```

First canary:

- `M0/P1` vs `M1/P1`
- task family: public-surface safety
- output: decision delta + causal trace strength

The first win is not a perfect benchmark. It is a clean example where retrieval
availability and decision impact diverge.
