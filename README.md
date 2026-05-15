# Windburn

> A memory-native agent substrate. Not a new base model — a cognitive cache layer above model-serving that turns observation, tool feedback, failure, and source-truth into durable future-self cognition.

The canonical design intent lives in the [MUW Windburn Cognitive Cache Direction](https://github.com/Fearvox/multica-ultimate-workbench/blob/main/docs/windburn-cognitive-cache-direction.md) (dated 2026-05-03). This repository is the build-state: the substrate, the runtime, and the evidence trail.

## One-Line Thesis

```text
observe reality → update belief → choose action → verify delta → preserve learning
```

The transformer KV cache answers *"what tokens have I already attended to?"*. The Windburn cognitive cache answers *"what reality have I already learned?"*.

## Seven Cache Slots (current state)

| Slot | Role | Status | Where it lives |
|------|------|--------|----------------|
| **source** | Research Vault, repo docs, source-of-truth files | ✅ shipped (proposal layer) | OpenChronicle install proposal + RV MCP read-only contract |
| **episodic** | What happened, in order | ✅ shipped (proposal layer) | OpenChronicle ingest plan for `~/.claude/learnings/` + read-only mirror of upstream agent memory |
| **perception** | Grounded observations from tools and humans | ✅ shipped | `scripts/windburn-side-lane-perception-bus.mjs` + bounded boundary smoke |
| **failure** | Actions attempted, observed deltas, avoid/retry rules | ✅ shipped | `docs/remote-workhorse/WINDBURN_CRABBOX_FAILURE_HOOK.md` + `hermes-distributions/fearvox-windburn/skills/windburn-crabbox-failure-hook/` |
| **procedural** | Reusable skills, repo routes, tool patterns | ✅ shipped | `goalv3-cc` skill (filesystem-only at `~/.claude/skills/goalv3-cc/`) + captured lessons in `docs/superpowers/plans/2026-05-12-goalv3-cc-PLAN-CLOSEOUT.md` |
| **belief** | Hypotheses with evidence and confidence | ⚠️ skeleton | `hermes-distributions/fearvox-windburn/skills/windburn-source-truth-review/` (scaffold only) |
| **working** | Current session focus + task stack | ❌ gap | per-session auto-memory partial proxy; no formal substrate yet |

Cross-source sync record: [`docs/research/2026-05-14-muw-windburn-cognitive-cache-sync.md`](docs/research/2026-05-14-muw-windburn-cognitive-cache-sync.md).

## Substrate Layer: Remote Workhorse

The cognitive cache needs durable compute. The first substrate slice is the DigitalOcean-backed NixOS workhorse reachable through the `remote-workhorse` route label, with contract-first evidence, tool truth, and a read-only canary before remote provisioning.

### Fast Path

```sh
scripts/superconductor-codex-intake.sh
scripts/check.sh
scripts/preflight.sh
scripts/remote-host-proof.sh
scripts/digitalocean-snapshot.sh
scripts/nixos-conversion.sh
scripts/nixos-remote-rebuild.sh
scripts/remote-secret-sync.sh
scripts/remote-provider-smoke.sh
scripts/remote-codex-auth-sync.sh
scripts/remote-hermes-codex-smoke.sh
scripts/droplet-engagement-review.sh
scripts/digitalocean-observability.sh
scripts/hermes-health-gate.sh
scripts/hermes-maintenance.sh
scripts/hermes-yolo-loop.sh
scripts/fusion-chat-preview.sh
scripts/fusion-chat-bridge.sh
scripts/multica-runtime-card-verify.sh
scripts/windburn-captain-runtime.sh
scripts/xai-setup-agent.sh
scripts/multica-codex-cache-janitor.sh
```

For one-shot DigitalOcean read-only preflight without storing a `doctl` context, export `DIGITALOCEAN_ACCESS_TOKEN`, `DIGITALOCEAN_TOKEN`, or `DOCTL_ACCESS_TOKEN` in your local shell before `scripts/preflight.sh`. Evidence records only the variable name, not the token value.

If `just` is installed:

```sh
just superconductor-intake
just check
just remote-proof
just snapshot-dry-run
just nixos-conversion-dry-run
just nixos-rebuild-dry-run
just remote-secret-dry-run
just remote-provider-smoke
just remote-codex-auth-dry-run
just remote-hermes-codex-smoke
just droplet-engagement-review
just do-observability
just hermes-health
just hermes-maintenance-inspect
just hermes-yolo-inspect
just fusion-chat-preview
just fusion-chat-bridge
just multica-runtime-card-verify
just windburn-captain-runtime-status
just xai-setup-inspect
just xai-setup-smoke
```

## Repo Map

### Cache layer
- `docs/research/2026-05-14-muw-windburn-cognitive-cache-sync.md` — current 7-cache slot status, public-safe sync record.
- `docs/superpowers/` — design specs, implementation plans, and captured-lessons closeouts for the procedural cache (notably `goalv3-cc` skill).
- `docs/research/` — research-level material (cognitive cache theory, heuristic learning, etc.).
- `hermes-distributions/fearvox-windburn/` — the distribution package: cognitive-cache, source-truth-review, and crabbox-failure-hook skills wired into a Hermes-shaped artifact.
- `.goal/` (gitignored, local-only) — per-goal state directories for `goalv3-cc`-driven autonomous work.

### Substrate / runtime layer
- `docs/remote-workhorse/` — approved design, Phase 1 artifacts, canary report, and the v1 Multica/gstack bootstrap runtime-queue handshake docs.
- `docs/superconductor-codex-intake.md` — Superconductor-side Codex handoff and read-only intake contract.
- `crates/runtimectl/` — Rust CLI for local doctor and canary evidence.
- `config/tool-registry.toml` — required, optional, and disabled tool policy.
- `docs/external-indexes/` — generated GitHub indexes for frontier stack repos.
- `flake.nix` — Nix dev shell/build scaffold for the remote workhorse cell.
- `nixos/hosts/windburn-workhorse-nyc1/` — first-boot NixOS host import.
- `apps/fusion-chat-terminal/` — dot-matrix web terminal for the unified remote chat entrance.

### Side-lane perception + scoring
- `scripts/windburn-side-lane-perception-bus.mjs` — bounded perception bus v0 for side-lane artifacts.
- `scripts/windburn-side-lane-boundary-smoke.mjs` — boundary-integrity smoke for relayed artifacts.
- `scripts/windburn-side-lane-goal-score.mjs` — 8-dimension scoring layer above perception bus.
- `docs/protocols/2026-05-12-codex-side-lane-perception-bus-v0.md` — perception bus protocol spec.
- `docs/goals/2026-05-12-side-lane-goal-metrics-v0.md` — 8-dimension goal metric scheme (boundary, scope, source-truth, traceability, ledger hygiene, public surface, model visibility, ...).

### Remote workhorse scripts (selected)
- `scripts/nixos-remote-rebuild.sh` — guarded remote NixOS test/switch deploy.
- `scripts/remote-secret-sync.sh` — allowlisted root-only provider secret sync.
- `scripts/remote-provider-smoke.sh` — remote provider smoke and repair card.
- `scripts/remote-codex-auth-sync.sh` — root-only Codex CLI plus Hermes `openai-codex` auth sync.
- `scripts/remote-hermes-codex-smoke.sh` — pinned Hermes `openai-codex` remote model-call smoke.
- `scripts/droplet-engagement-review.sh` — read-only DO/CCR/Hermes/Windburn engagement gate for remote pre-flight.
- `scripts/digitalocean-observability.sh` — dry-run first DO uptime/alert desired-state gate.
- `scripts/hermes-health-gate.sh` — read-only Hermes service, task, update, and tmux runtime-entry health gate.
- `scripts/hermes-maintenance.sh` — guarded Hermes update and fixed tmux runtime-entry maintenance path.
- `scripts/hermes-yolo-loop.sh` — guarded `hermes --yolo` tmux runtime loop and `openai-codex` one-shot proof.
- `scripts/fusion-chat-preview.sh` — static preview server for the fusion chat terminal.
- `scripts/fusion-chat-bridge.sh` — local read-only bridge server for live repo/proof hydration in the fusion chat terminal.
- `scripts/multica-runtime-card-verify.sh` — local verifier for the redacted Multica runtime-card contract.
- `scripts/windburn-captain-runtime.sh` — forced-command-friendly Captain runtime wrapper for stdin cards, bounded `run-card` queue execution, lease slots, spool status JSON, and compact redacted summaries.
- `scripts/xai-setup-agent.sh` — local xAI setup lane smoke gate using operator-owned credentials with redacted evidence.

### Ops + reliability
- `docs/ops/` — local reliability guards and public repo hardening specs such as Multica Codex cache pruning and GitHub rulesets.

## Current Boundary

This repo runs a DigitalOcean-backed NixOS workhorse reachable through the `remote-workhorse` route label. Public docs stay redacted: host details, snapshot ids, SSH targets, and operator-local absolute paths belong in operator-private proof surfaces, not in shared repo docs. Remote NixOS changes still go through `nixos-rebuild test` before `switch`. Provider smoke remains intentionally gated behind root-only allowlisted secret sync and may return `REMOTE_PROVIDER_SECRET_MISSING` until usable operator-owned provider profiles exist on the runtime host. The Codex-on-Hermes runtime path is proven in the remote-workhorse preflight docs through redacted evidence refs. Substrate work still succeeds only when a new agent can rerun the proof path, see which tools are usable, and return `PASS`, `FLAG`, or `BLOCK` without guesswork.

For Superconductor sessions, begin with `scripts/superconductor-codex-intake.sh` so the agent proves whether the canonical Windburn repo is attached through the expected Superconductor binding without copying raw operator-local paths into shared docs.

## Public-surface safety rules

Following the metric scheme in `docs/goals/2026-05-12-side-lane-goal-metrics-v0.md`:

- Absolute home directory paths (`/Users/<user>/...`, `/home/<user>/...`) in `docs/*.md` and `*.html`: **BLOCK**.
- Provider credential-shaped strings (`sk-...`, `ghp_...`, `sk-ant-...`, `Bearer ...`, `AKIA...`): **BLOCK**.
- Local queue filenames, socket paths, hook paths in public surface: **FLAG** (informational, may be redacted on commit).
- Public host/port combinations: **BLOCK**.

`scripts/` are operator-only surface and may contain local paths; `docs/`, top-level `*.md`, and `*.html` are public surfaces and are scanned against these rules.

## Pointers

- **Cognitive cache substrate design** — [`docs/windburn-cognitive-cache-direction.md` in MUW](https://github.com/Fearvox/multica-ultimate-workbench/blob/main/docs/windburn-cognitive-cache-direction.md) (canonical direction)
- **Cross-source sync** — [`docs/research/2026-05-14-muw-windburn-cognitive-cache-sync.md`](docs/research/2026-05-14-muw-windburn-cognitive-cache-sync.md) (build-state snapshot)
- **Procedural cache lessons** — [`docs/superpowers/plans/2026-05-12-goalv3-cc-PLAN-CLOSEOUT.md`](docs/superpowers/plans/2026-05-12-goalv3-cc-PLAN-CLOSEOUT.md) (8 captured lessons including anti-LGTM PR-scope failure modes)
- **Distribution package** — [`hermes-distributions/fearvox-windburn/README.md`](hermes-distributions/fearvox-windburn/README.md)
- **Agent grounding** — [`CLAUDE.md`](CLAUDE.md) (workbench discipline, do-not-touch lanes, 5-field closeout block)
