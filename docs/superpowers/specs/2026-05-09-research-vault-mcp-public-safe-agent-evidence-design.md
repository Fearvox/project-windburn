# Research Vault MCP Public-Safe Agent Evidence Design

Status: approved design
Date: 2026-05-09
Owner surface: `packages/research-vault-mcp`
Consumer surface: Windburn proof and Capy/MUW dogfood gates

## Goal

Upgrade Research Vault MCP from a useful knowledge connector into a public-safe,
agent-native evidence layer. The first implementation slice must make the
default autonomous-agent surface read-only, provenance-rich, freshness-aware,
and self-correcting when an agent calls the wrong tool.

This is a hardening slice, not a MUW rewrite. MUW remains downstream dogfood.
Windburn records the proof contract and local dogfood gate. The MCP package is
the implementation owner.

## Source-Of-Truth Surfaces

- Implementation workspace: CCR/Evensong `packages/research-vault-mcp`.
- Public template and product narrative: `Fearvox/dash-research-vault`.
- Distribution surface: npm package `@syndash/research-vault-mcp`.
- Windburn: consumer proof, public-surface safety contract, and dogfood gate.
- MUW: later downstream dogfood only.

The implementation must distinguish local build behavior from published package
behavior. If local behavior is ahead of npm, status responses must report an
`unpublished_local_build` freshness flag instead of implying the feature is
already released.

## Architecture

Add four small modules to the MCP package.

### `profile`

Parse `MCP_PROFILE` with allowed values:

- `readonly`
- `full`
- `admin`

Default is `readonly`. Unknown profile values fail closed to `readonly` and
emit an `agent_guidance` warning.

### `tool_policy`

Classify tools as:

- read tools: `vault_status`, `vault_taxonomy`, `vault_search`, `vault_get`,
  and read-only queue status.
- mutating tools: raw ingest, note save, delete, and future write tools.
- external tools: Amplify and any provider-backed remote integration.

In `readonly`:

- `tools/list` exposes read tools only.
- direct `tools/call` to mutating or external tools returns
  `BLOCK read_only_profile`.
- no mutating code path executes.
- `/configure` is disabled.

### `guidance`

All tool responses include an `agent_guidance` object. This is product behavior,
not decorative error text. It tells the calling agent what the result can prove,
what it cannot prove, and the recommended next tool call.

Blocked tools must explain:

- why the call is wrong;
- what public-surface risk is being avoided;
- the safe alternative;
- which profile or operator lane would be required.

### `evidence_metadata`

Centralize provenance, freshness, and public-safety metadata:

- redacted `source_ref` values instead of local absolute paths;
- search match explanations;
- snippets or excerpt anchors;
- modified timestamps and freshness verdicts;
- npm release age metadata;
- public-safety scan results.

## Response Envelope

All tool calls return a structured envelope:

```json
{
  "ok": true,
  "profile": "readonly",
  "tool": "vault_search",
  "as_of": "2026-05-09T00:00:00.000Z",
  "data": {},
  "evidence": {
    "source": "research-vault",
    "public_safe": true,
    "redacted": true,
    "freshness_verdict": "PASS"
  },
  "agent_guidance": {
    "summary": "Use these hits as candidates, not final proof.",
    "next_step": "Call vault_get with the selected id for anchored excerpts.",
    "citation_rule": "Cite source_ref, title, and snippet anchor, not local paths.",
    "misuse_warning": "Do not claim support from search result alone."
  }
}
```

Errors use the same shape with `ok=false` and a `verdict`.

## Read Tools

### `vault_search`

Search results must include:

- `id`
- `title`
- `category`
- `matched_fields`
- `why_matched`
- `snippet`
- `source_ref`
- `modified`
- `freshness`
- optional `canonical_group` or `duplicate_hint` when cheap to derive

Search guidance must say that search hits are candidates. Agents must fetch
anchored excerpts before claiming support.

### `vault_get`

In `readonly`, `vault_get` returns bounded excerpts by default. Full note
content is opt-in through `include_content=true`, subject to:

- `max_chars` upper bound;
- public-safety scan;
- redacted path refs;
- no raw local path in the response.

Default output should be enough for citation and review proof without dumping a
private note.

### `vault_status`

Status output must include:

- corpus totals;
- analyzed and pending counts;
- `as_of`;
- `active_profile`;
- `last_analyzed_at`;
- `oldest_pending_age`;
- `analyzed_coverage`;
- `freshness_verdict`;
- `freshness_reasons`;
- package version;
- npm latest version;
- npm modified timestamp;
- release age in days;
- release freshness verdict.

Freshness rules:

- missing required registry, taxonomy, decay, or checksum source is `BLOCK`;
- key source mtime older than seven days is `FLAG`;
- pending count alone is not a `FLAG`;
- pending age and coverage explain backlog health without panic-shaped output.

### Queue Status

Queue status remains read-only. It may report pending counts, oldest pending
age, and generic next actions. It must not emit local path-shaped hints,
private filenames, or shell-specific commands unless a later private diagnostic
profile explicitly enables them.

## Guardrails

In `readonly`, mutators are blocked at both listing and call time.

Example blocked response:

```json
{
  "ok": false,
  "profile": "readonly",
  "tool": "vault_delete",
  "verdict": "BLOCK",
  "reason": "read_only_profile",
  "agent_guidance": {
    "why_wrong": "This MCP profile is public-safe and read-only; mutation tools are disabled.",
    "public_surface_reason": "Deleting or writing vault data from a shared agent surface can destroy evidence or leak private state.",
    "safe_alternative": "Use vault_search and vault_get to gather evidence, then ask the operator for an admin lane.",
    "requires_profile": "admin"
  }
}
```

Full admin mutation hardening is out of scope for this slice. Future work may
rename destructive tools, add dry-run previews, require confirmation tokens,
and split `vault_admin_delete` from normal read tools.

## Public-Surface Safety

Shared responses must not include:

- raw local absolute paths;
- public host or IP values;
- credential-looking values;
- SSH or tmux targets;
- operator-only shell commands;
- raw provider payloads.

Responses use redacted refs such as `rv:knowledge/<category>/<id>` or
`rv:queue/<job-id>`.

## Release Lane

Create a separate operator-owned release workspace in a later implementation
step:

```text
~/release-lanes/research-vault-mcp/
```

The local implementation expands `~` to the operator home directory. Public
docs and shared responses should keep the home path redacted.

Purpose:

- run npm pack and publish dry-runs;
- verify GitHub remote sync;
- align implementation checkout, public template, and npm distribution;
- record release evidence.

Expected evidence files:

```text
~/release-lanes/research-vault-mcp/
  README.md
  check-release.sh
  evidence/
    latest.json
    npm-pack-dry-run.json
    git-sync.json
```

This release lane must not store tokens, private vault content, raw `.npmrc`, or
credential paths. It uses operator ambient auth only.

## Windburn Dogfood Gate

After the MCP package slice passes its own tests, Windburn may add a small
consumer proof gate that asserts:

- active profile is `readonly`;
- mutators are hidden from `tools/list`;
- direct mutator calls return `BLOCK read_only_profile`;
- `vault_search` returns provenance fields and `agent_guidance`;
- `vault_get` defaults to bounded excerpts;
- `vault_status` includes freshness and release metadata;
- public responses do not leak raw local paths, hosts, tokens, or shell hints.

The dogfood gate should not rewrite MUW and should not require a remote NixOS
mutation.

## Testing

Package-level tests:

- `tools/list` in `readonly` exposes only read tools.
- direct `tools/call vault_delete` in `readonly` returns structured block and
  causes no file change.
- `vault_search` returns envelope, provenance fields, snippets, and guidance.
- `vault_get` defaults to excerpt mode and bounds `include_content=true`.
- `vault_status` returns profile, freshness, and release metadata.
- public-safety regression rejects raw local paths, host/IP strings,
  token-like strings, and shell hints.
- `/configure` is disabled in `readonly`.
- existing Streamable HTTP smoke still passes.

Windburn-level tests:

- read live MCP status;
- perform one search/get proof loop against a non-sensitive canary note;
- verify output shape and public-surface safety;
- report `PASS`, `FLAG`, or `BLOCK` without changing MUW.

## Acceptance Criteria

The slice is complete when:

- default MCP startup is public-safe `readonly`;
- autonomous agents cannot see or execute mutators by default;
- blocked calls teach the agent why the call is wrong and what to do next;
- search/get/status responses are evidence-grade and citation-friendly;
- freshness and npm release drift are visible;
- Windburn can prove the behavior without mutating remote infrastructure;
- MUW remains downstream dogfood.

## Future Work

- admin mutation UX with dry-run, confirmation token, preview-before-mutate, and
  clearly named dangerous tools;
- richer semantic retrieval and canonical duplicate grouping;
- private diagnostic profile for operator-only paths and shell hints;
- Capy/MUW dogfood smoke after package release.
