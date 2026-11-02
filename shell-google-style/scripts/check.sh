#!/usr/bin/env bash
# Google Shell style scan.
# Usage: check.sh [root] [max_hits_per_rule]
# Runs shellcheck if installed, then grep/awk heuristics.
# Output: "## ID count SEV | description" + up to N "file:line:code" per rule, then TOTAL.
ROOT="${1:-.}"
MAX="${2:-8}"
TOTAL=0
export LC_ALL=C
cd "$ROOT" || exit 1

list_files() {
  find . \( -name .git -o -name node_modules -o -name vendor -o -name build -o -name dist \
    -o -name .venv -o -name venv \) -prune -o -type f \
    ! -name configure ! -name gradlew ! -name mvnw -print \
    | while IFS= read -r f; do
        b="${f##*/}"
        case "$b" in
          *.sh | *.bash) printf '%s\n' "$f" ;;
          *.*) ;;
          *) head -n 1 "$f" 2>/dev/null | grep -qE '^#!.*\b(ba)?sh\b' && printf '%s\n' "$f" ;;
        esac
      done
}

mapfile -t FILES < <(list_files)
[ "${#FILES[@]}" -eq 0 ] && { echo "no shell scripts under $ROOT"; exit 0; }

files() { printf '%s\0' "${FILES[@]}"; }

# report ID SEV "description" "hits"
report() {
  local n
  [ -z "$4" ] && return
  n=$(printf '%s\n' "$4" | wc -l)
  TOTAL=$((TOTAL + n))
  echo "## $1 $n $2 | $3"
  printf '%s\n' "$4" | head -n "$MAX" | sed 's#^\./##' | cut -c1-170
}

# check ID SEV "description" "pcre"   (comment-only lines are skipped)
check() {
  report "$1" "$2" "$3" "$(files | xargs -0r grep -HnP -- "$4" 2>/dev/null \
    | grep -vP '^[^:]+:\d+:\s*#')"
}

# awkcheck ID SEV "description" 'awk program printing FILENAME ":" FNR ":" $0'
awkcheck() {
  report "$1" "$2" "$3" "$(files | xargs -0r awk "$4" 2>/dev/null)"
}

echo "# ${#FILES[@]} shell scripts"

# --- shellcheck ---
if command -v shellcheck >/dev/null 2>&1; then
  SC=$(shellcheck -f gcc -x "${FILES[@]}" 2>&1)
  echo "# shellcheck rule statistics"
  printf '%s\n' "$SC" | grep -oE 'SC[0-9]+' | sort | uniq -c | sort -rn | head -n 25
  echo "# shellcheck samples"
  printf '%s\n' "$SC" | sed 's#^\./##' | head -n $((MAX * 10))
else
  echo "NOTE shellcheck not found - https://www.shellcheck.net enables precise checks; heuristics only"
fi

# --- Heuristics (always) ---
echo "# heuristics"
check S1 info "tab character (only allowed in <<- heredocs)" $'\t'
check S2 info "line > 80 cols" '^(?!.*https?://).{81,}$'
check S3 error "backticks instead of \$(...)" '`[^`]*`'
check S4 warning "[ ... ] or test instead of [[ ... ]]" '(^|[\s;&|!(])(\[(?!\[)\s|test\s+-)'
check S5 info "then/do on its own line (use '; then' / '; do')" '^\s*(then|do)\s*$'
check S6 warning "let/expr/\$[ ] instead of (( ))" '(^|[\s;&|])(let|expr)\s|\$\['
check S7 error "eval" '(^|[\s;&|])eval\s'
check S8 warning "\$* instead of \"\$@\"" '\$\*|\$\{\*\}'
check S9 error "parsing ls output" '\$\(\s*ls\b(?!-)|`ls\b(?!-)|(?<![\w-])ls\b(?!-)[^|#]*\|\s*(while|xargs|grep|awk|for)\b|for\s+\w+\s+in\s+\$\(\s*ls\b(?!-)'
check S10 error "local/readonly/export combined with \$(...) hides the exit code" '^\s*(local|readonly|declare|export)\s+(-\w+\s+)*\w+=\$\('
check S13 warning "error message probably not sent to STDERR" '(?i)\b(echo|printf)\b.*\b(error|fatal)\b(?!.*>&2)'
report S14 info "no 'set -e'/'set -o errexit' (project recommendation: set -euo pipefail)" \
  "$(files | xargs -0r grep -LE 'set -[a-zA-Z]*e|set -o errexit' 2>/dev/null | sed 's/$/:1:/')"
awkcheck S16 warning "shebang is not bash" '
  FNR == 1 && /^#!/ && !/bash/ { print FILENAME ":" FNR ":" $0 }'
awkcheck S12 warning "script with functions does not end with main \"\$@\"" '
  function emit() { if (k >= 1 && last !~ /^[ \t]*main[ \t]+"\$@"/) print cur ":" lastn ":" last }
  FNR == 1 { if (cur != "") emit(); cur = FILENAME; k = 0; last = ""; lastn = 0 }
  {
    if (match($0, /^[ \t]*(function[ \t]+)?[A-Za-z_][A-Za-z0-9_:]*[ \t]*\(\)/) \
        || match($0, /^[ \t]*function[ \t]+[A-Za-z_][A-Za-z0-9_:]*/)) {
      s = substr($0, RSTART, RLENGTH)
      sub(/^[ \t]*(function[ \t]+)?/, "", s); sub(/[ \t]*\(\).*$/, "", s)
      if (s != "main") k++
    }
  }
  !/^[ \t]*$/ && !/^[ \t]*#/ { last = $0; lastn = FNR }
  END { if (cur != "") emit() }'
awkcheck S17 warning "function without comment header" '
  FNR == 1 { prev = "" }
  /^[ \t]*$/ { next }
  {
    if ($0 ~ /^[ \t]*(function[ \t]+)?[A-Za-z_][A-Za-z0-9_:]*[ \t]*\(\)/ || $0 ~ /^[ \t]*function[ \t]+[A-Za-z_]/) {
      if (prev !~ /^[ \t]*#/ && $0 !~ /^[ \t]*(function[ \t]+)?main[ \t]*\(/) print FILENAME ":" FNR ":" $0
    }
    prev = $0
  }'

echo "TOTAL $TOTAL (heuristics; shellcheck findings listed separately)"
