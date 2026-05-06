# Windburn Agent Operating Contract

Windburn is the local-first control surface for the Remote Workhorse program.
The first active design is:

- `docs/remote-workhorse/0xvox-unknown-design-20260502-222759.md`

## Current Scope

Phase 1 is contract-first infrastructure plus the first proven DigitalOcean
NixOS workhorse. Build artifacts, evidence templates, local canaries, and
operator docs must let a new agent rerun the same workflow. Remote NixOS
mutations go through `scripts/nixos-remote-rebuild.sh`, with `test` before
`switch`. The first foundation layer is proven in
`docs/remote-workhorse/preflight/NIXOS_FOUNDATION_PROOF.md`.

## Communication Profile

Apply `docs/codex-desktop-communication-profile.md` for Codex Desktop,
Superconductor, Hermes, and Workbench-facing sessions. Default tone is direct,
human, concise, bilingual when useful, and pushback-ok. Keep the main line
visible, avoid service-bot filler, and treat screenshots/browser previews as
public surfaces.

## Superconductor Session

When launched from Superconductor, start by proving the repo anchor instead of
trusting the shell cwd:

```sh
scripts/superconductor-codex-intake.sh
```

Current canonical local repo is `/Users/0xvox/Windburn`. If Superconductor
starts in another project, use explicit `workdir` or `git -C /Users/0xvox/Windburn`
for every repo claim. Do not move, duplicate, or relink this repo without an
explicit operator request.

## Worktree Convention

Use project-local git worktrees under `.worktrees/` for implementation slices.
Keep `.worktrees/` ignored. Merge verified work back to `main` only after the
slice passes its local checks.

## Proof Rules

- Read live repo/tool state before making success claims.
- If a required tool is missing, write a repair card and return `FLAG` or
  `BLOCK`; do not fake `PASS`.
- Research Vault and code-review-graph claims require fresh proof artifacts.
- Preserve existing routes unless the design explicitly replaces them.
- Never store secrets in this repository. Use examples and operator-owned env
  files for provider credentials.
- Treat screenshots, browser previews, and livestream surfaces as public by
  default. Do not render raw public IPs, local absolute paths, credential paths,
  SSH/tmux targets, or operator commands in shared UI; use redacted/spoiler
  labels unless the operator explicitly requests a private diagnostic view.

## Default Verification

Run these before closeout when the relevant tooling exists:

```sh
scripts/superconductor-codex-intake.sh
scripts/check.sh
git diff --check
scripts/digitalocean-snapshot.sh
scripts/nixos-remote-rebuild.sh
git status --short --branch
```

## Darwin Self-Evolution for Creator Visual Paths

One atomic slice per run. Prioritize frontier adapter (capsule → p5/remotion/browser-demo/fixed-canvas QA using browser-qa skill). Mutation must render testable phenotype, evaluate creator usefulness (helps make visual artifacts without bloat), select smallest winner, retain with regression gate, avoid dashboards.

Retained winner: fusion-chat-terminal's industrial-brutalist terminal UI with live matrix scanline and setup assistant for xAI lane (links to DASH). Use browser-qa + vision_analyze on deployed preview for visual regression, fixed-canvas verification if applicable, and interaction smoke on setup/polish buttons.

Mutation axes this run: improved audit integration in AGENTS.md to enforce loaded skills (frontend-design, browser-qa, verification-loop).

Verification gate added: include `hermes mcp test research_vault` and visual proof in captain runtime checks.
