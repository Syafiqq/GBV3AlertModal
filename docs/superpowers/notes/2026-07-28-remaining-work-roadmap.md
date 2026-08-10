# SwiftUI Alert Modal — Remaining Work Roadmap

**Date:** 2026-07-28
**State:** Phase 1 (library descriptor) approved. Phase 2 (SwiftUI realization) complete + on-device
design-faithful + all 3 test layers green. Tier 0 proven. Everything unmerged on
`feat/modal-executor-capability`.

---

## GATE — the Tier decision (owner)

Everything below hangs off one choice. The prototype is now faithful enough (real colours, real
spacing/width/oblique verified on an iPhone 13) and Tier 0 is proven, so it's decidable now.

- **keep-pure-local** — SwiftUI screens own their modals with local `@State`. Nothing more to build.
- **Tier 0** — SwiftUI VMs call the existing executor; the UIKit modal paints over SwiftUI. **Proven
  working.** Only optional ergonomics remain (§B).
- **Tier 1** — a native SwiftUI-drawn renderer in the library. The real remaining build (§C).

> The depth of this design pass (perfecting the SwiftUI look) implies **Tier 1** is the intent —
> confirm before starting §C.

---

## §B — If Tier 0 (small)

- B1. Optional ~10-line `.sheet(item:)`-style VM adapter so SwiftUI screens get an idiomatic binding
  over `token.result` (library API stays `token.result`; adapter is app/example-side).
- B2. Short usage doc: "a SwiftUI VM triggers a dialog with `await executor.presentAndWait(…)`."
- (No renderer, no new views. Tier-0 hosting is already proven by `Tier0HostingSmokeTests`.)

## §C — If Tier 1 (the substantive build)

- **C1. Promote the SwiftUI surface into the library.** Move `AlertModalScaffold`, `SwiftUIAlertModal`,
  `ModalTokens`, `ModalButtonStyles`, `AlertResolution` + their tests from the example app into
  `Library/GBV3AlertModal`. Re-review under library constraints (public API surface, iOS-15
  back-deploy, no example-only shortcuts). Add ViewInspector + swift-snapshot-testing to the
  *library* test target (same pbxproj-free SPM add, but Package.swift this time).
- **C2. Build `SwiftUIModalRenderer: ModalRenderer`.** Map `present/update/dismiss/setHidden` →
  `@Published` state that drives the SwiftUI view. Wire it as an injectable alternative to
  `UIKitModalRenderer`. Prove parity by swapping it into the existing coordinator tests
  (serial/dedup/priority/interrupt/drain) — they should pass unchanged.
- **C3. Case-type parity** (the real gaps vs UIKit):
  - `PopupDialog` — SwiftUI descriptor + view.
  - Input dialogs — text-field (rename) and date-picker (worksheet) variants; needs a SwiftUI input
    surface + result plumbing.
  - Remaining bespoke content — badge grid, worksheet container (satisfaction already done as the
    exemplar via `AlertModalScaffold`).
- **C4. Bundle the SHSans font** into the library so type matches the app exactly (currently SwiftUI
  system font — sizes/weights match, family does not).
- **C5. Animation / transition parity** — present/dismiss + the no-blink in-place swap as real
  SwiftUI transitions; snapshot/observe.
- **C6. Coordinator lifecycle in SwiftUI** — hide/show, pause/resume, teardown-drain against the
  SwiftUI renderer.

## §D — Cross-cutting (any tier)

- **D1. Merge decision.** The branch is **92 commits / 219 files** ahead of `main`, merges clean, but
  it's all-or-nothing: it lands the executor capability + Swift 6 language-mode flip + iOS-15 floor +
  ViewInspector/SnapshotTesting deps + the SwiftUI prototype. Decide: reviewed PR of the whole branch
  (scoped honestly), or keep unmerged. Not a small descriptor change — see
  `2026-07-28` dry-run in session history.
- **D2. Route the orange→blue press hue-flip** to the designer —
  `docs/superpowers/notes/2026-07-28-findings-for-designer-oblique-press-hueflip.md` (real app theme
  issue, not ours).
- **D3. App migration (142 sites).** Separate downstream effort owned by the app team; out of this
  module's scope. Only defines which descriptor kinds the capability must support.

---

## Suggested order

1. **Owner: pick the Tier** (gate).
2. If Tier 1: **C1 (promote) → C2 (renderer) → C3 (case types) → C4/C5/C6 (font/animation/coordinator).**
3. **D1 (merge)** whenever the owner wants to land it — independent of tier.
4. **D2/D3** are hand-offs, not builds.
