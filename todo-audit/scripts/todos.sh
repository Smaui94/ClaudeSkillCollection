#!/usr/bin/env bash
# Collects TODO/FIXME/HACK/XXX/BUG comments with age and author from git blame.
# Usage: todos.sh [root] [max_hits]   Env: NO_BLAME=1 skips git blame (faster).
# Output: "path:line<TAB>TAG<TAB>age_days<TAB>author<TAB>text", then totals per tag.
ROOT="${1:-.}"
MAX="${2:-300}"
export LC_ALL=C
cd "$ROOT" || exit 1

TAGS='\b(TODO|FIXME|HACK|XXX|BUG)\b'
# Tag must follow a comment marker on the same line.
MARKER='(//|#|/\*|^\s*\*|--|<!--|^\s*;|\bREM\b)'
PATTERN="${MARKER}.*?${TAGS}"
# First tag after a comment marker (one per line).
FIRST_TAG="^.*?${MARKER}.*?\\K${TAGS}"

hits=$(grep -rInP \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=vendor \
  --exclude-dir=build --exclude-dir=dist --exclude-dir=out --exclude-dir=target \
  --exclude-dir=bin --exclude-dir=obj --exclude-dir=.venv --exclude-dir=venv \
  --exclude-dir=__pycache__ --exclude='*.min.js' --exclude='*.min.css' \
  --exclude='*.lock' --exclude='package-lock.json' \
  -- "$PATTERN" . 2>/dev/null | sed 's#^\./##')

[ -z "$hits" ] && { echo "no TODO/FIXME/HACK/XXX/BUG comments found"; exit 0; }

blame=0
if [ -z "$NO_BLAME" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  blame=1
fi
now=$(date +%s)

printf '%s\n' "$hits" | head -n "$MAX" | while IFS= read -r h; do
  file="${h%%:*}"
  rest="${h#*:}"
  line="${rest%%:*}"
  text="${rest#*:}"
  tag=$(printf '%s\n' "$text" | grep -oP "$FIRST_TAG" | head -n 1)
  age="?"
  author="?"
  if [ "$blame" = 1 ]; then
    b=$(git blame --porcelain -L "${line},${line}" -- "$file" 2>/dev/null)
    t=$(printf '%s\n' "$b" | sed -n 's/^author-time //p' | head -n 1)
    a=$(printf '%s\n' "$b" | sed -n 's/^author //p' | head -n 1)
    [ -n "$t" ] && age=$(( (now - t) / 86400 ))
    [ -n "$a" ] && author="$a"
  fi
  text=$(printf '%s\n' "$text" | sed -E 's/^[[:space:]]+//' | cut -c1-140)
  printf '%s:%s\t%s\t%s\t%s\t%s\n' "$file" "$line" "$tag" "$age" "$author" "$text"
done

total=$(printf '%s\n' "$hits" | wc -l)
echo "## total ${total} (shown: max ${MAX}; blame: $([ "$blame" = 1 ] && echo on || echo off))"
printf '%s\n' "$hits" | cut -d: -f3- | grep -oP "$FIRST_TAG" | sort | uniq -c | sort -rn
