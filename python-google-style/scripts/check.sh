#!/usr/bin/env bash
# Google Python style + mandatory docstring scan.
# Usage: check.sh [root] [max_hits_per_rule]
# Runs ruff (or pylint) if installed, then grep/awk heuristics.
# Output: "## ID count SEV | description" + up to N "file:line:code" per rule, then TOTAL.
ROOT="${1:-.}"
MAX="${2:-8}"
TOTAL=0
export LC_ALL=C
cd "$ROOT" || exit 1

files() {
  find . \( -name .git -o -name .venv -o -name venv -o -name env -o -name build \
    -o -name dist -o -name node_modules -o -name __pycache__ -o -name .tox \
    -o -name .mypy_cache -o -name .ruff_cache -o -name site-packages -o -name vendor \
    -o -name migrations \) -prune -o -type f -name '*.py' ! -name '*_pb2.py' -print0
}

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

# checkc ID SEV "description" "pcre"  (comment lines included)
checkc() {
  report "$1" "$2" "$3" "$(files | xargs -0r grep -HnP -- "$4" 2>/dev/null)"
}

# awkcheck ID SEV "description" 'awk program printing FILENAME ":" FNR ":" $0'
awkcheck() {
  report "$1" "$2" "$3" "$(files | xargs -0r awk "$4" 2>/dev/null)"
}

[ -z "$(files | head -c1)" ] && { echo "no .py files under $ROOT"; exit 0; }

# --- Linter ---
LINTER=none
if command -v ruff >/dev/null 2>&1; then
  LINTER=ruff
  echo "# ruff (Google docstring convention, 80 cols) - rule statistics"
  ruff check --no-cache --exit-zero --statistics \
    --select E,W,F,N,D,B,UP,PL,ANN \
    --config 'lint.pydocstyle.convention = "google"' \
    --config 'line-length = 80' . 2>&1 | head -n 40
  echo "# ruff samples"
  ruff check --no-cache --exit-zero --output-format concise \
    --select E,W,F,N,D,B,UP,PL,ANN \
    --config 'lint.pydocstyle.convention = "google"' \
    --config 'line-length = 80' . 2>&1 | head -n $((MAX * 10))
elif command -v pylint >/dev/null 2>&1; then
  LINTER=pylint
  echo "# pylint"
  pylint --recursive=y --max-line-length=80 --score=n --output-format=parseable \
    --ignore=.git,.venv,venv,env,build,dist,node_modules,__pycache__,vendor . 2>&1 \
    | head -n $((MAX * 10))
else
  echo "NOTE no ruff/pylint found - 'pip install ruff' enables precise checks; heuristics only"
fi

# --- Heuristics (always) ---
echo "# heuristics"
check P1 error "tab character" $'\t'
check P2 error "line > 80 cols" '^(?!\s*(from|import)\s)(?!.*(https?://|pylint: disable)).{81,}$'
check P3 error "backslash line continuation" '^(?!\s*#).*\\$'
check P4 error "bare except:" '^\s*except\s*:'
check P5 error "mutable default argument" 'def\s+\w+\(.*=\s*(\[\]|\{\}|list\(\)|dict\(\)|set\(\))'
check P6 error "wildcard import" '^\s*from\s+\S+\s+import\s+\*'
check P7 error "relative import" '^\s*from\s+\.+\S*\s+import\b'
check P8 error "comparison to None/True/False with ==/!=" '(==|!=)\s*(None|True|False)\b|\b(None|True|False)\s*(==|!=)'
check P9 warning "several modules imported on one line" '^\s*import\s+\w[\w.]*\s*,'
check P10 warning "several statements on one line (;)" $'^(?!\\s*#)[^#"\']*;\\s*\\S'
check P11 warning "@staticmethod (prefer a module-level function)" '^\s*@staticmethod\b'
check P12 warning "logging call with f-string (use %-placeholders)" $'\\b(logging|logger|log|LOGGER|_LOGGER)\\.(debug|info|warning|error|exception|critical|log)\\(\\s*f["\']'
checkc P13 info "TODO format: # TODO: <link> - <text>" '#\s*TODO\b(?!:\s*\S+\s+-\s|\([^)]+\):\s)'
check P15 error "open() without with-statement" '^\s*\w+\s*=\s*open\('

# Docstring heuristics only when ruff (rules D1xx) did not run.
if [ "$LINTER" != ruff ]; then
  awkcheck D1 error "module without docstring" '
    FNR == 1 { done = 0 }
    done { next }
    /^[ \t]*$/ || /^#/ { next }
    { if ($0 !~ /^[rRuU]?("""|\047\047\047)/) print FILENAME ":" FNR ":" $0; done = 1 }'
  awkcheck D2 error "public class/function without docstring" '
    FNR == 1 { want = 0; sig = 0 }
    {
      if (want) {
        if ($0 ~ /^[ \t]*$/) next
        if ($0 !~ /^[ \t]*[rRuU]?("""|\047\047\047)/) print pend
        want = 0
      }
      if (sig) { if ($0 ~ /:[ \t]*(#.*)?$/) { sig = 0; want = 1 }; next }
      if ($0 ~ /^[ \t]*(async[ \t]+)?def[ \t]+[A-Za-z]/ || $0 ~ /^[ \t]*class[ \t]+[A-Za-z]/) {
        if (FILENAME ~ /(^|\/)test_[^\/]*\.py$|_test\.py$/ && $0 ~ /def[ \t]+test/) next
        pend = FILENAME ":" FNR ":" $0
        if ($0 ~ /:[ \t]*(#.*)?$/) want = 1; else sig = 1
      }
    }'
fi

echo "TOTAL $TOTAL (heuristics; linter findings listed separately)"
