---
name: markdown-readme-google-style
description: Apply the Google README guidelines (https://google.github.io/styleguide/docguide/READMEs.html) when writing, editing, or reviewing README.md files and the Markdown documentation of a project. Use for any README work, when creating a new package/directory, and when asked to check READMEs against Google style.
---

# Google README guidelines

Source: https://google.github.io/styleguide/docguide/READMEs.html

Follow the rules below when writing or changing README files. When reviewing, report violations as `path - rule - fix`. If a project already has stricter or different documentation conventions, match them unless the user asks otherwise. The source covers READMEs only; for general Markdown formatting see https://google.github.io/styleguide/docguide/style.html.

## File
- Name the file exactly `README.md`: the `.md` extension is required and the name is case-sensitive.
- Make sure `README.md` of a directory renders when that directory is viewed on the hosting site (e.g. GitHub, Codeberg).
- Keep `README.md` on the default branch (`HEAD`) so the repository index shows it.

## Where
- Put a `README.md` in the top-level directory of the product or library codebase.
- Do not put it inside the product's documentation directory.
- Give every top-level directory of a code package an up-to-date `README.md`.
- Keep READMEs current first for directories that expose interfaces to other teams or users.

## What
- Include at least a link to user- and/or team-facing documentation.
- Every package-level `README.md` includes or links to:
  1. What the package or library contains and what it is used for.
  2. Points of contact (name, issue tracker, or team channel; do not publish private e-mail addresses without the owner's consent).
  3. Status, e.g. deprecated or not for general release.
  4. How to use it, with sample code, copyable build/test commands, or similar.
  5. Links to relevant documentation.
- Directory-level READMEs stay short: what is in the directory, how it is used, and links to the details instead of repeating them.

## Review checklist
- Does every top-level directory of the code package have a `README.md`?
- Does each README answer items 1 to 5 above or link to where they are answered?
- Are all links and commands valid and current (paths exist, commands run)?
- Does the README list the directory contents as they actually are?
