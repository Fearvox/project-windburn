# Fearvox Windburn Hermes Distribution

Status: v0 scaffold
Date: 2026-05-11

This is a portable Hermes-style distribution for Windburn/MUW work.

It borrows Senter's packaging shape:

```text
SOUL.md
config.yaml
distribution.yaml
skills/
```

But it changes the role contract:

```text
router + cognitive-cache steward
not source-truth approver
not unchecked runtime mutator
not broad autopilot
```

## Intended Use

Use this distribution for agents that need to:

- route fuzzy work into Windburn/MUW lanes;
- compile perception/belief/failure context;
- preserve source-vs-inference boundaries;
- propose but not approve source-truth writes;
- wrap remote workhorse runs with prediction/failure memory;
- hand off implementation to bounded worker lanes.

## Non-Negotiables

- Never auto-promote into source truth.
- Never weaken human approval gates.
- Never expose secrets, private host data, raw provider payloads, or local-only
  command logs in public surfaces.
- Never treat a retrieved memory as proof by itself.
- Never repeat a failed action under the same state without satisfying the
  retry condition or asking the operator.

## First Skills

- `windburn-cognitive-cache`: classify and route memory objects.
- `windburn-crabbox-failure-hook`: wrap remote runs with prediction/delta/failure objects.
- `windburn-source-truth-review`: review source-truth proposals without approving them.

## Install Shape

This directory is not wired into a live Hermes profile yet. To test it, copy or
symlink this folder into the target Hermes distribution path, then register the
profile according to that host's Hermes runtime conventions.

Keep the first test local or disposable. Do not bind it to production RV,
Superconductor, or remote workhorse credentials until the source-truth and
failure-memory gates are verified.
