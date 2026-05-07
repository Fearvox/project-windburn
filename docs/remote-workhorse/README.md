# Remote Workhorse

Read order for a new agent:

0. `../superconductor-codex-intake.md` when launched from Superconductor
1. `0xvox-unknown-design-20260502-222759.md`
2. `CONTEXT-2026-05-02-evening.md`
3. `phase1/SELF_AWARENESS_BOOTSTRAP.template.md`
4. `phase1/TOOL_INVENTORY.json`
5. `phase1/RESEARCH_VAULT_PROOF.json`
6. `phase1/CODE_REVIEW_GRAPH_PROOF.json`
7. `phase1/CANARY-read-only-repo-review-health.md`
8. `preflight/REMOTE_NIXOS_PREFLIGHT.md`
9. `preflight/COMPUTER_USE_PREFLIGHT_RUNBOOK.md`
10. `preflight/DIGITALOCEAN_CAPABILITY_MAP.md`
11. `preflight/DIGITALOCEAN_HOST_SELECTION_CARD.md`
12. `preflight/REMOTE_HOST_PROOF.md`
13. `preflight/NIXOS_CONVERSION_RUNBOOK.md`
14. `preflight/NIXOS_STAGE_PROOF.md`
15. `preflight/NIXOS_BOOT_PROOF.md`
16. `preflight/NIXOS_FOUNDATION_PROOF.md`
17. `preflight/PROVIDER_SECRET_SMOKE.md`
18. `preflight/HERMES_CODEX_RUNTIME_PROOF.md`
19. `preflight/WORKHORSE_HERMES_RUNTIME_PROOF.md`
20. `preflight/WORKHORSE_CODEX_RUNTIME_PROOF.md`
21. `preflight/WORKHORSE_HERMES_YOLO_LANE_PROOF.md`
22. `preflight/WORKHORSE_HERDR_COCKPIT_PROOF.md`
23. `preflight/DROPLET_ENGAGEMENT_REVIEW.md`
24. `preflight/DIGITALOCEAN_OBSERVABILITY_GATE.md`
25. `preflight/HERMES_HEALTH_GATE.md`
26. `preflight/HERMES_MAINTENANCE.md`
27. `preflight/HERMES_YOLO_LOOP_PROOF.md`
28. `FUSION_CHAT_TERMINAL.md`
29. `FUSION_BRIDGE_V0.md`
30. `SUPERRUNTIME_ORCHESTRATOR_SPEC.md`
31. `MULTICA_SSH_RUNTIME_INGRESS.md`
32. `FUSION_CHAT_PERSONALIZATION_SETTINGS_HANDOFF.md`
33. `preflight/XAI_SETUP_AGENT_SMOKE.md`
34. `preflight/STREAM_SAFETY_PREFLIGHT_SPEC.md`

Read `SUPERRUNTIME_ORCHESTRATOR_SPEC.md` and
`MULTICA_SSH_RUNTIME_INGRESS.md` together for the current v1 bootstrap queue
handshake: SSH stdin card ingress, `run-card` wrapper action, lease slots,
runtime spool, and redacted status JSON.

Phase 1 started local and read-only. It now has a fresh DigitalOcean base host
and base snapshot proven. The staged NixOS install has completed its guarded
lustrate reboot and is now booted as NixOS 25.11.

Remote NixOS updates use `scripts/nixos-remote-rebuild.sh`; run dry-run first,
then `--mode test`, and only use `--mode switch` after the test proof is clean.
The first foundation switch, reboot persistence proof, and post-foundation
snapshot are recorded in `preflight/NIXOS_FOUNDATION_PROOF.md`.
Provider credential sync and the current remote provider smoke `FLAG` are
recorded in `preflight/PROVIDER_SECRET_SMOKE.md`.
The remote Hermes `openai-codex` runtime route is proven in
`preflight/HERMES_CODEX_RUNTIME_PROOF.md`.
The NixOS workhorse's durable Hermes command, `uv`, runtime evidence timer, and
fresh Hermes Codex smoke are proven in
`preflight/WORKHORSE_HERMES_RUNTIME_PROOF.md`.
The NixOS workhorse's standalone Codex CLI package, fixed Codex tmux lane, and
Fusion Bridge readback fields are proven in
`preflight/WORKHORSE_CODEX_RUNTIME_PROOF.md`.
The durable fixed Hermes yolo tmux lane and runner evidence gate are proven in
`preflight/WORKHORSE_HERMES_YOLO_LANE_PROOF.md`.
The human-friendly Herdr cockpit server, socket API status, runner evidence
section, and Fusion Bridge readback are recorded in
`preflight/WORKHORSE_HERDR_COCKPIT_PROOF.md`.
The current multi-droplet engagement review is recorded in
`preflight/DROPLET_ENGAGEMENT_REVIEW.md` and can be refreshed with
`scripts/droplet-engagement-review.sh --out docs/remote-workhorse/preflight/DROPLET_ENGAGEMENT_REVIEW.md`.
The DigitalOcean observability desired state, Hermes health gate, and Hermes
update/tmux maintenance path are recorded in
`preflight/DIGITALOCEAN_OBSERVABILITY_GATE.md`,
`preflight/HERMES_HEALTH_GATE.md`, and `preflight/HERMES_MAINTENANCE.md`.
The fixed tmux `hermes --yolo` runtime window plus an `openai-codex` one-shot
loop proof are recorded in `preflight/HERMES_YOLO_LOOP_PROOF.md`.
The first unified remote chat entrance is recorded in
`FUSION_CHAT_TERMINAL.md` and implemented in `../../apps/fusion-chat-terminal/`.
The first read-only browser bridge is recorded in `FUSION_BRIDGE_V0.md` and
served by `../../scripts/fusion-chat-bridge.sh`.
The outer bridge/orchestrator contract for registering Superconductor as a
private runtime/executor is recorded in `SUPERRUNTIME_ORCHESTRATOR_SPEC.md`.
The current private forced-command runtime-channel handshake for Multica/gstack
ingress, including stdin cards, lease queueing, spool status JSON, and compact
redacted `PASS/FLAG/BLOCK` summaries, is recorded in
`MULTICA_SSH_RUNTIME_INGRESS.md`.
The setup/personalization maintenance lane for future Workbench swarm agents is
recorded in `FUSION_CHAT_PERSONALIZATION_SETTINGS_HANDOFF.md`.
The xAI setup lane credential shape and current API proof are recorded in
`preflight/XAI_SETUP_AGENT_SMOKE.md`.
The livestream safety gate and `NO_ROTATE / LOCKDOWN_FIRST / ROTATE` decision
contract are specified in `preflight/STREAM_SAFETY_PREFLIGHT_SPEC.md`.
