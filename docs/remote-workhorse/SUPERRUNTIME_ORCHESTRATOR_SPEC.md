# SUPERRUNTIME_ORCHESTRATOR_SPEC

Generated: `2026-05-04`

## Intent

Define Windburn's outer orchestration layer for assigning work from public
systems to Superconductor-enabled local runtimes without exposing
Superconductor itself to the public internet.

The core decision:

```text
Superconductor is a registered runtime/executor.
It is not the public webhook receiver, scheduler, or internet-facing control
plane.
```

Public systems such as Linear, GitHub, Slack, Discord, and future Multica-style
task surfaces should terminate in a stricter orchestration layer. That layer
normalizes tasks, applies policy, signs task envelopes, and hands work to
registered runtimes through a secure channel.

## Why This Exists

The current Fusion Chat and Superconductor work proves that local-first agent
execution can be fast and ergonomic. The missing layer is remote task
acquisition:

- Linear/GitHub/Slack/Discord want public webhooks.
- Superconductor should not be ngrok/cloudflared into the public web.
- Polling every upstream directly from Superconductor is operationally possible
  but gives weaker UX and worse policy centralization.
- Harness execution is orthogonal: Codex, Claude Code, Hermes, Pi, and later
  worker runtimes should be adapters behind one runtime contract.

So Windburn needs an outer orchestrator:

```text
Public Bridges
  -> Windburn Orchestrator
  -> Secure Runtime Channel
  -> Registered Superconductor Runtime
  -> Harness Adapter
  -> Worktree + Evidence
```

## Non-Goals

- Do not expose Superconductor's local HTTP/socket/control surface publicly.
- Do not turn Fusion Chat into a mutating public executor.
- Do not let public webhook payloads become shell commands.
- Do not require every harness to implement webhook or queue integration.
- Do not move worktree ownership away from the local runtime.
- Do not stream raw secrets, host IPs, local paths, OAuth payloads, or private
  issue content into browser-safe surfaces.

## Components

### 1. Public Bridges

Small public services that terminate provider-specific inbound events.

Initial bridge candidates:

| Bridge | Input | Output |
| --- | --- | --- |
| Linear | issue/comment/status webhook or polling fallback | `WorkIntent` |
| GitHub | issue/PR/check/review webhook | `WorkIntent` |
| Slack | app mention, slash command, thread action | `WorkIntent` |
| Discord | command or selected channel bridge | `WorkIntent` |
| Manual API | operator-created task | `WorkIntent` |

Bridge responsibilities:

- Verify provider signatures.
- Reject unsupported event types early.
- Store raw payloads in a private evidence bucket, not in browser payloads.
- Emit normalized `WorkIntent` records.
- Never dispatch directly to a harness.

### 2. Windburn Orchestrator

The central policy and queue layer.

Responsibilities:

- Deduplicate inbound work.
- Resolve workspace/repo/project routing.
- Select a registered runtime based on capability, availability, trust tier,
  and operator policy.
- Generate signed task envelopes.
- Track leases, attempts, timeouts, and final verdicts.
- Store redacted evidence bundles.
- Write back status to provider bridges.

The orchestrator is the only public-facing control plane. It can be hosted
separately from any local runtime and should have a much smaller capability
surface than Superconductor.

### 3. Runtime Registry

Registry of Superconductor-capable runtimes.

Runtime registration is outbound-first:

1. Local runtime starts.
2. Runtime authenticates to orchestrator.
3. Runtime registers capabilities.
4. Runtime opens a secure channel for assignments.
5. Runtime heartbeats with redacted state.

The orchestrator never assumes a runtime is reachable by inbound public
networking.

### 4. Secure Runtime Channel

The channel from orchestrator to runtime.

Allowed first implementations:

- outbound WebSocket;
- long-polling assignment pull;
- message queue consumer;
- tunnel with runtime-initiated session only.

Required properties:

- Runtime authenticates orchestrator messages.
- Orchestrator authenticates runtime identity.
- Every task envelope is signed.
- Each task has a lease and idempotency key.
- Runtime can refuse tasks without side effects.
- Channel carries redacted status events by default.

### 5. Superconductor Runtime Adapter

Local agent running next to Superconductor.

Responsibilities:

- Validate task envelope signatures and policy.
- Resolve or create the worktree.
- Prove repo anchor before dispatch.
- Lock the worktree lease.
- Choose a harness adapter.
- Run the harness.
- Collect evidence.
- Return status and final report.

This adapter should be native to Superconductor over time, but the first
Windburn prototype may live beside it.

### 6. Harness Adapters

Harness adapters execute bounded tasks inside prepared worktrees.

Initial adapters:

| Adapter | Use |
| --- | --- |
| Codex | code changes, repo inspection, verification, docs |
| Claude Code | alternate implementation/review lane |
| Hermes | long-context remote chat/provider lane |
| Pi or future agents | specialized harnesses |

Adapter contract:

- Receive a signed `HarnessDispatch`.
- Run only inside the assigned worktree/scope.
- Emit status events.
- Emit artifacts/evidence.
- Return `PASS`, `FLAG`, or `BLOCK`.

Harnesses do not own upstream webhook semantics. They execute work.

### 7. Evidence Plane

Durable proof surface for every assigned task.

Evidence classes:

- `raw_private`: provider webhook payload, hidden from browser and public docs.
- `runtime_private`: local paths, host details, command logs, raw stdout.
- `redacted_public`: browser-safe status, verdict, artifact summary.
- `repo_durable`: committed docs/code/tests.

Fusion Chat, docs, and Discord streaming surfaces should only consume
`redacted_public` unless the operator explicitly opens a private diagnostic
view.

## Core Data Contracts

### WorkIntent

Normalized provider-independent task request.

```json
{
  "schema_version": 1,
  "intent_id": "wi_...",
  "provider": "linear|github|slack|discord|manual",
  "provider_event_id": "opaque",
  "project_hint": "windburn",
  "repo_hint": "Fearvox/project-windburn",
  "requested_action": "review|implement|verify|triage|comment",
  "human_text": "bounded user-facing task summary",
  "source_visibility": "private|team|public",
  "created_at": "timestamp"
}
```

### RuntimeRegistration

Runtime capability declaration.

```json
{
  "schema_version": 1,
  "runtime_id": "rt_...",
  "runtime_kind": "superconductor",
  "display_name": "Windburn local runtime",
  "capabilities": ["git-worktree", "codex", "hermes", "browser-proof"],
  "workspace_roots": ["redacted"],
  "stream_safe": true,
  "mutation_policy": "operator-gated",
  "heartbeat_at": "timestamp"
}
```

### TaskEnvelope

Signed assignment from orchestrator to runtime.

```json
{
  "schema_version": 1,
  "task_id": "task_...",
  "intent_id": "wi_...",
  "runtime_id": "rt_...",
  "lease_id": "lease_...",
  "allowed_repo": "Fearvox/project-windburn",
  "worktree_policy": "create-isolated-worktree",
  "requested_harness": "codex",
  "task_prompt": "bounded implementation/review prompt",
  "permissions": {
    "network": "allowed",
    "remote_mutation": false,
    "secret_access": false,
    "provider_writeback": "orchestrator-only"
  },
  "evidence_requirements": ["tests", "git-status", "redacted-summary"],
  "expires_at": "timestamp",
  "signature": "detached-signature"
}
```

### HarnessDispatch

Runtime-local harness invocation contract.

```json
{
  "schema_version": 1,
  "dispatch_id": "dispatch_...",
  "task_id": "task_...",
  "harness": "codex|claude-code|hermes|pi",
  "workdir": "runtime-local path not returned to browser",
  "prompt": "bounded task prompt",
  "expected_output": "PASS/FLAG/BLOCK plus evidence",
  "stream_policy": "redacted"
}
```

### StatusEvent

Redacted event returned by runtime.

```json
{
  "schema_version": 1,
  "task_id": "task_...",
  "runtime_id": "rt_...",
  "phase": "queued|leased|worktree-prep|running|verifying|done",
  "level": "info|flag|block|pass",
  "message": "browser-safe text",
  "artifact_refs": ["redacted_public_ref"],
  "secret_values_recorded": false,
  "emitted_at": "timestamp"
}
```

## Assignment Flow

1. Provider event enters a Public Bridge.
2. Bridge verifies provider signature.
3. Bridge emits `WorkIntent`.
4. Orchestrator applies policy and routing.
5. Orchestrator selects registered runtime.
6. Orchestrator signs `TaskEnvelope`.
7. Runtime receives envelope over outbound secure channel.
8. Runtime validates signature, lease, repo, and permission boundaries.
9. Runtime prepares isolated worktree.
10. Runtime dispatches harness.
11. Harness executes and verifies.
12. Runtime returns redacted `StatusEvent` stream and final evidence summary.
13. Orchestrator writes provider status/comment through the bridge.
14. Fusion Chat displays redacted task status.

## Security Model

Default stance:

- Public bridges are narrow and provider-specific.
- Orchestrator is public but strict.
- Runtime is private and outbound-first.
- Harnesses are local executors, not public API servers.
- Browser surfaces are stream-safe by default.

Hard requirements:

- No arbitrary shell from provider payloads.
- No provider token in runtime-visible browser payloads.
- No raw local paths or host IPs in public status.
- No runtime accepting unsigned task envelopes.
- No public inbound route into Superconductor.
- No mutating action without explicit policy and audit record.

## Failure Modes

| Failure | Required Behavior |
| --- | --- |
| Provider signature invalid | Drop event and record private audit |
| Runtime offline | Queue or mark `FLAG`, do not fall back to public SSH |
| Runtime refuses envelope | Preserve task, surface `FLAG` with reason |
| Worktree dirty/conflicting | Create repair card or `BLOCK` |
| Harness crashes | Return `FLAG` with logs private and summary redacted |
| Evidence missing | Do not mark PASS |
| Stream-safety scan fails | Stop public display and mark `LOCKDOWN_FIRST` |

## First Windburn Slice

The first slice should be local-first and mostly fake the public cloud edge:

1. Add `docs/remote-workhorse/SUPERRUNTIME_ORCHESTRATOR_SPEC.md`.
2. Add a fixture `WorkIntent` and `TaskEnvelope` example.
3. Add a local verifier script that validates envelope shape, signature stub,
   and stream-safe output.
4. Add Fusion Chat read-only cards for:
   - registered runtime count;
   - queued task count;
   - current lease;
   - harness dispatch state.
5. Keep actual provider webhook handling out of scope until the local contract
   is proven.

## Open Questions

- Which provider is first: Linear, GitHub, Slack, Discord, or Manual API?
- Should runtime identity use mTLS, signed JWT, SSH certs, or Tailscale identity
  in v0?
- Does Superconductor own the runtime adapter process, or does Windburn run it
  beside Superconductor until native support lands?
- How much raw private evidence should be retained, and where?
- Which writeback destinations are allowed before account mechanisms exist?

## Acceptance Criteria

- A new agent can explain why Superconductor is not public-facing.
- Public bridges, orchestrator, runtime channel, Superconductor adapter, harness
  adapter, and evidence plane have distinct responsibilities.
- Data contracts are specific enough to implement a fixture-based prototype.
- The spec preserves existing Fusion Chat stream-safety rules.
- The spec does not require immediate changes to Superconductor internals.
