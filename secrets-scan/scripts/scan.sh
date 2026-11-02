#!/usr/bin/env bash
# Secret scan: gitleaks (redacted) if installed, plus grep patterns. Matches are always masked.
# Usage: scan.sh [root] [max_hits_per_rule]   Env: HISTORY=1 also scans the git history.
# Output: "## ID count SEV | description" + up to N "file:line: XXXX***" per rule, then TOTAL.
ROOT="${1:-.}"
MAX="${2:-20}"
TOTAL=0
export LC_ALL=C
cd "$ROOT" || exit 1

EXCL=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=vendor
  --exclude-dir=.venv --exclude-dir=venv --exclude-dir=build --exclude-dir=dist
  --exclude-dir=out --exclude-dir=target --exclude-dir=__pycache__
  --exclude='*.min.js' --exclude='*.lock' --exclude='package-lock.json'
  --exclude='pnpm-lock.yaml' --exclude='yarn.lock')

# Matches that look like placeholders or env references are skipped (checked on the match only).
PLACEHOLDER='^[^:]*:\d+:.*(?i:example|sample|dummy|placeholder|changeme|change_me|your[_-]?(api[_-]?)?(key|token|secret|password)|xxxx|\*\*\*|<[^>]*>|\$\{|\{\{|%\(|process\.env|os\.environ|getenv|scheme://|user:pass(word)?@)'

mask() { sed -E 's/^([^:]*:[0-9]+:)(.{0,4}).*/\1 \2***/'; }

# report ID SEV "description" "hits"
report() {
  local n
  [ -z "$4" ] && return
  n=$(printf '%s\n' "$4" | wc -l)
  TOTAL=$((TOTAL + n))
  echo "## $1 $n $2 | $3"
  printf '%s\n' "$4" | head -n "$MAX"
}

# rule ID SEV "description" "pcre" [extra grep options...]
rule() {
  local id="$1" sev="$2" desc="$3" re="$4" all real skipped
  shift 4
  all=$(grep -rInoP "${EXCL[@]}" "$@" -- "$re" . 2>/dev/null | sed 's#^\./##')
  [ -z "$all" ] && return
  real=$(printf '%s\n' "$all" | grep -vP "$PLACEHOLDER")
  skipped=$(( $(printf '%s\n' "$all" | wc -l) - $(printf '%s' "$real" | grep -c '^') ))
  report "$id" "$sev" "$desc" "$(printf '%s\n' "$real" | grep -v '^$' | mask)"
  [ "$skipped" -gt 0 ] && echo "   ($skipped placeholder-looking matches skipped for $id)"
}

in_git=0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && in_git=1

# --- gitleaks ---
if command -v gitleaks >/dev/null 2>&1; then
  echo "# gitleaks (redacted)"
  if gitleaks --help 2>&1 | grep -qE '^[[:space:]]+dir[[:space:]]'; then
    gitleaks dir . --redact --no-banner -v 2>&1 | head -n 200
    [ -n "$HISTORY" ] && [ "$in_git" = 1 ] && gitleaks git . --redact --no-banner -v 2>&1 | head -n 200
  else
    gitleaks detect --source . --no-git --redact --no-banner -v 2>&1 | head -n 200
    [ -n "$HISTORY" ] && [ "$in_git" = 1 ] && gitleaks detect --source . --redact --no-banner -v 2>&1 | head -n 200
  fi
else
  echo "NOTE gitleaks not found - https://github.com/gitleaks/gitleaks finds more secret types; patterns only"
fi

# --- Patterns ---
echo "# patterns (masked)"
rule SC1 error "provider token format" '\b(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,}|glpat-[A-Za-z0-9_-]{20,}|xox[abposr]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|[sr]k_live_[0-9A-Za-z]{20,}|sk-ant-[A-Za-z0-9_-]{20,}|sk-(proj-)?[A-Za-z0-9_-]{40,}|SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}|npm_[A-Za-z0-9]{36})\b|https://hooks\.slack\.com/services/[A-Za-z0-9/]+'
rule SC2 error "private key" '-----BEGIN ((RSA|EC|DSA|OPENSSH|PGP|ENCRYPTED) )?PRIVATE KEY( BLOCK)?-----'
rule SC3 error "credentials in connection string / URL" '\b[a-z][a-z0-9+.-]*://[^\s:/@"\x27]+:[^\s@/"\x27]{3,}@[^\s"\x27]+'
rule SC4 warning "literal password/secret/token assignment (possible)" '(?i)\b[\w.-]*(password|passwd|pwd|secret|api[_-]?key|apikey|access[_-]?key|auth[_-]?token|client[_-]?secret|private[_-]?key|token)\b["\x27]?\s*[:=]+\s*["\x27][^"\x27\s]{6,}["\x27]'
rule SC4c warning "unquoted secret in config file (possible)" '(?i)^\s*[\w.-]*(password|passwd|secret|api[_-]?key|token)[\w.-]*\s*[=:]\s*[^\s"\x27$#{<][^\s]{5,}\s*$' \
  --include='.env' --include='.env.*' --include='*.env' --include='*.properties' \
  --include='*.ini' --include='*.cfg' --include='*.conf' --include='*.yml' \
  --include='*.yaml' --include='*.toml'

# --- Files tracked by git ---
if [ "$in_git" = 1 ]; then
  report SC5 error "sensitive file tracked by git" "$(git ls-files \
    | grep -iE '(^|/)(\.env(\.[^/]*)?|[^/]*\.(pem|key|p12|pfx|jks|keystore|ppk)|id_(rsa|dsa|ecdsa|ed25519)|\.npmrc|\.pypirc|credentials(\.json)?|secrets?\.(json|ya?ml|toml))$' \
    | grep -viE '\.(example|sample|template|dist)$' | sed 's/$/:1: tracked/')"
  missing=""
  for p in .env .env.local secrets.pem server.key id_rsa; do
    git check-ignore -q --no-index "$p" 2>/dev/null || missing="${missing}.gitignore:1: does not ignore ${p}"$'\n'
  done
  report SC6 warning ".gitignore gaps" "$(printf '%s' "$missing" | grep -v '^$')"
else
  echo "NOTE not a git repository - SC5/SC6/SC7 skipped"
fi

# --- Git history ---
if [ -n "$HISTORY" ] && [ "$in_git" = 1 ]; then
  report SC7 error "secret in git history (commit:file)" "$(git log --all -p --no-color --format='@@commit %h' 2>/dev/null | awk -v max="$MAX" '
    /^@@commit / { c = $2; next }
    /^\+\+\+ b\// { f = substr($0, 7); next }
    /^\+/ && match($0, /(AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36}|glpat-[A-Za-z0-9_-]{20}|xox[abposr]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|[sr]k_live_[0-9A-Za-z]{20,}|sk-ant-[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY)/) {
      k = c ":" f ": " substr($0, RSTART, 4) "***"
      if (!(k in seen)) { seen[k] = 1; print k; if (++n >= max) exit }
    }')"
elif [ "$in_git" = 1 ]; then
  echo "NOTE git history not scanned - run with HISTORY=1 to include it (SC7)"
fi

echo "TOTAL $TOTAL (pattern findings; gitleaks findings listed separately)"
