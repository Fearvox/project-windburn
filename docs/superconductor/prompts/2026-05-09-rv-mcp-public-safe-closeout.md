# sc Prompt: Research Vault MCP Public-Safe Closeout

Use this prompt for a Superconductor (`sc`) agent session that continues the
Research Vault MCP hardening lane.

````text
Apply docs/codex-desktop-communication-profile.md.
Tone: direct, human, concise, bilingual when useful, pushback-ok.

Task:
Close out and activate the Research Vault MCP public-safe evidence layer for
Windburn/MUW dogfood. Start read-only. Preserve public-surface safety. Do not
rewrite MUW; treat MUW as downstream dogfood only.

Repo anchors:
- Windburn canonical checkout: /Users/0xvox/Windburn
- Research Vault MCP package checkout: /Users/0xvox/claude-code-reimagine-for-learning
- Local release lane: /Users/0xvox/release-lanes/research-vault-mcp

Current local merge state:
- Windburn main has the dogfood gate/proof merged through commit 6e0be6d.
- Research Vault MCP package branch was merged into the local package checkout
  through commit 0eaacbc7.
- The package checkout may have unrelated pre-existing dirty work; do not
  revert or clean it unless the operator explicitly asks.
- Windburn may have unrelated untracked screenshot artifacts; do not touch them
  unless they become part of this task.

What landed:
- Research Vault MCP defaults to MCP_PROFILE=readonly.
- Readonly public surface is limited to vault_status, vault_taxonomy,
  vault_search, vault_get, and read-only queue/status behavior.
- Mutators are hidden or blocked unless profile is explicitly widened.
- vault_search returns provenance/freshness fields such as matched_fields,
  why_matched, snippet, source_ref, section_anchor, offsets, duplicate hints,
  as_of, last_analyzed_at, and freshness_status.
- vault_status and queue/status responses include coverage/freshness metadata
  while avoiding local path-shaped operator hints.
- Prompt-companion guidance tells agents why a call failed and what safe next
  step to take, especially for profile violations and mutation attempts.

Proof to read first:
- docs/remote-workhorse/phase1/RESEARCH_VAULT_MCP_PUBLIC_SAFE_PROOF.json
- scripts/research-vault-mcp-dogfood.sh
- /Users/0xvox/release-lanes/research-vault-mcp/evidence/release-status.json

Known remaining gates:
1. Default ambient MCP endpoint may still be the older mutation-visible server.
   The latest PASS proof used a temporary readonly endpoint. Before claiming
   default PASS, restart or rebind the default RV MCP service to the package
   head with MCP_PROFILE=readonly and rerun the dogfood gate against the default
   endpoint.
2. npm version currently matches local package version 1.1.2, but npm package
   metadata still points at the wrong repository. Keep release status FLAG until
   the public package metadata points at https://github.com/Fearvox/dash-research-vault
   or the operator chooses a different canonical public repo.
3. No push or npm publish has been performed in this lane. Treat publishing as
   a separate explicit operator-approved action.

Suggested verification:
```sh
cd /Users/0xvox/Windburn
scripts/superconductor-codex-intake.sh
scripts/research-vault-mcp-dogfood.sh
scripts/check.sh
git diff --check
git status --short --branch

cd /Users/0xvox/claude-code-reimagine-for-learning
bun test:research-vault
bun build:research-vault
git status --short --branch

cd /Users/0xvox/release-lanes/research-vault-mcp
./check-release.sh
cat evidence/release-status.json
```

Expected closeout format:
WINDBURN_SUPERCONDUCTOR_CLOSEOUT
changed:
verified:
remote_mutation:
residual_risk:
next_action:
verdict: PASS | FLAG | BLOCK

Decision rule:
- PASS only if the default RV MCP endpoint is proven readonly/public-safe and
  the required checks pass.
- FLAG if implementation is merged but default service binding, npm metadata,
  or release publication remains unresolved.
- BLOCK only for missing source files, failing tests, leaked secrets, or a
  mutation-capable public/default endpoint that cannot be disabled safely.
````
