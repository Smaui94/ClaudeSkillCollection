---
name: concurrency-review
description: Review concurrent and asynchronous code - race conditions on shared mutable state, check-then-act (TOCTOU), missing or inconsistent locking, deadlock risks, non-thread-safe collections, broken double-checked locking, blocking calls in async code, missing await and fire-and-forget tasks, unbounded thread creation, shared state in request handlers and engine/UI main-thread violations (Godot, Unity, WPF, Android). Use when asked to check/review threads, async/await, locks, parallel code, race conditions, deadlocks or thread safety, in any language.
---

# Concurrency review

Review only: report findings, never change code unless the user explicitly asks. Concurrency bugs rarely show up in tests, so explain each finding with a concrete interleaving ("thread A reads, thread B reads, both write").

## Scope
Check the files/directories the user names, otherwise the whole repo. Focus on code that runs on several threads, tasks, goroutines or event-loop callbacks. Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`, generated code.

## Steps
1. Find the concurrency model: thread pools, `async`/`await`, goroutines, actors, worker threads, web server (one handler instance per request or shared?), game engine threads.
2. List shared mutable state: static/global fields, singletons, module-level variables, caches, collections passed to several threads, files and database rows.
3. For each piece of shared state, check how every access is protected (CC1-CC7), then check async flows (CC8-CC10) and framework rules (CC11-CC12).
4. Use analyzers if installed (never install; mention if helpful): Go `go test -race`, `go vet`; C/C++ ThreadSanitizer (`-fsanitize=thread`); Java SpotBugs; C# analyzers (VSTHRD for async); Rust `cargo clippy`, Miri; Python `pyright` for unawaited coroutines.
5. Report (format below).

## Rules
- CC1 error: shared mutable state accessed from several threads without synchronization
- CC2 error: check-then-act / TOCTOU (`if (!map.containsKey(k)) map.put(...)`, `if file exists: open`, lazy init without lock)
- CC3 error: inconsistent locking - the same field is guarded in some places and not in others, or by different locks
- CC4 error: deadlock risk - nested locks acquired in different orders, lock held while waiting for another thread/task
- CC5 warning: lock held during I/O, callbacks, `await` or calls into unknown code
- CC6 error: non-thread-safe type shared between threads (`HashMap`, `ArrayList`, `Dictionary`, `List<T>`, `SimpleDateFormat`, STL containers, Python `dict` with compound operations)
- CC7 error: broken double-checked locking (no `volatile`/`Lazy<T>`/`std::call_once`), unsafe lazy singleton; compound operations on volatile/atomic values (`count++` on `volatile`)
- CC8 error: blocking inside async code (`Thread.sleep`/`time.sleep`, `.Result`/`.Wait()`/`.get()`, sync file or network I/O on an event loop)
- CC9 error: missing `await`, fire-and-forget task whose exception is lost, `async void` outside event handlers, unhandled promise rejection
- CC10 warning: unbounded thread/task/goroutine creation; no cancellation or timeout; goroutine or task that can block forever (leak)
- CC11 error: per-request data stored in shared state (static fields, singleton services, module globals in web handlers)
- CC12 error: main-thread-only API called from another thread (Godot scene tree outside `call_deferred`/main thread, Unity API off the main thread, WPF/WinForms controls without `Dispatcher`/`Invoke`, Android views off the UI thread)
- CC13 warning: language-specific pitfalls (table)

## Language notes
| Language | Watch for |
| --- | --- |
| Java / Kotlin | `synchronized` on different objects, `HashMap` vs `ConcurrentHashMap` compound ops (`get`+`put` → `computeIfAbsent`), `volatile` misuse, coroutines on `Dispatchers.Main` blocking |
| C# | `lock` on `this`/strings/types, `async void`, `.Result` deadlocks with sync context, `ConfigureAwait`, `Dictionary` shared across tasks, `static` state in ASP.NET |
| C++ | data races are undefined behavior; `std::mutex` without RAII (`lock_guard`/`scoped_lock`), detached threads, `shared_ptr` copies are thread-safe but the object isn't |
| Python | GIL doesn't make compound operations atomic; `asyncio` + blocking calls; unawaited coroutines; `multiprocessing` shared state |
| JS / TS | no threads but interleaving at every `await`: read-modify-write across `await`, missing `await` in loops, `forEach` with async callbacks, Worker shared memory without `Atomics` |
| Go | concurrent map writes, loop variable capture (before Go 1.22), sending on/closing a closed channel, `WaitGroup.Add` inside the goroutine, missing `context` cancellation |
| Rust | `unsafe impl Send/Sync`, ignoring `Mutex` poisoning, holding a `MutexGuard` across `.await` |
| GDScript / Godot | `Thread`/`WorkerThreadPool` touching nodes, signals emitted from threads, missing `Mutex` around shared arrays |

## False positives to drop
State that is effectively immutable after construction (final/readonly, published safely) · thread-confined objects (only ever used by one thread) · single-threaded programs without async · data protected by a framework guarantee (actor model, one handler instance per request) - name the guarantee.

## Report
In the user's language, grouped by file:
```
path/to/file:line - error|warning|info - <ID> <rule> - <shared state / async flow> - interleaving: <concrete sequence that goes wrong> - direction: <what the synchronization must ensure>
```
- Every finding has a concrete location and a concrete interleaving or failure sequence. Mark findings where you couldn't confirm that code really runs concurrently as "possible".
- End with a summary: concurrency model as you understood it, shared state found, findings per severity, then the 3 most important things to fix first.
- Do not change code. Apply fixes only when the user explicitly asks for it.
