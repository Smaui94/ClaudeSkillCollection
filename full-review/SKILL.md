---
name: full-review
description: Complete code review that orchestrates the other review skills of this collection - discovers the available skills automatically, detects the project's languages, frameworks and features, proposes a plan (quick, standard or thorough, or a focus like security, before release or for learning), runs the selected skills on the same scope, removes duplicate findings and produces one prioritized report. Use when asked for a full/complete/overall review, audit or health check of a project or codebase, "check everything", "where should I start", or when it is unclear which review skill fits.
---

# Full review

Orchestrator for the review skills in this collection. Review only, like every skill it runs: never change code unless the user explicitly asks, and then fix only the findings the user selects.

## Step 1: discover skills and project
Run (no pipe): `bash <skill-dir>/scripts/discover.sh <project-root>`
- `## skills`: every sibling skill (`<skill-dir>/../*/SKILL.md`) with name, whether it has helper scripts, and its description. This list is the source of truth - newly added skills are used automatically; never rely on a hard-coded list alone. Ignore this skill itself.
- `## project`: languages (file counts per extension), manifests and frameworks, UI files, SQL/migrations, config files, concurrency hints, HTTP routes/API specs, tests, shell scripts, git state, last tag.

## Step 2: plan
Match skills to the project using their descriptions and the project facts. A skill is relevant only if the project contains what it reviews (e.g. `accessibility-audit` needs UI code, `sql-review` needs SQL or database access, a `*-style` skill needs its language).

Depths:
- **quick**: `secrets-scan`, `repo-hygiene`, the style skills for the main languages, `error-handling-review`
- **standard** (default): every relevant skill
- **thorough**: every relevant skill, with manual sampling of more files per skill (≈ 10-15 instead of ≈ 5) and git history for `secrets-scan`

Focus (when the user names one, select by it instead of depth):
- **security**: `secrets-scan`, `owasp-security-review`, `sql-review`, `dependency-audit`, `config-review`, `privacy-review`, `regex-review`, `error-handling-review`, `logging-review`
- **before release / publishing**: `secrets-scan`, `repo-hygiene`, `dependency-audit`, `config-review`, `todo-audit`, `api-design-review`, `markdown-readme-google-style`
- **maintainability**: style skills, `naming-review`, `complexity-check`, `dead-code-finder`, `doc-comment-audit`, `architecture-review`, `test-coverage-review`
- **for learning**: relevant skills, but the output follows the `review-without-fixing` rules (problems with guiding questions, no solutions)

Show the plan before running anything:
```
Depth/focus: <...>   Scope: <paths>   Project: <languages, frameworks>
Run:  <skill> - <why it applies>
Skip: <skill> - <why not>
```
Ask for confirmation, unless the user already said to run it directly. On a large repo (thousands of files), propose a scope (main source folders) and say which parts will be sampled.

## Step 3: run
Run the selected skills one after another on the same scope by reading and following each one's `SKILL.md` (`<skill-dir>/../<name>/SKILL.md`), including its helper scripts. Keep each skill's rule IDs and severities. Order: fast script-based skills first (`secrets-scan`, `repo-hygiene`, `todo-audit`, `dependency-audit`, `config-review`, style skills), then the reading-heavy reviews. Don't let one skill's report replace another's checks - but don't repeat the same finding either.

## Step 4: merge
- Duplicates: same location and same cause reported by several skills → keep one finding and list all IDs (e.g. `EH1 / LG8`).
- Same root cause in many places (e.g. no `.gitignore`, formatter not configured) → one finding with count and samples.
- Keep "possible" markers from the source skills.

## Report
In the user's language:
1. Project overview: languages, frameworks, size, scope reviewed, what was sampled.
2. Table: skill → error / warning / info counts (skipped skills listed with the reason).
3. **Top 10 findings across all skills**, ranked by impact: security and data loss first, then correctness bugs, then maintainability, then style:
```
path/to/file:line - error|warning|info - <skill ID(s)> <rule> - <why it matters> - direction: <what should be true afterwards>
```
4. Per-skill details (or, for long reports, the per-skill sections condensed with a pointer that details are available on request).
5. Next steps: the 3 things to do first, and which skills to re-run after fixing.

Do not change code. Apply fixes only when the user explicitly asks for it, and only for the findings the user selects.
