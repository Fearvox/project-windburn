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

## gstack / SSH Handshake

The v1 bootstrap handshake uses SSH stdin plus a forced command. Multica/gstack
submits the runtime card over stdin; the forced command supplies the bounded
wrapper action.

```text
Multica/gstack submits runtime card over SSH stdin
  -> forced command invokes windburn-captain-runtime.sh --card - --action run-card
  -> runtime verifies card
  -> runtime acquires lease slot
  -> runtime writes status JSON to spool
  -> runtime returns compact PASS/FLAG/BLOCK summary
  -> Multica polls/collects redacted status/evidence refs
```

Important distinction:

- `run-card` is the forced-command wrapper action, not the runtime-card
  `requested_action`.
- The runtime card still carries only the bounded requested action that the
  verifier allows.
- The wrapper reads the card from stdin via `--card -`, copies the verified card
  into the runtime spool, writes queue/status state, and returns only compact
  redacted refs.

## Runtime Queue Concurrency Model

The bootstrap queue is intentionally lease-based instead of tmux-first:

- `WINDBURN_RUNTIME_MAX_PARALLEL` sets the runtime slot count. Default: `10`.
- Slot leases are acquired with `flock` over numbered slot lockfiles.
- If no slot is available, the runtime returns
  `FLAG windburn_captain_runtime: runtime_queue_full`.
- `runtime_queue_full` is queue pressure, not repo failure. Upstream should
  retry, back off, or leave the card queued.
- The runtime writes status JSON for each queued/leased/running/final state so
  future Superruntime/Fusion Bridge surfaces can show live progress without
  scraping tmux or raw stdout.

Why this matters for 10-way autoresearch:

- bounded leases prevent untracked fan-out;
- the status spool creates one stream-safe source of truth;
- compact refs are safer to poll than live shell streams;
- raw tmux chaos does not provide queue fairness, retry semantics, or clean
  browser-safe status.

## Status JSON Contract

Each `run-card` attempt writes one redacted status JSON record in the runtime
spool. Current schema:

| Field | Type | Notes |
| --- | --- | --- |
| `schema_version` | number | Current value `1`. |
| `run_id` | string | Runtime-generated queue/run id. |
| `card_id` | string | Verified runtime-card id. |
| `runtime_id` | string | Verified runtime label. |
| `repo` | string | Allowed repo label. |
| `requested_action` | string | Card action actually being executed inside the wrapper. |
| `phase` | string | Current phase: `queued`, `leased`, `running`, `done`, `flag`, or `block`. |
| `level` | string | Redacted severity: `info`, `pass`, `flag`, or `block`. |
| `verdict` | string | Final or current wrapper verdict: `PASS`, `FLAG`, or `BLOCK`. |
| `slot` | string | `pending`, `none`, or lease label such as `slot-##`. |
| `git_status` | string/null | Populated when the bounded handler returns repo status. |
| `superruntime_fixture` | string/null | Populated when the bounded handler returns a fixture verdict. |
| `action` | string/null | Present for action-specific handlers such as `hermes-autoresearch`. |
| `topic_count` | number/null | Redacted topic count for Hermes autoresearch cards. |
| `max_parallel_effective` | number/null | Effective bounded parallelism after runtime cap. |
| `secret_values_recorded` | boolean | Must remain `false` for stream safety. |
| `provider_rate_limited` | boolean | Reserved for future provider-backed lanes; currently `false`. |
| `artifact_refs` | string[] | Redacted refs only, for example `local:status-json`. |
| `generated_at_utc` | string | RFC3339 UTC timestamp. |

Minimal shape:

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "card_id": "mrc_...",
  "runtime_id": "rt_...",
  "repo": "Fearvox/project-windburn",
  "requested_action": "status",
  "phase": "leased",
  "level": "info",
  "verdict": "PASS",
  "slot": "slot-01",
  "git_status": "clean",
  "superruntime_fixture": "PASS",
  "secret_values_recorded": false,
  "provider_rate_limited": false,
  "artifact_refs": [
    "local:status-json",
    "local:card-copy",
    "local:run-output",
    "local:superruntime-fixture"
  ],
  "generated_at_utc": "timestamp"
}
```

Stream-safety rules for status JSON:

- no raw hostnames, IPs, SSH targets, credential paths, local absolute paths, or
  provider account internals;
- no provider API keys, OAuth payloads, or copied session material;
- no raw topic text when the topic could carry private context; prefer counts or
  sanitized labels only;
- artifact refs stay abstract and redacted;
- status JSON is the future live-status input for Superruntime/Fusion Bridge, not
  a dump of private runtime logs.

## Runtime Card Contract

The v1 bootstrap queue still uses the same bounded runtime-card shape. The card
remains the minimal assignment contract for a private SSH/tmux entry lane before
signed envelopes exist.

Required fields in the current card contract:

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
| `action_payload` | Action-specific bounded payload. Required for `hermes-autoresearch`; absent for the status-only actions. |
| `expected_output` | Compact report contract. |
| `stream_policy` | v0 requires `redacted`. |
| `expires_at` | Lease-like expiry timestamp. |
| `signature_stub` | Non-cryptographic placeholder until signed cards land. |

Provider/auth boundary for the card:

- Runtime card must not contain provider API keys, OAuth tokens, credential
  paths, or provider account details.
- The card does not carry provider auth. Future provider execution must use
  runtime-host operator-owned OAuth/session/provider profiles outside the repo.
- The current bootstrap queue only runs bounded runtime actions. It does not
  embed provider credentials or browser-visible provider account details.
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

## Allowed Runtime-Card Actions

Only these runtime-card actions are currently allowed:

| Action | Behavior |
| --- | --- |
| `status` | Return compact runtime status and verifier-derived verdict. |
| `verify-card` | Validate the runtime card and print a redacted wrapper summary. |
| `superruntime-status` | Return a compact summary from the local Superruntime fixture. |
| `hermes-autoresearch` | v1 safe-default queue/spool handler. Validates bounded research topics, returns redacted status JSON, and stops at `FLAG hermes_autoresearch_not_configured` unless an operator-confirmed execution env is explicitly enabled. |

Wrapper action note:

- The forced command may invoke `--action run-card` as the transport wrapper.
- `run-card` is not an allowed runtime-card `requested_action`.
- The wrapper validates the card, acquires a lease, records spool state, and
  then dispatches only the bounded card action above.

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
  ForceCommand "<windburn-captain-runtime> --card - --action run-card"
  PermitTTY yes
  AllowTcpForwarding no
  X11Forwarding no
```

Possible wrapper chain shapes:

```text
Multica/gstack -> SSH stdin -> windburn-captain-runtime.sh --card - --action run-card
Multica/gstack -> SSH stdin -> tmux wrapper -> windburn-captain-runtime.sh --card - --action run-card
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
| queue full at lease acquisition | `FLAG runtime_queue_full`, not repo failure |
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

## Hermes Autoresearch Card v1 Safe-Default

The current branch now accepts a bounded `requested_action` of
`hermes-autoresearch` behind the same lease-based `run-card` wrapper. The v1
handler is safe-default:

- no raw shell from card payloads;
- no provider API call by default;
- no remote mutation;
- no raw host/IP/path/tmux/provider credential/provider account output;
- if no operator-confirmed Hermes execution env is enabled, return
  `FLAG hermes_autoresearch_not_configured` and write redacted status JSON.

Use route labels and bounded scope only:

```json
{
  "schema_version": 1,
  "card_id": "mrc_...",
  "source": "multica",
  "runtime_id": "rt_...",
  "repo": "Fearvox/project-windburn",
  "branch": "stacked-runtime-queue-branch-label",
  "intent": "Run bounded autoresearch on the remote-workhorse route.",
  "requested_action": "hermes-autoresearch",
  "allowed_actions": ["hermes-autoresearch"],
  "privacy_scope": "team",
  "action_payload": {
    "topics": [
      "topic-a",
      "topic-b"
    ],
    "max_parallel": 10,
    "scope": "remote-workhorse",
    "evidence_target": "redacted-team-bundle"
  },
  "permissions": {
    "shell": "forced-command",
    "remote_mutation": false,
    "secret_access": false,
    "provider_writeback": false,
    "network": "local-only"
  },
  "evidence_requirements": [
    "bounded-topic-plan",
    "redacted-status-json",
    "artifact-refs",
    "compact-summary"
  ],
  "operator_call_conditions": [
    "runtime-queue-full",
    "provider-rate-limit",
    "scope-expansion-request",
    "stream-safety-failure"
  ],
  "expected_output": "PASS/FLAG/BLOCK plus redacted evidence refs.",
  "stream_policy": "redacted",
  "expires_at": "timestamp",
  "signature_stub": "placeholder-until-signed-cards"
}
```

Future behavior expectations for that lane:

- provider auth remains runtime-host-owned and out of card payloads;
- `action_payload.topics` must be a non-empty array with at most 10 stream-safe
  strings;
- optional `action_payload.scope` and `action_payload.evidence_target` are
  short redacted labels, not file paths;
- optional `action_payload.max_parallel` is `1..10`, but the runtime env cap
  still wins;
- status JSON for this action includes `action`, `topic_count`,
  `max_parallel_effective`, `phase`, `level`, `verdict`,
  `provider_rate_limited`, `secret_values_recorded=false`, and redacted
  `artifact_refs`;
- `429` / `rate_limit` returns `FLAG provider_rate_limited`, not repo failure;
- autoresearch fan-out still runs behind leases/status JSON, not ad hoc tmux
  spawning.

## Follow-Up Notes

Later layers can add:

1. signed runtime cards and detached verification;
2. tmux transcript tails with stream-safety filtering;
3. replacement of the local fixture with a real Superruntime registry source;
4. bounded Multica status writeback after policy and audit contracts exist;
5. richer queue/backoff policy or explicit manual gate for future
   provider/CI-triggered harness calls;
6. live Superruntime/Fusion Bridge views backed by the runtime status spool.
