---
name: api-design-review
description: Review the design of public interfaces - library APIs, public classes and REST/HTTP endpoints - for consistent naming and parameter order, boolean traps, inconsistent return types and error behavior, leaked internal types, missing contracts, overload sprawl, exposed mutable state, REST conventions (methods, status codes, pagination, versioning, error format) and breaking changes since the last release tag with semantic versioning advice. Use when asked to review/check an API, public interface, SDK, REST endpoints, OpenAPI spec, breaking changes or API usability.
---

# API design review

Review only: report findings, never change signatures, routes or specs unless the user explicitly asks. Every suggested change to a public API is itself a breaking change - say so and give the semver impact.

## Scope
The public surface the user names, otherwise everything public: exported functions/classes (`export`, `public`, `pub`, capitalized Go names, `__all__`), public headers, route definitions/controllers, OpenAPI/GraphQL/protobuf schemas. Skip internal code, tests and generated clients.

## Steps
1. Identify the API surface and its consumers (library users, frontend, other services). Read the README/docs to learn the intended usage.
2. Check consistency across the whole surface, not per function: the same concept should look the same everywhere (AD1-AD8).
3. For HTTP APIs check AD9-AD13 against the routes and the spec.
4. Breaking changes (AD14): find the last release tag (`git describe --tags --abbrev=0`) and compare public signatures/specs (`git diff <tag> -- <public files>`). Use a tool if installed (never install; mention if helpful): `japicmp`/`revapi` (Java), `Microsoft.DotNet.ApiCompat`/PublicApiAnalyzers (C#), `api-extractor` (TS), `griffe check` (Python), `cargo-semver-checks` (Rust), `apidiff`/`gorelease` (Go), `oasdiff` (OpenAPI).
5. Report (format below).

## Rules
- AD1 warning: inconsistent naming for the same concept or operation (`getUser` / `fetchAccount` / `loadClient`) → details in `naming-review`
- AD2 warning: inconsistent parameter order between similar functions (`copy(src, dst)` vs `move(dst, src)`)
- AD3 warning: boolean trap - `send(msg, true, false)`; flags that should be an enum, options object or separate functions
- AD4 error: inconsistent error behavior for similar operations (one returns `null`, one throws, one returns an error code); errors not part of the documented contract
- AD5 warning: internal or implementation types leak into the public API (ORM entities, framework request objects, internal exceptions, third-party types that pin consumers to a dependency)
- AD6 warning: missing contract - unclear whether `null` is allowed, which units/ranges/formats are expected, thread safety, ownership of returned objects → documentation details in `doc-comment-audit`
- AD7 info: too many overloads or optional parameters; a parameter list that keeps growing (candidate for an options/config object)
- AD8 warning: exposes mutable internal state (returns the internal list/array, public mutable fields) so callers can break invariants
- AD9 error (HTTP): wrong method semantics - `GET` with side effects, non-idempotent `PUT`/`DELETE`
- AD10 warning (HTTP): wrong or inconsistent status codes (`200` with an error body, `500` for validation errors, `404` vs `403` leaking existence)
- AD11 warning (HTTP): inconsistent resource naming (verbs in paths, mixed plural/singular, mixed case styles), inconsistent query parameter conventions for filter/sort
- AD12 warning (HTTP): list endpoints without pagination; no versioning strategy for a public API
- AD13 warning (HTTP): inconsistent error format (recommend one shape, e.g. RFC 9457 Problem Details), errors exposing internals → `error-handling-review` EH7
- AD14 error: breaking change since the last release without a major version bump (removed/renamed public symbol, changed parameter or return type, new required parameter, changed default or error behavior, removed field/endpoint, stricter validation)
- AD15 info: mixed sync/async APIs for the same operations, or async functions that block

## Semver guidance
Removed or changed public behavior = **major**; new optional functionality = **minor**; bug fix without contract change = **patch**. Deprecate before removing: mark it (`@Deprecated`, `[Obsolete]`, `@deprecated` in docs, `Deprecation` header) for at least one minor release.

## False positives to drop
Inconsistencies dictated by an external standard or protocol · `0.x` versions where breaking changes in minor releases are documented as allowed · internal APIs that only look public (e.g. `public` for testing, `internal` packages) - mention that they should be marked internal.

## Report
In the user's language, grouped by API area (module, resource):
```
path/to/file:line - error|warning|info - <ID> <rule> - `symbol or METHOD /path` - <why it hurts consumers> - direction: <what the API should look like conceptually> - semver impact of changing it: major|minor|patch
```
- Every finding has a concrete location. Mark findings that depend on unknown consumers as "possible".
- AD14: list each breaking change with the old and new signature and the tag compared against.
- End with a summary: API surface size, last release tag, findings per severity, required version bump for the current changes, then the 3 most important improvements first.
- Do not change code. Apply changes only when the user explicitly asks for it.
