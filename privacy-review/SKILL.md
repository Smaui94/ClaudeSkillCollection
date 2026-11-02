---
name: privacy-review
description: Technical privacy review of code under the GDPR - builds an inventory of the personal data the code collects, stores and sends, then checks data minimization, deletion and retention, access/export paths, third-party recipients (analytics, tracking, error reporting, CDNs, AI APIs), tracking before consent, personal data in logs, URLs and client storage, unprotected special categories, IP/device IDs, real personal data in test fixtures and privacy by default. Not legal advice. Use when asked to check/review/audit privacy, data protection, GDPR/DSGVO compliance of code, personal data handling, tracking or cookies.
---

# Privacy review (GDPR, technical)

Review only: report findings, never change code unless the user explicitly asks. This is a **technical** review of what the code does with personal data - not legal advice. Whether a processing is lawful (legal basis, contracts with processors, privacy policy, records of processing) is out of scope; mention obviously missing pieces, and recommend a data protection officer or lawyer for the legal assessment.

Sources: GDPR text https://eur-lex.europa.eu/eli/reg/2016/679/oj · ePrivacy Directive Art. 5(3) (Germany: § 25 TDDDG) for cookies and device storage.

## Scope
Check the files/directories the user names, otherwise the whole repo: data models, database schemas/migrations, forms, API handlers, analytics/tracking code, logging, client-side code, third-party SDK setup, config files, test fixtures and seed data. Skip `.git/`, build output, `vendor/`, `node_modules/`, `.venv/` and generated code.

## Steps
1. **Data inventory** (always first): find personal data fields in models, schemas, DTOs, forms, API payloads and analytics events (name patterns below). For each: where it is collected, stored, sent, logged, and whether deletion exists.
2. **Recipients**: list every third party that receives personal data (SDKs, API clients, script tags, fonts/CDNs, webhooks, AI/LLM APIs, email/SMS providers), with the data sent and whether it may leave the EU/EEA.
3. Check PV2-PV14 against the inventory.
4. Report (format below), starting with the inventory table.

## Field name patterns (starting points, also German names)
| Category | Patterns |
| --- | --- |
| Identity | `name`, `first_name`, `last_name`, `vorname`, `nachname`, `username`, `birth`, `dob`, `geburtsdatum`, `gender`, `geschlecht`, `photo`, `avatar` |
| Contact | `email`, `mail`, `phone`, `telefon`, `mobile`, `address`, `street`, `strasse`, `zip`, `postal`, `plz`, `city` |
| Online IDs | `ip`, `ip_address`, `user_agent`, `device_id`, `imei`, `idfa`, `gaid`, `advertising_id`, `cookie_id`, `session_id`, `fingerprint` |
| Location | `lat`, `lng`, `latitude`, `longitude`, `location`, `geo`, `gps` |
| Financial / official | `iban`, `bic`, `card`, `pan`, `cvv`, `salary`, `tax_id`, `steuer`, `ssn`, `passport`, `id_card`, `ausweis`, `national_id` |
| Special categories (Art. 9) | `health`, `diagnosis`, `medical`, `disability`, `religion`, `ethnic`, `race`, `political`, `union`, `sexual`, `biometric`, `face`, `fingerprint`, `genetic` |
| Minors | `child`, `kid`, `age`, `parent`, `guardian` |

## Rules
- PV1 info: data inventory (table in the report; not a defect)
- PV2 warning: personal data collected or stored without a visible purpose, or never used afterwards - data minimization, Art. 5(1)(c) (possible)
- PV3 warning: stored personal data with no deletion or retention logic (no delete endpoint, no cleanup job, soft delete that keeps everything forever) - storage limitation Art. 5(1)(e), right to erasure Art. 17
- PV4 info: user accounts exist but no way to export a user's data - right of access Art. 15, portability Art. 20
- PV5 warning: personal data sent to a third party (analytics, tracking pixels, error reporting with user context or `sendDefaultPii`, externally loaded fonts/CDN scripts that transfer the IP, AI/LLM APIs, marketing tools) - list recipient and data; flag possible transfers outside the EU/EEA (Art. 44 ff.) as "check"
- PV6 error: tracking, analytics or other non-essential cookies/local storage/SDKs initialized before consent - ePrivacy Art. 5(3), § 25 TDDDG
- PV7 error: personal data in logs → `logging-review` LG4
- PV8 warning: personal data in URLs or query strings (ends up in server logs, browser history, referrer headers)
- PV9 warning: personal data or tokens in client-side storage (`localStorage`, `sessionStorage`, unencrypted mobile prefs) without need; error for special categories
- PV10 error: special categories (Art. 9), official IDs or financial data stored or transmitted without encryption (at rest: field/DB encryption; in transit: TLS); warning for ordinary personal data stored where protection is clearly expected (possible)
- PV11 warning: IP addresses, device IDs or precise location stored without need, or kept longer than needed / not truncated or anonymized
- PV12 warning: test fixtures, seed data or screenshots with real-looking personal data - use synthetic data
- PV13 info: easy pseudonymization not used (analytics events with e-mail or raw user ID instead of a pseudonymous ID) - Art. 25, Art. 32
- PV14 info: privacy by default not met - optional data collection on by default, opt-out instead of opt-in, pre-checked consent boxes (Art. 25(2))
- PV15 info: obviously missing privacy documentation (no privacy policy page or link in an app that collects data) - out of scope for the code, mention only

Related skills: secrets → `secrets-scan`; security of stored data → `owasp-security-review`; third-party packages → `dependency-audit`.

## False positives to drop
Fields with personal-sounding names that hold no personal data (`file_name`, `host_name`, `email_template`) · business contact data of companies (still mention if combined with persons) · local development tools that never run in production · data that is demonstrably anonymous (aggregates without IDs) · consent-gated code where the gate is visible (name it).

## Report
In the user's language:
1. Data inventory table: field | where collected | stored in | sent to | logged | deletion | category.
2. Recipients table: recipient | data | purpose (if visible) | possible non-EU transfer.
3. Findings, grouped by file:
```
path/to/file:line - error|warning|info - <ID> <rule> - <data> - <what happens to it and why it is a risk> (GDPR Art. <n>)
```
- Every finding has a concrete location. Never copy real personal data into the report; name the field instead.
- Mark findings whose purpose or legal basis can't be seen from the code as "possible".
- End with a summary: data categories found, number of recipients, findings per severity, the 3 most important things to fix first, and the note "technical review, not legal advice".
- Do not change code. Apply fixes only when the user explicitly asks for it.
