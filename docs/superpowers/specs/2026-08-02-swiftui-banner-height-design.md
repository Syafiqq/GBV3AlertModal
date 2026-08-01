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

**4.1 — `ModalTokens.bannerLayout` takes the artwork size.**

```swift
func bannerLayout(imageSize: CGSize, available: CGFloat) -> BannerLayout
```

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

**4.5 — Re-cut `gb_test_banner`** to a size that exercises the rules rather than dodging them:
**320×190 at 1x**, matching the real `img_gc2gs_prompt_*` assets, with `banner-comparable` moved to
`popupProperties().copy(bannerRatio: 320.0/190.0, bannerMaxHeight: 256)`. Expected on both sides:
column 310, height 184.0.

## 5. Landscape — scoped out, deliberately

| shape | UIKit | SwiftUI |
|---|---|---|
| quiz + 320×229 | 102.3 | 184.0 |
| standard + 320×229 | 134.3 | 39.5 |
| every real preset, tight card | ~102.3 regardless of ratio or cap | — |

In a height-constrained card UIKit distributes the remainder across four sub-required priority
tiers and the banner takes the residual. No closed form reaches 102.3, and §4.3's rigid frame
cannot yield at all — so landscape gets *worse* under this design before it gets better.

**Decision:** the `.banner` row is compared for height in **portrait only**. Landscape keeps full
element-for-element agreement for every other element, plus the banner's `x` and `width`. The
exception is typed — add `excluding:` + a required `because:` to `assertAgrees` — so it shows up in
failure output and cannot rot into an unexplained skip. Do **not** widen
`DifferentialGeometry.tolerance`.

Landscape banner parity is the next piece of work after this one, and it is the harder half.

## 6. Changes

| file | change |
|---|---|
| `SwiftUI/ModalTokens.swift` | `bannerLayout(imageSize:available:)` per §2's rules; drop `height`; correct the precedence doc |
| `SwiftUI/AlertModalScaffold.swift` | column becomes `max(contentMaxWidth, bannerColumnDemand)` |
| `SwiftUI/SwiftUIAlertModal.swift` | slot/image split per §4.3; rewrite the stale comment at 160-178 |
| `SwiftUI/ModalBannerGeometry.swift` | folded into the slot frame, or deleted; fix the "751 wins over 251" comment |
| `GBAlertModal+ViewGraph.swift` | comments cite 700/749/249; constants are 245/243/241. Fix. |
| `Tests/.../Resources/GBTestAssets.xcassets` | re-cut `gb_test_banner` to 320×190 at 1x |
| `Tests/.../SwiftUI/DifferentialGeometrySupport.swift` | repoint `banner-comparable`; add `excluding:`/`because:` |
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
6. **Landscape**, `excluding: [.banner]` with the §5 reason, plus a bound: the banner is non-zero on
   both sides.
7. **A zero-artwork shape.** Measured 0×0 slot / card 187 in UIKit, both paths; SwiftUI unknown.
8. **`BannerAspectStressTests`** — UIKit-side, must stay green untouched.
9. Example snapshots re-recorded and **looked at**; `SwiftUICatalog.bannerArtworkNote` updated.

## 8. Risks

- **§4.2 is the dangerous change.** It touches the card's width ladder. Mitigation is §7.5: prove
  inertness without a banner before touching anything else.
- **§4.3's rigid frame cannot yield**, which is a regression in landscape (§5) — accepted, gated,
  and named as the next piece of work.
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
