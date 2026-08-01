# Design — SwiftUI banner height

**Supersedes the diagnosis in** `2026-08-02-swiftui-banner-height.md`. That brief's §3 is wrong; see
§2 below. Its §1, §4, §5 and §7 still hold.

**Status:** designed, not implemented. **Branch:** `feat/modal-executor-capability`.

---

## 1. The bug is an ordering bug, not a missing model

`SwiftUIAlertModal.swift:154-167`:

```swift
Image(image.assetName, bundle: image.bundle)
    .resizable().scaledToFit()
    .modifier(ModalBannerGeometry(layout: tokens.bannerLayout))   // .aspectRatio(ratio, .fit)
    .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))  // .frame(maxWidth: .infinity)
```

The aspect ratio is applied to the image; the width frame is applied **outside** it. So the ratio
never receives the content column as its proposal — it settles on whatever vertical scrap the
enclosing `VStack` offered. The outer frame then reports 256pt of width around a 26.8pt-tall image.

The fix is to swap the two: fill the width first, let the ratio derive the height from it.

## 2. Measured UIKit behaviour — the brief's §3 was incomplete

Probes run against the real `GBAlertModal` on iPhone 17, portrait 390×844. `standardProperties()`
unless stated.

| ratio | artwork | slot | image frame |
|---|---|---|---|
| 1 | 160×90 | 256×**160** | 160×160 |
| 1 | 90×160 | 256×**160** | 160×160 |
| 1 | 64×64 | 256×**64** | 64×64 |
| 1 | 300×300 | **300**×300 | card grew to 350 |
| 1 | 340×340 | **318**×318 | card at its cap |
| 16:9 | 160×90 | 256×**90** | 160×90 |
| 9:16 | 90×160 | 256×**160** | 90×160 |
| nil | 160×90 | 256×**90** | 256×90 |
| nil | 400×225 | **305.7**×172 | card grew |
| 1 | 160×90, cap 40 | 256×**40** | 40×40 |
| 1 | 64×64, **fixed 200** | 256×**64** | no effect |
| nil | 64×64, **fixed 200** | 256×**64** | no effect |
| 1 | 0×0 | 0×0 | card 187 |

Real presets, artwork at production sizes:

| preset | ratio / cap | slot | `min(column/ratio, cap)` |
|---|---|---|---|
| `errorBanner` | 295:256 / 320 | 295×256.0 | 256.0 ✅ |
| `forceUpdate` | 1:1 / 320 | 310×310.0 | 310.0 ✅ |
| `capBanner` | 320:197 / 216 | 310×190.7 | 190.8 ✅ |
| `quizBanner` | 320:229 / 216 | 302×216.0 | 216.0 ✅ |
| `aiNotes` | 960:681 / 320 | 310×220.0 | 219.9 ✅ |
| `streak` | 200:168 / 168 | 256×168.0 | 168.0 ✅ |

**One rule fits every portrait row.** With `r = bannerRatio ?? imageW/imageH`:

```
slotHeight = min( bannerMaxHeight ?? ∞,
                  column / r,                      // the ratio, driven by the column
                  max(imageH, imageW / r) )        // the artwork's own intrinsic size
```

Three corrections to the brief's §3:

1. **It never mentions the artwork's intrinsic size**, which is what produces the 160 in the
   headline case. `max(imageH, imageW/r)` is the smallest ratio-shaped box containing the artwork's
   point size, held there by `UIImageView`'s default compression resistance (750).
2. **`bannerFixedHeight` is inert.** Measured zero effect on both paths, at every size tried,
   including `fixed 200` on a 64pt image. At priority 243 it loses to hugging (250) going up and to
   compression resistance (750) going down. Every shipping preset also sets
   `bannerMaxHeight == bannerFixedHeight`, or pairs 256 with a 320 cap that binds first.
3. **The column is not fixed.** Artwork wider than `contentMaxWidth` pushes it — the image's 750
   outranks `width == fixedWidth` at `.medium` (500). A 320pt asset moved the column 256 → 302 and
   the card 320 → 350.

## 3. The SwiftUI column IS pinned — verified

`AlertModalScaffold.swift:158` — `.frame(maxWidth: .infinity).frame(maxWidth: contentMaxWidth)`.
Greedy fill, then cap. SwiftUI's column is always `contentMaxWidth` and nothing can widen it.

Both backends, same shape, portrait:

| | UIKit card / banner | SwiftUI card / banner |
|---|---|---|
| `quizBanner` + 320×229 | 350 / **302**×216.0 | 320 / **256**×216.0 |
| `quizBanner` + 160×90 | 320 / 256×**114.3** | 320 / 256×**216.0** |
| `standard` + 320×229 | 350 / 291.3×**291.3** | 320 / 256×**52.2** |
| `standard` + 160×90 | 320 / 256×**160.0** | 320 / 256×**26.8** |

## 4. The design

Compute nothing. Give SwiftUI the same two-term rule the column already implies, and constrain the
artwork so the third term cannot bind.

**4.1 — Reorder the banner row.** Width inside, ratio outside, and introduce the slot:

```swift
Color.clear                                                       // the SLOT — vwBanner
    .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))
    .modifier(ModalBannerGeometry(layout: tokens.bannerLayout))
    .overlay { Image(image.assetName, bundle: image.bundle).resizable().scaledToFit() }
    .modalGeometryProbe(.banner)
    .padding(.bottom, tokens.gapBelowBanner)
```

`Color.clear` is the counterpart of `vwBanner`; the image is the counterpart of `ivBanner`,
letterboxed by `scaledToFit()` and imposing no size of its own. This is UIKit's two-view split,
expressed structurally rather than arithmetically.

**This exact modifier arrangement is a hypothesis, and it is the first thing to test.**
`.aspectRatio(_:contentMode:.fit)` fits within the proposal in **both** axes, and a `VStack` does
not promise a generous height proposal to a flexible child — that is precisely the mechanism that
produced 26.8pt. If the arrangement above under-sizes, the fallback is to measure the CONTAINER's
width with a `GeometryReader` and set the slot height from it. §7 of the brief permits this
explicitly ("measure it from the CONTAINER, not from the content it constrains") — but it is the
second choice, because the height it produces is rigid.

**Task 1 is a spike**: build both, measure both against §2's rule, keep the one that agrees. Do not
proceed to §4.3 or §4.4 until this is settled — everything downstream assumes the slot reaches
`column / r`.

**4.2 — The cap stays a ceiling.** `ModalBannerGeometry.cap` already uses `.frame(maxHeight:)`.
Do not change it to `.frame(height:)`; §7 of the brief records that mistake shipping once.

**4.3 — Delete `height` from `BannerLayout`.** It is inert in UIKit (§2.2) and currently applied in
SwiftUI on the ratio path (`ModalTokens.swift:724`) — a live divergence on every preset that sets
both, which is all of them. `ModalTokens.bannerFixedHeight` keeps carrying the value; only
`bannerLayout` stops using it.

**4.4 — The artwork invariant.** The intrinsic term is dominated, and the column stays put, iff:

```
imageW ≤ contentMaxWidth            // else UIKit's column grows and SwiftUI cannot follow
imageH ≥ contentMaxWidth / ratio    // else the artwork's own size binds below the ratio
```

Re-cut `gb_test_banner` to **256×256 at 1x**. `banner-comparable` keeps `standardProperties()`
(ratio 1, no cap, column 256), so both terms are 256 and both backends land on 256 — the two
inequalities hold as equalities, which is the widest margin for error this shape can have.

Two further shapes give DoD item 3 its three paths, both reusing the same asset:

| shape | properties | expected height |
|---|---|---|
| `banner-comparable` | `standardProperties()` — ratio 1, no cap | 256 |
| `banner-capped` | `.copy(bannerMaxHeight: 144)` | 144 |
| `banner-natural` | `standardPropertiesNilBannerRatio()` — `r = 256/256 = 1` | 256 |

**4.5 — The real app artwork violates 4.4, and this design does not fix that.**

Measured from `Geniebook/Assets.xcassets` (point sizes, not pixels — `aiNotes`' `960.0/681.0` is the
3× pixel ratio of a **320×227pt** asset):

| asset | point size | preset column | pushes? |
|---|---|---|---|
| `img_database_error` | 295×256 | 256 | **yes**, 295 > 256 |
| `img_illust_ai_notes_banner` | 320×227 | 256 | **yes**, 320 > 256 |

`popupProperties` inherits `standardProperties`' 256pt column — the 300 belongs to
`badgeProperties` alone. So every shipping banner asset is wider than the column it sits in, and
UIKit's card grows to absorb it. Both backends, real point sizes, portrait:

| shape | UIKit card / col / banner h | SwiftUI card / col / banner h | Δcard |
|---|---|---|---|
| `errorBanner` + 295×256 | **350** / 295 / 256.0 | 320 / 256 / 320.0 | −30 |
| `aiNotes` + 320×227 | **350** / 310 / 220.0 | 320 / 256 / 320.0 | −30 |
| `errorBanner` + 160×90 | 320 / 256 / 139.0 | 320 / 256 / 320.0 | 0 |

**Consequence, stated plainly: §4.1–4.4 make the fixture agree, not the app.** UIKit's column for a
real banner dialog is the artwork width (295) or the card's own maximum (310), never 256. Even with
the reorder landed, `errorBanner` computes `256/1.152 = 222.2` in SwiftUI against UIKit's 256 —
because the columns differ, not because the height rule is wrong. The card is 30pt narrower on
every real banner dialog.

Closing that means letting the SwiftUI content column grow with the banner, which reintroduces the
artwork's point size as an input and changes `AlertModalScaffold`'s width ladder — the container
every element's width flows through, currently held green by 469 tests. That is a **separate piece
of work**, not a paragraph in this one.

**Decision:** ship §4.1–4.4, which fixes the height rule and clears the gate for artwork that fits
the column. Do **not** claim it unblocks app adoption. The brief's "Blocks: adopting any
banner-carrying SwiftUI dialog in the app" stays open, now with a measured cause and a number.

This is the whole design. There is no arithmetic, no `UIImage` point-size lookup, and
`ModalTokens.bannerLayout` stays a pure function of `Properties`.

## 5. Landscape — scoped out, deliberately

Landscape banner heights are not a function of anything this design can express:

| shape | UIKit | SwiftUI |
|---|---|---|
| `quizBanner` + 320×229 | 102.3 | 184.0 |
| `standard` + 320×229 | 134.3 | 39.5 |
| every real preset, tight card | ~102.3 regardless of ratio or cap | — |

UIKit distributes leftover height across four sub-required priority tiers; the banner takes the
residual. SwiftUI compresses by a different rule. Reproducing 102.3 means reimplementing residual
distribution, which is the "second layout engine" the council rejected.

**Decision:** the `.banner` row is compared for height in **portrait only**. Landscape keeps full
element-for-element agreement for every other element, plus the banner's `x` and `width`.

The exception must be typed, not hand-written: add `excluding:` + a required `because:` to
`assertAgrees`, so it appears in the failure output and cannot rot into an unexplained skip. Do
**not** widen `DifferentialGeometry.tolerance`.

## 6. Changes

| file | change |
|---|---|
| `SwiftUI/SwiftUIAlertModal.swift` | reorder the banner row per §4.1; rewrite the stale comment block at 160-178 |
| `SwiftUI/ModalTokens.swift` | drop `height` from `bannerLayout`; correct the precedence doc (§2) |
| `SwiftUI/ModalBannerGeometry.swift` | delete `pin`; fix the "751 wins over 251" comment |
| `GBAlertModal+ViewGraph.swift` | comments cite 700/749/249; constants are 245/243/241. Fix. |
| `Tests/.../Resources/GBTestAssets.xcassets` | re-cut `gb_test_banner` to 256×184 at 1x |
| `Tests/.../SwiftUI/DifferentialGeometrySupport.swift` | repoint `banner-comparable` at a ratio+cap preset; add `excluding:`/`because:` |
| `docs/superpowers/specs/2026-08-02-swiftui-banner-height.md` | correct §3, or point it here |

## 7. Tests

1. **Promote the truth table.** A UIKit-side test asserting §2's rule against measured `vwBanner`
   frames across the probe matrix. This is the only artifact that knows what UIKit does, and the
   stale priority comments prove a constant can be changed without anything noticing.
2. **The artwork invariant, as a premise test.** For every banner preset: assert §4.4's two
   inequalities. Without this, re-cutting the asset is a dodge — narrow artwork silently re-enters
   the ambiguous regime and the gate goes quiet.
3. **`assertAgrees("banner-comparable")`**, portrait, replacing
   `test_geometry_bannerComparable_agreesOnWidth_notYetOnHeight`. Written first, as a failing test;
   the inequality pin is **deleted** in the same commit as the fix, never loosened.
4. **`test_theBannerRow_actuallyMeasuresABanner`** — unchanged, still the premise.
5. **Landscape**, `excluding: [.banner]` with the §5 reason, plus a bound: the banner is non-zero
   and no taller than its portrait height on both sides.
6. **A zero-artwork shape.** Measured 0×0 slot / card 187 in UIKit, both paths; SwiftUI unknown.
   This is what the `else` branch at `ViewGraph.swift:435` exists for.
7. **`BannerAspectStressTests`** — UIKit-side, must stay green untouched.
8. Example snapshots re-recorded and **looked at**; `SwiftUICatalog.bannerArtworkNote` updated to
   say the geometry is gated.

## 8. Open risks

- **Real artwork violates §4.4 — verified, ~30pt of card width.** See §4.5. This is the actual
  blocker on app adoption and it is not fixed here. Next piece of work: decide whether SwiftUI's
  column should grow with the banner (mirrors UIKit, costs an asset-dependent input and a change to
  `AlertModalScaffold`'s width ladder) or whether the app's presets should state the width their
  artwork already forces (`fixedWidthPortrait: 295` for the error banner, and so on — an app-side
  change that makes both backends agree without touching the ladder). The second is cheaper and
  probably more honest, since the 256 in those presets is already fiction.
- **An asset re-exported at a different scale factor breaks §4.4 silently** — the point size, not
  the pixel size, is what the constraint sees. Test 2 in §7 is the tripwire.
- **§4.1 may not hold**, per the spike. If the `GeometryReader` fallback is needed, the slot height
  becomes rigid and the landscape bound in §7.5 has to be re-checked — a rigid slot cannot yield
  at all, where SwiftUI currently at least compresses to 184.

## 9. Out of scope

- **UIKit is frozen.** The app consumes this module as an SPM dependency. Fix SwiftUI to match.
- **`badgeBannerMissing`** — a runtime `UIImage` still cannot be expressed; `ModalImage` must stay
  `Sendable`. Separate decision.
- **The vertical margin divergence** from the app's preset is deliberate.
- **`bannerFixedHeight` on the UIKit side.** Measured dead, but removing it is a UIKit change.
  Recorded, not acted on.
