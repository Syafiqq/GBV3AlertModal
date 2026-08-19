# GBAlertModal Decomposition & Robustness — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decompose the 1,146-line `GBAlertModal.swift` god-file into focused, well-bounded units (no file over ~250 lines), extract two independently-testable collaborators, and fix brittle logic + degenerate-case visual quirks — all gated by the existing test net.

**Architecture:** Hybrid. Extension-split `GBAlertModal` by responsibility into `GBAlertModal+X.swift` files; break the 308-line `registerDialogView`; split `ButtonAction.swift` into data/behavior; extract `ModalKeyboardAvoider` and pure layout math as owned, unit-testable collaborators. Then Tier-1 (behavior-neutral) and Tier-2 (deliberate re-baseline) fixes.

**Tech Stack:** Swift 5.9, iOS 13+, UIKit, SnapKit, XCTest, swift-snapshot-testing, `xcodebuild test` on iOS Simulator.

## Global Constraints

- Simulator is **iPhone 17**. Full suite: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17'`.
- **The existing net is the guardrail: 123 tests + 20 snapshots.** Tier-1 tasks are behavior-neutral — the full suite must stay green with ZERO snapshot diffs after each task. A diff means the move changed behavior → reconcile, do not re-baseline.
- **Tier-2 tasks intentionally re-baseline ONLY the affected snapshots** — record before/after, and each Tier-2 task must be independently reviewable/approvable.
- No file over ~250 lines when the plan completes.
- No public API change except *completing* `ResolvedModal` routing (Task 8) — `ResolvedModal`/`resolve(...)` signatures stay; the view reads more of it. No new runtime dependency.
- Pure-move tasks relocate NAMED methods **verbatim** (bodies unchanged, access levels preserved) — the plan lists which methods go where; it does not reproduce unchanged bodies.
- New collaborators are `internal` (or `public` only if a test needs `@testable`), live in their own files, and get their own unit tests (pure inputs → outputs).
- Work on branch `refactor/decompose-modal` (create from current HEAD of `chore/spm-library-and-tests`). Commit per task.

**Source file map (created/modified):**
```
Sources/GBV3AlertModal/
  GBAlertModal.swift                     (shrinks to shell: class, outlets, init/deinit)
  GBAlertModal+Lifecycle.swift           (new)
  GBAlertModal+Callbacks.swift           (new)
  GBAlertModal+Events.swift              (new)
  GBAlertModal+ViewFactory.swift         (new)
  GBAlertModal+ViewGraph.swift           (new)
  GBAlertModal+Layout.swift              (new)
  GBAlertModal+Style.swift               (new)
  GBAlertModal+Model.swift               (new)
  Support/ModalKeyboardAvoider.swift     (new collaborator)
  Support/ModalLayout.swift              (new pure layout math, or fold into +ResolvedModal)
  Components/GBAlertModal+ActionStyle.swift    (new — from ButtonAction split)
  Components/GBAlertModal+ButtonStyling.swift  (new — from ButtonAction split)
```

---

## Task 1: Split lifecycle + callbacks + events (pure move)

**Files:** Create `+Lifecycle.swift`, `+Callbacks.swift`, `+Events.swift`; modify `GBAlertModal.swift`.

**Move verbatim (from the current GBAlertModal.swift):**
- `+Lifecycle.swift`: `layoutSubviews` (83), `show(parent:completion:)` (150), `hide` (169), `dismiss` (181), `dismissAndEmit` (187), `updateDialog` (194), `changePrimaryActionEnableState` (208), `changeSecondaryActionEnableState` (218).
- `+Callbacks.swift`: `onOverlayTapped` (94), `onPrimaryActionTapped` (108), `onSecondaryActionTapped` (113), `onActionButtonPressed` (118), `onActionButtonUnPressed` (131), `onCloseTapped` (144).
- `+Events.swift`: `registerEvents` (786), `unregisterEvents` (810).

Each moved into `extension GBAlertModal { }` (or `private extension` where the originals were private — preserve `@objc`/`private`/`public` exactly).

- [ ] **Step 1: Create the three files, move the named methods verbatim, remove them from GBAlertModal.swift**

Preserve every attribute (`@objc`, `private`, `public`, `override`). `@objc private` methods referenced by `#selector` must remain reachable — keep them `private` in a `private extension` in the SAME module (works) or `@objc` as-is.

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Full suite (behavior-neutral gate)**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`
Expected: all passing, no snapshot diffs.

- [ ] **Step 4: Commit** — `refactor: split lifecycle/callbacks/events into extension files`

---

## Task 2: Split view-factory + style + model (pure move)

**Files:** Create `+ViewFactory.swift`, `+Style.swift`, `+Model.swift`; modify `GBAlertModal.swift`.

**Move verbatim:**
- `+ViewFactory.swift`: `initDesign` (1057) and all `generate*Design` methods (`generateGenericViewDesign` 1083, `generateStackViewForContentDesign` 1089, `generateImageViewForBannerDesign` 1099, `generateLabelForTitleDesign` 1106, `generateScrollForCustomViewDesign` 1116, `generateLabelForSubtitleDesign` 1124, `generateStackViewForMainButtonDesign` 1132, `generateButtonForCloseDesign` 1141).
- `+Style.swift`: `adjustDialogViewStyle` (609).
- `+Model.swift`: `updateProperties` (836), `makeResolvedModal` (263), `initData` (257), `initViews` (239), `initEvents` (250).

- [ ] **Step 1: Create files, move named methods verbatim, remove from GBAlertModal.swift**
- [ ] **Step 2: Build** — BUILD SUCCEEDED
- [ ] **Step 3: Full suite** — all passing, no diffs
- [ ] **Step 4: Commit** — `refactor: split view-factory/style/model into extension files`

---

## Task 3: Decompose the 308-line `registerDialogView` into `+ViewGraph.swift`

**Files:** Create `GBAlertModal+ViewGraph.swift`; move `registerDialogView` (300-608) and `unregisterDialogView` (274) there, then decompose.

The method has three internal `// MARK:` sections: View Initialization, View Graph, View Constraints. Decompose into focused private builders on the same extension, called in order by a thin `registerDialogView`:

**Interfaces (produce):**
- `private func buildBannerComponent(_ resolved: ResolvedModal)` , `buildTitleComponent`, `buildSubtitleComponent`, `buildActionComponents`, `buildCloseComponent` — each creates + assigns its outlets and adds to the view graph for that component only.
- `private func assembleViewGraph()` — parent/child `addSubview`/`addArrangedSubview` wiring.
- `private func installConstraints()` — the constraint block.
- `registerDialogView()` becomes: resolve → build each component → assemble → install constraints.

**Rule:** pure extraction — the union of the builders must produce the identical view tree + constraints as the original method. No behavior change.

- [ ] **Step 1: Move `registerDialogView`/`unregisterDialogView` to `+ViewGraph.swift` verbatim; build + full suite green; commit checkpoint** (`refactor: move view-graph methods to +ViewGraph`)
- [ ] **Step 2: Read the whole method; extract the per-component builders + assemble + installConstraints exactly, keeping the call order identical**
- [ ] **Step 3: Build** — BUILD SUCCEEDED
- [ ] **Step 4: Full suite** — all passing, ZERO snapshot diffs (this is the proof the decomposition preserved the view tree)
- [ ] **Step 5: Commit** — `refactor: decompose registerDialogView into per-component builders`

---

## Task 4: Split `ButtonAction.swift` into data + behavior

**Files:** Create `Components/GBAlertModal+ActionStyle.swift` (the `ActionStyle` enum + `CapsuleTheme`/`CapsuleOutlineTheme`/`PlainTheme`/`ObliqueBottomLeftTheme` structs) and `Components/GBAlertModal+ButtonStyling.swift` (the styling application: `configureButtonActionStyle` and the pressed/unpressed helpers). Delete `Components/GBAlertModal+ButtonAction.swift`.

- [ ] **Step 1: Move the type definitions to +ActionStyle.swift and the application functions to +ButtonStyling.swift verbatim**
- [ ] **Step 2: Build** — BUILD SUCCEEDED
- [ ] **Step 3: Full suite** — all passing, no diffs
- [ ] **Step 4: Commit** — `refactor: split ButtonAction into ActionStyle (data) + ButtonStyling (behavior)`

---

## Task 5: Extract `ModalKeyboardAvoider` collaborator

**Files:** Create `Support/ModalKeyboardAvoider.swift` + `Tests/.../ModalKeyboardAvoiderTests.swift`. Modify the keyboard extension (currently GBAlertModal.swift 880-1028) to delegate the geometry computation.

**Design:** the brittle math (`adjustDialogPosition`, `onKeyboardChangeFrameNotification` offset computation, `restoreDialogPosition`) becomes a pure function on a small type:
```swift
struct ModalKeyboardAvoider {
    /// Given the keyboard frame, the dialog's frame in window space, and the container's
    /// bottom inset, returns the vertical offset to apply (0 when the keyboard doesn't overlap).
    func offset(keyboardFrame: CGRect, dialogFrame: CGRect, safeBottom: CGFloat, emptySpace: CGFloat) -> CGFloat
}
```
(Confirm the exact inputs against the current code when you read it — match the existing formula EXACTLY. The notification plumbing stays in the view; only the computation moves.)

- [ ] **Step 1: Write failing unit tests** for `offset(...)`: keyboard below dialog → 0; keyboard overlapping → positive offset equal to overlap (+ emptySpace); fully covered dialog → clamped. Use the exact numbers from the current formula.
- [ ] **Step 2: Run tests → FAIL** (type not defined). `... -only-testing:GBV3AlertModalTests/ModalKeyboardAvoiderTests`
- [ ] **Step 3: Implement `ModalKeyboardAvoider.offset(...)` mirroring the current formula; wire the view's keyboard handlers to call it**
- [ ] **Step 4: Unit tests GREEN + full suite green (no diffs)** — keyboard behavior unchanged
- [ ] **Step 5: Commit** — `refactor: extract ModalKeyboardAvoider with unit tests`

---

## Task 6: Extract pure layout math into `+Layout.swift` + `ModalLayout`

**Files:** Create `Support/ModalLayout.swift` (pure functions) + tests; move `adjustBaseDialogConstraint` (643), `adjustVwContainerConstraint` (652), `adjustSvContentContainerConstraint` (683), `adjustSvContentContainerConstraintWidth` (752), `resolvedContentWidths` (772) into `GBAlertModal+Layout.swift`; extract the computable geometry (esp. `resolvedContentWidths` and any width/inset math) into `ModalLayout` pure functions.

**Interface:** `resolvedContentWidths` already returns `(fixed:, max:)` from `ResolvedModal.contentWidth` — promote that (and any sibling pure math) to `ModalLayout` static funcs taking plain inputs, unit-tested; `+Layout.swift` applies the SnapKit constraints from the results.

- [ ] **Step 1: Move the adjust* methods to +Layout.swift verbatim; build + suite green; commit checkpoint**
- [ ] **Step 2: Write failing unit tests for the extracted `ModalLayout` width/geometry funcs (plain inputs → expected), then implement by lifting the existing math**
- [ ] **Step 3: Unit tests GREEN; +Layout applies results; full suite green (no diffs)**
- [ ] **Step 4: Commit** — `refactor: extract pure ModalLayout math with unit tests`

---

## Task 7: Tier-1 fixes (behavior-neutral)

**Files:** modify `+Lifecycle.swift` (show), `+ResolvedModal.swift` + call sites, remove `isPad`.

- [ ] **Step 1: Remove the dead `weak var parent = parent` in `show(parent:)`** — replace the weak-then-guard with a direct use of the strong `parent` param. Build + suite green.
- [ ] **Step 2: Route `dismissOnAction`/`closeOnTapOverlay` through `ResolvedModal`.** `dismiss()`, `dismissAndEmit()`, `onOverlayTapped()` read `resolved.dismissOnAction`/`resolved.closeOnTapOverlay` instead of `dataHolder?.…`. Also route the subtitle outer-gate (currently the inline non-nil check) through the resolver. Add/extend a Layer A/B test asserting these fields are now the source of truth. Suite green (identical behavior — the resolver fields equal the dataHolder values).
- [ ] **Step 3: Drop the inert `isPad` parameter** from `resolve(...)` (verified unused), OR add a doc comment marking it reserved. Recommend DROP — it currently misleads. If dropped, update all callers + tests. Build + suite green.
- [ ] **Step 4: Commit** — `refactor: tier-1 fixes — dead weak parent, full ResolvedModal routing, drop inert isPad`

---

## Task 8: Tier-2 — empty-banner region (re-baseline)

**Files:** `+ViewGraph.swift` (banner builder) + `+ResolvedModal.swift` (`showsBanner`) + snapshot re-baseline + test.

**Change:** treat the banner as absent when `holder.banner == nil` OR its size is degenerate (`width == 0 || height == 0`). `showsBanner` becomes `banner != nil && banner.size.width > 0 && banner.size.height > 0`; the builder reserves no banner slot/space when `!showsBanner`.

- [ ] **Step 1: Add a failing Layer A test**: `resolve` with a zero-size `UIImage()` → `showsBanner == false`. Run → FAIL (currently true).
- [ ] **Step 2: Implement the `showsBanner` guard + builder skip**
- [ ] **Step 3: Layer A green; re-record the affected `withBanner` snapshots** (the zero-size fixture now shows no empty gap) — `... -only-testing:...LayerC.../test_standardDialog_withBanner_portrait` (record), inspect the PNG shows no empty region, re-run PASS. Full suite green.
- [ ] **Step 4: Commit** — `fix: collapse banner slot for nil/zero-size image (Tier 2, re-baselined)`

---

## Task 9: Tier-2 — orientation source (re-baseline)

**Files:** `+Layout.swift` / `Extensions/UIWindow+Orientation.swift` usage + `makeResolvedModal` + snapshots + test.

**Change:** derive `isLandscape` from the view's own geometry (`bounds.width > bounds.height`, or `traitCollection`) instead of `UIWindow.isLandscape` (real scene). This makes the landscape width branch fire from the actual layout size and become deterministic.

- [ ] **Step 1: Add a Layer B/behavioral test** proving that a modal laid out in a landscape-sized host selects the landscape width branch (use a preset with `fixedWidthLandscape != fixedWidthPortrait` so the branch is observable). Run → FAIL (today reads scene, not host).
- [ ] **Step 2: Change `makeResolvedModal()` to compute `isLandscape` from the view's bounds/traits; keep `resolve(isLandscape:)` parameter-driven**
- [ ] **Step 3: Test green; re-record any affected `_landscape` snapshots** (shipped presets use equal widths → most won't diff; inspect any that do). Full suite green.
- [ ] **Step 4: Commit** — `fix: derive orientation from view geometry, not window scene (Tier 2)`

---

## Task 10: Tier-2 — empty-subtitle quirk (re-baseline)

**Files:** `+ResolvedModal.swift` (subtitle kind) + `+ViewGraph.swift` (subtitle builder) + test + snapshots.

**Change:** treat a non-nil but empty `subtitle`/`subtitleAttributed` as absent — `SubtitleKind.none`, no scroll container built.

- [ ] **Step 1: Failing Layer A test**: `resolve` with `subtitle: ""` → `.none`. Run → FAIL (currently `.plain("")`).
- [ ] **Step 2: Add the empty check in the resolver + skip the container in the builder**
- [ ] **Step 3: Layer A green; re-record any affected snapshot (none shipped uses empty subtitle — add a tiny fixture if needed to lock it). Full suite green.**
- [ ] **Step 4: Commit** — `fix: treat empty subtitle as absent (Tier 2)`

---

## Task 11: Tier-2 — `subtitleCustomView` ownership

**Files:** `Components/GBAlertModal+DataHolder.swift` (or the view's retention) + test.

**Change:** the modal must retain its custom subtitle view so callers don't need an external strong ref. `subtitleCustomView` is currently `weak`; make the VIEW hold a strong reference once installed (e.g. it's in the view hierarchy, so retained — verify; if the `weak` on `DataHolder` causes early release before install, hold it strongly through installation).

- [ ] **Step 1: Failing test**: build a modal with a `subtitleCustomView` created inline (no external ref), render, assert the custom view is still in the hierarchy (not deallocated). Run → observe current behavior.
- [ ] **Step 2: Ensure the modal retains the custom view through install (add a strong stored ref if needed); do not change the public `DataHolder` signature**
- [ ] **Step 3: Test green; full suite green (the GeniePresets `retainedViews` test stash can be removed if the fix makes it unnecessary — verify)**
- [ ] **Step 4: Commit** — `fix: modal retains subtitleCustomView (Tier 2)`

---

## Self-Review

**Spec coverage:** decomposition (Tasks 1-4), collaborators (Tasks 5-6), Tier-1 fixes (Task 7), Tier-2 fixes (Tasks 8-11) — matches the design's Section 1 + Section 2. No gaps.

**Placeholders:** pure-move tasks name exact methods/line ranges (from the current MARK map) rather than reproducing unchanged bodies — legitimate for relocation. New-code tasks (5,6,8-11) give the interface + the failing test; the extraction body is derived from existing code the implementer reads. No vague "add error handling."

**Type consistency:** `ResolvedModal`, `resolve(...)`, `ModalKeyboardAvoider.offset(...)`, `ModalLayout`, `showsBanner`, `SubtitleKind` used consistently across tasks.

**Ordering/dependency:** pure moves first (1-4) so later fixes edit small focused files; collaborators (5-6) before their consuming fixes; Tier-1 (7) before Tier-2 (8-11); each Tier-2 task independent and separately re-baselineable.

**Risk note:** Task 3 (308-line decomposition) is the highest-risk — it carries a checkpoint commit (move verbatim first) before decomposing, and the zero-diff snapshot gate is the proof. Task 9 (orientation) is the most behavior-visible — isolated as its own task with an observable-branch test.
