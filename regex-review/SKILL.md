---
name: regex-review
description: Review regular expressions in code and config in any language - ReDoS risk through catastrophic backtracking, missing anchors, unescaped dots, wrong character ranges like [A-z], overmatching greedy .*, flag and Unicode pitfalls, user input inserted without escaping, regex compiled in loops, regex used where a parser is needed, unreadable patterns and dialect differences - explaining in words what each risky pattern matches. Use when asked to check/review/audit regex, regular expressions, patterns, validation regexes, ReDoS or "is my regex correct".
---

# Regex review

Review only: report findings, never change patterns unless the user explicitly asks. For each risky pattern, explain in plain words what it matches and give one short example input that it wrongly accepts or rejects. For ReDoS, describe the input class (e.g. "a long run of `a` followed by a character that doesn't match") instead of crafting inputs meant to hang a real system.

## Scope
Check the files/directories the user names, otherwise the whole repo: regex literals and patterns passed to regex APIs in code, validation patterns in configs and schemas (`pattern:` in JSON Schema/OpenAPI, routing rules), shell scripts (`grep -E/-P`, `sed -E`, `[[ =~ ]]`). Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`, minified and generated code.

## Steps
1. Run (no pipe; output is capped): `bash <skill-dir>/scripts/extract.sh <project-root> [maxHits=30]`
   - Lists regex usages per language with `file:line: code`, then heuristic flags: nested quantifiers (RX1, possible ReDoS), `[A-z]`/`|` inside character classes (RX4), patterns built from variables (RX11).
   - Heuristics only - read each pattern in context.
2. For every pattern: find where its input comes from (user input, file, constant) - this decides the RX1 severity - and whether it is meant to match the whole string (RX2).
3. Check the engine (table): linear-time engines (Go `regexp`, Rust `regex`, RE2) can't have catastrophic backtracking.
4. Use a tool if installed (never install; mention if helpful): `eslint-plugin-regexp`, `eslint-plugin-security` (`detect-unsafe-regex`), `semgrep` ReDoS rules, `recheck`/`regexploit` for ReDoS analysis.
5. Report (format below).

## Engines and APIs
| Language | API | Engine | Notes |
| --- | --- | --- | --- |
| Python | `re.compile/match/search/fullmatch/sub` | backtracking | `match` anchors only at the start, `fullmatch` for whole string; no timeout (`regex` module has one); possessive/atomic only from 3.11 |
| JS / TS | `/.../flags`, `new RegExp`, `.test/.match/.replace` | backtracking | no timeout; `u`/`v` flag for Unicode; lookbehind missing in old browsers (Safari < 16.4) |
| Java / Kotlin | `Pattern.compile`, `String.matches/replaceAll/split`, `Regex(...)` | backtracking | `matches()` = whole string, `find()` = substring; `split` takes a regex |
| C# | `new Regex`, `Regex.IsMatch`, `[GeneratedRegex]` | backtracking (or `RegexOptions.NonBacktracking`, .NET 7+) | supports a match timeout - use it for user input |
| Go | `regexp.MustCompile` | RE2 (linear) | no backreferences/lookaround; RX1 not applicable |
| Rust | `Regex::new` | linear | no backreferences/lookaround; RX1 not applicable |
| PHP | `preg_*` | PCRE (backtracking) | `pcre.backtrack_limit`; failures return `false`/`null` - check them |
| GDScript | `RegEx.new()` + `compile()` | PCRE2 (backtracking) | check `compile()` return value |
| Shell | `grep -E`/`-P`, `sed -E`, `[[ =~ ]]` | ERE / PCRE | `\d` and `\s` don't exist in POSIX ERE/BRE; quote patterns |

## Rules
- RX1 ReDoS through catastrophic backtracking - nested quantifiers (`(a+)+`, `(.*)*`, `(\w+\s?)*`), alternations whose branches overlap inside a repetition (`(a|ab)*`, `(\d|\d\d)+`), adjacent overlapping quantifiers on unbounded input (`\s*\s*`, `.*.*x`): error when the input is user-controlled on a backtracking engine, warning when it comes from files/config, info for constants or linear engines
- RX2 warning: missing anchors where the whole string must match (validation with `search`/`test`/`find` and no `^...$`, `\A...\z`, `fullmatch`, `matches()`); `$` matching before a trailing newline in Python/PCRE
- RX3 warning: unescaped `.` meant literally (domains, IP addresses, file extensions: `example.com`, `\.(jpg|png)` vs `.(jpg|png)`)
- RX4 error: wrong character class: `[A-z]` (also matches `[ \ ] ^ _` and backtick), invalid/unintended ranges (`[a-Z]`, `[0-9.-+]`), `|` inside `[...]` meant as "or", unescaped `-` in the middle
- RX5 warning: greedy `.*` / `.+` that overmatches (`<.*>` across several tags, `".*"` across several strings) - lazy quantifier or negated class needed
- RX6 warning: flags and Unicode: `^`/`$` without multiline mode on multi-line input (or with it unintentionally), case sensitivity on user input, `\w`/`\d`/`\b` being ASCII in one engine and Unicode in another (Python 3 and .NET `\d` match non-ASCII digits), missing `u` flag in JS for Unicode input
- RX7 info: regex compiled inside a loop or per call on a hot path → `performance-review` PF6
- RX8 warning: regex used where a parser is needed: HTML/XML, JSON, nested structures, full e-mail/URL validation (use the platform's URL/email parser or a simple sanity check), dates (use a date parser)
- RX9 info: unreadable pattern - long, no comment, no verbose mode (`re.X`, `(?x)`), no named groups for extracted parts
- RX10 warning: dialect issue: syntax not supported by the target engine/version (lookbehind, possessive quantifiers, `\d` in POSIX tools, `(?<name>)` vs `(?P<name>)`)
- RX11 error: user input inserted into a pattern without escaping (`re.escape`, `Pattern.quote`, `Regex.Escape`, an `escapeRegExp` helper) - changes the meaning and enables ReDoS
- RX12 info: unnecessary regex or capture groups: plain string methods would do (`startsWith`, `includes`, `split(",")`), capturing groups never used (use `(?:...)`)

## False positives to drop
Nested quantifiers where the inner and outer part can't match the same text (e.g. `(\d+,)*` - the comma separates repetitions) · patterns on short bounded input (length checked before) · regexes in tests and tooling · linear engines for RX1 · `.` inside a character class (`[.]` is already literal).

## Report
In the user's language, grouped by file:
```
path/to/file:line - error|warning|info - <ID> <rule> - `pattern` - matches: <plain-words meaning> - problem: <example input wrongly accepted/rejected, or the ReDoS input class> - direction: <what the pattern must ensure>
```
- Every finding has a concrete location and the pattern. Mark findings where the input source is unclear as "possible".
- No inputs crafted to hang a production system; a short description of the input class is enough.
- End with a summary: regex count per language, engines in use, findings per severity, then the 3 most important things to fix first.
- Do not change code. Apply fixes only when the user explicitly asks for it.
