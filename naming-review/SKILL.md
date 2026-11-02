---
name: naming-review
description: Review names in code for consistency and clarity - language naming conventions (camelCase/snake_case/PascalCase), meaningless names (data, tmp, foo), misleading names (isX that isn't a bool, getX with side effects), unclear abbreviations, synonyms for the same concept and mixed naming schemes. Suggests better names but never renames anything. Use when asked to review/check naming, variable names, identifiers or "are my names good", in any language.
---

# Naming review

Review only: report findings with a suggested name, never rename anything unless the user explicitly asks. Renaming public API breaks callers; say so whenever a finding concerns a public/exported name.

## Scope
Check the files/directories the user names, otherwise the whole repo. Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`, generated code, and names dictated by external APIs, frameworks, file formats or databases (e.g. JSON fields, ORM columns, overridden methods) - report those only as info if they leak deep into the code.

## Steps
1. Detect languages and any naming config (`.editorconfig` naming rules, Checkstyle, ESLint `naming-convention`, ruff `N`, pylint, clang-tidy `readability-identifier-naming`). The project config wins over language defaults.
2. Build a short glossary of the domain terms used in the code (types, modules, comments, README). Use it to find synonyms (NM5) and misleading names (NM3).
3. Go through declarations (types, functions, parameters, fields, constants, files) and the most-used local variables.
4. Report (format below).

## Language conventions (defaults when the project has none)
| Language | Types | Functions/methods | Variables/params | Constants |
| --- | --- | --- | --- | --- |
| Java, Kotlin | `PascalCase` | `camelCase` | `camelCase` | `UPPER_SNAKE` |
| C# | `PascalCase` (interfaces `IName`) | `PascalCase` | `camelCase`, private fields `_camelCase` | `PascalCase` |
| C++ (Google) | `PascalCase` | `PascalCase` | `snake_case`, members `snake_case_` | `kPascalCase` |
| Python | `PascalCase` | `snake_case` | `snake_case` | `UPPER_SNAKE` |
| JS / TS | `PascalCase` | `camelCase` | `camelCase` | `UPPER_SNAKE` or `camelCase` |
| Go | `PascalCase` exported, `camelCase` internal | same | short `camelCase` | `PascalCase`/`camelCase` |
| Rust | `PascalCase` | `snake_case` | `snake_case` | `UPPER_SNAKE` |
| GDScript | `PascalCase` | `snake_case` | `snake_case` | `UPPER_SNAKE` |
| Shell | – | `snake_case` | `snake_case` | `UPPER_SNAKE` |

## Rules
- NM1 warning: violates the language/project convention (table above)
- NM2 warning: meaningless name: `data`, `info`, `obj`, `thing`, `stuff`, `tmp`, `temp`, `val`, `foo`, `bar`, `test1`, `result2`, `doIt`, `handle`, `process`, `manager`/`helper`/`util` classes with mixed responsibilities; single letters outside short loops/lambdas (`i`, `j`, `k`, `x`/`y` for coordinates, `e` for exceptions are fine)
- NM3 error: misleading name:
  - `is`/`has`/`can`/`should` prefix on something that isn't a boolean
  - `get`/`find`/`calculate` that changes state, does I/O or is expensive without saying so
  - singular name for a collection, plural for a single item; `list`/`array` in the name of a set/map
  - name describes something other than what the code does (`validateUser` that also saves it)
  - wrong unit or missing unit (`timeout = 30` - seconds or ms? → `timeoutSeconds`)
- NM4 warning: unclear abbreviation (`calcTtlAmt`, `usrMgr`, `cfgPrsr`); common ones are fine (`id`, `url`, `http`, `db`, `io`, `min`/`max`, `config`, `args`)
- NM5 warning: several names for the same concept (`fetchUser` / `getCustomer` / `loadClient` for one entity; `remove`/`delete` mixed) or one name for different concepts
- NM6 info: mixed naming schemes in one project or file (`snake_case` and `camelCase` functions side by side)
- NM7 warning: type or scope encoded in the name (Hungarian `strName`, `iCount`, `m_` in languages that don't use it, `IFoo` outside C#/TS conventions, `fooList` when the type already says it)
- NM8 warning: negated booleans (`isNotEnabled`, `disableLogging = false`) - double negations in conditions
- NM9 info: name length doesn't fit the scope (long-lived global named `t`; local loop index named `currentIterationIndexCounter`)
- NM10 warning: shadows a builtin or an outer name (`list`, `id`, `str`, `type`, `input` in Python; `name`/`event` globals in JS; parameter hiding a field without `this.`)
- NM11 info: file/module name doesn't match its main content (`utils.py` with only date logic → `date_utils.py`)

## Report
In the user's language, grouped by file:
```
path/to/file:line - error|warning|info - <ID> <rule> - `oldName` → `suggestedName` - <why it is a problem>
```
- Every finding has a concrete location and a concrete suggestion. Mark uncertain ones as "possible" (e.g. NM3 when you can't see all usages).
- Mark public/exported names with "(public API - renaming breaks callers)".
- Bulk hits with one root cause (e.g. a whole module in the wrong case style): report once with count and 2-3 samples.
- NM5 findings: list all variants found with locations and propose one term for the glossary.
- End with a summary: findings per severity, the proposed glossary of domain terms, then the 3 most important things to fix first.
- Do not change code. Apply renames only when the user explicitly asks for it.
