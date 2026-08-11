# GBV3AlertModal — Decomposition & Robustness Design

**Date:** 2026-07-21
**Status:** Approved (brainstorming) — pending spec review → implementation plan

## Goal

Refactor `GBAlertModal` into maintainable, well-bounded units — **no god-size file** — while fixing brittle logic and degenerate-case visual quirks. All protected by the existing test net (123 tests + 20 snapshots). "UI consistent" = the shipped Geniebook UI renders identically; edge cases become coherent.

## Context

`GBAlertModal.swift` is 1,146 lines with one 308-line method (`registerDialogView`). The decision layer (`ResolvedModal` + `resolve(...)`) was already extracted (pure, unit-tested). This design decomposes the remaining rendering/layout/lifecycle god-object and extracts two independently-testable collaborators.

**Strategy: Hybrid.** Extension-split by responsibility as the backbone; extract collaborators only for the genuinely independent, brittle, math-heavy pieces (keyboard avoidance, layout geometry).

## Section 1 — Decomposition

Target: no file over ~250 lines, one responsibility each.

`GBAlertModal.swift` → shell only: class decl, outlets/state, `init`/`deinit` (~120 lines).

| File | Owns |
|---|---|
| `GBAlertModal+Lifecycle.swift` | `show`/`hide`/`dismiss`/`dismissAndEmit`/`updateDialog`/`changeEnableState`, `layoutSubviews` |
| `GBAlertModal+Callbacks.swift` | `on*Tapped` handlers |
| `GBAlertModal+Events.swift` | gesture + target-action wiring (`registerEvents`/`unregisterEvents`) |
| `GBAlertModal+ViewFactory.swift` | `generate*Design` builders + `initDesign` |
| `GBAlertModal+ViewGraph.swift` | `registerDialogView`/`unregisterDialogView` — **308-line method decomposed into per-component builders** (banner/title/subtitle/actions/close), then assembled |
| `GBAlertModal+Layout.swift` | `adjust*` constraint methods (thin; geometry delegated to pure functions) |
| `GBAlertModal+Style.swift` | `adjustDialogViewStyle` theming |
| `GBAlertModal+Model.swift` | `updateProperties`, `makeResolvedModal` |

**Collaborators (new, independently unit-testable):**
- `ModalKeyboardAvoider` — the ~148-line keyboard block as a pure-ish type: *(keyboard frame, view geometry) → offset*. Unit-testable without a live keyboard.
- **Layout math** joins `ResolvedModal`/a pure `ModalLayout` as functions; `+Layout.swift` applies results.

**Also split `ButtonAction.swift` (401 lines):**
- `GBAlertModal+ActionStyle.swift` — enum + 4 theme structs (data).
- `GBAlertModal+ButtonStyling.swift` — `configureButtonActionStyle` + pressed/unpressed (behavior).

**Guardrail:** behavior-neutral. 123 tests + 20 snapshots stay green throughout; a red file means the move changed behavior → reconcile before continuing.

## Section 2 — Fixes

### Tier 1 — behavior-neutral (snapshots stay green)
- All file splits + the 308-line method decomposition.
- Remove dead `weak var parent = parent` in `show()`.
- Route `dismissOnAction` / `closeOnTapOverlay` / subtitle outer-gate through `ResolvedModal` → completes the SwiftUI equivalence spec, identical behavior.
- Drop the inert `isPad` param (or document as reserved).

### Tier 2 — deliberate UI/robustness fixes (snapshots re-baselined on purpose, per-item approval, before/after shown)
1. **Empty-banner region** — when `banner` is nil or effectively zero-size, don't reserve the banner slot (kills the empty gap). Shipped app passes real images → real UI unchanged; fixes the degenerate case.
2. **Orientation source** — `UIWindow.isLandscape` → derive from the view's own `bounds`/`traitCollection`. Makes the landscape width branch fire correctly and become deterministic/testable. Shipped presets use equal portrait/landscape widths → shipped UI unchanged.
3. **Subtitle empty-string quirk** — non-nil-but-empty subtitle currently renders an empty scroll container; treat empty as absent (`.none`, no container).
4. **`subtitleCustomView` weak → strong** — modal retains its own custom subtitle view; no external retain needed. Robustness; negligible visual change.

**Through-line:** every Tier 2 item barely touches the shipped Geniebook UI (real presets don't hit these paths); they make edge cases coherent while removing brittleness.

## Testing

- Tier 1: existing 123 tests + 20 snapshots are the regression net; they must stay green after every move.
- New collaborators (`ModalKeyboardAvoider`, layout math) get their own unit tests (pure inputs → outputs), added as they're extracted.
- Tier 2: each item re-baselines only the affected snapshots (before/after reviewed), and adds/updates a targeted test (e.g. empty-banner → no banner slot; empty subtitle → `.none`; orientation branch via the layout function).

## Out of scope
- Bug 2 (localization memoization) — lives in the consumer app, not this repo.
- SwiftUI view implementation — separate downstream project; this design completes its spec (`ResolvedModal`) but does not build it.
