---
name: java-google-style
description: Audit a Java project/files for compliance with the Google Java Style Guide (https://google.github.io/styleguide/javaguide.html) plus mandatory Javadoc on every class, method and constructor, and report violations. Also apply these rules when writing or editing Java (.java). Use when asked to check/review/lint Java code against Google style or Javadoc completeness.
---

# Google Java Style + mandatory Javadoc

Audit: script first, read code only where needed; don't edit unless asked. Writing Java: follow the rules below; in legacy code match the file's style unless a migration is requested.

## Audit steps
1. Run (no pipe; output is capped): `bash <skill-dir>/scripts/check.sh <project-root> [hitsPerRule=8]`
   - Needs bash + GNU grep -P + gawk (Git Bash ok). `JDOC_SCOPE=visible` limits D1-D8 to public/protected (Guide minimum) instead of all.
   - Output: `## ID count SEV | desc` + samples `file:line:code|message`. Heuristic → spot-check samples, drop false positives (list below).
2. Bulk formatting hits (F1/F3/F8 hundreds) = one root cause (IDE 4-space/Allman settings): report once, suggest `google-java-format --replace` (or Checkstyle `google_checks.xml`).
3. Review ★ rules in ≤5 representative files (largest/core classes).
4. Report (user's language): table Category | ID | Count | SEV; top findings `file:line - rule - fix` (≤15, bulk as one line); fix order: Javadoc gaps → MUST code rules → SHOULD.

## Rules (ID → script; ★ manual)
Source file
- O1 file name = the single top-level class · O2 `package` present, never wrapped · UTF-8; F15 use `\n` `\t` … not octal/`\u` escapes; non-ASCII: real char or `\u` (whichever is clearer)
- Order: license → package → imports → class, one blank line between
- O3w no wildcard/module imports · O4 static group, one blank line, non-static group; ASCII-sorted names; no other blank lines; imports never wrapped; no static import of nested classes ★
- ★ logical member order (not "append at end") · O3 overloads/constructors contiguous

Formatting
- F5/F5b braces always for if/else/for/do/while · F3/F4/F7 K&R: `{` at line end, `} else {`, `} catch (…) {`; empty `{}` ok except in if/else, try/catch/finally
- F8 block indent +2 (comments too); continuation ≥ +4 · F1 no tabs · F2 ≤100 cols (except package/import, URLs, text blocks)
- F10 one statement per line · F11 one variable per declaration (except for-header) · F12 `String[] args` not `String args[]`
- F14 break before non-assignment operators and `.` `::` `&` `|`; after `=` ok; method name stays with `(`, comma with preceding token; no break at `->` (except after it, single expression)
- F6 space between keyword and `(`; spaces around binary/ternary ops, `->`, foreach `:`; none around `.` `::`; after `,` `;` and cast `)` ★
- ★ blank line between members (optional between fields) · alignment never required · grouping parens recommended
- Switch: labels +2, old-style statements +2 more; P6 fall-through commented (`// fall through`); P5 every switch exhaustive (add `default`); switch expressions use `->`
- F17 class/method annotations after Javadoc, one per line (single parameterless method annotation may share the line); fields may share
- Enums: one-line `enum Suit { A, B }` only without methods/docs · F13 `long` with `L` · text block `"""` on new line, closing `"""` own line, same indent
- F16 modifiers: `public protected private abstract default static final sealed non-sealed transient volatile synchronized native strictfp`
- Comments: `/* */` with aligned `*`, no boxes; F18 `// TODO: <link> - <text>`

Naming (ASCII letters/digits only)
- N1 classes UpperCamelCase (tests end in `Test`) · N2 methods lowerCamelCase (JUnit may use `a_b`) · N6 packages all lowercase, no `_`
- N3 `UPPER_SNAKE_CASE` only for static final + deeply immutable (primitives, String, immutable types, `null`); `Logger`, `HashMap`, mutable arrays → lowerCamelCase
- N4 other fields, N7 params, N7l locals (also `final`) lowerCamelCase; avoid 1-char params in public methods ★
- N5 no prefixes/suffixes (`mName`, `kName`, `s_name`, `name_`) · N9 type vars `T`, `T2` or `FooT` · `_` for unnamed vars ok
- N8 acronyms as words: `XmlHttpRequest`, `customerId`, `supportsIpv6OnIos`

Practices
- P1 `@Override` wherever legal (script checks equals/hashCode/toString; others ★) · P2 caught exceptions never ignored; empty catch needs a reason comment
- ★ static members via class name (`Foo.m()`, not `foo.m()`) · P4 no `finalize`

Javadoc (project rule, stricter than Guide 7.3)
- D1 EVERY class/interface/enum/record/annotation type (incl. nested, private) and EVERY method and constructor has Javadoc (`/** … */` or `///`). Overrides: `/** {@inheritDoc} */` suffices. D9 visible fields too. Turn `//`/`/* */` descriptions of a declaration into Javadoc.
- D2 `@param` for each parameter (records: each component in class doc; generics `@param <T>` allowed); none for missing params
- D3 non-void: `@return …` or `{@return …}`; void/ctor: no `@return` · D4 `@throws Type desc` for each declared `throws`
- D5 order `@param` → `@return` → `@throws` → `@deprecated` · D6 those tags never empty
- D7 summary fragment first: capitalized, ends with `.`, 3rd person ("Returns the id.", not "Return the id.", not "This method returns…", not "A Foo is…", not only `@return`)
- D8 basic form: `/**` alone, ` * ` lines, ` */` alone; single-line `/** Text. */` only without block tags; blank ` *` line between paragraphs and before tags; paragraphs 2+ start with `<p>` (no space after; not before `<ul>`/`<table>`); tag continuation +4 (`///`: +2)

Template:
```java
/**
 * Returns the order with the given ID.
 *
 * <p>Results are cached.
 *
 * @param orderId the order ID, never null
 * @return the order, or empty if unknown
 * @throws IOException if the store cannot be read
 */
```

## False positives to drop
F2/F8/F14 inside multi-line string concatenation or text blocks · F3 standalone scope block `{` after a statement · F5b `if` wrapped over several lines · F12 in generics/annotations · N3 constants of immutable custom types (judge immutability) · N8 2-letter words at name end (`PointXY`) · P5 enum switch covering all constants · D1/D2 in generated code (exclude dirs) · anonymous-class methods are not doc-checked (review ★).
