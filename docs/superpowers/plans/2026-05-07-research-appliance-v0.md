# Research Appliance v0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a minimal Windburn Research Workhorse Appliance that can validate research run cards, expose remote NixOS readiness evidence, and prepare the Agent Memory Causality program for reproducible experiments.

**Architecture:** Keep v0 as a small appliance, not a full MUW clone. The local repo owns the run-card schema and verifier; the NixOS module owns remote directories, a redacted status command, and a dry-run staging command. Experiments remain explicit run-card driven and public-safe by default.

**Tech Stack:** Bash, Node.js for local schema validation, NixOS shell applications, jq, systemd timers, existing Windburn evidence conventions.

---

### Task 1: Research Run Card Contract

**Files:**
- Create: `docs/remote-workhorse/fixtures/research-run-card-v0.json`
- Create: `scripts/research-run-card-verify.sh`
- Modify: `scripts/check.sh`
- Modify: `justfile`

- [x] **Step 1: Add a public-safe research run card fixture**

Create `docs/remote-workhorse/fixtures/research-run-card-v0.json` with an Agent Memory Causality canary card. It must include memory condition, pressure condition, evidence requirements, safety guardrails, and a Hugging Face export lane that is disabled until explicit review.

- [x] **Step 2: Add the verifier**

Create `scripts/research-run-card-verify.sh`. It must accept a path or stdin, validate the JSON shape, reject secret-like strings and raw public endpoint patterns, and print `PASS research_run_card_verify` on success.

- [x] **Step 3: Wire local checks**

Add the verifier to `scripts/check.sh` and add `just research-run-card-verify`.

- [x] **Step 4: Verify**

Run:

```sh
bash -n scripts/research-run-card-verify.sh
scripts/research-run-card-verify.sh docs/remote-workhorse/fixtures/research-run-card-v0.json
scripts/check.sh
```

Expected: all PASS.

### Task 2: Remote Research Appliance Module

**Files:**
- Create: `nixos/hosts/windburn-workhorse-nyc1/modules/remote-workhorse-research.nix`
- Modify: `nixos/hosts/windburn-workhorse-nyc1/windburn-workhorse.nix`
- Modify: `nixos/hosts/windburn-workhorse-nyc1/modules/remote-workhorse-runner.nix`
- Modify: `scripts/nixos-remote-rebuild.sh`

- [x] **Step 1: Add module**

Create a NixOS module that installs:

- `windburn-research-appliance-status`
- `windburn-research-runner`

It must create `/srv/windburn/research/{specs,runs,evidence,outbox}` and `/srv/windburn/evidence/research-appliance`, write redacted status JSON, and never read provider secrets.

- [x] **Step 2: Import module**

Import `remote-workhorse-research.nix` from `windburn-workhorse.nix`.

- [x] **Step 3: Add runner aggregate visibility**

Extend `windburn-runner-status` to include research appliance status and capability labels once deployed.

- [x] **Step 4: Extend remote rebuild smoke**

Add post-rebuild probes for the new commands and redacted evidence.

### Task 3: Research Appliance Docs

**Files:**
- Create: `docs/remote-workhorse/RESEARCH_APPLIANCE_V0.md`
- Modify: `docs/remote-workhorse/README.md`

- [x] **Step 1: Define v0 boundaries**

Document allowed actions, forbidden actions, evidence requirements, and PASS/FLAG/BLOCK behavior.

- [x] **Step 2: Include Hugging Face lane**

Document Hugging Face as export/publication infrastructure only in v0: no automatic dataset upload until a redacted artifact passes review.

- [x] **Step 3: Link from remote-workhorse README**

Add a short pointer to the new appliance spec.

### Task 4: Verification

**Files:**
- No new files.

- [x] **Step 1: Run format and test gates**

```sh
cargo fmt --check
cargo test
bash -n scripts/research-run-card-verify.sh
bash -n scripts/research-appliance-smoke.sh
scripts/research-appliance-smoke.sh
scripts/check.sh
git diff --check
```

- [x] **Step 2: Review status**

```sh
git status --short --branch
```

Expected: only intended files changed.
