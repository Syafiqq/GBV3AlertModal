# UIKit ↔ SwiftUI differences — full list, for review

Every known difference between the UIKit rendering path (`GBAlertModal`/`UIKitModalRenderer`/
`Properties`/`DataHolder`) and the three SwiftUI-native paths (`SwiftUIModalRenderer`/
`EmbeddedModalRenderer`/`WindowModalRenderer`, over `ModalProperties`/`ModalContent`), as of
2026-08-08 (commit `6f1d44b`). Compiled for owner review, not for action — nothing here is a
request to fix anything.

**Scope note.** All three SwiftUI-native renderers share the same drawing view
(`SwiftUIAlertModal`) and the same `ModalProperties`/`ModalContent` vocabulary, so unless stated
otherwise, "SwiftUI" below means all three uniformly — a divergence in `SwiftUIAlertModal` is not
specific to whichever renderer happens to be managing presentation state.

---

## 1. Vocabulary differences — `Properties`/`DataHolder` vs `ModalProperties`/`ModalContent`

| # | Difference | Status | Citation |
|---|---|---|---|
| 1.1 | `bannerFixedHeight` does not exist on `ModalProperties` at all. | Deliberate — proven **inert on both backends**, not a loss. `BannerLayout` has no field for it; nothing lays out with it on the UIKit path either. | `ModalProperties.swift:17-21`; `ModalTokens.swift:855-856` (`BannerGeometryTruthTests.test_bannerFixedHeight_isInert_*`) |
| 1.2 | `ActionStyle.capsule`/`.capsuleOutlined` — **CLOSED, same day.** Was: declared on `ModalProperties.ActionStyle` (all 4 UIKit cases present) but not rendered — only `.obliqueBottomLeft`/`.plain` were read, and a consumer shipping `.capsule` silently got the oblique look. Now: `CapsuleButtonStyle`/`CapsuleOutlinedButtonStyle` draw the real look (filled/outlined pill, either slot), picked via `ModalTokens.primaryCapsule`/`.secondaryCapsule`/`.primaryCapsuleOutlined`/`.secondaryCapsuleOutlined`. Reachable today via the example app's own `variant-button-capsule`/`variant-button-capsuleOutlined` catalog entries, which already existed and already carried real theme values — they just rendered the wrong shape until now. | `ModalButtonStyles.swift` (`CapsuleButtonStyle`/`CapsuleOutlinedButtonStyle`); `ModalTokens.swift` (`init(from:)`, both derivations); tests `test_primaryCapsule_derivesFromProperties`/`test_primaryCapsuleOutlined_derivesFromProperties`/`test_secondaryCapsule_derivesFromProperties_fromItsOwnTheme`/`test_secondaryCapsuleOutlined_derivesFromProperties`/`test_capsuleActionStyles_deriveTheSameTokens_onBothSides` |
| 1.3 | `subtitleCustomView: UIView` has no field on `ModalContent`. A `ModalDescriptor` is `Sendable` and can't carry a live view. | Deliberate, architectural (see §3). Replaced by `register(_:view:)` — a whole-modal SwiftUI body registered per descriptor **kind**, not a view attached per **instance**. | `ModalContent.swift` doc; `SwiftUICatalog+Divergences.swift:34-42` names this class of difference explicitly |
| 1.4 | Colour type (`Color` vs `UIColor`), `EdgeInsets.leading` vs `UIEdgeInsets.left`. | Cosmetic type differences only — both presets are horizontally symmetric so the leading/left substitution changes nothing. Field-for-field equality pinned by `ModalPropertiesEquivalenceTests` (builds one preset both ways, asserts equal `ModalTokens`). | `ModalTokens.swift:920-931` (the init's own doc names these as the **only** three differences from the UIKit derivation) |

---

## 2. Control-surface differences — `GBAlertModal`'s view methods vs `ModalRenderer`

`GBAlertModal` (the UIKit view) exposes 7 public methods beyond its initializer:
`show(parent:completion:)`, `hide()`, `dismiss()`, `dismissAndEmit(event:)`,
`updateDialog(holder:properties:)`, `changePrimaryActionEnableState(isEnable:)`,
`changeSecondaryActionEnableState(isEnable:)` (`GBAlertModal+Lifecycle.swift`).

| GBAlertModal method | SwiftUI equivalent |
|---|---|
| `show(parent:completion:)` | `renderer.present(descriptor:id:resolve:)` — different mechanism: descriptor-driven, not "attach a pre-built view to a parent". |
| `hide()` | `renderer.setHidden(id:_:)` — direct `ModalRenderer` protocol equivalent. |
| `dismiss()` | `renderer.dismiss(id:)` — direct equivalent. |
| `dismissAndEmit(event:)` | Folded into the resolve gate every renderer already runs — an action routes through `route`/`gate`, there's no separate "emit" call. |
| `updateDialog(holder:properties:)` | `renderer.update(id:to:)` — direct equivalent, full descriptor replacement rather than an in-place holder mutation. |
| `changePrimaryActionEnableState(isEnable:)` / `changeSecondaryActionEnableState(isEnable:)` | **No standalone equivalent.** Reached only by presenting/updating a descriptor conforming to `ButtonEnablement` (`primaryEnabled`/`secondaryEnabled` fields, `AlertDialog` already conforms) — a full descriptor update, not a targeted single-property mutator on a live instance. |

Citation: `GBAlertModal+Lifecycle.swift:30-93`; `ModalDescriptor.swift:24` (`ButtonEnablement`);
`AlertDialog.swift:12,23`.

---

## 3. Architectural difference — instantiate-a-view vs descriptor model

UIKit: `GBAlertModal(properties:holder:)` builds a real view; a consumer owns it and calls its
methods directly. SwiftUI: a consumer never touches a view — it hands a `Sendable` descriptor value
to `ModalExecutor`/`ModalRenderer`, which owns presentation, teardown, and the resolve-once gate.
This is the whole point of the migration, not a gap — named here only so it isn't missed when
scanning for "differences."

---

## 4. Rendering/visual divergences (measured)

The authoritative record is `SwiftUICatalog+Divergences.swift` (example app) — five shapes, each a
UIKit/SwiftUI twin pair you can step to side by side, each caption stating whether the difference is
**ACCEPTED** (real, judged not worth chasing) or a **DEFECT** (real, unfixed, on record).

| Entry | Status | What differs | Citation |
|---|---|---|---|
| D-A — tall uncapped artwork | **ACCEPTED** | `bannerRatio: nil`, no cap, 200×2000pt artwork. SwiftUI's `BannerSlot` yields the banner column ~13pt taller than UIKit's own residual-arbitration yield (525pt vs measured SwiftUI reading) and the subtitle clips to one line where UIKit shows two. Column width agrees (256, both). No shipping preset is in this regime — every real preset sets `bannerMaxHeight`, which binds first and makes the two agree exactly. | `SwiftUICatalog+Divergences.swift:81-95` |
| D-B — stated ratio ≠ artwork aspect | **DEFECT, unfixed, now gated** | A 320×190 asset under `bannerRatio: 1` (no unusual preset — that's the finding). UIKit measures a 305.67pt content COLUMN; SwiftUI's rule computes 318 (390-wide host) / 320 (1024-wide host) — SwiftUI's card and every row in it run ~12–14pt **wider** than UIKit's, at the same host size. Root cause: SwiftUI's demand reads the artwork's raw width; UIKit's `scaleAspectFit` letterboxes it under a different demand the rule can't see. Was pinned only at the isolated `bannerGeometry`-function level (`BannerGeometryTruthTests`); `BannerWidthDivergenceTests.test_bannerRatioMismatch_theCardWidthDivergesFromUIKit` now pins the SAME divergence through the full render too (CARD width, not just column — 380.67 UIKit vs 384 SwiftUI at the width the host ceiling doesn't clamp, `iPadWidthHost`). Still a real, unfixed defect — this only means closing OR silently widening it now fails a test instead of going unnoticed. | `SwiftUICatalog+Divergences.swift:97-110`; `BannerWidthDivergenceTests.swift` |
| banner-wide landscape column | **DEFECT, parked, now gated** | Landscape only (portrait agrees). UIKit's height-constrained banner shrinks its own width demand too (`height × ratio`), capping its COLUMN at 256; SwiftUI's portrait-derived rule stays at 320 — reaching the card (UIKit 320 vs SwiftUI 384, 64pt off) and every row that matches its width. `GeometryPinsTests.test_bannerWide_landscape` still gates every origin/height at 0.5pt and deliberately excludes width — that choice is unchanged. `BannerWidthDivergenceTests.test_bannerWide_landscape_theCardWidthDivergesFromUIKit` is the width assertion that test doesn't make, added alongside it rather than folded in, so the two tests' scopes stay legible (one shape, deliberately geometry-only; one gap, deliberately isolated). Closing the underlying defect still needs a feedback pass (`.superpowers/sdd/2026-08-02-swiftui-banner-geometry/landscape-width-report.md`) — only the "not gated by any test at all" half of this entry is now false. | `SwiftUICatalog+Divergences.swift:112-121`; `BannerWidthDivergenceTests.swift` |
| Vertical-compression band | **ACCEPTED, unmatchable** | Only at host heights 844×417…431. UIKit's answer here is **path-dependent** (same modal reports 18.67pt/38.33pt fresh vs 24.00pt/27.33pt after passing through a smaller size first — 16pt apart from identical inputs). SwiftUI's layout is a pure function of (tree, proposed size) and reproduces UIKit's *fresh* branch only — there is no single UIKit value to match. | `SwiftUICatalog+Divergences.swift:123-136` |
| `showsPrimary` not obeyed | **CLOSED** (Pass 2) | Was a genuine renderer-obedience bug, not a geometry divergence: the shared resolver correctly said "no primary button" but `AlertModalScaffold.primaryTitle` was non-optional `String` and drew one anyway (64pt of phantom card height). Fixed by making `primaryTitle: String?`. Kept in the catalog as the only worked example of the *defect* class (vs the geometry class the other four are). | `SwiftUICatalog+Divergences.swift:141-161` |

### Global divergences (apply to every SwiftUI entry, `SwiftUICatalog.swift:88-107`)

- **Banner artwork + geometry resolution mechanism differs.** SwiftUI resolves the asset by *name*
  (`Image(_:)`) and sizes the slot from `ModalTokens.bannerGeometry`; UIKit passes a real `UIImage`
  and lets Auto Layout constraint priorities decide. Same inputs, different layout engines — pinned
  element-for-element in **portrait only** (`BannerGeometryTruthTests`/`DifferentialGeometryTests`).
  **Landscape banner shapes are not gated by any test** — see the banner-wide landscape entry above,
  which is exactly that gap made visible.
- **Fonts.** Title/subtitle/button fonts DO flow from the same `Properties` (bridged via
  `UIFont`→`Font`). **Per-run fonts inside attributed text do NOT** — SwiftUI's `Text` ignores
  UIKit-scoped font attributes on individual runs, by design (not planned to change). Note: this
  caption predates this session's colour-bridging fix (below) and is still accurate for *font* —
  only colour/bold were fixed, not font.
- **Orientation.** All three SwiftUI renderers pin `isLandscape: false` always; the resolver's one
  orientation-sensitive branch always takes the portrait reading.

### Fixed this session, kept as closed record

- **No animation (C5).** Was: SwiftUI presented/tore down instantly on all three SwiftUI-native
  renderers; UIKit fades out over 0.2s (`GBAlertModal.hide()`) on dismiss (present itself is
  un-animated on UIKit too — `GBAlertModal.show()` has no animation block, so the two backends now
  agree on BOTH halves). `SwiftUIModalRenderer`/`EmbeddedModalRenderer` wrap their `teardown`'s
  `presentations` mutation in `withAnimation`, with `.transition(.opacity)` on each host's `ForEach`
  row; `WindowModalRenderer` (imperative `UIHostingController`, no `ForEach`) calls the literal same
  `UIView.animate` `GBAlertModal.hide()` uses. `live[id] = nil` (and the token resolve) stay
  synchronous on all three — only the visual removal is deferred, matching `UIKitModalRenderer`'s own
  fire-and-forget `hide()`. The no-blink in-place swap needed no change: an `update(_:to:)` rebuild
  replaces a `presentations` element at the SAME identity, never inserting/removing, so
  `.transition` never fires for it.
- **Attributed colour/bold runs** — `AttributedTextBridge` now re-scopes UIKit-scoped colour and
  bold onto SwiftUI's rendering scope, so they now render as UIKit draws them (previously silently
  dropped — a real, shipping-shape-affecting bug, fixed via commits 4464579/f0867e8/7cccf9d).
  `SwiftUICatalog.swift:112-115` (`attributedRuns`, kept as a closed-record constant).
- **`datePickerRange`** — `DatePickerDialog` now carries `minimumDate`/`maximumDate`, applied
  identically by both renderers. `SwiftUICatalog.swift:151-156`.

### Not really divergences — noted so they aren't mistaken for gaps

- **`badgeArtworkMissing`/`badgeBannerMissing`** — badge shapes can't show real per-record artwork;
  this test/example bundle has no such asset (`[API]` placeholder only, both galleries). Not a
  backend difference — an asset-availability limit of the demo environment.
- **`inputChrome`** — not a renderer divergence at all: both backends agree (`TextInputHolder`
  constrains a `UITextField` to 44pt on both). The UIKit *gallery's* entry hand-builds a bordered
  `UITextView` at the call site instead of using the descriptor path — a comparison-note artifact of
  the demo, not a library difference. `SwiftUICatalog.swift:137-146`.
- **`subtitleSlotNone`** — `ResolvedModal.SubtitleKind.custom` means `holder.subtitleCustomView !=
  nil` on UIKit; on SwiftUI backends the structural equivalent is `Presentation.customContent !=
  nil` instead. Neither holder fabricates an empty `UIView` just to make the resolver say `.custom`.
  `SwiftUICatalog.swift:147-150`.
- **`loadingPort`** — `LoadingDialog` additionally carries a busy-primary state the UIKit gallery
  entry has no way to ask for; shown in its resting state to match the catalog. An addition, not a
  loss. `SwiftUICatalog.swift:157-160`.
- **`TallBannerYieldTests` finding** — SwiftUI survives a tall-uncapped banner via **card growth**
  (the card consumes up to 778 of an 844pt portrait host); UIKit survives via **banner yield**
  (Auto Layout priority tiers shrink the banner to a host-dependent residual). Different mechanism,
  same safe outcome — title/subtitle never squeeze toward zero on either backend. This is the
  automated-test twin of divergence D-A above. `TallBannerYieldTests.swift:6-40`.

---

## 5. Test-coverage gaps

- **`BannerAspectStressTests`** (UIKit, 8 automated cases: 3 aspect ratios × portrait/landscape +
  2 extra) has exactly **one** SwiftUI counterpart (`TallBannerYieldTests`, the single highest-risk
  scenario) — not a full 1:1 port of the matrix.
- ~~The example app's 28-shape Stress Catalog... not wired into `EmbeddedCatalogScreen`/
  `WindowCatalogScreen`~~ — **CLOSED same day** (commit `ac66628`, after this doc was first written):
  both screens now register `UIKitFreeCatalogPresets.stressPresets` and present
  `SwiftUICatalog.dialogAndStressEntries`, so a visual stress browser exists for Embedded/Window too.
- ~~Landscape banner-wide column divergence is not gated by any test at all~~ — **CLOSED same day**,
  see the entry above (`BannerWidthDivergenceTests`). Still parked as a defect; closing IT needs a
  feedback pass, not just a code change — only the missing-gate half of this bullet was the gap.
- **`variant-subtitle-customview`** — the one `.notRenderable` entry in the whole catalog (26 real +
  28 stress + 4 variants + 5 divergence = 63 total). WON'T FIX, not can't: an arbitrary `UIView`
  can't cross a `Sendable` descriptor boundary; the bespoke-view route (`register(_:view:)`) already
  covers the real use case (see `badge-detail-popup`). `SwiftUICatalog+Variants.swift:106-119`.

---

## Summary

Nothing above is a functional regression or a silent gap — every divergence is either measured and
labeled ACCEPTED/DEFECT/CLOSED with a citation, or is a deliberate design decision with a test
pinning the decision. `.capsule`/`.capsuleOutlined` (1.2) is CLOSED as of this session — it now
renders for real, not a counterfeit oblique/plain look. The two genuinely open ITEMS (as opposed to
gaps in test coverage) worth a look if this gets prioritized: **D-B's card-width mismatch** (defect,
unfixed, now gated at both the isolated-function and full-render level) and **the landscape
banner-wide column** (defect, parked, now gated) — both are geometry-rule bugs in
`ModalTokens.bannerGeometry`, not something a consumer would hit outside a banner +
non-matching-aspect-ratio combination. Neither is fixed by anything in this session — only "would a
regression here go unnoticed" changed, from yes to no.
