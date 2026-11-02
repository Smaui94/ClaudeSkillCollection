---
name: dead-code-finder
description: Find dead code - unused functions, classes, variables, parameters and imports, unreachable code, commented-out code blocks and unused files - while accounting for reflection, public APIs, entry points and framework callbacks, which are reported as "possible" instead of "certain". Use when asked to find dead/unused/unreachable code, unused imports, leftover code or "what can I delete", in any language.
---

# Dead code finder

Review only: report candidates with a certainty level, never delete anything unless the user explicitly asks. Deleting code that is used dynamically breaks things at runtime, so certainty matters more than count.

## Scope
Check the files/directories the user names, otherwise the whole repo. Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`, generated code. Always search for references across the **whole repo**, including non-code files (configs, templates, build files, docs), even when only a subdirectory is checked.

## Steps
1. Prefer existing tools if installed (never install them; say which one would help if none is found):
   - Python: `vulture <dir> --min-confidence 80`, `ruff check --select F401,F841`
   - JS/TS: `knip`, `ts-prune`, ESLint `no-unused-vars`, `tsc --noUnusedLocals --noUnusedParameters`
   - Java/Kotlin: IDE inspections, PMD `UnusedPrivateMethod`; C#: analyzers IDE0051, IDE0052, IDE0060, CS0168
   - C/C++: `-Wall -Wextra -Wunused`, `cppcheck --enable=unusedFunction`; Go: `staticcheck` (U1000), `deadcode`; Rust: compiler `dead_code` warnings
2. For each candidate, grep its name across the repo (also as a string, e.g. `"methodName"`, `'ClassName'`) and check the exception list below before deciding the certainty.
3. Look for commented-out code (DD6) and unused files (DD7) separately: files that no other file imports/includes and that are no entry point.
4. Report (format below).

## Rules
- DD1 unused import/include/using
- DD2 unused local variable or parameter (parameters required by an interface/callback signature are fine)
- DD3 unused private/internal function, method, field, class or constant
- DD4 unused public/exported symbol - always "possible": external users may exist
- DD5 unreachable code: after `return`/`throw`/`break`/`continue`/`exit`, `if (false)`, conditions that are always true/false, `catch` for exceptions that can't be thrown
- DD6 commented-out code: blocks of ≥ 3 lines that are code, not explanation (git history keeps old code)
- DD7 unused file/module/asset: not imported, referenced or loaded anywhere and not an entry point
- DD8 obsolete feature flag / config option: always on or off, or the branch it guards is gone
- DD9 unused dependency → refer to the `dependency-audit` skill

## Certainty
- **certain**: private/local scope, no reference anywhere in the repo (code, strings, configs, templates), not on the exception list. Severity warning (DD5, DD6: warning; DD1, DD2: info).
- **possible**: anything on the exception list, any public/exported symbol, or a name that also appears as a string. Severity info.

Exceptions (never "certain"):
- Entry points: `main`, CLI commands, `__main__`, `package.json` `main`/`bin`/`exports`, `__all__`, `setup.py`/`pyproject` entry points, `Program.cs`, scripts referenced in CI/Makefiles/Dockerfiles
- Framework callbacks and conventions: Unity (`Start`, `Update`, `OnTriggerEnter` …), Godot (`_ready`, `_process`, `_on_*` signal handlers connected in `.tscn`), Android/iOS lifecycle, JUnit/pytest/NUnit tests and fixtures, Spring/ASP.NET/Flask/Django routes and beans, `__dunder__` methods, `toString`/`equals`/`hashCode`, serialization hooks
- Dynamic use: reflection, dependency injection, `getattr`/`importlib`/`eval`, `Class.forName`, string-based event or message names, templates and bindings (HTML, XAML, Razor, Vue/Svelte templates)
- C/C++: symbols exported from a library, macros, code inside `#if`/`#ifdef` for other platforms or configurations
- Public library APIs and interface implementations

## Report
In the user's language, grouped by file:
```
path/to/file:line - warning|info - <ID> <rule> - `name` - certain|possible - <evidence: "no reference found in repo" / "only referenced in comment" / reason it might still be used>
```
- Every finding has a concrete location and evidence. Never claim "certain" without having searched the whole repo.
- Bulk hits (e.g. 40 unused imports): report once with count and 2-3 samples, suggest the tool/IDE action that removes them safely.
- End with a summary: findings per rule split into certain/possible, estimated removable lines, then the 3 safest cleanups to do first.
- Do not change code. Delete code only when the user explicitly asks for it, and then only "certain" findings unless told otherwise.
