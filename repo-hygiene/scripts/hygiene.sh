#!/usr/bin/env bash
#
# Collects repository hygiene facts for the repo-hygiene skill.
# Usage: hygiene.sh [root] [max_hits_per_rule]
# Env:   LARGE_KB=<n> large-file limit in KB (default 5120),
#        BRANCHES=1 also lists stale and merged branches (RH11).
# Output: "## ID count SEV | description" + up to N samples, then TOTAL.
#
# No "set -e": grep finding nothing is an expected, non-fatal result here.
set -u

readonly ROOT="${1:-.}"
readonly MAX="${2:-8}"
readonly LARGE_KB="${LARGE_KB:-5120}"
TOTAL=0
EXTS=""

#######################################
# Prints one rule section with a sample of its hits.
# Globals:
#   MAX, TOTAL
# Arguments:
#   Rule ID, severity, description, newline-separated hits.
# Outputs:
#   Writes the section to stdout.
#######################################
report() {
  local n
  [[ -z "$4" ]] && return 0
  n="$(printf '%s\n' "$4" | wc -l)"
  n="${n// /}"
  TOTAL=$((TOTAL + n))
  echo "## $1 ${n} $2 | $3"
  printf '%s\n' "$4" | head -n "${MAX}" | cut -c1-170
}

#######################################
# Tells whether a file extension occurs among the tracked files.
# Globals:
#   EXTS
# Arguments:
#   Extension without dot, lowercase.
# Returns:
#   0 if present, 1 otherwise.
#######################################
has_ext() {
  [[ "${EXTS}" == *" $1 "* ]]
}

#######################################
# Prints ignore probes (path<TAB>reason) for the detected stack.
# Globals:
#   EXTS
# Outputs:
#   Probe lines on stdout.
#######################################
ignore_probes() {
  local m d
  printf '%s\t%s\n' ".env" "environment file" ".DS_Store" "macOS file" \
    "Thumbs.db" "Windows file" ".idea/workspace.xml" "JetBrains IDE"
  if has_ext py; then
    printf '%s\t%s\n' "__pycache__/x.pyc" "Python bytecode" \
      ".venv/pyvenv.cfg" "Python venv" "x.egg-info/PKG-INFO" "Python build"
  fi
  if has_ext class || has_ext java || has_ext kt; then
    printf '%s\t%s\n' "x.class" "Java bytecode"
  fi
  if has_ext c || has_ext cpp || has_ext cc || has_ext h || has_ext hpp; then
    printf '%s\t%s\n' "x.o" "object file" "x.obj" "object file" \
      "x.exe" "binary"
  fi
  if has_ext cs || has_ext cpp || has_ext sln; then
    printf '%s\t%s\n' ".vs/x" "Visual Studio" "x.user" "Visual Studio user file"
  fi
  while IFS= read -r m; do
    d="$(dirname "${m}")"
    if [[ "${d}" == "." ]]; then
      d=""
    else
      d="${d}/"
    fi
    case "${m##*/}" in
      package.json)
        printf '%s\t%s\n' "${d}node_modules/x" "Node dependencies" ;;
      pom.xml | Cargo.toml)
        printf '%s\t%s\n' "${d}target/x" "Maven/Cargo build output" ;;
      build.gradle | build.gradle.kts)
        printf '%s\t%s\n' "${d}build/x" "Gradle build output" \
          "${d}.gradle/x" "Gradle cache" ;;
      *.csproj)
        printf '%s\t%s\n' "${d}bin/x" ".NET build output" \
          "${d}obj/x" ".NET build output" ;;
      CMakeLists.txt)
        printf '%s\t%s\n' "${d}build/x" "CMake build dir" ;;
      project.godot)
        printf '%s\t%s\n' "${d}.godot/x" "Godot 4 cache" ;;
      ProjectVersion.txt)
        d="${d%ProjectSettings/}"
        printf '%s\t%s\n' "${d}Library/x" "Unity cache" "${d}Temp/x" \
          "Unity temp" "${d}Logs/x" "Unity logs" ;;
    esac
  done < <(git ls-files | grep -E '(^|/)(package\.json|pom\.xml|Cargo\.toml|build\.gradle(\.kts)?|[^/]*\.csproj|CMakeLists\.txt|project\.godot|ProjectSettings/ProjectVersion\.txt)$' \
    | grep -v 'node_modules/')
}

#######################################
# RH1: missing .gitignore or missing ignore entries.
#######################################
check_gitignore() {
  local hits="" p reason
  if ! git ls-files --error-unmatch .gitignore >/dev/null 2>&1 \
      && [[ ! -f .gitignore ]]; then
    report RH1 error "no .gitignore at the repository root" \
      ".gitignore: missing"
  fi
  while IFS=$'\t' read -r p reason; do
    if ! git check-ignore -q --no-index "${p}" 2>/dev/null; then
      hits+="${p}: not ignored (${reason})"$'\n'
    fi
  done < <(ignore_probes | sort -u)
  report RH1 warning ".gitignore misses entries for the detected stack" \
    "$(printf '%s' "${hits}" | grep -v '^$')"
}

#######################################
# RH2/RH3: committed build output, binaries, IDE and OS files.
#######################################
check_committed_junk() {
  local dirs files ide vscode
  dirs="$(git ls-files | grep -oE '^(.*/)?(node_modules|__pycache__|\.venv|venv|bin|obj|target|\.gradle|\.godot|\.import|Library|Temp|coverage|\.pytest_cache|\.mypy_cache)/' \
    | sort | uniq -c | sort -rn | awk '{ print $2 ": " $1 " files" }')"
  report RH2 warning "committed build output / dependency folders (possible)" \
    "${dirs}"
  files="$(git ls-files | grep -iE '\.(pyc|pyo|class|o|obj|exe|dll|so|dylib|a|lib|pdb|jar|war|apk|aab|ipa)$' \
    | grep -vE '(^|/)(node_modules|__pycache__|bin|obj|target)/')"
  report RH2 warning "committed binaries / build artifacts (possible)" \
    "${files}"
  ide="$(git ls-files | grep -iE '(^|/)(\.idea|\.vs)/|(^|/)(\.DS_Store|Thumbs\.db|desktop\.ini)$|\.(suo|user|swp|swo)$|~$')"
  report RH3 warning "committed IDE / OS files" "${ide}"
  vscode="$(git ls-files | grep -E '(^|/)\.vscode/')"
  report RH3 info \
    ".vscode/ committed (fine if settings are shared on purpose)" "${vscode}"
}

#######################################
# RH4/RH10: large and empty files (committed blobs in HEAD).
#######################################
check_sizes() {
  local tree large empty
  if ! git rev-parse --verify -q HEAD >/dev/null; then
    echo "NOTE no commits yet - RH4/RH10 skipped"
    return 0
  fi
  tree="$(git ls-tree -r -l HEAD)"
  large="$(printf '%s\n' "${tree}" | awk -F'\t' -v lim="${LARGE_KB}" '
    { split($1, m, " "); if (m[4] + 0 > lim * 1024)
        printf "%s: %.1f MB\n", $2, m[4] / 1048576 }' | sort -t: -k2 -rn)"
  report RH4 warning "files larger than ${LARGE_KB} KB" "${large}"
  empty="$(printf '%s\n' "${tree}" | awk -F'\t' '
    { split($1, m, " "); if (m[4] == "0") print $2 }' \
    | grep -vE '(^|/)(__init__\.py|py\.typed|\.gitkeep|\.keep)$')"
  report RH10 info "empty tracked files" "${empty}"
}

#######################################
# Describes a root file that is not tracked: untracked or missing.
# Arguments:
#   Alternation of base names (regex, case-insensitive).
# Outputs:
#   "exists but is not committed" or "missing at the root".
#######################################
root_state() {
  local f found=""
  shopt -s nocasematch
  for f in ./*; do
    [[ "${f#./}" =~ ^($1)(\.[a-z]+)?$ ]] && found=1
  done
  shopt -u nocasematch
  if [[ -n "${found}" ]]; then
    echo "exists but is not committed"
  else
    echo "missing at the root"
  fi
}

#######################################
# RH5: LICENSE and README at the root.
#######################################
check_root_files() {
  local root_files hits=""
  root_files="$(git ls-files | grep -v '/')"
  if ! printf '%s\n' "${root_files}" \
      | grep -qiE '^(license|licence|copying|unlicense)(\.[a-z]+)?$'; then
    hits+="LICENSE: $(root_state 'license|licence|copying|unlicense')"$'\n'
  fi
  if ! printf '%s\n' "${root_files}" | grep -qiE '^readme(\.[a-z]+)?$'; then
    hits+="README: $(root_state 'readme')"$'\n'
  fi
  report RH5 warning "missing root files" "$(printf '%s' "${hits}")"
}

#######################################
# RH6: line endings (index and working tree).
#######################################
check_line_endings() {
  local eol crlf lf mixed sh_crlf
  eol="$(git ls-files --eol 2>/dev/null)"
  [[ -z "${eol}" ]] && return 0
  crlf="$(printf '%s\n' "${eol}" | grep -c '^i/crlf')"
  lf="$(printf '%s\n' "${eol}" | grep -c '^i/lf')"
  if [[ "${crlf}" -gt 0 && "${lf}" -gt 0 ]] \
      && ! git ls-files --error-unmatch .gitattributes >/dev/null 2>&1; then
    if [[ "${crlf}" -le "${lf}" ]]; then
      mixed="$(printf '%s\n' "${eol}" | grep '^i/crlf' \
        | awk -F'\t' '{ print $2 ": CRLF in index" }')"
    else
      mixed="$(printf '%s\n' "${eol}" | grep '^i/lf' \
        | awk -F'\t' '{ print $2 ": LF in index" }')"
    fi
    report RH6 warning \
      "mixed line endings without .gitattributes (${lf} LF, ${crlf} CRLF)" \
      "${mixed}"
  fi
  sh_crlf="$(printf '%s\n' "${eol}" | grep -E '(i|w)/crlf' \
    | awk -F'\t' '$2 ~ /\.(sh|bash)$/ { print $2 ": CRLF" }')"
  report RH6 error "shell scripts with CRLF line endings" "${sh_crlf}"
}

#######################################
# RH7: executable bits.
#######################################
check_exec_bits() {
  local stage
  stage="$(git ls-files -s)"
  report RH7 info \
    "scripts not executable in git (core.filemode may be off on Windows)" \
    "$(printf '%s\n' "${stage}" | awk -F'\t' '
      $1 ~ /^100644/ && $2 ~ /\.(sh|bash)$/ { print $2 ": mode 100644" }')"
  report RH7 info "non-script files with executable bit" \
    "$(printf '%s\n' "${stage}" | awk -F'\t' '
      $1 ~ /^100755/ \
        && $2 ~ /\.(md|txt|json|ya?ml|png|jpe?g|gif|svg|html|css|java|cs|cpp|h)$/ {
        print $2 ": mode 100755"
      }')"
}

#######################################
# RH8: paths that differ only in case.
#######################################
check_case_conflicts() {
  local all
  all="$(git ls-files)"
  report RH8 error "paths that differ only in case" \
    "$(printf '%s\n' "${all}" | awk '
      {
        l = tolower($0)
        seen[l] = seen[l] (seen[l] ? " | " : "") $0
        n[l]++
      }
      END { for (k in n) if (n[k] > 1) print seen[k] }')"
  report RH8 error "directories that differ only in case" \
    "$(printf '%s\n' "${all}" | awk -F/ '
      {
        p = ""
        for (i = 1; i < NF; i++) { p = p (i > 1 ? "/" : "") $i; d[p] = 1 }
      }
      END {
        for (k in d) { l = tolower(k); s[l] = s[l] (s[l] ? " | " : "") k; c[l]++ }
        for (l in c) if (c[l] > 1) print s[l]
      }')"
}

#######################################
# RH9: .gitkeep in directories that have other tracked files.
#######################################
check_gitkeep() {
  report RH9 info ".gitkeep in a non-empty directory" \
    "$(git ls-files | awk -F/ '
      { dir = $0; sub(/\/?[^\/]*$/, "", dir)
        if ($NF == ".gitkeep") keep[dir] = 1; else other[dir] = 1 }
      END {
        for (k in keep) if (k in other) print (k == "" ? "." : k) "/.gitkeep"
      }')"
}

#######################################
# RH11: stale and merged local branches (only with BRANCHES=1).
#######################################
check_branches() {
  local cutoff current
  [[ -z "${BRANCHES:-}" ]] && return 0
  cutoff=$(( $(date +%s) - 180 * 86400 ))
  current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  report RH11 info "local branches without commits for 180+ days" \
    "$(git for-each-ref refs/heads \
      --format='%(committerdate:unix) %(committerdate:short) %(refname:short)' \
      | awk -v c="${cutoff}" '$1 < c { print $3 ": last commit " $2 }')"
  report RH11 info "local branches already merged into ${current}" \
    "$(git branch --merged 2>/dev/null | sed 's/^[* ]*//' \
      | grep -vxF "${current}" | sed 's/$/: merged/')"
}

#######################################
# Runs all checks.
# Arguments:
#   None (uses ROOT).
#######################################
main() {
  cd "${ROOT}" || exit 1
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "NOTE not a git repository - only manual checks possible"
    exit 0
  fi
  cd "$(git rev-parse --show-toplevel)" || exit 1
  EXTS=" $(git ls-files | sed -n 's/.*\.\([A-Za-z0-9]*\)$/\1/p' \
    | tr '[:upper:]' '[:lower:]' | sort -u | tr '\n' ' ') "
  check_gitignore
  check_committed_junk
  check_sizes
  check_root_files
  check_line_endings
  check_exec_bits
  check_case_conflicts
  check_gitkeep
  check_branches
  echo "TOTAL ${TOTAL}"
}

main "$@"
