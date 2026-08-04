#!/usr/bin/env bash
# Check that a branch's actual diff stays inside the write surface its claim
# declared.
#
# This is the missing half of the lease. Every claim declares the paths it will
# write, and the coordination guard checks those declarations against each
# other — but until this script existed, nothing ever compared a declaration to
# what the branch actually changed. The mechanism other agents route around was
# enforced at the moment of declaring and unenforced at the moment of writing,
# which is the only moment that matters.
#
# Usage:
#   scripts/check-write-surface.sh [BASE_REF] [BRANCH]
#
# Defaults to origin/main and the current branch. Exits non-zero on a violation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

BASE="${1:-origin/main}"
BRANCH="${2:-$(git rev-parse --abbrev-ref HEAD)}"

# Only agent branches carry claims. Human and automation branches are out of
# scope: the bot's reconcile branch has no claim by design, and requiring one
# would deadlock the thing that closes claims.
case "$BRANCH" in
  agent/*) ;;
  *)
    echo "Branch '$BRANCH' is not an agent branch; write-surface check does not apply."
    exit 0
    ;;
esac

changed="$(git diff --name-only "$BASE"...HEAD | sort -u)"
if [ -z "$changed" ]; then
  echo "No changed files."
  exit 0
fi

# Bookkeeping is always permitted regardless of the declared surface. An agent
# must be able to update its own claim, the generated index, and the assignment
# card without listing them as product write intent every time.
always_allowed() {
  case "$1" in
    docs/claims/* | docs/LIVE_CLAIMS.md | docs/ASSIGNMENT.md) return 0 ;;
    *) return 1 ;;
  esac
}

# Find the claim whose Branch field names this branch. Claims live on main, so
# look in the working tree — the claim landed before the work by definition.
claim=""
for f in docs/claims/*.md; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in README.md) continue ;; esac
  declared="$(sed -n '1,/^## /p' "$f" | sed -n 's/^- Branch:[[:space:]]*//p' | head -1)"
  if [ "$declared" = "$BRANCH" ]; then
    claim="$f"
    break
  fi
done

if [ -z "$claim" ]; then
  # Bookkeeping-only branches carry no claim, by design. A reconcile or archive
  # branch closes somebody else's claim; the claim it is retiring names the work
  # branch, not this one, and requiring a claim to close a claim is circular.
  #
  # This exemption is the same set of paths always permitted inside a declared
  # surface below. Nothing product can reach it: one file outside the registry
  # and the branch needs a claim like any other.
  bookkeeping_only=true
  while IFS= read -r file || [ -n "$file" ]; do
    [ -z "$file" ] && continue
    always_allowed "$file" || bookkeeping_only=false
  done <<< "$changed"

  if [ "$bookkeeping_only" = "true" ]; then
    echo "Bookkeeping-only branch with no claim — registry paths only. Nothing to check."
    exit 0
  fi

  echo "::error::No claim on main declares branch '$BRANCH'."
  echo "Claim-first: land a one-file claim PR before implementing. See docs/WORKBOARD.md."
  exit 1
fi

echo "Claim: $claim"

# Read the declared surface: bullets under '## Write surface', backticks stripped.
surfaces="$(awk '
  /^## Write surface/ { inside = 1; next }
  /^## / { inside = 0 }
  inside && /^-[[:space:]]/ {
    sub(/^-[[:space:]]*/, "")
    gsub(/`/, "")
    sub(/[[:space:]]+$/, "")
    sub(/\/+$/, "")
    if (length($0)) print
  }
' "$claim")"

if [ -z "$surfaces" ]; then
  echo "::error::$claim declares no write surface."
  exit 1
fi

# A read-only claim writes nothing but its own bookkeeping.
readonly_claim=false
if [ "$(printf '%s\n' "$surfaces" | tr -d '[:space:]')" = "none" ]; then
  readonly_claim=true
fi


covered() {
  local file="$1" surface
  # `|| [ -n "$surface" ]`: a final line without a trailing newline would
  # otherwise be dropped, silently narrowing the declared surface.
  while IFS= read -r surface || [ -n "$surface" ]; do
    [ -z "$surface" ] && continue
    [ "$surface" = "none" ] && continue
    # A directory covers everything beneath it.
    if [ "$file" = "$surface" ] || [ "${file#"$surface"/}" != "$file" ]; then
      return 0
    fi
  done <<< "$surfaces"
  return 1
}

violations=0
while IFS= read -r file || [ -n "$file" ]; do
  [ -z "$file" ] && continue
  if always_allowed "$file"; then
    continue
  fi
  if [ "$readonly_claim" = "true" ]; then
    echo "::error::$file was written by a read-only claim ($claim declares 'none')."
    violations=$((violations + 1))
    continue
  fi
  if ! covered "$file"; then
    echo "::error::$file is outside the write surface declared in $claim."
    violations=$((violations + 1))
  fi
done <<< "$changed"

if [ "$violations" -gt 0 ]; then
  echo
  echo "Declared surface:"
  while IFS= read -r s || [ -n "$s" ]; do [ -n "$s" ] && echo "  $s"; done <<< "$surfaces"
  echo
  echo "Either narrow the change or amend the claim's ## Write surface — but amend it"
  echo "knowing the surface is what other agents route around. Widening it silently is"
  echo "how two agents end up writing the same file with two valid claims."
  exit 1
fi

echo "All $(printf '%s\n' "$changed" | wc -l | tr -d ' ') changed file(s) are within the declared surface."
