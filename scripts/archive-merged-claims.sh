#!/usr/bin/env bash
# Move closed claims (Merged, Abandoned) into docs/claims/archive/.
#
# The guard and the live index read only top-level docs/claims/*.md, so closed
# claims left in place are pure noise at session start.
#
# Dry run by default. Pass --apply to move files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAIMS="$ROOT/docs/claims"
ARCHIVE="$CLAIMS/archive"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

mkdir -p "$ARCHIVE"
moved=0
for f in "$CLAIMS"/*.md; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in README.md) continue ;; esac
  status="$(sed -n '1,/^## /p' "$f" | sed -n 's/^- Status:[[:space:]]*//p' | head -1)"
  case "$status" in
    Merged | Abandoned) ;;
    *) continue ;;
  esac
  if [ "$APPLY" = "1" ]; then
    git -C "$ROOT" mv "$f" "$ARCHIVE/" 2>/dev/null || mv "$f" "$ARCHIVE/"
    echo "archived $(basename "$f") ($status)"
  else
    echo "would archive $(basename "$f") ($status)"
  fi
  moved=$((moved + 1))
done

if [ "$moved" = "0" ]; then
  echo "No closed claims to archive."
elif [ "$APPLY" = "1" ]; then
  "$ROOT/scripts/generate-live-claims-index.sh"
else
  echo "Dry run. Re-run with --apply to move $moved file(s)."
fi
