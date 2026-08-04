#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "=== Live claims ==="
sed -n '/^| Status/,/^$/p' "$ROOT/docs/LIVE_CLAIMS.md" 2>/dev/null || true
echo
echo "=== Assignment card ==="
sed -n '/^| Slot/,/^$/p' "$ROOT/docs/ASSIGNMENT.md" 2>/dev/null || true
echo
echo "=== Open pull requests ==="
if command -v gh >/dev/null 2>&1; then
  gh pr list --state open --limit 20 2>/dev/null || echo "(gh could not list)"
else
  echo "(gh not installed)"
fi
