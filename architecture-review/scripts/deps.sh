#!/usr/bin/env bash
#
# Extracts module-level dependencies for the architecture-review skill.
# Usage: deps.sh [source_root] [depth]
# Env:   INCLUDE_TESTS=1 includes test code, MERMAID=1 prints a Mermaid graph.
# Output: module edges, cycles, fan-in/fan-out, unresolved imports.
#
# No "set -e": grep finding nothing is an expected, non-fatal result here.
set -u

readonly ROOT="${1:-.}"
readonly DEPTH="${2:-2}"
HERE="$(cd "$(dirname "$0")" && pwd)"
readonly HERE
LIST_FILE=""

#######################################
# Lists source files below the current directory.
# Globals:
#   INCLUDE_TESTS
# Outputs:
#   One relative path per line.
#######################################
list_sources() {
  find . \( -name .git -o -name node_modules -o -name vendor -o -name .venv \
    -o -name venv -o -name build -o -name dist -o -name out -o -name target \
    -o -name bin -o -name obj -o -name __pycache__ -o -name .godot \
    -o -name generated -o -name Migrations \) -prune -o -type f \
    \( -name '*.py' -o -name '*.js' -o -name '*.jsx' -o -name '*.ts' \
    -o -name '*.tsx' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.vue' \
    -o -name '*.svelte' -o -name '*.java' -o -name '*.kt' -o -name '*.cs' \
    -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' \
    -o -name '*.h' -o -name '*.hh' -o -name '*.hpp' -o -name '*.hxx' \
    -o -name '*.go' -o -name '*.gd' \) -print \
    | sed 's#^\./##' \
    | grep -vE '\.(min|d)\.(js|ts)$|\.g\.cs$|\.Designer\.cs$' \
    | if [[ -n "${INCLUDE_TESTS:-}" ]]; then
        cat
      else
        grep -vE '(^|/)(test|tests|__tests__|spec|specs|testdata)/|_test\.go$|Tests?\.(java|kt|cs)$|\.(test|spec)\.[jt]sx?$|(^|/)test_[^/]*\.py$|_test\.py$'
      fi \
    | sort
}

#######################################
# Prints the module path from the shallowest go.mod, if any.
# Outputs:
#   "<module path><TAB><dir>" or nothing.
#######################################
go_module() {
  local mod
  mod="$(find . -name go.mod -not -path '*/vendor/*' 2>/dev/null \
    | awk -F/ '{ print NF "\t" $0 }' | sort -n | head -n 1 | cut -f2)"
  [[ -z "${mod}" ]] && return 0
  printf '%s\t%s\n' \
    "$(sed -n 's/^module[[:space:]]*//p' "${mod}" | tr -d '\r' | head -n 1)" \
    "$(dirname "${mod}" | sed 's#^\./##; s#^\.$##')"
}

#######################################
# Prints the directory of the shallowest project.godot, if any.
# Outputs:
#   Directory relative to the root ("" for the root itself).
#######################################
godot_dir() {
  find . -name project.godot 2>/dev/null | awk -F/ '{ print NF "\t" $0 }' \
    | sort -n | head -n 1 | cut -f2 | xargs -r dirname \
    | sed 's#^\./##; s#^\.$##'
}

#######################################
# Collects inputs and runs the extractor.
# Arguments:
#   None (uses ROOT, DEPTH).
#######################################
main() {
  local gomod gopath godir godot
  cd "${ROOT}" || exit 1
  LIST_FILE="$(mktemp)"
  trap 'rm -f "${LIST_FILE}"' EXIT
  list_sources > "${LIST_FILE}"
  if [[ ! -s "${LIST_FILE}" ]]; then
    echo "no supported source files under ${ROOT}"
    exit 0
  fi
  gomod="$(go_module)"
  gopath="${gomod%%$'\t'*}"
  godir="${gomod#*$'\t'}"
  [[ -z "${gomod}" ]] && godir=""
  godot="$(godot_dir)"
  awk -v depth="${DEPTH}" -v gomod="${gopath}" -v godir="${godir}" \
    -v godot="${godot}" -v mermaid="${MERMAID:-}" \
    -f "${HERE}/deps.awk" "${LIST_FILE}"
}

main "$@"
