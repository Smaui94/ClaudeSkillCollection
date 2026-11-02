---
name: repo-hygiene
description: Check repository health - missing or incomplete .gitignore for the detected languages, committed build artifacts, binaries, IDE and OS files, large files (Git LFS candidates), missing LICENSE/README, mixed line endings without .gitattributes, executable bits, case-only filename conflicts, misplaced .gitkeep files and optionally stale branches. Use when asked to check/clean up/audit a repository, .gitignore, committed junk files, repo structure hygiene, or before publishing a repo.
---

# Repository hygiene

Review only: report findings and suggest commands as text, never delete, untrack, move or rewrite anything unless the user explicitly asks.

## Scope
The git repository the user names, otherwise the current one. Uses tracked files (`git ls-files`) as the source of truth. Outside a git repository, only RH5 can be checked; say so.

## Steps
1. Run (no pipe; output is capped): `bash <skill-dir>/scripts/hygiene.sh <repo-root> [hitsPerRule=8]`
   - Prints `## ID count SEV | desc` + samples. `LARGE_KB=<n>` changes the large-file limit (default 5120 KB), `BRANCHES=1` adds RH11.
2. Verify samples: is a "committed artifact" really generated (e.g. `bin/` can hold real scripts)? Is a large file intended (e.g. a test asset)?
3. README content is out of scope here - point to `markdown-readme-google-style`. Secrets in files - point to `secrets-scan`.
4. Report (format below), with the commands the user could run.

## Rules
- RH1 error: no `.gitignore`; warning: `.gitignore` misses entries for detected languages/tools (`node_modules/`, `__pycache__/`, `.venv/`, `target/`, `bin/`/`obj/`, `build/`, `.godot/`, Unity `Library/`, `.env`, OS/IDE files)
- RH2 warning: committed build output or dependencies (`node_modules/`, `__pycache__/`, `bin/`, `obj/`, `target/`, `.godot/`, `*.pyc`, `*.class`, `*.o`, `*.exe`, `*.dll`, `*.jar` …) - "possible" when the folder may be intentional
- RH3 warning: committed IDE/OS files (`.idea/`, `.vs/`, `.DS_Store`, `Thumbs.db`, `desktop.ini`, `*.suo`, `*.user`, `*.swp`); info: `.vscode/` (shared settings can be intentional)
- RH4 warning: large file above the limit - candidate for Git LFS or for not being in the repo at all
- RH5 warning: no `LICENSE`/`COPYING` (public repos without a license are not open source) or no `README` at the root
- RH6 warning: mixed line endings without `.gitattributes`; error: shell scripts with CRLF line endings (break with `$'\r': command not found`)
- RH7 info: scripts without the executable bit in git, or non-scripts with it (on Windows `core.filemode` is often off, so all bits look the same - mention it)
- RH8 error: paths that differ only in case (break checkouts on Windows/macOS)
- RH9 info: `.gitkeep` in a directory that has other tracked files
- RH10 info: empty tracked files (except `__init__.py`, `py.typed`, `.gitkeep`)
- RH11 info (only with `BRANCHES=1`): local branches without commits for 180+ days, or already merged

## Commands to suggest (as text, never run them)
- Untrack but keep locally: `git rm -r --cached <path>` after adding it to `.gitignore`
- Templates: https://github.com/github/gitignore
- Line endings: a `.gitattributes` with `* text=auto` and `*.sh text eol=lf`, then `git add --renormalize .`
- Executable bit: `git update-index --chmod=+x <file>`
- Large files: `git lfs track "<pattern>"`; removing them from history needs `git filter-repo` and is disruptive - explain, don't run
- Case conflict: `git mv` via a temporary name

## False positives to drop
`bin/` with hand-written scripts (Node/Ruby/shell projects) · vendored binaries that are intentionally committed (document them) · `dist/` in libraries that publish from git · large test fixtures the project needs · `.vscode/` with shared `settings.json`/`extensions.json`.

## Report
In the user's language, grouped by rule:
```
path - error|warning|info - <ID> <rule> - <why it is a problem> - suggestion: <command or change>
```
- Every finding has a concrete path (or `.gitignore` / repo root). Mark uncertain ones as "possible".
- Bulk hits (e.g. 2,000 files in `node_modules/`): report once with count and the folder.
- End with a summary: findings per severity, then the 3 most important cleanups first.
- Do not change anything. Apply changes only when the user explicitly asks for it.
