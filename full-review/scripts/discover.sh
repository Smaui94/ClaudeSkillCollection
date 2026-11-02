#!/usr/bin/env bash
#
# Lists the skills of this collection and facts about a project for the
# full-review skill.
# Usage: discover.sh [project_root]
# Output: "## skills" (name | scripts | description) and "## project" facts.
#
# No "set -e": grep finding nothing is an expected, non-fatal result here.
set -u

readonly PROJECT="${1:-.}"
SKILLS_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
readonly SKILLS_DIR
SELF="$(basename "$(cd "$(dirname "$0")/.." && pwd)")"
readonly SELF

#######################################
# Prints every sibling skill with its description.
# Globals:
#   SKILLS_DIR, SELF
# Outputs:
#   "name | scripts|- | description" lines.
#######################################
list_skills() {
  local f name desc scripts
  echo "## skills (${SKILLS_DIR})"
  for f in "${SKILLS_DIR}"/*/SKILL.md; do
    [[ -f "${f}" ]] || continue
    name="$(sed -n 's/^name:[[:space:]]*//p' "${f}" | head -n 1 | tr -d '\r')"
    [[ "${name}" == "${SELF}" ]] && continue
    desc="$(sed -n 's/^description:[[:space:]]*//p' "${f}" | head -n 1 \
      | tr -d '\r' | cut -c1-200)"
    scripts="-"
    [[ -d "$(dirname "${f}")/scripts" ]] && scripts="scripts"
    printf '%s | %s | %s\n' "${name}" "${scripts}" "${desc}"
  done
}

#######################################
# Lists project files (tracked + untracked but not ignored, or find).
# Outputs:
#   One relative path per line.
#######################################
list_files() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files --cached --others --exclude-standard
  else
    find . \( -name .git -o -name node_modules -o -name vendor -o -name .venv \
      -o -name venv -o -name build -o -name dist -o -name target -o -name bin \
      -o -name obj -o -name __pycache__ -o -name .godot \) -prune \
      -o -type f -print | sed 's#^\./##'
  fi
}

#######################################
# Counts files whose content matches a pattern.
# Arguments:
#   File list (newline-separated), extended regex.
# Outputs:
#   Count.
#######################################
count_matching() {
  printf '%s\n' "$1" | grep -v '^$' | tr '\n' '\0' \
    | xargs -0r grep -lIE -- "$2" 2>/dev/null | wc -l | tr -d ' '
}

#######################################
# Prints "label: count" if a path pattern matches any file.
# Arguments:
#   Label, file list, extended regex on paths.
#######################################
count_paths() {
  local n
  n="$(printf '%s\n' "$2" | grep -cE -- "$3")"
  [[ "${n}" -gt 0 ]] && echo "$1: ${n}"
}

#######################################
# Prints facts about the project.
# Globals:
#   PROJECT
#######################################
project_facts() {
  local all code manifests deps
  cd "${PROJECT}" || exit 1
  echo "## project ($(pwd))"
  all="$(list_files | grep -vE '(^|/)(node_modules|vendor|\.venv|venv)/')"
  echo "files: $(printf '%s\n' "${all}" | grep -c .)"
  echo "### extensions (top 20)"
  printf '%s\n' "${all}" | sed -n 's/.*\.\([A-Za-z0-9]*\)$/\1/p' \
    | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -rn | head -n 20
  echo "### manifests and frameworks"
  manifests="$(printf '%s\n' "${all}" | grep -E '(^|/)(package\.json|requirements[^/]*\.txt|pyproject\.toml|pom\.xml|build\.gradle(\.kts)?|[^/]*\.csproj|[^/]*\.sln|CMakeLists\.txt|vcpkg\.json|Cargo\.toml|go\.mod|composer\.json|Gemfile|project\.godot|ProjectSettings/ProjectVersion\.txt|Dockerfile|docker-compose[^/]*\.ya?ml)$')"
  printf '%s\n' "${manifests:-none}" | head -n 25
  deps="$(printf '%s\n' "${manifests}" | grep -E '(package\.json|requirements|pyproject|pom\.xml|gradle|csproj)' \
    | tr '\n' '\0' | xargs -0r cat 2>/dev/null)"
  printf '%s\n' "${deps}" | grep -oiE '"(react|vue|svelte|@angular/core|next|nuxt|express|fastify|nestjs|electron)"|\b(django|flask|fastapi|sqlalchemy|celery|pandas|spring-boot|hibernate|Microsoft\.AspNetCore|EntityFrameworkCore|Dapper|Avalonia|WPF|MAUI)\b' \
    | tr -d '"' | sort -u | tr '\n' ' '
  echo
  echo "### features"
  count_paths "UI files (html/jsx/tsx/vue/svelte/xaml/tscn)" "${all}" \
    '\.(html?|jsx|tsx|vue|svelte|xaml|cshtml|razor|tscn)$'
  count_paths "SQL files" "${all}" '\.sql$'
  count_paths "migration files" "${all}" \
    '(^|/)(migrations?|db/migrate|Migrations|alembic/versions)/'
  count_paths "config files" "${all}" \
    '\.(ya?ml|json|toml|ini|cfg|conf|properties)$|(^|/)\.env'
  count_paths "shell scripts" "${all}" '\.(sh|bash)$'
  count_paths "test files" "${all}" \
    '(^|/)(tests?|__tests__|spec)/|_test\.(go|py)$|(^|/)test_[^/]*\.py$|Tests?\.(java|kt|cs)$|\.(test|spec)\.[jt]sx?$'
  count_paths "API specs (OpenAPI/GraphQL/proto)" "${all}" \
    '(openapi|swagger)[^/]*\.(ya?ml|json)$|\.(graphql|gql|proto)$'
  count_paths "CI configs" "${all}" \
    '^\.github/workflows/|^\.gitlab-ci\.yml$|^azure-pipelines|^Jenkinsfile$'
  code="$(printf '%s\n' "${all}" \
    | grep -E '\.(py|js|jsx|ts|tsx|java|kt|cs|c|cc|cpp|h|hpp|go|rs|php|rb|gd)$')"
  echo "code files: $(printf '%s\n' "${code}" | grep -c .)"
  echo "files with concurrency hints: $(count_matching "${code}" \
    '\b(Thread|async |await |Task\.Run|ExecutorService|threading|asyncio|Mutex|goroutine|go func|WorkerThreadPool|synchronized|Parallel\.)')"
  echo "files with HTTP routes: $(count_matching "${code}" \
    '@(Get|Post|Put|Delete|Request)Mapping|\[Http(Get|Post|Put|Delete)|app\.(get|post|put|delete)\(|router\.(get|post)|@app\.(route|get|post)|MapGet\(|HandleFunc\(')"
  echo "files with SQL/database access: $(count_matching "${code}" \
    '\b(SELECT|INSERT INTO|UPDATE [a-z_]+ SET|DELETE FROM)\b|execute\(|executeQuery|DbContext|createQuery|\$queryRaw|knex|sqlalchemy|sqlite3|psycopg|database/sql')"
  echo "files with regex: $(count_matching "${code}" \
    'new RegExp|re\.(compile|match|search|sub)|Pattern\.compile|new Regex|regexp\.MustCompile|Regex::new|RegEx\.new')"
  echo "files with analytics/tracking hints: $(count_matching \
    "$(printf '%s\n' "${all}" | grep -vE '\.(md|txt|rst|adoc)$')" \
    'gtag\(|googletagmanager|analytics|mixpanel|segment\.(io|com)|posthog|matomo|hotjar|fbq\(|sentry')"
  echo "### git"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    echo "commits: $(git rev-list --count HEAD 2>/dev/null || echo 0)"
    echo "last tag: $(git describe --tags --abbrev=0 2>/dev/null || echo none)"
    echo "uncommitted changes: $(git status --porcelain | wc -l | tr -d ' ')"
  else
    echo "not a git repository"
  fi
}

#######################################
# Prints skills and project facts.
# Arguments:
#   None (uses PROJECT).
#######################################
main() {
  list_skills
  project_facts
}

main "$@"
