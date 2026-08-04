#!/usr/bin/env bash
# Flip claim statuses to match reality, and clear the assignment card when a
# claim closes. Run by .github/workflows/claim-reconcile.yml after every merge
# and daily.
#
# Agents must not spend product-PR commits flipping other agents' claims. The
# bot batches it into one auto-merging registry PR instead.
#
# Prints CHANGED=1 when it modified anything, so the workflow knows whether to
# open a PR at all.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
CLAIMS="docs/claims"
TODAY="${TODAY:-$(date -u +%Y-%m-%d)}"
changed=0

field() {
  sed -n '1,/^## /p' "$1" | sed -n "s/^- $2:[[:space:]]*//p" | head -1
}

set_field() {
  # set_field <file> <name> <value> — rewrite a metadata bullet in place.
  local file="$1" name="$2" value="$3"
  awk -v name="$name" -v value="$value" '
    !done && $0 ~ "^- " name ":" { print "- " name ": " value; done = 1; next }
    { print }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

for f in "$CLAIMS"/*.md; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in README.md) continue ;; esac

  status="$(field "$f" 'Status')"
  [ "$status" = "PR Open" ] || continue

  pr="$(field "$f" 'Pull Request' | tr -d '#')"
  case "$pr" in
    '' | none) continue ;;
    */*) pr="${pr##*/}" ;;
  esac
  [ -n "$pr" ] || continue

  state="$(gh pr view "$pr" --json state,mergedAt -q '.state' 2>/dev/null || echo UNKNOWN)"
  case "$state" in
    MERGED) new=Merged ;;
    CLOSED) new=Abandoned ;;
    *) continue ;;
  esac

  echo "claim $(basename "$f"): PR #$pr is $state -> $new"
  set_field "$f" 'Status' "$new"
  set_field "$f" 'Last Updated' "$TODAY"
  changed=1

  # Clear the assignment row for this tool and task, so an idle slot reads as
  # idle rather than as work that never got cleaned up.
  tool="$(field "$f" 'Tool')"
  task="$(field "$f" 'Task ID')"
  awk -v tool="$tool" -v task="$task" -v today="$TODAY" '
    BEGIN { FS = "|"; OFS = "|" }
    /^\| (Continuous|On-demand) —/ {
      owner = $3; id = $4
      gsub(/^[ \t]+|[ \t]+$/, "", owner)
      gsub(/^[ \t]+|[ \t]+$/, "", id)
      if (owner == tool && id == task) {
        printf "|%s|  |  |  |  | done %s: %s |\n", $2, today, task
        next
      }
    }
    { print }
  ' docs/ASSIGNMENT.md > docs/ASSIGNMENT.md.tmp && mv docs/ASSIGNMENT.md.tmp docs/ASSIGNMENT.md
done

[ "$changed" = "1" ] && echo "CHANGED=1" || echo "CHANGED=0"
exit 0
