---
name: error-handling-review
description: Review error handling in code - empty catch/except blocks, swallowed exceptions, catch-all without re-throw or logging, ignored return values and error codes, missing input validation at boundaries (user input, files, network), resources that are not closed, lost exception causes and error messages that leak internals. Use when asked to check/review/audit error handling, exception handling, robustness, "what happens when this fails" or failure paths, in any language.
---

# Error handling review

Review only: report findings, never change code unless the user explicitly asks.

## Scope
Check the files/directories the user names, otherwise the whole repo. Focus on production code; tests only for EH1/EH5-style issues that hide test failures. Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/` and generated code.

## Steps
1. Grep for the patterns in the language table to find candidates fast, then read each candidate in context.
2. Identify the boundaries (HTTP handlers, CLI argument parsing, file/network/database access, deserialization, public library functions) and check EH5/EH7 there specifically.
3. Determine the project's error strategy (exceptions, error codes, `Result`/`Option`, error returns in Go) and judge findings against it (EH10).
4. Report (format below).

## Rules
- EH1 error: empty `catch`/`except` block, or only `pass`/`// ignore` without a reason
- EH2 error: swallowed exception: caught and ignored, only printed to stdout, or turned into `null`/`false`/default value without logging or a documented reason
- EH3 warning: catch-all (`catch (Exception)`, `catch (Throwable)`, `except Exception`/`BaseException`, `catch (...)`, `catch {}` in JS) outside a top-level boundary, without re-throw or logging
- EH4 error: ignored return value or error code (C `malloc`/`fopen`/`write`, Go `_ = err` or unchecked `err`, C# `TryParse` result unused, unchecked `subprocess` return code, Promise without `await`/`.catch`, Rust `unwrap()`/`expect()` in library code)
- EH5 warning: missing validation at a boundary (null/empty, range, format, size limits, path traversal, type of deserialized data)
- EH6 error: resource not released on all paths (no `try-with-resources`/`using`/`with`/`defer`/RAII, close only on the happy path, missing `finally`)
- EH7 warning: error message or response leaks internals (stack traces, SQL, file paths, secrets) to users or HTTP clients
- EH8 warning: lost cause: new exception without the original (`throw new X(msg)` without `cause`, Python `raise X` inside `except` without `from e`, `errors.New` instead of `fmt.Errorf("...: %w", err)`)
- EH9 info: exceptions used for normal control flow
- EH10 info: inconsistent strategy in one module (exceptions mixed with error codes, `null` mixed with `Optional`/`Result`)
- EH11 info: `try` block much larger than the statements that can actually fail
- EH12 info: log-and-rethrow at every level (the same error is logged many times)
- EH13 error: `return`/`break` inside `finally` (silently discards the exception)
- EH14 warning: retry without limit or backoff, or timeout missing on network calls

## Language patterns (starting points for grep)
| Language | Look for |
| --- | --- |
| Java / Kotlin | `catch (.*) {` + `}` on next line, `catch (Exception`, `catch (Throwable`, `printStackTrace()`, `new FileInputStream` outside try-with-resources |
| C# | `catch {`, `catch (Exception`, `async void`, `.Result`/`.Wait()`, `new StreamReader` without `using` |
| Python | `except:`, `except Exception`, `pass` after except, `open(` without `with`, `raise ... ` in except without `from` |
| JS / TS | `catch (e) {}`, `catch {}`, promises without `await`/`.catch`, `JSON.parse` without try, `.then(` without `.catch(` |
| Go | `_ = `, `err` assigned but not checked, `panic(` in libraries, `errors.New(err.Error())` |
| C / C++ | unchecked `malloc`/`fopen`/`fread`/`write`, `catch (...)`, raw `new`/`delete` pairs, missing RAII |
| Rust | `.unwrap()`, `.expect(` in library code, `let _ = ` on `Result` |
| Shell | no `set -e` and unchecked commands, `\|\| true` hiding failures, missing `PIPESTATUS` checks |

## False positives to drop
Top-level handlers that catch everything to log and exit/return 500 (that's correct at a boundary) · intentionally ignored errors with a comment explaining why · `unwrap()` in tests, examples or after a check that guarantees success · cleanup code that may fail silently by design (closing in `finally`, with a comment).

## Report
In the user's language, grouped by file:
```
path/to/file:line - error|warning|info - <ID> <rule> - <what happens when it fails here> - direction: <what the handling should achieve, not the code>
```
- Every finding has a concrete location and describes the concrete failure scenario ("If the file is missing, the function returns an empty list and the caller saves it as valid data").
- Mark findings that depend on code you couldn't see as "possible".
- End with a summary: the project's error strategy as you understood it, findings per severity, then the 3 most important things to fix first.
- Do not change code. Apply fixes only when the user explicitly asks for it.
