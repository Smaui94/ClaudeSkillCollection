# ClaudeSkillCollection

A collection of [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills)
for **reviewing existing code**: style guides, documentation comments, naming,
complexity, dead code, TODOs, secrets, error handling, dependencies and tests.

## Important note

These skills are **review tools**, not a replacement for your own work. They help you
find convention violations and check code after the fact. They do not replace:

- writing clean, readable code yourself,
- understanding what your code does and why,
- taking responsibility for your own work.

If you only generate or automatically "fix" code without understanding it, you learn
nothing and cannot maintain the result. Use these skills to question your own work, not
to hand it off.

## Included skills

Not sure where to start? Use [`full-review`](full-review/SKILL.md): it detects
your project, picks the matching skills below and merges their results into one
prioritized report.

| Skill | Purpose |
| --- | --- |
| [`cpp-google-style`](cpp-google-style/SKILL.md) | Check C++ against the Google C++ Style Guide, including mandatory Doxygen comments. |
| [`csharp-google-style`](csharp-google-style/SKILL.md) | Check C# against the Google C# Style Guide, including mandatory XML documentation comments. Includes the helper script `scripts/check.sh`. |
| [`java-google-style`](java-google-style/SKILL.md) | Check Java against the Google Java Style Guide, including mandatory Javadoc. Includes helper scripts in `scripts/`. |
| [`markdown-readme-google-style`](markdown-readme-google-style/SKILL.md) | Check README and Markdown documentation against the Google README guidelines. |
| [`python-google-style`](python-google-style/SKILL.md) | Check Python against the Google Python Style Guide and PEP 8, including mandatory Google-style docstrings and type hints on public APIs. Includes the helper script `scripts/check.sh` (uses ruff/pylint if installed). |
| [`shell-google-style`](shell-google-style/SKILL.md) | Check shell scripts against the Google Shell Style Guide. Includes the helper script `scripts/check.sh` (uses shellcheck if installed). |
| [`doc-comment-audit`](doc-comment-audit/SKILL.md) | Find missing, incomplete or outdated documentation comments in any language. |
| [`naming-review`](naming-review/SKILL.md) | Check names for convention violations, meaningless or misleading names, unclear abbreviations and inconsistent terms. |
| [`complexity-check`](complexity-check/SKILL.md) | Find long functions, deep nesting, many parameters, high cyclomatic complexity, large classes and duplicated code. |
| [`dead-code-finder`](dead-code-finder/SKILL.md) | Find unused code, imports and files, unreachable and commented-out code, with a certainty level for each finding. |
| [`todo-audit`](todo-audit/SKILL.md) | List TODO/FIXME/HACK/XXX/BUG comments with age and author, and flag old, unclear or possibly resolved ones. Includes the helper script `scripts/todos.sh`. |
| [`secrets-scan`](secrets-scan/SKILL.md) | Find leaked passwords, API keys, tokens and private keys in code, config and git history; always masked. Includes the helper script `scripts/scan.sh` (uses gitleaks if installed). |
| [`error-handling-review`](error-handling-review/SKILL.md) | Find empty catch blocks, swallowed exceptions, ignored error codes, missing validation and unclosed resources. |
| [`dependency-audit`](dependency-audit/SKILL.md) | Check dependencies for known vulnerabilities, outdated or unpinned versions and missing lock files; never updates anything. Includes the helper script `scripts/audit.sh`. |
| [`test-coverage-review`](test-coverage-review/SKILL.md) | Find logic without tests, untested error paths and edge cases, and tests that can't fail. |
| [`review-without-fixing`](review-without-fixing/SKILL.md) | General code review that explains problems and asks guiding questions, but never gives the solution. |
| [`sql-review`](sql-review/SKILL.md) | Check SQL and database access code for injection, missing WHERE, N+1 queries, missing indexes and transactions, and risky migrations. |
| [`repo-hygiene`](repo-hygiene/SKILL.md) | Check the repository for missing .gitignore entries, committed artifacts and IDE files, large files, line endings and case conflicts. Includes the helper script `scripts/hygiene.sh`. |
| [`owasp-security-review`](owasp-security-review/SKILL.md) | Security review based on the OWASP Top 10: injection, XSS, access control, crypto, deserialization, SSRF and more, with attack scenarios but no exploit payloads. |
| [`concurrency-review`](concurrency-review/SKILL.md) | Find race conditions, deadlock risks, unsafe shared state, async/await mistakes and main-thread violations. |
| [`performance-review`](performance-review/SKILL.md) | Find real performance problems related to realistic input sizes, and recommend a profiler to confirm them. |
| [`api-design-review`](api-design-review/SKILL.md) | Check public APIs and REST endpoints for consistency, contracts, error behavior and breaking changes since the last release. |
| [`logging-review`](logging-review/SKILL.md) | Check logging for missing logs, noise, wrong levels, sensitive data and missing context. |
| [`accessibility-audit`](accessibility-audit/SKILL.md) | Static accessibility check of web and UI code against WCAG 2.2 AA. |
| [`architecture-review`](architecture-review/SKILL.md) | Find dependency cycles, layer violations and coupling problems between modules, with a dependency overview. Includes the helper script `scripts/deps.sh`. |
| [`privacy-review`](privacy-review/SKILL.md) | Technical GDPR review: inventory of personal data, deletion and export paths, third-party recipients, tracking before consent. Not legal advice. |
| [`config-review`](config-review/SKILL.md) | Check config files for syntax errors, duplicate keys, YAML pitfalls, differences between environment variants and insecure defaults. Includes the helper script `scripts/config.sh`. |
| [`regex-review`](regex-review/SKILL.md) | Check regular expressions for ReDoS risk, missing anchors, wrong character classes and unescaped user input. Includes the helper script `scripts/extract.sh`. |
| [`full-review`](full-review/SKILL.md) | Run a complete review: detects the project, selects the matching skills of this collection, and merges their findings into one prioritized report. Includes the helper script `scripts/discover.sh`. |

## Installation

Copy the skill folders you want to `~/.claude/skills/` (Windows:
`%USERPROFILE%\.claude\skills\`) to use them in all projects, or to `.claude/skills/`
inside a specific project:

```sh
cp -r java-google-style ~/.claude/skills/
```

Claude Code loads a skill automatically when its description matches the task, for
example "check this Java code against the Google Style Guide".

## Running skills on a project

`run-skills.sh` (Git Bash, Linux, macOS) and `run-skills.cmd` (Windows) run selected
skills from this folder on a project, without installing them first. Step-by-step
instructions: [USAGE.md](USAGE.md).

```sh
./run-skills.sh --list                                   # show all skills
./run-skills.sh secrets-scan,repo-hygiene ../my-project  # run two skills
./run-skills.sh -l Deutsch -o review.md full ../my-project
./run-skills.sh --scripts-only todo-audit,config-review ../my-project
```

```bat
run-skills.cmd secrets-scan,repo-hygiene ..\my-project
run-skills.cmd -l Deutsch -o review.md full ..\my-project
```

- **Default mode** starts Claude Code non-interactively (`claude -p`) in the project
  directory. Claude may only read files, run the skills' helper scripts and use
  read-only git commands; editing tools are disabled, so the project is not changed.
  Requires [Claude Code](https://docs.claude.com/en/docs/claude-code/overview).
- **`--scripts-only`** runs only the helper scripts of the selected skills, without
  Claude. Fast and free, but covers only the skills marked with `S` in `--list`.
  Requires bash (on Windows: Git Bash from [Git for Windows](https://git-scm.com)).
- Options: `-o FILE` (save the report), `-l LANG` (report language), `-m MODEL`,
  `-x TEXT` (extra instructions, e.g. a focus folder), `--dry-run` (show the command
  and prompt only). Skills can be separated by commas or spaces; `full` runs
  `full-review`.
- A report saved with `-o` starts with the full path of the scanned project
  (`<!-- run-skills:project=PATH -->`), which `fix-issues` uses.

## Fixing reported issues

`fix-issues.sh` and `fix-issues.cmd` give a saved report to Claude Code, which then
fixes the findings in the project. They read the project path from the report header,
or you pass the project directory after the report file.

```sh
./fix-issues.sh --dry-run report.md                      # show the prompt only
./fix-issues.sh -t "npm test" -o fixes.md report.md      # fix errors and warnings
./fix-issues.sh -s error -f "SC1,SC5" report.md ../my-project
```

- **This changes your code.** The script refuses to start if the project has
  uncommitted changes (except the report itself), so every fix can be reviewed with
  `git diff` and undone with `git restore .`. Use `--allow-dirty` to skip the check.
- Claude verifies each finding first, makes minimal changes, never commits, pushes or
  deletes files, and never prints secret values. Fixes that would change public APIs or
  behavior are listed as "needs decision" instead of being made.
- It ends with a summary: status per finding (fixed, skipped, needs decision, manual),
  a one-sentence explanation of each change, the changed files and the manual steps.
- Options: `-s error|warning|info` (minimum severity, default `warning`), `-f TEXT`
  (only these findings), `-t COMMAND` (test command Claude may run), `-o FILE`,
  `-l LANG`, `-m MODEL`, `-x TEXT`, `--allow-dirty`, `--dry-run`.

Read every change before you keep it. Letting Claude fix code you don't understand
defeats the purpose of this collection (see [Important note](#important-note)).
Step-by-step instructions: [USAGE.md, section 8](USAGE.md#8-repair-the-findings-of-a-report).

## License

See [LICENSE](LICENSE).
