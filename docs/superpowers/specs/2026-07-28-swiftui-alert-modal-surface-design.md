# SwiftUI Alert Modal — Content/Descriptor Surface Design

**Date:** 2026-07-28
**Status:** Approved (decision list ratified by owner; placement ruled by /council)
**Source discussion:** `docs/superpowers/notes/2026-07-28-uikit-fields-swiftui-worth.md`
**Prior art:** SwiftUI UI-first prototype (`Examples/.../SwiftUI/`), executor capability (`Library/.../Executor/`)

---

## Scope

Decide the **SwiftUI content/descriptor surface** — the public shape a caller uses to describe an
alert modal — **independent of renderer tier**. The surface is identical whether the modal is
kept pure-local, drawn by the existing UIKit renderer (Tier 0), or by a future native
`SwiftUIModalRenderer` (Tier 1); that is why it can be decided now.

**Out of scope:** the Tier-1 `SwiftUIModalRenderer` design; migrating the distribution app's
142 call sites; animation/transition parity; snapshot infra for the example target.

Verdicts in the source note were "a starting point." This spec supersedes them where the two
disagree — several note verdicts were corrected against **real usage data** in
`geniebook-student-ios-distribution` (see Evidence).

---

## Evidence that corrected the note

Measured in the distribution app (facts, not the note's estimates):

- **`subtitleCustomView`** flows through GBV3-family modals in **3 real, shipping cases**:
  worksheet container (`V3AlertModal+Worksheet`), satisfaction rows (`SatisfactionLevelDialogView`),
  badge grid (`VBadgeListViewController`). Not a rare escape hatch — but small and enumerable.
  (Raw grep count of 44 was inflated by sibling modals — VBottomSheet/VTooltip/VOnboarding/V2Alert —
  each carrying their own same-named `subtitleCustomView` field.)
- **Attributed strings** are used through GBV3-family modals (`GenerateGc2GsModal` ×5,
  `BadgesPopUpView`, `V1WorkingSpaceViewController`, `QuestionHelper`), and `VBadgesItemView`
  builds *interactive* attributed text (normal + tappable "action text" with an id). Real content:
  bold/colored runs + inline tappable links.
- **`closeImage`** is **never** customized — the only modal site passes `nil`. (The 7 other grep
  hits were `closeImageEditor()`, an unrelated canvas method.)
- **`closeOnTapOverlay`** and **`showCloseButton`** each take **both** `true` and `false` across
  production sites — genuine per-call content.

---

## Decisions

### D1 — Custom body content: two honest surfaces
Do **not** unify the ~114 plain title/subtitle/button sites with the 3 custom-content sites.

- **Standard shape** → the `AlertDialog` value descriptor (`Sendable`), routed through the
  executor/coordinator/token path.
- **Bespoke content** → a **separate generic chrome view `AlertModalScaffold<Content: View>`** with
  a `@ViewBuilder content:` slot, composed directly by the caller with local `@State`/`.overlay`
  (as the prototype's `SatisfactionDemoView` already does). **Not** routed through the value-descriptor
  executor path. (Distinct type name — Swift forbids a non-generic `SwiftUIAlertModal` and a generic
  `SwiftUIAlertModal<Content>` coexisting.)

Rationale: a `@ViewBuilder` is a captured view closure — **not `Sendable`, not a value** — so it
cannot live on a descriptor that gets enqueued/deduped/replayed/handed across `@MainActor` without
breaking the executor model. Type-erasing to `AnyView` on the descriptor is rejected (kills token
replayability; SwiftUI identity/perf smell).

### D2 — Config vocabulary: reuse `AlertDialog`
The SwiftUI standard surface reuses the library `AlertDialog` value struct. No parallel
SwiftUI-side descriptor.

### D3 — Rich title/subtitle: one `AttributedString` field + two inits
`AlertDialog.title` and `.subtitle` change from `String?` to **`AttributedString?`**
(`AttributedString` is `Sendable`, so it stays on the value descriptor).

"Serve both" is shaped as **one stored field per slot + two convenience inits** — an all-`String`
init (the 114 plain sites) and an all-`AttributedString` init. A mixed call (plain title + rich
subtitle) uses the `AttributedString` init and lifts the plain side with `AttributedString("...")`
(one line). **Not** two parallel fields (`title` + `titleAttributed`) — that reproduces the
illegal-state / precedence asymmetry class already recorded as a shipped bug in the direction memory
(`Properties.copy` nil-vs-false).

Drop `NSAttributedString` entirely. **Interactive** text (tappable links with app callbacks, e.g.
the badges action-text) is *not* a descriptor concern — it goes to the D1 ViewBuilder surface.

### D4 — Dismissal + no-blink content swap
- **No `dismissOnAction` field.** Dismissal is caller-owned; the view never self-dismisses.
  Caller reacts to `onAction` (compose path) or `token.result` (executor path) and clears state.
- The UIKit `dismissOnAction: false` + instance-reuse pattern existed only to avoid the
  add/remove-view **blink** when swapping dialog A→B. In SwiftUI this is achieved natively by
  **in-place descriptor update** — executor `update(token:)` → `@Published`, or `active = newDialog`
  directly — **never** `active = nil` then set.
- **Two rules to encode** so the swap doesn't blink: (a) the presentation slot stays **non-nil**
  across the swap; (b) the container keeps **stable view identity** (no per-descriptor `.id`, or
  SwiftUI treats it as remove+insert = blink).

### D5 — Close glyph: fixed, dropped from the API
Drop `closeImage`. Fixed SF Symbol (`xmark.circle.fill` per prototype), color from `ModalTokens`.
Data: the app never customizes it.

### D6 — Keep `closeOnTapOverlay` + `showCloseButton`
Both remain per-call content flags on `AlertDialog` (already present). Data: both values used in
production. Overlay tap gated by `closeOnTapOverlay`; ✕ shown by `showCloseButton`.

### D7 — Banner: asset-name reference
Keep `ModalImage(assetName:)` → `Image(name)`. Not `UIImage` (not `Sendable`; UIKit type in a
SwiftUI surface; blocks enqueue/replay). Aspect ratio and max/fixed height are **view modifiers**
(`.aspectRatio`, `.frame`), not descriptor fields.

### D8 — Styling: `Properties` dissolves; fixed design via tokens + button styles
No per-call style fields (fonts, colors, spacing, widths, ratios, corner radius, orientation,
match-parent, tint, scrim color all become view modifiers / layout). The fixed design is expressed
as:

- a flat **`enum ModalTokens`** — corner radius, card width (phone/pad), inter-component spacing,
  scrim opacity, colors, fonts;
- two **`ButtonStyle`s** — `ObliquePrimaryStyle`, `PlainSecondaryStyle`.

No theming protocol / environment injection (one theme; speculative abstraction). **Token values
are derived from the app's real `V3AlertModal` preset** (256 phone / 300 pad width, oblique primary,
plain secondary, vertical buttons, matchParent) — not invented.

### D9 — Result callback (ratified from executor design)
Standard surface: `onAction: (AlertDialog.Result) -> Void` on the compose path / `token.result` on
the executor path. The `GBAlertModal` instance parameter of the legacy `completion` is dropped
(value-only result).

### D10 — Placement (ruled by /council, unanimous: Torvalds/Taleb/Rams/Ada)
**Option A.**

- **Descriptor data → library.** The `AttributedString` change (and the settled flags/banner shape)
  land on the library `AlertDialog`, as **its own reviewed, additive commit**. Guardrails:
  1. **Additive only** — two inits, drop only `NSAttributedString`; no existing caller breaks.
  2. **Whitelisted attribute subgrammar** — constrain descriptor `AttributedString` construction to
     **bold / color / inline-link** built with Foundation-bridgeable keys (`.foregroundColor` as
     `UIColor`, `.font`, `.link`). SwiftUI-only attribute scopes do **not** bridge to
     `NSAttributedString.Key` and would silently drop.
  3. **Golden round-trip test** — pin `AttributedString → NSAttributedString` output for exactly
     those three styles against real production descriptors, so the UIKit executor path can't
     silently mangle styling.
  4. **Second-eyes review** — this is the one "no-undo" widening of a shipped `Sendable` struct.
- **SwiftUI view realizations → stay in the example app** (`ModalTokens`, the two `ButtonStyle`s,
  the generic `SwiftUIAlertModal<Content>`, `SwiftUIAlertModal`) as the evolved prototype until the
  Tier fork (keep-local / Tier 0 / Tier 1) resolves. They are tier-dependent and premature to commit
  to the library.
- **Reject Option C** (a diverging SwiftUI-side descriptor): two descriptors carrying the same
  content is a dual-write with no compiler-enforced sync — divergence is a certainty over time.

### Cleanup folded in
Remove the dead `dismissOnOverlayTap` field on the prototype `ResolvedAlert` — the view routes
overlay taps through `resolve(_:_:)`; only a test reads the field.

---

## Resulting public surface (sketch)

```swift
// LIBRARY — value descriptor (D2/D3/D6/D7)
public struct AlertDialog: ModalDescriptor {
    public enum Result: Sendable, Equatable { case primary, secondary, dismissed }
    public var image: ModalImage?
    public var title: AttributedString?      // was String?
    public var subtitle: AttributedString?   // was String?
    public var primary: String
    public var secondary: String?
    public var closeOnTapOverlay: Bool
    public var showCloseButton: Bool

    // all-String convenience (114 plain sites)
    public init(image: ModalImage? = nil, title: String? = nil, subtitle: String? = nil,
                primary: String, secondary: String? = nil,
                closeOnTapOverlay: Bool = false, showCloseButton: Bool = false)

    // all-AttributedString canonical (rich sites; mixed lifts the plain side)
    public init(image: ModalImage? = nil, title: AttributedString? = nil, subtitle: AttributedString? = nil,
                primary: String, secondary: String? = nil,
                closeOnTapOverlay: Bool = false, showCloseButton: Bool = false)
}

// EXAMPLE APP — view realizations (D1/D5/D8), until Tier fork resolves
enum ModalTokens { /* corner, widths(256/300), spacing, scrimOpacity, colors, fonts */ }
struct ObliquePrimaryStyle: ButtonStyle { /* ... */ }
struct PlainSecondaryStyle: ButtonStyle { /* ... */ }

// bespoke-content chrome — scrim + card + close + buttons, caller-supplied body (D1)
struct AlertModalScaffold<Content: View>: View {
    let onAction: (AlertDialog.Result) -> Void
    @ViewBuilder let content: () -> Content
}

// standard modal — reads AlertDialog, never self-dismisses (D4).
// Implemented as AlertModalScaffold with a built-in standard body (title/subtitle/image).
struct SwiftUIAlertModal: View { let config: AlertDialog; let onAction: (AlertDialog.Result) -> Void }
```

*(The two share one chrome implementation: `SwiftUIAlertModal` is `AlertModalScaffold` with a
built-in standard body. Distinct names because Swift forbids same-name generic/non-generic types.
Exact factoring is an implementation-plan concern.)*

---

## Testing intent

- **Round-trip golden test** (library): `AttributedString → NSAttributedString` for bold/color/link
  against real production descriptors (D10 guardrail 3).
- **Resolver test** (example): `resolve(interaction, config)` covers every branch (already exists).
- **No-blink** (example): a swap A→B keeps the card mounted (assert the slot is never nil'd, identity
  stable) — Layer-B style behavioral assert, not a snapshot.
- **Both-inits** (library): String init and AttributedString init produce equivalent descriptors for
  plain text.

---

## Deferred (explicitly not decided here)

Tier-1 `SwiftUIModalRenderer`; app call-site migration; input/stateful SwiftUI variants; all 26
catalog shapes in SwiftUI; animation/transition parity; example-target snapshot infra; promoting the
view realizations into the library (gated on the Tier fork).
