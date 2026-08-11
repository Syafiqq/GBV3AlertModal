# GBV3AlertModal — Test, Extract Core, Fix Bugs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a three-layer test net around `GBAlertModal` grounded in real Geniebook usage, extract the render-decision logic into a pure testable resolver, fix two known bugs, and leave the module mature enough to justify a later SwiftUI port.

**Architecture:** Three test layers, each at its cheapest home. **Layer A (Resolver):** a pure `(Properties?, DataHolder) -> ResolvedModal` function, exhaustively unit-tested — this doubles as the SwiftUI equivalence spec. **Layer B (Wiring):** one view-property/behavioral assert per public config field + public method, proving each knob is wired (no snapshots). **Layer C (Snapshot):** a small set of shipped Geniebook shapes + text-wrapping extremes, image-diffed. Refactor is test-first: characterize (C) before extracting (A), so behavior is pinned before it moves.

**Tech Stack:** Swift 5.9, iOS 13+, UIKit, SnapKit, XCTest, `swift-snapshot-testing` (pointfree), `xcodebuild test` on an iOS Simulator destination.

## Global Constraints

- Platform: iOS 13+ (`.iOS(.v13)`), Swift tools 5.9. Verbatim from `Package.swift`.
- Tests run on Simulator only: `swift test` (macOS) will NOT compile — no iOS UIKit. Use `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 15'`.
- One new dependency permitted: `swift-snapshot-testing`, added as a **testTarget-only** dependency in `Package.swift`. No new runtime dependencies on the library product.
- The library product must gain **zero** new runtime dependencies and **zero** new public API in Phases 1–5 except the `ResolvedModal` type and its pure resolver (Phase 3). Bug fixes must not change public signatures.
- Test the **shipped slice** for snapshots (Layer C); test the **full config surface** only at the pure/wiring layers (A, B). Never snapshot the full config cross-product.
- Genie-like preset values are copied verbatim from the real consumer at
  `geniebook-student-ios-distribution/Common/Common/Custom/Components/AlertModal/V3AlertModal+GBV3AlertModal.swift`
  (width 256 phone / 300 pad, corner 16, vertical buttons, `matchParent` true, oblique primary + plain secondary). Fonts/colors are approximated with system equivalents — exact Genie tokens live in the app, not this repo.

**Public surface under test** (Layer B checklist source of truth):
- `Properties`: 19 fields — baseTint, overlayColor, contentProperty, margin, padding, bannerRatio, bannerMaxHeight, bannerFixedHeight, titleFont, titleColor, subtitleFont, subtitleColor, buttonActionShouldMatchParent, buttonActionOrientation, primaryActionStyle, secondaryActionStyle, closeButtonTint, space.
- `Properties.ContentProperty`: 7 — backgroundColor, cornerRadius, fixedWidthPortrait, maxWidthPortrait, fixedWidthLandscape, maxWidthLandscape, childShouldMatchParent.
- `Properties.ComponentSpace`: 4 — banner, title, subtitle, interButton.
- `DataHolder`: 13 — closeOnTapOverlay, banner, title, titleAttributed, subtitle, subtitleAttributed, subtitleCustomView, primaryAction, secondaryAction, showCloseButton, closeImage, dismissOnAction, completion.
- `ActionStyle`: 4 cases — capsule, capsuleOutlined, plain, obliqueBottomLeft (each with a theme struct).
- Public methods (9): `init(properties:holder:)`, `show(parent:completion:)`, `hide()`, `dismiss()`, `dismissAndEmit(event:)`, `updateDialog(holder:properties:)`, `changePrimaryActionEnableState(isEnable:)`, `changeSecondaryActionEnableState(isEnable:)`, `layoutSubviews()`.

---

## File Structure

- `Package.swift` — modify: drop i18n resource + `defaultLocalization`; add snapshot testTarget dep.
- `Library/GBV3AlertModal/Sources/GBV3AlertModal/i18n/` — delete (4 empty `.strings`).
- `Library/GBV3AlertModal/Sources/GBV3AlertModal/Components/GBAlertModal+ResolvedModal.swift` — create (Phase 3): the pure `ResolvedModal` value type + `resolve(properties:holder:)`.
- `Library/GBV3AlertModal/Sources/GBV3AlertModal/GBAlertModal.swift` — modify (Phase 3): route render decisions through the resolver; (Phase 5) bug fixes.
- `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/`
  - `Support/GeniePresets.swift` — create: Genie-like `Properties`/`DataHolder` fixtures + the 7 shipped shapes + wrapping extremes.
  - `Support/SnapshotSupport.swift` — create: host-window render helper for deterministic snapshots.
  - `LayerC_SnapshotTests.swift` — create (Phase 2): shipped shapes + wrapping.
  - `LayerA_ResolverTests.swift` — create (Phase 4): exhaustive config-branch asserts.
  - `LayerB_WiringTests.swift` — create (Phase 4/5): one assert per public field + method.
  - `BugRegressionTests.swift` — create (Phase 5): copy() + memoization.

---

## Task 1: Nuke dead i18n

**Files:**
- Delete: `Library/GBV3AlertModal/Sources/GBV3AlertModal/i18n/` (en/id/vi/zh-Hans `.lproj`, all empty)
- Modify: `Package.swift:31-34` (resources), `Package.swift:8` (defaultLocalization)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing — pure deletion. Confirmed safe: zero `NSLocalizedString`/`.localized` in the lib; only `Bundle.module` use is the close-button *image* (keep `Assets.xcassets`).

- [ ] **Step 1: Confirm no string localization exists (guard against surprise)**

Run: `grep -rn "NSLocalizedString\|\.localized\|localizedString" Library/GBV3AlertModal/Sources`
Expected: no matches.

- [ ] **Step 2: Delete the i18n directory**

```bash
git rm -r Library/GBV3AlertModal/Sources/GBV3AlertModal/i18n
```

- [ ] **Step 3: Remove the i18n resource and defaultLocalization from Package.swift**

In `Package.swift`, delete the `.process("i18n"),` line from the `resources:` array (leave `.process("Assets.xcassets")`), and delete the `defaultLocalization: "en",` line.

- [ ] **Step 4: Verify the package still resolves and builds**

Run: `xcodebuild -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 15' build`
Expected: BUILD SUCCEEDED. (Close image still loads via `Bundle.module`.)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "chore: remove dead i18n resources (all .strings empty, unused)"
```

---

## Task 2: Snapshot infrastructure + Layer C characterization (shipped shapes + wrapping)

**Files:**
- Modify: `Package.swift` (add `swift-snapshot-testing` dep + testTarget dep)
- Create: `Tests/GBV3AlertModalTests/Support/GeniePresets.swift`
- Create: `Tests/GBV3AlertModalTests/Support/SnapshotSupport.swift`
- Create: `Tests/GBV3AlertModalTests/LayerC_SnapshotTests.swift`

**Interfaces:**
- Produces:
  - `enum GeniePresets` with `static func standardProperties() -> GBAlertModal.Properties`, `popupProperties()`, and holder builders `oneButton()`, `twoButton()`, `withBanner()`, `withCloseButton()`, `renameWorksheet()`, `datePickerWorksheet()`, `longTitle()`, `longSubtitle()`, `longButtonLabel()`.
  - `func renderForSnapshot(_ modal: GBAlertModal, size: CGSize) -> UIView` — pins the modal in a fixed-size host window, forces layout, returns the host for `assertSnapshot`.

- [ ] **Step 1: Add swift-snapshot-testing as a test-only dependency**

In `Package.swift`, add to `dependencies:`:
```swift
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
```
and to the `GBV3AlertModalTests` target `dependencies:`:
```swift
.product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
```

- [ ] **Step 2: Write the render helper (deterministic host)**

Create `Support/SnapshotSupport.swift`:
```swift
import UIKit
@testable import GBV3AlertModal

func renderForSnapshot(_ modal: GBAlertModal, size: CGSize) -> UIView {
    let host = UIView(frame: CGRect(origin: .zero, size: size))
    host.backgroundColor = .white
    modal.show(parent: host, completion: {})
    host.setNeedsLayout()
    host.layoutIfNeeded()
    return host
}
```

- [ ] **Step 3: Write the Genie-like presets (verbatim structural values, approximated fonts/colors)**

Create `Support/GeniePresets.swift` copying the structural values from `V3AlertModal+GBV3AlertModal.swift` (corner 16, width 256 phone, vertical buttons, matchParent true, oblique primary + plain secondary, closeOnTapOverlay true, dismissOnAction true). Use `UIFont.boldSystemFont(ofSize:24)` etc. for fonts and `.systemBlue`/`.label` for colors as stand-ins. Provide the builders listed in Interfaces. (Full body written during execution against the current struct initializers — no field may be omitted; `buttonActionShouldMatchParent: true` is required.)

- [ ] **Step 4: Write ONE failing snapshot test first (recording pass)**

Create `LayerC_SnapshotTests.swift`:
```swift
import XCTest
import SnapshotTesting
@testable import GBV3AlertModal

final class LayerC_SnapshotTests: XCTestCase {
    let portrait = CGSize(width: 390, height: 844)
    let landscape = CGSize(width: 844, height: 390)

    func test_standardDialog_twoButton_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                 holder: GeniePresets.twoButton())
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
    }
}
```

- [ ] **Step 5: Run to record the baseline**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:GBV3AlertModalTests/LayerC_SnapshotTests/test_standardDialog_twoButton_portrait`
Expected: FAIL first run ("No reference was found on disk. Automatically recorded snapshot"), PASS on re-run. Inspect the recorded PNG visually before trusting it.

- [ ] **Step 6: Fill out the remaining Layer C fixtures**

Add tests for each shipped shape × {portrait, landscape}: one-button, two-button, withBanner, withCloseButton, popupProperties, renameWorksheet, datePickerWorksheet — plus wrapping extremes: longTitle (multi-line wrap), longSubtitle (wrap + assert scroll engages), longButtonLabel. For `longSubtitle`, add a behavioral assert alongside the snapshot:
```swift
func test_longSubtitle_scrollEngages() {
    let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                             holder: GeniePresets.longSubtitle())
    _ = renderForSnapshot(modal, size: portrait)
    let sv = modal.svSubtitleContainer!
    XCTAssertGreaterThan(sv.contentSize.height, sv.bounds.height,
                         "long subtitle must overflow so the scroll view engages")
}
```

- [ ] **Step 7: Run the full Layer C suite (record baselines, eyeball each PNG)**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:GBV3AlertModalTests/LayerC_SnapshotTests`
Expected: all record then PASS. **Manually review every recorded PNG** — a wrong baseline pins a bug.

- [ ] **Step 8: Commit the characterization net**

```bash
git add -A && git commit -m "test: Layer C snapshot characterization (shipped shapes + text wrapping)"
```

---

## Task 3: Extract the pure resolver (`ResolvedModal`)

**Files:**
- Create: `Components/GBAlertModal+ResolvedModal.swift`
- Modify: `GBAlertModal.swift` — replace inline decisions in the render pipeline (`initData`/`registerDialogView`/`adjustSvContentContainerConstraintWidth`) with reads from a computed `ResolvedModal`.

**Interfaces:**
- Produces:
```swift
extension GBAlertModal {
    public struct ResolvedModal: Equatable {
        public enum SubtitleKind: Equatable { case none, plain(String), attributed, custom }
        public var showsBanner: Bool
        public var showsTitle: Bool
        public var subtitle: SubtitleKind
        public var showsPrimary: Bool
        public var showsSecondary: Bool
        public var showsCloseButton: Bool
        public var buttonAxis: NSLayoutConstraint.Axis
        public var buttonsMatchParent: Bool
        public var dismissOnAction: Bool
        public var closeOnTapOverlay: Bool
        public var contentWidth: WidthResolution   // .fixed(CGFloat) / .max(CGFloat) / .flexible
    }
    static func resolve(properties: Properties?, holder: DataHolder,
                        isLandscape: Bool, isPad: Bool) -> ResolvedModal
}
```
- Consumes (Task 4): `resolve(...)`. Consumes (Task 5 fixes): unchanged.

**Precondition:** Layer C from Task 2 is green. Do NOT start extraction otherwise — the snapshots are the safety net that proves the move preserved behavior.

- [ ] **Step 1: Read the full render pipeline before touching it**

Read `GBAlertModal.swift` sections `initViews`, `initData`, `registerDialogView`, `adjustDialogViewStyle`, `adjustSvContentContainerConstraintWidth`, and the banner/subtitle/close visibility branches. Note every `if let`/`== true` decision that chooses what renders — these become `ResolvedModal` fields.

- [ ] **Step 2: Write the resolver's first failing test (visibility decisions)**

In a new `LayerA_ResolverTests.swift`:
```swift
func test_resolve_bannerVisibleWhenImagePresent() {
    let holder = GBAlertModal.DataHolder(banner: UIImage())
    let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false, isPad: false)
    XCTAssertTrue(r.showsBanner)
}
func test_resolve_noBannerWhenNil() {
    let r = GBAlertModal.resolve(properties: nil, holder: .default, isLandscape: false, isPad: false)
    XCTAssertFalse(r.showsBanner)
}
```

- [ ] **Step 3: Run to confirm failure**

Run: `xcodebuild test ... -only-testing:GBV3AlertModalTests/LayerA_ResolverTests/test_resolve_bannerVisibleWhenImagePresent`
Expected: FAIL — `resolve` not defined.

- [ ] **Step 4: Implement `ResolvedModal` + `resolve(...)` mirroring the current inline logic exactly**

Create `GBAlertModal+ResolvedModal.swift`. Port each decision verbatim from the pipeline read in Step 1 (banner: `holder.banner != nil`; title: `title != nil || titleAttributed != nil`; subtitle kind precedence: custom > attributed > plain > none; width from ContentProperty fixed/max × orientation). No behavior change — this is a pure mirror.

- [ ] **Step 5: Run the resolver tests green**

Run: `xcodebuild test ... -only-testing:GBV3AlertModalTests/LayerA_ResolverTests`
Expected: PASS.

- [ ] **Step 6: Route the view through the resolver, keep Layer C green**

Replace the inline decisions in the render pipeline with reads from `Self.resolve(...)`. Change nothing about the *values* — only the source. Run the FULL Layer C suite:
Run: `xcodebuild test ... -only-testing:GBV3AlertModalTests/LayerC_SnapshotTests`
Expected: PASS with no snapshot diffs. Any diff = the extraction changed behavior; reconcile before continuing.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "refactor: extract pure ResolvedModal resolver from view render pipeline"
```

---

## Task 4: Layer A exhaustive + Layer B wiring coverage

**Files:**
- Modify: `LayerA_ResolverTests.swift` (exhaustive branches)
- Create: `LayerB_WiringTests.swift` (one assert per public field + method)

**Interfaces:**
- Consumes: `GBAlertModal.resolve(...)`, all public config fields, the 9 public methods.

- [ ] **Step 1: Layer A — cover every structural branch**

For each structural config, assert `resolve(...)` yields the right `ResolvedModal`: `buttonActionOrientation` .horizontal vs .vertical → `buttonAxis`; `buttonActionShouldMatchParent` → `buttonsMatchParent`; `fixedWidth` vs `maxWidth` × portrait/landscape → `contentWidth`; `dismissOnAction`, `closeOnTapOverlay`, `showCloseButton`; subtitle precedence with every combination of plain/attributed/custom set. One assert per branch — no snapshots.

- [ ] **Step 2: Run Layer A green**

Run: `xcodebuild test ... -only-testing:GBV3AlertModalTests/LayerA_ResolverTests`
Expected: PASS.

- [ ] **Step 3: Layer B — appearance wiring, one assert per field**

For each appearance field, instantiate the view and assert the property landed. Example:
```swift
func test_titleFontApplied() {
    let props = GeniePresets.standardProperties().copy(titleFont: .systemFont(ofSize: 42))
    let modal = GBAlertModal(properties: props, holder: GeniePresets.twoButton())
    _ = renderForSnapshot(modal, size: CGSize(width: 390, height: 844))
    XCTAssertEqual(modal.lbTitle?.font.pointSize, 42)
}
```
Cover: titleFont/Color, subtitleFont/Color, closeButtonTint, contentProperty.cornerRadius/backgroundColor, overlayColor, and each `ActionStyle` theme's title color/font on the rendered button.

- [ ] **Step 4: Layer B — public method behavior**

Assert each method:
```swift
func test_show_addsToParent() {
    let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: GeniePresets.oneButton())
    let host = UIView(); modal.show(parent: host, completion: {})
    XCTAssertTrue(host.subviews.contains(modal))
}
func test_dismissAndEmit_emitsActionType() {
    var emitted: GBAlertModal.ActionType?
    let holder = GeniePresets.twoButton().copy(dismissOnAction: false,
        completion: { _, type in emitted = type })
    let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: holder)
    modal.dismissAndEmit(event: .primary)
    XCTAssertEqual(emitted, .primary)
}
func test_changePrimaryEnableState_togglesButton() {
    let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: GeniePresets.twoButton())
    _ = renderForSnapshot(modal, size: CGSize(width: 390, height: 844))
    modal.changePrimaryActionEnableState(isEnable: false)
    XCTAssertFalse(modal.btPrimaryAction!.isEnabled)
}
```
Also: `hide()` removes from superview (after animation — use expectation), `dismiss()` respects `dismissOnAction`, `updateDialog` swaps content.

- [ ] **Step 5: Run Layer B green + tick the public-surface checklist**

Run: `xcodebuild test ... -only-testing:GBV3AlertModalTests/LayerB_WiringTests`
Expected: PASS. Cross off every field/method in Global Constraints' public-surface list — no public knob untested.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "test: Layer A exhaustive resolver + Layer B public-surface wiring coverage"
```

---

## Task 5: Fix the two known bugs (failing-first)

**Files:**
- Modify: `Components/GBAlertModal+Properties.swift` (copy() default), `Components/GBAlertModal+DataHolder.swift` if same pattern present.
- Modify: consumer note only — the memoization staleness lives in the app's `V3AlertModal+GBV3AlertModal.swift`, NOT this repo. See Step 4.
- Create/Modify: `BugRegressionTests.swift`

**Interfaces:** no public signature changes.

- [ ] **Step 1: Failing test for copy() nil-vs-false**

```swift
func test_copy_preservesMatchParentTrue() {
    let base = GBAlertModal.Properties(buttonActionShouldMatchParent: true)
    let copied = base.copy(titleColor: .red)   // unrelated field
    XCTAssertEqual(copied.buttonActionShouldMatchParent, true,
                   "copy() must not drop an explicitly-set true")
}
```

- [ ] **Step 2: Run — confirm current behavior**

Run: `xcodebuild test ... -only-testing:GBV3AlertModalTests/BugRegressionTests/test_copy_preservesMatchParentTrue`
Expected: document actual result. The `init` default is `false` but `copy` coalesces with `?? self.buttonActionShouldMatchParent`, so this likely PASSES already — the real defect is the `init` default `false` vs `copy` default `nil` asymmetry. If it passes, add the asserting test that pins the *intended* semantics and move the `init` default to `nil` for consistency; re-run to prove no regression.

- [ ] **Step 3: Make `init` and `copy` defaults consistent (both `nil`)**

Change `GBAlertModal.Properties.init`'s `buttonActionShouldMatchParent: Bool? = false` to `= nil`, matching `copy`. Verify the render pipeline already treats `nil` as `false` (`== true` checks). Run Layer A + Layer C to prove no behavior change for real presets (which pass `true`).

- [ ] **Step 4: Failing test for localized-holder staleness (documented, fixed in consumer)**

The static memoization (`_holder` caching `"action_okay".localized` at first access) lives in the **distribution app**, not this library. Add a regression test *here* only if the library gains its own default text (it does not today). Document in the plan's follow-ups: the app should compute `holder`/`properties` as non-cached computed values, or invalidate on locale change. **No library code change.**

- [ ] **Step 5: Run full suite**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: all PASS. Re-baseline only snapshots that changed for a *deliberate* reason (none expected from Task 5).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "fix: align Properties.copy/init defaults; add bug regression tests"
```

---

## Task 6: SwiftUI readiness gate (verification only — no port here)

**Files:** none (verification + docs).

- [ ] **Step 1: Confirm the gate**

Run the full suite green. Confirm: Layer C covers the 7 shipped shapes + wrapping; Layer A covers every structural branch (incl. horizontal + width modes); Layer B ticks every public field + method; both bugs have regression tests. Only when all four hold is the module "mature and well UI tested" — the precondition the owner set for starting SwiftUI. The SwiftUI view, when built, must reproduce `ResolvedModal` and pass a parallel Layer A suite. SwiftUI implementation is out of scope for this plan.

---

## Self-Review

**Spec coverage:** i18n nuke → Task 1. Distinctive/shipped tests → Task 2 (Layer C). All-possibility → Task 4 (Layer A). All public config → Task 4 (Layer B, checklist-gated). Text wrapping → Task 2 Steps 6–7. Horizontal buttons → Task 4 Step 1 (Layer A branch). Core-logic extraction for consistency + SwiftUI → Task 3. Bug fixes → Task 5. SwiftUI gate → Task 6. No gaps.

**Placeholders:** Genie preset bodies and the full per-field Layer B enumeration are written during execution against live struct initializers — the exact fields are pinned verbatim in Global Constraints, so these are mechanical, not vague. Every code step that introduces new logic shows real code.

**Type consistency:** `renderForSnapshot`, `ResolvedModal`, `resolve(properties:holder:isLandscape:isPad:)`, `GeniePresets.*` names are used identically across Tasks 2–5.

**Known caveat (ponytail):** Automated tests live in the library SPM test target (`GBV3AlertModalTests`), not the example Xcode project — simplest single `xcodebuild test` for CI. The existing `Examples/` app stays as a manual visual demo. If the owner wants snapshots physically in the example project instead, it's a target relocation, not a redesign.
