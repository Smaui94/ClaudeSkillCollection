---
name: csharp-google-style
description: Apply the Google C# Style Guide (https://google.github.io/styleguide/csharpguide.html) plus mandatory XML/Doxygen-style documentation comments on every type and member when writing, editing, reviewing, or auditing C# code (.cs). Use for any C# work, and when asked to check/lint C# code against Google style.
---

# Google C# Style Guide + mandatory documentation comments

Source: https://google.github.io/styleguide/csharpguide.html

Follow the rules below when writing or changing C#. When reviewing, report violations as `file:line - rule - fix`, grouped by section. In existing code that does not follow this guide, or when the project has an `.editorconfig`, match the local conventions unless the user asks for a migration. Generated files (`*.Designer.cs`, `*.g.cs`, `Migrations/`) are exempt.

## Audit helper
For audits of a whole project, run first (no pipe, output is capped): `bash <skill-dir>/scripts/check.sh <project-root> [hitsPerRule=8]`. It prints `## ID count | description` plus samples `file:line:code`; the regexes are heuristics, so verify samples before reporting. Rule `C1` lists declarations without a `///` comment. Review manually only what the script cannot see (about 5 representative files). If violations stem from missing `.editorconfig`/`dotnet format` settings (2 spaces, K&R braces), report that once as root cause.

## Naming
- `PascalCase`: classes, methods, enums and their values, public fields, public properties, namespaces.
- `camelCase`: local variables and parameters.
- `_camelCase`: private, protected, internal, and protected internal fields and properties.
- `const`, `static`, `readonly` do not change the case style.
- Acronyms are words: `MyRpc`, not `MyRPC`. Interfaces start with `I` (`IInterface`).
- Files and directories: `PascalCase`; name the file after its main class (`MyClass.cs`); prefer one core class per file.

## Formatting
- Spaces only (never tabs), 2 spaces per indent level. Max 100 columns.
- One statement per line, one assignment per statement.
- K&R braces: the opening brace stays on the line of its declaration; `} else {` on one line. Always use braces, even when optional. Empty blocks may be written concisely (`{}`).
- Space after `if`, `for`, `while`, and after commas; none after `(` or before `)`. No space between a unary operator and its operand; one space on each side of other operators.
- Continuation lines are indented 4 spaces. Brace-delimited breaks (initializers, lambdas, object initializers) are not continuations: indent their contents 2 spaces.
- Wrapped arguments align with the first argument; if that does not fit or reads poorly, put each argument on its own line with a 4-space indent.
- Simple lambdas stay on one line without braces when they fit. A multi-line lambda's closing brace aligns with the first character of the line containing the opening brace. Prefer a leading newline before argument groups containing lambdas.
- Attributes: each on its own line above the member.

## Organization
- Modifier order: `public protected internal private new abstract virtual override sealed static readonly extern unsafe volatile async`.
- `using` directives at the top of the file, outside any namespace; sorted alphabetically with `System` first.
- Member groups in this order: nested classes/enums/delegates/events; static, const, and readonly fields; fields and properties; constructors and finalizers; methods. Within each group order by access: public, internal, protected internal, protected, private. Keep interface implementations together.
- Namespaces at most 2 levels deep; folder layout need not match namespaces. Use namespaces for shared library/module code, not for leaf application code. New top-level namespaces are globally unique and recognizable.
- Follow the project's folder conventions; prefer a flat folder structure.

## Coding guidelines
- `const` wherever possible, else `readonly`. Named constants instead of magic numbers.
- Inputs use the least capable type the implementation needs (`IReadOnlyCollection`, ...). `IEnumerable` as input only if iterated at most once. A returned container the caller owns is returned as `IList` rather than `List`; one the caller does not own as the most restrictive interface.
- `List<>` for public variables, properties, and return types when the size can change (subject to the interface rules above); arrays for fixed size known at construction and for multidimensional data.
- Generators vs. containers case by case: generators for lazy work; do not call `ToList()` on a generator when filling a container directly is simpler; do not enumerate a generator repeatedly.
- Properties: expression-bodied `=>` for single-line read-only properties, `{ get; set; }` otherwise. Expression-bodied methods only for a single statement (delegation or throwing). Use field initializers where appropriate.
- Almost always `class`; `struct` only for small, short-lived value-like types. Structs are copied, so member assignments on a returned struct do not change the original.
- A lambda with more than a couple of statements (declarations excluded) or reused in several places becomes a named method.
- Extension methods only if the source cannot be changed, only for core general features, never if the maintainer declined the method, and only in core libraries available everywhere. Avoid by default.
- `out` for additional return values that are not inputs, placed after all other parameters. `ref` rarely: only when the method must mutate or replace an input; never for struct performance or to pass a mutable container.
- LINQ: method syntax (`list.Where(...)`), short single-line calls over long chains; imperative code is fine. `ForEach(...)` only for a single statement.
- Prefer a named class over `Tuple<>`, especially for complex return types. Do not use `using` aliases for long type names; create a named class instead.
- Strings: choose the most readable option; avoid chained `+` in performance-sensitive code and use `StringBuilder` for repeated concatenation.
- Object initializers only for plain data types, not for types with constructors; multi-line initializers are indented one block level.
- Returning a struct that may be absent: prefer `bool TryX(out T value)`; nullable structs only if performance is irrelevant and readability clearly improves.
- Removing from a container while iterating: `RemoveAll(predicate)` if that is the only task, otherwise build a new container of the kept items and swap it in after the loop.
- Invoke delegates with `SomeDelegate?.Invoke(...)`.
- `var` when the type is obvious (`var apple = new Apple();`) or for a transient variable passed straight to another method; not for basic types (`bool`), compiler-resolved numeric types, or when knowing the type helps the reader.
- Unclear arguments, in order of preference: named constant for a repeated literal, `enum` instead of `bool`, named variable for a complex expression, named arguments at the call site; many options become one options class or struct.

## Documentation comments (mandatory)
These rules overrule Google's allowance to skip comments on simple or obvious members.

- Every type (class, struct, interface, enum, record, delegate) and every member (method, constructor, finalizer, property, indexer, event, operator) gets a `///` XML documentation comment, including trivial accessors and private/internal members. No type or method may be left without a comment; a missing one is a violation in reviews. Enum values and fields get one when their meaning or invariants are not clear from type and name.
- Use XML tags, which Doxygen, IDEs, and the compiler understand (do not use Javadoc `@` tags in C#):
  - `<summary>` first: one sentence, third-person verb phrase ("Opens the file."). Properties start with "Gets" or "Gets or sets"; boolean ones with "Gets a value indicating whether".
  - `<typeparam name="T">` for every generic parameter, `<param name="x">` for every parameter, `<returns>` for every non-void return (state what `null`, `false`, or empty means), `<exception cref="...">` for every exception the method throws on purpose.
  - Per parameter state whether it may be `null`, and whether the object retains it beyond the call. Refer to arguments with `<paramref name="x"/>`.
  - `<remarks>` for performance implications (complexity), threading assumptions, invariants, and lifetimes; `<example><code>...</code></example>` for usage; `<see cref="..."/>` for references.
  - Overrides and interface implementations: `<inheritdoc/>`, or a short `<summary>` describing only what is specific to them.
  - Constructors: describe the arguments and the state they establish; never write only "creates this object".
- Class comments explain what the class is for, how and when to use it, threading assumptions, and invariants; an `<example>` is encouraged.
- Enable compiler checks where possible: `<GenerateDocumentationFile>true</GenerateDocumentationFile>` and treat CS1591 (missing XML comment) as an error for public APIs.

### Other comments
- Comments are for the next reader, who may be you. Write complete sentences with correct punctuation. Explain *why*, not *what*; prefer clear names over comments that explain obscure ones.
- Explain tricky or complicated code blocks and the approach taken, before the block.
- Comment fields only when invariants, special values, relationships between members, or lifetimes are not clear from type and name.
- A file that declares several abstractions starts with a comment describing them.
- TODO: `// TODO(identifier): description` (bug ID, name, or email).
