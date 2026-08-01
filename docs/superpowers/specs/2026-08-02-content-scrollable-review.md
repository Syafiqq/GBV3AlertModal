# Brief — `contentScrollable`: keep, remove, or rework?

**Status:** shipped but INERT. Nothing opts in.
**This is a decision brief, not an implementation plan.** The first question is whether the feature
should exist in its current form; only then does "finish it" make sense.
**Branch:** `feat/modal-executor-capability`. Library 469 green, example green.

---

## 1. What it is

`Properties.contentScrollable` (default `false`) → `ModalTokens.contentScrollable` →
`SwiftUIAlertModal.textRows` wraps **title + subtitle** in `ScrollableContent`. Buttons and the close
button stay outside, so an action is always reachable. **SwiftUI only** — UIKit keeps its
subtitle-only `svSubtitleContainer` because the app consumes this module as an SPM dependency and its
UIKit half is the shipping dialog.

`ScrollableContent` measures its content's ideal height and applies `.frame(maxHeight: ideal)`, so:

- content fits → the scroll is exactly its content's height, i.e. **provably inert**, identical to no
  scroll at all (this is why all 26 shapes and the differential gate stayed green);
- content overflows → the viewport shrinks and the content scrolls at full size.

## 2. Why it was built — and why that reason has largely evaporated

It was built to fix the **sliced subtitle**: under a landscape card the subtitle slot settled at
~14pt of a 19.1pt line, so body text was drawn with its bottom half cut off.

Then the vertical card margin was zeroed (owner's call), which raised the landscape ceiling 214 → 294
and the popup content budget 174 → 254. **That fixed the real shapes outright** — the popup
two-button landscape dialog, the shape the lesson screens actually present, now renders title, full
two-line subtitle and both buttons with no slicing, no shrink and no scroll.

What still slices is `longTitle` landscape: a **139-glyph synthetic fixture**. No real call site has
been found that reaches it.

**So the honest position: the scroll solves a problem the margin change already solved for every
shape anyone has produced.** That is the case for removing it.

## 3. What it costs, stated plainly

**Coverage is thin** — 4 library tests + 1 differential row + 1 example snapshot, against 469 tests
for the default path:

| gated | not gated |
|---|---|
| scroll engages under pressure | landscape (the scrolling row is portrait only) |
| the flag is what engages it | the `.subtitle` element **cannot** be compared — UIKit's probe is on the scroll VIEWPORT (645.3), SwiftUI's on the `Text` CONTENT (1222.0); SwiftUI has no per-subtitle viewport |
| the banner stays outside the scroll | any production preset — nothing opts in |
| a premise test proving the shape really scrolls | |

**It contradicts the option that was chosen.** Asked "does the title still shrink?", the answer was
*"keep the shrink, scroll only as last resort"*. Inside a `ScrollView` the content is offered
unbounded height, so `minimumScaleFactor` **never fires** — the title renders full size and scrolls.
That is option 1 ("drop the shrink"), delivered under the label of option 2. Not a bug; a design
outcome nobody has signed off.

**The fold is a substitute, not the thing asked for.** A scroll viewport ends mid-line, which looks
like the slicing this work set out to remove. A whole-lines snap is **not expressible** — the fold
can land in the 24pt title or the 16pt subtitle and SwiftUI exposes no per-line geometry. What ships
is a 12pt gradient mask so the cut line fades. **It did not fail its own snapshot** at
`precision: 0.98` — 12pt of gradient is under the 2% tolerance — so it is confirmed only by a forced
re-record and a human looking at it. A guard that cannot see its own subject.

## 4. The three options

**A — Remove it.** Delete `ScrollableContent`, the `textRows` split, the `Properties`/`ModalTokens`
field, 4 tests, 1 snapshot, 1 differential shape. Justification: the margin change fixed the real
shapes; nothing opts in; it carries a behavioural surprise and a limitation that cannot be closed.
Cost: the synthetic `longTitle` landscape shape goes back to slicing, and a genuinely long-copy
dialog in future has no answer.

**B — Keep as-is, inert.** Zero risk today (default off, provably inert when content fits). Cost: a
feature nobody uses, lightly covered, that will drift. If kept, it needs the §5 work before any
preset turns it on.

**C — Keep and finish.** Do §5, then have design sign off the shrink-vs-scroll behaviour on a real
preset.

**Recommendation: A or B, and A if nobody can name a shape that needs it.** The strongest argument
for removal is that the feature's motivating defect no longer reproduces on any real shape.

## 5. If it is kept, what is outstanding

1. **Landscape differential coverage** for the scrolling shape —
   `assertAgrees("long-subtitle-scrolling", size: DifferentialGeometry.landscapeHost)` and see what
   it says.
2. **Decide the `.subtitle` probe.** Today it compares a viewport against content and is pinned by
   mechanism (`uiKit.height < swiftUI.height`). Either give SwiftUI a per-subtitle viewport, or
   redefine what `.subtitle` means on a scrolling shape.
3. **Reconcile the shrink.** Either accept scroll-instead-of-shrink and record it as the decision, or
   make the title shrink to fit the viewport before scrolling — which needs the viewport height fed
   to the text rows *without* creating a measurement cycle (see the trap below).
4. **Make the fold testable.** Either drop snapshot precision for that one shape so a fade change
   fails it, or assert the mask directly. As it stands it is verified by eye only.
5. **Decide the whole-lines question.** If a mid-line fold is unacceptable, the fade is not the
   answer and the viewport must snap — which needs per-line geometry SwiftUI does not expose, so it
   likely means measuring text manually via `ModalLayout.textHeight`.

## 6. Where the code is

| what | where |
|---|---|
| the wrapper | `SwiftUI/ScrollableContent.swift` |
| the opt-in branch | `SwiftUI/SwiftUIAlertModal.swift` — `textRows` / `titleAndSubtitle` |
| the flag | `Core/…/GBAlertModal+Properties.swift`, `SwiftUI/ModalTokens.swift` |
| library tests | `TitleSubtitleTruncationTests` (scroll engages, opt-in, banner outside) |
| differential | `DifferentialGeometrySupport` shape `long-subtitle-scrolling`; `DifferentialGeometryTests` row + premise |
| example snapshot | `SwiftUIAlertModalSmokeTests.test_snapshot_scrollable_landscape_noBanner` |

## 7. Traps already sprung here — do not re-derive them

- **The banner must NOT go inside the scroll.** It was tried. Inside a scroll nothing competes for
  space: each row takes its natural size in order, so the banner — first and largest — took the whole
  viewport and pushed title and subtitle out of sight. That inverts "banner never wins" exactly where
  it matters. Scoping the scroll to the text rows is what fixed it.
- **Measurement cycles.** A banner ceiling derived from the scroll viewport — which is sized from the
  content the ceiling bounds — is a cycle, and layout built on a cycle settles somewhere arbitrary.
  If a size must be measured, measure the CONTAINER, never the content it constrains.
- **`ScrollView` multi-view content gets an implicit stack with default 8pt spacing.** Cost an 8pt
  shift on all eight differential shapes until an explicit `VStack(spacing: 0)` was added.
- **A vacuous differential row passes.** The scrolling shape's subtitle was 611pt at twenty
  repetitions and the portrait card simply FIT it — slot 611.0 == content 611.0, scroll never
  engaged, row green. `test_theScrollingShape_actuallyScrolls` exists because of that; forty
  repetitions engage it.
- **Debug the fixture before the layout.** Three failed diagnoses of "the secondary button vanished"
  were all one cause: a bare `GBAlertModal.Properties` in the test fixture. `resolve` gates each
  button on BOTH its title and its `ActionStyle`, so a bare `Properties` drops the secondary by
  design. Use a real preset (`GalleryPresets.popupProperties.copy(...)`).
