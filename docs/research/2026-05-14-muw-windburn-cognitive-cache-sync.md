# MUW × Windburn — cognitive cache sync

Date: 2026-05-14
Context: cross-source signal absorption after operator-pointed briefing. Two signal sources treated as authoritative: MUW (orchestration layer) and Windburn (substrate).

## Observation

The MUW direction document `docs/windburn-cognitive-cache-direction.md` (dated 2026-05-03) defines Windburn as a memory-native agent substrate built around seven cache types, with the canonical loop:

```
observe reality → update belief → choose action → verify delta → preserve learning
```

The contrast vs. transformer KV cache is structural: KV cache answers "what tokens have I already attended to?"; cognitive cache answers "what reality have I already learned?".

Windburn this week landed concrete artifacts that fill or skeleton-fill five of the seven cache slots. This sync reconciles built-state against design-state with public-safe evidence.

## 7-cache mapping (built-state vs. design-state)

| Cache slot | Design-state intent | Built-state in Windburn main | Coverage |
|---|---|---|---|
| **source** | Research Vault, repo docs, source-of-truth files | OpenChronicle install proposal + RV MCP read-only contract (already documented) | proposal ✓ / apply ⏳ |
| **episodic** | What happened, in order | OpenChronicle ingest plan for `learnings/` + read-only mirror of upstream agent memory | proposal ✓ / ingest ⏳ |
| **perception** | Grounded observations from tools and humans | side-lane perception bus v0 (committed) + bounded boundary smoke | shipped ✓ |
| **failure** | Actions attempted, observed deltas, avoid/retry rules | crabbox failure hook doc (committed) + corresponding distribution skill | shipped ✓ |
| **procedural** | Reusable skills, repo routes, tool patterns | goalv3-cc skill (Phase 1+2 PASS), 8 captured lessons in PLAN-CLOSEOUT | shipped ✓ |
| **belief** | Hypotheses with evidence and confidence | hermes-distributions skill skeleton `windburn-source-truth-review` (skeleton only) | skeleton ⚠ |
| **working** | Current session focus and task stack | no formal substrate yet (auto-memory partial proxy) | gap ❌ |

Score: **5 shipped / 1 skeleton / 1 gap**. The substrate is materially in place for source, episodic, perception, failure, and procedural reality. Belief and working layers remain the next-frontier surface.

## Cross-source edge note

MUW currently has uncommitted hardening to its own codex per-run profile: normal issue/comment/review runs avoid carrying user-level hook configuration and disable plugin hooks to prevent automated lanes from triggering stop-review gates or hook side effects.

Mapping to Windburn's Phase 2 T2 hooks-port proposal: not in conflict. T2 proposes CC daily-interactive hooks (vibe-island-bridge, herdr-agent-state) which are intended for human-attended sessions. The MUW hardening covers ephemeral automated codex profiles. When Windburn later spawns its own automated review subprocesses, the same "ephemeral-profile-no-hooks" pattern should mirror — this is the belief-cache boundary of "when not to learn".

## Closeout

```text
CHANGED:
- docs/research/2026-05-14-muw-windburn-cognitive-cache-sync.md  (this doc, +N lines)
- auto-memory reference file recording MUW/Windburn relationship (cross-session continuity)

VERIFIED:
- five cognitive cache slots have shipped artifacts in current Windburn main
- one slot has skeleton only (belief, via hermes-distributions skill scaffold)
- one slot has no formal substrate yet (working cache)
- cross-source edge note re: hook scope is observation-only, not a code change
- public-safety scan: no absolute home paths, no live IDs, no secrets, no raw transcripts

REMAINING:
- working-cache substrate design (currently approximated by per-session auto-memory)
- belief-cache application activation (skeleton skill exists, not yet applied)
- Phase 2 proposal apply queue (T1 OpenChronicle MCP wire, T2 hooks port, T3 MCP servers via wrapper-script pattern, T4 null-action — all operator-driven, Dry-Run-Gated)
- next-frontier signal: MUW direction doc dated 2026-05-03, may warrant a Windburn-side response/revision after this cycle of artifacts lands

PRS / LINKS:
- Windburn main commits relevant to this sync (contains): 4d326ea Phase 1 closeout, f685e23 trifecta upstream feedback, 559c6ed pressure-test/probe/research/hermes batch, 0f34075 side-lane perception bus, 2a2e1d6 side-lane goal metrics + memory anchor
- MUW direction doc (cross-link source, dogfood-platform): docs/windburn-cognitive-cache-direction.md
- Windburn-side Phase 2 closeout (contains, gitignored local-only): .goal/absorb-codex-into-cc/closeout.md verdict=PASS

VERDICT: PASS
```

## Notes for next session

This sync is orientation, not application. No proposals were applied during this cycle. The next operator-driven decisions are choosing among (a) apply some Phase 2 proposal, (b) start a new goalv3-cc goal for belief-cache or working-cache, or (c) absorb the next round of MUW signal before acting. Workbench discipline says: all three are WIP-acceptable as long as decisions are recorded.
