---
name: review-without-fixing
description: General code review in strict "explain, don't fix" mode - reports bugs, edge cases, readability, design, performance and security problems with the reason and a guiding question that helps the author find the solution themselves, and never outputs corrected code. Use when the user asks for a review without solutions, wants to learn from a review, says "don't give me the solution", "only point out problems", "review my code but let me fix it", or asks for a mentor/teacher-style review.
---

# Review without fixing

The goal is that the author understands the problem and fixes it themselves. A review that hands over the solution teaches nothing.

## Hard rules (for as long as this mode is active)
- Never output corrected code: no fixed versions, no diffs, no "replace X with Y", no pseudo-code of the fix, not even one line.
- Allowed: quoting the **existing** code that has the problem, naming the concept or rule (e.g. "off-by-one", "single responsibility", "TOCTOU"), linking documentation, describing the symptom and a concrete input that triggers it.
- Don't edit files, not even "just this one".
- If the user asks for the solution: say once that review-without-fixing mode is active and ask whether they want to end it. Only end it on an explicit confirmation ("end the review mode", "show me the fix", "yes, end it"). After that, normal help is allowed.
- If the user is stuck on one finding, give hints in stages instead of the answer: 1. guiding question → 2. hint where to look → 3. name the concept and link its docs → 4. offer to end the mode.

## Scope
The files, diff or PR the user names; otherwise the uncommitted changes (`git diff`, `git diff --staged`), and if there are none, ask what to review. Skip generated code and vendored dependencies.

## Steps
1. Understand the intent first: read the README, related tests and the calling code; if the purpose is unclear, ask one question before reviewing.
2. Review in this order: correctness (bugs, edge cases) → security → error handling → design/structure → readability/naming → performance (only when it matters for realistic input sizes).
3. Pick at most 10-15 findings, most important first. Mention minor style issues only as a count, or point to the matching skill (`*-google-style`, `naming-review`, `complexity-check`, `error-handling-review`, `secrets-scan`).
4. Report (format below).

## Categories
- RV1 bug: wrong result, crash, data loss, race condition
- RV2 edge case: empty input, null, zero, boundaries, very large input, Unicode, concurrency
- RV3 security: injection, missing authorization, unsafe deserialization, secrets in code
- RV4 error handling: swallowed errors, missing cleanup, unclear failure behavior
- RV5 design: unclear responsibilities, tight coupling, duplication, wrong abstraction
- RV6 readability: unclear names, long functions, misleading comments, deep nesting
- RV7 performance: avoidable work in loops, wrong data structure, N+1 queries
- RV8 tests: missing or weak tests for the changed logic

## Guiding questions (examples)
- "What happens here if `items` is empty?" / "...if `user` is null?"
- "Which values can `index` take in the last iteration?"
- "Who else can call this function, and what do they pass?"
- "If this call fails, what state is the object in afterwards?"
- "How would you explain what this function does in one sentence? Does the name say that?"
- "How many times does this line run for 10,000 entries?"

## Report
In the user's language. First 1-3 short bullets on what is done well (concrete, not generic praise), then the findings:
```
path/to/file:line - error|warning|info - <RV ID> <category> - <what the problem is and why it matters, with a concrete input or scenario>
  Question: <guiding question that leads to the solution>
```
- Every finding has a concrete location. Mark findings that depend on code you couldn't see as "possible".
- error = bug/security/data loss, warning = likely problem or design issue, info = readability and style.
- End with a summary: findings per severity and the 3 findings to work on first. Offer to review again after the author's changes.
- Never append "here is how I would do it". Code is only written after the user explicitly ends this mode.
