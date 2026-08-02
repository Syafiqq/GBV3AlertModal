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

**4.3 — The banner row becomes a slot and an image**, mirroring `vwBanner` / `ivBanner`:

```swift
Color.clear
    .frame(width: layout.column, height: layout.height)
    .overlay { Image(image.assetName, bundle: image.bundle).resizable().scaledToFit() }
    .modalGeometryProbe(.banner)
    .padding(.bottom, tokens.gapBelowBanner)
```

The height is computed, so the frame is rigid — and that is a knowing trade. UIKit's banner yields
under pressure (its drivers sit below the card's `.low` 250 hugging), and a rigid frame does not.
In portrait, with the card free to grow, the two coincide: every §2 row is a case where nothing was
yielding. In landscape they do not — see §5. `.frame(maxHeight:)` was considered and does not work
here: the height must be *reached*, not merely bounded.

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

**Landscape is not gated for banner shapes.** No test asserts that UIKit and SwiftUI agree on
`banner`, `card`, `title`, `subtitle`, or `primaryButton` for a banner-carrying shape in landscape.
The five portrait-only landscape shapes (`standard-one-button`, `standard-two-button`,
`permission-denied-settings`, `oblique-red-leave-confirm`, `onboarding-welcome-nobanner`) are
gated as before — none of them carries a banner.

**It also breaches the card's VERTICAL margins, which the width cascade above does not cover.** The
card's height cap in `AlertModalScaffold.body` is a `.frame(maxHeight:)`, which only *proposes* a
height; `BannerSlot`'s rigid `.frame(height:)` reports a larger ideal and SwiftUI centres the
overflow rather than compressing it. Measured on `banner-wide` in landscape: the card runs from
~11pt to ~375pt in a 390pt-tall host — ~364pt against a 310pt cap, i.e. past the 40pt card margin at
both ends. Same root cause (the rigid slot cannot yield), second symptom.

**Consequence, stated plainly:** any preset that combines landscape with artwork wider than its
content column — which is eight of the app's nine real banner assets (§3) — renders measurably
differently between the two backends. Not "a taller banner": a WIDER CARD, with its title,
subtitle and primary button all displaced to match the wrong width. Landscape banner parity is the
next piece of work after this one, and it is the harder half.

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
