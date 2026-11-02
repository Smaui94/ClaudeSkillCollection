#!/usr/bin/env bash
# Google Java style + mandatory Javadoc scan.
# Usage: check.sh [root] [max_hits_per_rule]   Env: JDOC_SCOPE=all|visible (default all)
# Output: "## ID count SEV | description" + up to N "file:line:code|message" per rule, then TOTAL.
ROOT="${1:-.}"
MAX="${2:-8}"
TOTAL=0
HERE="$(cd "$(dirname "$0")" && pwd)"
export LC_ALL=C
cd "$ROOT" || exit 1

files() {
  find . \( -name .git -o -name target -o -name build -o -name out -o -name bin -o -name .gradle \
    -o -name .idea -o -name node_modules -o -name generated -o -name generated-sources \) -prune \
    -o -type f -name '*.java' -print0
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

# check ID SEV "description" "pcre"  (comment and Javadoc lines are skipped)
check() {
  report "$1" "$2" "$3" "$(files | xargs -0r grep -HnP -- "$4" 2>/dev/null \
    | grep -vP '^[^:]+:\d+:\s*(//|\*|/\*)')"
}

# awkcheck ID SEV "description" 'awk program printing FILENAME ":" FNR ":" $0'
awkcheck() {
  report "$1" "$2" "$3" "$(files | xargs -0r awk "$4" 2>/dev/null)"
}

[ -z "$(files | head -c1)" ] && { echo "no .java files under $ROOT"; exit 0; }

# Declaration-aware checks (Javadoc, naming, structure) in one pass.
S=$(files | xargs -0r awk -f "$HERE/structure.awk" 2>/dev/null)
struct() { report "$1" "$2" "$3" "$(printf '%s\n' "$S" | grep -P "^$1\t" | cut -f2-)"; }

# --- Javadoc (project rule: every class, method and constructor) ---
struct D1 MUST "missing Javadoc on class/method/constructor"
struct D2 MUST "@param missing or unknown (records: components)"
struct D3 MUST "@return missing (non-void) or misplaced (void/ctor)"
struct D4 MUST "@throws missing for declared exception"
struct D5 MUST "block tag order @param @return @throws @deprecated"
struct D6 MUST "block tag with empty description"
struct D7 SHOULD "summary fragment (capitalized, punctuated, not 'This method', not imperative)"
struct D8 MUST "Javadoc formatting (<p>, blank line before tags, single-line form)"
struct D9 MUST "visible field without Javadoc"

# --- Source file / imports ---
struct O1 MUST "file name = single top-level class"
struct O2 MUST "package declaration missing"
check O3w MUST "wildcard or module import" '^\s*import\s+((static\s+)?[\w.]+\.\*|module\s)\s*'
struct O4 MUST "import order: static group, blank line, non-static; ASCII-sorted"
struct O3 MUST "overloads not contiguous"

# --- Formatting ---
check F1 MUST "tab character" $'\t'
check F2 MUST "line > 100 cols" '^(?!\s*(package|import)\s)(?!.*https?://).{101,}$'
awkcheck F3 MUST "'{' on its own line (K&R)" '
  FNR == 1 { prev = "" }
  /^[ \t]*$/ || /^[ \t]*(\/\/|\*|\/\*)/ { next }
  /^[ \t]*\{[ \t]*$/ && prev !~ /[;{}][ \t]*$/ { print FILENAME ":" FNR ":" $0 }
  { prev = $0 }'
check F4 MUST "'}' and else/catch/finally on different lines" '^\s*(else|catch|finally)\b'
check F5 MUST "if/else/for/while/do without braces (single line)" '^\s*(\}\s*)?(if|else if|for|while)\s*\(.*\)\s*(?![{;])[^\s{].*;\s*$|^\s*(\}\s*)?(else|do)\s+(?!if\b)[^\s{].*;\s*$'
awkcheck F5b MUST "if/else/for/while/do without braces (multi-line)" '
  FNR == 1 { hdr = "" }
  /^[ \t]*$/ || /^[ \t]*(\/\/|\*|\/\*)/ { next }
  { if (hdr != "" && $0 !~ /^[ \t]*\{/) print hdr
    hdr = ($0 ~ /^[ \t]*(\}[ \t]*)?((else[ \t]+)?if|for|while)[ \t]*\(.*\)[ \t]*$/ || $0 ~ /^[ \t]*(\}[ \t]*)?(else|do)[ \t]*$/) ? FILENAME ":" FNR ":" $0 : "" }'
check F6 MUST "no space between keyword and '('" '\b(if|for|while|switch|catch|synchronized|try)\('
check F7 MUST "missing space before '{' or after '}'" '\)\{|\b(else|try|finally|do)\{|\}(else|catch|finally)\b'
# Body is +2 from the statement start; lambda / anonymous class bodies from the line with '{'.
awkcheck F8 MUST "block indent not +2" '
  FNR == 1 { open = 0; ended = 1; tb = 0 }
  /^[ \t]*$/ { next }
  tb { if ($0 ~ /"""/) tb = 0; next }
  { if (gsub(/"""/, "&") % 2) tb = 1
    match($0, /^ */); ind = RLENGTH
    if ($0 ~ /^[ \t]*(\*|\/\/|\/\*)/) next
    if (open && $0 !~ /^ *}/ && ind - pind != 2) print FILENAME ":" FNR ":" $0
    if (ended) stmt = ind
    open = ($0 ~ /\{[ \t]*$/)
    pind = ($0 ~ /(->|\)|new [A-Za-z0-9_.<>]+\(.*\))[ \t]*\{[ \t]*$/ && $0 ~ /->|new /) ? ind : stmt
    ended = ($0 ~ /[;{}][ \t]*$/ || $0 ~ /^[ \t]*@[A-Za-z]+(\(.*\))?[ \t]*$/) }'
check F10 MUST "more than one statement per line" '^(?!\s*for\s*\()(?!.*->).*;\s*[^\s/}].*;\s*$'
struct F11 MUST "one variable per declaration (fields)"
check F11l MUST "one variable per declaration (locals)" '^\s+(final\s+)?(?!return\b|throw\b|new\b|else\b)(int|long|short|byte|double|float|char|boolean|String|var)(\[\])*\s+\w+(\s*=\s*[^,;()]+)?\s*,\s*\w+\s*(=|;|,)'
check F12 MUST "C-style array declaration" '\b[\w>]+\s+\w+(\[\])+\s*(=|;|,|\))'
check F13 MUST "long literal with lowercase l" '\b\d[\d_]*l\b'
check F14 MUST "line break after operator (break before it)" '^(?!.*(//|/\*|\*/)).*(&&|\|\||(?<![+\-])[+\-](?![+\-=>])|(?<![*/])[*%]|(?<![*/])/(?![/*])|\?|==|!=|<=|>=|(?<!\.)\.|::)\s*$'
check F15 MUST "special char as octal/unicode escape (use \\n, \\t ...)" '\\u00(0[89aAcCdD]|2[27]|5[cC])|\\(010|011|012|014|015|042|047|134)(?![0-7])'
check F16 MUST "modifier order (public protected private abstract default static final sealed non-sealed transient volatile synchronized native strictfp)" '\b(static|final|abstract|synchronized|native|transient|volatile|sealed)\s+(public|protected|private)\b|\bfinal\s+(static|abstract)\b|\bstatic\s+abstract\b|\b(transient|volatile|synchronized|native)\s+(static|final|abstract)\b|\bnative\s+synchronized\b'
check F17 SHOULD "annotation placement (class/method: one per line; single parameterless allowed on method line)" '^\s*@\w+(\([^)]*\))?\s+((public|protected|private|abstract|final|static|sealed)\s+)*(class|interface|enum|record|@interface)\b|^\s*(@\w+(\([^)]*\))?\s+){2,}.*\)\s*(throws\s[\w., ]+)?\{?\s*$|^\s*@\w+\([^)]*\)\s+(public|protected|private|static|final|abstract|synchronized|<|void\b)[^=;]*\('
check F18 SHOULD "TODO format: // TODO: <link> - <text>" '\bTODO\b(?!: \S+ - )'

# --- Naming ---
struct N1 MUST "class name not UpperCamelCase"
struct N2 MUST "method name not lowerCamelCase"
struct N3 MUST "constant naming (UPPER_SNAKE_CASE only for deeply immutable static final)"
struct N4 MUST "non-constant field naming (lowerCamelCase)"
struct N5 MUST "prefix/suffix in name (mName, kName, s_name, name_)"
check N6 MUST "package name not lowercase" '^\s*package\s+[\w.]*[A-Z_]'
struct N7 MUST "parameter not lowerCamelCase"
check N7l MUST "local variable not lowerCamelCase (final locals too)" '^(?!.*\b(public|protected|private|static)\b)\s+(final\s+)?(var|int|long|short|byte|double|float|char|boolean|String|[A-Z]\w*(<[^;=()]*>)?)(\[\])*\s+(?!_\s*[=:])([A-Z]\w*|\w*_\w*)\s*(=|;|:)'
struct N8 MUST "acronym not camel-cased"
struct N9 MUST "type variable name (T, T2, RequestT)"

# --- Programming practices ---
struct P1 MUST "missing @Override (equals/hashCode/toString; others need review)"
check P2 MUST "empty catch block without explanatory comment" 'catch\s*\([^)]*\)\s*\{\s*\}'
awkcheck P2b MUST "empty catch block without explanatory comment (multi-line)" '
  FNR == 1 { c = "" }
  { if (c != "" && $0 ~ /^[ \t]*\}/) print c
    c = ($0 ~ /catch[ \t]*\(.*\)[ \t]*\{[ \t]*$/) ? FILENAME ":" FNR ":" $0 : "" }'
struct P4 MUST "finalizer"
struct P5 MUST "switch without default (exhaustiveness; enums may be fine - verify)"
struct P6 MUST "old-style switch fall-through without comment"

echo "TOTAL $TOTAL"
