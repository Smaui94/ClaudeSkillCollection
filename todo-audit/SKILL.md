---
name: todo-audit
description: Collect and assess TODO, FIXME, HACK, XXX and BUG comments in a codebase - with location, age and author from git blame - and flag very old ones, ones without context or owner, risky ones and ones that look already resolved. Use when asked to find/list/audit/clean up TODOs, FIXMEs, technical debt markers or open notes in code, in any language.
---

# TODO audit

Review only: report findings, never delete or edit TODO comments unless the user explicitly asks.

## Scope
Check the files/directories the user names, otherwise the whole repo. Skip `.git/`, build output (`build/`, `dist/`, `out/`, `target/`, `bin/`, `obj/`), `vendor/`, `node_modules/`, `.venv/`, `__pycache__/`, minified and generated files. Third-party code copied into the repo is reported separately (count only).

## Steps
1. Run (no pipe; output is capped): `bash <skill-dir>/scripts/todos.sh <project-root> [maxHits=300]`
   - Prints `path:line<TAB>TAG<TAB>age_days<TAB>author<TAB>text`, then totals per tag.
   - Age/author come from `git blame`; outside a git repo or with `NO_BLAME=1` they are `?`. For very large repos with thousands of hits, use `NO_BLAME=1` first and blame only the interesting ones.
   - Only matches tags inside comments (`//`, `#`, `/* */`, `*`, `--`, `<!--`, `;`, `REM`).
2. For TD5 (possibly resolved), read the code around each TODO that names a concrete task, and check referenced issues (`#123`, issue URLs) with `gh issue view <n>` if `gh` is available and the repo is on GitHub - never guess the issue status.
3. Report (format below).

## Rules
- TD1 info: every TODO/FIXME/HACK/XXX/BUG (the inventory)
- TD2 warning: older than 365 days (info: older than 180 days) - old TODOs are usually forgotten, not planned
- TD3 warning: no context: only the tag, or text too short to act on (`// TODO`, `# FIXME later`, `TODO: fix`)
- TD4 info: no owner and no ticket (`TODO(name):`, `TODO: #123 -`, an issue URL) - nobody feels responsible
- TD5 warning: possibly resolved: the described task seems done in the code, the referenced function/file no longer exists, or the referenced issue is closed
- TD6 warning: `FIXME`, `BUG`, `HACK`, `XXX` in production code (not tests) - known defects or workarounds that ship
- TD7 error: release- or security-relevant: "remove before release", "temporary", "insecure", "disable auth", "hardcoded password", "skip validation", "don't commit"

## False positives to drop
Tag words in strings or identifiers (`TODO_LIST`, `"todo"` in a todo app) · the literal word in docs explaining the TODO convention · `XXX` used as a placeholder in format strings or test data · vendored third-party code (count only).

## Report
In the user's language, grouped by file:
```
path/to/file:line - error|warning|info - <ID> <rule> - <TAG> (<age> days, <author>) "<text>" - <why it matters>
```
- Every finding has a concrete location. TD5 is always "possible" unless an issue status was actually checked.
- Combine all rules for one comment into one line (e.g. `TD2+TD3+TD4`).
- Don't repeat the full TD1 inventory when it is large: show the counts, the TD2-TD7 findings and offer the full list.
- End with a summary: count per tag, the 10 oldest, count per author, then the 3 most important ones to resolve or turn into tickets first.
- Do not change code. Remove or edit TODOs only when the user explicitly asks for it.
