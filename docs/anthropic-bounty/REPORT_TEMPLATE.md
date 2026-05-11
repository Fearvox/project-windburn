# HackerOne Report Template

Status: private-report skeleton with public-safe placeholders
Created: 2026-05-08

This template is for a private HackerOne submission after program acceptance.
Do not fill it with harmful prompt bodies or prohibited model completions in
this repository.

## Title

Universal jailbreak candidate against authorized Anthropic model-safety test
surface: `[candidate_id]`

## Summary

`[Short description of the candidate family and why it is universal.]`

Do not include operational harmful content in the public-safe copy.

## Program And Authorization

- Program: Anthropic Model Safety Bug Bounty Program
- Platform: HackerOne
- Participant authorization: `[private reference]`
- Authorized model/test surface: `[private reference]`
- Test question set: `[private reference]`
- NDA-bound materials stored outside repo: `yes`

## Authorization Evidence

- HackerOne program acceptance confirmed: `[private ref / timestamp]`
- NDA acceptance confirmed: `[private ref / timestamp]`
- Private storage proof verified outside repo: `[yes/no/private ref]`
- Harness redaction mode verified: `[yes/no]`

## Impact

`[Explain at a high level what safeguard boundary is bypassed and why the issue
matters. Avoid harmful domain details in repo-tracked copies.]`

## Affected Surface

- Model/test alias: `[private reference]`
- Classifier/safeguard surface: `[private reference if permitted]`
- Date buckets tested: `[day buckets]`

## Private Evidence Procedure

Private report only:

1. `[Authorized setup step]`
2. `[Candidate template application step]`
3. `[Authorized question selection step]`
4. `[Observed model behavior summary]`

Repo-safe copy must replace the actual candidate prompt, target questions, and
completion text with aggregate bucket ids and private evidence references.

## Evidence Table

| Bucket ID | Candidate ID | Question Bucket | Bucket Count | Bucket Eligible | Private Evidence Ref | Verdict | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `day:...` | `cand_...` | `private:q_...` | `[count]` | `[true/false]` | `[private ref]` | `PASS/FLAG/BLOCK` | redacted |

## Reliability

- total authorized questions tested: `[count]`
- successful buckets: `[count]`
- paraphrase variants: `[count]`
- retries per variant: `[count]`
- observed stability: `[score]`

## Novelty

`[Explain why this is not a known public jailbreak or trivial prompt variant.]`

## Safety Handling

- raw prompt stored in repo: `false`
- raw completion stored in repo: `false`
- harmful content recorded in public artifact: `false`
- per-attempt transcript hashes recorded in repo: `false`
- aggregate bucket counts recorded in repo: `true`
- private evidence retained according to program terms: `[yes/no/private ref]`

## Suggested Remediation Direction

`[High-level classifier or policy-boundary improvement suggestion. Do not reveal
exploit text in a public-safe copy.]`

## Disclosure Notes

- Public disclosure requires Anthropic permission.
- Program question sets, classifier details, and model details remain
  confidential unless Anthropic explicitly permits disclosure.
