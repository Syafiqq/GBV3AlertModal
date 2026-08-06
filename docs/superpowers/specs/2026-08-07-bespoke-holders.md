# Brief — the 5 bespoke holders: finishing Pass 5 step 6

**Status: DONE.** Written 2026-08-07 at the end of the Pass 5 session, picked up and closed the same
day. Commits `13b842f`/`6fd917e`/`1b6a2f8`/`2456389`/`3bcc527`, one per descriptor
(TextInputDialog/DatePickerDialog/BadgeDialog/LoadingDialog/SatisfactionDialog), 545/0 after each.
No deviations from the plan below — §0's measurements held, `SatisfactionDialog`'s missing
`secondary` field was the one trap and it was avoided. See `2026-08-07-uikit-retirement.md`'s
Progress section for the closing summary. Parent brief: `2026-08-07-uikit-retirement.md` (§3 step 6,
"Give the SwiftUI half its own holder" — scoped down mid-session to the standard family only; this
was the deferred remainder). Direction doc: `2026-08-05-backend-independence.md`.

This is a SMALL, MECHANICAL follow-up, not a new design. Everything this needs already exists and
is proven: `ModalContentInputs` (protocol), `ModalContent` (Sendable holder), the generalized
`Registration<D>.factory` internal type, and the exact pattern `registerStandard` already
demonstrates for AlertDialog/PopupDialog. This brief is five repetitions of that pattern, one per
descriptor.

---

## 0. What is already true, measured — read this before touching anything

Measured on 2026-08-07 at commit `4d6307e`, branch `feat/modal-executor-capability`, library suite
**545/0**. This spec family has a track record of stale claims (five caught before this session,
three more during it — see `2026-08-07-uikit-retirement.md`'s Progress section) — re-measure rather
than trust this table if it's been a while.

### The 5 remaining call sites, exact locations

```
grep -n "Holder.make" Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/SwiftUIModalRenderer.swift
```

All five are inside `registerBuiltInDescriptors()`:

| line | descriptor | UIKit holder called |
|---|---|---|
| 337 | `TextInputDialog` | `UIKitModalRenderer.TextInputHolder.make` |
| 347 | `DatePickerDialog` | `UIKitModalRenderer.DatePickerHolder.make` |
| 357 | `BadgeDialog` | `UIKitModalRenderer.BadgeHolder.make` |
| 369 | `LoadingDialog` | `UIKitModalRenderer.LoadingHolder.make` |
| 381 | `SatisfactionDialog` | `UIKitModalRenderer.SatisfactionHolder.make` |

Each is registered via the PUBLIC `register(_:factory:)` — the still-fully-supported, unchanged,
`DataHolder`-typed overload (Pass 5 step 6 kept it that way deliberately, for the example app and
existing consumers). Nothing is broken by leaving these as they are; this brief is a purity/
completeness follow-up, not a bug fix.

### Why these were scoped out of step 6

`registerStandard` (AlertDialog/PopupDialog) bypasses the public `register(_:factory:)` and
constructs `Registration<D>` DIRECTLY — that's what let it use the wider internal type
`(GBAlertModal.Properties?, any ModalContentInputs)` without touching the public `Factory<D>`
typealias. `registerBuiltInDescriptors()` currently goes THROUGH the public method for all five,
which is why it still needs `DataHolder` — the public overload's return type is unchanged.

### Each descriptor's fields, measured (not assumed) from its own file

```swift
// TextInputDialog: title: AttributedString?, placeholder: String, initialText: String,
//   primary: String, secondary: String?, closeOnTapOverlay: Bool
// DatePickerDialog: title: AttributedString?, initialDate: Date, minimumDate/maximumDate: Date?,
//   primary: String, secondary: String?, closeOnTapOverlay: Bool
// BadgeDialog: banner: ModalImage?, title/subtitle: AttributedString?, badges: [Badge],
//   primary: String, secondary: String?, closeOnTapOverlay: Bool, showCloseButton: Bool, style: ModalStyle
// LoadingDialog: title/subtitle: AttributedString?, primary: String, secondary: String?,
//   isLoading: Bool, closeOnTapOverlay: Bool, showCloseButton: Bool, style: ModalStyle
// SatisfactionDialog: title: AttributedString?, options: [Option], primary: String (NO secondary),
//   closeOnTapOverlay: Bool, style: ModalStyle
```

**`SatisfactionDialog` has no `secondary` field** — its holder never sets `secondaryAction`. Easy to
transcribe wrong by pattern-matching the other four; don't.

### What each UIKit holder currently does that `ModalContent.make` must mirror exactly

Read `Executor/UIKitModalRenderer+InputHolders.swift` (TextInputHolder, DatePickerHolder) and
`Executor/UIKitModalRenderer+BespokeHolders.swift` (BadgeHolder, LoadingHolder, SatisfactionHolder)
before writing anything — this table is a summary, not a substitute:

- **TextInputHolder / DatePickerHolder / SatisfactionHolder** all set `subtitleCustomView` (to a
  `UITextField` / `UIDatePicker` / `UISegmentedControl`) — i.e. `hasSubtitleCustomView: true` on the
  `ModalContent` mirror. **Confirmed inert, not just likely**: `SwiftUIModalRenderer.swift`'s own doc
  on `makePresentation` states it generally, for every descriptor — "`Presentation.resolved` … the
  value never reaches a renderer. `ModalPresentationBody.view(for:)` hands the view `properties` and
  `tokens` — never `resolved`" (lines ~567-572) — and a grep for `.resolved` across `SwiftUI/*.swift`
  turns up nothing reading it outside `Presentation`'s own storage and a comment in `ModalHost.swift`.
  Set `hasSubtitleCustomView: true` anyway, for structural parity with the UIKit mapping — it costs
  nothing and keeps `ModalContent.make` an honest mirror — but there's no live behavior riding on it.
- **BadgeHolder / LoadingHolder** carry `title`+`subtitle`, no custom view, `showCloseButton`.
  `BadgeHolder` additionally resolves `descriptor.banner` via `UIImage(named:in:bundle:) != nil` —
  the SAME transient-probe pattern `ModalContent.make(for: StandardAlertContent)` already uses for
  `hasBanner`. Mirror it, don't invent a new one.
- **All five** pass `dismissOnAction: false` (the renderer's gate owns teardown) and read `resolve`
  only to build `completion` — which `ModalContent` has no field for and none of the five need,
  exactly like `AlertHolder.make`'s `resolve` parameter was already unused on this backend (see
  `ModalContent.make`'s own doc). The five new overloads take no `resolve` parameter, same as the
  standard-family one.

---

## 1. The plan

One commit, or one commit per descriptor if that reads better — this is small enough either way.
Green after each.

### Step A — five new `ModalContent.make(for:)` overloads

In `SwiftUI/ModalContent.swift`, beside the existing `make(for: StandardAlertContent)`. Signature
shape per descriptor, using the field lists in §0 and the mirroring rules above:

```swift
public static func make(for descriptor: TextInputDialog) -> ModalContent
public static func make(for descriptor: DatePickerDialog) -> ModalContent
public static func make(for descriptor: BadgeDialog) -> ModalContent
public static func make(for descriptor: LoadingDialog) -> ModalContent
public static func make(for descriptor: SatisfactionDialog) -> ModalContent
```

Each: `ModalText.split` on the `AttributedString?` fields (title, and subtitle where present),
`hasBanner` via the `UIImage(named:)` probe (`BadgeDialog` only), the rest a direct field
transcription per §0's table. `dismissOnAction: false` on all five.

### Step B — rewrite the five `registerBuiltInDescriptors()` factory registrations

Currently five calls to the public `register(TypeDialog.self) { [weak self] descriptor, resolve in
(self?.properties(for: ...), UIKitModalRenderer.XHolder.make(for: descriptor, resolve: resolve)) }`.

Replace each with a DIRECT `Registration<D>` construction — the exact pattern `registerStandard`
already uses (`SwiftUIModalRenderer.swift`, the `let factory: (D, resolve) -> (Properties?, any
ModalContentInputs) = { [weak self] descriptor, _ in ... }` shape, then
`registrations[ObjectIdentifier(type)] = Registration<D>(factory: factory, route: nil, content: nil,
view: nil)`), so the factory half stops going through the public `Factory<D>`-typed method. Do NOT
change the separate `register(TypeDialog.self, view: { ... })` calls that follow each — those set the
CONTENT half only, are untouched by this brief, and already compose correctly with a
directly-constructed `Registration` (verified: `register(_:view:)` reads `previous?.factory` and
falls back to a `ModalContent()`-typed neutral factory — both already `any ModalContentInputs`-shaped
since Pass 5 step 6).

**Route stays `nil` for all five, same as today** — none of them are registered with
`register(_:route:factory:)` currently; their `view` builders resolve the gate directly. Don't add a
route while touching this code; that would be a behavior change this brief isn't about.

### Step C — verify

- `Script/test-lib.sh` — expect 545/0, no count change (pure internal refactor, no new/deleted
  tests unless you choose to add coverage for the new `ModalContent.make` overloads, which would be
  reasonable and welcome but isn't required to close this out).
- `Script/test-example.sh` — optional but recommended once (it's the one that caught real
  regressions before per that script's own header comment); a plain `xcodebuild build` on the
  example scheme is a fast proxy if the full ~25 minutes isn't warranted.
- Re-run `SwiftUIPurityTests` — should still pass with no allow-list changes (this brief adds no new
  `import UIKit` anywhere; `ModalContent.swift` already has one, from step 6).

---

## 2. What this does NOT do

- Does not touch `UIKitModalRenderer+InputHolders.swift` / `+BespokeHolders.swift` — those are
  `Executor/`, frozen, and their UIKit holders keep serving the UIKit backend exactly as before.
- Does not touch `TextInputContent`/`DatePickerContent`/`BadgeContent`/`LoadingContent`/
  `SatisfactionContent` (`SwiftUIModalRenderer+InputViews.swift` /
  `+BespokeViews.swift`) — those already render natively (Pass 4 found this true), and this brief
  only replaces what feeds `Presentation.resolved`/`.tokens`, not what draws.
- Does not add a `ModalProperties`-typed path for these five styles — that's Pass 5 step 5, deferred
  by owner decision (`2026-08-07-uikit-retirement.md`'s Progress section explains why: no conversion
  between `GBAlertModal.Properties` and `ModalProperties` exists, and `properties(for: style)` stays
  `GBAlertModal.Properties?`-typed regardless of what this brief does).
- Does not change any PUBLIC API. `register(_:factory:)` stays `Factory<D>`-typed and available; a
  consumer who registered a custom factory for one of these five kinds (unlikely, but the extension
  point is documented) keeps working unchanged.

## 3. How to start

Re-measure §0 first:

```bash
git log --oneline -3
grep -n "Holder.make" Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/SwiftUIModalRenderer.swift
./Script/test-lib.sh   # still 545/0?
```

Then read `registerStandard`'s current body in `SwiftUIModalRenderer.swift` once, side by side with
`registerBuiltInDescriptors()` — the former is exactly the shape the latter needs to become, five
times over.
