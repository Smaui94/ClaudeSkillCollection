---
name: logging-review
description: Review logging in code - missing logs at errors, external calls and security events, log noise, wrong log levels, sensitive and personal data in logs (passwords, tokens, GDPR data), string formatting instead of structured/parameterized logging, missing context like request or entity IDs, print/console.log instead of the project logger, exceptions logged without stack trace or twice, and log injection. Use when asked to check/review/audit logging, log levels, log output, observability or "what should I log", in any language.
---

# Logging review

Review only: report findings, never change logging code unless the user explicitly asks.

## Scope
Check the files/directories the user names, otherwise the whole repo. Focus on production code. Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`, generated code; tests and dev scripts only for LG4 (sensitive data in fixtures that end up in logs).

## Steps
1. Find the logging setup: library (`logging`, SLF4J/Logback/Log4j2, `Microsoft.Extensions.Logging`/Serilog/NLog, `winston`/`pino`, `zap`/`slog`, `spdlog`, Godot `print`/`push_error`/`push_warning`, Unity `Debug.Log`), configuration (levels per environment, format, sinks) and conventions already used.
2. Check the important points for presence of logs (LG1): error handling, calls to external systems, authentication/authorization events, startup configuration, important state changes.
3. Check existing log statements for LG2-LG12.
4. Report (format below).

## Level guide
| Level | Use for |
| --- | --- |
| ERROR | an operation failed and needs attention (someone may need to act) |
| WARN | unexpected but handled (retry succeeded, fallback used, deprecated usage) |
| INFO | important business/lifecycle events (startup, config summary, job finished) - few per request at most |
| DEBUG | details for developers (inputs, decisions, intermediate values) - off in production |
| TRACE | very fine-grained flow, loops - off by default |

## Rules
- LG1 warning: missing log where it matters: caught errors that are handled silently, failed external calls, security events (login failure, access denied, permission changes), startup configuration, retries/fallbacks
- LG2 warning: log noise - logging inside tight loops, per-item INFO logs in batch jobs, the same message on every request/frame
- LG3 warning: wrong level (table above) - errors at INFO, expected conditions at ERROR, debug details at INFO
- LG4 error: sensitive data in logs: passwords, tokens, API keys, session IDs, full card numbers, private keys; personal data (GDPR: e-mail, address, phone, health data, IP addresses in some contexts) without need; whole request bodies/headers or objects with `toString()` that include them
- LG5 warning: string formatting/concatenation instead of parameterized or structured logging (`log.info("user " + id)`, f-strings in Python logging) - costs time even when the level is off and loses structure
- LG6 warning: missing context - no request/correlation ID, user or entity ID, operation name, so a log line can't be traced back
- LG7 warning: `print`, `console.log`, `System.out.println`, `Console.WriteLine`, `printf` in production code instead of the project logger (Godot/Unity: unguarded debug prints in shipped builds)
- LG8 error: exception logged without stack trace or cause (only `e.getMessage()` / `str(e)`)
- LG9 info: the same error logged at several levels of the call stack → `error-handling-review` EH12
- LG10 warning: log injection - user input with line breaks or control characters logged unescaped (forged log lines)
- LG11 info: inconsistent message style (mixed languages, tenses, formats); no level configuration per environment
- LG12 info: expensive computation in log arguments without a level guard or lazy evaluation

## False positives to drop
CLI tools whose job is printing to stdout (LG7) · logs of IDs that are not personal data · intentionally verbose DEBUG logs that are off in production · `print` in scripts, notebooks and tests.

## Report
In the user's language, grouped by file:
```
path/to/file:line - error|warning|info - <ID> <rule> - <what is logged or missing and why it matters, e.g. "a failed payment leaves no trace"> - direction: <what the log should contain or omit>
```
- Every finding has a concrete location. LG4: name the data type, never copy the actual sensitive values into the report.
- Mark findings that depend on runtime configuration you couldn't see (levels, filters) as "possible".
- Bulk hits with one root cause (e.g. 80 `console.log` calls): report once with count and 2-3 samples.
- End with a summary: logging setup as found, findings per severity, then the 3 most important things to fix first.
- Do not change code. Apply fixes only when the user explicitly asks for it.
