# Dialog Gallery Sample App — Design

**Date:** 2026-07-21
**Status:** Approved (brainstorming) — pending spec review → implementation plan
**Content source:** `docs/superpowers/specs/2026-07-21-dialog-catalog.md` (26 distinct shapes, tokens, assets, strings — authoritative for all exact values)

## Goal

Turn the existing `Examples/GBV3AlertModalExample` into a **Dialog Gallery** that consumes the library **locally** and presents every distinct Geniebook alert shape with exact text/fonts/colors/images, traversable via a fixed floating Prev/Next control (plus a backing list). API-sourced content is stubbed and labeled `[API]`.

## Architecture

**1. Local consumption.** Repoint the example's package dependency from `XCRemoteSwiftPackageReference "GBV3AlertModal"` (git@github…) to a **local** package (`XCLocalSwiftPackageReference`, relative path to the repo root). The example then builds against the working copy.

**2. Preset replication (the key constraint).** The sample imports only `GBV3AlertModal` — it cannot use the app's `Presentation.UiKit.V3AlertModal` (that drags in `Dialogable`, `AppCompatHelper`, `UIColor.Genie`, `FontHelper`, RxSwift). So the sample replicates the preset layer verbatim from the catalog:
- `GalleryTokens` — `UIColor.Genie`-equivalent extension with the **12 exact hex values** and a `SHSans`-equivalent font accessor mapping to the bundled `OpenSans-*.ttf`.
- `GalleryPresets` — mirrors `V3AlertModal+GBV3AlertModal`: `properties`, `popupProperties`, plus `badgeProperties`/`streakModalProperties`/permission overrides, and the capsule / plain / oblique(default+red) themes, and the default `holder`. Copied from the catalog's resolved values.
- `SampleAlertModal: GBAlertModal` — thin subclass adding `show()`/`hide()` via the key window (mirrors `V3AlertModal.show()`), so call-site code reads like the real app.

**3. Catalog + factories.** `DialogCatalog` = `[DialogEntry]` where
```swift
struct DialogEntry { let name: String; let category: String; let make: () -> SampleAlertModal }
```
One entry per distinct shape (26 from the catalog). Each `make` builds the modal with the exact preset + holder + strings + asset from the catalog. Worksheet shapes (rename textview, date picker) build their `subtitleCustomView` as the app does.

**4. Resources copied into the example target.**
- `OpenSans-Regular/Medium/SemiBold/Bold/ExtraBold.ttf` → bundled + registered in Info.plist `UIAppFonts`.
- The 12 `.imageset`s → the example `Assets.xcassets`.
- The ~120 `en` strings → the example `en.lproj/Localizable.strings` (only the keys the catalog lists).
- Colors as hex literals in `GalleryTokens`.

**5. Gallery UI.**
- `GalleryViewController` (root, in a nav controller): a `UITableView` grouped by `category`; each row = a `DialogEntry`; tap → present that entry.
- A **fixed floating pill** pinned above the safe-area bottom, always on top (added to the key window, not the table): `‹ Prev | "<name> (i/N)" | Next ›`. Prev/Next dismisses the current modal (if any) and presents the neighbor, wrapping around. Tapping a list row also syncs the pill's index.

**6. API-sourced stubs.** Fields the catalog marks dynamic (`type.lastMessage`, `error.message`, `type.subtitle`, `badge.localImageName`, the badge-detail custom view) render as representative text prefixed `[API]` (and a placeholder image for `badge.localImageName`). A `DYNAMIC-CONTENT.md` in the example lists each so it's clear what's runtime-driven in the real app.

## File structure (under `Examples/GBV3AlertModalExample/GBV3AlertModalExample/`)
```
Gallery/GalleryTokens.swift          // colors + fonts (exact values)
Gallery/GalleryPresets.swift         // properties/popupProperties/themes/holder mirrors
Gallery/SampleAlertModal.swift       // GBAlertModal subclass + show()/hide()
Gallery/DialogCatalog.swift          // [DialogEntry] — the 26 factories
Gallery/GalleryViewController.swift  // table + floating pill traversal
Gallery/FloatingTraversalControl.swift
Resources/Fonts/OpenSans-*.ttf
Assets.xcassets/… (12 imagesets)
en.lproj/Localizable.strings
DYNAMIC-CONTENT.md
```
Plus: `Info.plist` (UIAppFonts), and the `.xcodeproj` package-ref change to local.

## Testing
- The example builds and launches; the gallery lists all 26 entries.
- A lightweight smoke test (in the example's test target, or an assert-on-launch) that **every** `DialogCatalog` entry's `make()` returns a modal with a non-nil container after `show()` — catches a broken factory without needing per-dialog snapshots.
- Manual: step through all 26 via the floating control in portrait + landscape.

## Out of scope
- SwiftUI (the library's future — separate).
- Vietnamese/other locales (catalog resolved `en` only; BeVietnamPro fonts not copied).
- Wiring real API data — dynamic fields are `[API]` stubs by design.

## Non-goals / fidelity caveats
- "Exact match" = the *static* content (text/fonts/colors/static banners) is copied verbatim; dynamic content is representative stubs. Conditional banners (`isEligibleForJcUiVariant`) are shown in their banner-present variant (the flag's non-JC branch) unless a shape is defined only by the nil-banner branch.
