# Direction — SwiftUI is the product; UIKit is legacy

**Decided 2026-08-05 by the owner.** Recorded because every document in this module currently
assumes the opposite, and that assumption is load-bearing in test prose.

> **Keep UIKit. Mature SwiftUI. Delete UIKit.**

---

## 1. What this changes

Until now the stated goal was **parity**: mirror a frozen, shipping UIKit dialog and prove the
mirror faithful. The architecture serves that goal well — both backends run the *same*
`GBAlertModal.resolve` over the *same* `AlertHolder.make`, which is why resolution provably cannot
diverge and why several test docs say "by construction."

The destination is now **independence**: SwiftUI stands alone, UIKit is deleted. That makes the
shared pipeline **transitional scaffolding with an end date**, and it changes four things:

| | before | after |
|---|---|---|
| The differential gate | the permanent proof of correctness | a **migration tool**, retired with UIKit |
| "UIKit is frozen" | it is canonical; SwiftUI must match | it is legacy; it must not *change*, but it is not the target |
| A divergence | a defect in SwiftUI | **a question**: is UIKit right here, or merely first? |
| `Properties` | the configuration API | a UIKit-typed API the app must eventually migrate off |

## 2. The reframing that matters most

**Reproducing a UIKit bug is now anti-value.** Three findings on the current branch were filed as
SwiftUI gaps and are better read as UIKit defects SwiftUI correctly declines to inherit:

- **The landscape inset band (844×417…431).** UIKit's vertical compression there is
  *path-dependent* — the same modal at the same size yields an 18.67pt top inset over a 38.33pt
  subtitle laid out fresh, and 24.00 over 27.33 after passing through a smaller size. 16pt apart,
  because two constraints tie at `defaultLow` and Auto Layout's optimum is a tied face rather than a
  point. SwiftUI's layout is a pure function of (tree, proposed size) and *cannot* be path
  dependent. That is a feature.
- **`showsPrimary` resolved but not obeyed.** A real asymmetry — but the fix is to make the
  descriptor able to express "no primary button", not to teach SwiftUI UIKit's behaviour.
- **`bannerFixedHeight`.** Measured inert on both UIKit paths at every size tried. It is dead
  vocabulary that SwiftUI should never have carried.

Divergences still need to be *measured and explained*. What changes is the default conclusion.

## 3. The boundary

`Core/` — `AlertDialog`, `ModalStyle`, `ModalImage` — is **already UIKit-free** and enforced by
`CorePurityTests`. That is the shared foundation and it stays shared.

Everything else splits. For the SwiftUI half to contain no UIKit it needs its own:

| what | why it cannot be shared |
|---|---|
| configuration type | `Properties` is 18 `UIColor`, 6 `UIFont`, 3 `UIEdgeInsets`, 3 `NSLayoutConstraint`. **DONE — `ModalProperties`, Pass 3b** |
| ~~resolver~~ | ~~`ResolvedModal.buttonAxis` is `NSLayoutConstraint.Axis`~~ — **no second resolver was needed; see §5's Pass 3c** |
| text measurement | `Font` cannot report a line height, so a `UIFont` is kept to measure with. ~~CoreText can measure without UIKit~~ — **measured false for the multi-line case, see §3b.** `ModalFont` (Pass 3a) makes the drawn and measured font ONE value |
| axis | currently bridged at one call site |
| orientation source | ~~`UIScreen.main`~~ — **deleted in Pass 1**; it never reached a renderer, and there was no environment to read a real one from |
| ~~four bespoke views~~ | ~~text input, date picker, badge, loading all delegate to `UIKitModalRenderer` because descriptors cannot carry a `UIView`~~ — **MEASURED FALSE, see §3d** |

## 3d. The bespoke views were never delegating. SwiftUI is the RICHER half

**Measured 2026-08-06, at the start of Pass 4.** §3's last row said text input, date picker, badge
and loading "all delegate to `UIKitModalRenderer` because descriptors cannot carry a `UIView`". That
is false, and appears to have been false when it was written:

- `SwiftUIModalRenderer+InputViews.swift` (225 lines) and `+BespokeViews.swift` (448 lines) are
  **native SwiftUI**. Neither imports UIKit. There is no `UIViewRepresentable` anywhere in `SwiftUI/`.
- `registerBuiltInDescriptors()` registers a `view:` for all five bespoke descriptors, and
  `ModalHost` draws that view in preference to anything else.
- **UIKit is the poorer half here, and its own source says so.**
  `UIKitModalRenderer.registerBuiltInDescriptors`: "`BadgeDialog`'s badge GRID has no UIKit content
  view in this library (SwiftUI draws it with `BadgeModalView`), and `LoadingDialog.isLoading` has no
  UIKit expression at all."

What the SwiftUI half genuinely still uses `UIKitModalRenderer` for is the **holder factories**
(`TextInputHolder.make` and friends) — producing the `DataHolder` the SHARED resolver consumes. That
is not a rendering delegation; it is the mechanism that makes both backends decide identically, and
Pass 3 deliberately kept it (§5's Pass 3c).

**This is the fifth factual error found in this spec family** (four were corrected in Pass 1's §0),
and all five are the same defect: a statement about the boundary that nothing re-checked. So Pass 4's
deliverable is an ENFORCEMENT rather than a port — `SwiftUIPurityTests` names every file in
`SwiftUI/` permitted to import UIKit, with the reason and the pass that removes it, and fails both
when the list grows and when an entry goes stale. `AlertModalScaffold.swift` was found carrying an
`import UIKit` it did not use, which is exactly how an allow-list becomes a fiction.

**The remaining UIKit surface in `SwiftUI/`, in full, is now that allow-list:** `ModalFont` and
`ModalTokens` (permanent — §3b measurement, and `Properties` is the app's API per §6a),
`AttributedTextBridge` (permanent while `Properties` is — naming both attribute scopes is its job),
and `SwiftUIModalRenderer` (Pass 5, blocked on the gate retiring).

## 3a. The SwiftUI config mirrors `Properties`' VOCABULARY, not its types

**Decided with §1.** The SwiftUI-native configuration keeps the same field names and the same
concepts as `GBAlertModal.Properties`, so a call site moving from UIKit to SwiftUI recognises every
line and only the types change. It is a **parallel type, not a translation layer** — nothing
converts at runtime, and neither side imports the other.

"More or less" is accepted: where the two worlds genuinely differ, the SwiftUI type is allowed to
differ, and where a UIKit field is dead it is **not** carried over.

Of the 29 public fields, roughly half need no change at all — `CGFloat` is CoreGraphics and `Bool`
is `Bool`. Only these actually move:

| `Properties` (UIKit) | SwiftUI mirror | note |
|---|---|---|
| `baseTint`, `overlayColor`, `titleColor`, `subtitleColor`, `closeButtonTint`, `backgroundColor` — `UIColor?` | `Color?` | direct |
| `titleFont`, `subtitleFont` — `UIFont?` | `Font?` **plus a way to measure** | the caller never sees a `UIFont`, but measurement moves inside via `UIFont` — **not** CoreText (§3b). A bare `Font?` is not enough: see the open question in §3b. |
| `margin` — `UIEdgeInsets?` | `EdgeInsets?` | direct |
| `padding` — `UIMinMaxEdgeInsets?` | own `MinMaxEdgeInsets` | SwiftUI has no min/max inset type; this one is genuinely ours either way |
| `buttonActionOrientation` — `NSLayoutConstraint.Axis?` | `Axis?` | already bridged at one call site today |
| `primaryActionStyle`, `secondaryActionStyle` — `ActionStyle?` | own `ActionStyle` | same four cases, `Color`-based themes |
| `contentProperty` — `ContentProperty?` | same shape, `Color` inside | nested, same field names |
| `bannerRatio`, `bannerMaxHeight`, `cornerRadius`, the four width fields, `space`, the `Bool`s | **unchanged** | `CGFloat`/`Bool`/own types |

**Deliberately NOT carried over:**

- **`bannerFixedHeight`.** Measured inert on both UIKit paths at every size tried — it loses to
  hugging (250) going up and to compression resistance (750) coming down. Dead vocabulary; the
  SwiftUI type should never have it. This is the model case for "more or less."

Any further omission needs the same standard: a measurement showing the field does nothing, not an
opinion that it looks redundant.

**That standard was applied once more in Pass 3b and the answer came out the other way.** Two of
`ActionStyle`'s four cases — `.capsule` and `.capsuleOutlined` — are never read by the SwiftUI
backend: `ModalTokens` derives colours from `.obliqueBottomLeft` (primary) and `.plain` (secondary)
only, and a consumer shipping `.capsule` already gets the oblique look
(`test_accentColors_keepStandardLiterals_whenActionStyleIsNotOblique`). Dropping them from
`ModalProperties` was considered and **rejected**: `bannerFixedHeight` earned its omission by doing
nothing *on UIKit's own path*, whereas `.capsule` is inert only because the SwiftUI RENDERER has not
implemented it. Carrying two cases would bake a renderer gap into the vocabulary and narrow what a
migrating call site can say — the opposite of what this type is for. All four are carried.

## 3b. Measurement stays on `UIFont`. CoreText was measured and rejected

**Decided 2026-08-05, after Pass 1 measured it.** The rule in §3a is *same vocabulary, own language* —
`UIFont` for UIKit, `Font` for SwiftUI, two parallel types with no derivation between them. That rule
governs the CONFIGURATION SURFACE. It says nothing about how the library measures internally, and the
two must not be conflated: measuring is not vocabulary.

CoreText was the plan for making SwiftUI's measurement UIKit-free. On-device, at the real preset's
256pt column:

| | `boundingRect` (UIKit/TextKit) | CoreText | delta |
|---|---|---|---|
| `UIFont.lineHeight` vs `CTFont` ascent+descent+leading | 19.09375 | 19.09375 | **0.0 — bit-identical** |
| `longTitle` @ 24pt bold | 171.84375 | 174.0 | −2.16pt |
| `longTitle` @ floored 18pt | 85.921875 | 85.0 | **+0.92pt** |

Single values agree exactly. **Multi-line wrapping does not**, and cannot: `boundingRect` runs
TextKit's line-fragment layout, `CTFramesetter` runs CoreText's own typesetter, and they choose
different break points. The module's working tolerance is 0.5pt. Worse, CoreText *under*-measures at
floor scale, which is the one direction that reintroduces the clipping the floor exists to prevent.

So: **the SwiftUI half measures with `UIFont`, internally, indefinitely.** The contract is behaviour
parity, and using the same measurement engine as UIKit is what guarantees it. Swapping engines would
have traded a real guarantee for a lower import count.

**This narrows what Pass 5 can mean.** "The SwiftUI path touches no UIKit" is achievable for the
*vocabulary* — no `UIColor`, `UIFont` or `UIEdgeInsets` in any type a caller names — and not for the
internals, by measurement rather than by choice. §5's Pass 5 should be read that way.

**~~The open question this leaves for Pass 3.~~ ANSWERED, in Pass 3a — `ModalFont`.**

The question was: today the split works because the INPUT is a `UIFont`, and `init(from:)` derives
`Font(titleFont)` to draw with while keeping `titleFont` to measure with. A SwiftUI-native config
hands the library a `Font?`, which is opaque with no `Font -> UIFont` direction — so the library
could render the caller's font but not measure it. Keeping a twin does not help; there is nothing to
keep a twin *of*.

The answer is to stop trying to keep two things in step and **invert which one is stored**.
`ModalFont` stores the `UIFont` and DERIVES the `Font` through the platform's own bridge. The caller
states `.system(size:weight:)` or `.custom(_:size:)` — `Font`'s own factory spelling, no UIKit type
named — and gets one value with two projections. The drawn font and the measured font are not two
values that agree; they are one value.

**This was not only forward-looking — it removed a live hazard.** `ModalTokens` carried
`titleFont: Font` and `titleUIFont: UIFont` as separate stored properties. `init(from: Properties)`
set both from the one `Properties.titleFont` and could not drift, but the memberwise init took only
the `Font`, so `ModalTokens.standard` stated `.system(size: 24, weight: .bold)` and let the `UIFont`
keep its own default — the same face, typed twice, kept equal by hand and guarded by a test. The
drift that test protected against is now unwritable.

Two smaller consequences worth recording:

- **`ModalTokensTests`' two font-provenance tests got STRICTER.** They compared
  `tokens.titleFont == Font(font)` — both sides through the same bridge, which the tests' own note
  admitted could not catch a bridge that dropped size or weight. The token now holds the caller's
  `UIFont` verbatim, so they assert identity against the original.
- **A missing custom face falls back to the system font, deliberately.** `UIFont(name:size:)` returns
  nil where `Font.custom` silently draws the system font; measuring anything else would reintroduce
  the drawn-one-thing / measured-another bug in the one case it is easiest to miss.

Still ruled out, unchanged: "accept `Font?` and reconstruct a measurement font by guessing" — that is
exactly the guessed measurement the numbers above show the cost of.

## 3c. `ModalTokens` has no external consumer — the §6a constraint does not reach it

§6a is right that `Properties` must stay public and working indefinitely: it is the app's live API and
removing a field is a source break for a consumer this repo cannot edit.

**That reasoning does not extend to the SwiftUI half.** Grepped across this repo, the example app, and
both `geniebook-student-ios` checkouts: `ModalTokens`, `SwiftUIAlertModal` and `SwiftUIModalRenderer`
have **zero** references outside the library and its own tests. The app is entirely on the UIKit
`Properties` path. `titleUIFont` and `subtitleUIFont` were `public` only because the struct was
declared that way — no caller ever read or wrote them, and Pass 1 made them internal at zero cost to
anyone.

So the SwiftUI surface is free to be reshaped right now, without staging or deprecation. That is a
materially stronger position than "everything public is a contract," and Pass 3 should plan on it
rather than protecting a compatibility that does not exist.

## 4. The descriptor gap — ~~one problem~~ THREE, with three different answers

**Corrected 2026-08-06, in Pass 2.** This section said the nine `notRenderable` entries, the
`showsPrimary` divergence and the four bespoke delegations were **one problem** and that "closing it
collapses all three at once." They shared a symptom — the UIKit gallery entry reaches past the
descriptor — and had nothing else in common:

| | entries | answer |
|---|---|---|
| **(a)** cannot say "no primary button" | 6 stress + the `showsPrimary` divergence | genuinely missing vocabulary. **Fixed** |
| **(b)** cannot carry a `UIView` | 1 (`variant-subtitle-customview`) | **WON'T FIX** — costs `Sendable`; `register(_:view:)` already serves it |
| **(c)** no presentation-state channel | 2 (button enable/disable) | the channel already existed. **Fixed** |

So Pass 2 closed **eight of nine**, not nine, and (b) is now a recorded decision rather than a gap.

**(a) — `StandardAlertContent.primary` is `String?`.** Nothing on the UIKit side changed to accept
it: `DataHolder.primaryAction` was already `String?`, so `nil` reaches `resolve`, which reports
`showsPrimary` false, which `buildActionComponents` has always obeyed. The five bespoke descriptors
keep a required primary — none has a buttonless shape.

`SwiftUIAlertModal` now passes `resolved.showsPrimary ? config.primary : nil`, which closes the
`showsPrimary`-resolved-but-not-obeyed divergence as a side effect. All eleven resolver fields are
resolved AND obeyed.

**(c) — no new channel was needed, and looking for one was the mistake.** `ModalRenderer.update(_:to:)`
already rebuilt a live presentation on both backends, so presentation state belongs ON the descriptor:
`AlertDialog.primaryEnabled`/`secondaryEnabled` (`ButtonEnablement`). The UIKit renderer makes the
same two `changeXActionEnableState` calls the gallery makes by hand, *after* its rebuild.

This costs the claim that "a descriptor carries content and style, not presentation state" — which
`LoadingDialog.isLoading` had already falsified. It is false on purpose now.

**What Pass 2 did NOT touch:** the four bespoke delegations. Those were called Pass 4, and grouping
them here was part of the same over-collection — which turned out to matter twice over, because
Pass 4 then measured them not to be delegations at all (§3d).

## 4a. The real work in Pass 2 was the SPACING, and it was invisible until then

Making the primary button absentable is three lines of vocabulary. What it cost was two layout rules
that had been **vacuously true** for as long as every descriptor carried a primary button:

- **A lone secondary must not carry the inter-button gap.** SwiftUI's vertical button run hand-rolls
  what `UIStackView.spacing` does, as a `.padding(.top, interButton)` on the secondary — and stack
  spacing applies only BETWEEN arranged subviews. Measured cost of getting it wrong: 8pt.
- **Every row's trailing gap is conditional on a row existing below it.** That is exactly what UIKit's
  `buildDividers` computes (`vwBannerAndBelowDivider`, `vwTitleAndBelowDivider`,
  `vwSubtitleAndBelowDivider` each exist only when a later component was built), and
  `SwiftUIAlertModal` applied all three unconditionally. Measured cost: 16pt on the subtitle.

Neither is visible from the descriptor change. Both were found by reading `GBAlertModal+ViewGraph.swift`
before writing any SwiftUI, which is the ordering Pass 1 established and this pass reused deliberately.

**Three shapes were added to the differential gate** — `no-primary-secondary-only`,
`no-buttons-title-subtitle`, `no-buttons-title-only` — and the third exists only because the second
cannot see the title's gap (its subtitle satisfies the condition either way). Both rules are
mutation-verified.

**One thing the gate could not do, and it is worth recording alongside §6's blindness note.**
Enable-state has no geometry: a disabled button occupies the same frame as an enabled one, so
`assertAgrees` is green through the entire (c) feature and can never gate it. `ButtonEnablementTests`
is a separate, non-geometric gate for that reason — the differential harness is not a universal net,
and the failure mode here is *absence of signal* rather than the common-mode *sameness of signal* §6
describes.

## 5. Staged path

Each pass leaves the suite green and the gate meaningful, so a regression is attributable.

**Pass 1 — leaves. DONE**, but not as written — see the Pass 1 brief's §0. CoreText was measured and
rejected (§3b); the `UIScreen` read was deleted rather than rehomed, because it never reached a
renderer and there was no environment to read from; and the real find was that the title floor
measured `String(title.characters)`, discarding per-run fonts the view draws. Golden absolute pins
landed alongside, after the mutation run in §6 showed the gate could not see a moved floor.

**Pass 2 — the descriptor gap. DONE**, and it was three problems rather than one — see §4 for the
correction and §4a for what the layout work turned out to be. `primary` is optional, descriptors carry
button enable-state through the `update(_:to:)` channel that already existed, and one entry is closed
as WON'T FIX. Eight gallery gaps and one divergence, not nine.

**Pass 3 — the core.** Split into three, because it is much larger than 1 or 2 and its riskiest
question deserved to be decided on its own evidence rather than inside a 600-line diff:

- **3a — `ModalFont`. DONE.** The §3b open question, answered above. Self-contained, and it paid for
  itself immediately by collapsing a real hand-maintained coincidence in `ModalTokens`.
- **3b — `ModalProperties`** (the §3a vocabulary mirror) **and `ModalTokens.init(from:)` beside it.
  DONE.** Gated exactly as planned: `ModalPropertiesEquivalenceTests` builds ONE preset both ways,
  every field set to a DISTINCT value, and asserts the two derived `ModalTokens` are equal.
  Mutation-verified against both real failure modes — a field read into the wrong token, and a
  dropped field — each killed by that one test and nothing else.

  Four things worth carrying forward:

  - **`ModalTokens` is now `Equatable`** (with `Palette` and `UIMinMaxEdgeInsets`). That is what
    makes the gate one assertion instead of twenty-five field checks — and a field-by-field test
    would have been a THIRD copy of the same list, wrong the same way if its author misread the
    source.
  - **The gate cannot speak to colour identity, and says so.** `Color(uiColor: .red) != Color.red`
    (different providers), so the SwiftUI preset states its colours as `Color(uiColor:)` of the very
    `UIColor` the UIKit preset gets. It proves both derivations route the same colour to the same
    token; it does not prove the two spellings render alike, which is a platform question.
  - **`bannerFixedHeight` is the only permitted difference**, pinned by its own test so the equality
    can be unqualified.
  - **"An empty config derives `standard`" is FALSE**, and asserting it was my first version of that
    test. `standard` ships a 160pt `bannerMaxHeight`, and both derivations assign the banner fields
    unconditionally because `nil` there means "install no such constraint". An empty config derives
    `standard` MINUS the banner fields.
- **3c — feeding the shared resolver. DONE, and it stops one step short of where it aimed.**

  `ModalStructureInputs` (in `Core/`, Foundation only) carries the five fields, both configurations
  conform, and `GBAlertModal.resolve` takes it. The old `resolve(properties:)` signature is kept as
  a forwarder, so no existing call site or public API moved. `SwiftUIAlertModal.properties` widened
  to `(any ModalStructureInputs)?`, which means **the public SwiftUI view can now be built without
  naming a single UIKit type**: `ModalProperties` for structure, `ModalTokens(from:)` for styling.

  `buttonsAreHorizontal` is a `Bool`, not `NSLayoutConstraint.Axis` — the axis has exactly two
  cases, so `orientation ?? .vertical` and "is it horizontal" are the same statement, and a
  UIKit-typed protocol requirement would have dragged `import UIKit` into the one file whose job is
  not to need it. `resolve` maps it back, because `UIStackView.axis` takes exactly that type.

  **What it does NOT deliver: `SwiftUIModalRenderer` still takes `GBAlertModal.Properties`.** The
  obstruction is real and worth recording rather than working around. `SwiftUIModalRenderer.Factory`
  returns `(GBAlertModal.Properties?, DataHolder)` and is **deliberately source-identical to
  `UIKitModalRenderer.Factory`** — a property the parity suite asserts structurally
  (`RendererParityTests`, and `RendererFixtures`' "the two branch bodies are LITERALLY THE SAME
  EXPRESSION"). Widening it to carry either vocabulary breaks that tested invariant.

  That invariant exists to serve the differential gate, which §6 already schedules for deletion at
  Pass 5. So the renderer's config vocabulary is **blocked on the gate retiring**, not on design —
  a Pass 5 dependency §5 did not anticipate. Deferred deliberately: breaking a tested parity claim
  to reach a milestone early is the trade this project has consistently declined.

**"and resolver" is struck, and this pass no longer costs "by construction".** The original plan
assumed a SwiftUI-native config forces a second resolver. Measured instead: `GBAlertModal.resolve`
reads exactly FIVE things from `Properties` — `primaryActionStyle` and `secondaryActionStyle` for
their NIL-NESS only, plus `buttonActionOrientation`, `buttonActionShouldMatchParent` and
`contentProperty`. Everything else comes from the holder. A small protocol carrying those five,
satisfied by both config types, keeps ONE resolver and both backends provably deciding identically.

That matters more than it looks: §6 measured the differential gate to be common-mode blind and
**already at its structural ceiling**, so "land Pass 3 after the gate is at its strongest" was
buying a safety net that cannot catch this class. Keeping the shared resolver is not a shortcut —
it is the only guarantee available.

`ResolvedModal.buttonAxis` staying `NSLayoutConstraint.Axis` does not violate Pass 5 either:
`ResolvedModal` is not a type a caller names, and the axis is already bridged at one call site.
`AlertHolder.make` stays for the same reason — internal, caller-invisible, and the mechanism that
makes both backends resolve the same way.

**Pass 4 — bespoke views. DONE, and there was nothing to build.** ~~Native SwiftUI text input, date
picker, badge, loading.~~ All four already were — see §3d for the measurement. SwiftUI is the richer
half of the two, and `UIKitModalRenderer`'s own source says so.

So the deliverable became an ENFORCEMENT of the boundary instead of a port to it:
`SwiftUIPurityTests` names every file in `SwiftUI/` permitted to import UIKit, with a reason and the
pass that removes it, and fails **both** when the list grows and when an entry goes stale. It also
names the two bespoke-view files explicitly and checks for `UIViewRepresentable`, so the specific
claim §3 got wrong is pinned to the specific test that corrects it.

That check immediately found `AlertModalScaffold.swift` importing UIKit and using zero UIKit symbols
— a dead import, deleted. **This is the point of the pass:** five statements in this spec family have
now been measured false, and every one was a description of the boundary that nothing re-checked. The
allow-list is the first version of that description which cannot rot.

**Pass 5 — be READY to retire UIKit.** **Briefed: `2026-08-07-uikit-retirement.md`.** *Gained a
dependency from Pass 3c: `SwiftUIModalRenderer`'s configuration vocabulary cannot move until the
differential gate retires, because `Factory`'s source-identity with the UIKit renderer is a
parity-tested invariant. Sequence the gate's deletion BEFORE the renderer's config change, not after.*

*The brief adds two things this entry did not anticipate. (a) The shared `DataHolder` — 17 call sites
in `SwiftUI/`, carrying `UIImage?`/`UIView?` — has to go in the SAME pass, because its justification
(both backends must resolve identically) expires with the gate and never becomes retractable again;
without that, "a module split is a manifest edit" is unreachable. (b) The acceptance test is a
COMPILE-TIME one: `GBAlertModal.resolve` is `nonisolated` but currently unreachable off the main actor
from the SwiftUI half, because every holder factory is `@MainActor`. If a SwiftUI presentation can be
resolved off the main actor afterwards, the coupling is genuinely gone.* Not "delete UIKit": this repo cannot do that on its own, and
the app is out of scope (§6a). The deliverable is a library where the SwiftUI path touches no UIKit
**in its vocabulary** — no `UIColor`, `UIFont`, `UIEdgeInsets` or `NSLayoutConstraint.Axis` in any
type a caller names — and the UIKit half is inert, deletable the day the app stops importing it, by
someone else, on someone else's schedule.

**"Vocabulary" is the operative word, and it is a measured limit rather than a concession** (§3b):
text measurement stays on `UIFont` internally because the UIKit-free alternative provably changes the
numbers, and behaviour parity outranks import count. A file's `import UIKit` line was never the goal
either — `SwiftUIAlertModal.swift` has no such import today and calls `UIKitModalRenderer` anyway.
The goal is that a caller never has to name a UIKit type, and that a future module split is a
manifest edit rather than a refactor.

## 6. Consequences to accept

- **"By construction" becomes an empirical claim at Pass 3.** Every test doc using that phrase needs
  re-checking then, not now.
- **The differential gate has an end date.** It is the safety net for Passes 3–4 and is deleted at
  Pass 5. Its measurements — the geometry rules, the truth table, the divergence catalogue — outlive
  it as documentation of what the shipping dialog did.
- **The gate is COMMON-MODE BLIND, and this is structural.** Measured in Pass 1: flipping
  `titleMinimumScaleFactor` from 0.75 to 0.70 — a 5.7pt move in the pressured title's floor — passed
  **517 of 518 tests**, the whole differential harness included. The one failure was the assertion on
  the literal `0.75`.

  The reason is not thin coverage. `ModalLayout.textHeight`, `subtitleFloorHeight` and
  `titleMinimumScaleFactor` are called by BOTH backends, so a change inside any of them moves both
  arms of the comparison equally, the difference stays zero, and every shape stays green. A
  differential cannot detect drift common to both arms; no number of extra shapes fixes it.

  The gate is therefore weaker than §5's "land Pass 3 after the gate is at its strongest" assumes —
  it has a structural ceiling and is already at it. What catches common-mode drift is the golden
  absolute pins added in Pass 1 (`test_theMeasurementsThemselves_arePinnedAbsolutely`), which are
  backend-independent and survive the gate's deletion. **Invest in those, not in strengthening the
  gate.**

## 6a. The app is READ-ONLY to this work

`geniebook-student-ios` is a **reference, never a target.** Read it to establish facts — what
`Properties` values the real presets use, what point sizes the real artwork is, which fields are
actually set. Never plan or make a change to it.

Two consequences:

- **`Properties` stays, working, indefinitely.** It is the app's live API. The SwiftUI-native config
  (§3a) lands *alongside* it, not instead of it. Nothing is removed from `Properties` on a schedule
  this repo controls — including `bannerFixedHeight`, which is dead but stays public because
  removing it is a source break for a consumer that is not ours to edit.
- **"Ready" is the finish line, not "deleted."** Success is: SwiftUI complete, independent, and
  proven; UIKit present but untouched by it. Whether and when UIKit is actually removed is a
  decision made elsewhere, with the app's migration.

This is also why the geometry measurements matter beyond this branch: they are the evidence an app
team needs to trust the swap, and they were taken against the real presets and the real artwork.

## 7. What is NOT in scope

- Changing UIKit. It stays frozen until it is deleted. Frozen now means *legacy*, not *canonical*.
- Reproducing UIKit defects in SwiftUI (§2).
- Re-litigating the measurements. The geometry rules and the divergence numbers are evidence and
  survive the reframing intact.
