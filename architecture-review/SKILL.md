---
name: architecture-review
description: Review the architecture of a codebase at module/package level - dependency cycles, layer violations (UI accessing the database, domain depending on infrastructure), god modules, modules reaching into other modules' internals, shared mutable global state, framework leakage into domain logic, high coupling, low cohesion and inconsistent project structure - judged against the intended architecture and with a dependency overview (Mermaid). Use when asked to review/check/analyze architecture, module structure, dependencies between packages, layering, coupling, circular dependencies or project structure.
---

# Architecture review

Review only: report findings and a dependency overview, never move files or restructure code unless the user explicitly asks. Architecture changes are expensive - each finding must say why it matters for this project, not only that a rule is broken.

## Scope
The repo or the subproject the user names. Module = a package/namespace/directory at a sensible depth (usually 1-3 levels below the source root). Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`, generated code; tests are excluded from the dependency graph by default.

## Steps
1. Find the **intended** architecture first: README, `docs/`, architecture decision records (`docs/adr/`), folder names (`domain/`, `application/`, `infrastructure/`, `ui/`, `api/`, `core/`, feature folders), framework conventions (MVC, Clean/Hexagonal, Godot scenes + autoloads). If nothing is documented, state the architecture you assume and judge against that.
2. Run (no pipe; output is capped): `bash <skill-dir>/scripts/deps.sh <source-root> [depth=2]`
   - Extracts import/include relations for Python, JS/TS, Java/Kotlin, C#, C/C++, Go and GDScript (`res://` paths, `class_name` usage) and prints module edges, cycles (strongly connected components), fan-in/fan-out per module and unresolved internal-looking imports.
   - `INCLUDE_TESTS=1` adds test code, `MERMAID=1` prints a Mermaid graph of the edges.
   - Limits: path aliases (`@/…` other than `@/` → `src/`), dependency injection, reflection and dynamic imports are not visible - say so when they are used.
   - Prefer a dedicated tool if installed (never install; mention if helpful): `madge --circular`/`dependency-cruiser` (JS/TS), `pydeps`/`import-linter` (Python), ArchUnit/jdepend (Java), NDepend/NetArchTest (C#), `deptrac` (PHP), `goda`/`go list -deps` (Go), `cargo-modules` (Rust).
3. Draw a dependency overview of the main modules (≤ 15 nodes, Mermaid `graph LR`), with problematic edges marked.
4. Check AR1-AR11, using `git log --format= --name-only | sort | uniq -c | sort -rn | head -30` for change frequency where stability matters (AR8, AR11).
5. Report (format below). File-level complexity → `complexity-check`; API surface → `api-design-review`; concurrency of shared state → `concurrency-review`.

## Rules
- AR1 error: dependency cycle between modules (A → B → … → A)
- AR2 error: layer violation against the intended architecture (presentation → data access directly; domain → infrastructure/framework/UI; lower layer importing a higher one)
- AR3 warning: god module - very high fan-in **and** fan-out, or a large share of the code and responsibilities in one module
- AR4 warning: reaching into another module's internals (importing `internal`/`_private`/`impl` paths, deep imports past a module's public entry point)
- AR5 warning: shared mutable global state used across modules (singletons, static mutable fields, Godot autoloads holding mutable game state used everywhere)
- AR6 info: feature envy between modules - logic in A works mainly with B's data and belongs in B
- AR7 info: inconsistent structure - partly organized by layer, partly by feature; files in the wrong module; naming of modules inconsistent
- AR8 warning: high coupling - a module depended on by almost everything that also changes often (every change ripples); stable shared kernels/utilities are fine
- AR9 info: low cohesion - a module whose parts don't use each other and serve unrelated purposes (`utils`, `common`, `helpers` dumping grounds)
- AR10 warning: framework leakage - HTTP request objects, ORM entities, UI or engine types inside domain/business logic; persistence models used as API DTOs
- AR11 info: stable, widely used modules depending on volatile ones (dependencies should point towards stability)

## False positives to drop
Cycles inside one module (only module-level cycles count) · type-only imports where the language erases them (TS `import type`) - report as info · composition roots/`main`/DI setup that legitimately know all layers · small projects where layering would be over-engineering (say so instead of demanding layers).

## Report
In the user's language:
1. Intended architecture (found or assumed) in 2-3 sentences.
2. Dependency overview (Mermaid, problematic edges labeled with the rule ID).
3. Findings, most severe first:
```
module or path/to/file:line - error|warning|info - <ID> <rule> - <evidence, e.g. "ui/ imports db/ in 14 files (ui/cart.ts:3, …)"> - <why it matters here> - direction: <where the dependency should point / what should move>
```
- Every finding has concrete evidence (edges with sample file:line). Mark findings that depend on assumptions about the intended architecture as "possible".
- End with a summary: module count, cycles, findings per severity, then the 3 most valuable structural improvements first, each with an estimate of how invasive it is.
- Do not change code. Restructure only when the user explicitly asks for it.
