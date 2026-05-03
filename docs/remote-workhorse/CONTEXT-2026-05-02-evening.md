# Context Summary: 2026-05-02 Evening Remote Workhorse Push

Window: 2026-05-02 18:00 America/New_York through the Windburn bootstrap run.

Sources used:

- Chronicle summaries from the evening work session.
- Codex thread `019deb6c-113c-7f51-aca4-b0fa0d9bc8bd`.
- Codex thread `019deb94-5d51-7801-9c6e-30bf863113d5`.
- Approved design in `0xvox-unknown-design-20260502-222759.md`.
- Live local probes run from `/Users/0xvox/Windburn`.

## Operator Intent

Windburn is not a generic migration folder. It is meant to become the stable
local control plane for the recent agent-work stack: Codex as the high-context
conductor, remote Hermes/provider lanes as high-throughput workers, and a
contract-first runtime that can keep working under pressure without forcing the
operator to pause for tool-path, MCP, repo, or evidence failures.

The desired system optimizes for:

- live truth before inherited assumptions;
- explicit tool selection and repair cards;
- bounded implementation slices;
- evidence artifacts with host, repo, command, exit, and verdict data;
- `PASS`, `FLAG`, or `BLOCK` closeouts instead of vague status prose;
- preserving working routes before redesigning them.

## Evening Facts Worth Carrying Forward

- Multica remained the heaviest active operations lane. The useful pattern was
  still issue JSON first, bounded comments/evidence, then concise terminal
  verdicts.
- Ultimate Workbench produced a Decision Runtime VM prototype path with stable
  local smoke commands. That work should inform bounded runtime design, but it
  should not be mixed into Remote Workhorse Phase 1.
- zonicdesign and DASH work reinforced the same rule: preview/runtime evidence
  beats branch-local optimism.
- The remote runtime research thread converged on a later NixOS/Rust cell:
  `disko`, `nixos-anywhere`, `sops-nix`, Tailscale/private ingress, `nh`, `nvd`,
  `nix-output-monitor`, Rust `crane`, `rust-overlay`, `sccache`, `nextest`,
  `cargo-deny`, `cargo-audit`, `cargo-machete`, `cargo-llvm-cov`, and `bacon`.
- Required future MCP shape: `runtime-control`, scoped filesystem, GitHub,
  code-review-graph, Context7, OpenAI developer docs, Research Vault, and
  public Playwright. Exa is useful for research. Figma and Notion are not Phase
  1 runtime dependencies.
- Research Vault is reachable, but the accepted Remote Workhorse design still
  needs a durable note. A zero-result search is evidence, not permission to skip
  the vault.
- code-review-graph is configured but currently has zero registered repos, so
  graph-backed review claims are gated until registration/freshness is proven.
- A Claude Code provider facade over OpenAI/Codex-style models remains a spike,
  not the mainline workflow. The stable route is still Codex conductor plus
  explicit worker/provider lanes.

## Approved Phase 1 Boundary

Phase 1 is Contract-First Canary:

- create `IDEA_RUN_CARD.template.json`;
- create `SELF_AWARENESS_BOOTSTRAP.template.md`;
- create `TOOL_INVENTORY.json`;
- create `RESEARCH_VAULT_PROOF.json`;
- create `CODE_REVIEW_GRAPH_PROOF.json`;
- create `MCP_DISABLED_BY_DESIGN.md`;
- create `RUN_DIGEST.template.md`;
- ship one read-only repo/review health canary.

Phase 1 explicitly does not provision NixOS, expose broad shell/filesystem
tools, copy private desktop MCP state to a remote host, or claim graph/RV/remote
readiness without evidence.

## Local Bootstrap Decisions

- Initialize `/Users/0xvox/Windburn` as the canonical git repo.
- Use `.worktrees/` for isolated implementation slices and keep it ignored.
- Use Rust for the first local control CLI: `crates/runtimectl`.
- Keep `scripts/check.sh` as the no-dependency fallback because `just` is not
  installed locally yet.
- Add `flake.nix` as the Phase 2 Nix/Rust workhorse scaffold, but do not require
  local Nix for Phase 1 verification.
- Use `building-github-index` to create a progressive-disclosure index for the
  frontier repos that will matter in Phase 2.

## Current Known Flags

- `nix` is not on the host PATH. `/Volumes/Nix Store` is mounted and contains
  Nix store/profile data, but `/nix` is absent, so direct Nix execution fails
  until activation/synthetic mount repair.
- `just` is not installed locally.
- `doctl` is not installed locally.

These are `FLAG` conditions for Phase 1, not blockers for the local scaffold.
They become blockers only if a later run claims full remote workhorse readiness
or graph-backed review without repairing them.

## Resolved After Bootstrap

- Research Vault durable note is now written and searchable as
  `Windburn Remote Workhorse Phase 1 contract-first canary`.
- code-review-graph now has `/Users/0xvox/Windburn` registered as `windburn`,
  built on `main`, and searchable through the MCP graph path.
- Colima default profile is running with Docker runtime. Live probe reports the
  VM OS as Ubuntu 24.04, so do not treat Colima itself as NixOS proof.
