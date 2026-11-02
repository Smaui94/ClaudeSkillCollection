---
name: test-coverage-review
description: Find logic without tests - public functions and classes without corresponding tests, untested error paths and edge cases (empty input, null, limits), tests without assertions or that can't fail, skipped and flaky tests - using existing coverage reports when present. Describes which test cases are missing but doesn't write tests unless asked. Use when asked to review/check/assess test coverage, missing tests, test quality or "what should I test", in any language.
---

# Test coverage review

Review only: describe missing and weak tests, never write or change tests unless the user explicitly asks. Don't run the test suite without asking: it can be slow or have side effects (databases, network). Offer the coverage command instead.

## Scope
The production code and tests the user names, otherwise the whole repo. Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`, generated code, and code that needs no tests (pure configuration, DTOs without logic, generated clients) - say what you skipped.

## Steps
1. Find the test setup: framework (JUnit, pytest, unittest, Jest, Vitest, NUnit, xUnit, GoogleTest, Catch2, Go `testing`, GUT/GdUnit for Godot), test directories and naming conventions (`tests/test_*.py`, `*_test.go`, `*Test.java`, `*.test.ts`/`*.spec.ts`, `*Tests.cs`, `test/`, `__tests__/`).
2. Look for existing coverage reports: `coverage.xml`, `.coverage`, `htmlcov/`, `lcov.info`, `coverage/coverage-final.json`, `jacoco.xml`, `cobertura.xml`, `*.coverage`. If present, read them (note their date - an old report may be stale). If not, suggest the command for the project (e.g. `pytest --cov=<pkg> --cov-report=term-missing`, `npx jest --coverage`, `mvn test jacoco:report`, `dotnet test --collect:"XPlat Code Coverage"`, `go test -cover ./...`) and continue with static mapping.
3. Map production units to tests: for each public function/class, find tests that call it (grep the name in test files). Prioritize by risk: business logic, parsing, calculations, security checks, error handling - before getters and glue code.
4. Read the tests of the most important units: do they cover error paths and edge cases, and do they actually assert something?
5. Report (format below).

## Rules
- TC1 warning: public function/class with logic but no test calling it (error for critical code: money, security, data loss, parsing)
- TC2 warning: error path not tested (exception branches, invalid input, failing I/O, timeouts)
- TC3 warning: edge cases missing - empty/null/None, zero, negative, one element, maximum/minimum values, boundaries (`<` vs `<=`), Unicode/whitespace, duplicates, very large input, concurrency where relevant
- TC4 error: test without any assertion (only calls the code; passes as long as nothing throws, unless that is the stated intent)
- TC5 error: assertion that can't fail (`assertTrue(true)`, `assert x == x`, asserting the mock's own return value, `try { ... } catch (Exception) {}` around the assertion)
- TC6 warning: test only verifies mocks (everything relevant mocked, so it tests the mock setup, not the code)
- TC7 warning: flaky signs - `sleep`, real time/date, network, random without seed, shared mutable state, dependence on test order or file system state
- TC8 info: skipped/disabled test without reason or ticket (`@Disabled`, `@Ignore`, `pytest.mark.skip`, `xit`, `it.skip`, `[Fact(Skip=...)]`)
- TC9 warning: low coverage from a report - file below 50 %, or critical file below 80 % (state the numbers; the user may override the thresholds)
- TC10 info: test names that don't say what is checked (`test1`, `testMethod`) - hard to see which case failed

## Report
In the user's language, grouped by production file (unit under test):
```
path/to/file:line - error|warning|info - <ID> <rule> - `unitName` - missing case: <given ... when ... then ...> - <why this case matters>
```
- Every finding has a concrete location (production code, or the test file for TC4-TC8, TC10).
- Describe missing tests as concrete cases in "given/when/then" form, not as code.
- Mark mappings you couldn't confirm (e.g. the unit may be tested indirectly through another unit) as "possible".
- End with a summary: test framework, coverage numbers if available (and their date), findings per severity, then the 3 most valuable tests to write first.
- Do not change code or tests. Write tests only when the user explicitly asks for it.
