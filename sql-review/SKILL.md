---
name: sql-review
description: Review SQL in application code and .sql/migration files - SQL injection through string building (also in ORM raw queries), UPDATE/DELETE without WHERE, SELECT *, N+1 queries, missing indexes, missing transactions, lost updates, non-sargable predicates, unbounded result sets, NULL pitfalls and risky migrations. Use when asked to check/review/audit SQL, queries, database access code, ORM usage, migrations or "is my query safe/fast".
---

# SQL review

Review only: report findings, never change queries, schemas or migrations unless the user explicitly asks. Never run queries, `EXPLAIN ANALYZE` or migrations against a real database without asking - they can be slow, lock tables or change data.

## Scope
Check the files/directories the user names, otherwise the whole repo: `.sql` files, migrations (`migrations/`, `db/migrate/`, Flyway `V*__*.sql`, Liquibase, EF `Migrations/`, Alembic `versions/`), and code that builds or runs queries. Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`, generated code (EF model snapshots, ORM-generated clients) and seed/test data dumps.

## Steps
1. Detect the database (connection strings, drivers, migration tool, dialect hints) and the data access stack (table below).
2. Find query construction: grep for `SELECT|INSERT|UPDATE|DELETE` in strings, raw-query APIs (`execute`, `query`, `raw`, `FromSqlRaw`, `$queryRawUnsafe`, `createNativeQuery`, `text(`), and string building near them (`+`, f-strings, `%`, `.format`, `${}`, `Sprintf`, `String.format`, `$"..."`).
3. For each query, trace where the dynamic parts come from (user input, config, constants) and check SQ1-SQ14.
4. Read the schema (migrations, DDL, ORM models) for SQ5/SQ10. Without a schema, SQ5 findings are "possible".
5. Use a linter if installed (never install it; mention it if it would help): `sqlfluff lint` for .sql files, `squawk` for Postgres migrations, `semgrep` with SQL injection rules.
6. Report (format below).

## Rules
- SQ1 error: SQL injection - dynamic values concatenated/formatted into the query instead of bound parameters (also inside ORM raw APIs). Dynamic identifiers (table, column, `ORDER BY`, `ASC/DESC`) can't be parameterized and need an allowlist.
- SQ2 error: `UPDATE`/`DELETE` without `WHERE`, or with a `WHERE` clause that can end up empty when built dynamically
- SQ3 warning: `SELECT *` in application code (over-fetching; breaks mapping when the schema changes)
- SQ4 warning: N+1 - a query inside a loop over the results of another query; ORM lazy loading inside loops
- SQ5 warning: missing index (possible) for columns used in frequent `WHERE`/`JOIN`/`ORDER BY`; foreign keys without index
- SQ6 error: multi-statement write that must be atomic without a transaction; warning: transaction kept open during network calls or user interaction
- SQ7 warning: lost update - read value, compute, write back without locking or version check (`SELECT` then `UPDATE` with the computed value)
- SQ8 warning: non-sargable predicate or implicit conversion: function on an indexed column (`WHERE LOWER(email) = ?`, `DATE(created_at) = ?`), leading wildcard `LIKE '%x'`, comparing text to number
- SQ9 warning: unbounded result set for user-facing lists (no `LIMIT`/pagination); `LIMIT` without `ORDER BY` (non-deterministic pages)
- SQ10 warning: risky migration: long table locks (index creation without `CONCURRENTLY`/`ONLINE`, rewriting large tables, adding `NOT NULL` without default on large tables depending on DB version), no down/rollback path, schema and data changes mixed
- SQ11 error: `= NULL` / `<> NULL` instead of `IS NULL`; warning: `NOT IN (subquery)` where the subquery can return `NULL` (returns no rows)
- SQ12 warning: connections/cursors not closed or no pool → `error-handling-review` EH6; credentials in connection strings → `secrets-scan`
- SQ13 info: `DISTINCT`/`GROUP BY` used to hide duplicate rows from a wrong join
- SQ14 info: dialect-specific syntax in a project that claims to support several databases

## Safe vs. unsafe per stack
| Stack | Safe | Unsafe (SQ1) |
| --- | --- | --- |
| JDBC | `PreparedStatement` with `?` | `Statement.execute("..." + x)` |
| JPA / Hibernate | `setParameter`, Criteria API | `createQuery`/`createNativeQuery` with concatenation |
| ADO.NET / Dapper | `SqlParameter`, Dapper `new { id }` | interpolation into `CommandText` |
| EF Core | LINQ, `FromSql($"...")`, `FromSqlInterpolated` | `FromSqlRaw`/`ExecuteSqlRaw` with a pre-built string |
| Python DB-API (sqlite3, psycopg) | `cur.execute(sql, params)` with `?`/`%s` | f-string, `%`, `.format` into `sql` |
| SQLAlchemy | `text("... :id")` with bind params, ORM | `text(f"...")` |
| Django | ORM, `raw(sql, params)` | `raw(f"...")`, `extra()` with strings |
| node-postgres / mysql2 | `query(text, values)` with `$1`/`?` | template literal into `text` |
| Prisma | `` $queryRaw`...${x}` `` (tagged) | `$queryRawUnsafe` with concatenation |
| Knex | query builder, `raw('?', [x])` | `` raw(`... ${x}`) `` |
| Go `database/sql`, GORM | `Query(sql, args...)`, `Where("x = ?", v)` | `fmt.Sprintf` into `Query`/`Where` |
| PHP PDO | `prepare` + `execute` | `query("..." . $x)` |

## False positives to drop
Concatenation of constant strings only (no external input) · identifiers from a hard-coded allowlist · `SELECT *` in ad-hoc scripts, `EXISTS (SELECT * ...)` and `COUNT(*)` · N+1 on tiny bounded lists (report as info) · migrations for tables that are known to be small.

## Report
In the user's language, grouped by file:
```
path/to/file:line - error|warning|info - <ID> <rule> - <what can happen, e.g. "name=' OR 1=1 -- returns all users"> - direction: <what the fix must achieve, e.g. "bind the value as a parameter">
```
- Every finding has a concrete location; for SQ1 name the source of the dynamic value. Don't write working attack payloads beyond a minimal illustration like the one above.
- Mark findings that depend on unknown data size or schema as "possible".
- Bulk hits with one root cause (e.g. one query helper that concatenates): report once with count and 2-3 call sites.
- End with a summary: database and access stack, findings per severity, then the 3 most important things to fix first.
- Do not change code. Apply fixes only when the user explicitly asks for it.
