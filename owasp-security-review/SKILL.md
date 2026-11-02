---
name: owasp-security-review
description: Code-level security review of a whole codebase or named files based on the OWASP Top 10 and OWASP ASVS - injection, XSS, broken access control and IDOR, authentication and session flaws, weak crypto, insecure deserialization, SSRF, path traversal, unsafe uploads, CSRF, XXE, open redirects and security misconfiguration - with the attack scenario for each finding but no exploit payloads. Use when asked for a security review/audit of code, OWASP check, "is my code secure", vulnerability review or secure coding review (for reviewing only the pending branch diff, Claude Code's built-in security-review also exists).
---

# OWASP security review

Review only: report findings, never change code unless the user explicitly asks. Describe the attack, not the weapon: no working exploit payloads, no step-by-step exploitation, no scanning or attacking of running systems.

Sources: https://owasp.org/Top10/ · https://owasp.org/www-project-application-security-verification-standard/ · https://cheatsheetseries.owasp.org/

## Scope
Check the files/directories the user names, otherwise the whole repo. Focus on code reachable from external input. Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/`, generated code; tests only when they reveal production behavior.

Related skills (point to them instead of repeating their rules): SQL injection → `sql-review`; secrets in code → `secrets-scan`; vulnerable dependencies → `dependency-audit`; leaking error messages → `error-handling-review`; missing security logging → `logging-review`.

## Steps
1. Map the attack surface: entry points (HTTP routes, controllers, CLI args, message consumers, file imports, webhooks), auth mechanism, frameworks and their security defaults.
2. For each entry point trace data from **source** (request params, headers, cookies, body, uploaded files, external messages) to **sink** (shell, file system, HTML output, deserializer, URL fetcher, redirect, query, template).
3. Check access control on every state-changing or data-returning entry point (SE3).
4. Grep for dangerous sinks (table below) to catch what tracing missed. Use `semgrep --config auto` or the framework's analyzer if installed (never install; mention if it would help).
5. Report (format below).

## Rules (with OWASP category)
- SE1 error (Injection): OS command (`shell=True`, `Runtime.exec`/`ProcessBuilder` with concatenation, `child_process.exec`, `system()`), template injection, LDAP/XPath, NoSQL (`$where`, operator objects from user JSON), `eval`/`Function`/`exec` on input
- SE2 error (Injection/XSS): untrusted data rendered unescaped: `innerHTML`, `dangerouslySetInnerHTML`, `v-html`, `{@html}`, `document.write`, `|safe`, `Html.Raw`, `th:utext`, HTML built by string concatenation, `href` from input without scheme check (`javascript:`)
- SE3 error (Broken Access Control): entry point without authentication/authorization check; IDOR (object loaded by an ID from the request without an ownership check); authorization only in the UI; mass assignment (request body bound directly to an entity incl. `isAdmin`/`role`)
- SE4 error (Authentication Failures): passwords stored plain or with fast hashes (MD5, SHA-1, unsalted SHA-256) instead of Argon2/bcrypt/scrypt/PBKDF2; JWT decoded without signature verification or `alg: none` accepted; session not renewed after login; warning: no rate limiting/lockout on login (possible); secrets compared with `==` (timing)
- SE5 error (Cryptographic Failures): ECB mode, static/reused IV or nonce, DES/RC4, `Math.random`/`random`/`rand()` for tokens or IDs; TLS verification disabled (`verify=False`, `rejectUnauthorized: false`, `InsecureSkipVerify`, certificate callbacks returning `true`)
- SE6 error (Data Integrity Failures): deserializing untrusted data with `pickle`, `yaml.load` (not `safe_load`), `ObjectInputStream`, `BinaryFormatter`, PHP `unserialize`, Json.NET `TypeNameHandling.All/Auto`
- SE7 error (SSRF): server fetches a user-supplied URL without allowlist (incl. redirects, internal IPs, cloud metadata endpoints)
- SE8 error (Broken Access Control): path traversal - file paths built from input without canonicalizing and checking the base directory; zip slip when extracting archives
- SE9 warning: unsafe file upload - no type/size check, stored in the web root, original filename used as path
- SE10 warning (CSRF): state change via `GET`; cookie-based auth without CSRF token / `SameSite`; CSRF protection disabled
- SE11 warning (Security Misconfiguration): debug mode on in production config, CORS `*` together with credentials, cookies without `Secure`/`HttpOnly`/`SameSite`, missing security headers (CSP, HSTS, `X-Content-Type-Options`) where the app sets headers, default credentials
- SE12 warning: open redirect - redirect target taken from input without allowlist
- SE13 error (XXE): XML parsers with external entities/DTDs enabled (`DocumentBuilderFactory` defaults, `XmlDocument` with resolver, `lxml` `resolve_entities=True`)
- SE14 warning (Integrity): downloading and executing code without verification (`curl | sh`), loading plugins/modules by name from input
- SE15 info (Insecure Design): missing limits that enable abuse (no size limits on requests/uploads, unbounded loops on user input) - possible

## Dangerous sinks to grep (starting points)
| Language | Sinks |
| --- | --- |
| Python | `subprocess(..., shell=True)`, `os.system`, `eval`, `exec`, `pickle.load`, `yaml.load`, `open(` with request data, `requests.get(` with user URL, `render_template_string`, `\|safe`, `verify=False` |
| JS / TS | `child_process.exec`, `eval`, `new Function`, `innerHTML`, `dangerouslySetInnerHTML`, `v-html`, `res.redirect(req.`, `fetch(`/`axios(` with user URL, `fs.*(` with request data, `rejectUnauthorized: false` |
| Java / Kotlin | `Runtime.exec`, `ProcessBuilder`, `ObjectInputStream`, `DocumentBuilderFactory`, `new File(` with input, `sendRedirect`, `Cipher.getInstance("AES")` (ECB default), `MessageDigest.getInstance("MD5")` |
| C# | `Process.Start`, `BinaryFormatter`, `TypeNameHandling`, `Html.Raw`, `XmlDocument`, `Path.Combine` with input, `Redirect(` with input, `MD5.Create` |
| PHP | `exec`, `system`, `shell_exec`, `eval`, `unserialize`, `include $`, `echo $_GET` |
| Go | `exec.Command("sh", "-c", ...)`, `template.HTML(`, `http.Get(` with user URL, `filepath.Join` with input, `InsecureSkipVerify` |
| C / C++ | `system`, `popen`, `sprintf`/`strcpy` into fixed buffers, format strings from input (`printf(user)`) |

## False positives to drop
Values that are constants or come from trusted config only · sinks behind a proper allowlist or sanitizer (name it) · framework auto-escaping that is active (React JSX, Razor, Jinja2 autoescape) unless explicitly bypassed · test code that never ships · admin-only tools where the user explicitly accepts the risk (still report as info).

## Report
In the user's language, grouped by file, most severe first:
```
path/to/file:line - error|warning|info - <ID> <OWASP category> - source: <input> → sink: <call> - <attack scenario in one sentence, e.g. "a logged-in user can read other users' invoices by changing the id"> - direction: <what the defense must achieve>
```
- Every finding has a concrete location and a source → sink path. Mark findings with unclear reachability as "possible".
- No exploit payloads, no weaponized requests; at most a minimal description of the malicious input class.
- End with a summary: attack surface (entry points, auth), findings per severity, then the 3 most important things to fix first. Recommend a professional penetration test for production systems handling sensitive data - a static review is not a security guarantee.
- Do not change code. Apply fixes only when the user explicitly asks for it.
