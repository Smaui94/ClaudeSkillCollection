---
name: performance-review
description: Review code for real performance problems - avoidable work in loops (repeated I/O, queries, regex compilation, allocations), wrong data structures, quadratic algorithms on growing input, string concatenation in loops, loading everything into memory instead of streaming, missing caching, memory leaks and heavy work in hot paths like game loops or render functions - always related to realistic input sizes, with a recommendation to measure before changing anything. Use when asked to check/review performance, speed, slowness, memory usage, efficiency or "why is this slow", in any language.
---

# Performance review

Review only: report findings, never optimize code unless the user explicitly asks. Measure before changing: every finding must say how it scales with realistic input, and the report recommends a profiler to confirm. No micro-optimizations without evidence.

## Scope
Check the files/directories the user names, otherwise the code paths the user calls slow, otherwise the main code paths (request handlers, loops over data, game loops, rendering). Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`, generated code, tests and one-off scripts.

## Steps
1. Ask yourself (or the user, if it isn't visible) what the realistic sizes are: number of records, request rate, frame budget (16.7 ms at 60 FPS). Without numbers, state your assumption.
2. Find the hot paths: loops over collections, per-request/per-frame code (`_process`, `_physics_process`, `Update`, `render`, `useEffect`, `paint`), recursive functions, batch jobs.
3. Estimate complexity for each finding (e.g. "O(n·m), n = orders ≈ 10,000, m = customers ≈ 5,000 → 5·10⁷ comparisons per request").
4. Check PF1-PF12. Database query issues → `sql-review` (SQ4, SQ5, SQ8, SQ9).
5. Report (format below) with the matching profiler.

## Rules
- PF1 error: repeated I/O inside a loop (file reads, HTTP calls, database queries → `sql-review` SQ4) that could be done once or batched
- PF2 warning: wrong data structure - lookups in a list/array inside a loop instead of a set/map; `list.contains`/`in list` on large lists; removing from the front of an array list
- PF3 error: quadratic or worse algorithm on input that grows (nested loops over the same or two large collections, repeated sorting, `indexOf` in a loop)
- PF4 warning: string concatenation in a loop (Java/C# `+=` on strings, Python `+=` in big loops) instead of a builder/`join`
- PF5 warning: loading everything into memory (whole file, whole table, all pages) where streaming or pagination is possible
- PF6 warning: expensive pure work repeated with the same input (regex compilation, parsing, reflection, `JSON.parse` of the same string) - candidate for caching or hoisting out of the loop
- PF7 error: memory leak - listeners/signals/subscriptions never removed, caches/static collections that only grow, unclosed resources, timers not cleared
- PF8 error: heavy work in a hot path: allocations, `find`/`get_node` lookups, `GetComponent`, loading resources, logging in every frame or every request
- PF9 warning: unnecessary work - computing values that are never used, re-rendering whole lists on every change, missing early exit
- PF10 warning: blocking the main/UI/event-loop thread with long work → also `concurrency-review` CC8
- PF11 info: inefficient but bounded (small, fixed-size input) - mention only if it is in a very hot path
- PF12 info: premature optimization that hurts readability without measured benefit (report it too - readability is a cost)

## Profilers (recommend the matching one)
| Stack | Profiler |
| --- | --- |
| Python | `cProfile` + `snakeviz`, `py-spy`, `scalene`, `memray` (memory) |
| Java / Kotlin | Java Flight Recorder + JMC, async-profiler, VisualVM, JMH (micro-benchmarks) |
| C# | `dotnet-trace`, `dotnet-counters`, Visual Studio profiler, BenchmarkDotNet |
| JS / TS | browser DevTools Performance/Memory tab, `node --prof`, `clinic.js` |
| C / C++ | `perf`, Visual Studio profiler, VTune, Valgrind `callgrind`/`massif`, Tracy |
| Go | `pprof` (`go test -bench . -cpuprofile`), `go tool trace` |
| Godot | built-in Profiler and Monitors (Debugger panel) |
| Unity | Unity Profiler, Memory Profiler, Frame Debugger |
| SQL | `EXPLAIN` / `EXPLAIN ANALYZE` (ask before running on real data) |

## False positives to drop
Code that runs once at startup or on tiny bounded input · loops where the compiler/runtime already optimizes the pattern (e.g. string `+` of constants) · readability-first code in non-hot paths · caching where the data changes often (stale data is a bug).

## Report
In the user's language, hotspots ranked by expected impact:
```
path/to/file:line - error|warning|info - <ID> <rule> - <what is slow and how it scales, e.g. "O(n²): 10,000 items → 10⁸ steps per call"> - direction: <what should change, e.g. "look up by key instead of scanning"> - confirm with: <profiler>
```
- Every finding has a concrete location and a scaling estimate with the assumed input size. Mark estimates as "approx." and unconfirmed hot paths as "possible".
- End with a summary: assumed input sizes, findings per severity, the profiler to use first, then the 3 changes with the biggest expected effect.
- Do not change code. Optimize only when the user explicitly asks for it.
