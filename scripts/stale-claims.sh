#!/usr/bin/env bash
# Report live claims that have gone stale.
#
# The 72-hour lease was documented from the start and computed by nothing. A
# rule nobody evaluates is a rule that quietly stops existing, and the specific
# failure it prevents — an agent holding a lease on a hot surface after it has
# stopped working — is invisible precisely because the agent is not around to
# report it.
#
# The heartbeat is the claim file's last commit date, not its self-reported
# `Last Updated` field. Derived beats declared: a hand-maintained timestamp is
# one more thing every agent must remember every session, it drifts silently the
# moment someone forgets, and git already knows the answer exactly.
#
# Report-only, always exits 0. PENUMBRA made stale claims deliberately
# non-blocking so one abandoned lease could not fail the whole fleet's CI, which
# is right — but non-blocking currently means nobody looks. This is the looking.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

HOURS="${1:-72}"
now="$(date -u +%s)"
found=0

field() {
  sed -n '1,/^## /p' "$1" | sed -n "s/^- $2:[[:space:]]*//p" | head -1
}

for f in docs/claims/*.md; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in README.md) continue ;; esac

  status="$(field "$f" 'Status')"
  case "$status" in
    Active | 'PR Open' | Paused) ;;
    *) continue ;;
  esac

  # Last commit that touched this file. Falls back to the working-tree mtime for
  # a claim that has not been committed yet, which is a claim mid-registration.
  ts="$(git log -1 --format=%ct -- "$f" 2>/dev/null || true)"
  if [ -z "$ts" ]; then
    ts="$(git log -1 --format=%ct 2>/dev/null || echo "$now")"
  fi

  age_hours=$(((now - ts) / 3600))
  [ "$age_hours" -lt "$HOURS" ] && continue

  pr="$(field "$f" 'Pull Request')"
  tool="$(field "$f" 'Tool')"
  task="$(field "$f" 'Task ID')"

  if [ "$found" = "0" ]; then
    echo "Stale claims (no commit in ${HOURS}h):"
    echo
    found=1
  fi

  printf '  %-28s %-8s %-10s %sh  PR: %s\n' "$task" "$tool" "$status" "$age_hours" "$pr"

  # An Active claim with no pull request is the reclaimable case: nothing has
  # been produced and nothing is in review. A PR Open claim that has gone quiet
  # is a different problem — there is work to salvage, so it needs a handoff
  # rather than a reclaim.
  if [ "$status" = "Active" ] && { [ "$pr" = "none" ] || [ -z "$pr" ]; }; then
    echo "      reclaimable — open a new claim and preserve context in ## Handoff"
  else
    echo "      not reclaimable — has work in review; ask for a handoff"
  fi
done

if [ "$found" = "0" ]; then
  echo "No stale claims (threshold ${HOURS}h)."
fi

exit 0
