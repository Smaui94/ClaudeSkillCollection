---
name: dependency-audit
description: Audit project dependencies - detect package manifests (requirements.txt, pyproject.toml, package.json, pom.xml, build.gradle, *.csproj, vcpkg/conan, Cargo.toml, go.mod …) and report known vulnerabilities, outdated and unpinned versions, missing lock files, unused, duplicate or misplaced dependencies. Never updates anything. Use when asked to check/audit dependencies, packages, libraries, vulnerable or outdated packages, or supply-chain hygiene.
---

# Dependency audit

Review only: report findings and suggest commands, never install, update, add or remove dependencies yourself. Vulnerability checks contact public advisory databases; mention that, and skip them with `OFFLINE=1` if the user doesn't want network access.

## Scope
All manifests in the repo unless the user names a subproject. Skip `node_modules/`, `vendor/`, `.venv/`, build output and example/fixture projects inside tests (report them separately if they look shipped).

## Steps
1. Run (no pipe; output is capped): `bash <skill-dir>/scripts/audit.sh <project-root>`
   - Lists manifests, missing lock files (DP4) and unpinned versions (DP3).
   - Runs the audit tools that are installed: `osv-scanner`, `pip-audit`, `npm audit` / `npm outdated`, `dotnet list package --vulnerable/--outdated`, `cargo audit`, `govulncheck`, `bundle-audit`, `composer audit`. Missing tools are listed with what they would add. Never install them yourself.
   - `OFFLINE=1` skips all tools that need the network.
2. Without tool output for an ecosystem: read the manifest and report versions that are clearly very old or end-of-life only when you are sure; otherwise recommend the matching tool (Maven/Gradle: OWASP `dependency-check` or `osv-scanner`; C/C++: `osv-scanner` on vcpkg/conan files, or check versions manually).
3. DP5 unused: for each declared dependency, grep for its import/package name in the source (`import x`, `require('x')`, `from x`, `using X`, `#include <x/...>`). Remember that package name and import name can differ (`beautifulsoup4` → `bs4`, `Pillow` → `PIL`, `python-dateutil` → `dateutil`).
4. Report (format below).

## Rules
- DP1 error: known vulnerability (CVE/GHSA/OSV ID); severity from the advisory - critical/high = error, moderate = warning, low = info. Note whether a fixed version exists and whether the vulnerable code path is likely used.
- DP2 warning: major version(s) behind or end-of-life; info: minor/patch behind
- DP3 warning: unpinned or floating version in an application (`*`, `latest`, no version, `>=` without upper bound, Maven `LATEST`/`RELEASE`/ranges, Gradle `+`, NuGet `*`); libraries may use ranges (info)
- DP4 warning: no lock file for an application (`package-lock.json`/`yarn.lock`/`pnpm-lock.yaml`, `poetry.lock`/`uv.lock`/pinned requirements, `Cargo.lock`, `go.sum`, `Gemfile.lock`, `composer.lock`; vcpkg `builtin-baseline`)
- DP5 info: declared but apparently unused - always "possible" (plugins, CLI tools, type stubs, peer deps are used without imports)
- DP6 warning: duplicate or conflicting declarations (same package in several manifests with different versions, in both `dependencies` and `devDependencies`)
- DP7 warning: dev/test tool in production dependencies (`pytest`, `jest`, `eslint`, `@types/*`, `junit` without `test` scope) or a runtime package only in dev dependencies
- DP8 info: deprecated or unmaintained package (npm deprecation notice, archived repo, no release for years) - only when the tool output or registry says so
- DP9 info: license that may conflict with the project license (GPL/AGPL in a proprietary or MIT project) - only when the license is known

## Report
In the user's language, grouped by manifest:
```
path/to/manifest:line - error|warning|info - <ID> <rule> - <package> <version> - <advisory ID / why it is a problem> - suggestion: <fixed version or command for the user to run>
```
- Every finding has a concrete manifest (and line where possible). DP5 and estimated DP2 findings are "possible".
- Suggest update commands only as text for the user (e.g. `npm install lodash@4.17.21`, `pip install "requests>=2.32.0"`), and mention that major updates can break the build and need testing.
- End with a summary: manifests checked, which ecosystems had no tool coverage, findings per severity, then the 3 most important updates to do first.
- Do not change any files. Apply changes only when the user explicitly asks for it.
