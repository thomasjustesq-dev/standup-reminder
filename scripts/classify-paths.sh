#!/usr/bin/env bash
# Classify a set of changed files into a PR path class.
#
# Single source of truth for the fast-path rules. Both .github/workflows/check.yml
# (which decides how much CI to run) and .github/workflows/pr-path-label.yml
# (which decides the label and whether to auto-merge) call this script.
#
# They used to carry their own copies. On PENUMBRA those two copies had already
# drifted apart — the labeller had an extra `docs/*` case the CI classifier did
# not — and the failure is silent in both directions. A PR labelled claims-only
# that runs the full suite is merely slow. The reverse ships product code behind
# a two-minute registry check.
#
# Reads file paths on stdin, one per line. Writes two lines:
#
#   claims_only=true|false
#   docs_process=true|false
#
# The classes are exclusive: claims_only is a subset of docs_process, and a
# claims-only change reports docs_process=false so callers can branch on one
# value without ordering their conditions correctly.
set -euo pipefail

claims_only=true
docs_process=true
seen=false

# `|| [ -n "$f" ]` catches a final line with no trailing newline. Without it the
# last path is silently dropped, which would classify a diff ending in a product
# file as docs-process and run the wrong CI.
while IFS= read -r f || [ -n "$f" ]; do
  [ -z "$f" ] && continue
  seen=true

  # Registry surface: the claim files, the generated index, the assignment card.
  case "$f" in
    docs/claims/* | docs/LIVE_CLAIMS.md | docs/ASSIGNMENT.md) ;;
    *) claims_only=false ;;
  esac

  # Docs and process surface: no product code, no product tests, no build config.
  case "$f" in
    docs/* | .github/* | scripts/* | *.md | .gitattributes | .editorconfig) ;;
    *) docs_process=false ;;
  esac
done

# An empty diff is not a process change. Treating it as one would let a PR with
# no files skip the full suite, which is a strange state that should be loud.
if [ "$seen" = "false" ]; then
  claims_only=false
  docs_process=false
fi

if [ "$claims_only" = "true" ]; then
  docs_process=false
fi

echo "claims_only=$claims_only"
echo "docs_process=$docs_process"
