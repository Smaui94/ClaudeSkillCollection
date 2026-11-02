#!/usr/bin/env bash
# Heuristic Google C# style scan. Usage: check.sh [root] [max_hits_per_rule]
# Output: one block per rule that has hits: "## ID count | description" + up to N "file:line: code".
ROOT="${1:-.}"
MAX="${2:-8}"
TOTAL=0
cd "$ROOT" || exit 1

files() {
  find . -type f -name '*.cs' \
    -not -path '*/bin/*' -not -path '*/obj/*' -not -path '*/.git/*' \
    -not -name '*.Designer.cs' -not -name '*.g.cs' -not -name '*.g.i.cs' \
    -not -name 'AssemblyInfo.cs' -not -path '*/Migrations/*' -print0
}

# check ID "description" "pcre"
check() {
  local id="$1" desc="$2" re="$3" out n
  out=$(files | xargs -0r grep -HnP -- "$re" 2>/dev/null | grep -vP '^[^:]+:\d+:\s*(//|\*|/\*|#)')
  report "$id" "$desc" "$out"
}

# report ID "description" "hits"
report() {
  local n
  [ -z "$3" ] && return
  n=$(printf '%s\n' "$3" | wc -l)
  TOTAL=$((TOTAL + n))
  echo "## $1 $n | $2"
  printf '%s\n' "$3" | head -n "$MAX" | cut -c1-180
}

# awkcheck ID "description" 'awk program printing FILENAME ":" FNR ":" $0'
awkcheck() {
  report "$1" "$2" "$(files | xargs -0r awk "$3" 2>/dev/null)"
}

[ -z "$(files | head -c1)" ] && { echo "no .cs files under $ROOT"; exit 0; }

# --- Formatting ---
check F1 "tab character" $'\t'
check F2 "line > 100 cols" '^.{101,}$'
check F3 "brace on own line (Allman)" '^\s*\{\s*$'
check F4 "'}' and 'else'/'catch'/'finally' on different lines" '^\s*(else|catch|finally)\b'
check F5 "single-line control statement without braces" '^\s*(if|else if|for|foreach|while|lock|using|fixed)\s*\(.*\)\s*[^\s{].*;\s*$|^\s*else\s+(?!if\b)[^\s{].*;\s*$|\{\s*(lock|using|fixed)\s*\(.*\)\s*[^\s{].*;'
check F5c "one-line try/catch/finally block" '^\s*(\}\s*)?(try|catch\b[^{]*|finally)\s*\{.*;\s*\}\s*$'
# F5b: control header ending the line, next non-blank line is not '{' (Allman braces are F3, not F5)
awkcheck F5b "control statement without braces (multi-line)" '
  FNR == 1 { hdr = "" }
  /^[ \t]*$/ { next }
  { if (hdr != "" && $0 !~ /^[ \t]*\{/) print hdr
    hdr = ($0 ~ /^[ \t]*(\}[ \t]*)?((else[ \t]+)?if|for|foreach|while)[ \t]*\(.*\)[ \t]*$/ || $0 ~ /^[ \t]*(\}[ \t]*)?else[ \t]*$/) ? FILENAME ":" FNR ":" $0 : "" }'
check F6 "no space after keyword" '\b(if|for|foreach|while|switch|catch|using|lock)\('
check F7 "space inside parentheses" '\(\s+[^\s)]|[^\s(]\s+\)'
check F8 "odd indentation (ok only if aligned to first argument)" '^( {2})* [^ *]'
# F9: line after a line ending in '{' indented by != 2 more spaces
awkcheck F9 "block indent not 2 spaces" '
  FNR == 1 { open = 0 }
  /^[ \t]*$/ { next }
  { match($0, /^ */); ind = RLENGTH
    if (open && $0 !~ /^ *}/ && ind - pind != 2) print FILENAME ":" FNR ":" $0
    open = ($0 ~ /\{[ \t]*$/); pind = ind }'
check F10 "multiple statements on one line" '^(?!\s*for\s*\()(?!.*\b(get|set|init)\s*;).*;\s*[^\s/}].*;\s*$'
check F11 "chained assignment" '(?<![=!<>+\-*/%&|^?])=(?![=>])\s*[\w.]+\s*(?<![=!<>+\-*/%&|^?])=(?![=>])'
check F12 "attribute on same line as member / multiple attrs per line" '^\s*\[[^\]]+\]\s*(\[|(public|private|protected|internal|static|void|async|override)\b)|^\s*\[\w+(\([^)]*\))?\s*,\s*\w'

# --- Naming ---
check N1 "non-public field/property not _camelCase" '^\s*(private|protected|internal)(\s+(protected|internal|static|readonly|const|volatile|new))*\s+[\w<>\[\],.?]+\s+(?!_[a-z])\w+\s*(=(?!>)|;|\{\s*get)'
check N2 "public member/type not PascalCase" '^\s*public(\s+(static|readonly|const|virtual|override|abstract|sealed|async|new|partial))*\s+([\w<>\[\],.?]+\s+)?[a-z_]\w*\s*(\(|=|;|\{|<)'
check N3 "interface without I prefix" '\binterface\s+(?!I[A-Z])\w+'
check N4 "acronym in caps in declared name (use MyRpc not MyRPC)" '^\s*(?:(?:public|private|protected|internal|static|readonly|const|override|virtual|abstract|sealed|async|partial|new)\s+)+(?:(?:class|interface|enum|struct|record)\s+|[\w<>\[\]?.]+\s+)?\w*[A-Z]{3,}\w*\s*($|[({<;=:])'
check N5 "local variable/parameter not camelCase" '^\s+(var|int|string|bool|double|float|long)\s+(_|[A-Z])\w*\s*='

# --- Organization ---
check O1 "using directive indented (inside namespace?)" '^\s+using\s+(static\s+)?[\w.]+\s*;'
check O2 "modifier order" '\b(static|readonly|virtual|override|abstract|sealed|async|extern|unsafe|volatile|new)\s+(public|protected|internal|private)\b|\breadonly\s+static\b|\b(static|sealed|override)\s+(abstract|virtual)\b|\bsealed\s+override\b|\basync\s+(static|override|virtual|abstract|unsafe)\b'
check O3 "namespace deeper than 2 levels" '^\s*namespace\s+\w+(\.\w+){2,}'
check O4 "using alias" '^\s*using\s+\w+\s*=\s*'

# --- Guidelines (review, not hard errors) ---
check G1 "LINQ query syntax (prefer method syntax)" '\bfrom\s+\w+\s+in\s+\w'
check G2 "Tuple<> (prefer named class)" '\bTuple<'
check G3 "delegate call without ?.Invoke" '(?<!\?)\.Invoke\(|if\s*\(\s*\w+\s*!=\s*null\s*\)\s*\w+\s*\('
check G4 "multi-statement List.ForEach" '\.ForEach\(\s*\(?\w*\)?\s*=>\s*\{'
check G5 "var with literal (use explicit type)" '\bvar\s+\w+\s*=\s*(true|false|-?\d[\d_.]*[fFdDmMlLuU]*|"[^"]*"|'"'"'.'"'"')\s*;'
check G6 "out param not last" '\(.*\bout\s+[\w<>\[\]?.]+\s+\w+\s*,\s*(?!out\b)[\w\[]'
check G7 "ref parameter (rarely justified)" '[(,]\s*ref\s+(?!readonly\b)[\w<>\[\]?.]+\s+\w+\s*[,)]'
check G8 "struct definition (prefer class)" '\b(?<!readonly\s)(?<!record\s)struct\s+[A-Z]\w*'
check G9 "extension method" '\(\s*this\s+[\w<>\[\],?]+\s+\w+'
check G10 "public List<>/array in API (check IList/IReadOnlyList)" '^\s*public\s+(static\s+|virtual\s+|override\s+)*(List<|\w+\[\]\s)'
check G11 "bool parameter (consider enum)" '^\s*(public|internal|protected)\s[^=]*\((.*,\s*)?bool\s+\w+'
check G12 "string += in loop candidate (StringBuilder)" '\w+\s*\+=\s*\$?"'


# --- Comments ---
# C1: type or member declaration without a preceding '///' documentation comment
awkcheck C1 "declaration without /// doc comment (mandatory)" '
  FNR == 1 { doc = 0 }
  /^[ \t]*$/ { next }
  /^[ \t]*\[/ { next }
  /^[ \t]*\/\/\// { doc = 1; next }
  { s = $0; decl = 0
    if (s ~ /^[ \t]*(public|protected|internal|private)[ \t]/ || s ~ /^[ \t]*((partial|static|abstract|sealed|record)[ \t]+)*(class|struct|interface|enum|record|delegate)[ \t]/) {
      if (s ~ /(^|[ \t])(class|struct|interface|enum|record|delegate)[ \t]+[A-Za-z_]/) decl = 1
      else { t = s; gsub(/=>/, "@>", t)
        if (t !~ /=/ && (t ~ /\(/ || t ~ /@>/ || t ~ /\{[ \t]*(get|set|init)/)) decl = 1 } }
    if (decl && !doc) print FILENAME ":" FNR ":" s
    doc = 0 }'

echo "TOTAL $TOTAL"
