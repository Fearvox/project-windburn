# RecursiveMAS Latent-State Causality Intake

Status: research intake / canary design
Created: 2026-05-08

## Source Snapshot

- Paper: `Recursive Multi-Agent Systems`, arXiv `2604.25917v1`
- Repo: `RecursiveMAS/RecursiveMAS`
- Repo readback: shallow clone at commit `bfb0a4e` (`Update README.md`)
- Scope used here: static paper/code intake only
- Explicit non-actions: no Hugging Face checkpoint download, no GPU run, no remote workhorse mutation

## Paper Summary

RecursiveMAS shifts the collaboration medium for multi-agent systems from
decoded text to latent state. Instead of a planner, critic, solver, or
specialist passing natural-language messages between agents, each agent
generates latent thoughts. Lightweight `RecursiveLink` modules transform those
hidden states within an agent and across heterogeneous agents, then the whole
system recurs over several rounds before the final agent decodes text.

The paper positions this as system-level recursive computation:

- agents act like layers in a looped computation graph;
- inner links map an agent's last-layer hidden state back into its own input
  embedding space;
- outer links map latent thoughts between agents with different hidden sizes;
- training freezes base LLMs and updates the link modules;
- only the final recursion round needs to emit a visible textual answer.

The claimed benefit is not just better prompting. It is a different substrate
for coordination: lower token cost, lower text-decoding latency, and trainable
cross-agent state transfer. The paper reports an average accuracy improvement
over its baselines, inference speedups, and token reduction, but those claims
depend on released checkpoints and training details that were not executed in
this intake.

## Repo Readiness Assessment

Current repo shape:

- `README.md` describes inference usage and says complete training/data pipeline
  is still pending.
- `modeling.py` implements the released adapter shapes:
  - `Adapter` for inner latent residual links;
  - `CrossModelAdapter` for outer cross-agent latent links.
- `load_from_repo.py` maps collaboration styles to released Hugging Face model
  repos.
- `hf_resolver.py` calls `snapshot_download` for model repos and expects adapter
  manifests or `.pt` files.
- `system_loader.py` provides a high-level loader for a released MAS system.
- `run.py` is the unified checkpoint-backed inference entrypoint.
- `inference_utils/` contains the concrete sequential, mixture, distillation,
  and deliberation inference paths.

Readiness verdict:

| Area | Intake Result |
| --- | --- |
| Paper source | Present in local arXiv tar |
| Inference harness | Present |
| HF checkpoint mapping | Present |
| Complete training pipeline | Not present in repo snapshot |
| Tests | Not found |
| License file | Not found |
| Local lightweight syntax check | Passed via `python3 -m compileall -q` |
| Checkpoint-light runnable proof | Not proven |
| GPU / remote appliance proof | Not attempted |

This is enough for research design and static smoke. It is not enough to claim a
working local L1 condition.

## Why This Matters For Agent Memory Causality

The Agent Memory Causality program asks whether a memory surface changes an
agent's decision, not just whether the agent can retrieve or cite it.
RecursiveMAS creates a third intervention type:

1. text collaboration: visible messages and scratchpads;
2. explicit memory/bootstrap: durable state injected into prompt or session
   setup;
3. latent recursive handoff: state passed as hidden embeddings across agents.

That third type matters because it can change the decision while leaving less
visible evidence than either text messages or explicit memory. It is a direct
stress test for the Workhorse question:

> If the final answer changes, can we prove which upstream state changed it?

RecursiveMAS is therefore useful less as an immediate runnable dependency and
more as a canary pressure source for causal trace design.

## Comparison

| Condition | Collaboration Medium | Observable By Default | Main Benefit | Main Audit Risk |
| --- | --- | --- | --- | --- |
| T0 text MAS | Text messages / visible scratchpad | High | Easy transcript and blame assignment | Token-heavy; intermediate text can leak public-surface details |
| M1 explicit memory | Memory bootstrap / retrieved notes | Medium | Durable state can be hashed, cited, and ablated | Agents may cite memory without it changing the decision |
| L1 latent recursive handoff | Hidden states transformed by RecursiveLink | Low | Lower token cost and possible stronger system-level coordination | Provenance becomes opaque unless latent-state hashes and intervention points are logged |

## Provenance And Audit Risk

Latent-state collaboration worsens the "who changed the decision?" problem.
With text MAS, the trace is expensive but visible. With explicit memory, the
trace can at least point to a retrieved document, bootstrap note, or memory
hash. With latent handoff, the decision delta may be caused by an embedding
projection that no public reviewer can inspect semantically.

Any Windburn use of L1 needs extra evidence:

- stable hash of the latent handoff tensor or surrogate;
- role and recursion-round labels for every handoff;
- explicit counterfactual pair pointer;
- verifier result that distinguishes answer-only changes from real decision
  changes;
- public-safe trace summary that does not expose raw hidden states, raw prompts
  containing private material, host details, or credential paths.

Do not publish raw latent tensors as public evidence. Treat them as private
operator/runtime material and publish only hashes, dimensions, and verifier
summaries unless a separate data-release review approves more.

## Research Appliance Canary Design

Goal: compare visible collaboration, explicit memory, and latent handoff under
one Agent Memory Causality fixture family without claiming a runnable
RecursiveMAS reproduction until a checkpoint-light proof exists.

### T0: Text MAS / Visible Scratchpad Baseline

- Medium: explicit text between roles.
- Task family: `public-surface-safety`.
- Pressure: `P1`, same as the first Agent Memory Causality canary direction.
- Evidence:
  - prompt text;
  - visible intermediate messages;
  - final decision;
  - verifier judgment;
  - public-surface leak scan.
- Expected value: maximum auditability, highest token cost.

### M1: Explicit Memory / Bootstrap Condition

- Medium: existing Windburn memory/bootstrap route.
- Task family: `public-surface-safety`.
- Counterfactual: `T0/P1` vs `M1/P1`.
- Evidence:
  - memory-state hash;
  - bootstrap or retrieval reference;
  - final decision;
  - verifier judgment;
  - decision-delta explanation.
- Expected value: tests whether explicit memory changes action, not just
  citation.

### L1: Latent Recursive Handoff Condition

- Medium: RecursiveMAS-style latent handoff.
- Runnable status: not yet runnable in Windburn from this intake.
- Required before execution:
  - checkpoint-light local reproduction or reviewed small surrogate;
  - no large HF download unless explicitly scoped;
  - no remote appliance mutation without operator approval;
  - latent-hash capture and round/role trace schema.
- Counterfactual: `T0/P1` vs `L1/P1`, then `M1/P1` vs `L1/P1`.
- Expected value: tests whether hidden state transfer can improve decisions
  while maintaining a usable provenance trace.

## Metrics

Each canary result should emit:

- `decision_delta`: whether the decision changed relative to the paired
  baseline;
- `answer_accuracy_or_quality`: task-specific quality score;
- `token_cost`: visible prompt/output tokens where measurable;
- `runtime_cost`: wall time or local runner cost;
- `auditability_score`: 0-5 score for how well a reviewer can reconstruct
  causality;
- `provenance_trace_completeness`: fraction of required trace fields present;
- `public_surface_leak_risk`: `PASS`, `FLAG`, or `BLOCK` after redaction scan.

## Proposed Canary Cards

```text
card_id: recursivemas_t0_text_mas_public_surface_safety
condition: T0/P1
action: design-only
verdict: FLAG until a local text-MAS runner writes evidence
```

```text
card_id: recursivemas_m1_explicit_memory_public_surface_safety
condition: M1/P1
action: design-only
verdict: FLAG until paired memory-state hash and verifier output exist
```

```text
card_id: recursivemas_l1_latent_handoff_public_surface_safety
condition: L1/P1
action: design-only
verdict: BLOCK for execution until checkpoint-light reproduction or surrogate
is explicitly approved and proven
```

## Recommended Next Slice

Do not start by downloading RecursiveMAS checkpoints. Start with a local
surrogate that preserves the audit question:

1. create a tiny latent-handoff surrogate that passes arrays or hashed vectors
   between roles;
2. run `T0/P1` and `M1/P1` with the existing public-surface-safety fixture;
3. run `L1/P1` only after the surrogate emits role/round/hash trace fields;
4. compare decision delta and auditability, not only answer quality.

If the surrogate can prove trace discipline, then a later GPU/HF lane can try a
real RecursiveMAS checkpoint under explicit model-download scope.

## Intake Verdict

`FLAG`: RecursiveMAS is research-relevant and the repo is syntax-clean, but the
released repo is checkpoint-heavy and training-incomplete. The Windburn L1
condition is a canary design, not a proven runnable appliance lane.
