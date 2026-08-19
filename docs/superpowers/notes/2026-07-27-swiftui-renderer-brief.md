# Brief: SwiftUI renderer — `SwiftUIModalRenderer` (renderer PARKED — UI-first next; see 2026-07-27 SESSION UPDATE below)

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

## SESSION UPDATE 2026-07-27 — direction locked (council-vetted), UI-FIRST sequence chosen

Owner brainstormed SwiftUI support this session (5-lens council: Torvalds / Rams / Taleb / Feynman / Ada).
The renderer itself is STILL deferred — but the framing, delivery tiers, topology, testability, and the
next step are now locked. **Owner will PLAN the SwiftUI UI in the next session; start there.** §1–§7 below
remain valid as the Tier-1 renderer spec; this block supersedes the *sequencing*.

### The reframe: "alongside" is already true, no renderer required for it
The whole app is UIKit; a SwiftUI screen is a `UIHostingController` inside the SAME `UIWindow`. The existing
`UIKitModalRenderer` paints onto the key window — so it ALREADY draws correctly over SwiftUI-hosted content.
A SwiftUI VM calling `await executor.presentAndWait(AlertDialog…)` gets a correct modal with ZERO new code.
"Run alongside UIKit" is one modal system serving both stacks through one window slot. (REASONED from the
shipped architecture; NOT yet observed — see UNPROVEN below.)

### Two-tier delivery
- **Tier 0 — the paradigm, zero library code, available now.** Inject the existing `DefaultModalExecutor`
  (UIKit renderer) into SwiftUI VMs. Modal renders UIKit, over the SwiftUI screen. This IS the centralized
  presenter SwiftUI best-practice converges on anyway (next point).
- **Tier 1 — native SwiftUI renderer** (§2–§5 of this brief). Only when the modal must be DRAWN/animated by
  SwiftUI. Swap the injected renderer; everything above it unchanged. **Scale S = the SEAM only, NOT visual
  parity** — animation/dimming/the 26 catalog shapes are separate and unestimated.

### Why the executor beats pure per-view `.sheet` (the design argument)
Per-view `.sheet(item:)` is right for a SCREEN-LOCAL modal. For CROSS-CUTTING dialogs (errors,
session-expiry, paywall) it forces a flag + a modifier in every screen → sprawl. The mature SwiftUI answer
is ONE injected presenter — exactly what `ModalExecutor` is. `catch { await executor.presentAndWait(.error) }`
from any SwiftUI VM is the idiomatic centralized pattern, not a compromise. Choose by concern: screen-local
→ native `.sheet`; cross-cutting → executor.

### Topology LOCK (Taleb + Ada, unanimous): never two peer renderers
If UIKit + SwiftUI ever render at once, use ONE composite renderer dispatching per-descriptor to a UIKit OR
SwiftUI backend into the SAME single slot, under ONE coordinator (Ada's **T4** — provably preserves
single-slot + resolve-on-every-exit). TWO peer renderers = two window slots = the coordinator's
serial/dedup/priority invariant silently voids at a boundary that moves every sprint = Black Swan. Two
coordinators (T3) is invalid outright. The seam already supports T4 — it's a switch inside one conformance.

### API surface LOCK (Rams): library stays `token.result`
No `.sheet`/`Binding`/Combine in the library — that lies about who drives the render loop. The idiomatic
`.sheet(item:)` feel is a ~10-line APP-SIDE VM adapter (`@Published activeModal` driven from the async
token). Promote to a shared helper only after 2–3 real usages, still app-side.

### Testability (holds up; arguably better than pure SwiftUI)
- **VM:** fully headless via a fake `ModalExecutor` (it's a protocol). `await presentAndWait` makes the whole
  request→result→reaction one awaitable line — MORE testable than pure-SwiftUI flags (which can't easily
  assert the post-tap reaction). Mirrors the repo's existing `SpyRenderer` pattern.
- **View:** SwiftUI's weak spot, same for everyone — but the executor moves logic OUT of the view. Snapshot
  (existing pointfree infra) for appearance; ONE hosting smoke test for tap→resolve.
- **Parity for free:** run the existing `RootScreenModalCoordinatorTests` / `ModalExecutorCoordinatorTests`
  against `SwiftUIModalRenderer` swapped in for the spy. Green = backend honors the baton contract.

### Accepted risk (convention, not mechanism): z-order vs SwiftUI's own presentation
Do NOT interleave an executor (window-subview) modal with a SwiftUI screen's OWN `.sheet` /
`.fullScreenCover` — z-order between the two presentation mechanisms is not guaranteed. Fix by routing that
screen's modal through the executor too (one mechanism per screen). Mediocristan; named, not guarded.

### The one OPEN product fork (owner to decide — gates Tier 1)
Do SwiftUI screens need modal CONTENT authored in SwiftUI (native look/animation/`@Observable`), or just to
TRIGGER a modal? Trigger-only → Tier 0, build nothing. Native content (or a future pure-SwiftUI app with NO
`UIWindow`) → build the Tier-1 renderer. Neither exists today.

### CHOSEN NEXT STEP (owner, this session): UI-FIRST, empirical — the thing to PLAN next session
Instead of proving the seam on paper, build a PURE-SwiftUI UI first, judge it, THEN decide executor/
coordinator integration. Next-session plan target (all pure SwiftUI, local `@State`, **NO executor**):
- `SwiftUIAlertModal` — native SwiftUI view mirroring `GBAlertModal` CONTENT (dimmed overlay + card:
  optional banner, title, subtitle, primary, optional secondary, optional close) + an `onAction` callback.
- `SwiftUIDemoScreen` — SwiftUI host driving it with LOCAL `@State` (idiomatic overlay/`ZStack`).
- Wire into the example app via `UIHostingController`, reachable from the existing UIKit entry.
- **Location: EXAMPLE APP, not the library** — zero library changes until the executor decision is made.
- **Fidelity:** content-faithful to `GBAlertModal`; native SwiftUI idioms for layout/animation (not a
  pixel-clone of the SnapKit version).
- Then decide: keep pure-local `.sheet`, or route through executor (Tier 0) / build the renderer (Tier 1).

### iOS floor bumped to 15 (DONE this session — verified 224/224 green)
`Package.swift` `.v13→.v15` + example app 8 configs `13.0→15.0` + dead `#available(iOS 13)` guard removed
(`AppCompatHelper.keyWindow`). So `@StateObject`, `.fullScreenCover(item:)`, `@Environment(\.dismiss)` are
all available; `@Observable` still iOS 17. Consumers (distribution app) now require iOS 15+ — owner
explicitly accepted ("nuke 13, all go with 15").

### UNPROVEN (cheapest thing to validate, whichever path is chosen)
The Tier-0 foundation — "executor modal paints correctly over a `UIHostingController` SwiftUI host" — is
reasoned, not observed. A single hosting smoke test (host a SwiftUI view, `await presentAndWait`, assert it
shows on top + a tap resolves) collapses that uncertainty for ~1hr. Worth doing before building on it.

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
to iOS 17. None block the core renderer.

## 7. Gotchas

- **Test run:** `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17'`
  (iOS 15 target; `swift test` won't compile — iOS-only package). `-only-testing:` for tight loops.
- **iOS 15 min target** (bumped from 13 on 2026-07-27, package + example app both at 15): `@StateObject`,
  `.fullScreenCover(item:)`, and `@Environment(\.dismiss)` are all available — use them. Still NO
  `@Observable` (iOS 17); use `ObservableObject`/`@Published` for the slot. Overlay `ZStack` remains the
  host of choice (not `.fullScreenCover`) so the library keeps owning the single-slot dimmed geometry.
- The coordinator already enforces single-slot dimmed-fullscreen geometry; the SwiftUI host should render ONE
  entry at a time under a coordinator. Only the direct (no-coordinator) path can stack — match UIKit behavior.
