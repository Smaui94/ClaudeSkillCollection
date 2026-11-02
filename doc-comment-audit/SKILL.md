---
name: doc-comment-audit
description: Language-independent audit for missing, incomplete or outdated documentation comments (Doxygen, Javadoc, XML docs, Python docstrings, JSDoc/TSDoc, GoDoc, Rustdoc, GDScript ##). Reports undocumented public types and functions, parameters missing from the docs, and comments that contradict the signature or behavior. Use when asked to check/review/audit documentation comments, API docs or "is my code documented", in any language.
---

# Documentation comment audit

Review only: report findings, don't write or change comments unless the user explicitly asks. For a full style check of one language, point to the matching skill in this collection: `cpp-google-style`, `csharp-google-style`, `java-google-style`, `python-google-style`, `shell-google-style` (comments), `markdown-readme-google-style` (READMEs).

## Scope
Check the files/directories the user names, otherwise the whole repo. Default: the **public/exported API** (see table). On request ("all", "including private") check every declaration. Skip `.git/`, build output (`build/`, `dist/`, `out/`, `target/`, `bin/`, `obj/`), `vendor/`, `node_modules/`, `.venv/` and generated files (`*.g.cs`, `*.Designer.cs`, `*_pb2.py`, `*.generated.*`, headers like `DO NOT EDIT`). Tests are exempt unless asked.

## Doc syntax and "public" per language
| Language | Doc comment | Counts as public |
| --- | --- | --- |
| C / C++ | `/** */`, `///` (Doxygen: `@brief @param @return @throws`) | declared in headers; `public`/`protected` members |
| Java / Kotlin | `/** */` Javadoc/KDoc (`@param @return @throws`) | `public`, `protected` |
| C# | `///` XML (`<summary> <param> <returns> <exception>`) | `public`, `protected`, `protected internal` |
| Python | `"""docstring"""` (Google: `Args: Returns: Raises:`) | module, class, names without leading `_` |
| JS / TS | `/** */` JSDoc/TSDoc (`@param @returns @throws`) | `export`ed, `module.exports` |
| Go | `// Name ...` comment directly above | capitalized identifiers, package comment |
| Rust | `///`, `//!` | `pub` items |
| GDScript | `##` above the declaration | names without leading `_` |
| Shell | `#` block above the function (Description/Arguments/Returns) | all library functions |

## Steps
1. Detect the languages (file extensions) and check for an existing doc linter config; prefer running it if installed (never install it): `ruff --select D`, `eslint-plugin-jsdoc`, `javadoc -Xdoclint:all`, `dotnet build` with warning CS1591, Doxygen `WARN_IF_UNDOCUMENTED=YES`, `revive`/`golint` (exported), `cargo clippy -W missing_docs`. If none is available, say which one would help and continue manually.
2. List public declarations (grep for `public`, `export`, `def`/`class`, `pub fn`, `func [A-Z]`, `func ` in GDScript …) and check the lines directly above/below for a doc comment.
3. For documented declarations, compare the comment with the signature and the body.
4. Report (format below).

## Rules
- DC1 error: public type (class/struct/interface/enum/module) without doc comment
- DC2 error: public function/method/constructor without doc comment (`@Override`/`override` may inherit docs: `{@inheritDoc}`, `<inheritdoc/>`)
- DC3 error: parameter not documented, where the language convention documents parameters
- DC4 error: documented parameter that doesn't exist, or a different name/order than the signature (renamed or removed parameter)
- DC5 warning: non-void return not documented; or `@return` on a void function/constructor
- DC6 warning: declared/thrown exceptions not documented (`@throws`, `<exception>`, `Raises:`) where the convention requires it
- DC7 error: comment contradicts the code (wrong type, wrong unit, describes behavior that was removed, says "returns null" but throws) — always quote both lines
- DC8 warning: empty or placeholder doc (`TODO`, `Insert description here`, IDE stubs like `@param x the x`, `/// <summary></summary>`)
- DC9 info: comment only repeats the name (`/** Gets the name. */ getName()` is fine; `/** Process. */ process()` with complex logic is not enough)
- DC10 warning: missing file/module/package doc where the convention expects one (Python module docstring, Go package comment, Rust crate `//!`)
- DC11 info: inconsistent doc style in one project (mixed `///` and `/** */`, mixed languages in comments)

## False positives to drop
Trivial getters/setters and properties when the project explicitly allows it · generated code · private helpers in default (public) mode · overrides that inherit docs · test methods · `main` entry points with an obvious purpose (report as info at most).

## Report
In the user's language, grouped by file:
```
path/to/file:line - error|warning|info - <ID> <rule> - <why it is a problem> (<link to the convention>)
```
- Every finding has a concrete location; mark uncertain ones as "possible" (e.g. DC7 when behavior depends on code you couldn't see).
- Bulk hits with one root cause (e.g. a whole module undocumented): report once with count and 2-3 sample locations.
- End with a summary: documented vs. undocumented public declarations (count and %), findings per severity, then the 3 most important things to fix first.
- Do not change code. Apply fixes only when the user explicitly asks for it.
