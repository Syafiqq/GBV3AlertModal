# Estimate: Toast presentation seam — shared base with GBV3AlertModal

**Status:** pre-project estimate. No code. Written from `gb-v3-alert-modal` (this repo) ahead of
creating the new toast project, so the decision on "shared base or not" is made before day one.
**Purpose:** review `VToastViewV2` (Top/Bottom) in `geniebook-student-ios`, decide whether the new
toast project can sit on the same `ModalDescriptor`/`ModalToken`/`ModalExecutor`/`ModalRenderer`
seam this module already ships, and size the work.

---

## 1. What exists today (`geniebook-student-ios`)

`Common/Common/Presentation/UIKit/Widget/Toast/`:

| File | Lines | Role |
|---|---|---|
| `VToastViewV2.swift` | 497 | Base view: layout (SnapKit), `doUpdateUi` (text/icon/CTA/color by `ToastType`), auto-hide timer, tap-to-dismiss, `DisplayProperties` config struct. `showView`/`hideView` are **empty stubs**. |
| `VToastViewV2+Top.swift` | 69 | `VToastTopViewV2: VToastViewV2`, overrides `showView`/`hideView`. |
| `VToastViewV2+Bottom.swift` | 69 | `VToastBottomViewV2: VToastViewV2`, overrides `showView`/`hideView`. |
| `Widget/ActivityIndicator/UIView+Toast.swift` | 261 | `showTopToast`/`showBottomToast` + `Distinct` variants + `attachTopToastV2`/`attachBottomToastV2` (SnapKit constraints to a parent `UIView`). |

**Finding — the Top/Bottom split buys nothing.** `VToastTopViewV2.showView`/`hideView` and
`VToastBottomViewV2.showView`/`hideView` are **byte-identical** (same 0.3s curve, same alpha
animation, same completion). Two files, two classes, zero behavioral difference between them.

**The actual top/bottom difference lives one layer up**, in `UIView+Toast.swift`:
`attachTopToastV2` anchors `constraintToShow` to `parent.safeAreaLayoutGuide.top` (offset
`+showSpace`) and `constraintToHide` above it; `attachBottomToastV2` mirrors both off `.bottom`
(negative offset). That's a **single sign flip on one edge**, but it's expressed as two ~45-line
near-duplicate functions plus two duplicate `show*ToastV2`/`hide*ToastV2` pairs — call-site-facing
API name is the only thing that structurally needs to differ (`showTopToast` vs `showBottomToast`).

**Net:** this is a textbook "subclass where a parameter would do" — exactly the shape
`GBV3AlertModal`'s descriptor pattern replaces elsewhere in this codebase. One view + one `edge:
.top | .bottom` case collapses 2 classes + 2 attach functions + 2 show/hide pairs into 1 of each.

### Call-site inventory (`geniebook-student-ios`)

36 call sites / 17 files: **33 top, 3 bottom** (bottom is barely used — confirm with the app owner
whether it's worth keeping as a first-class variant or folding into "an edge option nobody
exercises much"). 1 site uses `Distinct` (tag-based dedup — don't re-show if one's already up).
3 sites pass `ctaText`/`ctaAction` (inline CTA link). The rest are `type: .error/.success/.warning`
+ `displayProperties: .default.copyWith(animated: false)` or `.copyWith(showIcon: false)` — content
+ small behavior tweaks, never new visual style. 26/30 greppable sites target
`AppCompatHelper.keyWindow` directly; only 2 target a screen's own `view`. → **window-only
presentation is a safe default**, matching how `GBV3AlertModal` resolves its window today.

---

## 2. Can the new project share `GBV3AlertModal`'s base?

Checked `Core/ModalDescriptor.swift`, `Core/ModalToken.swift`, `Core/ModalExecutor.swift`,
`Core/ModalRenderer.swift`: **none of the four reference `GBAlertModal` or any alert-specific
type.** The seam is already generic:

```
VM ──present(descriptor)──▶ ModalExecutor ──render──▶ ModalRenderer (UIKit/SwiftUI)
        (pure, Sendable)         │
                                  ▼
                              ModalToken<Result>  (id + resolve-once + async replay)
```

`ModalDescriptor` just needs `associatedtype Result: Sendable` + `dismissedResult`. A `ToastDialog`
descriptor (`text`, `type`, `edge`, `ctaText?`, `autoDismiss`) fits it exactly the way `AlertDialog`
does. **Recommendation: the new toast project takes an SPM dependency on `GBV3AlertModal` and reuses
`ModalDescriptor`/`ModalToken`/`ModalExecutor`/`ModalRenderer` as-is**, registering its own
`ToastDialog` factory the same way a consumer already can via `UIKitModalRenderer.register(_:factory:)`
— no library change needed, no new package to stand up and maintain. Extracting a separate
`GBV3PresentationCore` micro-package is YAGNI at 2 consumers; revisit only if a third
presentation-shaped project shows up (Rule of Three).

**One piece does NOT transfer: `MainTabModalCoordinator`.** It is a *serial, one-at-a-time*
queue — "two would be visual garbage" is true for a dimmed fullscreen alert and **false** for
toasts, which are non-blocking and (per the `Distinct` call site above) sometimes need to coexist
or dedup *without* queueing. Toast needs its own, much lighter policy — likely just a `dedupKey`
check at present-time (no serialization), which is a real gap: `DefaultModalExecutor` currently
only honors `dedupKey` **when a coordinator is installed**, and the existing coordinator conflates
dedup with serialization. This is the one open design question below, not a solved problem to
inherit.

**SwiftUI changes this more than "defer it" — the real-app plan already picked the renderer Toast
should sit on.** `docs/superpowers/plans/2026-08-11-real-app-swiftui-integration.md` §2 wires
`geniebook-student-ios` (100% UIKit in production) to `WindowModalRenderer`, **not**
`UIKitModalRenderer` — it installs a `UIHostingController` as a `.clear`-background, full-frame
subview of the app's *existing* `UIWindow` (`WindowModalRenderer.install(_:in:)`), no pre-existing
SwiftUI screen required. That's already the app's chosen path for alerts, one instance, app-wide.

`WindowModalRenderer` also ships `register<D: ModalDescriptor>(_ type:, view: (D, resolve) -> AnyView)`
— a raw-SwiftUI-view registration that needs no `ModalProperties`/`ModalContent` mapping at all (see
`WindowModalRenderer.swift:133-146`, the same escape hatch the five bespoke descriptors use). That
means **Toast needs no new renderer type for its SwiftUI path** — just:

```swift
modalCenter.renderer.register(ToastDialog.self) { descriptor, resolve in
    AnyView(ToastContentView(descriptor: descriptor, resolve: resolve)) // edge-pinned, own timer/tap
}
```

registered on the SAME `WindowModalRenderer` instance and `GBModalCenter.executor` the app already
constructs for alerts. `WindowModalRenderer`'s own doc even states "no queue, by design... overlap
accepted" — exactly the coexistence toast wants, for free, with zero coordinator involvement.

**The one real constraint this puts on `ToastContentView`:** since the hosting view is a full-window
`.clear`-background subview (not a separate overlay `UIWindow`), touch passthrough outside the
toast's own drawn area works the same way it does for the alert's scrim — SwiftUI only registers hit
testing where something is actually drawn. `SwiftUIAlertModal` deliberately covers the WHOLE frame
(its scrim is the point). `ToastContentView` must do the opposite: an edge-pinned `VStack` + `Spacer`
with nothing else in the ZStack, so the untouched rest of the screen stays interactive. Getting this
wrong (e.g. a full-frame `Color.clear.contentShape(Rectangle())` for "give me a hit-testable frame")
would silently block the whole screen — call this out explicitly in the first PR, it's the one way
this port breaks the "app underneath is still usable" property today's UIKit toast already has.

**UIKit path (only needed while `geniebook-student-ios` call sites aren't migrated yet):** mirror
`UIKitModalRenderer`'s pattern — factory registry keyed by `ObjectIdentifier(D.self)`, resolve-once
gate, `[id: live]` registry — owning toast's own presentation (window attach + edge constraint). But
given the app itself is adopting `WindowModalRenderer` for alerts specifically so it can go
SwiftUI-native without a UIKit rewrite (memory: SwiftUI is the product for this whole modal effort,
UIKit is legacy), **build the SwiftUI path first** and let the UIKit path be the one that's optional.

---

## 3. Proposed shape (new project)

| Piece | Replaces | Shape |
|---|---|---|
| `ToastDialog: ModalDescriptor` | `ToastType` + `DisplayProperties` + free-floating `text`/`ctaText` params | One `Sendable` struct: `text`, `type`, `edge: .top \| .bottom`, `customIcon: ModalImage?`, `ctaText: String?`, `autoDismiss`/`autoDismissDuration`, `showIcon`. `Result: .cta, .dismissed`. |
| `ToastContentView: View` | `VToastViewV2` + `+Top` + `+Bottom` (3 files, 635 lines) | One SwiftUI view, edge-pinned via `VStack { if edge == .top {…}; Spacer(); if edge == .bottom {…} }` — no scrim, no full-frame fill, so the rest of the screen stays interactive (§2). Owns its own auto-hide timer (`.task { try? await Task.sleep(...); resolve(.dismissed) }`) and tap/CTA gestures. |
| — no new renderer type — | `UIView+Toast.swift`'s 4 near-duplicate function pairs (261 lines) | `modalCenter.renderer.register(ToastDialog.self) { d, resolve in AnyView(ToastContentView(...)) }` on the app's existing `WindowModalRenderer` instance. Same window install, same resolve-once gate, already written. |
| `DefaultModalExecutor` (from `GBV3AlertModal`) | — | Reused directly; no toast-specific executor needed. `present`/`dismiss` unchanged. |
| Toast-specific dedup policy | tag + `Distinct` variants | `dedupKey: AnyHashable?` on `present`, honored on the **direct** path too (currently coordinator-only) — smallest fix that makes `Distinct` unnecessary as a separate call-site name. |
| `UIKitToastRenderer` (optional, migration-only) | — | Only if `geniebook-student-ios`'s 36 UIKit call sites need to move before the app's own SwiftUI-native alert migration lands. Mirrors `UIKitModalRenderer`'s registry if/when built — not day one. |

---

## 4. Estimate

| Phase | Work | Size |
|---|---|---|
| 1 | `ToastDialog` descriptor + `ToastContentView` (SwiftUI, edge-pinned, own timer/tap/CTA, passthrough-safe) | **S** |
| 2 | `register(ToastDialog.self, view:)` on `WindowModalRenderer` + wire through `GBModalCenter.executor.present(...)` — no new renderer type, per §2 | **XS** |
| 3 | Dedup-without-serialization on `DefaultModalExecutor`'s direct path (the one real gap vs. reusing the alert seam wholesale) | **S** |
| 4 | Example-app gallery (top/success, top/error+CTA, bottom, dedup demo) + tests mirroring `Executor/*Tests.swift` in this repo | **S–M** |
| 5 *(optional, defer)* | `UIKitToastRenderer` if `geniebook-student-ios`'s 36 UIKit call sites must move before the app's SwiftUI-native alert migration lands | **S–M** |

**Headline: XS–S** for the SwiftUI path (smaller than the original modal-executor estimate — the
renderer already exists and already generalizes via `register(_:view:)`); Phase 5 only adds size if
UIKit migration can't wait.

**Deferred (separate, later):** `UIKitToastRenderer` (only if UIKit call sites must move before the
app's own SwiftUI migration), app migration of the 36 call sites (app-team, downstream),
stacking/queue policy for >1 simultaneous toast per edge if product actually wants it (today's app
shows one-at-a-time per tag already — parity first).

---

## 5. Open decisions for the new project (ask before Task 1)

1. **New repo name / location** — sibling of `gb-v3-alert-modal` under `modules/`?
2. **Dependency direction** — SPM dependency on `GBV3AlertModal` for `Core/*` (recommended above),
   or a hard vendor-copy of the 4 core files if the two projects must never couple releases?
3. **Bottom edge** — keep as a first-class case (3 real call sites) or fold into "top is the
   product, bottom is an option nobody really uses" and simplify further?
4. **Dedup semantics** — drop-new-silently (today's `Distinct` behavior) vs. replace-in-place vs.
   queue-behind, now that dedup no longer requires the alert coordinator's full serialization.
5. **Which `WindowModalRenderer` instance** — register `ToastDialog` onto the SAME `GBModalCenter`
   instance the real-app plan constructs for alerts (one executor, one renderer, whole app), or a
   second instance if toast ships as an independently-versioned package that shouldn't assume the
   alert integration has landed first?
