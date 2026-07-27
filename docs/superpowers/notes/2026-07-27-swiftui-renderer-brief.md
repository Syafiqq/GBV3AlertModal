# Brief: SwiftUI renderer — `SwiftUIModalRenderer` (PARKED — do NOT build yet)

**Status:** PARKED (YAGNI). **There is no SwiftUI screen and no SwiftUI dialog in this project** — the
app and every dialog are UIKit. Building a SwiftUI renderer now is speculative; no caller exists.
Do not start this until a real SwiftUI screen needs a modal.

**The one durable takeaway** (why this is safe to park): the seam was verified UIKit-free (§1), so we
owe **zero pre-work** — no adapter, no protocol reshaping, no "SwiftUI-ready" scaffolding. When a
SwiftUI caller finally appears, it's one new renderer file against the *existing* seam. No debt accrues
by waiting. This brief exists so nobody re-investigates the seam or pre-builds anything in the meantime.

**Trigger to un-park:** a concrete SwiftUI screen/VM that must present a modal. Not before.

**Branch:** builds on `feat/modal-executor-capability` (coordinator PRs 1-2 + hardening, unmerged).
**Related:** `2026-07-26-modal-coordinator-brief.md` (the executor/coordinator seam this would plug into).
**Scale:** S — one renderer file + tests, WHEN the trigger fires.

---

## 1. Why it's open (verified 2026-07-27)

The entire front-facing API is already UIKit-free — SwiftUI needs a new *backend*, not a new *seam*:

- `ModalDescriptor` — `Sendable`, "pure, UIKit-free description of *what* to present" (`ModalDescriptor.swift:3`). Images are `ModalImage(assetName:)`, not `UIImage`.
- `ModalToken` / `ModalID` — pure Foundation, `@MainActor`, "NEVER holds the UIView" (`ModalToken.swift:15`). The async `result` is already the SwiftUI-native surface.
- `ModalExecutor` — "No UIKit types cross this API" (`ModalExecutor.swift:1`).
- `RootScreenModalCoordinator` — no UIKit import; drives the renderer purely through the protocol.
- **`ModalRenderer`** — the one protocol a SwiftUI backend implements — has **no UIKit types in any signature**:
  `present(_ descriptor:, id:, resolve:)`, `update(_ id:, to:)`, `dismiss(_ id:)`, `setHidden(_ id:, _:)`.
  Its `import UIKit` (`ModalRenderer.swift:1`) is **vestigial** — drop it as part of this work.

So: swap the injected renderer, everything above it (VM → executor → coordinator → token) is unchanged.

## 2. Deliverable

1. **`SwiftUIModalRenderer: ModalRenderer`** — the four protocol methods, backed by SwiftUI hosting.
2. **A descriptor → SwiftUI `View` mapping** — mirrors what `UIKitModalRenderer` does when it turns a
   descriptor into a `GBAlertModal`. Start with `AlertDialog` only (the one descriptor that exists today).
3. Drop the vestigial `import UIKit` from `ModalRenderer.swift`.
4. Tests (see §5).

**Not in scope:** porting all 26 catalog shapes to SwiftUI (they're `SampleAlertModal`/UIKit demo art;
only `AlertDialog` is a real library descriptor). Add shapes when a real SwiftUI caller needs them.

## 3. The one real design call — imperative renderer vs. declarative SwiftUI

The renderer is **imperative** (`present`/`dismiss` called on it); SwiftUI presentation is **declarative**
(a view binds to state). Bridge inside the renderer — do NOT push this up the seam:

- The renderer owns an observable slot: `@Published var live: [ModalID: AnyModalContent]` (or a single
  optional if it only ever hosts one, which under a coordinator it does).
- `present` inserts + stores the `resolve` closure; the button tap in the SwiftUI view calls `resolve(result)`;
  `dismiss` removes; `setHidden` toggles an `opacity`/`allowsHitTesting` flag on the entry (NOT removal —
  hide must not resolve, same contract as UIKit `isHidden`).
- Host it with a `ModalHostView` the app drops once at the root: an overlay `ZStack` bound to the renderer's
  published slot. `fullScreenCover(item:)` also works but fights the coordinator's own serial/dimmed geometry —
  prefer a plain overlay so the library keeps owning the single-slot geometry it already enforces.

**Do NOT** try to make `executor.present` return a SwiftUI `Binding` or expose `.sheet(item:)` at the API.
If a caller wants the idiomatic `.sheet(item:)` feel, that's a thin **VM-side** adapter (`@Published activeModal`
driven from the async token) — app code, not library, not a seam change.

## 4. Contracts the renderer MUST honor (same as UIKit — these are load-bearing)

- **`resolve` fires exactly once per presentation**, on a user action. The token enforces exactly-once
  (`ModalToken.resolve` ignores extras), but don't lean on that — a double-resolve masks a view-state bug.
- **`dismiss(id)` on a shown modal MUST call the stored `resolve` with the dismissed value** — the coordinator's
  `finish()`/advance depends on the resolve baton coming back (this is how interrupt/teardown-drain advance the
  queue). A SwiftUI renderer that just removes the view WITHOUT resolving strands the coordinator's `current`.
  (This is the exact class of bug the hardening pass caught on the executor side.)
- **`setHidden` MUST NOT resolve** — visibility only. Coordinator uses it for tab push/pop.
- `@MainActor` throughout (protocol already requires it).

## 5. Tests

- **Parity via the existing coordinator/executor tests:** the strongest check is that
  `RootScreenModalCoordinatorTests` + `ModalExecutorCoordinatorTests` pass against `SwiftUIModalRenderer`
  swapped in for `SpyRenderer`/`UIKitModalRenderer`. If serial/dedup/priority/interrupt/hide-show/drain all
  stay green with the new backend, the backend honors the baton contract. (Consider parameterizing the suite
  over renderer, or a thin SwiftUI-specific mirror of the SpyRenderer conservation test.)
- **One hosting smoke test** in the Example app, same shape as `DialogCatalogSmokeTests`: host `ModalHostView`
  in a throwaway window, `present(AlertDialog…)`, force a layout pass, assert the SwiftUI view graph built
  and a simulated tap routes to `resolve`.
- **The dismiss-resolves-baton test is mandatory** (§4 bullet 2) — it's the one non-obvious contract a SwiftUI
  author is most likely to break.

## 6. Deferred (don't build until a caller needs it)

`.sheet(item:)`/native-presentation adapter, all 26 catalog shapes in SwiftUI, SwiftUI-native animation/
transition parity with the UIKit modal, a `@Observable` (iOS 17) variant of the slot if the min target rises
from iOS 13. None block the core renderer.

## 7. Gotchas

- **Test run:** `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17'`
  (iOS 13 target; `swift test` won't compile — iOS-only package). `-only-testing:` for tight loops.
- **iOS 13 min target:** no `@Observable`, no `.fullScreenCover(item:)` before iOS 14 — use
  `ObservableObject`/`@Published` + an overlay `ZStack`. Bump only if the package min target moves.
- The coordinator already enforces single-slot dimmed-fullscreen geometry; the SwiftUI host should render ONE
  entry at a time under a coordinator. Only the direct (no-coordinator) path can stack — match UIKit behavior.
