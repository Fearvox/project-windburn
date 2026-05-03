# Self-Awareness Bootstrap

Use this before starting any Remote Workhorse run.

## Read First

- Approved design: `docs/remote-workhorse/0xvox-unknown-design-20260502-222759.md`
- Tool inventory: `docs/remote-workhorse/phase1/TOOL_INVENTORY.json`
- Research Vault proof: `docs/remote-workhorse/phase1/RESEARCH_VAULT_PROOF.json`
- code-review-graph proof: `docs/remote-workhorse/phase1/CODE_REVIEW_GRAPH_PROOF.json`
- Tool registry: `config/tool-registry.toml`

## Required Loop

1. Restate the operator intent in one sentence.
2. Read live repo state: `pwd`, `git status --short --branch`, target docs/issues.
3. Run or inspect current tool truth: `codex mcp list`, `runtimectl doctor`.
4. Use Research Vault when the task has research, memory, architecture, or review context.
5. Treat code-review-graph as bootstrap-gated until the target repo is registered and fresh.
6. Route every missing tool to a repair card with owner action.
7. End every run with `PASS`, `FLAG`, or `BLOCK`.

## Stop Rules

- Do not provision NixOS in Phase 1.
- Do not copy local desktop MCP config blindly to a remote host.
- Do not expose raw shell, broad filesystem roots, private cookies, iMessage, email, or payment/cloud writes without explicit approval.
- Do not claim graph-backed review, RV-backed research, or remote readiness without evidence files.

