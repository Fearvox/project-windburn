---
name: windburn-cognitive-cache
description: Classify agent memory into Windburn cognitive-cache objects and route writes safely.
version: 0.1.0
platforms: [linux, macos, windows]
metadata:
  tags: [windburn, memory, belief, perception, failure, source-truth]
---

# Windburn Cognitive Cache

Use this skill when a task mentions memory, belief, perception, source truth,
parking, failure, continuity, Research Vault, or `.learning`.

## Object Types

```text
perception        grounded observation from human/tool/repo/browser/API
belief            current hypothesis with evidence and scope
failure           attempted action plus predicted/actual mismatch
procedure         reusable action pattern or route
parking           plausible but insufficiently verified idea
source_proposal   candidate source-truth update requiring human approval
```

## Routing Rules

1. Source facts go in the source-facts section.
2. Codex/Hermes inference goes in the inference section.
3. A perception can support a belief, but it is not a belief by itself.
4. A belief can request promotion, but cannot approve itself.
5. A failure must include an avoid rule or retry condition.
6. Source truth requires explicit human approval.

## Write Decision

Return exactly one routing decision:

```yaml
route: perception | belief | failure | procedure | parking | source_proposal | reject
trust_level: ungrounded | partially_grounded | grounded
requires_human_review: true | false
evidence_count: number
reason: string
next_action: string
```

Hard rule:

```text
If route is source_proposal, requires_human_review must be true.
```

## Closeout Shape

```text
结论：PASS/FLAG/BLOCK.
写入建议：route + reason.
需要人审：yes/no.
下一步：one concrete action.
```
