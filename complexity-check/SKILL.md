---
name: complexity-check
description: Find overly complex code - long functions, deep nesting, many parameters, high cyclomatic complexity, large classes and files, duplicated code blocks - using documented, user-overridable thresholds, in any language. Reports hotspots and refactoring directions without rewriting code. Use when asked to check/review/analyze complexity, code smells, maintainability, long functions, duplication or "where is my code too complicated".
---

# Complexity check

Review only: report hotspots and name a refactoring direction, never rewrite code unless the user explicitly asks.

## Scope
Check the files/directories the user names, otherwise the whole repo. Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`, generated code, minified files, migrations and test fixtures/data files.

## Thresholds
Defaults below. The user can override any of them ("max function length 30", "nesting 2"); state the thresholds used at the top of the report.

| ID | Metric | warning | error |
| --- | --- | --- | --- |
| CX1 | function length (lines without blank lines and comments) | > 50 | > 100 |
| CX2 | nesting depth (blocks inside a function) | > 3 | > 5 |
| CX3 | parameters per function | > 5 | > 7 |
| CX4 | cyclomatic complexity per function | > 10 | > 20 |
| CX5 | file length (lines) | > 500 | > 1000 |
| CX6 | class size: methods / lines | > 20 / > 500 | > 40 / > 1000 |
| CX7 | duplicated block (≥ 10 similar lines) | 2 copies | ≥ 3 copies |
| CX8 | boolean condition with many operators (`&&`, `\|\|`, `and`, `or`) | > 3 | > 5 |
| CX9 | `if`/`else if` chain or `switch` cases | > 7 | > 15 |

Cyclomatic complexity, when counted by hand: 1 + one for each `if`, `elif`/`else if`, `for`, `while`, `case`, `catch`/`except`, `&&`/`and`, `||`/`or`, `?:`, and each comprehension condition.

## Steps
1. Prefer a metrics tool if installed (never install it; say which one would help if none is found):
   - `lizard` (many languages): `lizard -C 10 -L 50 -a 5 -w <dirs>` (excludes: `-x "./node_modules/*"`)
   - Python: `radon cc -s -n C <dir>`, `radon raw`; JS/TS: ESLint `complexity`, `max-depth`, `max-params`, `max-lines-per-function`
   - Duplication: `jscpd --min-lines 10 <dir>`, PMD CPD
2. Without tools: find the longest files (`wc -l`), then the longest functions in them, and measure CX1-CX4, CX8, CX9 by reading the code. Look for repeated blocks in files of the same kind for CX7.
3. Rank hotspots: functions that exceed several thresholds first, then by how central they are (many callers, often changed: `git log --format= --name-only | sort | uniq -c | sort -rn | head` when git is available).
4. Report (format below).

## Refactoring directions (name, don't implement)
- Long function → extract well-named steps; separate I/O from logic
- Deep nesting → guard clauses / early return, extract inner loop body
- Many parameters → parameter object, builder, or the function does too much
- High complexity / long `if` chains → lookup table, polymorphism, strategy, splitting by case
- Large class → split by responsibility (look at which fields each method uses)
- Duplication → shared function; only when the copies really change together
- Complex condition → named boolean variables or predicate functions

## False positives to drop
Generated code, data tables and long-but-flat configuration code (e.g. a `switch` mapping enum values to strings, CX9 info at most) · test files with many similar cases (CX7) · parsers/state machines where one big `switch` is the clearest form (report as info with a note).

## Report
In the user's language. First the thresholds used, then hotspots ranked worst-first:
```
path/to/file:line - error|warning|info - <ID> <metric> - `functionName`: <value> (threshold <limit>) - <why it hurts here> - direction: <refactoring direction>
```
- Every finding has a concrete location and measured value. Mark estimated values (counted by hand) as "approx.".
- Group several metrics of one function into one finding.
- End with a summary: findings per severity, top 5 hotspots, then the 3 most important things to tackle first.
- Do not change code. Refactor only when the user explicitly asks for it.
