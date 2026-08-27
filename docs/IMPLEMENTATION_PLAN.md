# Stand Up Reminder — Antigravity Landing Implementation Plan

Status: IMPLEMENTED — 2026-08-27. All seven fidelity gaps are addressed on
`kimi/aero-kinetic-fidelity`; hosted macOS/iOS/watchOS verification remains the
merge gate.
Source of truth: `docs/design/` + Obsidian `Stand Up Reminder Aero-Kinetic Design System.md` (winning: **Aero-Kinetic**).

## Landing state

Landed on `main` (ff-merged `e5856be` mega-feature, then `177b542`, `5e15a84`, `7b026a7`, `f205626`). All four spec'd surfaces + chime engine exist.

## Design intent

Obsidian `#0A0B0E` floor, Frosted Slate `#161922` @70%, Kinetic Volt `#D2FF3A`, Ion Blue `#0A84FF`, Kinetic Orange `#FF9F0A`; 0.5pt specular rims; shadow `.black .35 r24 y12`; SF Pro timers (−0.5pt) + SF Mono telemetry (+0.8pt); menu bar (Volt arc **around the stretching figure** + posture radar), Settings, Dynamic Island/Live Activity, Watch circular dial, AeroAcoustics 528/1056 Hz chimes.

## Addressed gaps

### Design fidelity
1. **Menu bar popover misses the signature "Volt arc around the stretching figure"** — hero is a text countdown gauge (`AeroCountdownGauge`); the figure+ring exists only in the 22pt status item, and it's `isTemplate=true` monochrome (no Volt glow).
2. **"Spatial" chimes are mono** — `AeroAcoustics.playPCM` uses `mChannelsPerFrame: 1`; no stereo/3D.
3. Token drift: specular rim `0.20` vs spec `0.14`; border `0.75` vs `0.5pt`; shadow `0.4/r16/y8` vs `0.35/r24/y12`; slate opacity `0.75` vs 70%; widget bg `#0D0F14` vs `#161922`.
4. Timer tracking missing (−0.5pt): only `.monospacedDigit()` applied.
5. **Watch dial arc is static** — `.trim(from:0, to:0.75)` constant regardless of remaining time.
6. Watch haptics not "multi-tier" — single `WKInterfaceDevice.play` per action.
7. **Three parallel token definitions** (Mac `AeroColor`, iOS `AeroColor`, widget `AeroWidgetColor`) + Watch inline hardcoded volt/slate — drift risk.

## Implementation plan (completed in order)

1. **Menu bar hero**: render the stretching figure *inside* the Volt progression arc in the popover (reuse the status-item glyph, add Volt color/glow — drop `isTemplate` for the popover instance).
2. **Spatial chimes**: switch `AeroAcoustics` to a 2-channel (stereo) source or AVAudioEngine; or relabel the feature to "harmonic glass chimes" (do not overstate).
3. Normalize tokens to spec (specular 0.14, 0.5pt borders, shadow `0.35/r24/y12`, slate 70%).
4. Add `-0.5pt` tracking on countdown timers; add `+0.8pt`/uppercase on telemetry readouts.
5. **Watch dial**: drive `.trim(to:)` from remaining-time fraction, not a constant.
6. **Multi-tier haptics**: sequence (e.g., `.notification` then `.success`) for Done.
7. **Unify tokens**: one pure shared `AeroPalette` in `StandUpReminderCore`, consumed by Mac/iOS/widget/Watch without introducing SwiftUI into the core target.

## Verification

- Build macOS + iOS + watchOS; confirm popover shows figure-in-arc with Volt color, chime plays stereo, watch arc tracks remaining time, tokens identical across targets.

## Risks / notes

- Confirm `.strokeBorder` with a `LinearGradient` ShapeStyle compiles on the iOS minimum deployment target.
- Design spec + mood-board images live only in Obsidian (`![[…]]` embeds), not the repo — consider archiving assets in `docs/design/`.
