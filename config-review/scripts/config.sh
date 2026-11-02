#!/usr/bin/env bash
#
# Collects config file facts for the config-review skill.
# Usage: config.sh [root] [max_hits_per_rule]
# Output: "## ID count SEV | description" + up to N samples, then TOTAL.
# JSON checks (syntax, duplicate keys, nested keys) need Python 3.
#
# No "set -e": grep finding nothing is an expected, non-fatal result here.
set -u

readonly ROOT="${1:-.}"
readonly MAX="${2:-10}"
TOTAL=0
FLAT=""
DUPS=""

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
# Lists config files below the current directory.
# Outputs:
#   One relative path per line.
#######################################
list_configs() {
  find . \( -name .git -o -name node_modules -o -name vendor -o -name .venv \
    -o -name venv -o -name build -o -name dist -o -name out -o -name target \
    -o -name bin -o -name obj -o -name __pycache__ -o -name .godot \) -prune \
    -o -type f -size -1024k \( -name '*.yml' -o -name '*.yaml' -o -name '*.json' \
    -o -name '*.toml' -o -name '*.ini' -o -name '*.cfg' -o -name '*.conf' \
    -o -name '*.properties' -o -name '.env' -o -name '.env.*' -o -name '*.env' \) \
    ! -name 'package-lock.json' ! -name '*.lock' ! -name 'composer.lock' \
    ! -name '*.min.json' -print | sed 's#^\./##' | sort
}

#######################################
# Finds a Python 3 interpreter (the Windows store stub is skipped).
# Outputs:
#   Interpreter command or nothing.
#######################################
find_python() {
  local c
  for c in python3 python py; do
    if "${c}" -c 'import sys; sys.exit(sys.version_info < (3, 6))' \
        >/dev/null 2>&1; then
      echo "${c}"
      return 0
    fi
  done
}

#######################################
# Duplicate keys and flattened keys for YAML, .env, .properties and INI.
# Arguments:
#   Config files.
# Outputs:
#   "DUP<TAB>file:line<TAB>key" and "FLAT<TAB>file<TAB>key<TAB>type" lines.
#######################################
scan_text_configs() {
  awk '
    function vtype(v) {
      sub(/[ \t]+#.*$/, "", v)
      if (v ~ /^[ \t]*$/) return "map"
      if (v ~ /^[ \t]*-?[0-9]+(\.[0-9]+)?[ \t]*$/) return "number"
      if (v ~ /^[ \t]*(true|false|True|False)[ \t]*$/) return "bool"
      if (v ~ /^[ \t]*\[/) return "list"
      return "string"
    }
    function emit(key, v, line) {
      if ((FILENAME SUBSEP key) in seen)
        print "DUP\t" FILENAME ":" line "\t" key " (first at line " \
          seen[FILENAME SUBSEP key] ")"
      else
        seen[FILENAME SUBSEP key] = line
      print "FLAT\t" FILENAME "\t" key "\t" vtype(v)
    }
    FNR == 1 {
      kind = (FILENAME ~ /\.ya?ml$/) ? "yaml" : "kv"
      depth = 0; section = ""; block = -1; seq = 0
    }
    { sub(/\r$/, "") }
    kind == "kv" {
      if ($0 ~ /^[ \t]*([#;!]|$)/) next
      if (match($0, /^[ \t]*\[[^]]+\]/)) {
        section = substr($0, RSTART, RLENGTH)
        gsub(/^[ \t]*\[|\]$/, "", section)
        next
      }
      line = $0
      sub(/^[ \t]*export[ \t]+/, "", line)
      if (!match(line, /^[ \t]*[^=: \t]+[ \t]*[=:]/)) next
      key = substr(line, RSTART, RLENGTH)
      v = substr(line, RSTART + RLENGTH)
      sub(/[ \t]*[=:]$/, "", key)
      sub(/^[ \t]+/, "", key)
      emit((section != "" ? section "." : "") key, v, FNR)
      next
    }
    kind == "yaml" {
      if ($0 ~ /^---/) {
        # New YAML document: keys may repeat.
        depth = 0; block = -1
        for (k in seen) if (index(k, FILENAME SUBSEP) == 1) delete seen[k]
        next
      }
      if ($0 ~ /^[ \t]*(#|$)/) next
      match($0, /^ */)
      ind = RLENGTH
      if (block >= 0) { if (ind > block) next; block = -1 }
      rest = substr($0, ind + 1)
      if (rest ~ /^- /) {
        # A list item closes deeper entries and the previous item at this level.
        while (depth > 0 && (ind_[depth] > ind \
            || (ind_[depth] == ind && name_[depth] ~ /^\[/))) depth--
        depth++; ind_[depth] = ind; name_[depth] = "[" (++seq) "]"
        ind = ind + 2
        rest = substr(rest, 3)
        sub(/^ +/, "", rest)
      }
      if (!match(rest, /^("[^"]+"|\047[^\047]+\047|[^#{}\[\]"\047 ][^:#]*):( |$)/)) next
      key = substr(rest, 1, RLENGTH)
      v = substr(rest, RLENGTH + 1)
      sub(/:[ ]?$/, "", key)
      while (depth > 0 && ind_[depth] >= ind) depth--
      path = ""
      for (i = 1; i <= depth; i++) path = path name_[i] "."
      emit(path key, v, FNR)
      if (v ~ /^[ \t]*[|>][-+0-9]*[ \t]*(#.*)?$/) block = ind
      depth++; ind_[depth] = ind; name_[depth] = key
    }
  ' "$@" 2>/dev/null
}

#######################################
# Syntax, duplicate keys and flattened keys for JSON files (Python 3).
# Arguments:
#   Python command, JSON files.
# Outputs:
#   "ERR<TAB>file<TAB>msg", "DUP<TAB>file:line<TAB>key", "FLAT..." lines.
#######################################
scan_json() {
  local py="$1"
  shift
  "${py}" -I - "$@" <<'PY'
import json, re, sys

def strip_comments(text):
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1]); i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True; out.append(c)
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            out.append("\n" * text.count("\n", i, j if j >= 0 else n))
            i = (j + 2) if j >= 0 else n
            continue
        else:
            out.append(c)
        i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))

def jtype(v):
    if isinstance(v, bool): return "bool"
    if isinstance(v, (int, float)): return "number"
    if isinstance(v, list): return "list"
    if isinstance(v, dict): return "map"
    return "string" if isinstance(v, str) else "null"

for path in sys.argv[1:]:
    try:
        text = open(path, encoding="utf-8-sig").read()
    except (OSError, UnicodeDecodeError) as e:
        print("ERR\t%s\tunreadable: %s" % (path, e)); continue
    dups = []
    def hook(pairs):
        keys = [k for k, _ in pairs]
        dups.extend(k for i, k in enumerate(keys) if k in keys[:i])
        return dict(pairs)
    jsonc = bool(re.search(r"(^|/)(tsconfig[^/]*|jsconfig[^/]*|appsettings[^/]*"
                           r"|\.vscode/[^/]*|devcontainer)\.json$", path))
    try:
        data = json.loads(text, object_pairs_hook=hook)
    except ValueError as e:
        try:
            data = json.loads(strip_comments(text), object_pairs_hook=hook)
            if not jsonc:
                print("ERR\t%s\tparses only with comments/trailing commas removed" % path)
        except ValueError:
            print("ERR\t%s\t%s" % (path, e)); continue
    lines = text.splitlines()
    for k in sorted(set(dups)):
        hits = [i + 1 for i, l in enumerate(lines) if re.search(r'"%s"\s*:' % re.escape(k), l)]
        print("DUP\t%s:%s\t%s (key name occurs at lines %s)"
              % (path, hits[1] if len(hits) > 1 else (hits[0] if hits else "?"),
                 k, ",".join(map(str, hits[:5]))))
    def walk(v, prefix):
        if isinstance(v, dict) and v:
            for k, x in v.items():
                walk(x, prefix + "." + k if prefix else k)
        elif prefix:
            print("FLAT\t%s\t%s\t%s" % (path, prefix, jtype(v)))
    walk(data, "")
PY
}

#######################################
# Compares keys between environment variants of the same config.
# Input:
#   FLAT lines on stdin.
# Outputs:
#   "MISS<TAB>..." and "TYPE<TAB>..." lines.
#######################################
compare_variants() {
  awk -F'\t' '
    function group(f,    d, b) {
      d = f; b = f
      if (index(f, "/")) { sub(/\/[^\/]*$/, "", d); sub(/^.*\//, "", b) }
      else d = "."
      if (b ~ /^\.env(\..+)?$/ || b ~ /\.env$/) return d "/.env*"
      if (b ~ /^appsettings(\.[^.]+)?\.json$/) return d "/appsettings*.json"
      if (b ~ /^application(-[^.]+)?\.(ya?ml|properties)$/) return d "/application*"
      if (b ~ /^config(\.[^.]+)?\.(json|ya?ml|toml)$/) return d "/config*"
      return ""
    }
    function isbase(f,    b) {
      b = f; sub(/^.*\//, "", b)
      return b ~ /^(appsettings\.json|application\.(ya?ml|properties)|config\.(json|ya?ml|toml))$/
    }
    $1 == "FLAT" {
      g = group($2)
      if (g == "") next
      files[g SUBSEP $2] = 1
      key[g SUBSEP $3] = 1
      has[$2 SUBSEP $3] = $4
      if (isbase($2)) base[g] = $2
    }
    END {
      for (gf in files) {
        split(gf, p, SUBSEP); g = p[1]; f = p[2]; nf[g]++
      }
      for (gf in files) {
        split(gf, p, SUBSEP); g = p[1]; f = p[2]
        if (nf[g] < 2) continue
        for (gk in key) {
          split(gk, q, SUBSEP)
          if (q[1] != g) continue
          k = q[2]
          if (g ~ /\.env\*$/) {
            if (!((f SUBSEP k) in has))
              print "MISS\t" f ": missing " k " (defined in another .env variant)"
          } else if ((g in base) && f != base[g] && ((f SUBSEP k) in has) \
              && !((base[g] SUBSEP k) in has) && has[f SUBSEP k] != "map") {
            print "MISS\t" f ": " k " not in base " base[g] " (typo?)"
          }
          if ((g in base) && f != base[g] && ((f SUBSEP k) in has) \
              && ((base[g] SUBSEP k) in has) \
              && has[f SUBSEP k] != has[base[g] SUBSEP k])
            print "TYPE\t" f ": " k " is " has[f SUBSEP k] ", base has " \
              has[base[g] SUBSEP k]
        }
      }
    }'
}

#######################################
# Runs all checks.
# Arguments:
#   None (uses ROOT).
#######################################
main() {
  local -a files yaml kv json
  local py results f
  cd "${ROOT}" || exit 1
  mapfile -t files < <(list_configs)
  if [[ "${#files[@]}" -eq 0 ]]; then
    echo "no config files under ${ROOT}"
    exit 0
  fi
  for f in "${files[@]}"; do
    case "${f}" in
      *.yml | *.yaml) yaml+=("${f}") ;;
      *.json) json+=("${f}") ;;
      *.toml) ;;
      *) kv+=("${f}") ;;
    esac
  done
  echo "# ${#files[@]} config files (${#yaml[@]} YAML, ${#json[@]} JSON," \
    "${#kv[@]} env/ini/properties/cfg)"

  results=""
  if [[ "${#yaml[@]}" -gt 0 || "${#kv[@]}" -gt 0 ]]; then
    results="$(scan_text_configs "${yaml[@]}" "${kv[@]}")"
  fi
  py="$(find_python)"
  if [[ "${#json[@]}" -gt 0 ]]; then
    if [[ -n "${py}" ]]; then
      results+=$'\n'"$(scan_json "${py}" "${json[@]}")"
    else
      echo "NOTE Python 3 not found - JSON syntax/duplicate/variant checks skipped"
    fi
  fi
  FLAT="$(printf '%s\n' "${results}" | grep $'^FLAT\t')"
  DUPS="$(printf '%s\n' "${results}" | grep $'^DUP\t' | cut -f2- | tr '\t' ' ')"

  report CF1 error "syntax error / does not parse" \
    "$(printf '%s\n' "${results}" | grep $'^ERR\t' | cut -f2- \
      | sed $'s/\t/: /')"
  report CF2 error "duplicate key (later value wins)" "${DUPS}"
  if [[ "${#yaml[@]}" -gt 0 ]]; then
    report CF3 warning "YAML 1.1 boolean (yes/no/on/off) unquoted" \
      "$(grep -HnE ':[[:space:]]+(yes|no|on|off|y|n|Yes|No|YES|NO|On|Off|ON|OFF|Y|N)[[:space:]]*(#.*)?$' \
        "${yaml[@]}" 2>/dev/null)"
    report CF3 warning "number that loses digits or is octal (1.10, 0755)" \
      "$(grep -HnE ':[[:space:]]+([0-9]+\.[0-9]*0|0[0-9]+)[[:space:]]*(#.*)?$' \
        "${yaml[@]}" 2>/dev/null)"
    report CF3 error "tab in YAML indentation" \
      "$(grep -HnP '^ *\t' "${yaml[@]}" 2>/dev/null)"
  fi
  if [[ "${#kv[@]}" -gt 0 ]]; then
    report CF3 warning ".env line with spaces around = or unquoted spaces" \
      "$(printf '%s\n' "${kv[@]}" | grep -E '(^|/)\.env|\.env$' \
        | tr '\n' '\0' | xargs -0r grep -HnE \
        '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]+=|^[^#=]+=[[:space:]]+[^[:space:]]|^[^#=]+=[^"'"'"']*[^[:space:]"'"'"'][[:space:]]+[^[:space:]#]' \
        2>/dev/null)"
  fi
  report CF4 warning "key missing in an environment variant" \
    "$(printf '%s\n' "${FLAT}" | compare_variants | grep $'^MISS\t' \
      | cut -f2- | sort -u)"
  report CF5 warning "key has a different type than in the base file" \
    "$(printf '%s\n' "${FLAT}" | compare_variants | grep $'^TYPE\t' \
      | cut -f2- | sort -u)"
  report CF6 error "insecure setting (verify: dev-only files are fine)" \
    "$(grep -HniP '\bdebug\b["\x27]?\s*[:=]\s*["\x27]?(true|1|yes|on)\b|(allow[_-]?origins?|cors[\w.-]*)["\x27]?\s*[:=]\s*[\["\x27 ]*\*|(verify[_-]?(ssl|tls|cert)|ssl[_-]?verify|tls[_-]?verify|rejectUnauthorized|check[_-]?hostname)["\x27]?\s*[:=]\s*["\x27]?(false|0|no|off)\b|insecure[_-]?skip[_-]?verify["\x27]?\s*[:=]\s*["\x27]?(true|1|yes)\b' \
      "${files[@]}" 2>/dev/null)"
  report CF12 warning "machine-specific path or user name" \
    "$(grep -HnP '[A-Za-z]:\\\\?(Users|Dokumente|Documents)\\\\?|/home/[a-z][\w.-]*/|/Users/[A-Za-z][\w.-]*/' \
      "${files[@]}" 2>/dev/null)"
  echo "TOTAL ${TOTAL}"
}

main "$@"
