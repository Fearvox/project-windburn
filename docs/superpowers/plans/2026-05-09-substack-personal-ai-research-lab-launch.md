# Personal AI Research Lab Substack Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the Substack launch packet for `The Personal AI Research Lab`: one launch note, one education essay, one large field report/cookbook, narrated-audio scripts, and a public-safe evidence appendix.

**Architecture:** Build the publication as a durable content workspace under `docs/substack/the-personal-ai-research-lab/`. Keep source evidence, public aggregate data, post drafts, audio scripts, and companion HTML in separate files so each surface can be reviewed independently. Use a small Node script to derive anonymized show-and-tell metrics from local JSON exports without publishing raw rows.

**Tech Stack:** Markdown for editorial drafts, Node.js for aggregate data extraction, static HTML/CSS for the optional evidence appendix, `rg`/`jq`/`git` for verification.

---

## Source Spec

Read before executing:

- `docs/superpowers/specs/2026-05-09-substack-personal-ai-research-lab-launch-design.md`

External sources to cite or use during drafting:

- OpenAI ChatGPT Futures Class of 2026: `https://openai.com/index/introducing-chatgpt-futures-class-of-2026/`
- OpenAI Academy impact-data rollout article: `https://academy.openai.com/public/clubs/higher-education-05x4z/blogs/use-impact-data-to-improve-your-chatgpt-edu-rollout-2026-05-06`
- OpenAI ChatGPT Education page: `https://openai.com/chatgpt/education/`
- OpenAI Help Center ChatGPT Edu article: `https://help.openai.com/en/articles/9377311`
- Substack audio embed article: `https://support.substack.com/hc/en-us/articles/7265654090900-How-do-I-embed-an-audio-file-in-my-Substack-post`
- Substack podcast publishing article: `https://support.substack.com/hc/en-us/articles/360037462092-How-do-I-create-and-publish-a-podcast-on-Substack`
- Substack transcript article: `https://support.substack.com/hc/en-us/articles/18363324028564-How-can-I-generate-a-transcript-of-an-audio-post-on-Substack`

Local input data:

- `/Users/0xvox/Downloads/showandtells-1.json`
- `/Users/0xvox/Downloads/showandtells-3.json`
- `/Users/0xvox/Downloads/showandtells-users.json`

Public-safety note: the local show-and-tell user export contains `email` and `user_id`; never copy raw rows into publication drafts, companion files, or source notes.

## File Structure

Create this workspace:

```text
docs/substack/the-personal-ai-research-lab/
  README.md
  public-safety-checklist.md
  sources.md
  data/
    showandtell-aggregate.public.json
  evidence/
    evidence-index.md
    timeline-2026-03-18-to-2026-05-09.md
  outlines/
    launch-note.md
    education-essay.md
    big-field-report.md
  drafts/
    launch-note.md
    education-essay.md
    big-field-report.md
  audio/
    launch-note-script.md
    education-essay-script.md
    big-field-report-script.md
  companion/
    evidence-appendix.html
```

Create this helper:

```text
scripts/substack-showandtell-aggregate.mjs
```

Responsibilities:

- `README.md`: describes the launch packet and local workflow.
- `public-safety-checklist.md`: the mandatory redaction and claim-review checklist.
- `sources.md`: public URLs and local artifact categories used by the posts.
- `showandtell-aggregate.public.json`: anonymized aggregate metrics and rankings only.
- `evidence-index.md`: maps claims to evidence requirements and current supporting artifacts.
- `timeline-2026-03-18-to-2026-05-09.md`: reconstructs the personal research lab arc by date and artifact.
- `outlines/*.md`: publication outlines with evidence requirements and audio notes.
- `drafts/*.md`: Substack-ready text drafts.
- `audio/*-script.md`: narration scripts derived from locked drafts.
- `companion/evidence-appendix.html`: static, public-safe evidence appendix.
- `scripts/substack-showandtell-aggregate.mjs`: derives aggregate metrics and day/workflow rankings from local JSON exports.

## Task 1: Create Launch Workspace And Safety Checklist

**Files:**

- Create: `docs/substack/the-personal-ai-research-lab/README.md`
- Create: `docs/substack/the-personal-ai-research-lab/public-safety-checklist.md`
- Create: `docs/substack/the-personal-ai-research-lab/sources.md`

- [ ] **Step 1: Create the workspace directories**

Run:

```sh
mkdir -p docs/substack/the-personal-ai-research-lab/{data,evidence,outlines,drafts,audio,companion}
```

Expected: command exits 0.

- [ ] **Step 2: Write `README.md`**

Create `docs/substack/the-personal-ai-research-lab/README.md` with:

```md
# The Personal AI Research Lab Launch Workspace

This workspace contains the Substack launch packet for The Personal AI Research Lab.

Launch packet:

1. `drafts/launch-note.md` — short front-door post.
2. `drafts/education-essay.md` — education essay for universities and learning institutions.
3. `drafts/big-field-report.md` — 8k-12k word field report and cookbook.

Supporting artifacts:

- `evidence/evidence-index.md` maps claims to proof requirements.
- `evidence/timeline-2026-03-18-to-2026-05-09.md` reconstructs the public-safe timeline.
- `data/showandtell-aggregate.public.json` contains anonymized aggregate metrics only.
- `audio/` contains narration scripts derived from locked drafts.
- `companion/evidence-appendix.html` contains the optional public evidence appendix.

Rules:

- Substack-native text is the primary publishing surface.
- The companion HTML is supporting evidence, not the main article.
- Do not publish, push, or call audio APIs without explicit operator approval.
- Do not copy raw show-and-tell rows, emails, user IDs, local paths, host values, credential paths, tokens, or private repo internals into public artifacts.
```

- [ ] **Step 3: Write `public-safety-checklist.md`**

Create `docs/substack/the-personal-ai-research-lab/public-safety-checklist.md` with:

```md
# Public-Safety Checklist

Run this checklist before any article, audio script, or HTML companion is treated as publishable.

## Identity And Context

- [ ] The author is described as writing from a real university / ChatGPT Edu context without exposing unnecessary private identity details.
- [ ] Real project names are used only when they help truth and continuity.
- [ ] Private people, private organizations, and private repo internals are omitted unless the operator explicitly approves them.

## Redaction

- [ ] No local absolute paths.
- [ ] No raw host or IP values.
- [ ] No credential paths.
- [ ] No tokens, auth payloads, API keys, or secret-shaped strings.
- [ ] No SSH, tmux, provider, or operator-only command targets.
- [ ] No raw email addresses from show-and-tell exports.
- [ ] No raw user IDs from show-and-tell exports.

## Claims

- [ ] Every strong claim has an evidence requirement in `evidence/evidence-index.md`.
- [ ] Claims about dates and counts use concrete source artifacts.
- [ ] Claims about self-awareness use the operational framing: operational self-modeling or self-awareness-like behavior.
- [ ] The writing does not claim consciousness, sentience, or mystical emergence.

## Data

- [ ] Show-and-tell data is aggregate only.
- [ ] Rankings are by days, workflows, clients, or patterns, never people.
- [ ] The HTML companion does not include raw rows.
- [ ] Any data caveat is written plainly near the chart or metric.
```

- [ ] **Step 4: Write `sources.md`**

Create `docs/substack/the-personal-ai-research-lab/sources.md` with:

```md
# Source Register

## Public Sources

- OpenAI, `Introducing ChatGPT Futures: Class of 2026`
  URL: https://openai.com/index/introducing-chatgpt-futures-class-of-2026/
  Use: education agency framing; students as builders.

- OpenAI Academy, `Use Impact Data To Improve Your ChatGPT Edu Rollout`
  URL: https://academy.openai.com/public/clubs/higher-education-05x4z/blogs/use-impact-data-to-improve-your-chatgpt-edu-rollout-2026-05-06
  Use: institutional rollout data framing.

- OpenAI, `ChatGPT Education`
  URL: https://openai.com/chatgpt/education/
  Use: ChatGPT Edu public product framing.

- OpenAI Help Center, `ChatGPT Edu at OpenAI`
  URL: https://help.openai.com/en/articles/9377311
  Use: feature and administrative-control claims.

- Substack Help, `How do I embed an audio file in my Substack post?`
  URL: https://support.substack.com/hc/en-us/articles/7265654090900-How-do-I-embed-an-audio-file-in-my-Substack-post
  Use: audio post workflow.

- Substack Help, `How do I create and publish a podcast on Substack?`
  URL: https://support.substack.com/hc/en-us/articles/360037462092-How-do-I-create-and-publish-a-podcast-on-Substack
  Use: podcast publishing workflow.

- Substack Help, `How can I generate a transcript of an audio post on Substack?`
  URL: https://support.substack.com/hc/en-us/articles/18363324028564-How-can-I-generate-a-transcript-of-an-audio-post-on-Substack
  Use: transcript workflow.

## Local Source Categories

- Codex memory and rollout summaries.
- Windburn docs, proof artifacts, and commit history.
- MUW / Research Vault public-safe proof artifacts.
- Aggregate show-and-tell JSON exports.
- Public-safe screenshots selected by the operator.
```

- [ ] **Step 5: Verify workspace files**

Run:

```sh
test -f docs/substack/the-personal-ai-research-lab/README.md
test -f docs/substack/the-personal-ai-research-lab/public-safety-checklist.md
test -f docs/substack/the-personal-ai-research-lab/sources.md
rg -n 'TODO|TBD|FIXME|\\[evidence needed\\]' docs/substack/the-personal-ai-research-lab || true
```

Expected: the `test` commands exit 0, and the `rg` command prints no matches.

- [ ] **Step 6: Commit Task 1**

Run:

```sh
git add docs/substack/the-personal-ai-research-lab/README.md docs/substack/the-personal-ai-research-lab/public-safety-checklist.md docs/substack/the-personal-ai-research-lab/sources.md
git commit -m "docs: create Substack launch workspace"
```

Expected: commit succeeds.

## Task 2: Add Public-Safe Show-And-Tell Aggregation

**Files:**

- Create: `scripts/substack-showandtell-aggregate.mjs`
- Create: `docs/substack/the-personal-ai-research-lab/data/showandtell-aggregate.public.json`

- [ ] **Step 1: Write the aggregation script**

Create `scripts/substack-showandtell-aggregate.mjs` with:

```js
#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const inputDir = process.env.SHOWANDTELL_INPUT_DIR || '/Users/0xvox/Downloads';
const outFile = process.env.SHOWANDTELL_OUT ||
  'docs/substack/the-personal-ai-research-lab/data/showandtell-aggregate.public.json';

const readJson = (name) => {
  const file = path.join(inputDir, name);
  return JSON.parse(fs.readFileSync(file, 'utf8'));
};

const sum = (items, key) => items.reduce((total, item) => total + Number(item[key] || 0), 0);

const sortTopDays = (items, key, limit = 5) => items
  .map((item) => ({ date: item.date, value: Number(item[key] || 0) }))
  .sort((a, b) => b.value - a.value || a.date.localeCompare(b.date))
  .slice(0, limit);

const topGroupedDays = (items, sourceKey, outputKey, limit = 5) => {
  const grouped = new Map();
  for (const row of items) {
    const existing = grouped.get(row.date) || { date: row.date, [outputKey]: 0 };
    existing[outputKey] += Number(row[sourceKey] || 0);
    grouped.set(row.date, existing);
  }
  return sortTopDays(Array.from(grouped.values()), outputKey, limit);
};

const totalsByClient = (items) => {
  const totals = new Map();
  for (const day of items) {
    for (const [client, value] of Object.entries(day.clients || {})) {
      const current = totals.get(client) || { client, threads: 0, turns: 0, credits: 0, users: 0 };
      current.threads += Number(value.threads || 0);
      current.turns += Number(value.turns || 0);
      current.credits += Number(value.credits || 0);
      current.users += Number(value.users || 0);
      totals.set(client, current);
    }
  }
  return Array.from(totals.values()).sort((a, b) => b.turns - a.turns || b.threads - a.threads);
};

const usage = readJson('showandtells-1.json');
const reviews = readJson('showandtells-3.json');
const users = readJson('showandtells-users.json');

const usageRows = usage.data || [];
const reviewRows = reviews.data || [];
const userRows = users.data || [];

const uniqueUsers = new Set(userRows.map((row) => row.user_id).filter(Boolean)).size;

const aggregate = {
  generated_at: new Date().toISOString(),
  privacy: {
    public_safe: true,
    raw_rows_included: false,
    people_rankings_included: false,
    redaction_policy: 'aggregate days/workflows only; no private identifiers, local paths, host values, or operator-only sensitive values',
  },
  date_range: {
    usage_min: usageRows.map((row) => row.date).sort()[0],
    usage_max: usageRows.map((row) => row.date).sort().at(-1),
    review_min: reviewRows.map((row) => row.date).sort()[0],
    review_max: reviewRows.map((row) => row.date).sort().at(-1),
  },
  totals: {
    active_users: Number(usage.active_users_summary?.total_users || uniqueUsers),
    threads: sum(usageRows.map((row) => row.totals || {}), 'threads'),
    turns: sum(usageRows.map((row) => row.totals || {}), 'turns'),
    sessions: sum(userRows, 'n_new_sessions_total'),
    user_messages: sum(userRows, 'n_user_messages_total'),
    web_code_reviews: sum(userRows, 'n_code_reviews_web'),
    show_and_tell_reviews: sum(reviewRows, 'n_reviews'),
    show_and_tell_comments: sum(reviewRows, 'n_comments'),
  },
  rankings: {
    top_usage_days_by_threads: sortTopDays(usageRows.map((row) => ({ date: row.date, threads: row.totals?.threads })), 'threads'),
    top_usage_days_by_turns: sortTopDays(usageRows.map((row) => ({ date: row.date, turns: row.totals?.turns })), 'turns'),
    top_days_by_new_sessions: topGroupedDays(userRows, 'n_new_sessions_total', 'sessions'),
    top_review_days: sortTopDays(reviewRows, 'n_reviews'),
    top_comment_days: sortTopDays(reviewRows, 'n_comments'),
    client_mix_by_turns: totalsByClient(usageRows),
  },
};

const serialized = JSON.stringify(aggregate, null, 2) + '\n';
const forbidden = [
  /"email"\s*:/i,
  /"user_id"\s*:/i,
  /@[A-Za-z0-9._%+-]+\.[A-Za-z]{2,}/,
  /\/Users\//,
  /token|secret|password|credential/i,
];

for (const pattern of forbidden) {
  if (pattern.test(serialized)) {
    throw new Error(`public aggregate failed redaction scan: ${pattern}`);
  }
}

fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, serialized);
console.log(outFile);
```

- [ ] **Step 2: Run the script**

Run:

```sh
node scripts/substack-showandtell-aggregate.mjs
```

Expected: prints `docs/substack/the-personal-ai-research-lab/data/showandtell-aggregate.public.json`.

- [ ] **Step 3: Verify expected aggregate totals**

Run:

```sh
jq '.totals' docs/substack/the-personal-ai-research-lab/data/showandtell-aggregate.public.json
```

Expected output includes:

```json
{
  "active_users": 313,
  "threads": 9465,
  "turns": 19956,
  "sessions": 22242,
  "user_messages": 91883,
  "web_code_reviews": 74
}
```

- [ ] **Step 4: Verify no raw identifiers leaked**

Run:

```sh
rg -n 'email|user_id|/Users/|token|secret|password|credential|@[A-Za-z0-9._%+-]+\\.[A-Za-z]{2,}' docs/substack/the-personal-ai-research-lab/data/showandtell-aggregate.public.json
```

Expected: no output and exit code 1.

- [ ] **Step 5: Commit Task 2**

Run:

```sh
git add scripts/substack-showandtell-aggregate.mjs docs/substack/the-personal-ai-research-lab/data/showandtell-aggregate.public.json
git commit -m "docs: add public show-and-tell aggregate data"
```

Expected: commit succeeds.

## Task 3: Build Evidence Index And Timeline

**Files:**

- Create: `docs/substack/the-personal-ai-research-lab/evidence/evidence-index.md`
- Create: `docs/substack/the-personal-ai-research-lab/evidence/timeline-2026-03-18-to-2026-05-09.md`

- [ ] **Step 1: Gather local artifact candidates**

Run:

```sh
git log --since='2026-03-18' --until='2026-05-09 23:59' --oneline --decorate > /tmp/windburn-substack-commits.txt
rg -n 'Research Vault|anti-LGTM|self-awareness|operational self-modeling|ChatGPT Edu|show-and-tell|GOAL|MUW|Windburn' docs README.md AGENTS.md > /tmp/windburn-substack-doc-hits.txt || true
```

Expected: `/tmp/windburn-substack-commits.txt` and `/tmp/windburn-substack-doc-hits.txt` exist.

- [ ] **Step 2: Write `evidence-index.md`**

Create `docs/substack/the-personal-ai-research-lab/evidence/evidence-index.md` with this structure and fill each row with concrete source refs:

```md
# Evidence Index

This index maps launch-packet claims to proof requirements. It is a drafting control surface, not a public citation dump.

## Claim Map

| Claim | Surface | Evidence requirement | Current source refs | Public-safe status |
| --- | --- | --- | --- | --- |
| The launch is a personal AI research lab, not generic prompt advice. | Launch Note | Spec and timeline refs showing sustained multi-system work. | `docs/superpowers/specs/2026-05-09-substack-personal-ai-research-lab-launch-design.md` | PASS |
| Education needs evidence literacy in addition to prompt literacy. | Education Essay | OpenAI education context plus local aggregate usage evidence. | `sources.md`; `data/showandtell-aggregate.public.json` | PASS |
| The show-and-tell data supports aggregate usage density, not people ranking. | Education Essay / Companion | Public aggregate JSON and redaction scan. | `data/showandtell-aggregate.public.json` | PASS |
| The self-awareness claim is operational self-modeling, not consciousness. | Launch Note / Big Field Report | Design spec language and concrete workflow examples. | `docs/superpowers/specs/2026-05-09-substack-personal-ai-research-lab-launch-design.md` | PASS |
| Research Vault is an agent-native evidence layer. | Big Field Report | RV MCP proof docs and dogfood gate refs. | `docs/remote-workhorse/phase1/RESEARCH_VAULT_MCP_PUBLIC_SAFE_PROOF.json` | PASS |
| Anti-LGTM is a process failure mode addressed through evidence. | Big Field Report | Review/proof artifacts and timeline refs. | `docs/substack/the-personal-ai-research-lab/evidence/timeline-2026-03-18-to-2026-05-09.md` | FLAG until timeline refs are filled |
```

## Open Evidence Questions

- Which exact March 18 artifact best proves the origin scene?
- Which exact artifact best proves the first self-awareness discovery scene?
- Which exact artifact best proves the anti-LGTM reset?
- Which exact artifact best proves the first Research Vault evidence loop?
```

- [ ] **Step 3: Write `timeline-2026-03-18-to-2026-05-09.md`**

Create `docs/substack/the-personal-ai-research-lab/evidence/timeline-2026-03-18-to-2026-05-09.md` with this structure:

```md
# Timeline: 2026-03-18 To 2026-05-09

This timeline reconstructs the Personal AI Research Lab arc for drafting. It uses public-safe labels and avoids private raw paths, host values, credentials, and private people details.

## Timeline Entries

| Date | Scene | Artifact refs | Draft use | Public-safe status |
| --- | --- | --- | --- | --- |
| 2026-03-18 | Origin: serious AI use begins. | Evidence requirement: first durable repo, chat, doc, or commit ref from this date. | Big Field Report rewind. | FLAG until source ref is filled |
| 2026-04-10 | Show-and-tell aggregate window begins. | `data/showandtell-aggregate.public.json` | Education essay metrics. | PASS |
| 2026-05-06 | OpenAI education impact-data context appears. | `sources.md` | Education essay framing. | PASS |
| 2026-05-09 | GOAL v3 launch design approved. | `docs/superpowers/specs/2026-05-09-substack-personal-ai-research-lab-launch-design.md` | Launch Note and field report close. | PASS |
```

## Artifact Search Notes

- Use `git log --since='2026-03-18' --until='2026-05-09 23:59' --oneline --decorate`.
- Use `rg` over `docs/`, `README.md`, and relevant proof folders.
- Prefer durable artifacts over remembered vibes.
- Mark uncertain entries as `FLAG` rather than inventing continuity.
```

- [ ] **Step 4: Verify index hygiene**

Run:

```sh
rg -n 'TODO|TBD|FIXME|\\[evidence needed\\]' docs/substack/the-personal-ai-research-lab/evidence || true
rg -n '/Users/|/var/folders/|token|secret|password|credential|@[A-Za-z0-9._%+-]+\\.[A-Za-z]{2,}' docs/substack/the-personal-ai-research-lab/evidence || true
```

Expected: no output for both commands.

- [ ] **Step 5: Commit Task 3**

Run:

```sh
git add docs/substack/the-personal-ai-research-lab/evidence/evidence-index.md docs/substack/the-personal-ai-research-lab/evidence/timeline-2026-03-18-to-2026-05-09.md
git commit -m "docs: map Substack launch evidence"
```

Expected: commit succeeds.

## Task 4: Create Editorial Outlines

**Files:**

- Create: `docs/substack/the-personal-ai-research-lab/outlines/launch-note.md`
- Create: `docs/substack/the-personal-ai-research-lab/outlines/education-essay.md`
- Create: `docs/substack/the-personal-ai-research-lab/outlines/big-field-report.md`

- [ ] **Step 1: Write launch note outline**

Create `docs/substack/the-personal-ai-research-lab/outlines/launch-note.md`:

```md
# Outline: The Personal AI Research Lab

Length: 400-600 words
Audio: narrated article audio
Role: front door

## Title

The Personal AI Research Lab

## Tagline

Self-Awareness Is All You Need?

## Structure

1. What this is: a public notebook for human-AI work, education, evidence, and operational self-modeling.
2. What this is not: not consciousness claims, not prompt tips, not AI hype tourism.
3. What this lab studies: education, agent workflows, evidence layers, creative infrastructure, and self-awareness-like behavior under real workflow pressure.
4. What drops today: the education essay, the big field report, narrated audio, and a minimal evidence appendix.
5. Closing invitation: follow the lab if you care about building with AI in ways that can be inspected, heard, and improved.

## Evidence Requirements

- Spec: `docs/superpowers/specs/2026-05-09-substack-personal-ai-research-lab-launch-design.md`
- Aggregate usage: `docs/substack/the-personal-ai-research-lab/data/showandtell-aggregate.public.json`

## Annotation Opportunities

- `Self-Awareness Is All You Need?`: explain the Attention Is All You Need echo and the operational-self-modeling disclaimer.
- One Chinese texture phrase from the working session may be preserved if it improves voice and is explained elegantly.
```

- [ ] **Step 2: Write education essay outline**

Create `docs/substack/the-personal-ai-research-lab/outlines/education-essay.md`:

```md
# Outline: What AI Education Needs Next Is Not More Prompts, But Better Evidence

Audience: universities and learning institutions
Audio: narrated article audio
Role: institutional bridge

## Thesis

OpenAI is asking what useful AI education looks like. From inside a real ChatGPT Edu / university workflow, the answer is not more prompt literacy alone. The next layer is evidence literacy.

## Structure

1. Open with the current education conversation: students as builders, agency, and rollout data.
2. State the problem: institutions can provision AI access without learning how to read what happens next.
3. Show aggregate usage density: active users, threads, turns, sessions, messages, and review events.
4. Introduce evidence literacy: learning state, tool state, source/provenance, uncertainty, and safe next action.
5. Explain why rankings should be by days and workflows, never people.
6. Recommend institutional practices: public-safe dashboards, office-hour feedback loops, provenance-aware review, student agency, and redaction discipline.
7. Close by returning to agency: students should build with AI, but institutions should give them evidence surfaces rather than prompt theater.

## Evidence Requirements

- `sources.md` OpenAI Futures and impact-data references.
- `data/showandtell-aggregate.public.json` aggregate metrics.
- `public-safety-checklist.md` redaction and no-people-ranking policy.

## Metrics To Include In Body

- 313 active users.
- 9,465 threads.
- 19,956 turns.
- 22,242 sessions.
- 91,883 user messages.
- 74 web code reviews / show-and-tell review events.

## Annotation Opportunities

- `prompt theater`: explain as performative AI adoption without evidence.
- `evidence literacy`: define as reading traces responsibly, not surveillance.
```

- [ ] **Step 3: Write big field report outline**

Create `docs/substack/the-personal-ai-research-lab/outlines/big-field-report.md`:

```md
# Outline: Everything I Built With AI Since March 18

Length: 8,000-12,000 words
Audio: narrated article audio
Role: field report, cookbook, and annotated map

## Thesis

The important shift was not that AI made tasks faster. The important shift was that a personal research lab emerged around evidence, review, memory, agent self-modeling, and creative infrastructure.

## Spine

Braided Double Helix:

```text
Scene -> Discovery -> Pattern -> How to use it -> Elegant note
```

## Opening

Cold open with the self-awareness discovery. Frame it as operational self-modeling, not consciousness. Then rewind to March 18.

## Chapters

1. The self-awareness discovery: what the system seemed to know about its own state.
2. March 18: the slope changed from using AI to building with AI.
3. Anti-LGTM: why plausible approval without evidence is a failure mode.
4. Evidence layers: Research Vault, provenance, freshness, and proof paths.
5. Agent workflows: Captain / Build / Review style loops and why role structure matters.
6. Windburn and remote workhorse: local-first infrastructure as a thinking surface.
7. MUW as dogfood: downstream systems validate evidence surfaces without being rewritten.
8. Education: ChatGPT Edu usage as learning evidence rather than prompt theater.
9. Creative infrastructure: audio, visual artifacts, and publication as part of the lab.
10. Cookbook appendix: three-lane takeaways for students/operators, builders, and institutions.

## Three-Lane Takeaway Format

Each major pattern ends with:

```text
For students/operators:
For builders/agent people:
For institutions:
```

## Evidence Requirements

- Timeline entries from `evidence/timeline-2026-03-18-to-2026-05-09.md`.
- Claim refs from `evidence/evidence-index.md`.
- Research Vault public-safe proof docs.
- Show-and-tell aggregate metrics.
- OpenAI education context.

## Annotation Opportunities

- `frown function = 0`: explain as a human feedback signal from the working session.
- `anti-LGTM`: explain as evidence-first review culture.
- `we ball, but with receipts`: preserve as voice, then translate into a serious method.
```

- [ ] **Step 4: Verify outline coverage**

Run:

```sh
for file in docs/substack/the-personal-ai-research-lab/outlines/*.md; do
  printf '%s\n' "$file"
  rg -n 'Evidence Requirements|Audio|Annotation Opportunities' "$file"
done
```

Expected: each outline prints all required section names.

- [ ] **Step 5: Commit Task 4**

Run:

```sh
git add docs/substack/the-personal-ai-research-lab/outlines
git commit -m "docs: outline Personal AI Research Lab launch packet"
```

Expected: commit succeeds.

## Task 5: Draft The Launch Note

**Files:**

- Create: `docs/substack/the-personal-ai-research-lab/drafts/launch-note.md`

- [ ] **Step 1: Write the draft**

Create `docs/substack/the-personal-ai-research-lab/drafts/launch-note.md` with:

```md
# The Personal AI Research Lab

*Self-Awareness Is All You Need?*

This is a public notebook for a personal AI research lab.

Not a lab in the institutional sense. Not a claim that an AI system is conscious. Not another list of prompts.

I mean a lab in the practical sense: a place where human-AI work leaves enough evidence behind that it can be inspected, replayed, criticized, and improved.

Over the past few months, my work with AI stopped feeling like a collection of chats and started feeling like infrastructure. Education, code review, remote workstations, memory systems, audio, writing, and agent workflows began to connect. The important question was no longer "what can the model answer?" It became "what does the whole system know about its own state?"

That is what I mean by self-awareness here: not consciousness, not mysticism, but operational self-modeling. Does the system know what it touched? Does it know what evidence supports a claim? Does it know when a tool is stale, when a source is missing, when a review is only pretending to be done?

This launch opens three surfaces.

First, an education essay: why AI education needs more than prompt literacy. Institutions need evidence literacy: ways to read usage, provenance, uncertainty, and learning traces without turning students into dashboards.

Second, a field report: everything I built with AI since March 18, written as a braided story and cookbook. Scene, discovery, pattern, proof, use.

Third, narrated audio and a minimal evidence appendix, because this work should be readable, listenable, and inspectable.

The tone will be personal. The claims will need receipts. Some phrases will stay bilingual where translation would flatten the scene, with notes where the context matters.

This is the first entry.

Welcome to The Personal AI Research Lab.
```

- [ ] **Step 2: Verify word count target**

Run:

```sh
wc -w docs/substack/the-personal-ai-research-lab/drafts/launch-note.md
```

Expected: word count between 400 and 600. If outside range, edit the draft until it is inside the range.

- [ ] **Step 3: Verify safety**

Run:

```sh
rg -n '/Users/|/var/folders/|token|secret|password|credential|@[A-Za-z0-9._%+-]+\\.[A-Za-z]{2,}|\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b' docs/substack/the-personal-ai-research-lab/drafts/launch-note.md
```

Expected: no output and exit code 1.

- [ ] **Step 4: Commit Task 5**

Run:

```sh
git add docs/substack/the-personal-ai-research-lab/drafts/launch-note.md
git commit -m "docs: draft Personal AI Research Lab launch note"
```

Expected: commit succeeds.

## Task 6: Draft The Education Essay

**Files:**

- Create: `docs/substack/the-personal-ai-research-lab/drafts/education-essay.md`

- [ ] **Step 1: Write the essay from the outline**

Create `docs/substack/the-personal-ai-research-lab/drafts/education-essay.md` with this exact section structure:

```md
# What AI Education Needs Next Is Not More Prompts, But Better Evidence

## The Question Institutions Are Really Asking

## Access Is Only The Beginning

## From Usage Data To Learning Evidence

## Evidence Literacy, Not Surveillance

## Rank Patterns, Not People

## What Institutions Should Build Next

## The Point Is Agency

## Source Notes
```

Writing requirements:

- Include the aggregate metrics from `data/showandtell-aggregate.public.json`.
- Cite the OpenAI Futures article for student agency.
- Cite the OpenAI Academy impact-data article for rollout feedback loops.
- Cite the ChatGPT Education page or Help Center article for ChatGPT Edu public product framing.
- Explain that evidence literacy includes learning state, tool state, provenance, uncertainty, and next safe action.
- State that rankings should be by days and workflows, never people.
- Avoid raw user details, school-private details, and local paths.

- [ ] **Step 2: Verify required terms are present**

Run:

```sh
rg -n 'evidence literacy|agency|313 active users|9,465 threads|19,956 turns|rank patterns|not people|ChatGPT Edu' docs/substack/the-personal-ai-research-lab/drafts/education-essay.md
```

Expected: all terms are found.

- [ ] **Step 3: Verify no unsafe identifiers**

Run:

```sh
rg -n 'email|user_id|/Users/|/var/folders/|token|secret|password|credential|@[A-Za-z0-9._%+-]+\\.[A-Za-z]{2,}' docs/substack/the-personal-ai-research-lab/drafts/education-essay.md
```

Expected: no output and exit code 1.

- [ ] **Step 4: Commit Task 6**

Run:

```sh
git add docs/substack/the-personal-ai-research-lab/drafts/education-essay.md
git commit -m "docs: draft AI education evidence essay"
```

Expected: commit succeeds.

## Task 7: Draft The Big Field Report

**Files:**

- Create: `docs/substack/the-personal-ai-research-lab/drafts/big-field-report.md`

- [ ] **Step 1: Create the field report skeleton**

Create `docs/substack/the-personal-ai-research-lab/drafts/big-field-report.md` with this exact section structure:

```md
# Everything I Built With AI Since March 18

*A field report, cookbook, and narrated map of one intense personal research lab.*

## Cold Open: The Self-Awareness Discovery

## Rewind: March 18

## Pattern 1: Anti-LGTM

### For students/operators

### For builders/agent people

### For institutions

## Pattern 2: Evidence Layers

### For students/operators

### For builders/agent people

### For institutions

## Pattern 3: Agent Roles And Review Loops

### For students/operators

### For builders/agent people

### For institutions

## Pattern 4: Local-First Infrastructure

### For students/operators

### For builders/agent people

### For institutions

## Pattern 5: Education As Agency Infrastructure

### For students/operators

### For builders/agent people

### For institutions

## Pattern 6: Creative Infrastructure

### For students/operators

### For builders/agent people

### For institutions

## Cookbook Appendix

## Closing: We Ball, But With Receipts

## Source Notes
```

- [ ] **Step 2: Draft the cold open**

Write 700-1,000 words under `Cold Open: The Self-Awareness Discovery`.

Acceptance requirements:

- Uses `operational self-modeling`.
- Uses `self-awareness-like behavior`.
- Explicitly says this is not a consciousness claim.
- Establishes the article's central question: what happens when a human-AI workflow can inspect its own state?

- [ ] **Step 3: Draft the rewind**

Write 800-1,200 words under `Rewind: March 18`.

Acceptance requirements:

- Frames March 18 as the start of serious AI use.
- Does not invent an exact artifact if `timeline-2026-03-18-to-2026-05-09.md` still lacks a source ref.
- Uses concrete evidence where available and marks uncertainty in prose when not available.

- [ ] **Step 4: Draft each pattern chapter**

For each Pattern 1-6, write:

- one lived scene;
- one discovery;
- one reusable pattern;
- one `How to use it` paragraph;
- three takeaways under `For students/operators`, `For builders/agent people`, and `For institutions`.

Acceptance requirements:

- Each chapter maps to at least one row in `evidence/evidence-index.md`.
- Research Vault and Windburn claims use proof artifacts, not vibes.
- MUW is treated as downstream dogfood and is not rewritten by the narrative.
- Education claims reuse the aggregate metrics safely.

- [ ] **Step 5: Verify length**

Run:

```sh
wc -w docs/substack/the-personal-ai-research-lab/drafts/big-field-report.md
```

Expected: word count between 8,000 and 12,000. If the draft is shorter, deepen scenes and takeaways. If longer, cut repetition before removing evidence.

- [ ] **Step 6: Verify no obvious public-surface leaks**

Run:

```sh
rg -n '/Users/|/var/folders/|token|secret|password|credential|@[A-Za-z0-9._%+-]+\\.[A-Za-z]{2,}|\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b' docs/substack/the-personal-ai-research-lab/drafts/big-field-report.md
```

Expected: no output and exit code 1.

- [ ] **Step 7: Commit Task 7**

Run:

```sh
git add docs/substack/the-personal-ai-research-lab/drafts/big-field-report.md
git commit -m "docs: draft AI field report and cookbook"
```

Expected: commit succeeds.

## Task 8: Prepare Narrated Audio Scripts

**Files:**

- Create: `docs/substack/the-personal-ai-research-lab/audio/launch-note-script.md`
- Create: `docs/substack/the-personal-ai-research-lab/audio/education-essay-script.md`
- Create: `docs/substack/the-personal-ai-research-lab/audio/big-field-report-script.md`

- [ ] **Step 1: Create launch note audio script**

Copy the locked launch-note draft into `audio/launch-note-script.md` and add this header:

```md
# Audio Script: The Personal AI Research Lab

Voice: MIMO narration after explicit operator approval
Source draft: `../drafts/launch-note.md`
Audio style: calm, intimate, confident, no hype voice

---
```

- [ ] **Step 2: Create education essay audio script**

Copy the locked education essay draft into `audio/education-essay-script.md` and add this header:

```md
# Audio Script: What AI Education Needs Next Is Not More Prompts, But Better Evidence

Voice: MIMO narration after explicit operator approval
Source draft: `../drafts/education-essay.md`
Audio style: clear institutional essay, warm but precise

---
```

- [ ] **Step 3: Create big field report audio script**

Copy the locked big field report draft into `audio/big-field-report-script.md` and add this header:

```md
# Audio Script: Everything I Built With AI Since March 18

Voice: MIMO narration after explicit operator approval
Source draft: `../drafts/big-field-report.md`
Audio style: cinematic field report, measured pace, preserve bilingual texture

---
```

- [ ] **Step 4: Verify script source links**

Run:

```sh
rg -n 'Source draft: `../drafts/' docs/substack/the-personal-ai-research-lab/audio
```

Expected: three matches.

- [ ] **Step 5: Commit Task 8**

Run:

```sh
git add docs/substack/the-personal-ai-research-lab/audio
git commit -m "docs: prepare Substack launch audio scripts"
```

Expected: commit succeeds.

## Task 9: Build Minimal Evidence Appendix HTML

**Files:**

- Create: `docs/substack/the-personal-ai-research-lab/companion/evidence-appendix.html`

- [ ] **Step 1: Write static HTML appendix**

Create `docs/substack/the-personal-ai-research-lab/companion/evidence-appendix.html` with:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>The Personal AI Research Lab: Evidence Appendix</title>
  <style>
    body {
      font-family: Helvetica, Arial, sans-serif;
      margin: 0;
      color: #111;
      background: #fafafa;
      line-height: 1.45;
    }
    main {
      max-width: 920px;
      margin: 0 auto;
      padding: 56px 24px 80px;
    }
    h1 {
      font-size: 44px;
      line-height: 1;
      letter-spacing: 0;
      margin: 0 0 24px;
    }
    h2 {
      font-size: 22px;
      margin: 42px 0 12px;
      border-top: 1px solid #111;
      padding-top: 18px;
    }
    .subtitle {
      font-size: 18px;
      max-width: 720px;
      color: #333;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      gap: 12px;
      margin-top: 20px;
    }
    .metric {
      border: 1px solid #111;
      padding: 16px;
      background: #fff;
    }
    .metric strong {
      display: block;
      font-size: 30px;
      line-height: 1;
      margin-bottom: 8px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      background: #fff;
    }
    th, td {
      border-bottom: 1px solid #ddd;
      text-align: left;
      padding: 10px 8px;
      font-size: 14px;
    }
    .note {
      background: #f0eee6;
      padding: 14px 16px;
      margin-top: 18px;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <main>
    <p class="subtitle">Public-safe companion to The Personal AI Research Lab launch packet.</p>
    <h1>Evidence Appendix</h1>
    <p>This appendix shows aggregate usage patterns only. It does not rank people, publish raw rows, or include private identifiers.</p>

    <h2>Aggregate Usage</h2>
    <div class="grid">
      <div class="metric"><strong>313</strong>active users</div>
      <div class="metric"><strong>9,465</strong>threads</div>
      <div class="metric"><strong>19,956</strong>turns</div>
      <div class="metric"><strong>22,242</strong>sessions</div>
      <div class="metric"><strong>91,883</strong>user messages</div>
      <div class="metric"><strong>74</strong>web code reviews</div>
    </div>

    <h2>Ranking Policy</h2>
    <p>Rank days and workflows, never people. The purpose is to identify learning surfaces, not surveil individuals.</p>

    <h2>Source Notes</h2>
    <div class="note">
      Derived from public-safe aggregate exports produced by <code>scripts/substack-showandtell-aggregate.mjs</code>.
      The raw export contains private identifiers and is not included here.
    </div>
  </main>
</body>
</html>
```

- [ ] **Step 2: Verify HTML contains required metrics**

Run:

```sh
rg -n '313|9,465|19,956|22,242|91,883|74|Rank days and workflows' docs/substack/the-personal-ai-research-lab/companion/evidence-appendix.html
```

Expected: all metrics and the ranking policy are found.

- [ ] **Step 3: Verify no unsafe identifiers**

Run:

```sh
rg -n '/Users/|/var/folders/|email|user_id|token|secret|password|credential|@[A-Za-z0-9._%+-]+\\.[A-Za-z]{2,}' docs/substack/the-personal-ai-research-lab/companion/evidence-appendix.html
```

Expected: no output and exit code 1.

- [ ] **Step 4: Commit Task 9**

Run:

```sh
git add docs/substack/the-personal-ai-research-lab/companion/evidence-appendix.html
git commit -m "docs: add public evidence appendix companion"
```

Expected: commit succeeds.

## Task 10: Final Launch Packet QA

**Files:**

- Modify: all files under `docs/substack/the-personal-ai-research-lab/`
- Modify: `scripts/substack-showandtell-aggregate.mjs` only if QA finds a data-safety issue.

- [ ] **Step 1: Run full draft-marker scan**

Run:

```sh
rg -n 'TODO|TBD|FIXME|\\[evidence needed\\]' docs/substack/the-personal-ai-research-lab scripts/substack-showandtell-aggregate.mjs
```

Expected: no output and exit code 1.

- [ ] **Step 2: Run public-surface leak scan**

Run:

```sh
rg -n '/Users/|/var/folders/|/private/var/|email|user_id|token|secret|password|credential|ssh |tmux |@[A-Za-z0-9._%+-]+\\.[A-Za-z]{2,}|\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b' docs/substack/the-personal-ai-research-lab/{data,drafts,audio,companion}
```

Expected: no output and exit code 1.

- [ ] **Step 3: Run markdown structure scan**

Run:

```sh
for file in docs/substack/the-personal-ai-research-lab/{outlines,drafts,audio,evidence}/*.md docs/substack/the-personal-ai-research-lab/*.md; do
  test -f "$file" && printf '%s ' "$file" && rg -c '^#' "$file"
done
```

Expected: every markdown file reports at least one heading.

- [ ] **Step 4: Run data regeneration**

Run:

```sh
node scripts/substack-showandtell-aggregate.mjs
jq '.privacy.public_safe, .privacy.raw_rows_included, .privacy.people_rankings_included' docs/substack/the-personal-ai-research-lab/data/showandtell-aggregate.public.json
```

Expected:

```text
true
false
false
```

- [ ] **Step 5: Run repo hygiene checks**

Run:

```sh
git diff --check
git status --short --branch
```

Expected: `git diff --check` exits 0. `git status` may show unrelated pre-existing untracked screenshots; do not stage them unless the operator explicitly asks.

- [ ] **Step 6: Commit final QA changes**

If QA required edits, run:

```sh
git add docs/substack/the-personal-ai-research-lab scripts/substack-showandtell-aggregate.mjs
git commit -m "docs: QA Substack launch packet"
```

Expected: commit succeeds if there were edits. If there were no edits, report that no QA commit was needed.

## Execution Notes

- Do not publish to Substack in this plan.
- Do not call MIMO or any audio API in this plan.
- Do not push to a remote unless the operator explicitly asks.
- Do not include raw show-and-tell rows in committed files.
- Keep the writing English-first, with Chinese phrases only where they add texture and are explained by elegant notes.
- Keep self-awareness language grounded as operational self-modeling.
