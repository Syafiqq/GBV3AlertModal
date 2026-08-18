# SwiftUI/UIKit Target Independence Implementation Plan

> Implement in order. Every task ends with focused verification and one atomic commit. Do not
> combine behavioral changes, source moves, or manifest edits. UIKit retirement and downstream
> consumer migration are outside this plan.

**Goal:** Make `GBV3AlertModalCore` and `GBV3AlertModalSwiftUI` build and test without UIKit,
Migration, or SnapKit while preserving UIKit through an explicit compatibility surface.

**Design:** [SwiftUI/UIKit Target Independence Design](../specs/2026-08-18-swiftui-uikit-target-independence-design.md)

## Global guardrails

- Before every implementation commit, run `git diff --check`, the focused test command named in
  that task, and the generic iOS Simulator example build when production rendering changes.
- Keep Swift 6 strict concurrency enabled. Do not use `@unchecked Sendable` to silence a boundary
  error. Core values crossing actors must be genuinely value-semantic and `Sendable`; renderer UI
  state remains `@MainActor`.
- Preserve the `ModalToken`/coordinator resolve-on-every-exit invariant and exactly-once continuation
  behavior. Async tests must await observable work or signals and remain bounded; do not add fixed
  sleeps.
- Search symbols as well as imports after every boundary task. Same-module coupling is expected
  before the manifest split and is not visible through `import UIKit` alone.
- Do not regenerate snapshots until a focused native SwiftUI test identifies an intentional layout
  change and the change is visually reviewed.

## Task 1 — Extract the neutral resolver vocabulary

**Files:**

- Create `Library/GBV3AlertModal/Sources/GBV3AlertModal/Core/ResolvedModal.swift`.
- Update `Library/GBV3AlertModal/Sources/GBV3AlertModal/Components/GBAlertModal+ResolvedModal.swift`.
- Update `Library/GBV3AlertModal/Sources/GBV3AlertModal/Support/ModalLayout.swift`.
- Update resolver call sites in `GBAlertModal+Layout.swift`, `SwiftUI/SwiftUIAlertModal.swift`,
  `SwiftUI/EmbeddedModalRenderer.swift`, and `Executor/WindowModalRenderer.swift`.
- Update `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/LayerA_ResolverTests.swift` and
  `Architecture/CorePurityTests.swift`.

**Steps:**

1. Add failing assertions that Core `ResolvedModal.ButtonAxis` is `.horizontal`/`.vertical`, plus a
   synchronous `nonisolated` compile witness that calls the resolver with Sendable stub inputs. Do
   not introduce `Task.detached` merely to demonstrate the absence of actor isolation. Add a purity
   assertion that the Core declaration contains no UI-framework symbol.
2. Move `ResolvedModal`, including `SubtitleKind` and `WidthResolution`, into Core. Replace
   `NSLayoutConstraint.Axis` with the neutral `ButtonAxis`; make all nested values `Sendable` and
   `Equatable`.
3. Move the protocol-based pure resolver body into Core as the one source of truth. Keep temporary
   deprecated `GBAlertModal.resolve` forwarding overloads only if required for source compatibility;
   forwarding code must contain no decision logic.
4. Map the neutral axis to UIKit only at `UIStackView`/layout edges and to `SwiftUI.Axis` only at
   SwiftUI view edges. Update `ModalLayout` to accept Core `WidthResolution`.
5. Run:

   ```sh
   xcodebuild test -scheme GBV3AlertModal \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -only-testing:GBV3AlertModalTests/LayerA_ResolverTests \
     -only-testing:GBV3AlertModalTests/CorePurityTests
   ```

6. Build the example with the brief's generic iOS Simulator command and confirm `rg` finds no
   `NSLayoutConstraint` or UIKit type in `Core/`.
7. Commit: `Extract platform-neutral modal resolver`.

## Task 2 — Make `ModalFont` descriptive and UIKit-free

**Files:**

- Update `Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/ModalFont.swift`.
- Update `Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/ModalTokens.swift` and native layout
  helpers in `SwiftUI/AlertModalScaffold.swift`.
- Add `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/ModalFontTests.swift`.
- Update focused geometry/snapshot tests only where native SwiftUI layout intentionally changes.

**Steps:**

1. Add failing value-semantic tests for system/custom family, all weights, fixed-size default,
   opt-in semantic scaling, missing custom-font fallback behavior, `Equatable`, and `Sendable`.
2. Replace stored `UIFont` with `Family`, `Weight`, `size`, and `ScalingPolicy` values. Keep each
   descriptor type small and value-semantic; if public nested types make the file unwieldy, extract
   them into separate Swift files in the eventual SwiftUI source root.
3. Map the descriptor directly to SwiftUI `Font`. Fixed custom fonts remain fixed; semantic scaling
   uses a declared relative text style. Do not expose `Font -> UIFont` or store a UIKit twin.
4. Remove SwiftUI calls to `ModalLayout.textHeight`, `renderedFont`, and other TextKit measurement.
   Prefer native SwiftUI proposals and layout priorities. If a deterministic measurement remains
   demonstrably necessary, add a SwiftUI-local CoreText implementation and a focused absolute test.
5. Add Dynamic Type/accessibility coverage that proves fixed and relative policies behave as
   documented. Rebaseline absolute SwiftUI geometry only after reviewing the rendered output;
   record the reason beside each changed pin.
6. Run `ModalFontTests`, affected modal layout tests, `git diff --check`, and the generic example
   build. Confirm `ModalFont.swift` contains no `UIKit`, `UIFont`, or `ModalLayout` reference.
7. Commit: `Make SwiftUI modal fonts platform-native`.

## Task 3 — Establish the single SwiftUI token derivation

**Files:**

- Update `SwiftUI/ModalTokens.swift`, `SwiftUI/ModalProperties.swift`, and SwiftUI preset call sites.
- Create temporary adapter files under
  `Library/GBV3AlertModal/Sources/GBV3AlertModal/Migration/` while the package is still one target.
- Add `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Migration/ModalPropertiesAdapterTests.swift`.
- Update `LayerB_WiringTests.swift` and `Support/GeniePresets.swift`.

**Steps:**

1. Add a failing table-driven coverage test that lists every public UIKit `Properties` field and
   requires a mapped SwiftUI field or a documented omission with rationale.
2. Add failing conversion tests for colors, fonts, margins/padding, width/orientation fields, button
   styles, enablement, overlay behavior, and representative preset values.
3. Make `ModalTokens(from: ModalProperties)` the only SwiftUI derivation implementation. Remove all
   SwiftUI initializers/helpers that accept `GBAlertModal.Properties`, `UIColor`, `UIFont`, UIKit
   action styles, or legacy layout measurement.
4. Implement legacy-to-`ModalProperties` adapters in the temporary Migration directory. The adapter
   constructs `ModalProperties`; it never derives `ModalTokens` itself.
5. Update coexistence call sites to adapt first and then call the single token initializer. Confirm
   no duplicated switch or fallback table exists across SwiftUI and Migration.
6. Run the new adapter tests, `LayerB_WiringTests`, the example catalog smoke tests, and the generic
   example build. Search `SwiftUI/ModalTokens.swift` for every forbidden UIKit symbol.
7. Commit: `Isolate legacy modal property adaptation`.

## Task 4 — Move attributed-text adaptation to Migration

**Files:**

- Replace or delete `SwiftUI/AttributedTextBridge.swift`.
- Update `SwiftUI/SwiftUIAlertModal.swift`, `SwiftUIModalRenderer+BespokeViews.swift`, and
  `SwiftUIModalRenderer+InputViews.swift`.
- Add `Migration/LegacyAttributedTextAdapter.swift`.
- Split `Executor/Descriptors/ModalText.swift` into a Core-neutral descriptor contract, a
  UIKit-local renderer adapter, and the cross-backend Migration adapter.
- Add `Tests/GBV3AlertModalTests/Migration/LegacyAttributedTextAdapterTests.swift`.

**Steps:**

1. Add failing adapter tests for legacy foreground color and font conversion, mixed runs, absent
   attributes, and precedence when explicit SwiftUI and UIKit scopes overlap.
2. Keep descriptor payloads in Core as Foundation `AttributedString` without importing either UI
   framework. UIKit's standalone adapter may read Foundation/UIKit attributes and degrade unknown
   SwiftUI-only scopes to plain text; it must not import SwiftUI. Cross-backend Migration converts
   legacy `NSAttributedString`/UIKit scopes into SwiftUI-scoped attributes and preserves explicit
   SwiftUI values when both scopes provide the same semantic attribute.
3. Make all SwiftUI views render the Core `AttributedString` directly. Delete the
   bridge if it becomes an identity function; otherwise rename it to describe SwiftUI-only work.
4. Update catalog captions and historical comments that claim UIKit scope handling lives in SwiftUI.
5. Run adapter tests, `ModalTextTests`, affected rendering tests, and the generic example build.
   Confirm `rg '\.uiKit|import UIKit|UIFont|UIColor' SwiftUI/` reports no attributed-text coupling.
6. Commit: `Move legacy attributed text conversion to migration`.

## Task 5 — Remove UIKit from the SwiftUI renderer graph

**Files:**

- Update `SwiftUI/EmbeddedModalRenderer.swift`, `SwiftUI/SwiftUIAlertModal.swift`,
  `SwiftUI/ModalHost.swift`, `SwiftUI/ModalContent.swift`, and renderer bespoke/input extensions.
- Move `Executor/WindowModalRenderer.swift` to the future UIKit ownership area or split its pure
  SwiftUI presentation assembly from its window/controller integration.
- Update renderer, host, mapping, and cancellation tests.

**Steps:**

1. Add failing architecture assertions for forbidden SwiftUI symbols: `GBAlertModal`,
   `UIKitModalRenderer`, `UIView`, `UIImage`, `UIColor`, `UIFont`, `UIDatePicker`, `UIWindow`,
   `UIApplication`, and `UIHostingController`.
2. Change SwiftUI presentation and view signatures to Core `ResolvedModal`, `ModalProperties`, and
   `ModalContent`. Remove `Presentation.resolved` if no runtime consumer needs it.
3. Keep embedded renderer and `ModalHost` in SwiftUI. Put all window/application/hosting-controller
   behavior under UIKit ownership even when the hosted content is SwiftUI.
4. Audit mutable renderer state and protocol conformances. Keep UI mutations `@MainActor`; do not
   broaden Core protocol isolation or add unchecked sendability to make conformances compile.
5. Re-run coordinator cancellation, executor state, renderer update, and exactly-once resolution
   tests. Use awaited signals/streams, not timing delays, for any new cancellation coverage.
6. Run the full library suite and generic example build. Require both forbidden-import and
   forbidden-symbol scans under `SwiftUI/` to be empty except allowlisted comments/tests, then remove
   stale allowlist entries.
7. Commit: `Decouple SwiftUI renderer from UIKit backend`.

## Task 6 — Move neutral sources without changing targets

**Files:**

- Create `Library/GBV3AlertModal/Sources/GBV3AlertModalCore/` and move the existing `Core/` files,
  `ResolvedModal.swift`, and other proven-neutral values there.
- Replace `Components/UIMinMaxEdgeInsets.swift` with Core `MinMaxEdgeInsets.swift` and a deprecated
  UIKit-side compatibility typealias.
- Update imports/references, package documentation, and purity-test source paths.

**Steps:**

1. Add failing equality/initialization tests for `MinMaxEdgeInsets` and compile coverage for the
   deprecated `UIMinMaxEdgeInsets` alias.
2. Introduce the neutral name and migrate Core/SwiftUI code to it. Keep the old name only in UIKit,
   Migration, and compatibility-facing tests/examples.
3. Move files with no semantic edits. Temporarily set the existing target's `path` to
   `Library/GBV3AlertModal/Sources` and give it explicit `sources` entries for the legacy
   `GBV3AlertModal` root and new `GBV3AlertModalCore` root; update the resource path accordingly.
   SwiftPM cannot compile sources outside a target path, so do not point the target at one child
   directory while trying to include its sibling. Do not declare the final target graph yet.
4. Run the full library tests and generic example build. Review `git diff --summary` to confirm moves
   are detected as moves and no behavior changed.
5. Commit: `Move platform-neutral modal sources`.

## Task 7 — Expose the cross-module API before moving backends

**Files:**

- Update declarations in `Library/GBV3AlertModal/Sources/GBV3AlertModalCore/` that are consumed by
  the future SwiftUI, UIKit, or Migration targets.
- Update declarations in the existing `SwiftUI/`, UIKit-owned, and `Migration/` directories that
  will be consumed by another future target.
- Add `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/CrossModuleAPITests.swift`, a checked-in
  symbol-ownership inventory, and `Script/validate-cross-module-api.sh`.

**Steps:**

1. Build a symbol-level inventory from every reference that will cross a target boundary after the
   split: Core -> SwiftUI/UIKit/Migration, SwiftUI/UIKit -> Migration, and backend modules -> the
   compatibility shim. Include initializers, methods, properties, nested types, protocol
   requirements, conformances, and generic constraints—not only top-level type declarations.
2. Classify each referenced declaration as `public` when it belongs to a product's supported
   consumer surface, or `package` when it is implementation-only cooperation between targets in
   this package. Do not expose backend implementation details merely to make the split compile.
   Record the owner, consumers, chosen access, and rationale in the inventory.
3. Apply the access-control changes while sources still build in the single compatibility target.
   In particular, expose `ModalDiagnostics.logUnregisteredDescriptor` to sibling backend targets
   with the narrowest viable access, and audit all renderer dependencies rather than treating that
   known call as the complete list. Check memberwise initializers explicitly because promoting a
   struct does not promote its synthesized initializer.
4. Add compile witnesses for representative supported `public` APIs without `@testable import`.
   Add an architecture test that compares the checked-in inventory with cross-owner symbol scans
   and fails when a newly referenced boundary declaration has no classification.
5. Make `validate-cross-module-api.sh` assemble a disposable package under `/tmp` by copying the
   current sources into their proposed Task 8 ownership roots and applying the proposed target
   graph. Build Core, SwiftUI, UIKit, and Migration separately there. The script must exercise the
   actual compiler access checks, clean up its temporary package, and make no source move or
   manifest change in the developer checkout. Fix every access-control failure in this task and
   rerun until all four targets build.
6. Run the full library suite, generic example build, the boundary-validation script twice, and
   `git diff --check`. Inspect every access-level widening and confirm this commit contains no source
   moves or production manifest target split.
7. Commit: `Prepare cross-module modal APIs`.

## Task 8 — Declare products, targets, compatibility shim, and resources

**Files:**

- Update `Package.swift`.
- Create source roots `GBV3AlertModalSwiftUI`, `GBV3AlertModalUIKit`,
  `GBV3AlertModalMigration`, and compatibility `GBV3AlertModal`.
- Move backend files without semantic edits.
- Split `Assets.xcassets` into backend-owned catalogs and add target-local bundle access helpers.
- Temporarily update the existing `GBV3AlertModalTests` target dependencies and test imports to
  access declarations through their owning backend modules.

**Steps:**

1. Move SwiftUI, UIKit, and Migration files into non-overlapping roots. Keep
   `WindowModalRenderer` with UIKit integration. Restrict production Swift changes to mechanical
   moves; any newly required access-control edit means Task 7's audit is incomplete and must be
   corrected in a separate preceding commit before continuing this task.
2. Declare four backend products and targets. Core has no UI dependency; SwiftUI depends only on
   Core; UIKit depends on Core + SnapKit; Migration depends on Core + SwiftUI + UIKit.
3. Before replacing the implementation module with the compatibility shim, make the existing
   aggregate `GBV3AlertModalTests` target depend directly on Core, SwiftUI, UIKit, and Migration.
   Replace each `@testable import GBV3AlertModal` with `@testable` imports of only the module or
   modules that own the internals exercised by that test file. Keep this temporary aggregate target
   until Task 9 assigns the files to separate test targets; do not rely on the compatibility shim to
   re-export another module's internal declarations.
4. Add a tiny `GBV3AlertModal` compatibility target/product that transitionally uses
   `@_exported import` to preserve the old single-import surface. This underscored attribute is an
   explicit accepted risk limited to the disposable compatibility target; backend modules must not
   use it. Add a compile fixture that imports only `GBV3AlertModal` and exercises representative
   Core, SwiftUI, UIKit, and Migration APIs before migrating the example.
5. Give SwiftUI and UIKit separate resource catalogs and `Bundle.module` resolution. Duplicate the
   close asset if both need it rather than sharing a backend bundle.
6. Run `swift package describe --type json` and inspect the dependency graph. Then build each scheme
   for a generic iOS Simulator, including Core and SwiftUI independently. Confirm only UIKit has a
   SnapKit edge, and compare the result with Task 7's disposable boundary-validation build.
7. Run the full existing library suite through the temporary backend-aware aggregate test target,
   run the compatibility-only compile fixture, and build the example through the compatibility
   product.
8. Commit: `Split alert modal package targets`.

## Task 9 — Split tests and the example by ownership

**Files:**

- Update `Package.swift` with Core, SwiftUI, UIKit, and Migration test targets.
- Move tests from the temporary aggregate `Tests/GBV3AlertModalTests/` target into non-overlapping
  target directories.
- Update the example Xcode project, imports, schemes, and `Script/test-lib.sh`; add a distinct
  SwiftUI-only example target/scheme rather than treating the mixed app as boundary proof.
- Add architecture tests for module imports, symbols, dependencies, field coverage, and resources.

**Steps:**

1. Assign resolver/executor/coordinator tests to Core; native configuration/rendering tests to
   SwiftUI; legacy layout/renderer tests to UIKit; adapters and cross-backend parity to Migration.
2. Ensure Core tests do not import UI frameworks and nonisolated resolver tests run outside the main
   actor. Keep SwiftUI renderer tests `@MainActor` where required by actual isolation.
3. Keep the existing mixed gallery app on the compatibility product for coexistence. Add a distinct
   SwiftUI-only application target and shared scheme containing the SwiftUI catalog sources but no
   UIKit gallery sources; link only Core + SwiftUI products and import only those modules. Move
   genuinely shared, framework-neutral example fixtures into a separate shared source group rather
   than duplicating them.
4. Add gates for all ten architecture requirements in the design, including resource resolution and
   the 70 unique SwiftUI catalog entries. Source scanning supplements rather than replaces builds.
5. Update test scripts to name each scheme explicitly and fail if an expected suite executes zero
   tests. Preserve the example script's one retry for the documented simulator infrastructure flake.
6. Run all four package test schemes plus example unit/UI tests. Confirm cross-backend snapshots live
   only in Migration/comparison tests.
7. Commit: `Split backend tests and examples`.

## Task 10 — Add the authoritative SwiftUI-only deletion proof

**Files:**

- Add `Script/test-swiftui-independence.sh`.
- Add a checked-in SwiftUI-only manifest fixture or deterministic manifest-generation input under
  `Tests/Architecture/` that omits UIKit, Migration, compatibility, and SnapKit.
- Update architecture documentation and CI entry points.

**Steps:**

1. Make the script create a disposable directory/worktree under `/tmp`; never delete or rewrite the
   developer's current checkout.
2. Apply the manifest variant that removes the SnapKit package declaration and exposes only Core +
   SwiftUI. Build the separate SwiftUI-only example scheme against that variant. Ensure dependency
   resolution omits SnapKit and compile logs contain no UIKit/Migration/compatibility target.
3. Build and test Core, SwiftUI, and the SwiftUI-only example under Swift 6 strict concurrency.
4. Add assertions that fail if forbidden source directories, products, resources, or dependencies
   participate. Verify the script fails when a deliberate temporary SwiftUI-to-UIKit dependency is
   introduced, then revert that probe before committing.
5. Run the script twice to prove cleanup/idempotence, followed by the normal full-backend suites.
6. Commit: `Prove SwiftUI builds without UIKit backend`.

## Task 11 — Final verification and documentation handoff

**Files:**

- Update package README/DocC and supersede historical claims that UIKit imports are permanent.
- Add a consumer migration/retirement checklist without changing production APIs.
- Update CI documentation with the independence command.

**Steps:**

1. Run `git diff --check` and all backend package tests.
2. Run the example tests, including the exactly-70 unique catalog contract.
3. Run `Script/test-swiftui-independence.sh` and archive its dependency/build summary.
4. Inspect `swift package describe --type json` and build logs: Core has no UIKit/SwiftUI edge;
   SwiftUI has no UIKit/Migration/SnapKit edge; only Migration knows both backends.
5. Review any changed SwiftUI snapshots for native behavior, accessibility, and Dynamic Type. Record
   why each changed; restore unexplained changes.
6. Perform a final symbol scan over Core and SwiftUI and verify the retirement invariant: removing
   UIKit, Migration, compatibility, SnapKit, and transitional comparison tests requires no Core or
   SwiftUI production edit.
7. Commit: `Document target independence verification`.

## Completion criteria

- Tasks 1–11 are individually committed and green.
- Core + SwiftUI build/test in the deletion-proof configuration without resolving or linking UIKit,
  Migration, compatibility, or SnapKit.
- The compatibility product keeps existing consumers compiling during coexistence.
- SwiftUI owns its configuration, fonts, colors, attributed content, controls, resources, renderer,
  tests, and 70-entry catalog.
- No Core or SwiftUI production file needs modification in the future UIKit/Migration deletion
  commit.

## Adversarial plan review

**Review result:** GO after corrections in this revision.

Findings resolved:

1. **No-go — invalid intermediate SwiftPM source layout.** A target cannot include a sibling outside
   its `path`. Task 6 now moves the temporary target path to the common `Sources` parent and lists
   both child roots explicitly.
2. **No-go — cross-module access control was deferred until the move-only split.** Task 7 now
   inventories and classifies every future cross-target reference, applies narrowly scoped
   `public`/`package` access before moving files, explicitly covers `ModalDiagnostics`, and reserves
   compiler proof for the immediately following per-target builds.
3. **No-go — product composition did not prove old import compatibility.** Task 8 now specifies a
   transitional `@_exported import` shim, records the underscored-attribute risk, and requires a
   compile fixture that imports only the legacy module.
4. **No-go — the mixed example could link UIKit while appearing SwiftUI-pure.** Tasks 9–10 now require
   a separate SwiftUI-only application target/scheme and build it with UIKit, Migration,
   compatibility, and SnapKit absent.
5. **No-go — attributed-text ownership could force UIKit to import SwiftUI or Core to import a UI
   framework.** Task 4 now keeps Foundation `AttributedString` in Core, a Foundation/UIKit-only
   adapter in UIKit, and true cross-backend scope conversion in Migration.
6. **Medium — a detached task was unnecessary proof of resolver isolation.** Task 1 now uses a
   synchronous nonisolated compile witness, avoiding unstructured concurrency in the test.

Accepted risk:

- The compatibility shim uses underscored `@_exported import`. It is confined to a disposable
  coexistence target, covered by a source-compatibility compile fixture, and removed with the legacy
  compatibility product. Replacing it with wrappers/typealiases for the entire public API would add
  a larger and more drift-prone transitional surface.
