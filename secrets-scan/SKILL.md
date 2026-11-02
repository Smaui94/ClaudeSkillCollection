---
name: secrets-scan
description: Scan code, config files and optionally git history for leaked secrets - passwords, API keys, tokens, private keys, connection strings with credentials, committed .env and key files - and check .gitignore. Found secrets are always masked, never printed in full. Use when asked to scan/check/audit for secrets, credentials, API keys, passwords or tokens in a repo, or before publishing/open-sourcing a repository.
---

# Secrets scan

Review only: report findings, never change files, rewrite history or rotate keys yourself.

## Masking (strict)
- Never print a found secret in full - not in the report, not in a summary, not in a command you suggest. Show at most the first 4 characters followed by `***` (e.g. `AKIA***`, `ghp_***`).
- Don't copy secret values into other files, issues or commit messages.
- When you read a file to verify a hit, quote only the key name and the masked value.

## Scope
Check the whole repo unless the user names files/directories. Skip `.git/` internals (history is scanned separately), `node_modules/`, `vendor/`, `.venv/`, build output, lock files and minified files. Include config files, scripts, notebooks, Dockerfiles, CI files (`.github/workflows`, `.gitlab-ci.yml`) and docs.

## Steps
1. Run (no pipe; output is capped): `bash <skill-dir>/scripts/scan.sh <project-root> [hitsPerRule=20]`
   - Runs `gitleaks` (redacted) if installed, plus grep patterns SC1-SC4 (masked), SC5 committed sensitive files and SC6 `.gitignore` gaps.
   - `HISTORY=1 bash .../scan.sh <root>` also scans the full git history (SC7). Ask before running it on very large repos; it can take a while.
   - No gitleaks installed: the script says so. Tell the user that gitleaks (https://github.com/gitleaks/gitleaks) finds more secret types, then continue. Never install anything yourself.
2. Verify each hit by reading the surrounding lines: real value, placeholder, test fixture or reference to an environment variable?
3. Look manually for what patterns miss: long random-looking strings assigned to config keys (SC8), credentials in URLs inside docs, secrets in notebooks' outputs, base64 blobs in configs.
4. Report (format below) and give the remediation steps.

## Rules
- SC1 error: known provider token format (AWS, GitHub, GitLab, Slack, Google, Stripe, Anthropic, OpenAI, SendGrid, npm …)
- SC2 error: private key (`-----BEGIN ... PRIVATE KEY-----`)
- SC3 error: credentials in a connection string / URL (`scheme://user:password@host`)
- SC4 warning: password/secret/token/API key assigned a literal value in code or config - "possible" until verified
- SC5 error: sensitive file tracked by git (`.env`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `id_rsa`, `credentials.json`, `secrets.yaml` …); `.npmrc`/`.pypirc` only if they contain a token
- SC6 warning: `.gitignore` does not ignore `.env`, key files or `id_rsa`
- SC7 error: secret in git history - still exposed even if deleted from the current files
- SC8 info: high-entropy string that looks like a secret (manual)

## False positives to drop
Placeholders (`changeme`, `xxx`, `<your-api-key>`, `${API_KEY}`, `{{ secret }}`, `example`, `dummy`) · documented example keys (`AKIAIOSFODNN7EXAMPLE`) · public keys and certificates (`BEGIN PUBLIC KEY`, `BEGIN CERTIFICATE`) · hashes and checksums · test fixtures with obviously fake values (report as info if they look real). The script already skips placeholder-looking matches and prints how many it skipped.

## Remediation (include in the report when anything real is found)
1. **Rotate/revoke the secret first.** Once it was pushed, deleting it does not make it safe again.
2. Remove it from the code; load it from environment variables or a secret manager (e.g. GitHub Actions secrets, Vault, cloud key vaults); commit only a `.env.example` with placeholders.
3. Add the files to `.gitignore`; untrack committed ones with `git rm --cached <file>`.
4. If it is in the history and the repo is (or will be) public: rewrite history with `git filter-repo` or BFG, force-push, and ask collaborators to re-clone - explain that this is disruptive and must be coordinated. Do not run it yourself.
5. Prevent recurrence: a pre-commit hook (`gitleaks protect --staged`) or GitHub secret scanning / push protection.

## Report
In the user's language, grouped by file:
```
path/to/file:line - error|warning|info - <ID> <rule> - <key name> = <first 4 chars>*** - <why it is a problem>
```
- Every finding has a concrete location (`commit:file` for SC7). Unverified SC4/SC8 hits are "possible".
- End with a summary: findings per severity, whether the history was scanned, then the remediation steps for the real findings, most urgent first.
- Do not change files. Apply changes only when the user explicitly asks for it, and never print the secret while doing so.
