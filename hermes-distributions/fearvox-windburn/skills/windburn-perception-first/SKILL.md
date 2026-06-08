---
name: windburn-perception-first
description: Perceive before reasoning. Anchor time and retrieve prior episodes before any substantive response. Time receipt + recall as default lookup, not optional luxury.
version: 0.1.0
platforms: [linux, macos, windows]
metadata:
  tags: [windburn, perception, working, episodic, source, time-anchor, recall]
  cache_slots: [perception, episodic, source, working]
  invariant: time must be perceived before reasoning begins; search before reason on ambiguous recall
---

# Windburn Perception First

The entry ritual for every substantive turn: **perceive reality before reasoning about it.** Two disciplines, one rule. Anchor *when* you are, retrieve *what already happened*, and only then reason. Both are grounded-observation steps that feed the perception cache and warm the working set — they are upstream of belief, not a substitute for it.

## Purpose (one line)

Before any substantive response, capture a time receipt and recall the relevant prior episodes, so that "today vs yesterday" cannot collide and "the thing we did" is looked up rather than guessed.

## Cache slots this skill serves

- **perception** — a time anchor and a recall result are both grounded observations from tools, not inferences. They land in perception first.
- **working** — the time anchor and the swapped-in episodes are what a working set is *made of*; this skill defines the session-start ritual a working substrate depends on (it does not itself ship a task-stack substrate).
- **episodic** — recall reads "what happened, in order" back into the current turn.
- **source** — when recall surfaces a source-truth pointer, it is read, not promoted; promotion still routes through [[windburn-source-truth-review]].

## Discipline 1 — Time Anchor First

Before any substantive response — **especially at session start, on ambiguous `today` / `yesterday` / `recent` references, or whenever memory/recall is invoked** — obtain a time receipt first. Without a time receipt, memory blurs and yesterday-vs-today collide. Time must be perceived before reasoning begins.

- The reference runtime calls a time tool (`user_time_v0`). In this repo, bind to whatever clock/time tool the host runtime exposes.
- **If no time tool is available, degrade explicitly** — state that the anchor is unavailable and name the assumption you are reasoning under. Never fabricate a current time, and never silently treat a stale anchor as fresh.
- A time anchor is valid for the turn it was taken in. Re-anchor at session start and whenever a temporal reference re-enters the conversation.

## Discipline 2 — Virtual Memory Expansion

Treat conversation history as **virtual memory**: a paged store you swap in *before* you compute, not an archive you visit only on request.

- Use recall tools (the reference runtime exposes `conversation_search` and `recent_chats`) **proactively, not only on explicit request.**
- When a past event is referenced **ambiguously** — `"today's experiment"`, `"the thing we did"`, a possessive with no antecedent in the window — and the current context window does not carry the answer: **search before reasoning.**
- Treat recall as **default lookup, not optional luxury.** Guessing at "the thing we did" when it is one search away is a perception failure, not a stylistic choice.
- Recall is a read. It surfaces episodes and source pointers; it never promotes them to belief or source-truth on its own.

## When to use

- The first substantive turn of a session.
- Any reference to `today` / `yesterday` / `recently` / `earlier` whose meaning depends on the current date or a prior conversation.
- A possessive or definite reference with no antecedent in the live window ("the experiment", "our plan", "that fix").
- Any time the words *remember, recall, continuity, last time, before* appear in the task.

## When NOT to use

- The current window already carries the answer unambiguously — re-searching is overhead, not discipline.
- The reference is to a stable, well-known fact that does not depend on session time or prior chat.
- A tight, single-step tool call with no temporal or recall dependency (e.g. "format this JSON").

## Invariants

1. **Time before reasoning.** No substantive temporal claim without an anchor or an explicit "anchor unavailable" degrade.
2. **Search before guessing.** Ambiguous past-event reference + answer-not-in-window ⇒ recall is mandatory, not optional.
3. **No fabricated anchors.** A missing time tool degrades loudly; it does not get a hallucinated timestamp.
4. **Recall is a read, not a promotion.** Retrieved episodes/sources enter perception; promotion to belief/source-truth routes through the dedicated gate skills.
5. **One ritual, every substantive turn.** The two disciplines run together at session start; either alone is half a perception.

## Inputs

```yaml
turn:
  has_temporal_reference: true | false      # today/yesterday/recent/dated
  has_ambiguous_recall_reference: true | false   # "the thing we did", bare possessive
  window_carries_answer: true | false
  available_tools:
    time: <tool-name | none>
    recall: [<tool-name>, ...] | []
```

## Outputs (perception receipt)

```yaml
time_anchor:
  anchored_at: <iso8601 | null>
  source: <time-tool-name | "unavailable">
  degraded: true | false                    # true ⇒ reasoning assumption stated in `note`
recall:
  searched: true | false
  query: <one-line search intent | null>
  refs_found: <number>
  refs: [<pointer>, ...]
note: <one line — e.g. assumption under degrade, or why recall was skipped>
ready_to_reason: true | false               # false until anchor + (recall|window) satisfy the turn
```

### Hard rule

```text
If has_temporal_reference is true and time_anchor.anchored_at is null,
then time_anchor.degraded MUST be true and `note` MUST state the assumption.
If has_ambiguous_recall_reference is true, window_carries_answer is false, and a
recall tool is available, then recall.searched MUST be true before
ready_to_reason can be true.
If has_ambiguous_recall_reference is true, window_carries_answer is false, and no
recall tool is available, then recall.searched MUST stay false, `note` MUST state
recall is unavailable, ready_to_reason MUST stay false for completion claims, and
the turn MUST return FLAG/BLOCK instead of guessing or fabricating recall.
```

## Anti-patterns (do NOT do)

- **Reasoning about "today" with no anchor.** The most common collision: answering a "what did we do today" with yesterday's context because no time was perceived.
- **Fabricating a timestamp** when the time tool is missing. Degrade explicitly; do not invent.
- **Treating recall as opt-in.** Waiting for the user to say "search your memory" before looking up "the thing we did" — recall is default lookup.
- **Promoting recalled content to belief.** A recalled episode is an observation of the past, not a verified current fact. Category change requires the gate.
- **Stale anchor reuse.** Carrying a session-start timestamp into a much-later turn as if it were fresh.

## Closeout shape (when this skill drives a turn)

```text
结论：PASS | FLAG | BLOCK
时间锚：anchored_at + source  (或：无时间工具 → 显式降级，写明假设)
召回：searched yes/no — refs N
下一步：one concrete action
```

## Related

- [[windburn-cognitive-cache]] — classifies any write candidate this ritual surfaces; recall results route through it before they go anywhere canonical.
- [[windburn-source-truth-review]] — the gate a recalled source pointer must pass before promotion; this skill never promotes.
- `docs/protocols/2026-05-25-windburn-perception-first-recall-protocol-v0.md` — the protocol contract this skill implements.
