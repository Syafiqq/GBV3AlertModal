# SwiftUI Tier 1 — Design

**Date:** 2026-07-29
**Branch:** `feat/modal-executor-capability` (unmerged, 100 commits)
**Supersedes/extends:** `2026-07-28-swiftui-alert-modal-surface-design.md` (revises D8), `2026-07-28-remaining-work-roadmap.md` (§C)

---

## 1. Scope

Build the native SwiftUI rendering path — renderer, executor integration, coordinator parity —
into the library, with test-group parity against the existing UIKit suite and a comparison
strategy that does not lean on screenshots.

**Constraints (owner-set, non-negotiable):**

- All work happens in **this** repository.
- `geniebook-student-ios-distribution` is a **read-only source of truth**. It is mined for real
  presets, colours, strings and dialog shapes. It is **never modified**.
- Screenshot/pixel comparison is a **last resort**, not the primary proof.
- Completion criterion: each step closes out its test group the way the UIKit groups did.

**Out of scope:** app migration; any change to the distribution app; Tier-1 adoption by a real
screen (no such screen exists yet).

### 1.1 Dissent on record

A five-member council (Torvalds, Kahneman, Taleb, Rams, Lao Tzu) voted **5–0 against** building
Tier 1, on the grounds that its gate question — *"do SwiftUI screens need modal content authored
in SwiftUI, or just to trigger dialogs?"* — has never been answered by a real screen, and that
two renderers at pixel parity is an unbounded maintenance liability.

The owner has overridden this. It is recorded here so the trade is explicit, not forgotten:
**we are accepting a permanent two-renderer parity cost in exchange for a SwiftUI-native path
that no consumer has yet requested.** The comparison strategy in §5 exists specifically to make
that cost payable rather than merely hoped-for.

---

## 2. Decisions

### Settled

| # | Decision | Rationale |
|---|---|---|
| **T2** | Geometry extraction = **in-view measurement harness (frames) + narrow CALayer reads (shadow/corner)** | Council 2–1 for the harness (Ada, Torvalds); Feynman's dissent for a hierarchy walk is *complementary*, not contradictory — frames structurally cannot express the defect class that actually shipped (offset shadow mistaken for a corner cut). Both are adopted, each where it is strongest. |
| **T5** | **One target**, sources organised `Core/` `UIKit/` `SwiftUI/`, plus a test asserting `Core/` imports neither UI framework | Council split with **no consensus** (A 1.75 / B 1.5, threshold 2.333). Taleb's objection to splitting was falsified by inspection — all 12 executor/descriptor declarations are *already* `public` — but Rams' argument survives: a split serves a SwiftUI-only consumer who does not exist, at the cost of the UIKit consumer who does. Folders + purity test preserve Aristotle's (correct) categorisation as structure, reducing a future split to a manifest edit. |
| **T7** | **No resolver surgery.** SwiftUI calls `ResolvedModal.resolve(properties:holder:isLandscape:)` unchanged | The resolver reads `properties` in exactly five places, all presence checks or plain scalars — no `UIColor`, `UIFont`, or `UIImage` value. `AlertHolder.make` already provides `AlertDialog → DataHolder`. |
| **C-1** | **Delete `ResolvedAlert`; SwiftUI consumes `ResolvedModal`** | `ResolvedModal` is public, `Equatable`, 11 fields, 53 tests, and its docstring already names this use: *"later used as the SwiftUI equivalence spec."* `ResolvedAlert` is a 5-bool subset that exists only because the prototype was quarantined in the example app. Equivalence becomes true by construction rather than tested after the fact. |
| **T3** | Point the Tier-0 demo at `GalleryPresets`; delete `Tier0DemoStyle.swift` | `GalleryPresets` already mirrors the real app with citations. `Tier0DemoStyle` reinvented it (`.systemOrange`, `.systemIndigo`, fixed-300 width) and admits so in its own header. C-0 depends on the demo's input being the real preset. |
| **T4** | SHSans deferred | Irrelevant to C-0…C-3; gates only C-4. |

### Revised

**D8-revised — style identity is a token on the descriptor, not a descriptor type.**

D8 established *style identity = descriptor type*; `PopupDialog` exists as a content-identical
twin of `AlertDialog` for that reason alone. The 26-shape catalog falsifies the premise:

- Five distinct presets in production (`properties`, `popupProperties`, `badgeProperties`,
  `permissionAlertProperties`, `streakModalProperties`).
- Plus **per-entry overrides** — `obliqueBottomLeftRedTheme`, a custom `ComponentSpace` on
  `badge-detail-popup`, custom padding/space on `rename-worksheet` and `date-picker-worksheet`.

Under type-per-style the type count grows with the *design system* rather than the *content
shape*, requiring `BadgeDialog`, `PermissionDialog`, `StreakDialog`, `ObliqueRedDialog`,
`BadgeDetailDialog`… A `style:` token covers all 26 including the overrides.

**Consequence:** `PopupDialog` becomes redundant. It is retained for source compatibility on this
branch and marked for removal; it must not be joined by further style-twins.

> ⚠️ **Owner review required.** This reverses a decision previously ratified by council.

### Open

| # | Decision | Note |
|---|---|---|
| **T6** | How many of the 26 shapes must render in SwiftUI to call Tier 1 done? | Matrix in §6. **20** are standard content differing only by preset; **6** use `subtitleCustomView`, of which 2 already have descriptors. Recommend the 20 as the bar, with bespoke content and timer state explicitly deferred. |
| **T1** | Workstream order | Recommended W1→W6 (§4). |

---

## 3. Architecture

One target, three source regions:

```
Core/     descriptors, executor, token, coordinator, ResolvedModal, ModalText   (no UIKit, no SwiftUI)
UIKit/    GBAlertModal, Properties, DataHolder, UIKitModalRenderer, holders
SwiftUI/  SwiftUIModalRenderer, SwiftUIAlertModal, AlertModalScaffold, ModalButtonStyles, ModalTokens
```

A test asserts no file under `Core/` imports `UIKit` or `SwiftUI`. That is the enforcement
mechanism for the boundary; the module split is deliberately *not* purchased yet.

**Rendering path — identical up to the last step:**

```
AlertDialog (+style token)
   → AlertHolder.make          → DataHolder          [shared, 9 tests]
   → ResolvedModal.resolve(...)                      [shared, 53 tests]
   → UIKitModalRenderer   → GBAlertModal (UIView)
   → SwiftUIModalRenderer → SwiftUIAlertModal (View)
```

Both renderers consume the *same* resolver output. Divergence is therefore only possible in the
final render step, which is exactly what §5 measures.

**`ModalTokens` becomes a derived projection, not a transcription.** D8 originally dissolved
`Properties` into a hand-written `ModalTokens` because the quarantined prototype could not reach
`Properties`. That transcription is precisely what produced the wrong width, spacing and oblique
values that only a physical device caught. In the library, `ModalTokens` is constructed *from*
`Properties` (`UIColor → Color`, `UIFont → Font`, both lossless), so C-0 becomes a constructor
rather than a test, and the drift class is eliminated at its root.

**Topology invariant (prior council, unanimous):** never two peer renderers live at once — one
composite renderer, two backends, one coordinator. Module boundaries do not enforce this;
only the coordinator does. Preserved unchanged.

---

## 4. Workstreams

| # | Work | Exit criterion |
|---|---|---|
| **W0** | T3: Tier-0 demo → `GalleryPresets`; delete `Tier0DemoStyle` | Demo renders from the real preset |
| **W1** | Promote SwiftUI surface into the library; folder structure; `Core/` purity test; delete `ResolvedAlert`; `ModalTokens.init(from: Properties)` | Library builds; existing 239 tests still green |
| **W2** | `SwiftUIModalRenderer: ModalRenderer` — `present`/`update`/`dismiss`/`setHidden` | **C-2 runnable — first real parity evidence** |
| **W3** | Coordinator parity: serial / dedup / priority / interrupt / drain | The ~62 renderer-agnostic tests pass unchanged against the SwiftUI renderer |
| **W4** | Case-type coverage per T6, incl. the `style:` token | Agreed share of the 26 shapes renders |
| **W5** | Bundle SHSans | C-4 becomes meaningful for text |
| **W6** | Animation / transition parity, incl. no-blink in-place swap | Observed; snapshot where numeric assertion is impossible |

C-2 at the end of W2 is the earliest point at which "the SwiftUI path actually works" stops being
an assertion. If W2's parity run fails broadly, stop and reassess before W4 — that is the
cheapest available kill signal.

---

## 5. Comparison strategy

Premise: both renderers run **in the same process on the same descriptor**, and UIKit is the
shipping implementation. This is *differential* testing, not baseline recording — which is why
screenshots can be demoted. A recorded snapshot detects only drift from itself; it provably
cannot catch wrong-but-consistent design, and did not: the modal was snapshot-green while its
width, spacing and button style were all wrong.

| Rung | Method | Catches |
|---|---|---|
| **C-0** | Token provenance — `ModalTokens` derived from `Properties` | Transcription drift (eliminated by construction) |
| **C-1** | Shared `ResolvedModal` | Structural divergence (eliminated by construction) |
| **C-2** | ~62 renderer-agnostic tests parameterised over both renderers | Semantic divergence: present/update/dismiss/hide, result plumbing, serial/dedup/priority/interrupt/drain |
| **C-3a** | In-view `GeometryReader`/`PreferenceKey` harness → frames, compared to UIKit `.frame` within tolerance | Layout divergence: card, banner + aspect, labels, buttons + spacing, close button |
| **C-3b** | Narrow `CALayer` reads on the hosted tree — `shadowOffset`, `shadowRadius`, `cornerRadius` | Visual-property divergence — **the class that actually shipped broken** |
| **C-4** | Pixel diff, UIKit-render vs SwiftUI-render of the same shape | Only what has no numeric expression. Narrow. Blocked on W5 for anything containing text. |

**Scoping constraints:**

- Geometry diffing is **not** built for the ~62 renderer-agnostic tests. Parameterise those.
- The measurement sink is gated behind `#if DEBUG` so it never ships in release binaries.
- Instrumentation covers only named semantic elements that are already tolerance targets.
  Scope creep here is a discipline failure, not a design change.

**Known limits, stated rather than discovered later:**

- C-3a measures the view's *self-reported* layout, one level removed from what the OS lowers to.
  C-3b is the mitigation, deliberately reading the rendered layer.
- C-3b depends on undocumented SwiftUI→UIKit lowering. CI Xcode version is pinned; breakage is
  treated as a signal to re-verify, not as a false negative to suppress.
- SHSans is absent from the repo, so SwiftUI renders the system font — sizes and weights match,
  family does not. Any text-bearing pixel comparison fails on family alone until W5.
- **No automated rung replaces a human looking at the result on a device.** Geometry testing
  narrows what a human must check; it does not remove the human. This is the lesson the device
  pass taught, and it is not repealed by better tooling.

---

## 6. T6 — coverage matrix

26 shapes mined from production, in `DialogCatalog+*.swift`.

| Group | Shapes | Preset | Executor status |
|---|---|---|---|
| Standard | 13 — `standard-one-button`, `standard-two-button`, `title-nil-error`, `close-button-dismiss`, `oblique-red-leave-confirm`, `badge-detail-popup`, `exit-worksheet-confirm-banner`, `worksheet-ready-timer-banner`, `worksheet-timeup-timer-banner`, `worksheet-generating-abused`, `rename-worksheet`, `date-picker-worksheet`, `switch-device-recommendation` | `properties` | `AlertDialog` ✅ |
| Popup | 9 — `onboarding-welcome-nobanner`, `onboarding-trial-banner`, `database-error-banner`, `force-update-banner`, `quiz-info-banner`, `quiz-begin-banner`, `credit-deduction-popup`, `ai-notes-ready-banner`, `worksheet-abused-cap-banner` | `popupProperties` | `PopupDialog` ✅ |
| Badge | 2 — `badge-unlock-single`, `badge-unlock-multi` | `badgeProperties` | ❌ no descriptor |
| Permission | 1 — `permission-denied-settings` | `permissionAlertProperties` | ❌ no descriptor |
| Streak | 1 — `streak-popup-banner` | `streakModalProperties` | ❌ no descriptor |

The preset groups above and the content mechanisms below **overlap** — `badge-unlock-single`/`-multi`
are missing a preset *and* use bespoke content. Counting by content mechanism instead, so the
totals are disjoint:

| Content mechanism | Shapes | Blocked by |
|---|---|---|
| Standard (title / subtitle / buttons / banner) | **20** | Only the missing `style:` token, for 2 of them |
| `subtitleCustomView` | **6** — `badge-unlock-single`, `badge-unlock-multi`, `badge-detail-popup`, `worksheet-generating-abused`, `rename-worksheet`, `date-picker-worksheet` | Bespoke mechanism — **except** `rename-worksheet` and `date-picker-worksheet`, already served by `TextInputDialog`/`DatePickerDialog` |
| **Total** | **26** | |

Additionally, 2 shapes (`worksheet-ready-timer-banner`, `worksheet-timeup-timer-banner`) carry
timer state on top of standard content, and ~14 carry a banner.

**Recommended bar:** the **20 standard-content shapes** render in SwiftUI, which requires only the
`style:` token. The 4 genuinely bespoke shapes (3 badge grids + `worksheet-generating-abused`) and
the 2 timer-stateful ones are explicitly deferred and **named as deferred** — not silently dropped.

---

## 7. Test-group parity

UIKit baseline: **239 tests, 17 groups** (verified `Executed 239 tests, with 0 failures`).

| Class | Groups | Tests | Tier-1 obligation |
|---|---|---|---|
| Renderer-agnostic | `ModalExecutorTests`, `ModalExecutorCoordinatorTests`, `RootScreenModalCoordinatorTests`, `ExecutorStatefulTests`, `CoordinatorUsageExample`, `ModalTokenTests`, `ModalTextTests` | ~62 | **Author nothing.** Parameterise; must pass unchanged. |
| Structural | `LayerA_ResolverTests`, `AlertDialogMappingTests`, `BugRegressionTests` | 66 | Shared via `ResolvedModal` — largely satisfied by construction |
| View-bound | `LayerB_WiringTests`, `ModalLayoutTests`, `BannerAspectStressTests`, `ModalKeyboardAvoiderTests`, `LayerC_SnapshotTests`, `UIKitModalRendererTests`, `InputDialogTests`, `SubtitleCustomViewLifetimeTests` | ~111 | SwiftUI equivalents; this is where C-3 applies |

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| Two renderers drift after this branch lands | C-0 and C-1 remove drift by construction rather than detecting it; C-2/C-3 cover the rest |
| C-3b breaks on an iOS release | Pinned CI Xcode; breakage re-verifies rather than suppresses |
| Instrumentation scope creep into production views | `#if DEBUG` gate; named tolerance targets only |
| Reversing D8 invalidates prior review | Flagged for explicit owner review; `PopupDialog` retained for compatibility |
| The 5–0 council objection proves right — no consumer ever needs this | W2's C-2 run is the cheapest kill signal; stop there if parity fails broadly |
| Sole maintainer, no reviewer, 100 commits unmerged | Unchanged by this spec; merge remains a separate custodial decision |

---

## 9. Open questions for the owner

1. **T6** — is the 22-shape bar right, or must bespoke/timer shapes be in scope?
2. **D8-revised** — confirm the reversal to a `style:` token, and `PopupDialog`'s deprecation.
3. **T1** — confirm workstream order, in particular treating W2/C-2 as a genuine stop-or-continue gate.
