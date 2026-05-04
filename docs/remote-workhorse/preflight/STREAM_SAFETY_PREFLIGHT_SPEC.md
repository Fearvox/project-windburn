# STREAM_SAFETY_PREFLIGHT_SPEC

Generated: `2026-05-04`

## Intent

Create a read-only pre-livestream gate for Windburn/Fusion Chat so an operator
can safely stream Discord, Fusion Chat, Superconductor, and remote workhorse
workflows without raw infrastructure details appearing on screen.

This gate answers one practical question:

```text
Can we keep the current remote hosts, or do we need lockdown/rotation before
the next public working session?
```

## Background

A Fusion Chat screenshot exposed a public host value in the right-side Route
Contract. The value was not a token, key, password, webhook, or credential. The
immediate fix made the Fusion Chat browser surface stream-safe by default:
hosts, paths, attach targets, operator commands, and credential paths now render
as spoiler/redacted labels.

The next step is not automatic IP rotation. Rotation is only useful if there is
evidence of credential compromise, unauthorized access, or an unbounded public
service. Otherwise the better move is lockdown: prove the exposed host posture,
close public surfaces that do not need to be public, and keep the UI redaction
gate enforced.

## Scope

The first implementation must be read-only.

Targets:

- Fusion Chat browser UI and read-only bridge payloads.
- Local static artifacts under `apps/fusion-chat-terminal/`.
- DigitalOcean Droplet inventory, firewall inventory, and uptime/monitoring
  desired state.
- Remote SSH posture for Hermes, NixOS workhorse, and CCR lanes.
- Public listening ports and local-only listening ports on each remote host.
- Recent SSH/auth log summary, redacted to counts and verdicts.
- Repo/docs evidence that could be shown during a stream.

Out of scope for the first pass:

- Automatic IP rotation.
- Automatic firewall mutation.
- Secret rotation.
- DNS changes.
- Editing Discord/WeChat/social history.
- Publishing a private diagnostic view.

## Commands

Planned command:

```sh
scripts/stream-safety-preflight.sh
```

Optional output override:

```sh
scripts/stream-safety-preflight.sh --out docs/remote-workhorse/preflight/STREAM_SAFETY_PREFLIGHT.md
```

The command must not print raw public IPs, credential paths, token lengths,
private paths, or SSH target strings. It can print stable route labels such as
`hermes`, `workhorse`, `ccr`, `codex`, and `superconductor`.

## Checks

### 1. Fusion Surface Leak Scan

Probe:

- Serve Fusion Chat with the read-only bridge on `127.0.0.1`.
- Fetch `/`, `/api/status`, `/api/remotes`, `/api/preflight`, and
  `/api/setup/xai/inspect`.
- Scan response bodies and browser text for:
  - public IPv4 literals;
  - local absolute paths;
  - remote absolute paths under service roots;
  - credential filenames;
  - raw SSH/tmux attach targets;
  - key/token-shaped strings;
  - Vercel project/deployment IDs if the page is stream-facing.

Pass:

- No forbidden pattern appears in browser-visible text or API payloads.
- Spoiler labels are present for `host`, `transport`, and `command`.
- Server-only source files are not served as static assets.

### 2. Static Artifact Leak Scan

Probe:

- Scan `apps/fusion-chat-terminal/` and its public static payloads.
- Scan public-facing Windburn docs likely to be screen-shared.

Pass:

- No newly added raw IP/path/credential references in the stream-facing app.
- Historical evidence docs may contain host proof, but the preflight report must
  mark them as `PRIVATE_EVIDENCE`, not livestream material.

### 3. DigitalOcean Control Plane Read-Only Snapshot

Probe:

- Droplet list by route label.
- Firewall list and firewall-to-Droplet associations.
- Uptime check inventory.
- Monitoring/alert policy inventory where available.

Pass:

- Each remote host has an explicit firewall posture recorded.
- SSH exposure is intentionally described.
- Unneeded public service ports are absent or marked as `LOCKDOWN_FIRST`.

### 4. Remote SSH Posture

Probe each remote host through temporary known-hosts files:

- OS identity and hostname.
- `sshd` effective password/root login posture where available.
- Failed units count.
- Recent auth log count summary only.
- `last`/`lastlog` summary by count and recency, without raw IP output.

Pass:

- Key-only access is confirmed or password login is explicitly blocked.
- No unexplained successful login appears after the exposure time.
- Auth failures are normal internet noise, not successful access.

### 5. Public Listener Posture

Probe:

- `ss -ltnp` or platform equivalent.
- Classify listeners as:
  - `EXPECTED_PUBLIC`;
  - `EXPECTED_LOCAL`;
  - `INTERNAL_ONLY`;
  - `UNKNOWN_PUBLIC`.

Pass:

- SSH and explicitly intended public services are the only public listeners.
- Any inference/gateway/debug service bound to `0.0.0.0` is either required or
  produces `LOCKDOWN_FIRST`.

### 6. Evidence Hygiene

Probe:

- Generated report.
- Generated JSON if present.
- Git diff for newly added sensitive strings.

Pass:

- Evidence uses route labels, counts, and redacted fields.
- No raw credential paths, key lengths, IPs, or SSH target commands are added to
  new public artifacts.

## Verdicts

### `NO_ROTATE`

Use when:

- No token/private key/password was leaked.
- Fusion Chat and bridge leak scans are clean.
- SSH is key-only or password access is disabled.
- No unexplained successful login appears after the exposure.
- Public listeners are expected and bounded.
- Firewall posture is known.

Meaning:

- Keep the current hosts.
- Continue with stream-safe UI.
- Schedule lockdown improvements as normal work, not emergency rotation.

### `LOCKDOWN_FIRST`

Use when:

- No credential compromise is proven, but a public surface is wider than needed.
- Firewall posture is missing or ambiguous.
- A nonessential service is listening publicly.
- Auth logs are noisy or incomplete but do not show confirmed successful access.
- A stream-facing artifact reintroduces raw infrastructure detail.

Meaning:

- Do not rotate yet.
- First close or restrict the public surface.
- Rerun the preflight. Rotate only if compromise evidence appears.

### `ROTATE`

Use when:

- A secret, private key, password, session token, webhook, or provider credential
  was exposed.
- There is an unexplained successful login after exposure.
- Password SSH is enabled and cannot be immediately locked down.
- A public service exposes secret-bearing or mutating endpoints.
- The host identity is no longer trustworthy.

Meaning:

- Stop streaming this surface.
- Snapshot only if safe.
- Rotate credentials and host entrypoints intentionally.
- Update known_hosts, docs, dashboards, firewall targets, and route contracts
  after rotation.

## Report Contract

The generated report should use this shape:

```text
STREAM_SAFETY_PREFLIGHT
generated_utc=<timestamp>
mode=read-only

VERDICT=<NO_ROTATE|LOCKDOWN_FIRST|ROTATE>
reason=<short_machine_reason>

routes:
- hermes: <PASS|FLAG|BLOCK> <redacted_reason>
- workhorse: <PASS|FLAG|BLOCK> <redacted_reason>
- ccr: <PASS|FLAG|BLOCK> <redacted_reason>
- fusion-ui: <PASS|FLAG|BLOCK> <redacted_reason>
- docs: <PASS|FLAG|BLOCK> <redacted_reason>

operator_next_action=<one concrete action>
mutation_performed=false
secret_values_recorded=false
```

## Acceptance Criteria

- Running the script without flags performs no mutation.
- A report is produced even when optional tools are missing.
- Missing `doctl`, missing SSH access, or missing auth logs degrade to
  `LOCKDOWN_FIRST`, not false PASS.
- The report itself passes the leak scan.
- Fusion Chat can ingest the report as another read-only preflight item without
  exposing raw host/path details.

## Next Implementation Slice

1. Add `scripts/stream-safety-preflight.sh` with local UI/API leak checks first.
2. Add DigitalOcean read-only inventory checks.
3. Add SSH posture checks behind route labels.
4. Write `STREAM_SAFETY_PREFLIGHT.md`.
5. Add Fusion Chat preflight row for the latest stream-safety verdict.
