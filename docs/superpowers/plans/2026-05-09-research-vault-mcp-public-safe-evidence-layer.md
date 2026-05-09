# Research Vault MCP Public-Safe Evidence Layer Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to execute this plan.

## Goal

Harden Research Vault MCP into a default read-only, public-safe evidence layer for Windburn and MUW dogfood without rewriting MUW.

The implementation must preserve the existing package entrypoint and external read tool names while adding:

- a default read-only profile;
- provenance-rich search and get responses;
- freshness and coverage metadata;
- prompt-companion guidance that tells agents what went wrong and what to do next;
- mutation guardrails that fail closed unless explicitly enabled;
- a local release lane for npm/GitHub synchronization evidence;
- a Windburn dogfood gate that verifies the public-safe agent surface.

## Source Context

Primary implementation root:

- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp`

Windburn planning and proof root:

- `~/Windburn`

Public surfaces to keep aligned:

- `https://github.com/Fearvox/dash-research-vault`
- `https://www.npmjs.com/package/@syndash/research-vault-mcp`

Supporting Windburn artifacts already created:

- `~/Windburn/docs/superpowers/specs/2026-05-09-research-vault-mcp-public-safe-agent-evidence-design.md`
- `~/Windburn/docs/external-indexes/dash-research-vault.md`
- `~/Windburn/docs/external-indexes/research-vault-mcp-package.md`

Live audit findings to preserve:

- active MCP server is served from the CCR/Evensong package, not Windburn;
- Windburn and MUW consume the surface as downstream dogfood;
- current package exposes read, write, delete, ingest, and Amplify tools together;
- `/configure` is only secret-gated when a secret exists;
- `vault_get` currently lives with write tools and returns full content/path data;
- queue/status responses contain operator-shaped command hints.

## Architecture

Add small policy and response modules around the existing tools instead of rewriting the server:

```text
packages/research-vault-mcp/src/
  profile.ts          # MCP_PROFILE / env-driven profile resolution
  tool_policy.ts      # tool visibility and call authorization
  guidance.ts         # agent_guidance envelope content
  public_safety.ts    # redact/scan public response payloads
  response.ts         # shared ok/error envelopes
  evidence_metadata.ts# freshness, provenance, release metadata helpers
  server.ts           # wire policy + envelope into MCP and HTTP configure path
  vault.ts            # read tools, vault_get, search/status metadata
  vault_write.ts      # mutators only
```

Profiles:

- `readonly` is the default for autonomous agents.
- `full` allows read tools plus bounded mutators.
- `admin` allows destructive operations after explicit confirmation tokens.

Read-only public toolset:

- `vault_status`
- `vault_taxonomy`
- `vault_search`
- `vault_get`
- `vault_batch_analyze`

`vault_batch_analyze` remains read-only queue visibility in the public profile. It must not return shell commands or local paths.

Mutation tools remain implemented but hidden and blocked in `readonly`:

- `vault_raw_ingest`
- `vault_note_save`
- `vault_delete`
- Amplify configuration/mutating tools
- HTTP `/configure`

## Response Envelope Contract

All tool responses should converge on this shape:

```ts
type AgentGuidance = {
  verdict: 'PASS' | 'FLAG' | 'BLOCK';
  reason: string;
  next_step: string;
  recommended_tool?: string;
  retryable?: boolean;
};

type EvidenceMetadata = {
  as_of: string;
  profile: 'readonly' | 'full' | 'admin';
  public_safe: boolean;
  freshness?: Record<string, unknown>;
  provenance?: Record<string, unknown>;
  release?: Record<string, unknown>;
};

type ToolEnvelope<T> = {
  ok: boolean;
  data: T | null;
  agent_guidance: AgentGuidance;
  evidence: EvidenceMetadata;
};
```

Design rule: if a response detects a public-surface leak candidate, redact the leaked value before returning data, set `ok: false`, set `agent_guidance.verdict: 'BLOCK'`, and give a next step that tells the agent to switch to private diagnostics or sanitize the source.

## Implementation Tasks

### Task 1: Add Profile, Guidance, Response, and Public-Safety Foundations

Files:

- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/src/profile.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/src/guidance.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/src/public_safety.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/src/response.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/__tests__/profile_response.test.ts`

Steps:

1. Add `profile.ts`.

```ts
export type McpProfile = 'readonly' | 'full' | 'admin';

export function getActiveProfile(env = process.env): McpProfile {
  const raw = String(env.MCP_PROFILE || env.RESEARCH_VAULT_MCP_PROFILE || 'readonly').toLowerCase();
  if (raw === 'full' || raw === 'admin' || raw === 'readonly') return raw;
  return 'readonly';
}

export function profileAllowsMutation(profile: McpProfile): boolean {
  return profile === 'full' || profile === 'admin';
}

export function profileAllowsAdmin(profile: McpProfile): boolean {
  return profile === 'admin';
}
```

2. Add `guidance.ts`.

```ts
import type { McpProfile } from './profile.js';

export type GuidanceVerdict = 'PASS' | 'FLAG' | 'BLOCK';

export type AgentGuidance = {
  verdict: GuidanceVerdict;
  reason: string;
  next_step: string;
  recommended_tool?: string;
  retryable?: boolean;
};

export function passGuidance(reason: string, next_step: string, recommended_tool?: string): AgentGuidance {
  return { verdict: 'PASS', reason, next_step, recommended_tool, retryable: false };
}

export function flagGuidance(reason: string, next_step: string, recommended_tool?: string): AgentGuidance {
  return { verdict: 'FLAG', reason, next_step, recommended_tool, retryable: true };
}

export function blockGuidance(reason: string, next_step: string, recommended_tool?: string): AgentGuidance {
  return { verdict: 'BLOCK', reason, next_step, recommended_tool, retryable: false };
}

export function readonlyBlockedGuidance(toolName: string, profile: McpProfile): AgentGuidance {
  return blockGuidance(
    `Tool ${toolName} is not available in ${profile} profile.`,
    'Use vault_search or vault_get for evidence retrieval, or restart the MCP server with an explicit non-readonly profile for operator-approved mutation.',
    'vault_search',
  );
}
```

3. Add `public_safety.ts`.

```ts
const HOME_PATH_RE = /\/Users\/[^/\s]+(?:\/[^\s"'<>]*)?/g;
const SSH_RE = /\b(?:ssh|scp|rsync)\s+[^"'<>]+/gi;
const TOKEN_RE = /\b(?:sk-[A-Za-z0-9_-]{12,}|ghp_[A-Za-z0-9_]{12,}|xox[baprs]-[A-Za-z0-9-]{12,})\b/g;
const IPV4_RE = /\b(?:\d{1,3}\.){3}\d{1,3}\b/g;

export type PublicSafetyScan = {
  public_safe: boolean;
  redacted: boolean;
  reasons: string[];
};

export function redactUnsafeText(input: string): string {
  return input
    .replace(TOKEN_RE, '[redacted-token]')
    .replace(SSH_RE, '[redacted-operator-command]')
    .replace(HOME_PATH_RE, '[redacted-local-path]')
    .replace(IPV4_RE, '[redacted-ip]');
}

export function sanitizePublicData<T>(value: T): T {
  if (typeof value === 'string') return redactUnsafeText(value) as T;
  if (Array.isArray(value)) return value.map((item) => sanitizePublicData(item)) as T;
  if (!value || typeof value !== 'object') return value;

  const out: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
    out[key] = sanitizePublicData(item);
  }
  return out as T;
}

export function scanPublicSafety(value: unknown): PublicSafetyScan {
  const raw = typeof value === 'string' ? value : JSON.stringify(value ?? null);
  const reasons = [
    HOME_PATH_RE.test(raw) ? 'local_path' : '',
    SSH_RE.test(raw) ? 'operator_command' : '',
    TOKEN_RE.test(raw) ? 'token_shape' : '',
    IPV4_RE.test(raw) ? 'ip_address' : '',
  ].filter(Boolean);

  return {
    public_safe: reasons.length === 0,
    redacted: reasons.length > 0,
    reasons,
  };
}
```

4. Add `response.ts`.

```ts
import { getActiveProfile, type McpProfile } from './profile.js';
import { blockGuidance, passGuidance, type AgentGuidance } from './guidance.js';
import { sanitizePublicData, scanPublicSafety } from './public_safety.js';

export type EvidenceMetadata = {
  as_of: string;
  profile: McpProfile;
  public_safe: boolean;
  safety_reasons?: string[];
  freshness?: Record<string, unknown>;
  provenance?: Record<string, unknown>;
  release?: Record<string, unknown>;
};

export type ToolEnvelope<T> = {
  ok: boolean;
  data: T | null;
  agent_guidance: AgentGuidance;
  evidence: EvidenceMetadata;
};

export function okEnvelope<T>(
  data: T,
  guidance: AgentGuidance = passGuidance('Tool completed.', 'Use returned evidence before making a claim.'),
  evidence: Partial<EvidenceMetadata> = {},
): ToolEnvelope<T> {
  const rawScan = scanPublicSafety(data);
  const safeData = sanitizePublicData(data);
  const profile = evidence.profile || getActiveProfile();
  const publicSafe = rawScan.public_safe && evidence.public_safe !== false;

  return {
    ok: publicSafe,
    data: safeData,
    agent_guidance: publicSafe
      ? guidance
      : blockGuidance('Response contained public-surface leak candidates and was redacted.', 'Use a private diagnostic profile or remove local path, host, token, and operator command material from the source.'),
    evidence: {
      as_of: evidence.as_of || new Date().toISOString(),
      profile,
      public_safe: publicSafe,
      safety_reasons: rawScan.reasons.length ? rawScan.reasons : evidence.safety_reasons,
      freshness: evidence.freshness,
      provenance: evidence.provenance,
      release: evidence.release,
    },
  };
}

export function errorEnvelope(reason: string, next_step: string, evidence: Partial<EvidenceMetadata> = {}): ToolEnvelope<null> {
  return {
    ok: false,
    data: null,
    agent_guidance: blockGuidance(reason, next_step),
    evidence: {
      as_of: evidence.as_of || new Date().toISOString(),
      profile: evidence.profile || getActiveProfile(),
      public_safe: evidence.public_safe ?? true,
      safety_reasons: evidence.safety_reasons,
      freshness: evidence.freshness,
      provenance: evidence.provenance,
      release: evidence.release,
    },
  };
}
```

5. Add tests.

```ts
import { describe, expect, test } from 'bun:test';
import { getActiveProfile } from '../src/profile';
import { okEnvelope } from '../src/response';

describe('profile and public response envelope', () => {
  test('defaults to readonly for unknown or missing profile', () => {
    expect(getActiveProfile({} as NodeJS.ProcessEnv)).toBe('readonly');
    expect(getActiveProfile({ MCP_PROFILE: 'surprise' } as NodeJS.ProcessEnv)).toBe('readonly');
  });

  test('accepts explicit full and admin profiles', () => {
    expect(getActiveProfile({ MCP_PROFILE: 'full' } as NodeJS.ProcessEnv)).toBe('full');
    expect(getActiveProfile({ RESEARCH_VAULT_MCP_PROFILE: 'admin' } as NodeJS.ProcessEnv)).toBe('admin');
  });

  test('redacts unsafe public values before returning data', () => {
    const body = okEnvelope({ path: '/Users/example/private/file.md', token: 'sk-1234567890abcdef' });
    expect(body.ok).toBe(false);
    expect(body.agent_guidance.verdict).toBe('BLOCK');
    expect(JSON.stringify(body.data)).not.toContain('/Users/example');
    expect(JSON.stringify(body.data)).not.toContain('sk-1234567890abcdef');
  });
});
```

6. Run package tests for the new modules.

```sh
cd ~/claude-code-reimagine-for-learning/packages/research-vault-mcp
bun test __tests__/profile_response.test.ts
```

Expected result: tests pass.

### Task 2: Enforce Readonly Tool Policy in the MCP Server

Files:

- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/src/tool_policy.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/src/server.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/__tests__/streamable_http.test.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/__tests__/server-auth.test.ts`

Steps:

1. Add `tool_policy.ts`.

```ts
import type { ToolDefinition } from './types.js';
import { getActiveProfile, profileAllowsMutation, type McpProfile } from './profile.js';
import { errorEnvelope } from './response.js';
import { readonlyBlockedGuidance } from './guidance.js';

export const READONLY_TOOL_NAMES = new Set([
  'vault_status',
  'vault_taxonomy',
  'vault_search',
  'vault_get',
  'vault_batch_analyze',
]);

export const MUTATION_TOOL_NAMES = new Set([
  'vault_raw_ingest',
  'vault_note_save',
  'vault_delete',
]);

export function visibleToolsForProfile(tools: ToolDefinition[], profile: McpProfile = getActiveProfile()): ToolDefinition[] {
  if (profile === 'readonly') return tools.filter((tool) => READONLY_TOOL_NAMES.has(tool.name));
  if (profile === 'full') return tools.filter((tool) => !tool.name.includes('delete') && !tool.name.includes('admin'));
  return tools;
}

export function isToolAllowed(name: string, profile: McpProfile = getActiveProfile()): boolean {
  if (profile === 'readonly') return READONLY_TOOL_NAMES.has(name);
  if (profile === 'full') return !name.includes('delete') && !name.includes('admin');
  return true;
}

export function blockedToolResponse(name: string, profile: McpProfile) {
  return {
    content: [
      {
        type: 'text' as const,
        text: JSON.stringify({
          ...errorEnvelope(`Tool ${name} is blocked by the active MCP profile.`, readonlyBlockedGuidance(name, profile).next_step, {
            profile,
            public_safe: true,
          }),
          agent_guidance: readonlyBlockedGuidance(name, profile),
        }),
      },
    ],
    isError: true,
  };
}

export function configureAllowed(profile: McpProfile = getActiveProfile()): boolean {
  return profileAllowsMutation(profile);
}
```

2. Wire the policy into `server.ts`.

Implementation details:

- Keep the current HTTP and stdio transports.
- Change tool listing to call `visibleToolsForProfile(allTools, profile)`.
- Before executing any tool in `tools/call`, call `isToolAllowed(name, profile)`.
- Return `blockedToolResponse` instead of throwing for policy denial. Agents need a readable next step.
- Add `profile`, `public_safe_default`, and `visible_tools` to `/health`.
- Block `/configure` when the active profile is `readonly`, even if no configure secret is set.

Representative patch shape:

```ts
import { getActiveProfile } from './profile.js';
import { blockedToolResponse, configureAllowed, isToolAllowed, visibleToolsForProfile } from './tool_policy.js';

const profile = getActiveProfile();
const visibleTools = visibleToolsForProfile(allTools, profile);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: visibleTools.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const activeProfile = getActiveProfile();

  if (!isToolAllowed(name, activeProfile)) {
    return blockedToolResponse(name, activeProfile);
  }

  const tool = allTools.find((t) => t.name === name);
  if (!tool) throw new Error(`Unknown tool: ${name}`);
  return tool.handler(args || {});
});
```

3. Update `/health` response.

Required fields:

```json
{
  "status": "ok",
  "profile": "readonly",
  "public_safe_default": true,
  "tools": 5,
  "total_registered_tools": 13,
  "visible_tools": ["vault_status", "vault_taxonomy", "vault_search", "vault_get", "vault_batch_analyze"]
}
```

4. Update streamable HTTP tests.

Add a readonly default test:

```ts
test('HTTP MCP lists only read-only tools by default', async () => {
  const server = Bun.spawn(['bun', 'run', 'src/server.ts'], {
    cwd: packageRoot,
    env: {
      ...process.env,
      MCP_TRANSPORT: 'http',
      MCP_PORT: String(port),
      MCP_PROFILE: 'readonly',
      RESEARCH_VAULT_ROOT: tmpVault,
    },
  });

  const res = await rpc(port, 'tools/list', {});
  const toolNames = res.result.tools.map((tool: { name: string }) => tool.name);

  expect(toolNames).toContain('vault_status');
  expect(toolNames).toContain('vault_search');
  expect(toolNames).toContain('vault_get');
  expect(toolNames).not.toContain('vault_delete');
  expect(toolNames).not.toContain('vault_raw_ingest');
});
```

Add a blocked call test:

```ts
test('HTTP MCP blocks hidden mutators in readonly profile with guidance', async () => {
  const res = await rpc(port, 'tools/call', {
    name: 'vault_delete',
    arguments: { id: 'demo' },
  });

  const body = JSON.parse(res.result.content[0].text);
  expect(res.result.isError).toBe(true);
  expect(body.agent_guidance.verdict).toBe('BLOCK');
  expect(body.agent_guidance.next_step).toContain('vault_search');
});
```

5. Update configure tests.

Existing back-compat tests that assume open `/configure` must set `MCP_PROFILE=full`, or be replaced with readonly-denial expectations.

Add:

```ts
test('configure is blocked in readonly profile even without configure secret', async () => {
  const response = await fetch(`http://localhost:${port}/configure`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ databaseUrl: 'postgres://example.invalid/db' }),
  });

  expect(response.status).toBe(403);
  const body = await response.json();
  expect(body.agent_guidance.verdict).toBe('BLOCK');
});
```

6. Run targeted tests.

```sh
cd ~/claude-code-reimagine-for-learning/packages/research-vault-mcp
bun test __tests__/streamable_http.test.ts __tests__/server-auth.test.ts
```

Expected result: readonly tests pass, and existing full-profile configure coverage remains valid under explicit `MCP_PROFILE=full`.

### Task 3: Move `vault_get` Into the Read Surface With Bounded Excerpts

Files:

- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/src/types.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/src/vault.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/src/vault_write.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/__tests__/vault_get_readonly.test.ts`

Steps:

1. Extend `VaultGetInput`.

```ts
export interface VaultGetInput {
  id: string;
  include_content?: boolean;
  max_chars?: number;
}
```

2. Move `vault_get` out of `vaultWriteTools` and into `vaultTools`.

3. Export a shared read helper from `vault_write.ts` or a new `vault_store.ts`.

Required helper behavior:

- find by exact ID first;
- fall back to file stem only if unique;
- do not return raw local file paths;
- include `source_ref` as a stable, public-safe note reference;
- default to excerpt content only;
- full content requires `include_content: true`;
- cap full content at `max_chars`, with a hard ceiling of `12000`.

Representative handler in `vault.ts`:

```ts
const MAX_GET_CHARS = 12000;
const DEFAULT_EXCERPT_CHARS = 1200;

async function handleVaultGet(input: VaultGetInput) {
  if (!input.id) {
    return {
      content: [{ type: 'text' as const, text: JSON.stringify(errorEnvelope('Missing required id.', 'Call vault_search first, then pass the selected result id to vault_get.')) }],
      isError: true,
    };
  }

  const entry = await getEntry(input.id);
  if (!entry) {
    return {
      content: [{ type: 'text' as const, text: JSON.stringify(errorEnvelope(`No vault entry matched id ${input.id}.`, 'Call vault_search with the claim terms and pick a returned id.', { public_safe: true })) }],
      isError: true,
    };
  }

  const maxChars = Math.min(Math.max(input.max_chars || DEFAULT_EXCERPT_CHARS, 200), MAX_GET_CHARS);
  const includeContent = input.include_content === true;
  const content = includeContent ? entry.content.slice(0, maxChars) : entry.content.slice(0, DEFAULT_EXCERPT_CHARS);

  return {
    content: [{
      type: 'text' as const,
      text: JSON.stringify(okEnvelope({
        id: entry.id,
        title: entry.title,
        category: entry.category,
        source_ref: entry.id,
        excerpt: content,
        content_truncated: entry.content.length > content.length,
        content_char_count: entry.content.length,
        include_content: includeContent,
      }, passGuidance('Vault note returned with bounded evidence content.', 'Cite the source_ref and excerpt before making a claim.', 'vault_search'))),
    }],
  };
}
```

4. Test `vault_get` in readonly tool list and bounded response.

```ts
import { describe, expect, test } from 'bun:test';
import { vaultTools } from '../src/vault';

describe('vault_get readonly behavior', () => {
  test('vault_get is in read tool surface', () => {
    expect(vaultTools.map((tool) => tool.name)).toContain('vault_get');
  });

  test('vault_get input schema exposes bounded content controls', () => {
    const tool = vaultTools.find((item) => item.name === 'vault_get');
    expect(tool?.inputSchema.properties).toHaveProperty('id');
    expect(tool?.inputSchema.properties).toHaveProperty('include_content');
    expect(tool?.inputSchema.properties).toHaveProperty('max_chars');
  });
});
```

5. Run tests.

```sh
cd ~/claude-code-reimagine-for-learning/packages/research-vault-mcp
bun test __tests__/vault_get_readonly.test.ts
```

Expected result: `vault_get` is a read tool and no mutator module is required to list it.

### Task 4: Add Search Provenance, Freshness, and Release Metadata

Files:

- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/src/evidence_metadata.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/src/vault.ts`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/__tests__/vault_evidence_metadata.test.ts`

Steps:

1. Add helper functions in `evidence_metadata.ts`.

Required exports:

- `matchedFields(entry, query)`;
- `whyMatched(entry, query, fields)`;
- `snippetFromContent(content, query, maxChars)`;
- `itemFreshness(entry)`;
- `coverageMetadata(statusData)`;
- `queueFreshness(queueItems)`;
- `releaseMetadata(env, packageJson)`.

Representative snippets:

```ts
export function matchedFields(entry: Record<string, unknown>, query: string): string[] {
  const q = query.toLowerCase();
  return ['title', 'category', 'summary', 'content', 'tags'].filter((field) => {
    const value = entry[field];
    return Array.isArray(value)
      ? value.join(' ').toLowerCase().includes(q)
      : String(value || '').toLowerCase().includes(q);
  });
}

export function snippetFromContent(content: string, query: string, maxChars = 280): string {
  const cleaned = content.replace(/\s+/g, ' ').trim();
  const index = cleaned.toLowerCase().indexOf(query.toLowerCase());
  if (index < 0) return cleaned.slice(0, maxChars);
  const start = Math.max(index - Math.floor(maxChars / 3), 0);
  return cleaned.slice(start, start + maxChars);
}

export function staleVerdict(lastAnalyzedAt?: string): 'PASS' | 'FLAG' {
  if (!lastAnalyzedAt) return 'FLAG';
  const ageMs = Date.now() - Date.parse(lastAnalyzedAt);
  return ageMs > 7 * 24 * 60 * 60 * 1000 ? 'FLAG' : 'PASS';
}
```

2. Enrich `vault_search`.

Each result must include:

- `matched_fields`;
- `why_matched`;
- `snippet`;
- `source_ref`;
- `section_anchor` if available;
- `canonical_group` if duplicate grouping already exists;
- freshness metadata such as `last_analyzed_at`, `source_mtime`, `freshness_verdict`;
- no local absolute `path`.

3. Enrich `vault_status`.

Required top-level metadata:

- `as_of`;
- `last_analyzed_at`;
- `analyzed_coverage`;
- `oldest_pending_age`;
- `recent_throughput`;
- `release.package_name`;
- `release.local_version`;
- `release.npm_latest_version`;
- `release.npm_modified_at`;
- `release.days_since_npm_update`;
- `release.public_repo`;
- `agent_guidance`.

Release metadata can read from env first:

```ts
RESEARCH_VAULT_NPM_LATEST_VERSION
RESEARCH_VAULT_NPM_MODIFIED_AT
RESEARCH_VAULT_PUBLIC_REPO_URL
```

If env values are missing, return null fields and a `FLAG` guidance explaining that release freshness was not provided by the runtime environment.

4. Sanitize queue visibility.

Change `vault_batch_analyze` public response:

- keep pending count and preview IDs/titles;
- include oldest pending age if calculable;
- include next action such as `operator_run_batch_analysis`;
- remove `cd ... && bun run ...` command text;
- remove local vault root/path hints.

5. Add tests.

```ts
import { describe, expect, test } from 'bun:test';
import { matchedFields, snippetFromContent, staleVerdict } from '../src/evidence_metadata';

describe('evidence metadata helpers', () => {
  test('matchedFields identifies title and content hits', () => {
    const fields = matchedFields({ title: 'Windburn proof', content: 'Research Vault evidence layer' }, 'Vault');
    expect(fields).toContain('content');
  });

  test('snippetFromContent anchors near query', () => {
    const snippet = snippetFromContent('alpha beta gamma delta evidence zeta eta theta', 'evidence', 32);
    expect(snippet).toContain('evidence');
    expect(snippet.length).toBeLessThanOrEqual(32);
  });

  test('staleVerdict flags missing or old analysis dates', () => {
    expect(staleVerdict()).toBe('FLAG');
    expect(staleVerdict(new Date(Date.now() - 8 * 24 * 60 * 60 * 1000).toISOString())).toBe('FLAG');
    expect(staleVerdict(new Date().toISOString())).toBe('PASS');
  });
});
```

6. Run tests.

```sh
cd ~/claude-code-reimagine-for-learning/packages/research-vault-mcp
bun test __tests__/vault_evidence_metadata.test.ts
```

Expected result: helpers pass and public status/search responses carry metadata without raw local paths.

### Task 5: Add Local Release Lane Skeleton

Files outside Windburn and outside the package repo:

- `~/release-lanes/research-vault-mcp/README.md`
- `~/release-lanes/research-vault-mcp/check-release.sh`

Steps:

1. Create the directory.

```sh
mkdir -p ~/release-lanes/research-vault-mcp
```

2. Add `README.md` with this contract:

```md
# Research Vault MCP Release Lane

Purpose: keep the local package, npm package, and public GitHub surfaces synchronized without storing secrets or private corpus content.

Inputs:
- local package root: `~/claude-code-reimagine-for-learning/packages/research-vault-mcp`
- public template repo: `https://github.com/Fearvox/dash-research-vault`
- npm package: `@syndash/research-vault-mcp`

Rules:
- no tokens in this directory;
- use ambient npm and git auth only;
- store release evidence as redacted JSON;
- never copy vault notes, local absolute paths, host values, or credential paths into evidence.
```

3. Add `check-release.sh`.

```sh
#!/usr/bin/env bash
set -euo pipefail

PKG_ROOT="${PKG_ROOT:-$HOME/claude-code-reimagine-for-learning/packages/research-vault-mcp}"
OUT_DIR="${OUT_DIR:-$HOME/release-lanes/research-vault-mcp/evidence}"
mkdir -p "$OUT_DIR"

local_version="$(node -p "require('$PKG_ROOT/package.json').version")"
npm_json="$(npm view @syndash/research-vault-mcp version time repository homepage --json)"
remote_main="$(git ls-remote https://github.com/Fearvox/dash-research-vault.git refs/heads/main | awk '{print $1}')"

jq -n \
  --arg package "@syndash/research-vault-mcp" \
  --arg local_version "$local_version" \
  --argjson npm "$npm_json" \
  --arg public_repo "https://github.com/Fearvox/dash-research-vault" \
  --arg remote_main "$remote_main" \
  --arg as_of "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    as_of: $as_of,
    package: $package,
    local_version: $local_version,
    npm: $npm,
    public_repo: $public_repo,
    public_repo_main_sha: $remote_main
  }' > "$OUT_DIR/release-status.json"

cat "$OUT_DIR/release-status.json"
```

4. Make executable.

```sh
chmod +x ~/release-lanes/research-vault-mcp/check-release.sh
```

5. Verify.

```sh
~/release-lanes/research-vault-mcp/check-release.sh
```

Expected result: prints redacted release status JSON with npm/package/public repo metadata. No local path, host/IP, or credential value should appear in the JSON.

### Task 6: Add Windburn Dogfood Gate

Files:

- `~/Windburn/scripts/research-vault-mcp-dogfood.sh`
- generated proof: `~/Windburn/docs/remote-workhorse/phase1/RESEARCH_VAULT_MCP_PUBLIC_SAFE_PROOF.json`

Steps:

1. Add the dogfood script in Windburn.

```sh
#!/usr/bin/env bash
set -euo pipefail

MCP_URL="${MCP_URL:-http://localhost:8787/mcp}"
OUT="${OUT:-docs/remote-workhorse/phase1/RESEARCH_VAULT_MCP_PUBLIC_SAFE_PROOF.json}"
mkdir -p "$(dirname "$OUT")"

session_init="$(curl -sS "$MCP_URL" \
  -H 'content-type: application/json' \
  -H 'accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"windburn-rv-dogfood","version":"0.1.0"}}}')"

session_id="$(printf '%s' "$session_init" | awk -F'mcp-session-id: ' '/mcp-session-id:/ {print $2}' | tr -d '\r')"
if [ -z "$session_id" ]; then
  echo "BLOCK: MCP session id missing" >&2
  exit 2
fi

tools="$(curl -sS "$MCP_URL" \
  -H 'content-type: application/json' \
  -H 'accept: application/json, text/event-stream' \
  -H "mcp-session-id: $session_id" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')"

search="$(curl -sS "$MCP_URL" \
  -H 'content-type: application/json' \
  -H 'accept: application/json, text/event-stream' \
  -H "mcp-session-id: $session_id" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"vault_search","arguments":{"query":"Windburn Research Vault evidence","limit":3}}}')"

blocked="$(curl -sS "$MCP_URL" \
  -H 'content-type: application/json' \
  -H 'accept: application/json, text/event-stream' \
  -H "mcp-session-id: $session_id" \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"vault_delete","arguments":{"id":"dogfood"}}}')"

jq -n \
  --arg as_of "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson tools "$tools" \
  --argjson search "$search" \
  --argjson blocked "$blocked" \
  '{
    as_of: $as_of,
    verdict: (
      if (($tools.result.tools | map(.name) | index("vault_delete")) == null)
        and (($tools.result.tools | map(.name) | index("vault_search")) != null)
        and (($blocked.result.isError // false) == true)
      then "PASS" else "FLAG" end
    ),
    tools: $tools,
    search: $search,
    blocked_mutation: $blocked
  }' > "$OUT"

grep -E '/Users/|ssh |sk-|ghp_|xox[baprs]-|([0-9]{1,3}\.){3}[0-9]{1,3}' "$OUT" && {
  echo "BLOCK: public-surface leak candidate in proof output" >&2
  exit 3
}

cat "$OUT"
```

2. Make executable.

```sh
cd ~/Windburn
chmod +x scripts/research-vault-mcp-dogfood.sh
```

3. Verify against a running local RV MCP server.

```sh
cd ~/Windburn
MCP_URL=http://localhost:8787/mcp scripts/research-vault-mcp-dogfood.sh
```

Expected result:

- proof JSON verdict is `PASS`;
- `vault_delete` is not listed;
- blocked mutation returns `isError: true`;
- search result contains `agent_guidance` and provenance metadata;
- proof file has no raw local home path, host/IP, token, or operator command.

### Task 7: Final Verification and Package Readiness

Files:

- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/README.md`
- `~/claude-code-reimagine-for-learning/packages/research-vault-mcp/CHANGELOG.md`
- package implementation/test files from prior tasks
- Windburn dogfood script/proof from Task 6

Steps:

1. Document the profile contract in the package README.

Required README section:

```md
## MCP Profiles

`MCP_PROFILE=readonly` is the default public-safe autonomous-agent profile. It exposes only read/evidence tools:

- `vault_status`
- `vault_taxonomy`
- `vault_search`
- `vault_get`
- `vault_batch_analyze`

Mutating tools are hidden and blocked unless the operator starts the server with `MCP_PROFILE=full` or `MCP_PROFILE=admin`.
```

2. Add a CHANGELOG entry.

Required points:

- default read-only MCP profile;
- provenance/freshness response envelope;
- bounded `vault_get`;
- mutation blocking guidance;
- public-surface safety redaction.

3. Run package checks.

```sh
cd ~/claude-code-reimagine-for-learning
bun test:research-vault
bun build:research-vault
git -C ~/claude-code-reimagine-for-learning diff --check
```

4. Run release-lane check.

```sh
~/release-lanes/research-vault-mcp/check-release.sh
```

5. Run Windburn dogfood proof and checks.

```sh
cd ~/Windburn
MCP_URL=http://localhost:8787/mcp scripts/research-vault-mcp-dogfood.sh
scripts/check.sh
git diff --check
git status --short --branch
```

6. Review dirty state.

Rules:

- do not stage unrelated pre-existing files;
- do not stage private evidence with raw local path, host/IP, token, or credential material;
- commit package changes in the package repo;
- commit Windburn dogfood script/proof separately in Windburn;
- keep release-lane files uncommitted unless the operator explicitly wants a separate local repo there.

## Acceptance Criteria

Implementation is complete when all are true:

- `MCP_PROFILE` unset lists only read-only tools.
- Direct calls to hidden mutators return a structured `BLOCK` guidance response.
- `/configure` is blocked under readonly even without a configure secret.
- `vault_search` returns `matched_fields`, `why_matched`, `snippet`, `source_ref`, and freshness metadata.
- `vault_get` is available in readonly and returns bounded evidence content without raw local paths.
- `vault_status` includes `as_of`, coverage, queue freshness, and release metadata fields.
- Queue status no longer returns local path or shell-command remediation by default.
- Package tests and build pass.
- Windburn dogfood proof is generated and public-surface scan passes.
- MUW is not rewritten; it remains downstream dogfood.

## Failure Handling

If tests fail:

- keep the failing test output;
- fix the smallest code path responsible;
- rerun the same targeted test before moving to broader checks.

If the active MCP server is not the package being edited:

- return `FLAG`;
- report the listener command and expected package root in redacted form;
- do not claim runtime proof until the correct server is restarted.

If release metadata cannot be fetched from npm or GitHub:

- return `FLAG`;
- keep read tools functional;
- report missing release evidence through `agent_guidance.next_step`.

If public-surface scan catches raw local/private data:

- return `BLOCK`;
- redact the value in outputs;
- fix the source response before running Windburn dogfood again.

## Suggested Commit Boundaries

Package repo:

1. `feat: add RV MCP readonly profile and guidance envelopes`
2. `feat: enrich RV MCP evidence provenance and freshness`
3. `docs: document RV MCP public-safe profiles`

Windburn:

1. `test: add RV MCP public-safe dogfood gate`

Release lane:

- no commit by default.
