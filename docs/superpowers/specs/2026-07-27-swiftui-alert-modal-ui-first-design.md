# SwiftUI Alert Modal — UI-first prototype (design)

**Date:** 2026-07-27
**Branch:** `feat/modal-executor-capability` (unmerged)
**Scale:** S. Example-app only, zero library changes.
**Related:** `docs/superpowers/notes/2026-07-27-swiftui-renderer-brief.md`, memory `gb-v3-alert-modal-executor-decisions`.

## Goal

Build a **pure-SwiftUI** alert modal that mirrors `GBAlertModal`'s *content*, driven by
**local `@State`** (no executor, no coordinator), reachable from the existing UIKit gallery in the
Example app. Purpose: let the owner **judge the SwiftUI-native authoring + look/feel** before deciding
whether to keep it pure-local, route through the executor (Tier 0), or build a native renderer (Tier 1).

This is a **judgment prototype**. Visuals are content-faithful but provisional; it may be discarded.

## Locked decisions (council-vetted 2026-07-27, owner-confirmed)

1. **Sequence: UI-first.** Build this pure-local UI *now*. The ~1hr Tier-0 hosting smoke test
   (executor modal paints over a SwiftUI host) is a **separate later task**, not in this slice.
   (Council 3–1 preferred smoke-test-first; owner overruled — judge the destination before wiring plumbing.)
2. **Presentation: overlay `ZStack`** — dimmed backdrop + centered card. **NOT** `.sheet` /
   `.fullScreenCover`: those are edge-anchored full covers and structurally cannot produce a *centered
   dimmed card*. The idiomatic SwiftUI centered-card IS an overlay. Also keeps presentation authority in
   one slot (no competing SwiftUI presentation lifecycle).
   - **Invariant to build to (verified in current UIKit code):** every dialog is a **full-screen scrim +
     centered card**. `GBAlertModal` pins to the parent's edges (`+Lifecycle.swift:27`); `vwOverlay` pins
     `edges.equalToSuperview()` (`+ViewFactory.swift:22`) with `backgroundColor = overlayColor`
     (`+Style.swift:17`) — dimmed *or* `.clear`/transparent, same full-screen view either way; the card
     (`vwContainer`) floats centered on top. The SwiftUI view mirrors this exactly:
     `ZStack { Color(scrim).ignoresSafeArea(); Card() }`, scrim color the only variable (default dimmed).
3. **State: item-driven** — `@State private var active: AlertConfig?` in the demo screen. Not a `Bool`
   toggle, not an `ObservableObject`. Single source of truth; mirrors `presentAndWait(config:)` shape.
4. **Fidelity: content-faithful, native idioms.** Same slots + hierarchy + behavior as `GBAlertModal`.
   **No** pixel-clone of the oblique primary button, banner ratios, or DM Sans fonts. Native SwiftUI
   fonts/shapes/spacing.
5. **Scope: `AlertDialog` content shape only** — banner?/title?/subtitle?/primary/secondary?/close? +
   `onAction`. No input variant, no stateful (Gc2Gs) variant. Those are a second decision after this lands.
6. **Demo variants: two** — minimal (title + subtitle + primary) and full (all slots). Toggles are
   independent, so this is enough to exercise the layout; not a full cross-product.
7. **Location: Example app only.** Zero library changes. No `.sheet`/`Binding`/Combine in the library.
8. **Well tested via the repo's 3-layer house style, no new deps, no library changes** (see Testing).

## Content vocabulary

Reuse the library's public `AlertDialog` as the config type where practical — it already IS the content
shape (image?/title?/subtitle?/primary/secondary?/closeOnTapOverlay/showCloseButton) and its `Result`
(`.primary` / `.secondary` / `.dismissed`) is the outcome vocabulary. Reusing it keeps the demo speaking
the same language as the executor path, so a later Tier-0/Tier-1 transition is a rewire, not a re-model.

- `AlertConfig` = `AlertDialog` (library type), imported.
- `AlertResult` = `AlertDialog.Result`.
- `ModalImage(assetName:)` → resolve to a SwiftUI `Image(assetName)` inside the view (asset lookup is the
  view's job, keeping the config `Sendable`/UIKit-free — same discipline the library already uses).

## Architecture — dumb view, headless logic

The view holds **no branching logic**. All of it lives in two pure functions so it is exhaustively
testable without hosting or a view-inspection dependency.

```
AlertConfig (= AlertDialog)
      │
      ├── ResolvedAlert(_ config) -> ResolvedAlert      // pure: which slots render
      │       showsBanner, showsSubtitle, showsSecondary, showsClose,
      │       dismissOnOverlayTap  (derived from config)
      │
      └── resolve(_ interaction, _ config) -> AlertResult?   // pure: interaction routing
              .primaryTapped   -> .primary
              .secondaryTapped -> .secondary   (only reachable when showsSecondary)
              .closeTapped     -> .dismissed   (only reachable when showsClose)
              .overlayTapped   -> .dismissed IFF config.closeOnTapOverlay else nil (no-op)

SwiftUIAlertModal: View
   let config; let onAction: (AlertResult) -> Void
   body: ZStack {
       Color.overlay.ignoresSafeArea()
            .onTapGesture { route(.overlayTapped) }        // route = resolve(...).map(onAction)
       Card {
           if resolved.showsBanner   { Image(...) }
           if let title              { Text(title) }
           if resolved.showsSubtitle { Text(subtitle) }
           Button(primary)   { route(.primaryTapped) }
           if resolved.showsSecondary { Button(secondary) { route(.secondaryTapped) } }
       }
       if resolved.showsClose { CloseButton { route(.closeTapped) } }
   }
   private func route(_ i: Interaction) { resolve(i, config).map(onAction) }
```

- `Interaction` = local enum `{ primaryTapped, secondaryTapped, closeTapped, overlayTapped }`.
- `ResolvedAlert` + `resolve` are free functions / a small enum-namespaced helper — **not** methods on the
  `View` (so tests import them without constructing SwiftUI types).

### Demo screen

```
SwiftUIDemoScreen: View
   @State private var active: AlertConfig?      // item-driven (decision 3)
   body: VStack {
       Button("Minimal alert") { active = .demoMinimal }
       Button("Full alert")    { active = .demoFull }
   }
   .overlay {                                   // overlay, not .sheet (decision 2)
       if let cfg = active {
           SwiftUIAlertModal(config: cfg) { result in
               // record/print result, then dismiss:
               active = nil
           }
           .transition(.opacity)                // native SwiftUI animation, provisional
       }
   }
```

- `.demoMinimal` / `.demoFull` are two static `AlertConfig` fixtures in the demo screen.
- `onAction` closure sets `active = nil` (dismiss) after recording — the demo screen owns dismissal, the
  modal view never dismisses itself (keeps the view dumb; matches the executor contract where teardown is
  the caller's/coordinator's job).

### Wiring into the Example app

- New folder `Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/`:
  `SwiftUIAlertModal.swift`, `AlertResolution.swift` (the two pure helpers + `Interaction`),
  `SwiftUIDemoScreen.swift`.
- Reach it from the existing UIKit gallery: add a nav-bar button (or a top row) in
  `GalleryViewController` that pushes/presents `UIHostingController(rootView: SwiftUIDemoScreen())`.
  This is the "SwiftUI screen = UIHostingController in the same UIWindow" reframe made concrete — and the
  cheapest possible place to eyeball SwiftUI-hosted content next to the UIKit gallery.

## Testing (well tested — Layer A + hosting smoke, no new deps)

Target: `GBV3AlertModalExampleTests` (existing). No swift-snapshot-testing (not linked there), no
ViewInspector.

- **Layer A — headless, exhaustive** (`AlertResolutionTests`):
  - `ResolvedAlert`: every slot toggle — banner present/absent, subtitle present/absent, secondary
    present/absent, close on/off — asserts the right `shows*` flags. All branches.
  - `resolve(interaction, config)`: every `(interaction × relevant config)` pair, including the two
    gates — overlay tap returns `.dismissed` iff `closeOnTapOverlay`, `nil` otherwise; primary/secondary/
    close map to the correct `AlertResult`. This is the whole interaction-correctness surface.
- **Layer C-equiv — hosting smoke** (`SwiftUIAlertModalSmokeTests`), mirroring `DialogCatalogSmokeTests`:
  for each variant, host `UIHostingController(rootView: SwiftUIAlertModal(config:onAction:))` in a
  throwaway key `UIWindow`, force a layout pass, assert the hosted view is non-nil / laid out (`bounds`
  non-zero). Catches a config that crashes or produces an empty view. Tear down the window each iteration
  (same leak-avoidance as the existing smoke test).
- **Snapshot: deliberately deferred** — `ponytail:` gap. Visuals are provisional; appearance is judged by
  running the demo. Add pointfree snapshots to the example test target only if the SwiftUI path is chosen
  to ship.

**Run:** `xcodebuild test -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17'`
(iOS 15 floor). `-only-testing:` for tight loops.

## Non-goals / deferred

Tier-0 hosting smoke test (separate task), Tier-1 `SwiftUIModalRenderer`, all 26 catalog shapes in
SwiftUI, animation/transition parity with the SnapKit modal, input + stateful (Gc2Gs) variants, the
`.sheet(item:)` VM-side adapter, `@Observable`/iOS 17, any library change, any app-migration.

## After this lands

Owner judges the running demo + the authoring feel, then picks: **keep pure-local**, **Tier 0** (route
through the existing executor — needs the 1hr hosting smoke test first), or **Tier 1** (native renderer).
The `SwiftUIAlertModal` content view is reusable under Tier 1, so this work is not throwaway even if the
demo's local-state driving is.
