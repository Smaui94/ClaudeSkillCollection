---
name: cpp-google-style
description: Apply the Google C++ Style Guide (https://google.github.io/styleguide/cppguide.html) plus mandatory Doxygen comments on every class and function when writing, editing, or reviewing C++ code (.h, .hpp, .cc, .cpp). Use for any C++ work, and when asked to check/lint C++ code against the style guide.
---

# Google C++ Style Guide + Doxygen

Source: https://google.github.io/styleguide/cppguide.html

Follow the rules below when writing or changing C++. When reviewing, report violations as `file:line - rule - fix`, grouped by section. In existing code that does not follow this guide, match the local conventions of the file unless the user asks for a migration. Follow the project's file extensions (`.hpp`/`.cpp` are fine) instead of forcing `.h`/`.cc`. For details not covered here, consult the source URL.

## Header Files
- Pair each source file with a header (tests and tiny `main()` files excepted). Headers are self-contained: guarded and including everything they need.
- Guard format `<PROJECT>_<PATH>_<FILE>_H_` (use `_HPP_` for `.hpp`) from the full path in the source tree. No `#pragma once`.
- Include what you use; never rely on transitive includes. Prefer `#include` over forward declarations; never forward-declare entities you do not own.
- Inline and template definitions live in the header; no `-inl.h`. Define functions in headers only if short (about 10 lines), and make them ODR-safe (`inline`, template, or in-class). Put header-only implementation in a `private` section or an `internal` namespace.
- Include order, one blank line between groups, alphabetical within each: 1. related header, 2. C system headers, 3. C++ standard headers, 4. other libraries, 5. project headers.
- Project headers by path from the source root, no `.`/`..`. Angle brackets only for standard/system/third-party headers.

## Scoping
- Put code in project-specific namespaces; no indentation inside; comment closing braces of multi-line namespaces (`}  // namespace foo`). Prefer `namespace a::b {` for nesting.
- Never `using namespace`, inline namespaces, or declarations in `std`. No namespace aliases at header namespace scope (except in `internal` namespaces).
- Implementation details go in namespaces whose name contains `internal`.
- In `.cc` files give internal linkage to anything other files do not need (unnamed namespace, closing comment `}  // namespace`, or `static`); never in headers.
- Prefer namespaced nonmember functions over globals; no classes that only group static members.
- Declare variables in the narrowest scope, initialize at declaration; declare `if`/`while`/`for` variables inside the statement.
- Static-storage objects must be trivially destructible; mark constants `constexpr`/`constinit`; avoid dynamic initialization of non-local statics; no smart pointers as statics. Fallback: `static const auto& x = *new T(...);`.
- Namespace/class-scope `thread_local` must be `constinit`; prefer function-local.

## Classes
- No virtual calls in constructors; avoid fallible constructors (use factory or `Init()`). No exceptions.
- `explicit` on single-argument constructors and conversion operators (copy/move exempt; `initializer_list` constructors may omit it).
- Make copy/move support explicit in the public interface: `= default` or `= delete`. Declare or delete both copy operations, both move operations. Omit only when obvious (passive structs, clearly non-copyable base).
- Prevent slicing: base classes get protected constructors/destructors or a pure virtual. Avoid deriving from concrete classes.
- `struct` only for passive data, all fields public, no invariants; otherwise `class`. Prefer a named `struct` over `std::pair`/`std::tuple` when elements have meaning.
- Composition over inheritance. Public inheritance only, for is-a. Mark non-base classes `final`. Exactly one of `override`/`final` on overrides, no redundant `virtual`. Avoid multiple implementation inheritance.
- Operators: overload only when meaning is obvious, only on your own types, in the same namespace; non-member for non-modifying binary operators; define `operator==` for equality; never overload `&&`, `||`, `,`, unary `&`; no user-defined literals.
- All data members `private` (constants excepted).
- Declaration order: `public`, `protected`, `private` (omit empty). Within each: types/aliases, static constants, factories, constructors/assignment, destructor, other functions, data members.
- Keep large method bodies out of the class definition.

## Functions
- Return values rather than output parameters; return by value, else reference; raw pointers only when null is meaningful.
- Inputs by value or `const&`; non-optional outputs/in-out by non-const reference; optional by-value input `std::optional`; optional input reference as `const*`; optional output as non-const pointer. Input parameters before output parameters.
- Do not require a reference parameter to outlive the call.
- Keep functions short (reconsider beyond about 40 lines).
- Overload only when semantically identical; one umbrella comment for an overload set; prefer `std::string_view` over `const std::string&`/`const char*` overloads.
- Default arguments only on non-virtual functions with always-identical defaults.
- Leading return types by default; trailing only when required or clearly clearer.

## Other C++ Features
- Ownership: single fixed owner; `std::unique_ptr` for transfer; `std::shared_ptr` only with strong reason (prefer `shared_ptr<const T>`). Never `auto_ptr`.
- Rvalue references only for move operations, `&&`-qualified consuming methods, forwarding references with `std::forward`, and `Foo&&`/`const Foo&` overload pairs.
- `friend` sparingly, defined in the same file as the class. No exceptions; `noexcept` only when accurate (move constructors).
- Avoid RTTI (`typeid`, `dynamic_cast`) outside tests; prefer virtual methods or Visitor.
- Casts: no C-style (except to `void`); `int64_t{x}` for arithmetic, `std::string(x)` for class types, `static_cast` for sure up/down casts, `const_cast` only to remove const, `reinterpret_cast` only when necessary, `std::bit_cast` for punning.
- Streams only for ad-hoc, local, human-readable I/O; no manipulators/format flags/`imbue()`; prefer logging libraries and `absl::StrCat`/`StrFormat`. Overload `<<` only for value types; use `DebugString()` for debugging.
- Prefix `++i`/`--i` unless the postfix value is used.
- `const` wherever accurate (`const T&` params, `const` methods; all `const` operations thread-safe); no `const` on by-value parameters in declarations. `constexpr` for true constants, `constinit` for guaranteed constant initialization, `consteval` for compile-time-only; never to force inlining.
- Integers: `int` for ordinary values (at least 32 bits); `<stdint.h>` types when size matters; `int64_t` for values that may reach 2^31. Unsigned only for bit patterns/modular arithmetic, never to express non-negativity. Avoid `short`, `long`, `long long`.
- Floating point: only `float` and `double`; never `long double`.
- Portability: no `printf` formatting; addresses in `uintptr_t`; braces for 64-bit constants (`uint64_t{3} << 48`).
- Macros: avoid; prefer inline functions, enums, `constexpr`. If unavoidable: project-prefixed, define right before use and `#undef` right after, none in headers, no `##` name generation.
- `nullptr` for pointers, `'\0'` for the null character. Prefer `sizeof(variable)` over `sizeof(type)`.
- `auto` only when it makes code clearer or safer (obvious types, iterators, lambdas); keep explicit types that carry information; structured bindings for map elements; avoid `decltype(auto)`, `auto` parameters in non-lambda functions, and return-type deduction in public headers.
- CTAD only for templates with an explicit deduction guide (all `std` templates qualify).
- Designated initializers: C++20 form, in declaration order.
- Lambdas: prefer explicit captures if the lambda may escape; `[&]` only when obviously shorter-lived than captures; `[=]` only for short lambdas, never implicitly capturing `this`; no init-captures that introduce new names or shadow; init-captures for move-only variables are fine.
- Templates: avoid metaprogramming (recursive instantiation, type lists, SFINAE, expression templates); hide it from user-facing headers.
- Concepts: sparingly, only where C++17 would have used a template; no new concepts in public headers; prefer standard concepts; use `requires(...)`, not `template<Concept T>` or `enable_if`.
- No C++20 modules. Coroutines only via approved libraries. No Boost unless the project uses it.
- Banned standard headers: `<ratio>`, `<cfenv>`/`<fenv.h>`, `<filesystem>`.
- No nonstandard extensions (`__attribute__`, `__builtin_*`, `#pragma`, inline asm, VLAs, `alloca()`, `a?:b`) except via a project portability header.
- Aliases: `using` over `typedef`; public aliases only if clients should use them, with documented intent; local aliases fine in function bodies, private sections, internal namespaces, `.cc` files.
- Switch: `default` unless switching on an enum; unreachable `default` is an error; annotate fall-through with `[[fallthrough]];`.
- Inclusive language: no master/slave, blacklist/whitelist; use they/them for unspecified people, it/its for software.

## Naming
Clear to a new reader, descriptiveness scaled to scope. Avoid unfamiliar abbreviations; never drop letters within words; capitalize abbreviations as words (`StartRpc()`).
- Files: lowercase with underscores (`my_class.cc`, `my_class_test.cc`); do not reuse `/usr/include` names; be specific.
- Types (classes, structs, enums, aliases, type template parameters, concepts): `PascalCase`.
- Variables and parameters: `snake_case`. Class data members `snake_case_` (trailing underscore); struct members without.
- Constants (`constexpr`/`const` with static storage): `kPascalCase`. Enumerators likewise, never `ENUM_NAME`.
- Functions: `PascalCase`; trivial accessors/mutators may be `snake_case` (`count()`, `set_count()`). Names mirroring a standard entity may follow its convention (`size()`, `empty()`).
- Namespaces: `snake_case`, globally unique top level, never `std`/`absl`.
- Template parameters: types like types, non-types like variables/constants; `T` and `i` are fine for simple cases.
- Macros: `ALL_CAPS_WITH_UNDERSCORES`, project-prefixed.

## Comments
- Use `//` or `/* */` consistently. Write complete sentences with correct punctuation. Explain *why*, not *what*; prefer clear names over comments that explain obscure ones.
- Files: license boilerplate if the project requires it; describe the abstractions when a file declares several.
- Function definitions: explain tricky logic and the approach taken, not what the declaration comment already says.
- Variables: comment class members only when invariants, sentinel values, or lifetimes are not obvious. Document every global: what it is and why it must be global.
- Implementation: comment tricky or important blocks. For unclear call arguments prefer, in order: named constants, enums instead of `bool`, option structs, named variables, finally `/*param=*/` comments.
- TODO: `TODO(identifier): description` (bug ID, name, or email).

### Doxygen (mandatory; overrides Google's "skip trivial comments")
- Every class, struct, enum, function, method, constructor, destructor, and template alias gets a Doxygen comment, including trivial accessors, private/protected members, and `internal` namespaces. **No class or function may be left without a comment.** A missing Doxygen comment is a violation in reviews.
- Use `/** ... */` blocks (`///` only for one-line member docs) with Javadoc-style tags:
  - `@brief` first: one sentence, third-person verb phrase ("Opens the file.").
  - `@tparam` for every template parameter, `@param` for every parameter (add `[in]`, `[out]`, `[in,out]` when direction is not obvious), `@return` for every non-void return value (state what `false`/`nullptr`/error values mean).
  - `@note`, `@warning`, `@pre`, `@post`, `@see`, `@code ... @endcode` where useful: lifetime of reference/pointer arguments, nullability, state changes, complexity, threading, invariants.
  - Overrides use `@copydoc Base::Method` or a short `@brief`; deleted/defaulted special members get a one-line `@brief`.
  - Each header starts with a `@file` / `@brief` block.
- Class comments explain what the class is for, when to use it, threading assumptions, and invariants; a short `@code` usage example is encouraged.

## Formatting
- Max 80 columns (exceptions: unsplittable URLs/comments, includes, header guards, using-declarations). Spaces only, 2 per indent. UTF-8, non-ASCII rare. No trailing whitespace.
- Functions: return type on the name line; no space before `(`; `{` at end of line after one space. Wrapped parameters align with the first one, or break after `(` with a 4-space indent. Unused parameter names omitted or commented (`/*radians*/`). Attributes before the return type.
- Lambdas: format like functions; `[&x]` without space.
- Float literals: digits on both sides of the point, `f` suffix for float (`1.0f`, `1248.0e6`).
- Calls and braced init lists: one line if it fits, else align with the first argument or break after `(` with a 4-space indent; treat `{` like `(`. No spaces inside parentheses.
- `if`/`for`/`while`/`switch`: space after the keyword, none inside parentheses. `} else {` on one line. Braces required; omit only if the statement fits on one line (or two with a break after `)`), never for `if ... else` or `do ... while`. Empty loop bodies `{}` or `continue;`, never a bare `;`.
- Switch: `case 1:` no space before the colon; braced cases as `case 0: {`, `break;` inside the braces.
- Pointers/references: `char* c;`, `const std::string& s;`; no spaces around `.`/`->`; no multi-declarations with pointer/reference variables.
- Boolean expressions: wrap with operators at line ends; use `&&`, `||`, `!`, never `and`/`or`/`not`.
- `return result;` without parentheses. Initialization: `=`, `()`, `{}` all fine; braces prevent narrowing but prefer `initializer_list` constructors.
- Preprocessor directives start at column 0, even inside indented code.
- Class format: `public:`/`protected:`/`private:` indented 1 space, members 2; blank line before each label except the first, none after. Base class on the same line: `class Foo : public Bar {`.
- Constructor initializer lists: one line if it fits; otherwise break before the colon, indent 4 spaces, one member per line.
- Horizontal whitespace: two spaces before end-of-line comments; space before `{`, none before `;`; spaces around assignment and most binary operators; unary operators unspaced (`-5`, `++x`); `Foo() {}` for empty, `void Reset() { x_ = 0; }` otherwise; no spaces in template brackets or casts (`static_cast<char*>(x)`).
- Vertical whitespace: sparingly; none at the start or end of a block; separate logical chunks like paragraphs.

## Exceptions
- Existing non-conformant code: match local conventions; ask the code owner when unsure.
- Windows code: no Hungarian notation, stay close to standard C++ types, no `#pragma once`, wrap `__declspec` in macros, MSVC warning level 3+ with warnings as errors.
