#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0
need() { [ -f "$1" ] || { echo "MISSING $1"; fail=1; }; }
for f in \
  docs/WORKBOARD.md docs/ASSIGNMENT.md docs/LIVE_CLAIMS.md docs/PROCESS_LESSONS.md \
  docs/DECISIONS.md docs/SESSION_LOG.md docs/OPEN_QUESTIONS.md docs/KNOWN_LIMITS.md \
  docs/ROADMAP.md docs/claims/README.md CLAUDE.md AGENTS.md
do need "$f"; done
if [ -f .gitattributes ]; then
  for f in docs/DECISIONS.md docs/SESSION_LOG.md docs/OPEN_QUESTIONS.md; do
    grep -qE "^${f}[[:space:]]+merge=union" .gitattributes || { echo "gitattributes missing merge=union for $f"; fail=1; }
  done
else
  echo "MISSING .gitattributes"; fail=1
fi
grep -qE '^\|[[:space:]]*Slot[[:space:]]*\|' docs/ASSIGNMENT.md || { echo "ASSIGNMENT.md has no Slot table"; fail=1; }
shopt -s nullglob
for f in docs/claims/*.md; do
  case "$(basename "$f")" in README.md) continue ;; esac
  for field in "Task Type" "Task ID" "Branch" "Base Branch" "Tool" "Status" "Pull Request"; do
    sed -n '1,/^## /p' "$f" | grep -q "^- $field:" || { echo "$(basename "$f") missing $field"; fail=1; }
  done
  for sec in "## Scope" "## Write surface" "## Hot spots" "## Handoff"; do
    grep -q "^$sec" "$f" || { echo "$(basename "$f") missing $sec"; fail=1; }
  done
done
[ "$fail" -eq 0 ] && echo "coordination-guard: OK" || { echo "coordination-guard: FAILED"; exit 1; }
