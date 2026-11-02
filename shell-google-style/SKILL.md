---
name: shell-google-style
description: Audit shell scripts (.sh, .bash, files with a bash/sh shebang) against the Google Shell Style Guide (https://google.github.io/styleguide/shellguide.html) and report violations - quoting, [[ ]], $(...), error handling, function comments, main, naming. Use when asked to check/review/lint/audit Bash or shell scripts against Google style. Also apply these rules when writing or editing shell scripts.
---

# Google Shell Style Guide

Source: https://google.github.io/styleguide/shellguide.html

Audit: script first, read code only where needed. Review only: report findings, don't edit unless the user explicitly asks. If a project has its own shell conventions (`.editorconfig`, `.shellcheckrc`), report deviations from Google style once, then follow the project.

## Scope
Check the files/directories the user names, otherwise the whole repo: `*.sh`, `*.bash` and extensionless files with a `sh`/`bash` shebang. Skip `.git/`, `node_modules/`, `vendor/`, `build/`, `dist/`, `.venv/` and generated scripts (e.g. `configure`, `gradlew`, `mvnw`).

## Audit steps
1. Run (no pipe; output is capped): `bash <skill-dir>/scripts/check.sh <project-root> [hitsPerRule=8]`
   - Uses `shellcheck` if installed (rule statistics + samples), then grep/awk heuristics `## ID count SEV | desc` + samples `file:line:code`.
   - No shellcheck installed: the script says so. Tell the user that shellcheck (https://www.shellcheck.net) makes quoting and logic checks much more precise, then continue with heuristics and manual review. Never install anything yourself.
2. Spot-check samples, drop false positives (list below).
3. Review ★ rules manually in ≤5 representative scripts (longest, most used).
4. Report (format below). Fix order: correctness (quoting, error handling, eval) → structure → formatting.

## Rules (ID → script; ★ manual)
When to use shell
- ★ shell only for small utilities and wrappers; >100 lines or complex logic/data structures → recommend a structured language
- S16 executables start with `#!/bin/bash` (or `#!/usr/bin/env bash`) · ★ libraries end in `.sh` and are not executable; executables have `.sh` or no extension · ★ no SUID/SGID

Environment and errors
- S13 error messages go to STDERR (`echo "..." >&2` or an `err()` helper)
- S14 recommended (project rule, not in the Guide): `set -euo pipefail` or explicit error checks, so failures don't go unnoticed
- ★ check return values: `if ! mv "${a}" "${b}"; then ...`; check `PIPESTATUS` for pipelines when needed

Comments
- ★ file header comment describing the contents
- S17 every function except trivial ones has a comment with Description, `Globals:`, `Arguments:`, `Outputs:`, `Returns:` (all library functions, no exceptions)
- ★ TODO format: `# TODO(user): text`

Formatting
- S1 indent 2 spaces, no tabs (tabs only in `<<-` heredocs) · S2 ≤80 columns (except URLs, long string literals)
- ★ long pipelines: one segment per line, `|` at the start of the continuation line, indented 2
- S5 `; then` and `; do` on the same line as `if`/`for`/`while`
- ★ `case`: patterns indented 2, one-line actions ok, `;;` on its own line for multi-line actions
- ★ prefer `"${var}"` over `"$var"` (except single-char specials and positional parameters like `$1`, `$?`)

Features and bugs
- ★ quote everything that contains variables, command substitutions, spaces or metacharacters; use arrays for lists of arguments; `"$@"`, never `$*` (S8)
- S3 `$(command)`, never backticks · S4 `[[ ... ]]` instead of `[ ... ]` / `test`
- ★ string tests with `-z` / `-n`; `==` for equality inside `[[ ]]`; `(( ))` for numbers
- ★ wildcard expansion with explicit path: `rm -v ./*`, not `rm -v *`
- S7 no `eval` · S6 arithmetic with `(( ))` / `$(( ))`, not `let`, `expr`, `$[ ]`
- ★ no `cmd | while read`; use process substitution `< <(cmd)` or `readarray` (variables in a pipe subshell are lost)
- S9 don't parse `ls` output (use globs or `find -print0`) · ★ no aliases in scripts, use functions
- ★ prefer builtins over external commands (`${var//a/b}` over `sed` for simple cases)

Naming and structure
- ★ functions `lower_snake_case`, `::` for package separation; braces on the function line; `function` keyword optional but consistent
- ★ variables `lower_snake_case`; constants and exported variables `UPPER_SNAKE_CASE`, declared at the top with `readonly` / `declare -r`
- ★ `local` for function variables · S10 declare and assign separately when using command substitution (`local x; x="$(cmd)"`), otherwise `local` hides the exit code
- ★ all functions together after constants, no executable code between functions
- S12 scripts with at least one function have `main` and end with `main "$@"`

## False positives to drop
S1 tabs inside `<<-` heredocs · S2 long URLs or string literals · S3 backticks inside strings or comments · S4 single brackets in POSIX `#!/bin/sh` scripts that must stay portable (then report the shebang decision instead) · S12/S17 in sourced library files without executable code · S13 messages that are intentionally user output.

## Report
In the user's language, grouped by file:
```
path/to/script.sh:line - error|warning|info - <ID> <rule> - <why it is a problem> (https://google.github.io/styleguide/shellguide.html#<section>)
```
- Correctness rules (quoting, eval, errors) = error, structure/naming = warning, formatting = info, unless the script says otherwise.
- Every finding has a concrete location; mark uncertain ones as "possible".
- Bulk hits with one root cause: report once with count and 2-3 sample locations.
- End with a summary: findings per severity, then the 3 most important things to fix first.
- Do not change code. Apply fixes only when the user explicitly asks for it.
