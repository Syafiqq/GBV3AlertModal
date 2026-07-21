# Dialog Gallery Sample App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build a Dialog Gallery in the example app that presents every distinct Geniebook alert shape with exact text/fonts/colors/images, traversable via a fixed floating Prev/Next control + a backing list.

**Design:** `docs/superpowers/specs/2026-07-21-dialog-gallery-sample-design.md`
**Content source of truth:** `docs/superpowers/specs/2026-07-21-dialog-catalog.md` — 26 shapes, resolved `en` strings, 12 assets (+source paths), 12 colors (hex), 5 fonts. USE ITS EXACT VALUES; do not invent text/colors.

## Already done (setup — do NOT redo)
- Example converted to folder-synchronized group (objectVersion 77): **any file dropped into `Examples/GBV3AlertModalExample/GBV3AlertModalExample/` is auto-compiled/bundled** — no pbxproj edits needed. (Exception: `Info.plist` is excluded from bundling.)
- Package repointed to the local library (`../..`); the example builds against the working copy. Verified BUILD SUCCEEDED.

## Global Constraints
- Work in `Examples/GBV3AlertModalExample/GBV3AlertModalExample/` (the app folder). New Swift files, fonts, and `.imageset`s dropped here are auto-included.
- Simulator: **iPhone 17**. Build/run: `xcodebuild -project Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17' build`. (Run in FOREGROUND with a long timeout; if it backgrounds, read the log to completion — do not yield on a background monitor.)
- The sample imports ONLY `GBV3AlertModal`. It must NOT reference the distribution app's `Presentation.UiKit.V3AlertModal`, `UIColor.Genie`, `FontHelper`, `Dialogable`, or RxSwift.
- Exact `en` strings embedded as Swift string literals (from the catalog) — NO Localizable.strings/localization setup.
- Font source files: `geniebook-student-ios-distribution/Others/Fonts/OpenSans-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf`. Asset sources: paths in the catalog's "Static assets" table.
- API/dynamic fields (catalog-flagged) render as representative text prefixed `[API] `.

## File structure (all under the app folder)
```
Gallery/GalleryTokens.swift
Gallery/GalleryPresets.swift
Gallery/SampleAlertModal.swift
Gallery/DialogCatalog.swift
Gallery/GalleryViewController.swift
Gallery/FloatingTraversalControl.swift
Resources/Fonts/OpenSans-*.ttf         (5 files)
Assets.xcassets/…                       (12 imagesets copied in)
DYNAMIC-CONTENT.md
Info.plist                              (add UIAppFonts)
AppDelegate.swift / SceneDelegate       (set GalleryViewController as root)
```

---

## Task 1: Fonts + assets (resources)

**Files:** copy 5 `.ttf` into `.../GBV3AlertModalExample/Resources/Fonts/`; copy 12 `.imageset` folders into `.../GBV3AlertModalExample/Assets.xcassets/`; edit `Info.plist`.

- [ ] **Step 1: Copy the 5 OpenSans fonts** from `geniebook-student-ios-distribution/Others/Fonts/OpenSans-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf` into `Resources/Fonts/`.
- [ ] **Step 2: Register them in `Info.plist`** — add a `UIAppFonts` array listing the 5 filenames. (Info.plist is the one at the app folder root, referenced via INFOPLIST_FILE.)
- [ ] **Step 3: Copy the 12 `.imageset`s** listed in the catalog's assets table (each is a folder with `Contents.json` + pngs) from the distribution `Assets.xcassets` paths into the example `Assets.xcassets/`.
- [ ] **Step 4: Build** → BUILD SUCCEEDED (fonts + assets are picked up automatically via the sync group / asset catalog).
- [ ] **Step 5: Commit** — `feat(example): add Geniebook fonts + banner assets`

---

## Task 2: `GalleryTokens` — exact colors + fonts

**Files:** create `Gallery/GalleryTokens.swift`.

**Interfaces (produce):**
- `enum GalleryColor` with the **12 hex values** from the catalog (e.g. `accentSecondary = #F7A440`, `primary/GBPNavy = #262262`, `textPrimaryDark = #333333`, `labelSubtitle = #515151`, `accentSecondaryDark = #F7941E`, `pressedBlue = #038CD5`, `borderLight = #B4B4B4`, `orangeMandarin = #E57B41`, `pastelRed = #F56468`, `englishVermillion = #C54A47`, `blueSky = #63C1E9`, white). Provide `UIColor` accessors + a `UIColor(hex:)` init.
- `enum GallerySHSans` mapping weights to bundled OpenSans: `.regular→OpenSans-Regular`, `.medium→OpenSans-Medium`, `.semiBold→OpenSans-SemiBold`, `.bold→OpenSans-Bold`, `.heavy→OpenSans-ExtraBold`; `func font(_ size: CGFloat) -> UIFont` using the PostScript name.

- [ ] **Step 1: Write `GalleryTokens.swift`** with the exact hex + font names from the catalog.
- [ ] **Step 2: Build** → SUCCEEDED.
- [ ] **Step 3: Assert the fonts resolve** — a tiny check (e.g. in a temporary `#if DEBUG` assert on launch, or the smoke test in Task 7) that `GallerySHSans.bold.font(24)` is not the system fallback (`fontName` contains "OpenSans"). Remove/keep per Task 7.
- [ ] **Step 4: Commit** — `feat(example): GalleryTokens with exact Genie colors + OpenSans fonts`

---

## Task 3: `GalleryPresets` — preset layer mirror

**Files:** create `Gallery/GalleryPresets.swift`.

Mirror `V3AlertModal+GBV3AlertModal` from the catalog: `properties` (standard), `popupProperties` (banner popup), `badgeProperties`, `streakModalProperties`, and the permission-alert override; the `capsuleTheme`/`plainTheme`/`obliqueBottomLeftTheme` (default) + the red oblique theme (pastelRed/englishVermillion); the default `holder`. Build them with `GBAlertModal.Properties(...)`/`ContentProperty`/`ComponentSpace`/`ActionStyle` using `GalleryColor`/`GallerySHSans`. Copy the exact numeric values (corner 16, width 256 phone / 300 pad, margins, paddings, spaces, ratios) from the catalog.

- [ ] **Step 1: Write `GalleryPresets.swift`** — one static per preset/theme, values from the catalog.
- [ ] **Step 2: Build** → SUCCEEDED.
- [ ] **Step 3: Commit** — `feat(example): GalleryPresets mirroring V3AlertModal presets/themes`

---

## Task 4: `SampleAlertModal`

**Files:** create `Gallery/SampleAlertModal.swift`.

`final class SampleAlertModal: GBAlertModal` with `show()` (find the key window, `show(parent:completion:)`) and `removeSelf()/hide` — mirroring the app's `V3AlertModal.show()`. Keep it minimal; no Dialogable.

- [ ] **Step 1: Write it.**
- [ ] **Step 2: Build** → SUCCEEDED.
- [ ] **Step 3: Commit** — `feat(example): SampleAlertModal (show via key window)`

---

## Task 5: `DialogCatalog` — the 26 factories

**Files:** create `Gallery/DialogCatalog.swift` (split into 2 files by category if it grows past ~400 lines).

```swift
struct DialogEntry { let name: String; let category: String; let make: () -> SampleAlertModal }
enum DialogCatalog { static let entries: [DialogEntry] = [ … 26 … ] }
```
One entry per catalog shape. Each `make` uses the matching preset + a `DataHolder` built from the catalog's exact strings/assets/config. Worksheet shapes build their `subtitleCustomView` (a `UITextView` in a bordered container for rename; a `UIDatePicker` for date) as the catalog describes. API-flagged fields use `"[API] …"` literals; `badge.localImageName` uses a placeholder image.

- [ ] **Step 1: Implement all 26 factories** from the catalog. Reference the catalog per entry for name, preset, holder config, exact `en` text, and asset name.
- [ ] **Step 2: Build** → SUCCEEDED.
- [ ] **Step 3: Commit** — `feat(example): DialogCatalog with 26 Geniebook dialog shapes`

---

## Task 6: Gallery UI + floating traversal

**Files:** create `Gallery/GalleryViewController.swift`, `Gallery/FloatingTraversalControl.swift`; modify the app entry point to make `GalleryViewController` (in a `UINavigationController`) the root.

- `GalleryViewController`: `UITableViewController`-style list grouped by `entry.category`; row text = `entry.name`; tap → `dismissCurrent(); present(entry)`; keeps a `currentIndex`.
- `FloatingTraversalControl`: a pill view (added to the key window, pinned above safe-area bottom, high `windowLevel`/z so it stays above presented modals): `‹ Prev`, center label `"<name> (i/N)"`, `Next ›`. Prev/Next → `gallery.step(-1/+1)` which dismisses the current modal, advances `currentIndex` (wrapping), presents the new entry, and updates the label + list selection.
- Wire the app's entry point (`AppDelegate`/`SceneDelegate` — check which the example uses) to install the gallery as root and add the floating control to the key window on launch.

- [ ] **Step 1: Implement the VC + floating control + entry-point wiring.**
- [ ] **Step 2: Build** → SUCCEEDED.
- [ ] **Step 3: Commit** — `feat(example): gallery list + floating prev/next traversal`

---

## Task 7: API-content doc + smoke test + launch verify

**Files:** create `DYNAMIC-CONTENT.md`; add a smoke test (example test target) or a launch assert.

- [ ] **Step 1: Write `DYNAMIC-CONTENT.md`** listing every `[API]`/dynamic field per shape (from the catalog's flagged fields) so it's clear what's runtime-driven in the real app.
- [ ] **Step 2: Smoke test** — for every `DialogCatalog.entries`, assert `make()` returns a modal whose `vwContainer` is non-nil after `show()` into a test window (catches a broken factory). Put it in `GBV3AlertModalExampleTests` (that target already exists). If the test target is awkward under the sync-group conversion, instead add a `#if DEBUG` launch assert that instantiates every entry once.
- [ ] **Step 3: Build + launch** the app on the simulator; confirm the gallery lists 26 entries and the floating control steps through them. Capture a screenshot of the list + one stepped dialog.
- [ ] **Step 4: Commit** — `docs(example): dynamic-content list + catalog smoke test`

---

## Self-Review
**Coverage:** setup (done) → fonts/assets (T1) → tokens (T2) → presets (T3) → SampleAlertModal (T4) → 26 factories (T5) → gallery+floating traversal (T6) → API doc+smoke+launch (T7). Matches the design.
**Placeholders:** exact strings/colors/assets live in the catalog doc (resolved, not TBD); tasks reference it per entry. Representative code shown for the structural pieces; the 26 factories are mechanical transcriptions of catalog rows.
**Risk:** T5 (26 factories) is the largest — split by category if needed; the smoke test (T7) is its safety net. T6 floating-control-over-presented-modal z-ordering is the trickiest UI bit — the control lives in the key window at a high level so presented modals (added to the same window) don't cover it; verify visually on launch.
