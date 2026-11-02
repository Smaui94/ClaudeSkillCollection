#!/usr/bin/env bash
#
# Runs selected review skills of this collection on a project.
#
# AI mode (default): starts Claude Code non-interactively (claude -p) in the
# project directory. Claude may only read files and run the skills' helper
# scripts and read-only git commands; editing tools are disabled.
# Scripts mode (--scripts-only): runs only the helper scripts of the selected
# skills, without Claude.
#
# No "set -e": a failing skill script should not abort the remaining skills.
set -u

SKILLS_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SKILLS_DIR

#######################################
# Prints a directory in the form Claude's tools expect: C:/... under Git Bash
# on Windows (pwd -W), unchanged elsewhere.
# Arguments:
#   Existing directory.
# Outputs:
#   Path on stdout.
#######################################
native_path() {
  (cd "$1" && pwd -W 2>/dev/null) || (cd "$1" && pwd)
}

#######################################
# Prints the usage text.
# Outputs:
#   Usage on stdout.
#######################################
usage() {
  cat <<'EOF'
Usage: run-skills.sh [options] <skill[,skill...]...> [project_dir]

Runs the given review skills of this collection on project_dir (default: .).
Skills may be separated by commas or spaces; "full" = full-review.

Options:
  -o FILE         also write the report to FILE
  -l LANG         report language (default: English)
  -m MODEL        Claude model (default: Claude Code's default)
  -x TEXT         extra instructions, e.g. "focus on src/" or "depth thorough"
  --scripts-only  run only the skills' helper scripts, without Claude
  --dry-run       print the claude command and prompt instead of running it
  --list          list the available skills
  -h, --help      show this help

Examples:
  ./run-skills.sh secrets-scan,repo-hygiene ../my-project
  ./run-skills.sh -l Deutsch -o review.md full ../my-project
  ./run-skills.sh --scripts-only todo-audit,config-review .
EOF
}

#######################################
# Prints an error message to STDERR and exits.
# Arguments:
#   Message.
#######################################
die() {
  echo "run-skills: $*" >&2
  exit 2
}

#######################################
# Lists all skills with a script marker and a short description.
# Globals:
#   SKILLS_DIR
# Outputs:
#   One skill per line.
#######################################
list_skills() {
  local f name desc marker
  for f in "${SKILLS_DIR}"/*/SKILL.md; do
    [[ -f "${f}" ]] || continue
    name="$(basename "$(dirname "${f}")")"
    desc="$(sed -n 's/^description:[[:space:]]*//p' "${f}" | head -n 1 \
      | tr -d '\r' | cut -c1-90)"
    marker=" "
    compgen -G "$(dirname "${f}")/scripts/*.sh" >/dev/null && marker="S"
    printf '%-30s %s %s\n' "${name}" "${marker}" "${desc}"
  done
  echo "(S = has helper scripts, usable with --scripts-only)"
}

#######################################
# Validates a comma-separated skill list and prints it space-separated.
# Globals:
#   SKILLS_DIR
# Arguments:
#   Comma-separated skill names ("full" = full-review).
# Outputs:
#   Space-separated skill names.
#######################################
resolve_skills() {
  local s out=""
  local -a names
  IFS=',' read -r -a names <<< "$1"
  for s in "${names[@]}"; do
    s="${s// /}"
    [[ -z "${s}" ]] && continue
    [[ "${s}" == "full" ]] && s="full-review"
    [[ -f "${SKILLS_DIR}/${s}/SKILL.md" ]] \
      || die "unknown skill '${s}' (see --list)"
    out+="${s} "
  done
  [[ -z "${out}" ]] && die "no skills given"
  echo "${out% }"
}

#######################################
# Runs the helper scripts of the given skills on the project.
# Globals:
#   SKILLS_DIR
# Arguments:
#   Project directory, skill names...
# Outputs:
#   Script output per skill.
#######################################
run_scripts() {
  local project="$1" s script found
  shift
  for s in "$@"; do
    found=""
    for script in "${SKILLS_DIR}/${s}"/scripts/*.sh; do
      [[ -f "${script}" ]] || continue
      found=1
      echo "=================== ${s} ($(basename "${script}"))"
      bash "${script}" "${project}"
      echo
    done
    if [[ -z "${found}" ]]; then
      echo "=================== ${s}"
      echo "no helper script - this skill needs Claude" \
        "(run without --scripts-only)"
      echo
    fi
  done
}

#######################################
# Prints the report header. fix-issues.sh reads the project path from the
# "run-skills:project=" comment, so keep that line format stable.
# Arguments:
#   Project directory, skill names (space-separated), mode, language.
# Outputs:
#   Markdown header on stdout.
#######################################
report_header() {
  local path
  path="$(native_path "$1")"
  cat <<EOF
# Skill review report

- Project: \`${path}\`
- Skills: ${2// /, }
- Mode: $3
- Language: $4
- Date: $(date '+%Y-%m-%d %H:%M')

<!-- run-skills:project=${path} -->

---

EOF
}

#######################################
# Builds the prompt for Claude.
# Globals:
#   SKILLS_DIR
# Arguments:
#   Skill names (space-separated), language, extra instructions.
# Outputs:
#   Prompt on stdout.
#######################################
build_prompt() {
  local dir
  dir="$(native_path "${SKILLS_DIR}")"
  cat <<EOF
Run these review skills from the skill collection in ${dir} on the project in the current working directory: $1.

For each skill, read ${dir}/NAME/SKILL.md (NAME = the skill name) and follow it exactly. Wherever a skill says <skill-dir>, use ${dir}/NAME.
Run helper scripts only in this form: bash ${dir}/NAME/scripts/SCRIPT.sh ARGS (use . as the project root).
Review only: do not create, modify or delete any files, and run no commands that change state.
This is a non-interactive run: never wait for confirmation. Where a skill says to ask the user, choose the sensible default and state the assumption in the report.

Report: one section per skill in that skill's report format, then a combined summary with the 10 most important findings across all skills, most severe first. Write the report in $2.
EOF
  [[ -n "$3" ]] && printf '\nAdditional instructions: %s\n' "$3"
}

#######################################
# Parses arguments and runs the selected mode.
# Arguments:
#   Command line (see usage).
#######################################
main() {
  local out="" lang="English" model="" extra="" scripts_only="" dry_run=""
  local skills="" project="" prompt dir last
  local -a positional=() cmd
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o) [[ $# -ge 2 ]] || die "-o needs a file"; out="$2"; shift 2 ;;
      -l) [[ $# -ge 2 ]] || die "-l needs a language"; lang="$2"; shift 2 ;;
      -m) [[ $# -ge 2 ]] || die "-m needs a model"; model="$2"; shift 2 ;;
      -x) [[ $# -ge 2 ]] || die "-x needs text"; extra="$2"; shift 2 ;;
      --scripts-only) scripts_only=1; shift ;;
      --dry-run) dry_run=1; shift ;;
      --list) list_skills; exit 0 ;;
      -h | --help) usage; exit 0 ;;
      -*) die "unknown option $1 (see --help)" ;;
      *) positional+=("$1"); shift ;;
    esac
  done
  [[ "${#positional[@]}" -ge 1 ]] || { usage >&2; exit 2; }
  # The last positional is the project directory unless it is a skill name.
  last="${positional[${#positional[@]}-1]}"
  project="."
  if [[ "${#positional[@]}" -ge 2 && "${last}" != "full" \
      && ! -f "${SKILLS_DIR}/${last}/SKILL.md" ]]; then
    project="${last}"
    unset 'positional[${#positional[@]}-1]'
  fi
  skills="$(IFS=','; resolve_skills "${positional[*]}")" || exit 2
  [[ -d "${project}" ]] || die "project directory not found: ${project}"
  project="$(cd "${project}" && pwd)"
  # Resolve -o before changing into the project directory.
  if [[ -n "${out}" && "${out}" != /* && "${out}" != [A-Za-z]:* ]]; then
    out="$(pwd)/${out}"
  fi

  if [[ -n "${scripts_only}" ]]; then
    # shellcheck disable=SC2086  # word splitting of the skill list is intended
    if [[ -n "${out}" ]]; then
      {
        report_header "${project}" "${skills}" "scripts-only" "${lang}"
        run_scripts "${project}" ${skills}
      } | tee "${out}"
    else
      report_header "${project}" "${skills}" "scripts-only" "${lang}"
      run_scripts "${project}" ${skills}
    fi
    exit 0
  fi

  command -v claude >/dev/null 2>&1 \
    || die "claude not found - install Claude Code or use --scripts-only"
  prompt="$(build_prompt "${skills// /, }" "${lang}" "${extra}")"
  dir="$(native_path "${SKILLS_DIR}")"
  cmd=(claude -p --permission-mode dontAsk --add-dir "${dir}"
    --allowedTools Read Grep Glob
    "Bash(bash ${dir}/*)" "Bash(git log *)" "Bash(git blame *)"
    "Bash(git ls-files *)" "Bash(git ls-tree *)" "Bash(git diff *)"
    "Bash(git show *)" "Bash(git status *)" "Bash(git describe *)"
    "Bash(git rev-parse *)" "Bash(git check-ignore *)" "Bash(git branch *)"
    "Bash(git for-each-ref *)" "Bash(git rev-list *)" "Bash(wc *)"
    --disallowedTools Edit Write NotebookEdit PowerShell WebFetch WebSearch
    --output-format text)
  [[ -n "${model}" ]] && cmd+=(--model "${model}")

  if [[ -n "${dry_run}" ]]; then
    echo "# working directory: ${project}"
    printf '%q ' "${cmd[@]}"
    printf '<<PROMPT\n%s\nPROMPT\n' "${prompt}"
    exit 0
  fi

  cd "${project}" || exit 1
  if [[ -n "${out}" ]]; then
    {
      report_header "${project}" "${skills}" "claude" "${lang}"
      printf '%s\n' "${prompt}" | "${cmd[@]}"
    } | tee "${out}"
  else
    report_header "${project}" "${skills}" "claude" "${lang}"
    printf '%s\n' "${prompt}" | "${cmd[@]}"
  fi
}

main "$@"
