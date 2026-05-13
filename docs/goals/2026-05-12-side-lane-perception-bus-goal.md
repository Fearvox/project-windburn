# Goal: Side-Lane Perception Bus v0.1

Use this as the `/goal` prompt for a fresh Hermes / Codex / Claude Code agent
inside the Windburn repo root.

```text
/goal Build Windburn side-lane perception bus v0.1.

Context:
- We already proved a local Codex app-server perception bus smoke.
- Read first:
  - docs/protocols/2026-05-12-codex-side-lane-perception-bus-v0.md
  - scripts/codex-app-server-relay-smoke.mjs
- Existing hook writes explicit side-lane relay artifacts to:
  - repo-local relay state under var/side-lane-relay/
- The hook only captures explicit markers:
  - PARK_TO_PARENT:
  - DISTILL_TO_PARENT:
  - RETURN_TO_PARENT:

Goal:
Create the smallest production-shaped relay daemon that turns explicit
side-lane artifacts into parent-thread model-visible context, without treating
side-chat transcripts as truth.

Required behavior:
1. Add a script under scripts/ that can read relay inbox JSONL records.
2. Validate each record as a bounded artifact:
   - marker is one of PARK_TO_PARENT / DISTILL_TO_PARENT / RETURN_TO_PARENT
   - relay_payload is non-empty
   - cwd/path scope is Windburn-local when present
   - artifact is not promoted to source-truth
3. For dry-run mode, print the exact Responses API item that would be injected.
4. For live mode, use the same app-server newline JSON protocol proven by
   scripts/codex-app-server-relay-smoke.mjs:
   - start app-server over stdio://
   - initialize
   - thread/start
   - thread/inject_items
   - turn/start only when verification is requested
   - thread/read for materialized receipt
5. Write relay receipts to:
   - repo-local relay state under var/side-lane-relay/
6. Keep source-truth human-gated:
   - no automatic writes to source-truth
   - no automatic belief promotion
   - parking/perception receipts only

Deliverables:
- scripts/windburn-side-lane-perception-bus.mjs
- docs/protocols/2026-05-12-codex-side-lane-perception-bus-v0.md updated with
  v0.1 usage
- one focused smoke command in the docs
- no unrelated repo cleanup

Verification:
- node --check scripts/windburn-side-lane-perception-bus.mjs
- dry-run against a synthetic relay artifact
- live smoke may be optional if app-server/model auth is unavailable, but if it
  runs, it must prove model-visible materialization the same way
  scripts/codex-app-server-relay-smoke.mjs does.

Guardrails:
- Do not inspect or store full side-chat transcripts.
- Do not send private files or secrets into app-server context.
- Do not change hooks/config unless strictly required.
- Preserve all existing untracked files.
- Report exact PASS/FLAG/BLOCK at closeout.
```
