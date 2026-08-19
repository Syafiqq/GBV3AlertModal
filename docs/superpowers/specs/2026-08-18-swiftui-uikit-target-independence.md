# Brief — SwiftUI and UIKit target independence

**Status:** READY FOR EXECUTION in a fresh session.
**Written:** 2026-08-18.
**Branch at handoff:** `dev/swift-ui-support-3`.
**Direction:** UIKit and SwiftUI coexist as independent backends; after consumer migration, UIKit
must be removable without editing Core or SwiftUI production code.

## 0. Read this first

The owner has made a stronger decision than the earlier backend-independence work:

> SwiftUI owns its configuration, renderer, views, controls, fonts, colours, and resources. UIKit
> owns its legacy equivalents. They may deliberately use the same property names and concepts to
> keep migration mechanical, but neither backend may depend on the other.

This supersedes earlier conclusions that UIKit imports inside `SwiftUI/` were permanent for TextKit
measurement or attributed-text parity. Those choices were correct for the old priority — exact
UIKit parity — but independence is now the priority. Native SwiftUI behavior may intentionally
differ when exact UIKit behavior requires UIKit implementation details.

Do not delete UIKit in this work. The finish line is that deleting it later becomes a package
manifest and file-removal operation, with no edits to SwiftUI components.

## 1. Work already completed

Two safe stages landed before this brief:

1. `eb7e680 Decouple SwiftUI catalog presets from UIKit`
   - `SwiftUICatalogPresets.standard` is the canonical SwiftUI example configuration.
   - All 70 SwiftUI examples derive from SwiftUI-owned values.
   - `UIKitFreeCatalogPresets.swift` no longer reads `GalleryPresets` or `StressCatalog`.
2. `ef520f3 Use native SwiftUI date picker`
   - Removed the explicit `UIDatePicker`/`UIViewRepresentable` implementation.
   - `DatePickerModalView` now uses native SwiftUI `DatePicker` range overloads.

The example app built successfully for a generic iOS Simulator under Swift 6 strict concurrency
after each commit. The worktree was clean when this brief was written.

Do not redo these changes. Date-picker snapshots may legitimately change because SwiftUI now owns
the layout.

## 2. Required final target graph

```text
GBV3AlertModalCore
├── descriptors and results
├── ModalStyle / ModalImage references
├── ModalAction
├── ModalToken
├── ModalExecutor protocol/default executor
├── MainTabModalCoordinator
├── ModalRenderer protocol
└── platform-neutral resolved-presentation vocabulary

GBV3AlertModalSwiftUI ──depends──> GBV3AlertModalCore
├── ModalProperties
├── ModalFont
├── ModalTokens
├── SwiftUIModalRenderer
├── ModalHost
├── SwiftUIAlertModal / scaffold / button styles
├── native input and bespoke views
└── SwiftUI-owned assets and localizations

GBV3AlertModalUIKit ─────depends──> GBV3AlertModalCore
├── GBAlertModal and Properties
├── UIKitModalRenderer
├── UIKit holders/window integration
├── UIKit-owned assets
└── SnapKit

GBV3AlertModalMigration ─depends──> Core + SwiftUI + UIKit
├── GBAlertModal.Properties -> ModalProperties
├── UIFont/UIColor/edge-inset adaptation
├── UIKit-attributed text -> SwiftUI-attributed text
└── temporary consumer migration conveniences
```

The migration target is optional and disposable. It is the only production target allowed to know
both backends.

### Dependency rules

- Core imports neither UIKit nor SwiftUI.
- SwiftUI imports SwiftUI, Foundation/CoreGraphics/CoreText as needed, but never UIKit.
- SwiftUI never references `GBAlertModal`, `UIKitModalRenderer`, UIKit holders, or the migration
  target.
- UIKit may import Core, UIKit, and SnapKit, but must not be required by SwiftUI.
- Migration may import both backend products because its only purpose is temporary adaptation.
- Tests that compare both backends live outside their production targets and disappear with UIKit.

## 3. Compatibility rule: copy the vocabulary, not the dependency

Keep familiar property names and approximately the same property coverage so consumer migration is
mostly type substitution:

```swift
// UIKit
GBAlertModal.Properties(
    titleColor: UIColor,
    titleFont: UIFont,
    margin: UIEdgeInsets
)

// SwiftUI
ModalProperties(
    titleColor: Color,
    titleFont: ModalFont,
    margin: EdgeInsets
)
```

Expected mappings:

| UIKit | SwiftUI |
| --- | --- |
| `UIColor` | `Color` |
| `UIFont` | descriptive `ModalFont` |
| `UIEdgeInsets` | `EdgeInsets` |
| `NSLayoutConstraint.Axis` | platform-neutral axis / `SwiftUI.Axis` at the view edge |
| `UIImage` | `ModalImage` resource reference / SwiftUI `Image` |
| `UIView` custom content | registered SwiftUI `View` |

`CGFloat`, `Bool`, `String`, `Date`, spacing, and sizing concepts may keep the same spelling.

Do not copy UIKit-only implementation vocabulary into SwiftUI: Auto Layout priorities, `UIView`
factories, `CALayer` state, window lookup, TextKit-specific behavior, or fields proven inert.

While both backends live, a compatibility test may compare corresponding property coverage and
preset values. That test is a migration gate, not a runtime dependency.

## 4. Current coupling that remains

At brief creation, direct UIKit imports remaining under `Sources/.../SwiftUI/` are exactly:

- `ModalFont.swift` — stores `UIFont` and derives `Font`.
- `ModalTokens.swift` — contains `GBAlertModal.Properties`/UIKit theme conversion and uses
  `ModalLayout`/`UIFont` measurement.
- `AttributedTextBridge.swift` — inspects UIKit attribute scopes.

There are additional same-module dependencies that do not require an import and therefore must not
be missed by an import-only audit:

- `EmbeddedModalRenderer.Presentation.resolved` is `GBAlertModal.ResolvedModal`.
- `EmbeddedModalRenderer` calls `GBAlertModal.resolve`.
- `SwiftUIAlertModal` calls `GBAlertModal.resolve` and accepts `GBAlertModal.ResolvedModal`.
- `ModalTokens` calls shared `ModalLayout` functions implemented with UIKit/TextKit.
- `UIMinMaxEdgeInsets` is Foundation-only despite its misleading name, but it currently lives among
  UIKit components and must move or gain a neutral replacement before target splitting.
- The package is one target, so SwiftUI consumers still link UIKit and SnapKit even when they never
  name them.

Use symbol searches in addition to `import UIKit` searches.

## 5. Forced implementation order

Each numbered step must leave the relevant build green and be committed atomically. Do not combine
the target move with behavioral refactors; otherwise failures cannot be attributed.

### Step 1 — Introduce platform-neutral resolved vocabulary in Core

Move the resolver result out of `GBAlertModal`:

```swift
public struct ResolvedModal: Sendable, Equatable {
    public enum ButtonAxis: Sendable, Equatable {
        case vertical
        case horizontal
    }

    public enum SubtitleKind: Sendable, Equatable { ... }
    public enum WidthResolution: Sendable, Equatable { ... }
    // Existing resolved decisions, with no UIKit types.
}
```

Move the pure resolver function into Core over `ModalStructureInputs` and `ModalContentInputs`.
UIKit and SwiftUI must both consume this one neutral resolver; do not create two decision engines.

At the UIKit rendering edge, map `ResolvedModal.ButtonAxis` to `NSLayoutConstraint.Axis`. At the
SwiftUI edge, map it to `SwiftUI.Axis` or branch directly.

Acceptance:

- Core resolver compiles in a `nonisolated` context.
- Existing resolver behavior tests pass.
- No Core declaration names a UIKit or SwiftUI type.

### Step 2 — Make `ModalFont` descriptive and UIKit-free

Replace stored `UIFont` with value semantics, for example:

```swift
public struct ModalFont: Sendable, Equatable {
    public enum Family: Sendable, Equatable {
        case system
        case custom(String)
    }

    public enum Weight: Sendable, Equatable, CaseIterable { ... }

    public var family: Family
    public var size: CGFloat
    public var weight: Weight
    public var font: Font { ... }
}
```

SwiftUI measurement must no longer require `UIFont` or `ModalLayout`'s TextKit functions. Prefer
native SwiftUI layout. If deterministic pre-measurement remains necessary, isolate it behind a
SwiftUI/CoreText implementation and explicitly update absolute geometry pins. Do not silently guess
a `UIFont` from `Font`.

Put `UIFont -> ModalFont` conversion in Migration or UIKit, never in SwiftUI.

Acceptance:

- `ModalFont.swift` has no UIKit import or UIKit symbol.
- SwiftUI presets still express system and named custom fonts.
- Dynamic Type behavior is considered explicitly; do not accidentally promise scaling for a fixed
  custom-font API.

### Step 3 — Move every UIKit conversion out of `ModalTokens`

`ModalTokens` should derive only from `ModalProperties` inside the SwiftUI target.

Move all of these into Migration/UIKit adapter files:

- `init(from: GBAlertModal.Properties)`
- UIKit action-theme conversion
- `Color(uiColor:)`/`Color(cgColor:)` conversion used only by legacy input
- `Font(UIFont)` helpers

The adapter should first create `ModalProperties`, then let SwiftUI's single
`ModalTokens(from: ModalProperties)` derivation run. Do not maintain two token derivation functions.

Acceptance:

- `ModalTokens.swift` names no `GBAlertModal`, `UIFont`, `UIColor`, or UIKit action style.
- There is exactly one SwiftUI token derivation source of truth.
- The migration adapter has direct field-coverage tests.

### Step 4 — Remove UIKit attributed-text scope handling from SwiftUI

SwiftUI descriptors and views consume SwiftUI-scoped `AttributedString` directly.

Move conversion from legacy `NSAttributedString`/UIKit attribute scopes into Migration. Preserve
the rule that explicit SwiftUI attributes win when both scopes are present.

Acceptance:

- `AttributedTextBridge.swift` is either deleted or SwiftUI-only.
- No SwiftUI file accesses `.uiKit` attributed-string scope.
- Migration tests cover colour and font conversion for legacy callers.

### Step 5 — Remove `GBAlertModal` from the SwiftUI renderer/view graph

Update `SwiftUIModalRenderer.Presentation`, `SwiftUIAlertModal`, and helper signatures to use the
Core `ResolvedModal` and SwiftUI-native `ModalProperties`/`ModalContent` exclusively.

Delete unused transitional bookkeeping such as `Presentation.resolved` if the host never consumes
it. Do not keep a dependency merely because a parity test used to inspect it; move the test to the
neutral resolver or migration suite.

Classify window-level behavior carefully:

- `ModalHost` and embedded renderer are SwiftUI.
- Anything using `UIWindow`, `UIApplication`, or `UIHostingController` is UIKit integration and
  belongs in UIKit or Migration, not the independent SwiftUI target.

Acceptance:

- No SwiftUI production file references `GBAlertModal` or `UIKitModalRenderer`.
- The executor can drive either renderer through the Core protocol.
- Swift 6 isolation remains explicit: mutable renderer/UI state is `@MainActor`; neutral resolver
  values are `Sendable`.

### Step 6 — Move neutral files before declaring targets

Move shared types into a real Core source directory. Likely candidates include existing `Core/`
files plus `UIMinMaxEdgeInsets` (prefer renaming additively to `MinMaxEdgeInsets`, with a deprecated
UIKit-side typealias if source compatibility matters).

Do not place `Color`, `Font`, `Image`, `UIView`, `UIImage`, or backend resources in Core.

Build the existing one-target package after moves before editing the manifest. Commit file moves
separately from target declaration when practical.

### Step 7 — Split Package.swift targets and resources

Create products/targets for Core, SwiftUI, UIKit, and Migration using non-overlapping source paths.

Only UIKit depends on SnapKit. SwiftUI must link successfully without SnapKit in its dependency
graph.

Resource ownership:

```text
Sources/GBV3AlertModalSwiftUI/Resources/Assets.xcassets
Sources/GBV3AlertModalUIKit/Resources/Assets.xcassets
```

Duplicate small assets temporarily if both backends need them; independent ownership is preferable
to one backend reaching into the other's bundle. Share only semantic names/localization keys in
Core. Resolve SwiftUI assets using the SwiftUI target's module bundle.

Preserve a compatibility product named `GBV3AlertModal` if existing consumers require it, but make
its composition explicit. It must not be the product used by the SwiftUI-only example/deletion
build.

Acceptance:

- Core target builds alone.
- SwiftUI target builds with Core and without UIKit/SnapKit.
- UIKit target builds with Core.
- Migration target builds only when both backends are present.

### Step 8 — Split examples and tests by dependency

The SwiftUI catalog target must import only Core + SwiftUI and retain exactly 70 unique entries.
UIKit gallery/tests may continue importing UIKit + Core.

Move cross-backend parity tests to a migration/comparison test target. Mark them transitional.
SwiftUI correctness tests must be absolute/native tests, not comparisons that require UIKit.

Add compile-time purity tests that enumerate source imports/references and fail on both growth and
stale exceptions.

### Step 9 — Prove deletion before consumer migration starts

Add a CI/local command that builds and tests only:

- GBV3AlertModalCore
- GBV3AlertModalSwiftUI
- SwiftUI-only example

The command must not compile, link, or resolve:

- GBV3AlertModalUIKit
- GBV3AlertModalMigration
- SnapKit
- UIKit resources/tests

Also perform a temporary deletion simulation in a disposable worktree or manifest variant: exclude
UIKit and Migration targets and confirm Core + SwiftUI still build without source edits. Do not
commit destructive deletions during coexistence.

### Step 10 — Consumer migration, then actual retirement

Consumer sequence:

1. Add Core + SwiftUI products and install `ModalHost`/SwiftUI renderer.
2. Temporarily use Migration adapters for existing UIKit presets where useful.
3. Move each preset to native `ModalProperties` with familiar field names.
4. Move each presentation call to the Core executor + SwiftUI renderer.
5. Remove Migration imports from the consumer.
6. Confirm the consumer imports no UIKit modal product.

Only then retire this project's legacy backend:

1. Delete UIKit target/files/resources/tests.
2. Delete Migration target/files/tests.
3. Remove SnapKit if nothing else uses it.
4. Remove transitional parity tests and compatibility products.

No Core or SwiftUI production file may change in that retirement commit. If one must change, target
independence was not completed.

## 6. Verification

This is an iOS-only package. Plain `swift test` attempts a macOS build and fails at `import UIKit`;
do not treat that as a product failure while UIKit still exists.

Fast build used successfully during the first two stages:

```sh
xcodebuild build \
  -project Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj \
  -scheme GBV3AlertModalExample \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/gb-v3-independence-derived \
  CODE_SIGNING_ALLOWED=NO
```

Before every implementation commit:

- run `git diff --check`;
- build the affected target/example with Swift 6 strict concurrency;
- run focused tests for the changed resolver/config/view;
- confirm `git status --short` contains no unrelated user changes;
- commit only the verified atomic stage.

Before final handoff:

- run the library test scheme on an available iOS Simulator;
- run the example tests, including the catalog pairing contract (`70` SwiftUI entries, unique names);
- run the SwiftUI-only deletion-proof build;
- list target dependencies and confirm SwiftUI has no UIKit/SnapKit edge;
- regenerate only snapshots whose native SwiftUI behavior intentionally changed, documenting why.

## 7. Required architecture tests

At minimum, add gates for:

1. Core forbidden imports: UIKit and SwiftUI.
2. SwiftUI forbidden imports: UIKit.
3. SwiftUI forbidden symbols: `GBAlertModal`, `UIKitModalRenderer`, `UIView`, `UIImage`, `UIColor`,
   `UIFont`, `UIDatePicker`, `UIWindow`, `UIApplication`, `UIHostingController`.
4. SwiftUI target dependency graph excludes UIKit target, Migration target, and SnapKit.
5. Every UIKit property selected for migration has either a corresponding SwiftUI field or an
   explicitly documented omission.
6. Migration conversions cover every mapped field.
7. Core resolver is callable off the main actor with `Sendable` inputs/results.
8. SwiftUI renderer mutations remain `@MainActor` and async cancellation tests remain bounded.
9. SwiftUI resource resolution uses its own module bundle.
10. SwiftUI catalog remains exactly 70 unique entries.

Do not make source-scanning tests the only proof. The separate SwiftUI target build without UIKit is
the authoritative boundary test.

## 8. Known tradeoffs and traps

- Native SwiftUI date-picker geometry will differ from the former `UIDatePicker` wrapper. This is
  intentional under the new direction.
- Removing TextKit measurement may move line wrapping and geometry beyond the old 0.5pt UIKit parity
  tolerance. Rebaseline SwiftUI-native pins only after visual/accessibility review; do not force the
  old behavior back through UIKit.
- A file can reference UIKit-backed same-module types without writing `import UIKit`. Search symbols,
  not only imports.
- `Color`, `Font`, and `Image` are not generally `Equatable` in the way scalar configuration is.
  Keep semantic descriptors separately equatable where tests need stable comparison.
- Do not expose a public `Font -> UIFont` guess. Migration direction is legacy UIKit value into an
  explicit SwiftUI descriptor, not the reverse.
- `WindowModalRenderer` is not SwiftUI-pure merely because it hosts SwiftUI; window/controller APIs
  belong to UIKit integration.
- Resources must use the owning target's `Bundle.module`; main-bundle lookup makes a split appear
  green in the example and fail in a consuming app.
- Preserve the resolve-on-every-exit invariant in `ModalToken`/coordinator. Target moves must not
  weaken cancellation, drain, or exactly-once continuation behavior.
- Existing documentation contains historical claims that UIKit imports are permanent. Update or
  supersede those claims when the corresponding implementation changes; do not let stale comments
  become design authority.

## 9. Definition of done

All statements below must be true simultaneously:

- UIKit and SwiftUI renderers work independently in this project.
- Both depend only on platform-neutral Core, not on each other.
- SwiftUI owns its configuration, renderer, controls, fonts, colours, resources, and tests.
- UIKit owns its legacy configuration, renderer, resources, and SnapKit dependency.
- Similar property names reduce consumer migration without sharing backend types.
- Migration adapters are isolated in a disposable target.
- Core + SwiftUI build and test with UIKit/Migration/SnapKit excluded.
- The SwiftUI example imports no UIKit modal product and still exposes 70 unique examples.
- Deleting UIKit + Migration later requires no modification to any Core or SwiftUI production file.

That last statement is the release gate. “Mostly independent” is not sufficient.
