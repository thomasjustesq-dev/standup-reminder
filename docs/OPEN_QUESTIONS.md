# Open questions

Append-only. `merge=union`.

---

## 2026-08-04

1. **[DEFERRED]** Is repository secret `REPO_PAT` configured for claim auto-merge?
   — Multi-agent claim package is **dormant** at fleet of one; not needed until concurrent agents return.
2. **[CLOSED]** What is the next product Task ID for ASSIGNMENT?
   — Solo author mode; ASSIGNMENT left empty by design. Product work uses normal branches/PRs.

## 2026-08-06

1. **[OPEN]** Are App Group `group.com.thomasjust.standupreminder` and iCloud container
   `iCloud.com.thomasjust.standupreminder` provisioned on the Apple Developer team?
   — Blocks notarized release and real multi-device sync. Thomas must check portal.
2. **[OPEN]** After first run of 4.2.x, confirm one iCloud push re-seeds multi-device sync.
   — Seed banner + `cloudContainerEmpty` in SyncHealth now surface this; still needs a live confirm.

## 2026-08-10

1. **[OPEN]** Apple notarization secrets (local env and/or GitHub Actions) for first `v4.2.2` release.
2. **[OPEN]** Cask `sha256` after first notarized zip lands.
