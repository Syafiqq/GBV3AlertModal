# SwiftUI Banner Geometry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the SwiftUI banner match UIKit's measured column width and slot height in portrait, so the differential gate compares a real banner element-for-element.

**Architecture:** UIKit's banner geometry is emergent Auto Layout output, but it is closed-form in portrait. Two rules — one for the content column, one for the slot height — were fitted to 30+ measurements and checked against six real preset/artwork pairs to within 0.4pt. This plan puts those rules in `ModalTokens` as a pure function, feeds them the artwork's point size (the operand `.resizable()` discards), and renders a slot/image split mirroring UIKit's `vwBanner`/`ivBanner`.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, UIKit, SnapKit (UIKit side only), XCTest, swift-snapshot-testing, xcodebuild against an iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-08-02-swiftui-banner-height-design.md`

## Global Constraints

- **UIKit is frozen.** `GBAlertModal+ViewGraph.swift` and `ModalLayout.swift` layout behaviour must not change. Only their stale *comments* may be corrected. Fix SwiftUI to match UIKit, never the reverse.
- **Never widen `DifferentialGeometry.tolerance`.** It is 0.5pt, deliberately not per-shape.
- **A vacuous pass must never look like a real one.** Every new differential shape needs a premise test proving it exercises what it claims.
- **No measurement cycles.** Never derive a size from a measurement that the same size feeds back into. Artwork point size is a prior, independent input — that is allowed. Container width from a `GeometryReader` is allowed. Content height is not.
- **All test commands:** `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17'`, run from the repo root `/Users/engineering/Documents/c/ios/repos/geniebook/modules/gb-v3-alert-modal`.
- **Every `ModalTokens` public API addition must keep `ModalTokens` `Equatable` and its existing `init` source-compatible** (add parameters with defaults).
- **Landscape banner height is out of scope** and must stay out. Do not attempt to make it agree.

---

## The two rules (referenced by every task)

With `r = bannerRatio ?? imageW/imageH` and `cap = bannerMaxHeight ?? .greatestFiniteMagnitude`:

```
columnCeiling = availableCardWidth - contentPadding.leftMin - contentPadding.rightMin
demand        = min(imageW, cap * r)
column        = min(max(demand, contentMaxWidth), columnCeiling)
height        = min(cap, column / r, max(imageH, imageW / r))
card          = min(column + contentPadding.leftMax + contentPadding.rightMax, availableCardWidth)
```

`availableCardWidth = hostWidth - 2 * cardMarginV`… **no** — `- 2 * cardMarginH`. On a 390pt host with `cardMarginH: 20` that is 350.

Verified against measured UIKit (portrait, iPhone 17, 390×844):

| case | column pred/meas | height pred/meas | card pred/meas |
|---|---|---|---|
| 160×90, r 1, no cap | 256 / **256** | 160 / **160** | 320 / **320** |
| badge 160×160, r 1, cap 216 | 256 / **256** | 160 / **160** | 320 / **320** |
| gc2gs 320×190, r 320:190, cap 256 | 310 / **310** | 184.1 / **184.0** | 350 / **350** |
| quiz 320×229, r 320:229, cap 216 | 301.8 / **302.0** | 216.0 / **216.0** | 350 / **350** |
| errorBanner 295×256, r 295:256, cap 320 | 295 / **295** | 256.1 / **256.0** | 350 / **350** |
| fasttrack 1168×760, r 292:190, cap 256 | 310 / **310** | 201.7 / **202.0** | 350 / **350** |
| aiNotes 320×227, r 960:681, cap 320 | 310 / **310** | 219.9 / **220.0** | 350 / **350** |

---

## File Structure

| file | responsibility | task |
|---|---|---|
| `Tests/.../BannerGeometryTruthTests.swift` | **new.** UIKit-side truth table: the two rules vs measured `vwBanner` | 1 |
| `Sources/.../SwiftUI/ModalTokens.swift` | `BannerGeometry` type + `bannerGeometry(imageSize:availableCardWidth:)`; drop `height` from `BannerLayout` | 2, 3 |
| `Tests/.../SwiftUI/ModalBannerGeometryRuleTests.swift` | **new.** Unit tests for the pure function, no views | 2 |
| `Sources/.../Core/ModalDescriptor.swift` | `ModalImage.pointSize` | 3 |
| `Sources/.../SwiftUI/AlertModalScaffold.swift` | `bannerArtworkSize` parameter, environment publication, card/content caps | 3, 4 |
| `Sources/.../SwiftUI/SwiftUIAlertModal.swift` | banner row as slot + image overlay | 3 |
| `Sources/.../SwiftUI/ModalBannerGeometry.swift` | deleted — folded into the slot frame | 3 |
| `Tests/.../Resources/GBTestAssets.xcassets/gb_test_banner_wide.imageset` | **new.** 320×190 at 1x, matching `img_gc2gs_prompt_*` | 4 |
| `Tests/.../SwiftUI/DifferentialGeometrySupport.swift` | new shapes; `excluding:`/`because:` | 3, 4, 5 |
| `Tests/.../SwiftUI/DifferentialGeometryTests.swift` | promote the banner row to a full comparison; landscape | 3, 4, 5 |

---

### Task 1: Pin the UIKit truth table

Locks the model before any production code depends on it. **No production change.** The stale priority comments in `GBAlertModal+ViewGraph.swift` (which cite 700/749/249 against constants of 245/243/241) prove a constant can change with nothing noticing; this test is the tripwire.

**Files:**
- Create: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/BannerGeometryTruthTests.swift`

**Interfaces:**
- Consumes: `GeniePresets.standardProperties()`, `GeniePresets.popupProperties()`, `GeniePresets.withBanner(width:height:)`, `GBAlertModal.vwBanner`, `GBAlertModal.vwContainer` — all existing.
- Produces: nothing consumed by later tasks. This is a pinning test.

- [ ] **Step 1: Write the failing test**

Create the file with exactly this content:

```swift
import XCTest
@testable import GBV3AlertModal

/// **The UIKit banner rules, pinned against measured Auto Layout output.**
///
/// UIKit's banner geometry is emergent — `vwBanner` often carries NO height constraint at all, and
/// the slot's size falls out of `ivBanner`'s intrinsic content size meeting its default compression
/// resistance (750) through the `width == height * ratio` tie. Two closed-form rules reproduce it in
/// portrait; this suite is what fails if a priority in `ModalLayout.Priority` is retuned, which has
/// already happened once with only stale comments to show for it.
///
/// PORTRAIT ONLY, and deliberately so: in a height-constrained card UIKit distributes the remainder
/// across four sub-required tiers and the banner takes the residual (measured 102.3 for every real
/// preset regardless of ratio or cap). No closed form reaches that, and none is claimed here.
@MainActor
final class BannerGeometryTruthTests: XCTestCase {
    private let host = CGSize(width: 390, height: 844)

    /// The rules under test. Mirrors `ModalTokens.bannerGeometry` (Task 2) but is written out
    /// independently ON PURPOSE: a truth table that imports the implementation it is checking
    /// proves only that the code equals itself.
    private func predicted(
        imageSize: CGSize,
        ratio: CGFloat?,
        cap: CGFloat?,
        contentMaxWidth: CGFloat,
        leftMin: CGFloat,
        rightMin: CGFloat,
        availableCardWidth: CGFloat
    ) -> (column: CGFloat, height: CGFloat) {
        guard imageSize.width > 0, imageSize.height > 0 else { return (0, 0) }
        let r = ratio ?? (imageSize.width / imageSize.height)
        let capped = cap ?? .greatestFiniteMagnitude
        let ceiling = availableCardWidth - leftMin - rightMin
        let demand = min(imageSize.width, capped * r)
        let column = min(max(demand, contentMaxWidth), ceiling)
        let height = min(capped, column / r, max(imageSize.height, imageSize.width / r))
        return (column, height)
    }

    private func measure(
        _ properties: GBAlertModal.Properties,
        imageSize: CGSize
    ) -> (column: CGFloat, height: CGFloat, card: CGFloat) {
        let modal = GBAlertModal(
            properties: properties,
            holder: GeniePresets.withBanner(width: imageSize.width, height: imageSize.height)
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: host))
        window.isHidden = false
        modal.show(parent: window, completion: {})
        window.setNeedsLayout()
        window.layoutIfNeeded()
        let slot = modal.vwBanner?.frame ?? .zero
        let card = modal.vwContainer?.frame ?? .zero
        window.isHidden = true
        return (slot.width, slot.height, card.width)
    }

    private func assertRules(
        _ label: String,
        properties: GBAlertModal.Properties,
        imageSize: CGSize,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let measured = measure(properties, imageSize: imageSize)
        let padding = properties.padding ?? UIMinMaxEdgeInsets()
        let expected = predicted(
            imageSize: imageSize,
            ratio: properties.bannerRatio,
            cap: properties.bannerMaxHeight,
            contentMaxWidth: properties.contentProperty?.maxWidthPortrait ?? .infinity,
            leftMin: padding.leftMin,
            rightMin: padding.rightMin,
            availableCardWidth: host.width - (properties.margin?.left ?? 0) - (properties.margin?.right ?? 0)
        )
        XCTAssertEqual(
            measured.column, expected.column, accuracy: 0.5,
            "\(label): column rule broke — measured \(measured.column), rule says \(expected.column)",
            file: file, line: line
        )
        XCTAssertEqual(
            measured.height, expected.height, accuracy: 0.5,
            "\(label): height rule broke — measured \(measured.height), rule says \(expected.height)",
            file: file, line: line
        )
    }

    // MARK: - Artwork that fits inside the column

    func test_ratio1_artworkNarrowerThanColumn() {
        assertRules("160x90 r1 no cap",
                    properties: GeniePresets.standardProperties(),
                    imageSize: CGSize(width: 160, height: 90))
    }

    func test_ratio1_squareArtworkNarrowerThanColumn() {
        assertRules("160x160 r1 cap216",
                    properties: GeniePresets.popupProperties().copy(bannerRatio: 1, bannerMaxHeight: 216),
                    imageSize: CGSize(width: 160, height: 160))
    }

    func test_naturalAspect_artworkNarrowerThanColumn() {
        assertRules("160x90 rNil no cap",
                    properties: GeniePresets.standardPropertiesNilBannerRatio(),
                    imageSize: CGSize(width: 160, height: 90))
    }

    // MARK: - Artwork wider than the column (every real app asset but one)

    func test_gc2gsShape_artworkWiderThanColumn() {
        assertRules("320x190 r320:190 cap256",
                    properties: GeniePresets.popupProperties()
                        .copy(bannerRatio: 320.0 / 190.0, bannerMaxHeight: 256),
                    imageSize: CGSize(width: 320, height: 190))
    }

    func test_quizShape_capBindsBeforeTheColumn() {
        assertRules("320x229 r320:229 cap216",
                    properties: GeniePresets.popupProperties()
                        .copy(bannerRatio: 320.0 / 229.0, bannerMaxHeight: 216),
                    imageSize: CGSize(width: 320, height: 229))
    }

    func test_errorBannerShape_artworkJustUnderTheCeiling() {
        assertRules("295x256 r295:256 cap320",
                    properties: GeniePresets.errorBannerProperties(),
                    imageSize: CGSize(width: 295, height: 256))
    }

    func test_fasttrackShape_hugeArtworkClampsToTheCeiling() {
        assertRules("1168x760 r292:190 cap256",
                    properties: GeniePresets.popupProperties()
                        .copy(bannerRatio: 292.0 / 190.0, bannerMaxHeight: 256),
                    imageSize: CGSize(width: 1168, height: 760))
    }

    // MARK: - The cap

    func test_capBelowEverything_wins() {
        assertRules("160x90 r1 cap40",
                    properties: GeniePresets.standardProperties().copy(bannerMaxHeight: 40),
                    imageSize: CGSize(width: 160, height: 90))
    }

    // MARK: - The inert field, pinned so its removal from SwiftUI stays justified

    /// `bannerFixedHeight` sits at 243: below the card's hugging (250) going up, below the image's
    /// compression resistance (750) coming down. Measured zero effect at every size tried. SwiftUI
    /// drops it in Task 3 on the strength of this test.
    func test_bannerFixedHeight_isInert_onTheRatioPath() {
        let withFixed = measure(
            GeniePresets.standardProperties().copy(bannerFixedHeight: 200),
            imageSize: CGSize(width: 64, height: 64)
        )
        let without = measure(
            GeniePresets.standardProperties(),
            imageSize: CGSize(width: 64, height: 64)
        )
        XCTAssertEqual(withFixed.height, without.height, accuracy: 0.5,
                       "bannerFixedHeight changed the slot height — it is no longer inert, and "
                           + "ModalTokens.bannerLayout must start applying it again")
        XCTAssertEqual(withFixed.height, 64, accuracy: 0.5)
    }

    func test_bannerFixedHeight_isInert_onTheNaturalAspectPath() {
        let withFixed = measure(
            GeniePresets.standardPropertiesNilBannerRatio().copy(bannerFixedHeight: 200),
            imageSize: CGSize(width: 64, height: 64)
        )
        XCTAssertEqual(withFixed.height, 64, accuracy: 0.5,
                       "bannerFixedHeight is no longer inert on the natural-aspect path")
    }

    // MARK: - Degenerate

    func test_zeroSizeArtwork_collapsesTheSlot() {
        let measured = measure(GeniePresets.standardProperties(), imageSize: .zero)
        XCTAssertEqual(measured.column, 0, accuracy: 0.5)
        XCTAssertEqual(measured.height, 0, accuracy: 0.5)
    }
}
```

- [ ] **Step 2: Run it and read the failures**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GBV3AlertModalTests/BannerGeometryTruthTests 2>&1 | grep -E "error:|failed|passed|\*\* TEST"
```

Expected: it may not compile first time. `GBAlertModal.Properties`' fields (`padding`, `margin`, `contentProperty`) may be non-optional, and `UIMinMaxEdgeInsets` may not have a no-argument `init`. **Fix the accessors to match the real types — do not change the rules.** Read `Components/GBAlertModal+Properties.swift` for the actual optionality.

- [ ] **Step 3: Make every case pass**

All eleven tests must pass with the rules **exactly as written**. If a case disagrees, the model is wrong and this plan's premise is broken — stop and report the disagreeing case with both numbers rather than adjusting the rule to fit.

- [ ] **Step 4: Verify**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GBV3AlertModalTests/BannerGeometryTruthTests 2>&1 | grep -E "\*\* TEST"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Library/GBV3AlertModal/Tests/GBV3AlertModalTests/BannerGeometryTruthTests.swift
git commit -m "test: pin UIKit's banner column and height rules against measured output"
```

---

### Task 2: The pure geometry function

**Files:**
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/ModalTokens.swift` (add near `bannerLayout`, ~line 684-727)
- Create: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/ModalBannerGeometryRuleTests.swift`

**Interfaces:**
- Consumes: `ModalTokens.bannerRatio`, `.bannerMaxHeight`, `.contentMaxWidth`, `.contentPadding` (all existing stored properties).
- Produces:
  - `public struct ModalTokens.BannerGeometry: Equatable { public var column: CGFloat; public var height: CGFloat }`
  - `public func bannerGeometry(imageSize: CGSize, availableCardWidth: CGFloat) -> BannerGeometry`

  Task 3 and Task 4 both call `tokens.bannerGeometry(imageSize:availableCardWidth:)` with exactly these labels.

- [ ] **Step 1: Write the failing test**

Create `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/ModalBannerGeometryRuleTests.swift`:

```swift
import XCTest
@testable import GBV3AlertModal

/// The two banner rules as a PURE function — no views, no window, no Auto Layout.
/// `BannerGeometryTruthTests` is the other half: it proves the rules match UIKit. This one proves
/// `ModalTokens` implements the rules. Neither is sufficient alone.
final class ModalBannerGeometryRuleTests: XCTestCase {
    /// Column 256, padding 20/32 per side, matching the app's real iPhone preset
    /// (`V3AlertModal+GBV3AlertModal.swift`: 256 on iPhone, 300 on iPad).
    private func tokens(ratio: CGFloat?, cap: CGFloat?) -> ModalTokens {
        ModalTokens(
            cornerRadius: 16,
            contentMaxWidth: 256,
            cardMarginV: 40,
            cardMarginH: 20,
            contentPadding: UIMinMaxEdgeInsets(
                top: (20, 32), left: (20, 32), bottom: (20, 32), right: (20, 32)
            ),
            contentChildrenFillWidth: true,
            bannerRatio: ratio,
            bannerMaxHeight: cap,
            gapBelowBanner: 16,
            gapBelowTitle: 12,
            gapBelowSubtitle: 24,
            interButton: 8,
            titleFont: .system(size: 24, weight: .bold),
            subtitleFont: .system(size: 16),
            palette: ModalTokens.standard.palette
        )
    }

    /// 390pt host, 20pt horizontal card margin -> 350pt of card, 310pt of column ceiling.
    private let available: CGFloat = 350

    func test_artworkNarrowerThanColumn_columnStaysAtContentMaxWidth() {
        let g = tokens(ratio: 1, cap: nil)
            .bannerGeometry(imageSize: CGSize(width: 160, height: 90), availableCardWidth: available)
        XCTAssertEqual(g.column, 256, accuracy: 0.01)
        XCTAssertEqual(g.height, 160, accuracy: 0.01)   // max(90, 160/1) = 160
    }

    func test_artworkWiderThanColumn_columnGrows() {
        let g = tokens(ratio: 320.0 / 190.0, cap: 256)
            .bannerGeometry(imageSize: CGSize(width: 320, height: 190), availableCardWidth: available)
        XCTAssertEqual(g.column, 310, accuracy: 0.01)   // demand 320, clamped by the 310 ceiling
        XCTAssertEqual(g.height, 310 / (320.0 / 190.0), accuracy: 0.01)   // 184.06
    }

    func test_capLimitsTheColumnDemand_notJustTheHeight() {
        // cap 216 * ratio 1.397 = 301.8, which is BELOW the artwork's 320 — so the cap, not the
        // artwork, sets the demand. Measured UIKit: column 302.
        let g = tokens(ratio: 320.0 / 229.0, cap: 216)
            .bannerGeometry(imageSize: CGSize(width: 320, height: 229), availableCardWidth: available)
        XCTAssertEqual(g.column, 216 * (320.0 / 229.0), accuracy: 0.01)   // 301.83
        XCTAssertEqual(g.height, 216, accuracy: 0.01)
    }

    func test_hugeArtwork_clampsToTheCeiling() {
        let g = tokens(ratio: 292.0 / 190.0, cap: 256)
            .bannerGeometry(imageSize: CGSize(width: 1168, height: 760), availableCardWidth: available)
        XCTAssertEqual(g.column, 310, accuracy: 0.01)
        XCTAssertEqual(g.height, 310 / (292.0 / 190.0), accuracy: 0.01)   // 201.7
    }

    func test_nilRatio_usesTheArtworksOwnAspect() {
        let g = tokens(ratio: nil, cap: nil)
            .bannerGeometry(imageSize: CGSize(width: 160, height: 90), availableCardWidth: available)
        XCTAssertEqual(g.column, 256, accuracy: 0.01)
        // r = 160/90; max(90, 160/r) = 90; column/r = 144. min -> 90.
        XCTAssertEqual(g.height, 90, accuracy: 0.01)
    }

    func test_capBelowEverything_wins() {
        let g = tokens(ratio: 1, cap: 40)
            .bannerGeometry(imageSize: CGSize(width: 160, height: 90), availableCardWidth: available)
        XCTAssertEqual(g.height, 40, accuracy: 0.01)
    }

    func test_zeroArtwork_collapses() {
        let g = tokens(ratio: 1, cap: nil)
            .bannerGeometry(imageSize: .zero, availableCardWidth: available)
        XCTAssertEqual(g.column, 0, accuracy: 0.01)
        XCTAssertEqual(g.height, 0, accuracy: 0.01)
    }

    func test_infiniteContentMaxWidth_doesNotProduceAnInfiniteColumn() {
        // `ModalTokens.standard` uses `contentMaxWidth: .infinity` (no Properties to derive a cap
        // from). The ceiling must still bound it.
        var t = ModalTokens.standard
        t.bannerRatio = 1
        t.bannerMaxHeight = nil
        let g = t.bannerGeometry(imageSize: CGSize(width: 160, height: 90), availableCardWidth: available)
        XCTAssertTrue(g.column.isFinite, "an infinite contentMaxWidth escaped the ceiling")
        XCTAssertTrue(g.height.isFinite)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GBV3AlertModalTests/ModalBannerGeometryRuleTests 2>&1 | grep -E "error:"
```

Expected: compile error — `value of type 'ModalTokens' has no member 'bannerGeometry'`.

- [ ] **Step 3: Implement it**

In `ModalTokens.swift`, immediately after the `BannerLayout` struct (~line 688), add:

```swift
    /// **The banner's content column and slot height, as UIKit resolves them.**
    ///
    /// UIKit gives `vwBanner` no height constraint at all on the `bannerRatio != nil` path: the
    /// slot's size falls out of `ivBanner`'s INTRINSIC content size meeting its default vertical
    /// compression resistance (750) through the `width == height * ratio` tie — and that same 750
    /// outranks the content column's `width == fixedWidth` at `.medium` (500), so wide artwork
    /// makes the COLUMN wider too. Both facts are invisible from `Properties` alone, which is why
    /// this takes the artwork's point size.
    ///
    /// Not a measurement cycle (the trap recorded in the brief's §7): `imageSize` is a property of
    /// the asset, prior to and independent of the frame this returns, and `availableCardWidth`
    /// comes from the CONTAINER, not from the content it constrains.
    ///
    /// PORTRAIT ONLY. In a height-constrained card UIKit distributes the remainder across four
    /// sub-required priority tiers and the banner takes the residual (measured ~102.3 for every
    /// real preset, regardless of ratio or cap). Nothing here reaches that, and the differential
    /// gate excludes the banner row in landscape for exactly this reason.
    ///
    /// Pinned against measured Auto Layout output in `BannerGeometryTruthTests`.
    public struct BannerGeometry: Equatable {
        /// The content column's width — `contentMaxWidth`, or wider when the artwork demands it.
        public var column: CGFloat
        /// The banner SLOT's height — the counterpart of `vwBanner`, not of the picture inside it.
        public var height: CGFloat

        public static let zero = BannerGeometry(column: 0, height: 0)
    }

    /// `imageSize` is the artwork's POINT size (`ModalImage.pointSize`), not its pixel size.
    /// `availableCardWidth` is the host width minus both card margins.
    public func bannerGeometry(imageSize: CGSize, availableCardWidth: CGFloat) -> BannerGeometry {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let ratio = bannerRatio ?? (imageSize.width / imageSize.height)
        guard ratio > 0, ratio.isFinite else { return .zero }

        let cap = bannerMaxHeight ?? .greatestFiniteMagnitude
        // The column can never exceed what is left of the card after its RIGID minimum padding —
        // UIKit's `.required` leading/trailing inequalities. The max padding is `.low` and gives
        // way, which is why the minima are what bound this.
        let ceiling = max(0, availableCardWidth - contentPadding.leftMin - contentPadding.rightMin)
        // What the artwork asks the column for: its own width, but never more than the cap allows
        // a ratio-shaped slot to be wide.
        let demand = min(imageSize.width, cap * ratio)
        let column = min(max(demand, contentMaxWidth), ceiling)
        // The smallest of: the cap, what the column allows at this ratio, and the smallest
        // ratio-shaped box containing the artwork.
        let height = min(cap, min(column / ratio, max(imageSize.height, imageSize.width / ratio)))
        return BannerGeometry(column: column, height: height)
    }
```

- [ ] **Step 4: Run it to verify it passes**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GBV3AlertModalTests/ModalBannerGeometryRuleTests 2>&1 | grep -E "\*\* TEST"
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/ModalTokens.swift \
        Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/ModalBannerGeometryRuleTests.swift
git commit -m "feat: add ModalTokens.bannerGeometry, the column and height rules as a pure function"
```

---

### Task 3: The slot/image split — `banner-comparable` goes green

The ordering bug. The aspect ratio is currently applied to the image and the width frame **outside** it, so the ratio never receives the column and settles on whatever vertical scrap the `VStack` offered — 26.8pt against UIKit's 160.

This task fixes only the case where the artwork fits inside the column, which is what the existing 160×90 fixture is. Column growth is Task 4.

**Files:**
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Core/ModalDescriptor.swift` (after `bundle`, ~line 36)
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/AlertModalScaffold.swift` (init ~line 59, `body` GeometryReader ~line 90)
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/SwiftUIAlertModal.swift:151-179`
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/ModalTokens.swift` (`bannerLayout`, ~line 721)
- Delete: `Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/ModalBannerGeometry.swift`
- Modify: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/DifferentialGeometryTests.swift:456-477`

**Interfaces:**
- Consumes: `ModalTokens.bannerGeometry(imageSize:availableCardWidth:)` and `ModalTokens.BannerGeometry` from Task 2.
- Produces:
  - `public extension ModalImage { var pointSize: CGSize }`
  - `AlertModalScaffold.init(..., bannerArtworkSize: CGSize = .zero, ...)` — added with a default, so every existing call site compiles unchanged.
  - `EnvironmentValues.modalBannerGeometry: ModalTokens.BannerGeometry` — how the banner row inside the content closure learns the geometry the scaffold computed.

- [ ] **Step 1: Write the failing test**

Replace `test_geometry_bannerComparable_agreesOnWidth_notYetOnHeight` in `DifferentialGeometryTests.swift:456-477` **entirely** with:

```swift
    /// **The banner, compared element-for-element.**
    ///
    /// This replaces an inequality pin (`swiftUI.height < uiKit.height`) that recorded the open bug
    /// rather than freezing its wrong numbers. The bug is closed: UIKit's slot is 256x160 (the
    /// artwork is 160pt wide at ratio 1, so `max(imageH, imageW/r)` is 160) and SwiftUI now
    /// computes the same from `ModalTokens.bannerGeometry`.
    ///
    /// `bannerIsUnresolvableInTheLibraryBundle` is still correct for every OTHER banner shape —
    /// their assets live in the app — so that exclusion stays. This shape sidesteps it by naming
    /// the test target's own resource bundle, which is what `ModalImage.bundleIdentifier` is for.
    func test_geometry_bannerComparable() { assertAgrees("banner-comparable") }
```

Do **not** leave the old test behind in any form. Do not relax it.

- [ ] **Step 2: Run it to verify it fails**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GBV3AlertModalTests/DifferentialGeometryTests/test_geometry_bannerComparable 2>&1 \
  | grep -E "DIFFER|banner|\*\* TEST"
```

Expected: FAIL, with the element table showing `banner` UIKit `h 160.0` against SwiftUI `h 26.8`, and `card`/`title` displaced below it.

- [ ] **Step 3: Add `ModalImage.pointSize`**

In `Core/ModalDescriptor.swift`, after the `bundle` computed property (~line 36), inside the `ModalImage` struct:

```swift
    /// **The artwork's POINT size — the operand `.resizable()` discards.**
    ///
    /// UIKit's banner slot is sized by `ivBanner`'s intrinsic content size, which is this. SwiftUI's
    /// `Image(_:bundle:).resizable()` throws it away before layout sees it, so the SwiftUI backend
    /// has to look it up to reach the same answer (`ModalTokens.bannerGeometry`).
    ///
    /// POINTS, not pixels: a 960x681 pixel asset at 3x is 320x227 points, and it is the point size
    /// the constraint sees. `UIImage` reports points, so this is already correct — but note that a
    /// preset ratio spelled `960.0/681.0` is the PIXEL ratio of that same asset.
    ///
    /// `.zero` when the asset does not resolve, which collapses the slot exactly as a zero-size
    /// `UIImage` does on the UIKit side.
    var pointSize: CGSize {
        UIImage(named: assetName, in: bundle, compatibleWith: nil)?.size ?? .zero
    }
```

If `ModalDescriptor.swift` does not already `import UIKit`, add it at the top.

- [ ] **Step 4: Publish the geometry from the scaffold**

In `AlertModalScaffold.swift`, add near the top of the file (after the imports):

```swift
/// How the banner row — which lives inside the caller's `content` closure — learns the geometry the
/// scaffold computed from its `GeometryReader`. An environment value rather than a `PreferenceKey`
/// on purpose: preferences flow UP from content, which is the measurement cycle the brief's §7
/// warns about. This flows DOWN from the container.
private struct ModalBannerGeometryKey: EnvironmentKey {
    static let defaultValue = ModalTokens.BannerGeometry.zero
}

extension EnvironmentValues {
    var modalBannerGeometry: ModalTokens.BannerGeometry {
        get { self[ModalBannerGeometryKey.self] }
        set { self[ModalBannerGeometryKey.self] = newValue }
    }
}
```

Add a stored property alongside the existing ones (near `content`, ~line 43):

```swift
    /// The banner artwork's point size, or `.zero` when this modal has no banner. Drives
    /// `ModalTokens.bannerGeometry`, which the banner row reads back out of the environment.
    public let bannerArtworkSize: CGSize
```

Add the parameter to `init` (~line 59) **with a default**, so existing call sites are untouched:

```swift
        bannerArtworkSize: CGSize = .zero,
```

and assign it in the body: `self.bannerArtworkSize = bannerArtworkSize`.

Inside `body`'s `GeometryReader`, before the `ZStack` (~line 89), compute it and inject it on the `card`:

```swift
            let bannerGeometry = tokens.bannerGeometry(
                imageSize: bannerArtworkSize,
                availableCardWidth: max(0, proxy.size.width - tokens.cardMarginH * 2)
            )
```

then change `card` (~line 96) to `card.environment(\.modalBannerGeometry, bannerGeometry)`.

Leave every `.frame(maxWidth:)` in the scaffold **unchanged** in this task — the caps move in Task 4.

- [ ] **Step 5: Pass the artwork size in from `SwiftUIAlertModal`**

Find where `SwiftUIAlertModal`'s `body` constructs `AlertModalScaffold` and add:

```swift
            bannerArtworkSize: resolved.showsBanner ? (config.image?.pointSize ?? .zero) : .zero,
```

- [ ] **Step 6: Replace the banner row**

In `SwiftUIAlertModal.swift`, replace lines 151-179 (the whole `if resolved.showsBanner` branch through `.padding(.bottom, tokens.gapBelowBanner)`) with:

```swift
            if resolved.showsBanner, let image = config.image, bannerGeometry.height > 0 {
                // UIKit models the banner as TWO views and so does this: `Color.clear` is the SLOT
                // (`vwBanner`), sized by `ModalTokens.bannerGeometry`; the image is `ivBanner`,
                // letterboxed inside it by `scaledToFit()` and imposing no size of its own.
                //
                // This used to be ONE view — `.resizable().scaledToFit()` with the aspect ratio
                // applied to the image and the width frame applied OUTSIDE it, so the ratio never
                // received the content column and settled on whatever vertical scrap the VStack
                // offered: 26.8pt against UIKit's 160.
                //
                // The frame is RIGID, knowingly. UIKit's banner yields under pressure (its drivers
                // sit below the card's `.low` 250 hugging) and this cannot. In portrait, with the
                // card free to grow, nothing is yielding and the two coincide — every row of
                // `BannerGeometryTruthTests` is such a case. In landscape they do not, which is why
                // the differential gate excludes this row there. `.frame(maxHeight:)` does not work
                // here: the height must be REACHED, not merely bounded.
                Color.clear
                    .frame(width: bannerGeometry.column, height: bannerGeometry.height)
                    .overlay {
                        // `Image(_:bundle:)` with a nil bundle IS `Image(_:)`, so the default path
                        // is unchanged — this only adds the ability to name a non-main bundle.
                        Image(image.assetName, bundle: image.bundle)
                            .resizable()
                            .scaledToFit()   // preserve the artwork's aspect (no distortion)
                    }
                    .clipped()
                    // Probed on the SLOT, the counterpart of UIKit's `vwBanner` — not of the
                    // picture inside it, and not of `vwBannerAndBelowDivider`.
                    .modalGeometryProbe(.banner)
                    .padding(.bottom, tokens.gapBelowBanner)
            }
```

Add the environment read to `SwiftUIAlertModal`'s stored properties:

```swift
    @Environment(\.modalBannerGeometry) private var bannerGeometry
```

`ModalBannerGeometryKey` is `private` to `AlertModalScaffold.swift`, but the `EnvironmentValues` extension is internal — same module, so this resolves.

- [ ] **Step 7: Drop the inert `height` and delete `ModalBannerGeometry`**

In `ModalTokens.swift`, change `bannerLayout` (~line 721) to:

```swift
    var bannerLayout: BannerLayout {
        BannerLayout(
            aspectRatio: bannerRatio,
            // `bannerFixedHeight` is NOT applied. At priority 243 it loses to the card's hugging
            // (250) going up and to the image's compression resistance (750) coming down, so UIKit
            // ignores it on BOTH paths — measured zero effect at every size tried, including
            // `fixed 200` on a 64pt image (`BannerGeometryTruthTests.test_bannerFixedHeight_*`).
            // Applying it here was a live divergence on every preset that sets both, which is all
            // of them. `ModalTokens.bannerFixedHeight` still carries the value; nothing lays out
            // with it.
            height: nil,
            maxHeight: bannerMaxHeight
        )
    }
```

Then `git rm` `SwiftUI/ModalBannerGeometry.swift` and remove any remaining `ModalBannerGeometry` references. If `ModalBannerLayoutTests.swift` asserts the old `height` behaviour, update those assertions to expect `nil` and cite the truth-table tests.

- [ ] **Step 8: Run the target test**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GBV3AlertModalTests/DifferentialGeometryTests/test_geometry_bannerComparable 2>&1 \
  | grep -E "DIFFER|\*\* TEST"
```

Expected: `** TEST SUCCEEDED **` — banner `256 x 160` on both sides.

- [ ] **Step 9: Run the whole suite**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 \
  | grep -E "error:|failed|\*\* TEST"
```

Expected: `** TEST SUCCEEDED **`. Snapshot failures for banner shapes are expected here — re-record them in Task 7, not now. If any NON-banner test fails, stop: the environment/scaffold plumbing has leaked.

- [ ] **Step 10: Commit**

```bash
git add -A Library/GBV3AlertModal
git commit -m "fix: give the SwiftUI banner a slot, so the ratio sees the content column

The aspect ratio was applied to the image and the width frame outside it,
so the ratio never received the column and settled on whatever vertical
scrap the VStack offered: 26.8pt against UIKit's 160. Mirror UIKit's
vwBanner/ivBanner split and size the slot from ModalTokens.bannerGeometry.

Drops bannerFixedHeight from the layout: measured inert in UIKit on both
paths, and applying it here diverged on every preset that sets it."
```

---

### Task 4: Let the column grow — the wide-artwork case

Eight of the app's nine banner assets are wider than the 256pt column. UIKit lets them push it (`ivBanner`'s 750 compression resistance outranks the column's `width == fixedWidth` at `.medium` 500); SwiftUI's column is pinned by `.frame(maxWidth: contentMaxWidth)`. Measured cost: card 30pt narrow, banner 54-72pt tall, on every real banner dialog.

**This is the riskiest change in the plan** — it touches the ladder every element's width flows through. Step 1 proves it inert before anything moves.

**Files:**
- Create: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Resources/GBTestAssets.xcassets/gb_test_banner_wide.imageset/`
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/AlertModalScaffold.swift:101` (card cap) and `:219-220` (content cap)
- Modify: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/DifferentialGeometrySupport.swift` (new shape)
- Modify: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/DifferentialGeometryTests.swift` (new tests)

**Interfaces:**
- Consumes: `EnvironmentValues.modalBannerGeometry` and `AlertModalScaffold.bannerArtworkSize` from Task 3.
- Produces: differential shape `"banner-wide"` — a 320×190 asset under `popupProperties().copy(bannerRatio: 320.0/190.0, bannerMaxHeight: 256)`. Expected on both sides: card 350, column 310, banner height 184.06.

- [ ] **Step 1: Prove the change is inert without a banner — BEFORE changing anything**

Record the current full-suite result as the baseline:

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 \
  | grep -E "Executed .* tests" | tail -3
```

Write the count down. Every non-banner test must still pass at Step 8 with the same count. `bannerGeometry` returns `.zero` when `bannerArtworkSize` is `.zero`, so the `max(...)` in Step 5 is the identity for every shape without a banner — this step is what proves that claim rather than asserting it.

- [ ] **Step 2: Create the wide test asset**

```bash
cd Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Resources/GBTestAssets.xcassets
mkdir -p gb_test_banner_wide.imageset
sips -z 190 320 gb_test_banner.imageset/gb_test_banner.png \
     --out gb_test_banner_wide.imageset/gb_test_banner_wide.png
sed 's/gb_test_banner\.png/gb_test_banner_wide.png/' \
    gb_test_banner.imageset/Contents.json > gb_test_banner_wide.imageset/Contents.json
cd -
```

320×190 at 1x, matching the real `img_gc2gs_prompt_1/2/4` assets. Verify: `sips -g pixelWidth -g pixelHeight gb_test_banner_wide.imageset/gb_test_banner_wide.png` reports 320 and 190.

- [ ] **Step 3: Add the shape**

In `DifferentialGeometrySupport.swift`, after the `banner-comparable` shape, add:

```swift
            /// **The banner shape whose artwork is WIDER than the content column.**
            ///
            /// Eight of the app's nine real banner assets are (`img_gc2gs_prompt_*` at 320x190pt is
            /// this one, verbatim). UIKit lets the artwork push the column past `contentMaxWidth` —
            /// `ivBanner`'s compression resistance (750) outranks `width == fixedWidth` at
            /// `.medium` (500) — and before this shape existed nothing on the SwiftUI side could
            /// see that. Measured cost when it was missed: card 30pt narrow, banner 72pt tall.
            ///
            /// Expected on both sides: card 350, column 310, banner height 184.06.
            Shape(
                name: "banner-wide",
                dialog: AlertDialog(
                    image: ModalImage(
                        "gb_test_banner_wide", bundleIdentifier: Bundle.module.bundleIdentifier
                    ),
                    title: "Heads up",
                    subtitle: "A banner wider than the column it sits in.",
                    primary: "Okay"
                ),
                properties: GeniePresets.popupProperties()
                    .copy(bannerRatio: 320.0 / 190.0, bannerMaxHeight: 256)
            ),
```

- [ ] **Step 4: Write the failing tests**

In `DifferentialGeometryTests.swift`, beside `test_geometry_bannerComparable`:

```swift
    /// The wide-artwork case — see the shape's note. This is the regime every real app banner is in.
    func test_geometry_bannerWide() { assertAgrees("banner-wide") }

    /// The premise: this shape must actually be in the wider-than-column regime, or it is just
    /// `banner-comparable` with a different asset and proves nothing.
    func test_bannerWide_actuallyExceedsTheColumn() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-wide"))
        let artwork = try XCTUnwrap(shape.dialog.image).pointSize
        let column = try XCTUnwrap(shape.properties.contentProperty?.maxWidthPortrait)
        XCTAssertGreaterThan(
            artwork.width, column,
            "'banner-wide' artwork (\(artwork.width)pt) no longer exceeds the column (\(column)pt), "
                + "so this shape has stopped testing column growth"
        )
        let frames = DifferentialGeometry.uiKitFrames(shape)
        let banner = try XCTUnwrap(frames[.banner])
        XCTAssertGreaterThan(
            banner.width, column,
            "UIKit stopped widening the column for wide artwork — the rule in "
                + "ModalTokens.bannerGeometry is now wrong, not just this shape"
        )
    }
```

- [ ] **Step 5: Run to verify they fail**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GBV3AlertModalTests/DifferentialGeometryTests/test_geometry_bannerWide 2>&1 \
  | grep -E "DIFFER|card|banner|\*\* TEST"
```

Expected: FAIL — UIKit `card 350 / banner 310 x 184.0` against SwiftUI `card 320 / banner 256 x ...`.

- [ ] **Step 6: Grow the content cap**

In `AlertModalScaffold.swift`, replace line 220 (`.frame(maxWidth: tokens.contentMaxWidth)`) with:

```swift
        // The stated cap, or the banner's column when the artwork demands a wider one. UIKit has no
        // separate mechanism for this: `ivBanner`'s compression resistance (750) simply outranks
        // `svContentContainer`'s `width == fixedWidth` at `.medium` (500), so a wide banner widens
        // the column. `bannerGeometry` is `.zero` with no banner, so `max` is the identity for
        // every shape that has none.
        .frame(maxWidth: max(tokens.contentMaxWidth, bannerGeometry.column))
```

`card` is a computed property on the scaffold, so it needs the value in scope. Add to `AlertModalScaffold`'s stored properties:

```swift
    @Environment(\.modalBannerGeometry) private var bannerGeometry
```

**This will not work as written** — the scaffold is what *sets* that environment value, and a view cannot read an environment value it set on its own subtree. Instead, hoist the computation: make `card` a function taking the geometry, `private func card(bannerGeometry: ModalTokens.BannerGeometry) -> some View`, and pass the value computed in `body`'s `GeometryReader` (Task 3, Step 4) into it. Keep the `.environment(...)` injection as well — the banner row inside the caller's `content` closure still needs it.

- [ ] **Step 7: Grow the card cap**

Replace line 101 (`.frame(maxWidth: tokens.cardMaxWidth)`) with:

```swift
                // `cardMaxWidth` is `contentMaxWidth + leftMax + rightMax`. When the banner has
                // widened the column, the card must widen with it — UIKit's `vwContainer` has NO
                // width constraint at all, only the margin inequalities, so it takes whatever the
                // content plus its `.low` max padding asks for, bounded by the margins. Measured:
                // a 320pt asset in a 256pt column produces a 350pt card, not a 320pt one.
                .frame(maxWidth: max(
                    tokens.cardMaxWidth,
                    bannerGeometry.column + tokens.contentPadding.leftMax + tokens.contentPadding.rightMax
                ))
```

The outer `.frame(maxHeight:)`/`.padding(.horizontal, tokens.cardMarginH)` at lines 127-130 already bound this to the margins, which is what clamps 359 down to the measured 350.

- [ ] **Step 8: Run the wide test, then the whole suite**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GBV3AlertModalTests/DifferentialGeometryTests 2>&1 | grep -E "DIFFER|\*\* TEST"
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 \
  | grep -E "error:|failed|Executed .* tests|\*\* TEST"
```

Expected: both banner tests pass; the executed-test count matches Step 1's baseline plus the new tests; no non-banner test regressed. Snapshot diffs on banner shapes are expected — Task 7.

- [ ] **Step 9: Commit**

```bash
git add -A Library/GBV3AlertModal
git commit -m "fix: let banner artwork widen the SwiftUI column, as it does in UIKit

ivBanner's compression resistance (750) outranks the content column's
width == fixedWidth at .medium (500), so wide artwork widens the column
and the card. Eight of the app's nine banner assets are in that regime;
SwiftUI's column was pinned, costing 30pt of card and up to 72pt of
banner height on every real banner dialog."
```

---

### Task 5: Landscape — gate everything except the banner row

In a height-constrained card UIKit distributes the remainder across four sub-required priority tiers and the banner takes the residual: measured 102.3 for every real preset regardless of ratio or cap, against SwiftUI's 184.0. No closed form reaches it, and Task 3's rigid frame cannot yield at all. The exception must be typed so it shows up in failure output rather than rotting into an unexplained skip.

**Files:**
- Modify: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/DifferentialGeometryTests.swift:552-582` (`assertAgrees`)

**Interfaces:**
- Consumes: `DifferentialGeometry.rows(for:size:)`, `ModalGeometryElement` — existing.
- Produces: `assertAgrees(_:size:excluding:because:file:line:)`. `excluding` defaults to `[]` and `because` to `""`, so every existing call site compiles unchanged.

- [ ] **Step 1: Write the failing test**

Add to `DifferentialGeometryTests.swift`:

```swift
    /// **Landscape, with the banner row excluded and the reason stated.**
    ///
    /// Every other element agrees. The banner's HEIGHT does not and is not expected to: in a
    /// height-constrained card UIKit distributes the remainder across four sub-required priority
    /// tiers and the banner takes the residual (measured 102.3 for every real preset, regardless of
    /// ratio or cap, against SwiftUI's 184.0). `ModalTokens.bannerGeometry` is a PORTRAIT rule and
    /// says so; reaching 102.3 means reimplementing residual distribution.
    ///
    /// This is an exclusion, not a widened tolerance. `DifferentialGeometry.tolerance` stays 0.5pt.
    func test_geometry_bannerWide_landscape() {
        assertAgrees(
            "banner-wide",
            size: DifferentialGeometry.landscapeHost,
            excluding: [.banner],
            because: "the banner's landscape height is Auto Layout residual arbitration, not a "
                + "closed form — see ModalTokens.bannerGeometry's doc and the design spec §5"
        )
    }

    /// The excluded row must still EXIST on both sides. Without this, `excluding: [.banner]` would
    /// also pass for a shape that drew no banner at all — agreement about an absence, which is the
    /// vacuous-pass failure mode this suite exists to prevent.
    func test_bannerWide_landscape_stillDrawsABannerOnBothSides() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-wide"))
        let rows = DifferentialGeometry.rows(for: shape, size: DifferentialGeometry.landscapeHost)
        let banner = try XCTUnwrap(rows.first { $0.element == .banner })
        XCTAssertNotNil(banner.uiKit, "UIKit drew no banner in landscape")
        XCTAssertNotNil(banner.swiftUI, "SwiftUI drew no banner in landscape")
        XCTAssertGreaterThan(try XCTUnwrap(banner.swiftUI).height, 0)
        XCTAssertGreaterThan(try XCTUnwrap(banner.uiKit).height, 0)
    }
```

- [ ] **Step 2: Run it to verify it fails**

Expected: compile error — `extra arguments 'excluding', 'because'`.

- [ ] **Step 3: Extend `assertAgrees`**

Replace its signature and add the filter. The exclusion must appear in the failure table, not be silently dropped:

```swift
    private func assertAgrees(
        _ name: String,
        size: CGSize = DifferentialGeometry.host,
        excluding: Set<ModalGeometryElement> = [],
        because reason: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let shape = DifferentialGeometry.shape(named: name) else {
            XCTFail("no differential shape named '\(name)'", file: file, line: line)
            return
        }
        if !excluding.isEmpty {
            XCTAssertFalse(
                reason.isEmpty,
                "'\(name)': excluding \(excluding) without a stated reason. An unexplained "
                    + "exclusion is how a gate rots — pass `because:`.",
                file: file, line: line
            )
        }
        let allRows = DifferentialGeometry.rows(for: shape, size: size)
        let orientation = size.width > size.height ? "landscape" : "portrait"
        var title = "\(name) [\(orientation)]"
        if !excluding.isEmpty {
            title += " — EXCLUDING \(excluding.map(String.init(describing:)).sorted().joined(separator: ", ")): \(reason)"
        }
        let table = DifferentialGeometry.table(name: title, rows: allRows)

        // Honesty first: an empty measurement must never read as agreement. Checked on ALL rows,
        // including excluded ones — an exclusion suppresses a comparison, not a measurement.
        guard allRows.contains(where: { $0.uiKit != nil }), allRows.contains(where: { $0.swiftUI != nil }) else {
            XCTFail(
                "'\(name)': one side measured nothing, so there is no comparison to report.\n" + table,
                file: file, line: line
            )
            return
        }

        let rows = allRows.filter { !excluding.contains($0.element) }
        let disagreements = rows.filter { $0.verdict.isDisagreement }
        let comparable = rows.filter { $0.verdict != .absentOnBoth }
        XCTAssertTrue(
            disagreements.isEmpty,
            "\(disagreements.count) of \(comparable.count) comparable elements DIFFER.\n" + table,
            file: file, line: line
        )
    }
```

If `ModalGeometryElement` is not `Hashable`, add the conformance — it is a simple enum.

- [ ] **Step 4: Run to verify it passes**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GBV3AlertModalTests/DifferentialGeometryTests 2>&1 | grep -E "DIFFER|\*\* TEST"
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/DifferentialGeometryTests.swift
git commit -m "test: gate the banner in landscape by exclusion, with a required reason"
```

---

### Task 6: Correct the stale comments

Three files cite priorities that no longer exist. `GBAlertModal+ViewGraph.swift` says 700/749/249 where `ModalLayout.Priority` actually holds 245/243/241; the deleted `ModalBannerGeometry.swift` said "751 wins over 251". Comments only — **no behaviour changes**, UIKit is frozen.

**Files:**
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/GBAlertModal+ViewGraph.swift:353-372`
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Support/ModalLayout.swift:~350-357`
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/ModalTokens.swift` (the `bannerLayout` precedence doc, ~line 690-720)
- Modify: `docs/superpowers/specs/2026-08-02-swiftui-banner-height.md:44-68`

**Interfaces:** none. Documentation only.

- [ ] **Step 1: Fix the ViewGraph comment block**

In the `vwBanner` constraint block (~line 353), every occurrence of `700` describing `bannerNaturalAspect` becomes `245`, `749` becomes the actual `subtitleSlotHeight` value, and `249` describing `bannerImageIntrinsic` becomes `241`. Read the current values from `ModalLayout.Priority` and quote them. Add one line recording why the drift is dangerous:

```swift
                // Every rung named here lives in `ModalLayout.Priority` and is pinned by
                // `BannerGeometryTruthTests` — these numbers drifted from the constants once
                // already, and only a comment showed it.
```

- [ ] **Step 2: Fix the `ModalLayout.Priority` doc**

The doc above `enum Priority` says "after the subtitle slot (250/749), after the banner (700) and after the banner image (249)". Correct to the real values.

- [ ] **Step 3: Correct the brief's §3**

Prepend to `docs/superpowers/specs/2026-08-02-swiftui-banner-height.md`:

```markdown
> **§3 of this brief is WRONG and is superseded by
> `2026-08-02-swiftui-banner-height-design.md`.** It omits the term that actually produces the
> headline 160 — the artwork's intrinsic point size — and states that `bannerFixedHeight` sizes the
> slot on the `bannerRatio != nil` path. Measured: `bannerFixedHeight` is inert on BOTH paths at
> every size tried. §1, §4, §5 and §7 still hold.
```

- [ ] **Step 4: Verify nothing moved**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 \
  | grep -E "error:|failed|\*\* TEST"
```

Expected: identical to Task 5's result. A comment-only change that moves a test means something was edited that should not have been.

- [ ] **Step 5: Commit**

```bash
git add -A Library docs
git commit -m "docs: correct three stale priority citations and the brief's wrong §3"
```

---

### Task 7: Re-record snapshots and update the catalog caption

Banner shapes move — that is the point. They must be **looked at**, not blind-accepted.

**Files:**
- Modify: snapshot references under `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/__Snapshots__/` and `Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/__Snapshots__/`
- Modify: `Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/SwiftUICatalog.swift:103-106`

**Interfaces:** none.

- [ ] **Step 1: Find every failing snapshot**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 \
  | grep -E "failed - Snapshot|@—" | sort -u
```

- [ ] **Step 2: Re-record**

Set `isRecording = true` (or `withSnapshotTesting(record: .all)`) in the affected suites, run, then set it back. Never leave recording enabled — a suite in record mode passes unconditionally.

- [ ] **Step 3: LOOK at each changed image**

```bash
git diff --stat -- '*__Snapshots__*'
```

Open each changed PNG. Confirm for every one: the banner is not stretched or cropped, it is horizontally centred in the card, and the title sits directly below it with the expected gap. A banner that is the right *size* but drawn in the wrong *place* passes the geometry gate — the gate probes the slot, not the picture.

- [ ] **Step 4: Update the catalog caption**

Replace `bannerArtworkNote` (`SwiftUICatalog.swift:103-106`) with:

```swift
    static let bannerArtworkNote = SwiftUIDivergence(
        caption: "Banner geometry is GATED, not eyeballed: the slot's column and height come from "
            + "ModalTokens.bannerGeometry, pinned against measured UIKit output in "
            + "BannerGeometryTruthTests and compared element-for-element in DifferentialGeometryTests "
            + "(portrait). Landscape banner height is excluded and still differs — see the design spec §5."
    )
```

- [ ] **Step 5: Full suite, both schemes**

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 \
  | grep -E "error:|failed|Executed .* tests|\*\* TEST"
```

Then the example scheme, as the repo's own convention requires. Expected: both green.

- [ ] **Step 6: Commit**

```bash
git add -A Library Examples
git commit -m "test: re-record banner snapshots and mark the catalog caption as gated"
```

---

## Self-Review

**Spec coverage:**

| spec section | task |
|---|---|
| §4.1 `bannerLayout` takes artwork size | 2 (as `bannerGeometry`) |
| §4.2 column becomes `max(contentMaxWidth, demand)` | 4 |
| §4.3 slot/image split | 3 |
| §4.4 delete `height` from `BannerLayout` | 3, Step 7 |
| §4.5 re-cut the asset | 4, Step 2 (as a *new* asset; see the deviation below) |
| §5 landscape exclusion | 5 |
| §6 stale comments | 6 |
| §7.1 truth table | 1 |
| §7.2 `assertAgrees("banner-comparable")` | 3, Step 1 |
| §7.3 premise test unchanged | untouched, verified in 3 Step 9 |
| §7.4 three paths + fits-column case | 1 (UIKit side), 3 + 4 (differential) |
| §7.5 non-banner inertness sweep | 4, Steps 1 and 8 |
| §7.6 landscape bound | 5 |
| §7.7 zero-artwork | 1 (`test_zeroSizeArtwork_collapsesTheSlot`); SwiftUI side guarded by `bannerGeometry.height > 0` in 3 |
| §7.8 `BannerAspectStressTests` untouched | verified green in 3 Step 9 |
| §7.9 snapshots + caption | 7 |

**Deliberate deviation from the spec:** §4.5 says re-cut `gb_test_banner` to 320×190 and repoint `banner-comparable`. This plan **adds** `gb_test_banner_wide` instead and leaves `gb_test_banner` at 160×90. Reason: the existing 160×90 fixture already exercises the artwork-fits-the-column regime (UIKit measured 256×160), which is the only real regime `img_badge_multi_achievement` is in — so keeping it buys a second covered regime for free, and lets Task 3 land a green gate before Task 4 touches the width ladder. Both regimes end up gated.

**Placeholder scan:** no TBD/TODO; every code step carries the actual code. Task 4 Step 6 deliberately states an approach that does *not* compile and gives the fix — that is a known SwiftUI trap (a view cannot read an environment value it set on its own subtree), and naming it is cheaper than an implementer rediscovering it.

**Type consistency:** `bannerGeometry(imageSize:availableCardWidth:)` uses the same labels in Tasks 2, 3, 4. `ModalTokens.BannerGeometry` with `.column`/`.height`/`.zero` is used consistently. `ModalImage.pointSize` is defined in Task 3 Step 3 and used in Task 3 Step 5 and Task 4 Step 4. `EnvironmentValues.modalBannerGeometry` is defined in Task 3 Step 4 and read in Task 3 Step 6; Task 4 Step 6 flags that the scaffold itself must take it as a parameter instead.

**Known-uncertain, flagged rather than hidden:** Task 1 Step 2 anticipates that `Properties`' optionality may not match what the test assumes, and says to fix the accessors rather than the rules. Task 3's `@Environment` read inside `SwiftUIAlertModal` assumes the internal `EnvironmentValues` extension is visible module-wide — it is, but if the build disagrees, promote the key to internal rather than making it public.
