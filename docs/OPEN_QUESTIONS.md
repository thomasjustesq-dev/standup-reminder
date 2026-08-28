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


## 2026-08-10 — product PRs landed

1. **[CLOSED]** Authority lease + daily UX (#10, #11) on main as 4.2.2.
2. **[OPEN]** Apple notarization secrets / portal (unchanged — blocks tag ship).
3. **[OPEN]** Cask sha256 after first notarized zip.
4. **[OPEN]** Live multi-device seed + 15m lease degrade confirm on Thomas hardware.

## 2026-08-10 — ship preflight (local)

1. **[CLOSED]** iCloud container `iCloud.com.thomasjust.standupreminder` on Mac App ID
   — present on Development provisioning profile (with legacy container retained).
2. **[OPEN]** App Group `group.com.thomasjust.standupreminder` registered on portal.
   — Binary is signed with it; profile listing still showed legacy group + `BBTNHBK7VX.*`.
   Confirm the group exists and is attached to Mac + iOS + widget App IDs.
3. **[OPEN]** Developer ID Application certificate.
   — CSR+private key exist at `~/.standup-release/`; no matching cert in keychain.
   Blocks notarize + GH `APPLE_CERTIFICATES_P12` / `APPLE_CERTIFICATES_PASSWORD`.
4. **[PARTIAL]** GH release secrets: ASC key trio + Sparkle Ed present; **p12 pair missing**.
5. **[CLOSED]** Local Development install of 4.2.2 (8) on this Mac; iCloud legacy migrate ran.

## 2026-08-27 — v4.2.4 release closure

1. **[CLOSED]** Developer ID certificate and Mac/widget provisioning — the CI release passed signed App Group/iCloud capability verification and Apple notarization.
2. **[CLOSED]** GitHub release secrets and Cask checksum — v4.2.4 was published with signed appcast, notarized zip/DMG, and verified Cask SHA-256.
3. **[OPEN]** Physical-iPhone provisioning and smoke test for the HealthKit authorization sheet, recent-workout read, and mindful-session write.
4. **[OPEN]** Live two-device confirmation of automatic iCloud reconciliation and 15-minute authority-lease fallback.
