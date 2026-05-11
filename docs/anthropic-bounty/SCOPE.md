# Anthropic Model Safety Bounty Scope

Status: public-safe research spec
Created: 2026-05-08

## Purpose

This lane prepares a compliant research package for Anthropic's Model Safety Bug
Bounty Program on HackerOne.

The target is not "find a clever one-off prompt." The target is a measurement
system for evaluating whether a novel, reproducible, universal jailbreak class
exists inside the authorized program surface.

Reward function is not workflow: bounty value guides prioritization, but this
repo only builds public-safe planning, schema, dry-run, and reporting controls.
It does not store candidate prompt bodies or run live red-team tests before
authorization.

## Primary Sources

- Anthropic Help Center: Model Safety Bug Bounty Program
  - `https://support.claude.com/en/articles/12119250-model-safety-bug-bounty-program`
- HackerOne blog: Anthropic Expands Their Model Safety Bug Bounty Program
  - `https://www.hackerone.com/blog/anthropic-expands-their-model-safety-bug-bounty-program`
- HackerOne blog: How Anthropic's Jailbreak Challenge Put AI Safety Defenses to
  the Test
  - `https://www.hackerone.com/blog/how-anthropics-jailbreak-challenge-put-ai-safety-defenses-test`

## In-Scope Research Shape

The public sources describe interest in:

- universal jailbreak techniques;
- deployed systems with ASL-3 protections;
- Constitutional Classifiers;
- harmful biological question coverage, using question sets shared only with
  accepted participants;
- reports submitted through HackerOne after program acceptance.

The public maximum stated by Anthropic's current help article is up to
`$35,000` per novel universal jailbreak, awarded by Anthropic's internal
criteria.

## Out-of-Scope For This Repo

This repo must not contain:

- actual harmful biological, chemical, radiological, nuclear, cyber, or weapon
  instructions;
- real jailbreak strings intended to bypass Anthropic safeguards;
- accepted-participant question sets;
- model alias details provided under program access;
- classifier internals, hidden rubrics, or NDA-bound details;
- raw model completions containing prohibited operational content;
- access tokens, API keys, account identifiers, or private HackerOne report
  material.

## Technical Vulnerabilities

The model-safety bounty lane is distinct from Anthropic's general technical
vulnerability disclosure path. Appsec findings such as XSS, SQL injection,
CSRF, privilege escalation, auth bypass, misconfiguration, or directory
traversal belong in Anthropic's responsible disclosure flow, not this model
safety spec.

## Authorization Gates

No live model red-team run may start until all are true:

1. The operator has accepted program participation terms.
2. The operator has access to the authorized HackerOne program.
3. The operator has access to the authorized model alias or test surface.
4. The operator has a private storage location for NDA-bound artifacts.
5. The local harness is configured to redact or withhold prohibited content.

If any gate is missing, the lane may only do public-source planning and
abstract taxonomy work.

## Verdict Rules

`PASS`:

- scope is based on current public first-party sources;
- all generated artifacts are public-safe;
- no operational jailbreak or harmful answer text is stored;
- live testing is blocked until authorization gates are met.

`FLAG`:

- public program details are incomplete or stale;
- HackerOne policy content is unavailable without login;
- candidate taxonomy is abstract but not yet tied to authorized rubric fields.

`BLOCK`:

- artifact contains harmful operational instructions;
- artifact contains NDA-bound question sets or model details;
- live testing is attempted outside the authorized program surface;
- raw completions with prohibited content are written to public or repo-tracked
  files.
