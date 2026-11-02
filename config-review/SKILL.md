---
name: config-review
description: Review configuration files (YAML, JSON, TOML, INI, .properties, .env, appsettings*.json, application*.yml, XML configs) - syntax errors, duplicate keys, YAML pitfalls (yes/no booleans, versions parsed as floats, octal numbers, tabs), keys missing or with different types between environment variants, insecure defaults, machine-specific paths, values hard-coded in code, keys read in code but never defined (and the reverse), missing schema validation and unclear units. Use when asked to check/review/audit config files, settings, environment variables, .env files, YAML/JSON config or "why does my config not work".
---

# Config review

Review only: report findings, never change configuration unless the user explicitly asks. Never print secret values found in configs; refer to `secrets-scan` and mask them (first 4 characters + `***`).

## Scope
Check the files/directories the user names, otherwise all config files in the repo: `*.yml`, `*.yaml`, `*.json`, `*.toml`, `*.ini`, `*.cfg`, `*.conf`, `*.properties`, `.env*`, `*.env`, XML configs (`web.config`, `*.config`, `pom.xml` properties only). Skip lock files (`package-lock.json`, `*.lock`), data files (large JSON/YAML that are not configuration), `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`. Deep checks of `Dockerfile`/`docker-compose.yml`, CI files and Kubernetes manifests are out of scope beyond the general rules.

## Steps
1. Run (no pipe; output is capped): `bash <skill-dir>/scripts/config.sh <project-root> [hitsPerRule=10]`
   - Finds config files and prints `## ID count SEV | desc` + samples: duplicate keys (CF2), YAML/.env pitfalls (CF3), keys that differ between environment variants (CF4/CF5), insecure defaults (CF6), machine-specific paths (CF12).
   - JSON checks (syntax CF1, duplicate keys, nested key comparison) need Python 3; without it the script says so and you check those manually.
2. Verify samples in context: is a "dev-only" file really dev-only? Is a duplicate in YAML really in the same mapping?
3. Compare config keys with the code (CF7, CF8): grep how the code reads configuration (table below) and match against the defined keys.
4. Check schema validation (CF9) and readability (CF10, CF11) in the most important config files.
5. Report (format below).

## How code reads configuration (for CF7/CF8)
| Stack | Reads |
| --- | --- |
| Python | `os.environ["X"]`, `os.getenv("X")`, pydantic `BaseSettings` fields, Django `settings.X`, `config["a"]["b"]` |
| Node / TS | `process.env.X`, `import.meta.env.X`, `config.get("a.b")`, `dotenv` |
| .NET | `Configuration["A:B"]`, `GetSection("A")`, `IOptions<T>` binding (property names = keys), env vars `A__B` |
| Java / Spring | `@Value("${a.b}")`, `@ConfigurationProperties(prefix = "a")`, `Environment.getProperty("a.b")`, env vars `A_B` |
| Go | `os.Getenv("X")`, `viper.Get*("a.b")`, struct tags `mapstructure:"x"` |
| Godot | `ProjectSettings.get_setting("a/b")`, `ConfigFile.get_value("section", "key")` |

## Rules
- CF1 error: syntax error (the file does not parse); info for JSON-with-comments files (`tsconfig.json`, `.vscode/*.json`, `appsettings*.json`) where comments are allowed by the tool
- CF2 error: duplicate key in the same mapping/section - the later value silently wins in most parsers
- CF3 warning: format pitfalls: YAML 1.1 booleans (`yes`/`no`/`on`/`off` unquoted, e.g. country code `NO` → `false`), versions parsed as floats (`1.10` → `1.1`), leading zeros (octal), tabs in YAML indentation; `.env` lines with spaces around `=` or unquoted values with spaces
- CF4 warning: key present in one environment variant but missing in another (`.env` vs `.env.example`; a key in `appsettings.Production.json` / `application-prod.yml` that the base file doesn't know - possible typo)
- CF5 warning: same key with different types between variants (`8080` vs `"8080"`, `true` vs `"true"`, list vs string)
- CF6 error: insecure default in production or default config: debug mode on, CORS `*`, TLS/certificate verification off, default or empty passwords (→ `secrets-scan`), admin interfaces bound to `0.0.0.0` (possible), detailed error pages on
- CF7 warning: environment-specific values hard-coded in code (URLs, hostnames, ports, timeouts, feature flags, credentials → `secrets-scan`)
- CF8 warning: key read in code but defined nowhere (runtime crash or silent fallback); info: key defined but never read (dead config → `dead-code-finder` DD8)
- CF9 info: important configuration without validation at startup (pydantic settings, `ValidateOnStart`/data annotations, `@Validated`, JSON Schema, `zod`/`envalid`)
- CF10 info: unclear units or magic values (`timeout: 30`, `size: 1000`) without unit in the key name or a comment
- CF11 info: very large config without structure or comments; the same value repeated in many places (candidate for one shared key/anchor)
- CF12 warning: machine-specific paths or user names committed (`C:\Users\...`, `/home/<user>`, `/Users/<user>`)

## False positives to drop
Insecure settings in files that are clearly local/dev only (`*.Development.json`, `.env.local`, `docker-compose.override.yml`) - report as info · duplicate keys in different YAML list items or different INI sections (the script tracks these, verify anyway) · `yes`/`no` that are meant as strings in a parser that uses YAML 1.2 (still recommend quoting) · keys that are read dynamically (prefix loops, binding whole sections).

## Report
In the user's language, grouped by file:
```
path/to/file:line - error|warning|info - <ID> <rule> - `key` - <what goes wrong, e.g. "prod has no DB_POOL_SIZE, the app falls back to 1 connection"> - direction: <what should be true afterwards>
```
- Every finding has a concrete location and key. Mask secret values.
- Mark findings that depend on how the app loads config (load order, overrides) as "possible".
- End with a summary: config files and environment variants found, findings per severity, then the 3 most important things to fix first.
- Do not change files. Apply fixes only when the user explicitly asks for it.
