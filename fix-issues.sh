#!/usr/bin/env bash
#
# Fixes the findings of a run-skills report with Claude Code.
#
# Reads a report written by run-skills.sh/.cmd (-o FILE), takes the project
# path from its header (or from the command line) and starts Claude Code
# non-interactively in the project. Claude may read and edit files inside the
# project directory only. It does not commit, push or rewrite git history.
#
# No "set -e": git commands that find nothing are expected, non-fatal results.
set -u

#######################################
# Prints the usage text.
# Outputs:
#   Usage on stdout.
#######################################
usage() {
  cat <<'EOF'
Usage: fix-issues.sh [options] <report.md> [project_dir]

Fixes the findings in report.md (written by run-skills -o) in the project.
The project directory is read from the report header unless given.

Options:
  -s LEVEL        minimum severity to fix: error, warning (default) or info
  -f TEXT         fix only these findings, e.g. "SC1,EH1" or "only secrets-scan"
  -t COMMAND      test/build command Claude may run to check the fixes,
                  e.g. "npm test" or "pytest"
  -o FILE         also write Claude's change summary to FILE
  -l LANG         language of the summary (default: English)
  -m MODEL        Claude model (default: Claude Code's default)
  -x TEXT         extra instructions
  --allow-dirty   run even if the project has uncommitted git changes
  --dry-run       print the claude command and prompt instead of running it
  -h, --help      show this help

Examples:
  ./fix-issues.sh report.md
  ./fix-issues.sh -s error -t "npm test" -o fixes.md report.md
  ./fix-issues.sh -f "SC1,SC5" report.md ../my-project
EOF
}

#######################################
# Prints an error message to STDERR and exits.
# Arguments:
#   Message.
#######################################
die() {
  echo "fix-issues: $*" >&2
  exit 2
}

#######################################
# Prints a directory as C:/... under Git Bash on Windows, unchanged elsewhere.
# Arguments:
#   Existing directory.
# Outputs:
#   Path on stdout.
#######################################
native_path() {
  (cd "$1" && pwd -W 2>/dev/null) || (cd "$1" && pwd)
}

#######################################
# Reads the project path from a run-skills report header.
# Arguments:
#   Report file.
# Outputs:
#   Project path or nothing.
#######################################
project_from_report() {
  sed -n 's/^<!-- run-skills:project=\(.*\) -->[[:space:]]*$/\1/p' "$1" \
    | tr -d '\r' | head -n 1
}

#######################################
# Fails if the project has uncommitted changes (the report file is ignored).
# Arguments:
#   Project directory, report file.
#######################################
check_clean() {
  local changes
  git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "fix-issues: note - project is not a git repository;" \
      "changes can't be reviewed or reverted with git" >&2
    return 0
  }
  changes="$(git -C "$1" status --porcelain | grep -vF -- "$(basename "$2")")"
  if [[ -n "${changes}" ]]; then
    echo "fix-issues: the project has uncommitted changes:" >&2
    printf '%s\n' "${changes}" | head -n 10 >&2
    die "commit or stash them first (so you can review the fixes)," \
      "or use --allow-dirty"
  fi
}

#######################################
# Builds the prompt for Claude.
# Arguments:
#   Project path, severity text, filter, test command, language, extra,
#   report file.
# Outputs:
#   Prompt on stdout.
#######################################
build_prompt() {
  cat <<EOF
You get a review report for the project in the current working directory ($1). The report was made with review skills; each finding has a location, a severity (error, warning or info), a rule ID and a reason.

Task: fix the findings with severity $2.
EOF
  [[ -n "$3" ]] && printf 'Only fix these findings: %s\n' "$3"
  cat <<EOF

Rules:
1. Verify each finding in the code before you change anything. If a finding is a false positive or already fixed, do not change the code; list it as skipped with the reason.
2. Make the smallest change that fixes the finding. Keep the existing code style. Do not refactor unrelated code.
3. Do not change public APIs, file formats or behavior beyond what a finding requires. If a fix needs such a change, do not make it; list it as "needs decision".
4. Secrets: never print secret values. Replace them with a reference to an environment variable or config entry, and list "rotate the secret" as a manual step. Do not rewrite git history.
5. Do not commit, push, create branches, delete files or install anything. Steps you can't do (e.g. git rm --cached, installing tools, updating dependencies) go to the manual steps.
6. Do not modify the report file.
EOF
  if [[ -n "$4" ]]; then
    printf '7. After the fixes, run the test command: %s\n' "$4"
    printf '   If it fails because of your changes, fix or revert them.\n'
  fi
  cat <<EOF
This is a non-interactive run: never wait for confirmation.

At the end, write a summary in $5:
- a table with: finding (file:line and rule ID), status (fixed / skipped / needs decision / manual), what you changed and why
- the list of changed files
- the manual steps for the user
EOF
  [[ -n "$4" ]] && printf -- '- the test result\n'
  cat <<EOF
Explain each change in one sentence so that the author understands it. The author will review the diff.
EOF
  [[ -n "$6" ]] && printf '\nAdditional instructions: %s\n' "$6"
  printf '\n===== REPORT =====\n'
  tr -d '\r' < "$7"
}

#######################################
# Parses arguments and runs Claude.
# Arguments:
#   Command line (see usage).
#######################################
main() {
  local level="warning" filter="" test_cmd="" out="" lang="English" model=""
  local extra="" allow_dirty="" dry_run="" report="" project="" sev prompt
  local -a positional=() cmd
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s) [[ $# -ge 2 ]] || die "-s needs a level"; level="$2"; shift 2 ;;
      -f) [[ $# -ge 2 ]] || die "-f needs text"; filter="$2"; shift 2 ;;
      -t) [[ $# -ge 2 ]] || die "-t needs a command"; test_cmd="$2"; shift 2 ;;
      -o) [[ $# -ge 2 ]] || die "-o needs a file"; out="$2"; shift 2 ;;
      -l) [[ $# -ge 2 ]] || die "-l needs a language"; lang="$2"; shift 2 ;;
      -m) [[ $# -ge 2 ]] || die "-m needs a model"; model="$2"; shift 2 ;;
      -x) [[ $# -ge 2 ]] || die "-x needs text"; extra="$2"; shift 2 ;;
      --allow-dirty) allow_dirty=1; shift ;;
      --dry-run) dry_run=1; shift ;;
      -h | --help) usage; exit 0 ;;
      -*) die "unknown option $1 (see --help)" ;;
      *) positional+=("$1"); shift ;;
    esac
  done
  [[ "${#positional[@]}" -ge 1 ]] || { usage >&2; exit 2; }
  [[ "${#positional[@]}" -le 2 ]] || die "too many arguments"
  report="${positional[0]}"
  [[ -f "${report}" ]] || die "report not found: ${report}"
  report="$(cd "$(dirname "${report}")" && pwd)/$(basename "${report}")"

  project="${positional[1]:-$(project_from_report "${report}")}"
  [[ -n "${project}" ]] \
    || die "no project path in the report header - give the project directory"
  [[ -d "${project}" ]] || die "project directory not found: ${project}"
  project="$(cd "${project}" && pwd)"
  if [[ -n "${out}" && "${out}" != /* && "${out}" != [A-Za-z]:* ]]; then
    out="$(pwd)/${out}"
  fi

  case "${level}" in
    error) sev="error" ;;
    warning) sev="error and warning" ;;
    info) sev="error, warning and info" ;;
    *) die "-s must be error, warning or info" ;;
  esac

  prompt="$(build_prompt "$(native_path "${project}")" "${sev}" "${filter}" \
    "${test_cmd}" "${lang}" "${extra}" "${report}")"
  cmd=(claude -p --permission-mode dontAsk
    --allowedTools Read Grep Glob Edit Write
    "Bash(git status)" "Bash(git status *)" "Bash(git diff)" "Bash(git diff *)"
    "Bash(git log *)" "Bash(git ls-files *)" "Bash(git show *)")
  if [[ -n "${test_cmd}" ]]; then
    cmd+=("Bash(${test_cmd})" "Bash(${test_cmd} *)")
  fi
  cmd+=(--disallowedTools NotebookEdit PowerShell WebFetch WebSearch
    --output-format text)
  [[ -n "${model}" ]] && cmd+=(--model "${model}")

  if [[ -n "${dry_run}" ]]; then
    echo "# working directory: ${project}"
    printf '%q ' "${cmd[@]}"
    printf '<<PROMPT\n%s\nPROMPT\n' "${prompt}"
    exit 0
  fi

  command -v claude >/dev/null 2>&1 \
    || die "claude not found - install Claude Code"
  [[ -n "${allow_dirty}" ]] || check_clean "${project}" "${report}"

  cd "${project}" || exit 1
  if [[ -n "${out}" ]]; then
    printf '%s\n' "${prompt}" | "${cmd[@]}" | tee "${out}"
  else
    printf '%s\n' "${prompt}" | "${cmd[@]}"
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo
    echo "===== changed files (review with: git diff; undo with: git restore .)"
    git status --short
    git diff --stat
  fi
}

main "$@"
