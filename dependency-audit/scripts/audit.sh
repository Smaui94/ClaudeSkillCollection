#!/usr/bin/env bash
# Finds dependency manifests and runs installed audit tools. Read-only: nothing is updated.
# Usage: audit.sh [root]   Env: OFFLINE=1 skips tools that contact advisory databases.
# Output: sections "## manifests", "## DP4 ...", "## DP3 ...", "# <tool>" and "## tools missing".
ROOT="${1:-.}"
export LC_ALL=C
cd "$ROOT" || exit 1

have() { command -v "$1" >/dev/null 2>&1; }
anyof() { local d="$1" f; shift; for f in "$@"; do [ -e "$d/$f" ] && return 0; done; return 1; }
cap() { head -n "${1:-80}"; }

mapfile -t M < <(find . \( -name .git -o -name node_modules -o -name vendor -o -name .venv \
  -o -name venv -o -name build -o -name dist -o -name target -o -name bin -o -name obj \) -prune \
  -o -type f \( -name 'requirements*.txt' -o -name pyproject.toml -o -name Pipfile \
  -o -name setup.py -o -name setup.cfg -o -name package.json -o -name pom.xml \
  -o -name build.gradle -o -name build.gradle.kts -o -name '*.csproj' -o -name packages.config \
  -o -name Directory.Packages.props -o -name vcpkg.json -o -name conanfile.txt \
  -o -name conanfile.py -o -name Cargo.toml -o -name go.mod -o -name Gemfile \
  -o -name composer.json \) -print | sed 's#^\./##' | sort)

echo "## manifests (${#M[@]})"
[ "${#M[@]}" -eq 0 ] && { echo "none found"; exit 0; }
printf '%s\n' "${M[@]}"

missing=()
note_missing() { case " ${missing[*]} " in *" $1 "*) ;; *) missing+=("$1") ;; esac; }

# --- DP4 lock files ---
echo "## DP4 lock files"
for m in "${M[@]}"; do
  d=$(dirname "$m"); b=$(basename "$m")
  case "$b" in
    package.json) anyof "$d" package-lock.json yarn.lock pnpm-lock.yaml bun.lockb bun.lock \
      || echo "$m: no package-lock.json/yarn.lock/pnpm-lock.yaml" ;;
    pyproject.toml) anyof "$d" poetry.lock uv.lock pdm.lock requirements.txt \
      || echo "$m: no poetry.lock/uv.lock/pdm.lock/requirements.txt (fine for libraries)" ;;
    Pipfile) anyof "$d" Pipfile.lock || echo "$m: no Pipfile.lock" ;;
    Cargo.toml) anyof "$d" Cargo.lock || echo "$m: no Cargo.lock (fine for libraries)" ;;
    go.mod) anyof "$d" go.sum || echo "$m: no go.sum" ;;
    Gemfile) anyof "$d" Gemfile.lock || echo "$m: no Gemfile.lock" ;;
    composer.json) anyof "$d" composer.lock || echo "$m: no composer.lock" ;;
    vcpkg.json) grep -q builtin-baseline "$m" || echo "$m: no builtin-baseline (versions not pinned)" ;;
    *.csproj) anyof "$d" packages.lock.json || echo "$m: no packages.lock.json (optional, info)" ;;
  esac
done

# --- DP3 unpinned versions ---
echo "## DP3 unpinned versions (file:line:entry)"
for m in "${M[@]}"; do
  case "$(basename "$m")" in
    requirements*.txt) grep -nvE '^\s*(#|$|-)|==|===|@' "$m" | sed "s#^#$m:#" ;;
    package.json) grep -nE '"[^"]+"\s*:\s*"(\*|latest|x|)"' "$m" | sed "s#^#$m:#" ;;
    pom.xml) grep -nE '<version>[^<]*(LATEST|RELEASE|SNAPSHOT|\[|\()[^<]*</version>' "$m" | sed "s#^#$m:#" ;;
    build.gradle | build.gradle.kts) grep -nE "[:'\"][0-9.]*\+['\"]|latest\.(release|integration)" "$m" | sed "s#^#$m:#" ;;
    *.csproj | Directory.Packages.props) grep -nE 'Version="[^"]*\*' "$m" | sed "s#^#$m:#" ;;
    Cargo.toml) grep -nE '=\s*"\*"' "$m" | sed "s#^#$m:#" ;;
  esac
done | cap 60

if [ -n "$OFFLINE" ]; then
  echo "NOTE OFFLINE=1 - vulnerability/outdated checks skipped"
  exit 0
fi

# --- Tools ---
if have osv-scanner; then
  echo "# osv-scanner (all ecosystems)"
  osv-scanner -r . 2>&1 | cap 120
else
  note_missing "osv-scanner (all ecosystems: https://google.github.io/osv-scanner/)"
fi

for m in "${M[@]}"; do
  d=$(dirname "$m"); b=$(basename "$m")
  case "$b" in
    requirements*.txt)
      if have pip-audit; then echo "# pip-audit $m"; pip-audit -r "$m" --progress-spinner off 2>&1 | cap
      else note_missing "pip-audit (Python: pip install pip-audit)"; fi ;;
    package.json)
      if [ -e "$d/package-lock.json" ] && have npm; then
        echo "# npm audit $d"; (cd "$d" && npm audit 2>&1 | cap)
        echo "# npm outdated $d"; (cd "$d" && npm outdated 2>&1 | cap 40)
      elif [ -e "$d/pnpm-lock.yaml" ] && have pnpm; then
        echo "# pnpm audit $d"; (cd "$d" && pnpm audit 2>&1 | cap)
      elif have npm; then echo "# npm: $d has no package-lock.json - npm audit needs one"
      else note_missing "npm (Node.js)"; fi ;;
    *.csproj)
      if have dotnet; then
        echo "# dotnet vulnerable $m"; dotnet list "$m" package --vulnerable --include-transitive 2>&1 | cap
        echo "# dotnet outdated $m"; dotnet list "$m" package --outdated 2>&1 | cap 40
      else note_missing "dotnet SDK (dotnet list package --vulnerable)"; fi ;;
    Cargo.toml)
      if have cargo-audit || cargo audit --version >/dev/null 2>&1; then
        echo "# cargo audit $d"; (cd "$d" && cargo audit 2>&1 | cap)
      else note_missing "cargo-audit (Rust: cargo install cargo-audit)"; fi ;;
    go.mod)
      if have govulncheck; then echo "# govulncheck $d"; (cd "$d" && govulncheck ./... 2>&1 | cap)
      else note_missing "govulncheck (Go: go install golang.org/x/vuln/cmd/govulncheck@latest)"; fi ;;
    Gemfile)
      if have bundle-audit; then echo "# bundle-audit $d"; (cd "$d" && bundle-audit check --update 2>&1 | cap)
      else note_missing "bundler-audit (Ruby)"; fi ;;
    composer.json)
      if have composer; then echo "# composer audit $d"; (cd "$d" && composer audit 2>&1 | cap)
      else note_missing "composer (PHP)"; fi ;;
    pom.xml | build.gradle | build.gradle.kts)
      if have dependency-check; then echo "# OWASP dependency-check $d"; dependency-check --scan "$d" --format JSON --out /dev/null 2>&1 | cap 40
      else note_missing "OWASP dependency-check or osv-scanner (Maven/Gradle)"; fi ;;
    vcpkg.json | conanfile.txt | conanfile.py)
      have osv-scanner || note_missing "osv-scanner (C/C++ vcpkg/conan)" ;;
  esac
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "## tools missing (would improve coverage)"
  printf -- '- %s\n' "${missing[@]}"
fi
