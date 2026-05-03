# Remote Workhorse

Read order for a new agent:

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

Phase 1 started local and read-only. It now has a fresh DigitalOcean base host
and base snapshot proven. The staged NixOS install has completed its guarded
lustrate reboot and is now booted as NixOS 25.11.

Remote NixOS updates use `scripts/nixos-remote-rebuild.sh`; run dry-run first,
then `--mode test`, and only use `--mode switch` after the test proof is clean.
The first foundation switch, reboot persistence proof, and post-foundation
snapshot are recorded in `preflight/NIXOS_FOUNDATION_PROOF.md`.
