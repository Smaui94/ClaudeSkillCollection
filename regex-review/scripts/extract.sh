#!/usr/bin/env bash
#
# Extracts regex usages per language for the regex-review skill.
# Usage: extract.sh [root] [max_hits_per_section]
# Output: "## <lang> count | api" + "file:line: code" samples, then heuristic
#         flags "## RX<n> count SEV | description", then TOTAL.
#
# No "set -e": grep finding nothing is an expected, non-fatal result here.
set -u

readonly ROOT="${1:-.}"
readonly MAX="${2:-30}"
TOTAL=0
ALL=""
readonly -a EXCLUDES=(--exclude-dir=.git --exclude-dir=node_modules
  --exclude-dir=vendor --exclude-dir=.venv --exclude-dir=venv
  --exclude-dir=build --exclude-dir=dist --exclude-dir=out
  --exclude-dir=target --exclude-dir=bin --exclude-dir=obj
  --exclude-dir=__pycache__ --exclude-dir=.godot --exclude='*.min.js')

#######################################
# Prints one section with a sample of its hits.
# Globals:
#   MAX, TOTAL
# Arguments:
#   Header, newline-separated hits, "count" to add hits to TOTAL.
# Outputs:
#   Writes the section to stdout.
#######################################
section() {
  local n
  [[ -z "$2" ]] && return 0
  n="$(printf '%s\n' "$2" | wc -l)"
  n="${n// /}"
  [[ "${3:-}" == "count" ]] && TOTAL=$((TOTAL + n))
  echo "## $1 (${n})"
  printf '%s\n' "$2" | head -n "${MAX}" | cut -c1-170
}

#######################################
# Greps one language for regex API usage and records the hits.
# Globals:
#   ALL
# Arguments:
#   Label, PCRE pattern, include globs...
# Outputs:
#   The section via section().
#######################################
lang() {
  local label="$1" re="$2" hits g
  local -a inc=()
  shift 2
  for g in "$@"; do
    inc+=(--include="${g}")
  done
  hits="$(grep -rnIP "${EXCLUDES[@]}" "${inc[@]}" -- "${re}" . 2>/dev/null \
    | sed 's#^\./##; s/[[:space:]]\+/ /g')"
  [[ -n "${hits}" ]] && ALL+="${hits}"$'\n'
  section "${label}" "${hits}"
}

#######################################
# Flags heuristic findings among all collected regex usages.
# Globals:
#   ALL
# Arguments:
#   Rule ID, severity, description, PCRE pattern,
#   optional PCRE on the file path to exclude.
#######################################
flag() {
  local hits
  hits="$(printf '%s' "${ALL}" | grep -P -- "$4" \
    | grep -vP -- "${5:-^\$^}")"
  [[ -z "${hits}" ]] && return 0
  section "$1 $2 | $3" "${hits}" count
}

#######################################
# Runs extraction and heuristics.
# Arguments:
#   None (uses ROOT).
#######################################
main() {
  cd "${ROOT}" || exit 1
  lang "Python re" \
    '\bre\.(compile|match|search|fullmatch|findall|finditer|sub|subn|split)\s*\(' \
    '*.py'
  lang "JS/TS RegExp and literals" \
    '\bnew\s+RegExp\s*\(|\bRegExp\s*\(|\.(match|matchAll|replace|replaceAll|search|split|test)\s*\(\s*/[^/*\s]|(^|[=(:,!&|?;{]|\breturn)\s*/(?![/*\s])(?:\\.|\[[^\]]*\]|[^/\\\[\n])+/[dgimsuyv]*\s*[.;,)\]}]' \
    '*.js' '*.jsx' '*.ts' '*.tsx' '*.mjs' '*.cjs' '*.vue' '*.svelte'
  lang "Java Pattern / String regex" \
    '\bPattern\.(compile|matches)\s*\(|\.(matches|replaceAll|replaceFirst|split)\s*\(\s*"' \
    '*.java'
  lang "Kotlin Regex" '\bRegex\s*\(|\.toRegex\s*\(|\bPattern\.compile\s*\(' '*.kt'
  lang "C# Regex" \
    '\bnew\s+Regex\s*\(|\bRegex\.(IsMatch|Match|Matches|Replace|Split|EnumerateMatches|Count)\s*\(|\[GeneratedRegex\s*\(' \
    '*.cs'
  lang "Go regexp (RE2, linear)" \
    '\bregexp\.(MustCompile|Compile|MatchString|Match)(POSIX)?\s*\(' '*.go'
  lang "Rust regex (linear)" '\bRegex(Builder|Set)?::new\s*\(' '*.rs'
  lang "PHP preg" '\bpreg_(match|match_all|replace|replace_callback|split|grep)\s*\(' \
    '*.php'
  lang "GDScript RegEx" '\bRegEx\.(new|create_from_string)\s*\(|\.compile\s*\(\s*"' \
    '*.gd'
  lang "C/C++ regex" '\bstd::regex\b|\bregcomp\s*\(|\bpcre2?_compile' \
    '*.c' '*.cc' '*.cpp' '*.cxx' '*.h' '*.hpp'
  lang "Shell grep/sed/=~" \
    '=~|\bgrep\s+(-\w+\s+)*-\w*[EP]\w*\b|\bsed\s+(-\w+\s+)*-\w*[Er]\w*\b' \
    '*.sh' '*.bash'
  lang "Config pattern/regex keys" \
    '(?i)^\s*["\x27]?[\w.-]*(pattern|regex|regexp)["\x27]?\s*[:=]' \
    '*.json' '*.yml' '*.yaml' '*.toml' '*.ini' '*.properties'

  echo "# heuristics (possible - verify each in context)"
  flag RX1 warning "nested quantifier - possible catastrophic backtracking" \
    '\((?:[^()\\]|\\.)*[+*](?:[^()\\]|\\.)*\)[+*{]' '^[^:]+\.(go|rs):'
  flag RX1 info "several .* or .+ in one pattern - check for overlap" \
    '\.[*+].*\.[*+]' '^[^:]+\.(go|rs):'
  flag RX4 error "[A-z] range (also matches [ \\ ] ^ _ and backtick)" \
    '\[[^\]]*A-z'
  flag RX4 warning "| inside a character class (literal, not 'or')" \
    '\[[^\]\\(]*\|[^\]]*\]'
  flag RX11 warning "pattern built from a variable or f-string - check escaping" \
    '\bnew\s+RegExp\s*\(\s*[A-Za-z_$`]|\bre\.(compile|match|search|fullmatch|sub)\s*\(\s*(f["\x27]|[A-Za-z_]\w*\s*[,)])|\bPattern\.compile\s*\(\s*[A-Za-z_]|\bnew\s+Regex\s*\(\s*[A-Za-z_$]|\bregexp\.MustCompile\s*\(\s*[A-Za-z_]|\bRegex::new\s*\(\s*&?[A-Za-z_]'
  echo "TOTAL ${TOTAL} heuristic flags"
}

main "$@"
