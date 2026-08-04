#!/usr/bin/env bash
# Claim-first registration in one step: write the claim file, fill the
# assignment card row, regenerate the live index, and open a claims-only PR
# that auto-merges.
#
# A claim on your own branch is invisible to every other agent. docs/claims/ on
# main is the registry they read. On PENUMBRA, learning this the other way
# produced four duplicate-work collisions in a single day, with every agent
# following the protocol correctly.
#
# Usage:
#   scripts/claim-open.sh --tool Grok --task 2 --slug day-tick \
#       --type Gate --surface src/sim/tick.ts --surface tests/tick.test.ts
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

TOOL="" TASK="" SLUG="" TYPE="Maintenance" SCOPE=""
SURFACES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --tool) TOOL="$2"; shift 2 ;;
    --task) TASK="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    --surface) SURFACES+=("$2"); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$TOOL" ] && [ -n "$TASK" ] && [ -n "$SLUG" ] || {
  echo "usage: $0 --tool TOOL --task TASK_ID --slug SLUG [--type Round|Sub-round|Maintenance] [--scope TEXT] [--surface PATH ...]" >&2
  exit 2
}
[ "${#SURFACES[@]}" -gt 0 ] || {
  echo "error: declare at least one --surface (use 'none' for read-only work)." >&2
  echo "A claim reserves a task; collisions happen on files. See docs/WORKBOARD.md." >&2
  exit 2
}

TOOL_LC="$(printf '%s' "$TOOL" | tr '[:upper:]' '[:lower:]')"
TODAY="$(date -u +%Y-%m-%d)"
case "$TYPE" in
  Round | Sub-round) BRANCH="agent/$TOOL_LC/round-$TASK-$SLUG" ;;
  *) BRANCH="agent/$TOOL_LC/task-$SLUG" ;;
esac
FILE="docs/claims/$TODAY-$(printf '%s' "$TASK" | tr '/' '-')-$SLUG.md"

default="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo main)"
cur="$(git rev-parse --abbrev-ref HEAD)"
[ "$cur" = "$default" ] || [ "$cur" = "main" ] || [ "$cur" = "master" ] || {
  echo "error: run from default branch ($default). Claim-first lands claim first." >&2
  exit 1
}

git checkout -b "$BRANCH"

{
  echo "# Claim — $SLUG"
  echo
  echo "- Task Type: $TYPE"
  echo "- Task ID: $TASK"
  echo "- Branch: $BRANCH"
  echo "- Base Branch: main"
  echo "- Tool: $TOOL"
  echo "- Assigned By: Thomas"
  echo "- Date Claimed: $TODAY"
  echo "- Last Updated: $TODAY"
  echo "- Status: Active"
  echo "- Blocked By: none"
  echo "- Pull Request: none"
  echo
  echo "## Scope"
  echo
  echo "- ${SCOPE:-TODO: what this claim will do}"
  echo "- TODO: what this claim will not do"
  echo
  echo "## Write surface"
  echo
  for s in "${SURFACES[@]}"; do
    if [ "$s" = "none" ]; then echo "- none"; else echo "- \`$s\`"; fi
  done
  echo
  echo "## Hot spots"
  echo
  echo "- TODO: shared surfaces expected to change"
  echo
  echo "## Handoff"
  echo
  echo "- Touched files: none yet"
  echo "- Tests run: none yet"
  echo "- Remaining acceptance criteria: all"
  echo "- Open questions: none"
} > "$FILE"

# Fill the assignment card row for this tool. CI fails an Active claim whose
# tool has no matching row, so this is not optional bookkeeping.
awk -v tool="$TOOL" -v task="$TASK" '
  BEGIN { IGNORECASE = 1 }
  /^\| (Continuous|On-demand) —/ {
    split($0, c, "|")
    slot = c[2]
    if (index(tolower(slot), tolower(tool)) > 0 && $0 ~ /\|[[:space:]]*\|[[:space:]]*\|/) {
      printf "|%s| %s | %s | yes |  |  |\n", slot, tool, task
      next
    }
  }
  { print }
' docs/ASSIGNMENT.md > docs/ASSIGNMENT.md.tmp && mv docs/ASSIGNMENT.md.tmp docs/ASSIGNMENT.md

./scripts/generate-live-claims-index.sh >/dev/null

./scripts/coordination-guard.sh || {
  echo >&2
  echo "error: the coordination guard rejects this claim. Fix it before opening the PR." >&2
  exit 1
}

git add "$FILE" docs/ASSIGNMENT.md docs/LIVE_CLAIMS.md
git commit -q -m "chore(claim): $TYPE $TASK — $SLUG"
git push -q -u origin "$BRANCH"

gh pr create --base main --head "$BRANCH" \
  --title "chore(claim): $TYPE $TASK — $SLUG" \
  --body "Claim-only registration for \`$TASK\` (${TOOL}). One file plus the assignment row; no implementation.

Claim-first exists because a claim on a topic branch is invisible to every other agent. See \`docs/WORKBOARD.md\`."

PR="$(gh pr list --head "$BRANCH" --state open --json number -q '.[0].number')"
gh pr merge "$PR" --squash --delete-branch --auto ||
  echo "Auto-merge not enabled for #$PR (checks pending or branch protection absent)."

echo
echo "Claim #$PR registered. Implement on $BRANCH once it lands on main."
