# MCP Disabled By Design

Phase 1 keeps the runtime narrow. Disabled tools are not failures unless a run
requires them and no repair card exists.

| MCP | Phase 1 Status | Reason | Repair Action |
| --- | --- | --- | --- |
| `cloudflare-api` | Disabled | Cloud-provider writes require explicit operator approval. | Add an operator-approved issue and scoped token plan. |
| `figma` | Disabled | No design-surface work is required for local workflow proof. | Enable only for UI/design implementation slices. |
| `notion` | Disabled | Avoid private workspace dependency in the runtime proof path. | Add only if Notion becomes source of truth for a run. |
| Private browser/email/social MCPs | Excluded from remote | Credentials and personal state should not be copied to a workhorse host. | Use explicit connector scopes and operator approval. |
| Raw shell / broad filesystem roots | Excluded from remote | Too much blast radius for autonomous remote execution. | Use scoped runtime-control and filesystem roots. |

