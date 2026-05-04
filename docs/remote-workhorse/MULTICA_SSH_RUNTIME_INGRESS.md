# MULTICA_SSH_RUNTIME_INGRESS

Generated: `2026-05-04`

## Intent

Define the first private, read-only runtime ingress for Multica to call
Windburn/Captain without exposing Superconductor publicly and without creating a
mutation bridge.

```text
Multica
  -> SSH forced command / tmux wrapper
  -> windburn-captain-runtime.sh
  -> runtime card validation
  -> read-only status/evidence
  -> Superruntime/Fusion Bridge status surfaces
```

This lane is:

- private runtime ingress;
- forced-command-friendly;
- read-only in v0;
- stream-safe by default.

This lane is not:

- a public webhook receiver;
- a public Superconductor exposure path;
- a mutation bridge;
- a generic shell escape.

## V0 Runtime Card Contract

The ingress consumes one bounded runtime card. The card is the minimal
assignment contract for a private SSH/tmux entry lane before signed envelopes
exist.

Required fields in v0:

| Field | Purpose |
| --- | --- |
| `schema_version` | Contract version. v0 requires `1`. |
| `card_id` | Stable runtime-card id, prefixed with `mrc_`. |
| `source` | Caller id. v0 requires `multica`. |
| `runtime_id` | Registered runtime label, prefixed with `rt_`. |
| `repo` | Allowed repo. v0 is pinned to `Fearvox/project-windburn`. |
| `branch` | Intended branch label. |
| `intent` | Human-readable, bounded read-only reason. |
| `requested_action` | Default action to execute if wrapper override is absent. |
| `allowed_actions` | Explicit allowlist for wrapper action selection. |
| `privacy_scope` | `private` or `team`. |
| `permissions` | Forced-command security posture for shell, mutation, secrets, writeback, and network. |
| `evidence_requirements` | Minimal proof outputs the runtime must return. |
| `operator_call_conditions` | Conditions that stop automation and require a human operator. |
| `expected_output` | Compact report contract. |
| `stream_policy` | v0 requires `redacted`. |
| `expires_at` | Lease-like expiry timestamp. |
| `signature_stub` | Non-cryptographic placeholder until signed cards land. |

Provider/auth boundary for the card:

- Runtime card must not contain provider API keys, OAuth tokens, credential
  paths, or provider account details.
- v0 ingress is status/card verification only. It does not invoke
  Codex/provider calls.
- Future harness dispatch should use operator-owned auth profiles outside the
  repo: prefer OAuth/session login where available; otherwise use an
  operator-provided provider profile such as OpenRouter/xAI injected by
  environment on the runtime host.

Minimal shape:

```json
{
  "schema_version": 1,
  "card_id": "mrc_...",
  "source": "multica",
  "runtime_id": "rt_...",
  "repo": "Fearvox/project-windburn",
  "branch": "main",
  "intent": "Inspect runtime status through a private read-only ingress.",
  "requested_action": "status",
  "allowed_actions": ["status", "verify-card", "superruntime-status"],
  "privacy_scope": "team",
  "permissions": {
    "shell": "forced-command",
    "remote_mutation": false,
    "secret_access": false,
    "provider_writeback": false,
    "network": "local-only"
  },
  "evidence_requirements": [
    "repo-anchor",
    "git-status",
    "runtime-card-verdict",
    "superruntime-status",
    "redacted-summary"
  ],
  "operator_call_conditions": [
    "remote-mutation",
    "secret-access",
    "provider-writeback",
    "unknown-action",
    "stream-safety-failure"
  ],
  "expected_output": "PASS/FLAG/BLOCK plus redacted evidence.",
  "stream_policy": "redacted",
  "expires_at": "timestamp",
  "signature_stub": "stub:v0-ssh-runtime-card-not-cryptographic"
}
```

## Allowed Actions

Only these v0 actions are allowed:

| Action | Behavior |
| --- | --- |
| `status` | Return compact runtime status and verifier-derived verdict. |
| `verify-card` | Validate the runtime card and print a redacted wrapper summary. |
| `superruntime-status` | Return a compact summary from the local Superruntime fixture. |

## Forbidden Actions

The wrapper must reject these classes in v0:

- arbitrary shell;
- direct SSH target display;
- NixOS rebuild `apply` or `switch`;
- secret sync `apply`;
- provider writeback;
- public inbound Superconductor route.
- provider auth payloads embedded in the runtime card.

## Forced-Command Guidance

Use placeholders only. Do not copy raw hostnames, IPs, credential paths, or
operator-local absolute paths into shared docs or browser surfaces.

Example shape:

```text
Match User <runtime-user>
  ForceCommand "<windburn-captain-runtime> --card <runtime-card-json>"
  PermitTTY yes
  AllowTcpForwarding no
  X11Forwarding no
```

Possible wrapper chain shapes:

```text
SSH forced command -> windburn-captain-runtime.sh --card <runtime-card-json>
SSH forced command -> tmux wrapper -> windburn-captain-runtime.sh --card <runtime-card-json>
```

The runtime card is input data, not a command source. The wrapper never executes
payload-provided shell fragments.

## Failure Model

| Failure | Required Result |
| --- | --- |
| invalid card | `BLOCK` |
| expired card | `BLOCK` |
| stream-safety violation | `BLOCK` |
| unknown action | `BLOCK` |
| action outside `allowed_actions` | `BLOCK` |
| provider credential, OAuth token, credential path, or provider account detail present in card | `BLOCK` |
| provider returns `429` / `rate_limit` in a future harness lane | `FLAG provider_rate_limited`, not repo failure |
| dirty repo during status | at most `FLAG` |
| dirty repo for a future clean-tree action | escalate per action policy |

## Status Surface Rules

- Output stays compact and text-first.
- Public/runtime-shared status omits raw hostnames, IPs, SSH targets, and local
  absolute paths.
- Secret capability remains explicit `false` in v0.
- Remote mutation remains explicit `false` in v0.
- Provider writeback remains explicit `false` in v0.
- Provider ids, provider account labels, raw provider tokens, and auth profile
  internals do not print in status output.

The v0 wrapper is a private runtime channel sketch for Multica to inspect
Windburn state safely before any signed mutation lane exists.

## Follow-Up Notes

Later layers can add:

1. signed runtime cards and detached verification;
2. tmux transcript tails with stream-safety filtering;
3. replacement of the local fixture with a real Superruntime registry source;
4. bounded Multica status writeback after policy and audit contracts exist;
5. concurrency/backoff or explicit manual gate for future provider/CI-triggered
   harness calls.
