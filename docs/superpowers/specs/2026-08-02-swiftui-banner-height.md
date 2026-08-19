# Brief — SwiftUI banner height

> **§3 of this brief is WRONG and is superseded by
> `2026-08-02-swiftui-banner-height-design.md`.** It omits the term that actually produces the
> headline 160 — the artwork's intrinsic point size — and states that `bannerFixedHeight` sizes the
> slot on the `bannerRatio != nil` path. Measured: `bannerFixedHeight` is inert on BOTH paths at
> every size tried. §1, §4, §5 and §7 still hold.

**Status:** open. Width fixed (`4ee0b23`), height not.
**Blocks:** adopting any banner-carrying SwiftUI dialog in the app.
**Branch:** `feat/modal-executor-capability`. Library 469 tests green, example green.

---

## 1. The bug, in numbers

The differential gate's `banner-comparable` shape, portrait, `GeniePresets.standardProperties()`
(`bannerRatio: 1`, no fixed height, no cap), 160×90 source image:

```
element | UIKit (measured)               | SwiftUI (computed)
card    | w 320.0 h 355.0                | w 320.0 h 285.0
banner  | x 32.0 y 24.0 w 256.0 h 160.0  | x 32.0 y 24.0 w 256.0 h  26.8
title   | x 32.0 y 192.0                 | x 32.0 y 100.0
```

`x` and `width` agree (that was the width fix). **Height does not: 160 vs 26.8.** Everything below
the banner is displaced by the difference, so the card is 70pt short.

This was wrong in **every banner shape the SwiftUI backend has ever rendered**. Nothing caught it
because no banner asset resolved in the library test bundle until `ModalImage.bundleIdentifier`
existed.

## 2. Why the two disagree

**UIKit models the banner as TWO views** (`GBAlertModal+ViewGraph.swift`, `installConstraints`):

- `vwBanner` — the SLOT. Fills the content column (256). Its height is driven by the constraints in
  §3 below.
- `ivBanner` — the IMAGE, inside the slot, with `contentMode = .scaleAspectFit` and (on the
  `bannerRatio != nil` path) `width == height * ratio`. Its own vertical compression resistance is
  dropped to `bannerImageIntrinsic` so raw pixel height cannot fight the text.

So the slot's height comes from a constraint, and the picture letterboxes inside it.

**SwiftUI has ONE view**: `Image(name, bundle:).resizable().scaledToFit()` +
`ModalBannerGeometry` + `ContentRowWidth` (`SwiftUIAlertModal.swift`, the banner row). An outer
width frame does not make a `scaledToFit` image grow vertically, so it settles at its own small
intrinsic-ish size. **The fix is to give SwiftUI the same slot/image split.**

## 3. The precedence to reproduce — read off UIKit, do not guess

On `vwBanner`, at most three constraints, from `ModalLayout.Priority`:

| constraint | priority | when |
|---|---|---|
| `height <= bannerMaxHeight` | **950** | `bannerMaxHeight` set |
| `height == width * (imageH/imageW)` | **245** | `bannerRatio == nil` **and** image has usable size |
| `height == bannerFixedHeight` | **243** | `bannerFixedHeight` set |

Consequences, already reasoned in `ModalTokens.BannerLayout`'s doc comment:

1. The cap (950) outranks everything and always applies when present.
2. `bannerRatio == nil` → natural-aspect (245) beats fixed height (243), so **`bannerFixedHeight` is
   inert on the natural-aspect path**.
3. `bannerRatio != nil` → no natural-aspect driver, so fixed height (243) sizes the slot.
4. **All three drivers sit BELOW the card's `.low` (250) hugging.** Deliberate — "banner never be a
   winner, it is just cosmetic, not information". Where the card can hug tighter than the banner
   wants to be tall, the banner yields. `BannerAspectStressTests.test_banner9x16_uncapped_portrait`
   encodes this: the natural aspect is a **ceiling**, not an entitlement.

Point 4 is the subtle one. A naive "make SwiftUI's banner as tall as the ratio says" will diverge
from UIKit on any card that is hugging.

## 4. Where the code is

| what | where |
|---|---|
| SwiftUI banner row | `SwiftUI/SwiftUIAlertModal.swift` — the `resolved.showsBanner` branch |
| SwiftUI geometry modifier | `SwiftUI/ModalBannerGeometry.swift` — `shape` / `pin` / `cap`, applied to one view |
| Token | `SwiftUI/ModalTokens.swift` — `BannerLayout` + its precedence doc |
| UIKit truth | `GBAlertModal+ViewGraph.swift` — `installConstraints`, `vwBanner` / `ivBanner` blocks |
| Priorities | `Support/ModalLayout.swift` — `Priority` |

## 5. How to verify

The gate exists and already measures this. Run:

```
xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:GBV3AlertModalTests/DifferentialGeometryTests
```

- `test_geometry_bannerComparable_agreesOnWidth_notYetOnHeight` — **pinned as an inequality**
  (`swiftUI.height < uiKit.height`). When the fix lands this test **fails**, on purpose. Replace it
  with `assertAgrees("banner-comparable")` and delete the exception; do not relax the inequality.
- `test_theBannerRow_actuallyMeasuresABanner` — the premise. A banner row over an unresolvable asset
  reads `absent (both)` and PASSES; this stops that.
- `BannerAspectStressTests` — 8 shapes across 16:9 / 9:16 / 1:1, capped and uncapped, portrait and
  landscape. These are UIKit-side and must stay green.

Add landscape coverage for the banner shape once portrait agrees
(`assertAgrees("banner-comparable", size: DifferentialGeometry.landscapeHost)`).

## 6. Definition of done

1. `banner-comparable` agrees element-for-element, portrait **and** landscape, at 0.5pt.
2. The inequality pin is **deleted**, not loosened.
3. All three paths are covered by a shape: `bannerRatio` set, `bannerRatio == nil` (natural aspect),
   and `bannerMaxHeight` capping each.
4. Example snapshots re-recorded and **looked at** — banner shapes will move.
5. `SwiftUICatalog`'s `bannerArtworkNote` caption updated to say the geometry is gated, not eyeballed.

## 7. Traps this codebase has already sprung — read before starting

These cost real time in the sessions that produced the surrounding work:

- **A vacuous pass looks identical to a real one.** A differential row where both sides measure
  nothing reports agreement. Every new shape needs a premise test proving it exercises what it
  claims (`test_theScrollingShape_actuallyScrolls` caught a shape whose scroll never engaged; the
  banner premise test caught a resolution helper that ignored the bundle).
- **Do not widen `DifferentialGeometry.tolerance`.** It is 0.5pt, deliberately not per-shape.
- **Beware measurement cycles.** Deriving a size from a measurement that the size then feeds back
  into produces a settled-but-arbitrary layout. This already had to be removed once, from a banner
  ceiling derived from the scroll viewport it was meant to bound. If the slot's height is measured,
  measure it from the CONTAINER, not from the content it constrains.
- **`.frame(height:)` is rigid; `.frame(maxHeight:)` is flexible.** A fixed frame does not become
  compressible by being given a low layout priority — that mistake shipped once and the test caught it.
- **A `ScrollView`'s multi-view content gets an implicit stack with default 8pt spacing.** Cost an
  8pt shift on all eight shapes before an explicit `VStack(spacing: 0)` was added.
- **Read what UIKit does before theorising about SwiftUI.** Four consecutive wrong diagnoses in one
  session were all fixed by opening the UIKit source instead of guessing — including one where the
  symptom came from a test fixture, not the layout at all (`resolve` gates each button on BOTH its
  title and its `ActionStyle`; a bare `Properties` silently drops the secondary button).

## 8. Out of scope

- UIKit is **frozen**. The production app consumes this module as an SPM dependency
  (`Tuist/Package.swift` pins it), so its UIKit half is the shipping dialog. Fix SwiftUI to match
  UIKit, never the reverse.
- `badgeBannerMissing` — a runtime `UIImage` still cannot be expressed; `ModalImage` carries an asset
  name and optional bundle identifier because it must stay `Sendable`. Separate decision.
- The vertical margin divergence from the app's preset is deliberate ("keep margin different we
  fought this for 2 days").
