# SwiftUI/UIKit Target Independence Design

**Date:** 2026-08-18  
**Status:** Approved for implementation planning

## Objective

Split the current monolithic `GBV3AlertModal` Swift package into independently usable Core,
SwiftUI, UIKit, and Migration modules. SwiftUI and UIKit remain supported during consumer
migration, but neither backend may depend on the other. After consumers migrate, removing UIKit
and Migration must require only manifest and file deletion; Core and SwiftUI production sources
must remain unchanged.

This work does not retire UIKit. It establishes the boundary that makes retirement safe.

## Non-goals

- Exact geometry or TextKit parity where native SwiftUI behavior differs.
- A `Font`-to-`UIFont` inference API.
- Sharing backend-specific resources, views, colors, fonts, or layout implementation through Core.
- Migrating downstream applications or deleting legacy targets in this repository.
- Reimplementing the already-landed SwiftUI catalog preset and native date-picker work.

## Module graph

```text
GBV3AlertModalCore
├── descriptors, results, actions, styles, and image references
├── ModalToken, ModalExecutor, MainTabModalCoordinator
├── ModalRenderer
├── ModalStructureInputs and ModalContentInputs
├── ResolvedModal and the single pure resolver
└── MinMaxEdgeInsets and other platform-neutral values

GBV3AlertModalSwiftUI ──> GBV3AlertModalCore
├── ModalProperties, ModalFont, ModalTokens
├── SwiftUIModalRenderer, EmbeddedModalRenderer, ModalHost
├── SwiftUIAlertModal, scaffold, styles, and native input views
└── SwiftUI assets and localizations

GBV3AlertModalUIKit ────> GBV3AlertModalCore
├── GBAlertModal.Properties and GBAlertModal implementation
├── UIKitModalRenderer and window/controller integration
├── UIKit layout and holder implementations
├── UIKit assets and localizations
└── SnapKit

GBV3AlertModalMigration ──> Core + SwiftUI + UIKit
├── legacy Properties -> ModalProperties
├── UIFont/UIColor/UIEdgeInsets and attributed-text adaptation
└── temporary field-coverage and parity support

GBV3AlertModal compatibility shim ──> Core + SwiftUI + UIKit + Migration
```

Core and SwiftUI must have no dependency path to UIKit, Migration, or SnapKit. Migration is the
only production module allowed to import both backends.

## Public products and compatibility

Add explicit products named `GBV3AlertModalCore`, `GBV3AlertModalSwiftUI`,
`GBV3AlertModalUIKit`, and `GBV3AlertModalMigration`. New code chooses only the products it needs.

Preserve the existing `GBV3AlertModal` product during coexistence through a small compatibility
target with the same module name. The target depends on and re-exports the split modules so existing
`import GBV3AlertModal` consumers do not face an immediate flag day. The compatibility target is
transitional and must not be used by the SwiftUI-only example or deletion-proof build.

Because SwiftPM product composition does not itself preserve an importable module, the manifest
must declare this compatibility target explicitly; a multi-target library product alone is not
sufficient.

## Neutral resolution model

Move `GBAlertModal.ResolvedModal` and the resolver into Core as `ResolvedModal` and a single pure,
nonisolated resolution function over `ModalStructureInputs` and `ModalContentInputs`. The value and
its nested enums are `Sendable` and `Equatable` and contain no UIKit or SwiftUI types.

Both renderers consume this result. UIKit maps `ResolvedModal.ButtonAxis` at its view edge to
`NSLayoutConstraint.Axis`; SwiftUI maps it to `SwiftUI.Axis` or branches directly. Resolver tests
move with Core and retain current decisions. Backend renderers may adapt presentation, but they may
not fork the decision engine.

`UIMinMaxEdgeInsets` becomes neutral `MinMaxEdgeInsets` in Core. UIKit exposes a deprecated
`UIMinMaxEdgeInsets` typealias during coexistence so existing callers compile while neutral and
SwiftUI code use the honest name.

## SwiftUI-owned configuration

`ModalProperties` remains a SwiftUI-native configuration whose familiar field names make consumer
migration mechanical. Its fields use `Color`, `EdgeInsets`, `ModalFont`, resource references, and
platform-neutral scalar values. It never accepts a UIKit configuration.

`ModalFont` becomes a descriptive, value-semantic `Sendable` and `Equatable` type. It records
family, size, weight, and an explicit scaling policy. The default is fixed-size to preserve existing
custom-font and snapshot behavior; callers may opt into a semantic relative text style for Dynamic
Type. SwiftUI alone maps the descriptor to `Font`. Migration may map `UIFont` into the descriptor,
but there is no reverse public guess.

`ModalTokens` has one derivation path: `ModalTokens(from: ModalProperties)`. Any initializer or
helper that consumes `GBAlertModal.Properties`, UIKit action styles, `UIColor`, `UIFont`, or shared
TextKit measurement moves to Migration or UIKit. Native SwiftUI layout replaces pre-measurement;
CoreText may be used only if a deterministic requirement remains after native layout is evaluated.
Any intentional geometry change receives an absolute SwiftUI-native test rather than restored UIKit
coupling.

SwiftUI descriptors and views consume SwiftUI-scoped `AttributedString`. Legacy
`NSAttributedString` and UIKit attribute-scope conversion moves to Migration, preserving the rule
that explicit SwiftUI attributes win when scopes overlap.

## Renderer and integration ownership

`SwiftUIModalRenderer`, `EmbeddedModalRenderer`, `SwiftUIAlertModal`, and `ModalHost` accept Core
`ResolvedModal` plus SwiftUI-native content and properties. They do not name `GBAlertModal` or
`UIKitModalRenderer`. Transitional `Presentation.resolved` state is removed when it has no runtime
consumer.

Anything that uses `UIWindow`, `UIApplication`, `UIView`, `UIImage`, or `UIHostingController`
belongs to UIKit or Migration even if it displays a SwiftUI view. Hosting SwiftUI does not make
window/controller integration SwiftUI-pure.

Mutable renderer and UI state stays `@MainActor`. Core resolver inputs and outputs remain
`Sendable`, and the resolver must compile and run from a nonisolated context. Existing token,
coordinator, cancellation, drain, and exactly-once continuation behavior remains unchanged across
file and target moves.

## Source and resource layout

First remove logical coupling while the package remains one target. Then move files into
non-overlapping source roots:

```text
Library/GBV3AlertModal/Sources/GBV3AlertModalCore/
Library/GBV3AlertModal/Sources/GBV3AlertModalSwiftUI/
Library/GBV3AlertModal/Sources/GBV3AlertModalUIKit/
Library/GBV3AlertModal/Sources/GBV3AlertModalMigration/
Library/GBV3AlertModal/Sources/GBV3AlertModal/        # compatibility shim only
```

SwiftUI and UIKit each own their asset catalog and localizations and resolve them through their
target's `Bundle.module`. Small common images may be duplicated; one backend may not reach into the
other's bundle. Core carries only semantic resource identifiers.

File moves and manifest edits are distinct verified commits where practical. This separates path
mistakes from API and behavioral changes.

## Migration behavior

Migration adapters convert legacy values into `ModalProperties`, after which the single SwiftUI
token derivation runs. Adapters cover each mapped UIKit property explicitly. A field-coverage test
requires every selected legacy property to have a corresponding SwiftUI field or a documented
omission. Conversion tests cover fonts, colors, insets, action themes, and attributed strings.

Migration is disposable. No Core, SwiftUI, or UIKit public API depends on it, and no SwiftUI source
imports it.

## Test ownership and architecture gates

Split tests along production boundaries:

- Core tests cover resolution, executor/coordinator state, tokens, cancellation, and Sendable/
  nonisolated behavior without importing either UI framework.
- SwiftUI tests cover native configuration, token derivation, rendering, inputs, resources, and
  absolute geometry/accessibility expectations.
- UIKit tests cover legacy view/layout/renderer behavior and SnapKit integration.
- Migration tests cover every cross-backend conversion and transitional parity contract.
- The example's SwiftUI catalog imports Core + SwiftUI only and retains exactly 70 unique entries.

Add source-scanning gates for forbidden imports and symbols, but treat a real separate-target build
as authoritative. The SwiftUI dependency graph must exclude UIKit, Migration, and SnapKit; Core
must exclude UIKit and SwiftUI. Resource tests must prove lookup through the owning module bundle.

Cross-backend snapshots may remain transitional migration tests. When native SwiftUI behavior
changes intentionally—especially font measurement and date-picker layout—replace parity assertions
with reviewed SwiftUI-native pins and document regenerated snapshots.

## Delivery sequence

1. Extract neutral `ResolvedModal` and the resolver into Core vocabulary.
2. Make `ModalFont` UIKit-free and define explicit scaling behavior.
3. Move UIKit conversions out of `ModalTokens` and establish one token derivation.
4. Move legacy attributed-text conversion to Migration ownership.
5. Remove `GBAlertModal` and UIKit integration from the SwiftUI renderer/view graph.
6. Introduce `MinMaxEdgeInsets`, move all neutral files, and keep the one-target build green.
7. Inventory every future cross-module API, widen access with the narrowest viable visibility, and
   prove the proposed boundaries with a disposable split-target build before moving backends.
8. Declare split targets/products and assign resources and SnapKit ownership.
9. Split examples and tests and add architecture gates.
10. Add and run a SwiftUI-only build plus a temporary deletion simulation.
11. Hand off consumer migration and eventual UIKit/Migration retirement as later work.

Each numbered stage is an atomic verified commit. Behavioral refactors do not share a commit with
bulk source moves or manifest target declaration.

## Verification and release gate

At every stage, run `git diff --check`, focused tests, and an affected iOS Simulator build under
Swift 6 strict concurrency. Before handoff, run the library and example test schemes, the 70-entry
catalog contract, architecture scans, target dependency inspection, and the SwiftUI-only proof.

The deletion proof uses a disposable manifest variant or worktree that excludes UIKit and Migration
targets, files, resources, tests, compatibility shim, and SnapKit. Core, SwiftUI, and the SwiftUI
example must build and test without production source edits. The proof must demonstrate that
excluded dependencies are neither compiled nor linked, not merely that SwiftUI sources avoid
spelling their names.

The design is complete only when deleting UIKit and Migration would leave all Core and SwiftUI
production files byte-for-byte unchanged.
