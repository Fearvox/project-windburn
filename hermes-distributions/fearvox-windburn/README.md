# Fearvox Windburn — Hermes Distribution

> A portable Hermes-style distribution that ships three skills enacting Windburn cognitive-cache discipline. Router + memory steward, not source-truth approver.

| | |
|---|---|
| **Version** | 0.2.0 |
| **Status** | v0.2 — three skills production-shaped; install path operator-driven; live wiring deferred until source-truth gates verified in a sandbox profile |
| **Hermes requires** | ≥ 0.12.0 |
| **Origin** | [project-windburn](https://github.com/Fearvox/project-windburn), `hermes-distributions/fearvox-windburn/` |
| **Direction doc** | [`docs/windburn-cognitive-cache-direction.md` in MUW](https://github.com/Fearvox/multica-ultimate-workbench/blob/main/docs/windburn-cognitive-cache-direction.md) (2026-05-03) |

## What it is

A Senter-shaped distribution package:

```text
SOUL.md            ← agent persona / role contract
config.yaml        ← runtime config (commented per-field)
distribution.yaml  ← manifest with cache-slot mapping + policy declarations
skills/            ← three skills, dependency-ordered
```

With a tighter role contract:

```text
router + cognitive-cache steward
not source-truth approver
not unchecked runtime mutator
not broad autopilot
```

## Cognitive cache slots served

This distribution directly serves four canonical Windburn cache slots and one non-cache holding lane:

| Slot / lane | Type | Skill | Status |
|-------------|------|-------|--------|
| **source** | canonical cache slot | `windburn-cognitive-cache` (routing only) | proposal-layer |
| **episodic** | canonical cache slot | `windburn-cognitive-cache` + `windburn-crabbox-failure-hook` | shipped |
| **belief** | canonical cache slot | `windburn-source-truth-review` (gate only, no auto-promote) | shipped |
| **failure** | canonical cache slot | `windburn-crabbox-failure-hook` | shipped |
| **parking** | holding lane, not one of the seven cache slots | `windburn-cognitive-cache` | shipped |

The three canonical cache slots NOT served here:
- `perception` — handled at the parent repo level (`scripts/windburn-side-lane-perception-bus.mjs`)
- `procedural` — handled at the parent repo level (`goalv3-cc` operator skill install)
- `working` — not yet implemented (substrate gap)

## The three skills (dependency-ordered)

```text
windburn-cognitive-cache        (entry point — classifies any memory candidate)
    │
    ├─ routes "source_proposal" candidates ──────► windburn-source-truth-review
    │
    └─ classifies output of ─────────────────────  windburn-crabbox-failure-hook
                                                   (which runs before/after every remote workhorse call)
```

### `windburn-cognitive-cache` — classify-and-route

The entry point. Takes a memory candidate and emits a routing decision: `perception`, `belief`, `failure`, `procedure`, `parking`, `source_proposal`, or `reject`. Each route comes with `trust_level`, `requires_human_review`, and a concrete `next_action`. No silent category promotion.

See `skills/windburn-cognitive-cache/SKILL.md`.

### `windburn-source-truth-review` — review-gate

Reviews source-truth proposals against a 5-check gate (≥ 2 independent evidence refs, fact-vs-inference separation, contradictory evidence named, public-surface safety, human-approval-flag preserved). Returns `PASS | FLAG | BLOCK`. **Never returns "approved"** — final approval is operator-only, always.

See `skills/windburn-source-truth-review/SKILL.md`.

### `windburn-crabbox-failure-hook` — remote-run-wrapper

Wraps remote workhorse runs with a three-stage protocol: prediction packet (before), observed delta (after), failure memory (on mismatch). Forces the agent to predict before acting, compare deltas after, and produce an `avoid_rule` or `retry_condition` for every failure. Failures without either are rejected — a failure without learning is just a complaint.

See `skills/windburn-crabbox-failure-hook/SKILL.md`.

## Non-negotiables

- Never auto-promote into source truth.
- Never weaken human approval gates.
- Never expose secrets, private host data, raw provider payloads, or local-only command logs in public surfaces.
- Never treat a retrieved memory as proof by itself.
- Never repeat a failed action under the same state without satisfying the `retry_condition` or asking the operator.

These are enforced jointly by SOUL.md (agent persona), `config.yaml` (`policy` section), and the per-skill invariants.

## Install (operator-driven)

This directory is NOT wired into a live Hermes profile by default. To stand it up:

```sh
# 1. Choose a target Hermes distribution path on the operator host.
#    Replace <hermes-dist-path> with the actual path on that host.

# 2. Copy or symlink this folder into that path:
cp -R hermes-distributions/fearvox-windburn <hermes-dist-path>/fearvox-windburn
# OR
ln -s "$(pwd)/hermes-distributions/fearvox-windburn" <hermes-dist-path>/fearvox-windburn

# 3. Verify the runtime sees the four expected manifest files:
hermes-runtime list-distributions | grep fearvox-windburn

# 4. Smoke-test in a sandbox profile (NOT production) first:
hermes-runtime profile sandbox --distribution fearvox-windburn
hermes-runtime smoke --profile sandbox --task "echo classify a parking note"
```

If you don't have `hermes-runtime` on PATH, the distribution still validates as a static package — read SOUL.md and the three SKILL.md files directly; the contract holds regardless of host runtime version.

## Verification before binding to production

Before binding this distribution to production RV, Superconductor, or remote workhorse credentials, verify each of:

1. **Source-truth gate dry-run**: feed a deliberately under-evidenced proposal through `windburn-source-truth-review`. Expect `FLAG`, not `PASS`. If `PASS`, the gate is broken.
2. **Failure-hook retry-rejection**: trigger a known-failed action without satisfying its `retry_condition`. Expect the run to stop or escalate. If it proceeds, the hook is broken.
3. **Public-surface scan**: run the parent repo's public-surface check against any generated artifact:
   ```sh
   grep -E "/Users/<user>/|sk-[a-zA-Z0-9]{30,}|ghp_[a-zA-Z0-9]{30,}|Bearer " <artifact>
   ```
   Expect 0 matches. Any match BLOCKs the bind.

Keep the first live test bounded to a disposable target. Failure during sandbox is fine; failure during production binding can corrupt downstream caches.

## Related

- Parent repo: [project-windburn](https://github.com/Fearvox/project-windburn) — substrate, runtime scripts, evidence trail
- Direction doc: MUW `docs/windburn-cognitive-cache-direction.md` — canonical design intent (2026-05-03)
- Agent grounding: parent repo `CLAUDE.md` — workbench discipline + anti-LGTM invariant + operator-locked lanes
- Cross-source sync: parent repo `docs/research/2026-05-14-muw-windburn-cognitive-cache-sync.md` — current 7-cache slot status
