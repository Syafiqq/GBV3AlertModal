# Design — SwiftUI banner geometry

**Supersedes the diagnosis in** `2026-08-02-swiftui-banner-height.md`. That brief's §3 is wrong; see
§2. Its §1, §4, §5 and §7 still hold.

**Status:** designed, not implemented. **Branch:** `feat/modal-executor-capability`.

> **Retitled from "banner height".** The height is one of two divergences, and it is the smaller
> one. The banner also sizes the CARD, and SwiftUI cannot currently follow — measured at 30pt on
> every real banner dialog in the app.

---

## 1. Two bugs, not one

**1a — an ordering bug.** `SwiftUIAlertModal.swift:154-167` applies the aspect ratio to the image
and the width frame *outside* it, so the ratio never receives the content column and settles on
whatever vertical scrap the `VStack` offered — 26.8pt.

**1b — a missing input.** In UIKit the banner artwork can make the content column WIDER than
`contentMaxWidth`: `ivBanner`'s compression resistance (750) outranks the column's
`width == fixedWidth` at `.medium` (500). SwiftUI's column is `.frame(maxWidth: .infinity)
.frame(maxWidth: contentMaxWidth)` (`AlertModalScaffold.swift:158`) — pinned, and nothing can widen
it.

## 2. Measured UIKit behaviour

Probes against the real `GBAlertModal`, iPhone 17, portrait 390×844. Full tables in the session
scratchpad; the load-bearing rows:

| ratio | artwork | column | slot h | note |
|---|---|---|---|---|
| 1 | 160×90 | 256 | **160** | intrinsic drives — brief's §3 never mentions this term |
| 1 | 300×300 | **300** | 300 | artwork widened the column |
| 1 | 340×340 | **318** | 318 | clamped by the card |
| 16:9 | 160×90 | 256 | 90 | |
| nil | 160×90 | 256 | 90 | natural-aspect driver (245) loses to hugging (250) |
| 1 | 64×64, **fixed 200** | 256 | **64** | `bannerFixedHeight` inert |
| 1 | 160×90, cap 40 | 256 | 40 | cap (950) always wins |
| 1 | 0×0 | 0 | 0 | card 187 |

Three corrections to the brief's §3:

1. **It omits the artwork's intrinsic point size**, which is what produces the headline 160.
2. **`bannerFixedHeight` is inert** — measured zero effect on both paths at every size tried,
   including `fixed 200` on a 64pt image. At 243 it loses to hugging (250) upward and to
   compression resistance (750) downward.
3. **The column is not fixed** (§1b).

**Two rules fit every measurement taken.** With `r = bannerRatio ?? imageW/imageH` and
`cap = bannerMaxHeight ?? ∞`:

```
columnDemand = min(imageW, cap × r)
column       = clamp(columnDemand, lower: contentMaxWidth, upper: cardAvailableWidth)
height       = min(cap, column / r, max(imageH, imageW / r))
```

Verified against every probed configuration, including the awkward ones:

| case | column predicted / measured | height predicted / measured |
|---|---|---|
| gc2gs 320×190, r 320:190, cap 256 | 310 / **310** | 184.1 / **184.0** |
| fasttrack 1168×760, r 292:190, cap 256 | 310 / **310** | 201.7 / **202.0** |
| badge 160×160, r 1, cap 216 | 256 / **256** | 160 / **160** |
| quiz 320×229, r 320:229, cap 216 | 301.8 / **302.0** | 216.1 / **216.0** |
| errorBanner 295×256, r 295:256, cap 320 | 295 / **295** | 256 / **256** |
| aiNotes 320×227, r 960:681, cap 320 | 310 / **310** | 219.9 / **220.0** |

This is a closed form fitted to 30+ measurements, not a reimplementation of the solver.

## 3. The real app — checked, not assumed

`Common/Common/Custom/Components/AlertModal/V3AlertModal+GBV3AlertModal.swift`: the column is
**256 on iPhone, 300 on iPad**. `GeniePresets`' reconstruction is faithful.

Every banner asset the app actually passes, measured from `Geniebook/Assets.xcassets` in **points**
(note `aiNotes`' preset ratio `960.0/681.0` is the 3× *pixel* ratio of a 320pt asset):

| asset | point size | ratio | cap | vs 256pt column |
|---|---|---|---|---|
| `img_illust_gc_finished_quiz` | 320×320 | 1 | 320 | wider |
| `img_illust_onboarding` | 320×229 | 320:229 | 216 | wider |
| `img_gc2gs_prompt_1/2/4` | 320×190 | 320:190 | 256 | wider |
| `img_fasttrack_banner` | **1168×760** | 292:190 | 256 | wider |
| `img_illust_abused_worksheet` | 320×197 | 320:197 | 216 | wider |
| `img_database_error` | 295×256 | 295:256 | 320 | wider |
| `img_illust_ai_notes_banner` | 320×227 | 960:681 | 320 | wider |
| `img_badge_multi_achievement` | 160×160 | 1 | 216 | **fits** |

Both backends, real presets and real point sizes, portrait:

| shape | UIKit card / col / h | SwiftUI card / col / h | Δcard | Δh |
|---|---|---|---|---|
| gc2gs 320×190 | 350 / 310 / 184.0 | 320 / 256 / 256.0 | **−30** | **+72** |
| fasttrack 1168×760 | 350 / 310 / 202.0 | 320 / 256 / 256.0 | **−30** | **+54** |
| forceUpdate 320×320 | 350 / 310 / 310.0 | 320 / 256 / 320.0 | **−30** | **+10** |
| badge 160×160 (fits) | 320 / 256 / 160.0 | 320 / 256 / 216.0 | 0 | **+56** |

**Not one real asset would satisfy a "keep the artwork inside the column" invariant** — eight are
too wide, and the ninth (160×160) is too small, so the intrinsic term binds below the ratio. A
structural fix plus an authoring rule would make the test fixture agree and leave every shipping
dialog wrong. That approach was drafted, measured, and rejected here.

## 4. The design

Give SwiftUI the two rules from §2 as a computed input. The artwork's point size is a genuine
operand that `.resizable()` discards, and there is no way to reach app parity without it.

**4.1 — A new `ModalTokens` rule takes the artwork size.** Shipped as a SEPARATE member rather than
a reshaped `bannerLayout`, because the two answer different questions and both are still live:
`bannerLayout` keeps feeding the bespoke banner rows (ratio + cap applied to an `Image`), while the
standard banner row reads the computed slot geometry.

```swift
func bannerGeometry(imageSize: CGSize, availableCardWidth: CGFloat) -> BannerGeometry
```

`BannerGeometry` is `(column, height)`. Both it and the function are `internal` — they have no
external callers, and everything needed to use them (`\.modalBannerGeometry`, `BannerSlot`) is
internal or private.

Not a measurement cycle: the input is the asset, prior to and independent of the frame it produces.
The trap §7 of the brief records is deriving a size from a measurement that the same size feeds
back into — this is a different shape. `available` comes from the scaffold's existing `proxy`
(`AlertModalScaffold.swift:133`), which is the CONTAINER, as §7 requires.

**4.2 — The column becomes `max(contentMaxWidth, bannerColumnDemand)`.** A no-op when there is no
banner, and when the artwork fits — so the 469 green tests and every non-banner shape are
unaffected by construction. This is the change that closes §1b, and the one that carries real
regression risk: it touches the ladder every element's width flows through
(`AlertModalScaffold.swift:158, 219-220`).

**4.3 — The banner row becomes a slot and an image**, mirroring `vwBanner` / `ivBanner`.

> **The sample below is the SHIPPED spelling, updated.** It originally read
> `.frame(width: layout.column, height: layout.height)` over a `layout` local, and was followed by a
> paragraph arguing that a rigid frame was a knowing trade because "the height must be *reached*, not
> merely bounded". Task 6 measured that argument to be false and the code changed; the sample is
> brought in line here rather than left describing an implementation that no longer exists. What the
> row actually ships as (`SwiftUIAlertModal.BannerSlot`):

```swift
Color.clear
    .frame(width: bannerGeometry.column)
    .frame(maxHeight: bannerGeometry.height)
    .overlay { Image(image.assetName, bundle: image.bundle).resizable().scaledToFit() }
    .modalGeometryProbe(.banner)
    .padding(.bottom, bannerGeometry.height > 0 ? tokens.gapBelowBanner : 0)
```

Three changes from the original sample, all of them measured rather than stylistic:

* **the height is a `maxHeight` over a GREEDY `Color.clear`, not a rigid frame.** `Color.clear`
  expands to fill whatever it is offered up to its cap, so the slot resolves to
  `min(itsOwnDesire, whateverIsLeft)` — UIKit's yield semantics, produced by the layout engine
  instead of by arithmetic. Where the card is free to grow the two spellings are bit-identical
  (every portrait row is unchanged across the switch); where it is against its ceiling, only this
  one yields. This is what closed the landscape banner heights and the vertical margin breach — see
  §5b;
* **the geometry comes from the environment** (`\.modalBannerGeometry`, published by
  `AlertModalScaffold` on `card`), not from a `layout` local — a view cannot read an environment
  value it publishes on its own descendant, which is why `BannerSlot` is a separate type at all;
* **the gap below is paired with the slot**, so a `.zero` geometry occupies no vertical space rather
  than leaving a `gapBelowBanner` hole under nothing, exactly as UIKit's `vwBanner` collapses.

There is also no `.clipped()`: it was inert (an `.overlay` is proposed its host's size and
`scaledToFit` only shrinks inside that) and had no UIKit counterpart — `vwBanner` never sets
`clipsToBounds`; only the card does.

**4.4 — Delete `height` from `BannerLayout`.** Inert in UIKit (§2.2), currently applied in SwiftUI
on the ratio path (`ModalTokens.swift:724`) — a live divergence on every preset that sets both,
which is all of them. `ModalTokens.bannerFixedHeight` keeps carrying the value; only `bannerLayout`
stops using it.

**4.5 — Cover the wide-artwork regime with a NEW asset, not by re-cutting the old one.** This
section originally proposed re-cutting `gb_test_banner` to **320×190 at 1x** (matching the real
`img_gc2gs_prompt_*` assets) and repointing `banner-comparable` at
`popupProperties().copy(bannerRatio: 320.0/190.0, bannerMaxHeight: 256)`. That would have traded one
regime for the other: the artwork-NARROWER-than-the-column case would have lost its only shape.

What shipped instead is a second asset, `gb_test_banner_wide` (320×190 at 1x), behind a second
differential shape, `banner-wide`, carrying exactly the properties above. `gb_test_banner` and
`banner-comparable` are unchanged, so both regimes are covered at once:

| shape | asset | regime | expected on both sides |
|---|---|---|---|
| `banner-comparable` | `gb_test_banner` (160×90 at 1x — 16:9, narrower than the column) | column stays at `contentMaxWidth` | column 256 |
| `banner-wide` | `gb_test_banner_wide` (320×190) | artwork widens the column | card 350, column 310, height 184.06 |

## 5. Landscape — measured, and corrected in Task 6

**This section originally said the divergence was a taller banner (102.3 vs 184.0) and that the fix
was to exclude the `.banner` row. Task 5 measured the actual shape and both halves of that were
wrong.** The numbers below are still the real measurements; the account of what they mean and what
to do about it is rewritten here.

| shape | UIKit | SwiftUI |
|---|---|---|
| quiz + 320×229 | 102.3 | 184.0 |
| standard + 320×229 | 134.3 | 39.5 |
| every real preset, tight card | ~102.3 regardless of ratio or cap | — |

In a height-constrained card UIKit distributes the remainder across four sub-required priority
tiers and the banner takes the residual — no closed form reaches 102.3, and §4.3's rigid frame
cannot yield at all, so landscape gets *worse* under this design before it gets better. That part
still holds. What does not hold is treating this as a HEIGHT problem contained to one row.

> **SUPERSEDED IN PART — read §5b before acting on this section.** The sentence above ("no closed
> form reaches 102.3, and §4.3's rigid frame cannot yield at all") was the reasoning that kept the
> slot rigid, and it is falsified: the frame does not have to *compute* the residual, only stop
> insisting on more than it. `Color.clear` under a `.frame(maxHeight:)` yields it. The banner heights
> and the vertical margin breach are FIXED and `banner-wide` is gated in landscape; the width cascade
> this section describes is real and remains open. §5b has the measured before/after.

**It is a width problem that starts at the banner and ends at the card.** In landscape, UIKit's
residual arbitration shrinks the banner's height — and, because the artwork is WIDER than the
content column on every real preset (§3), the required `ivBanner.width == ivBanner.height * ratio`
tie shrinks the banner's WIDTH DEMAND right along with it. That wrong width does not stay on the
banner: it propagates to the CARD (the card's width is sized off its widest row), and from the card
to every OTHER row that matches the card's width. Measured: `card`, `title`, `subtitle` and
`primaryButton` all diverge from UIKit in landscape on a wide-artwork shape — four rows that read
as four defects until you trace them back to the one place the number is actually wrong. It is one
root cause, not four.

**Excluding only `.banner` does not work.** `banner`, `card`, `title`, `subtitle` and
`primaryButton` are exactly the elements `banner-wide` draws, so an `excluding: [.banner]` call
still measures four more rows that also diverge — the exclusion this section originally proposed
does not gate the shape, it just hides the row where the divergence is easiest to see. Excluding
the whole cascade (`[.banner, .card, .title, .subtitle, .primaryButton]`) is honest about the
divergence but leaves `banner-wide` with NOTHING left to compare — a vacuous gate, indistinguishable
from a passing test that asserts nothing. So the landscape comparison test for `banner-wide` was
**deleted**, not excluded.

**What actually shipped, in Task 5 and Task 6:**

1. A structural guard on `assertAgrees`: any call that leaves nothing comparable fails outright
   (`'\(name)': NOTHING was comparable` — `DifferentialGeometryTests.assertAgrees`). This makes the
   vacuous-gate failure mode this section almost shipped structurally impossible to repeat, not just
   avoided by discipline.

   An `excluding:` / `because:` pair was added alongside it and has since been **deleted**. It never
   gained a caller, because this section's own ruling is that the honest response to a shape whose
   every element diverges is to delete the comparison, not narrow it — so the parameters encoded an
   option the design had already decided against, and their guard rail (`because:` must be
   non-empty) was itself unreachable and untested. `assertAgrees` now has no exclusion mechanism at
   all. The `comparable.isEmpty` guard stays regardless: it independently catches an unexcluded
   shape that measures nothing comparable, and it is what would make any future exclusion mechanism
   safe.
2. A landscape **presence** test for `banner-wide` (`test_bannerWide_landscape_
   stillDrawsABannerOnBothSides`): both backends must draw something non-zero on every element that
   isn't `absentOnBoth`. This catches a regression that makes the shape vanish; it does NOT catch a
   regression that changes its size or position, and its name says so.
3. Task 4's slot-containment invariant
   (`test_bannerWide_theSlotNeverOverflowsTheCard_atAnyHostWidth`), checked at three host sizes
   (portrait phone, landscape phone, iPad portrait): the banner slot never starts left of the card
   and never overflows it, and stays inside the card's required minimum padding. This is a bound on
   where the (wrong) numbers land, not an agreement check.

## 5b. Landscape, revisited — the residual DOES have a closed form, and it is not arithmetic

**Two claims in §5 above are now measurably wrong and are corrected here. The measured tables stay;
they were never the problem.**

### What was wrong

1. *"No closed form reaches 102.3."* False in the sense that matters. No formula **computes** the
   residual — that part stands — but the layout engine **arrives** at it, which is exactly what Auto
   Layout is doing on the UIKit side. `BannerSlot`'s frame was rigid on the stated reasoning that
   "the height must be REACHED, not merely bounded", and that reasoning is falsified by a property of
   the view it was applied to: **`Color.clear` is greedy.** Under `.frame(maxHeight: h)` it expands
   to fill whatever it is offered, up to `h`. So the slot resolves to
   **`min(itsOwnDesire, whateverIsLeft)`** — which is precisely the yield semantics UIKit's priority
   ladder produces by placing every banner driver (`bannerNaturalAspect` 245, `bannerFixedHeight`
   243, `bannerImageIntrinsic` 241) below the card's `.low` 250 hugging.
2. *"Landscape is not gated for banner shapes."* No longer true — see below.

The change is one line: `.frame(width: column, height: height)` becomes `.frame(width: column)` plus
`.frame(maxHeight: height)`. **`.layoutPriority(-1)` was tried and is inert** — byte-identical
results on every probed shape in both orientations. The banner already yields first without it,
because `Color.clear.frame(maxHeight:)` is the only child in the column with a `[0, h]` range and
SwiftUI serves its stiffest children first. The evidence that the ordering is correct is the title:
under the rigid frame `minimumScaleFactor` squeezed it to 21.5pt; under `maxHeight` it returns to its
natural 28.7 while the banner absorbs the entire squeeze.

### Measured, at 844x390

| shape | element | UIKit | SwiftUI (rigid) | SwiftUI (`maxHeight`) |
|---|---|---|---|---|
| `banner-wide` | card h | 294.0 | 374.6 | **294.0** |
| `banner-wide` | banner h | 102.33 | 190.0 | **102.0** |
| `banner-wide` | title y | 138.33 | 226.0 | **138.0** |
| `banner-comparable` | card h | 294.0 | 312.6 | **294.0** |
| `banner-comparable` | banner h | 134.33 | 160.0 | 115.0 |

**Portrait did not move by so much as a rounding step** — every portrait frame is bit-identical
across the switch, which is the point: where the card is free to grow, the slot is offered at least
its desire and takes exactly it, so a `maxHeight` frame and a rigid one are indistinguishable.

The vertical-margin breach §5 recorded is closed. Both banner shapes now land on the ceiling exactly
instead of reporting a larger ideal and having SwiftUI centre the overflow.

### What is gated now

**`banner-wide` IS gated in landscape** — `test_geometry_landscape_bannerWide_agreesOnEveryOriginAndHeight`
compares `minX`, `minY` and `height` on every comparable row at the usual 0.5pt. It deliberately does
**not** compare `width`, and does not use `assertAgrees` (which still has no exclusion mechanism, per
§5 point 1 — that decision stands). The exclusion is justified by a mechanism that is itself
asserted, in `test_bannerWide_landscape_theWidthGapIsTheColumnRule`.

**The width gap is real and unfixed.** UIKit's landscape arbitration shrinks the banner's height, and
the required `ivBanner.width == ivBanner.height * ratio` tie shrinks the image's width demand with
it: measured, `ivBanner` is **172pt wide inside a 256pt `vwBanner`**, so the image asks for less than
the content column, nothing pushes the column past `contentMaxWidth`, and UIKit's column does not
grow in landscape at all. `ModalTokens.bannerGeometry` computes 320 there. The 64pt difference
reaches the card (384 vs 320) and every row that matches the card. It is not computable without a
measurement pass: the column depends on the resolved height, the height on the residual, the residual
on the text, and the text's wrapping on the column. §5's width-cascade analysis was therefore
**correct**; only its attribution was one step short — the cascade starts at the height, not at the
column.

**`banner-comparable` is NOT gated in landscape, and the reason is not the banner.** Its widths
already agree, its card and primary button are now exact, and what remains is a single **19.33pt**
displacement. That number is the D-7 subtitle gap, measured: in landscape UIKit's
`svSubtitleContainer` compresses to a **19.0pt viewport over a 38.33pt label** — it clips half its own
subtitle — while SwiftUI, having no per-subtitle viewport, keeps the full 38.3. The residual is
conserved, so the banner pays exactly what the subtitle withheld. Pinned by mechanism (the two
shortfalls must be equal) in `test_bannerComparable_landscape_divergesOnlyByTheSubtitleViewport`, and
recorded against D-7 in `DifferentialGeometrySupport`'s header rather than as a banner gap.

> **SUPERSEDED — see §5c.** D-7 is closed and `banner-comparable` IS gated in landscape, through the
> ordinary `assertAgrees`. The mechanism pin named above is deleted, replaced by
> `test_geometry_landscape_bannerComparable` plus an explicit non-vacuity premise. The paragraph
> stays because its measurements are the evidence §5c builds on.

### Consequence, restated

Landscape banner parity is **no longer the harder half; it is two smaller halves with known owners.**

1. **D-7's subtitle viewport** — worth a measured 19.33pt, blocks `banner-comparable` alone, and is a
   prerequisite for `banner-wide` regardless of route. This is the load-bearing item. **DONE — §5c.**
2. **The landscape column rule** — worth 64pt on wide artwork, needs a measurement pass rather than a
   formula, and should wait behind (1), because `banner-wide`'s width divergence currently masks the
   subtitle one and a second pass cannot be validated while a 19.33pt error is still in the residual
   it would be measuring. **Still open, and now unblocked: (1) is out of the residual.**

Any preset combining landscape with artwork wider than its content column (eight of the app's nine
real banner assets, §3) still renders a wider card than UIKit. What is no longer true is that it also
renders a taller one, an overflowing one, or an ungated one.

## 5c. D-7 — the subtitle slot, measured and closed

### The rule UIKit is following

Swept on `banner-comparable` at 844 wide, host height 450 → 330 in 10pt steps, reading
`svSubtitleContainer.bounds` (the viewport), `lbSubtitle.bounds` (the content) and `vwBanner`:

| host | viewport | content | banner | what moved |
|---|---|---|---|---|
| 844x450 | 38.33 | 38.33 | 160.0 | nothing is under pressure |
| 844x440 | 38.33 | 38.33 | 160.0 | — |
| 844x430 | **19.33** | 38.33 | 160.0 | the SUBTITLE yields; the banner has not moved at all |
| 844x415 | **19.0** | 38.33 | 159.3 | subtitle reaches its floor, banner begins to pay |
| 844x390 | 19.0 | 38.33 | 134.33 | landscape phone |
| 844x330 | 19.0 | 38.33 | 74.33 | banner absorbs every further point |

`viewport == clamp(whatever is left, ModalLayout.subtitleFloorHeight, contentHeight)`, and **the
subtitle yields BEFORE the banner.**

That order looks backwards against `ModalLayout.Priority` — `bannerNaturalAspect` 245 / 243 / 241 all
sit BELOW `subtitleSlotHeight` (`.defaultLow`, 250), and `TitleSubtitleTruncationTests` asserts it. It
is not backwards. Those three set the banner's height; what DEFENDS it under pressure is `ivBanner`'s
WIDTH compression resistance (**750**) reaching the height through the required
`width == height * ratio` tie. The effective ladder is therefore **subtitle slot (250) → banner (750)
→ subtitle floor (850)**, which is exactly the order measured, and the floor is what stops the
subtitle before the banner starts.

### The SwiftUI answer — two changes, both in `SwiftUIAlertModal`

1. **`SubtitleSlot`**, the counterpart of `svSubtitleContainer`: a `ScrollView` under
   `.frame(minHeight: floor, maxHeight: contentHeight)`. That is the mirror of `BannerSlot`'s greedy
   `Color.clear` — a `Text` cannot express the `[floor, content]` range, because a flexible frame
   reports `clamp(childHeight, min, max)` and `Text` answers every height proposal with the height its
   glyphs need, so with `maxHeight` at the ideal the clamp is the identity and the row is rigid. A
   `ScrollView` reports `[0, ∞)`, and the frame turns that into the interval Auto Layout arbitrates
   over. **Unconditional**, because UIKit's is: it does not read `contentScrollable`.
2. **`subtitleLayoutPriority` 0 → −1**, which puts the subtitle below the BANNER as well as below the
   title. Without it the slot exists and never engages: SwiftUI's VStack hands a same-priority
   subtitle its ideal and lets the banner absorb everything, which is precisely the pre-fix numbers.
   With it, the VStack serves the banner first, reserves the subtitle's `minHeight`, and gives the
   subtitle `clamp(residual, floor, content)` — UIKit's rule, arrived at rather than computed.

### Measured after

| host | element | UIKit | SwiftUI |
|---|---|---|---|
| 844x390 | banner h | 134.33 | 134.24 |
| 844x390 | subtitle h | 19.0 | 19.09 |
| 844x390 | card h | 294.0 | 294.0 |
| 390x844 | every row | — | **bit-identical to before this change** |

Every row at every 10pt step from 844x450 to 844x330 agrees to within **0.09pt**, except the band
described below. Portrait did not move.

### What is gated now

* **`banner-comparable` in landscape**: the ordinary `assertAgrees`
  (`test_geometry_landscape_bannerComparable`), every row, every coordinate, 0.5pt. The 19.33pt
  mechanism pin is deleted. Non-vacuity is asserted separately
  (`test_bannerComparable_landscape_bothBackendsAreClippingTheSubtitle`): both backends must be
  clipping, or the agreement is between two unpressured cards and proves nothing.
* **`long-subtitle-unscrolled`**, a new shape — the 1222pt subtitle with `contentScrollable` OFF —
  through `assertAgrees` in BOTH orientations. UIKit's viewport 645.33 against SwiftUI's 645.33
  portrait; 161.33 against 161.33 landscape. This is the real comparison that the
  `long-subtitle-scrolling` inequality was standing in for.

### What is left, and it is not D-7

* **`contentScrollable`.** `long-subtitle-scrolling` still cannot compare its subtitle row, but the
  cause has inverted: it is a SwiftUI-only feature, not a missing one. `ScrollableContent` wraps title
  AND subtitle, so inside it the height proposal is unbounded, the subtitle slot is never pressured,
  and it reports 1222 where UIKit's viewport is 645.3. Since the subtitle now scrolls without the
  flag, this is the deciding input for `2026-08-02-content-scrollable-review.md`.
* **Vertical padding compression, in a 15pt band.** `banner-comparable` agrees at every host height
  from 844x450 to 844x435 and from 844x415 to 844x330, and diverges only in **844x420…430**: UIKit
  re-expands its top inset 16 → 23 and pays for it by collapsing the subtitle a further 14pt, because
  its `componentSpacing` is 800 and the subtitle slot's tie is 250 — spacing outranks body text.
  SwiftUI's padding yields first instead, having no min/max padding primitive. **The band was already
  divergent before this work, on more rows and by more points**; it is narrowed, not introduced. It
  falls on no gated host size.

## 6. Changes

| file | change |
|---|---|
| `SwiftUI/ModalTokens.swift` | add `bannerGeometry(imageSize:availableCardWidth:)` per §2's rules (internal); drop `BannerLayout.height`; correct the precedence doc |
| `SwiftUI/AlertModalScaffold.swift` | column becomes `max(contentMaxWidth, bannerColumnDemand)` |
| `SwiftUI/SwiftUIAlertModal.swift` | slot/image split per §4.3; rewrite the stale comment at 160-178 |
| `SwiftUI/ModalBannerGeometry.swift` | folded into the slot frame, or deleted; fix the "751 wins over 251" comment |
| `GBAlertModal+ViewGraph.swift` | comments cite 700/749/249; constants are 245/243/241. Fix. |
| `Tests/.../Resources/GBTestAssets.xcassets` | ADD `gb_test_banner_wide` at 320×190 1x; `gb_test_banner` (160×90) unchanged |
| `Tests/.../SwiftUI/DifferentialGeometrySupport.swift` | add the `banner-wide` shape; `banner-comparable` unchanged |
| `docs/superpowers/specs/2026-08-02-swiftui-banner-height.md` | correct §3, or point it here |

## 7. Tests

1. **Pin §2's two rules** as a UIKit-side truth table against measured `vwBanner` frames across the
   probe matrix. This is the only artifact that knows what UIKit does, and the stale priority
   comments prove a constant can change with nothing noticing.
2. **`assertAgrees("banner-comparable")`**, portrait — written first, as a failing test. The
   inequality pin is **deleted** in the same commit as the fix, never loosened.
3. **`test_theBannerRow_actuallyMeasuresABanner`** — unchanged, still the premise.
4. **Shapes for all three paths** per DoD item 3: ratio set, ratio nil, cap binding. Plus one where
   the artwork FITS the column (160×160, the badge case) — the only real asset in that regime, and
   the one that proves the column change is a no-op when it should be.
5. **A non-banner regression sweep** — the §4.2 column change must be provably inert without a
   banner. The existing suite covers this; run it and say so.
6. **Landscape.** This item originally read "`excluding: [.banner]` with the §5 reason, plus a
   bound: the banner is non-zero on both sides" — superseded, see §5 (Task 6). `excluding: [.banner]`
   alone does not gate `banner-wide`: `card`, `title`, `subtitle` and `primaryButton` also diverge,
   and excluding all five leaves nothing comparable, which `assertAgrees`'s structural guard now
   refuses outright. What shipped instead: no landscape agreement comparison for banner shapes at
   all, a landscape **presence** test (both backends draw something non-zero on every element that
   isn't `absentOnBoth`), and Task 4's slot-containment invariant checked at three host sizes.
7. **A zero-artwork shape.** Measured 0×0 slot / card 187 in UIKit, both paths; SwiftUI unknown.
8. **`BannerAspectStressTests`** — UIKit-side, must stay green untouched.
9. Example snapshots re-recorded and **looked at**; `SwiftUICatalog.bannerArtworkNote` updated.

## 8. Risks

- **§4.2 is the dangerous change.** It touches the card's width ladder. Mitigation is §7.5: prove
  inertness without a banner before touching anything else.
- **§4.3's rigid frame cannot yield**, which is a regression in landscape (§5) — accepted, left
  **un**gated for banner shapes (§5, corrected in Task 6: excluding only `.banner` is not a gate,
  since `card`/`title`/`subtitle`/`primaryButton` diverge too), and named as the next piece of work.
- **Scale-factor re-exports** change the point size the constraint sees while the pixel size looks
  unchanged. §7.1's truth table is the tripwire.
- **iPad is unmeasured.** The app's column is 300 there. The rules are width-parameterised so they
  should hold, but "should" is not "measured".

## 9. Out of scope

- **UIKit is frozen.** The app consumes this module as an SPM dependency. Fix SwiftUI to match.
- **`badgeBannerMissing` is a GALLERY fixture note, not an app blocker.** Checked: all 13 banner
  call sites in the app pass `UIImage(named:)` with a literal or a `String` (`badge.localImageName`
  is `let localImageName: String`, resolved through `UIImage(named:)` in three other views too).
  No runtime-constructed `UIImage` exists on the app's banner path, so every one is expressible as
  `ModalImage(name)`. Adoption is a mechanical call-site migration, not an API gap. The catalog
  entry draws a generated placeholder only because the example app has no real badge artwork —
  that placeholder is what `ModalImage` cannot name. The forward-looking version of this risk is
  narrow: if badge artwork ever becomes API-supplied rather than a local name, `ModalImage` needs a
  case for it.
- **`bannerFixedHeight` on the UIKit side.** Measured dead, but removing it is a UIKit change.
- **The vertical margin divergence** from the app's preset is deliberate.
