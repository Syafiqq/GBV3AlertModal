# SwiftUI Tier 1 (W0–W3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native `SwiftUIModalRenderer` into the library and prove it semantically equivalent to `UIKitModalRenderer` by making the existing renderer-agnostic test suite pass against both.

**Architecture:** Both renderers consume the *same* `AlertDialog → DataHolder → ResolvedModal` chain; divergence is only possible in the final render step. `ResolvedAlert` is deleted and `ModalTokens` becomes a projection of `Properties`, so structural and token drift are eliminated by construction rather than detected by tests.

**Tech Stack:** Swift 6 language mode, SwiftUI, UIKit, SnapKit, XCTest, swift-snapshot-testing 1.19.3, ViewInspector 0.10.3 (example target only).

**Spec:** `docs/superpowers/specs/2026-07-29-swiftui-tier1-design.md` (commit `4e65835`)

**Scope:** W0–W3 only. **Task 8 is a stop-or-continue gate.** W4 (style token + 20-shape coverage), W5 (SHSans), W6 (animation) get a separate plan written *after* the gate passes.

## Global Constraints

- **Swift 6 language mode** (`swift-tools-version: 6.0`). Strict concurrency violations are compile **errors**, not warnings.
- **iOS 15 floor.** No API newer than iOS 15 without an `@available` guard. Note `onGeometryChange` is iOS 16+ — use `GeometryReader` + `PreferenceKey`.
- **`../../geniebook-student-ios-distribution` is READ-ONLY.** It is a source of truth to read from. Never modify it, never create files in it, never run its build.
- **Library test command:** `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17'`
- **Example test command:** `xcodebuild test -project Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17'` — the `-project` flag is REQUIRED; a repo-root workspace named `gb-v3-alert-modal` shadows the scheme.
- **Never trust `** TEST SUCCEEDED **`.** Always confirm a non-zero executed count: `grep -E "Executed [0-9]+ tests" <log>`. Do **not** pass `-quiet` when verifying counts — it suppresses per-case lines.
- **The example test target uses EXPLICIT membership.** New test files there do NOT auto-join and must be wired into `project.pbxproj`. The library test target does not have this problem. Prefer putting new tests in the **library** target.
- **Baseline to preserve:** `Executed 239 tests, with 0 failures`. Every task must leave this at ≥239 passing.
- **xcodebuild can exceed 120s.** Pass `timeout: 600000` to the Bash tool, or run in background and read the output file.

---

## File Structure

**New source region** — `Library/GBV3AlertModal/Sources/GBV3AlertModal/Core/` (framework-neutral):
moved from `Executor/`: `ModalDescriptor.swift`, `ModalExecutor.swift`, `ModalToken.swift`,
`RootScreenModalCoordinator.swift`, `ModalRenderer.swift`, and `Descriptors/` (`AlertDialog`,
`PopupDialog`, `TextInputDialog`, `DatePickerDialog`, `StandardAlertContent`, `ModalText`).

**New source region** — `.../Sources/GBV3AlertModal/SwiftUI/`:
`SwiftUIModalRenderer.swift`, `ModalHost.swift`, `SwiftUIAlertModal.swift`,
`AlertModalScaffold.swift`, `ModalTokens.swift`, `ModalButtonStyles.swift`.

**Unchanged:** `GBAlertModal*.swift`, `Components/`, `Extensions/`, `Support/`,
`UIKitModalRenderer*.swift` stay where they are (the UIKit region, implicitly).

> **Why `ResolvedModal` is NOT in `Core/`:** it is typed with `NSLayoutConstraint.Axis` and lives in
> `Components/GBAlertModal+ResolvedModal.swift`. It stays in the UIKit region; the SwiftUI renderer
> imports UIKit to use it, which is free on iOS. Do not attempt to make it framework-neutral —
> that was explicitly rejected as T7.

**New tests** (all in the **library** target, `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/`):
`Architecture/CorePurityTests.swift`, `SwiftUI/ModalTokensProvenanceTests.swift`,
`SwiftUI/SwiftUIModalRendererTests.swift`, `SwiftUI/RendererParityTests.swift`,
`SwiftUI/GeometryDifferentialTests.swift`, `Support/RendererFixtures.swift`.

---

## Task 1: Point the Tier-0 demo at the real preset (W0)

`Tier0DemoStyle` invented styling (`.systemOrange`, `.systemIndigo`, fixed-300 width) that
`GalleryPresets` already mirrors faithfully from the distribution app. C-0 depends on the demo's
input being the real preset.

**Files:**
- Modify: `Examples/GBV3AlertModalExample/GBV3AlertModalExample/Gallery/GalleryViewController.swift:89-103`
- Delete: `Examples/GBV3AlertModalExample/GBV3AlertModalExample/Gallery/Tier0DemoStyle.swift`

**Interfaces:**
- Consumes: `GalleryPresets.properties`, `GalleryPresets.popupProperties` (both `GBAlertModal.Properties`, already defined)
- Produces: nothing new

- [ ] **Step 1: Confirm nothing else references `Tier0DemoStyle`**

Run: `grep -rn "Tier0DemoStyle" Examples/ Library/`
Expected: only `GalleryViewController.swift:90-92` and the definition file itself.

- [ ] **Step 2: Rewrite `openTier0Demo` to use `GalleryPresets`**

In `GalleryViewController.swift`, replace lines 89–103 with:

```swift
    /// Tier 0: build the library executor over a UIKit renderer and inject it into a SwiftUI VM.
    /// The renderer paints the real UIKit modal on the key window, over the pushed SwiftUI screen.
    /// Styling comes from `GalleryPresets` — the faithful mirror of the distribution app's
    /// `Presentation.UiKit.V3AlertModal` preset — so the demo exercises production-shaped config.
    @objc private func openTier0Demo() {
        let properties = GalleryPresets.properties
        let renderer = UIKitModalRenderer(
            alertProperties: properties,
            popupProperties: GalleryPresets.popupProperties
        )
        // Custom-content input descriptors — registered by the consumer with the library's holders.
        renderer.register(TextInputDialog.self) { descriptor, resolve in
            (properties, UIKitModalRenderer.TextInputHolder.make(for: descriptor, resolve: resolve))
        }
        renderer.register(DatePickerDialog.self) { descriptor, resolve in
            (properties, UIKitModalRenderer.DatePickerHolder.make(for: descriptor, resolve: resolve))
        }
        let executor = DefaultModalExecutor(renderer: renderer)
        let host = UIHostingController(rootView: Tier0DemoScreen(executor: executor))
        navigationController?.pushViewController(host, animated: true)
    }
```

- [ ] **Step 3: Delete the invented style file**

```bash
git rm Examples/GBV3AlertModalExample/GBV3AlertModalExample/Gallery/Tier0DemoStyle.swift
```

- [ ] **Step 4: Build and run the example suite**

Run: `xcodebuild test -project Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17' > /tmp/ex.log 2>&1; grep -E "Executed [0-9]+ tests" /tmp/ex.log | tail -2`
Expected: non-zero executed count, 0 failures.

> The app target uses `PBXFileSystemSynchronizedRootGroup`, so deleting a source file needs no
> pbxproj edit. If the build fails with "cannot find Tier0DemoStyle", a stale reference exists —
> remove it from `project.pbxproj`.

- [ ] **Step 5: Commit**

```bash
git add -A Examples/
git commit -m "fix(example): Tier 0 demo renders from GalleryPresets, not invented styling

Tier0DemoStyle approximated the app's preset with .systemOrange/.systemIndigo
and a fixed 300pt width. GalleryPresets already mirrors the real
Presentation.UiKit.V3AlertModal preset with citations. Use it and delete the
approximation, so the Tier-0 executor path is exercised with production-shaped
config."
```

---

## Task 2: Create the `Core/` region and enforce its purity (W1a)

**Files:**
- Move (git mv): 11 files from `Executor/` → `Core/` (list in Step 2)
- Modify: `Core/ModalRenderer.swift` (import UIKit → Foundation)
- Modify: `Core/Descriptors/ModalText.swift` (remove SwiftUI scope checks + import)
- Create: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Architecture/CorePurityTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `Core/` source region; no API change. All moved types keep their existing public names.

- [ ] **Step 1: Write the failing purity test**

Create `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Architecture/CorePurityTests.swift`:

```swift
import XCTest

/// The `Core/` region is the framework-neutral executor contract: descriptors, executor, token,
/// coordinator, renderer protocol. It must not depend on a UI framework — that is what makes a
/// future module split a manifest edit rather than a refactor. This test IS the enforcement;
/// there is no module boundary doing it for us (spec T5).
final class CorePurityTests: XCTestCase {

    /// `.../Library/GBV3AlertModal` — four levels up from this file.
    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Architecture/
            .deletingLastPathComponent()  // GBV3AlertModalTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // GBV3AlertModal/
    }

    private var coreSwiftFiles: [URL] {
        let core = packageRoot.appendingPathComponent("Sources/GBV3AlertModal/Core")
        guard let e = FileManager.default.enumerator(at: core, includingPropertiesForKeys: nil)
        else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    func testCoreRegionExistsAndIsNotEmpty() {
        XCTAssertFalse(coreSwiftFiles.isEmpty, "Core/ region is missing or empty")
    }

    func testCoreRegionImportsNoUIFramework() throws {
        var offenders: [String] = []
        for file in coreSwiftFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "import UIKit" || trimmed == "import SwiftUI" {
                    offenders.append("\(file.lastPathComponent): \(trimmed)")
                }
            }
        }
        XCTAssertEqual(
            offenders, [],
            "Core/ must stay framework-neutral. Offending imports:\n" + offenders.joined(separator: "\n")
        )
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/CorePurityTests > /tmp/t2.log 2>&1; grep -E "Executed [0-9]+ tests|error:" /tmp/t2.log | tail -3`
Expected: FAIL — `testCoreRegionExistsAndIsNotEmpty` fails because `Core/` does not exist yet.

- [ ] **Step 3: Move the framework-neutral files**

```bash
cd Library/GBV3AlertModal/Sources/GBV3AlertModal
mkdir -p Core/Descriptors
git mv Executor/ModalDescriptor.swift            Core/
git mv Executor/ModalExecutor.swift              Core/
git mv Executor/ModalToken.swift                 Core/
git mv Executor/RootScreenModalCoordinator.swift Core/
git mv Executor/ModalRenderer.swift              Core/
git mv Executor/Descriptors/AlertDialog.swift          Core/Descriptors/
git mv Executor/Descriptors/PopupDialog.swift          Core/Descriptors/
git mv Executor/Descriptors/TextInputDialog.swift      Core/Descriptors/
git mv Executor/Descriptors/DatePickerDialog.swift     Core/Descriptors/
git mv Executor/Descriptors/StandardAlertContent.swift Core/Descriptors/
```

**`ModalText.swift` deliberately does NOT move.** It needs `import UIKit` for
`NSAttributedString` bridging, so it belongs to the UIKit region, not the neutral contract.
Leave it at `Executor/Descriptors/ModalText.swift` — hence no `rmdir Executor/Descriptors`.

`Executor/` retains the UIKit renderer plus that one bridging utility:
`UIKitModalRenderer.swift`, `UIKitModalRenderer+Holder.swift`,
`UIKitModalRenderer+InputHolders.swift`, `Descriptors/ModalText.swift`.

SPM recurses into subdirectories under the target `path`, so no `Package.swift` change is needed.

- [ ] **Step 4: Make `ModalRenderer.swift` framework-neutral**

It declares `import UIKit` but uses no UIKit type — only `ModalID` and `ModalDescriptor`.
In `Core/ModalRenderer.swift`, change line 1:

```swift
import Foundation
```

- [ ] **Step 5: Fix `ModalText` — the parked SwiftUI-scope bug**

`ModalText.split` currently treats a run carrying a **SwiftUI**-scoped `.foregroundColor`/`.font`
as "styled", returning `NSAttributedString(text)`. But `NSAttributedString(AttributedString)`
**drops SwiftUI-scoped attributes** — they have no UIKit key to bridge to. The resolver renders
attributed subtitles as-is, so such text arrives with *no* styling, which is strictly worse than
being treated as plain (where the resolver applies default font and colour).

This could not occur while SwiftUI callers did not exist. Tier 1 creates them, so fix it now.

In `Executor/Descriptors/ModalText.swift` (it stays in the UIKit region — see Step 3), delete
line 2 (`import SwiftUI`) and the two SwiftUI-scope checks, and update the comment:

```swift
import Foundation
import UIKit

/// Bridges a descriptor `AttributedString` into the legacy `DataHolder`'s plain/attributed
/// split. Styling is contractually limited to bold/color/link (Foundation-bridgeable keys);
/// see the plan's Global Constraints.
public enum ModalText {
    /// `nil` → nothing. Unstyled → plain `String` (resolver applies default styling).
    /// Styled → `NSAttributedString` (resolver renders as-is).
    public static func split(_ text: AttributedString?) -> (plain: String?, attributed: NSAttributedString?) {
        guard let text else { return (nil, nil) }
        // "Plain" means carrying none of the whitelisted CONCRETE styling attributes
        // (foreground color, font, link). Presentation-intent attributes (e.g. from
        // `AttributedString(markdown:)` parsing unmarked text) are out of the whitelisted
        // subgrammar and don't bridge reliably to UIKit, so intent-only runs stay plain.
        //
        // SwiftUI-scoped color/font keys are deliberately NOT checked: they do not bridge to
        // NSAttributedString at all, so treating them as "styled" would yield an attributed
        // string stripped of styling, which the resolver renders as-is — worse than plain,
        // which at least receives the resolver's default styling. The SwiftUI renderer never
        // calls `split`; it consumes the descriptor's `AttributedString` directly.
        let isPlain = text.runs.allSatisfy { run in
            run[AttributeScopes.UIKitAttributes.ForegroundColorAttribute.self] == nil
                && run[AttributeScopes.UIKitAttributes.FontAttribute.self] == nil
                && run[AttributeScopes.FoundationAttributes.LinkAttribute.self] == nil
        }
        if isPlain { return (String(text.characters), nil) }
        return (nil, NSAttributedString(text))
    }
}
```

> `import UIKit` stays for `NSAttributedString` bridging. That is exactly why this file is not in
> `Core/` — it is a UIKit-bridging utility, not part of the neutral contract.

- [ ] **Step 6: Add a regression test for the SwiftUI-scope fix**

Append to `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/ModalTextTests.swift`:

```swift
    /// A SwiftUI-scoped colour cannot bridge to NSAttributedString, so it must NOT flip the
    /// string onto the attributed path — that would strip styling entirely and the resolver
    /// would render it unstyled. Treating it as plain gets the resolver's default styling.
    func testSwiftUIScopedColorStaysPlain() {
        var text = AttributedString("Hello")
        text.swiftUI.foregroundColor = .red
        let (plain, attributed) = ModalText.split(text)
        XCTAssertEqual(plain, "Hello")
        XCTAssertNil(attributed)
    }
```

> This test needs `import SwiftUI` in `ModalTextTests.swift`. Test targets are not covered by the
> purity test — only `Sources/GBV3AlertModal/Core/` is.

- [ ] **Step 7: Run the full library suite**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' > /tmp/t2b.log 2>&1; grep -E "Executed [0-9]+ tests, with [0-9]+ failures" /tmp/t2b.log | tail -1`
Expected: `Executed 242 tests, with 0 failures` (239 baseline + 2 purity + 1 ModalText regression).

- [ ] **Step 8: Commit**

```bash
git add -A Library/
git commit -m "refactor(core): extract framework-neutral Core/ region + purity test

Moves the executor contract (descriptors, executor, token, coordinator, renderer
protocol) into Sources/GBV3AlertModal/Core/ and adds CorePurityTests asserting
that region imports neither UIKit nor SwiftUI. Per spec T5 we keep ONE target;
this test is the enforcement mechanism, and it reduces a future module split to
a manifest edit.

ModalRenderer.swift imported UIKit without using a UIKit type -> Foundation.

Also fixes the parked ModalText bug now that SwiftUI callers exist: a
SwiftUI-scoped foregroundColor/font flipped split() onto the attributed path,
but those keys do not bridge to NSAttributedString, so the text arrived
unstyled. Treating them as plain yields the resolver's default styling instead."
```

---

## Task 3: Promote the SwiftUI surface into the library (W1b)

**Files:**
- Create (moved from example): `Sources/GBV3AlertModal/SwiftUI/SwiftUIAlertModal.swift`, `AlertModalScaffold.swift`, `ModalTokens.swift`, `ModalButtonStyles.swift`
- Delete: the four corresponding files under `Examples/.../SwiftUI/`
- Modify: `Examples/.../SwiftUI/SwiftUIDemoScreen.swift`, `SatisfactionDemoView.swift` (drop local definitions, rely on the library)

**Interfaces:**
- Consumes: `ResolvedModal` (Task 4 wires it), `GBAlertModal.Properties`
- Produces: `public struct SwiftUIAlertModal: View`, `public struct AlertModalScaffold<Content: View>: View`, `public struct ModalTokens`, `public struct ObliquePrimaryStyle: ButtonStyle`, `public struct PlainSecondaryStyle: ButtonStyle`

- [ ] **Step 1: Move the four files**

```bash
cd /Users/engineering/Documents/c/ios/repos/geniebook/modules/gb-v3-alert-modal
mkdir -p Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI
for f in SwiftUIAlertModal AlertModalScaffold ModalTokens ModalButtonStyles; do
  git mv Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/$f.swift \
         Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/$f.swift
done
```

- [ ] **Step 2: Make the moved types public**

Each moved file was internal (example-app code). In all four files, add `public` to every
type declaration, its stored properties, and its initializers. Add `public var body` where
the type conforms to `View` or `ButtonStyle`.

> Swift 6 gotcha already hit on this code: a `ButtonStyle`'s nested body type must NOT be named
> `Body` (it collides with the `ButtonStyle.Body` associatedtype), the parameter type is
> `ButtonStyleConfiguration` (not `Configuration`) when written out, and the nested body view
> must be non-private.

- [ ] **Step 3: Remove the now-duplicated `import GBV3AlertModal` usages in the example**

In `Examples/.../SwiftUI/SwiftUIDemoScreen.swift` and `SatisfactionDemoView.swift`, the types
now come from the library. They already `import GBV3AlertModal`, so no edit is expected —
verify by building.

- [ ] **Step 4: Build both targets**

Run: `xcodebuild build -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: `BUILD SUCCEEDED`

Run: `xcodebuild build -project Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Run both suites**

Run the library and example commands from Global Constraints.
Expected: library ≥242 passing; example suite passing with non-zero executed count.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(swiftui): promote SwiftUI surface into the library

Moves SwiftUIAlertModal, AlertModalScaffold, ModalTokens and ModalButtonStyles
from the example app into Sources/GBV3AlertModal/SwiftUI/ and makes them public.
No behaviour change; the example now consumes them from the library."
```

---

## Task 4: Delete `ResolvedAlert`; SwiftUI consumes `ResolvedModal` (W1b, C-1)

`ResolvedAlert` is a 5-bool subset of the library's 11-field `ResolvedModal`, which is public,
`Equatable`, backed by 53 tests, and whose docstring already names this exact use. Sharing it
makes structural equivalence true by construction instead of something to test.

**Files:**
- Modify: `Sources/GBV3AlertModal/SwiftUI/SwiftUIAlertModal.swift`
- Modify: `Examples/.../SwiftUI/AlertResolution.swift` (delete `ResolvedAlert` struct only; keep `resolve`, `shouldApply`, `noBlinkSwap`)
- Modify: `Examples/.../GBV3AlertModalExampleTests/AlertResolutionTests.swift`

**Interfaces:**
- Consumes: `GBAlertModal.ResolvedModal.resolve(properties:holder:isLandscape:) -> ResolvedModal`, `UIKitModalRenderer.AlertHolder.make(for:resolve:) -> GBAlertModal.DataHolder`
- Produces: `SwiftUIAlertModal.init(resolved: GBAlertModal.ResolvedModal, holder: GBAlertModal.DataHolder, tokens: ModalTokens, onAction: @escaping (GBAlertModal.ActionType) -> Void)`

- [ ] **Step 1: Write the failing equivalence test**

Create `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/SharedResolverTests.swift`:

```swift
import XCTest
@testable import GBV3AlertModal

/// C-1: the SwiftUI path consumes the SAME resolver as UIKit, so structural equivalence is a
/// property of the code, not of a comparison harness. These tests pin the shared chain.
@MainActor
final class SharedResolverTests: XCTestCase {

    private func resolved(for dialog: AlertDialog) -> GBAlertModal.ResolvedModal {
        let holder = UIKitModalRenderer.AlertHolder.make(for: dialog, resolve: { _ in })
        return GBAlertModal.resolve(
            properties: GBAlertModal.Properties(),
            holder: holder,
            isLandscape: false
        )
    }

    func testTwoButtonDialogResolvesBothActions() {
        let dialog = AlertDialog(title: "T", subtitle: "S", primary: "OK", secondary: "Cancel")
        let r = resolved(for: dialog)
        XCTAssertTrue(r.showsTitle)
        XCTAssertTrue(r.showsPrimary)
        XCTAssertTrue(r.showsSecondary)
        XCTAssertEqual(r.subtitle, .plain("S"))
    }

    func testOneButtonDialogHasNoSecondary() {
        let dialog = AlertDialog(title: "T", subtitle: "S", primary: "OK")
        XCTAssertFalse(resolved(for: dialog).showsSecondary)
    }

    func testCloseButtonFlagRoundTrips() {
        let dialog = AlertDialog(title: "T", subtitle: "S", primary: "OK", showCloseButton: true)
        XCTAssertTrue(resolved(for: dialog).showsCloseButton)
    }
}
```

> Verify the exact `AlertDialog` initializer parameter labels and the `GBAlertModal.resolve`
> call form against `Core/Descriptors/AlertDialog.swift` and
> `Components/GBAlertModal+ResolvedModal.swift` before running — `resolve` is declared as a
> `static func` on the `GBAlertModal` extension. Adjust the call site if it is nested differently.

- [ ] **Step 2: Run to verify it fails or passes**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/SharedResolverTests > /tmp/t4.log 2>&1; grep -E "Executed|error:" /tmp/t4.log | tail -3`
Expected: compiles and passes — this pins existing behaviour before the refactor. If it fails to
compile, fix the call form; if an assertion fails, STOP and report — the shared chain does not
behave as the spec assumes.

- [ ] **Step 3: Rewrite `SwiftUIAlertModal` to take `ResolvedModal`**

Replace its `ResolvedAlert`-derived slot logic with `ResolvedModal` fields:

| Was (`ResolvedAlert`) | Now (`ResolvedModal`) |
|---|---|
| `showsBanner` | `showsBanner` |
| `showsTitle` | `showsTitle` |
| `showsSubtitle` | `subtitle != .none` |
| `showsSecondary` | `showsSecondary` |
| `showsClose` | `showsCloseButton` |
| *(absent)* | `buttonAxis`, `buttonsMatchParent`, `contentWidth`, `closeOnTapOverlay` |

Subtitle rendering switches on the richer kind:

```swift
    @ViewBuilder
    private var subtitleView: some View {
        switch resolved.subtitle {
        case .none:
            EmptyView()
        case let .plain(text):
            Text(text)
                .font(tokens.subtitleFont)
                .foregroundColor(tokens.subtitleColor)
                .multilineTextAlignment(.center)
        case .attributed:
            // The UIKit path stores an NSAttributedString on the holder. SwiftUI renders the
            // bridged value; styling is limited to the whitelisted bold/color/link subgrammar.
            Text(AttributedString(holder.subtitleAttributed ?? NSAttributedString()))
                .multilineTextAlignment(.center)
        case .custom:
            // Bespoke content is served by AlertModalScaffold's ViewBuilder slot, not here.
            EmptyView()
        }
    }
```

Button axis now comes from the resolver rather than being hardcoded vertical:

```swift
    @ViewBuilder
    private var actions: some View {
        if resolved.buttonAxis == .horizontal {
            HStack(spacing: tokens.interButtonSpacing) { buttonPair }
        } else {
            VStack(spacing: tokens.interButtonSpacing) { buttonPair }
        }
    }
```

- [ ] **Step 4: Delete `ResolvedAlert`**

In `Examples/.../SwiftUI/AlertResolution.swift`, delete the `ResolvedAlert` struct (lines 9–26 in
the current file). Keep `AlertInteraction`, `resolve`, `shouldApply`, `noBlinkSwap` — they are
interaction routing, not structure, and are still used.

- [ ] **Step 5: Update example tests that referenced `ResolvedAlert`**

Run: `grep -rn "ResolvedAlert" Examples/`
Delete or rewrite each hit in `AlertResolutionTests.swift` against `ResolvedModal` via the
`SharedResolverTests` pattern from Step 1. Do not simply delete assertions — port them.

- [ ] **Step 6: Run both suites**

Expected: library ≥245 passing; example suite passing.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor(swiftui): share ResolvedModal; delete ResolvedAlert (spec C-1)

ResolvedAlert was a 5-bool subset of the library's 11-field ResolvedModal,
duplicated only because the prototype was quarantined in the example app.
SwiftUIAlertModal now consumes ResolvedModal directly, so structural
equivalence between the two renderers is true by construction rather than
something a comparison harness has to detect.

Picks up buttonAxis, buttonsMatchParent, contentWidth, closeOnTapOverlay and
the four-case SubtitleKind, none of which the SwiftUI path modelled before."
```

---

## Task 5: `ModalTokens` derived from `Properties` (W1c, C-0)

`ModalTokens` was hand-transcribed from the app's preset while the prototype could not reach
`Properties`. That transcription is what produced the wrong width, spacing and oblique values
that only a physical device caught. Deriving it removes the drift class at its root.

**Files:**
- Modify: `Sources/GBV3AlertModal/SwiftUI/ModalTokens.swift`
- Create: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/ModalTokensProvenanceTests.swift`

**Interfaces:**
- Consumes: `GBAlertModal.Properties`
- Produces: `public init(from properties: GBAlertModal.Properties)` on `ModalTokens`

- [ ] **Step 1: Write the failing provenance test**

```swift
import XCTest
import SwiftUI
@testable import GBV3AlertModal

/// C-0: tokens are DERIVED from Properties, never transcribed. A transcription is what produced
/// the wrong width/spacing/oblique values that only a device caught.
@MainActor
final class ModalTokensProvenanceTests: XCTestCase {

    func testCornerRadiusComesFromProperties() {
        var content = GBAlertModal.Properties.ContentProperty()
        content.cornerRadius = 21
        let properties = GBAlertModal.Properties(contentProperty: content)
        XCTAssertEqual(ModalTokens(from: properties).cardCornerRadius, 21)
    }

    func testInterButtonSpacingComesFromProperties() {
        let space = GBAlertModal.Properties.ComponentSpace(
            banner: 1, title: 2, subtitle: 3, interButton: 9
        )
        let properties = GBAlertModal.Properties(space: space)
        XCTAssertEqual(ModalTokens(from: properties).interButtonSpacing, 9)
    }

    func testTitleColorComesFromProperties() {
        let properties = GBAlertModal.Properties(titleColor: .magenta)
        XCTAssertEqual(ModalTokens(from: properties).titleColor, Color(UIColor.magenta))
    }
}
```

> Check `GBAlertModal.Properties`' and `ContentProperty`'s real initializer signatures in
> `Components/GBAlertModal+Properties.swift` before running; adapt construction to whatever
> defaults exist. If `ContentProperty` has no memberwise mutation, build it via its full init.

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/ModalTokensProvenanceTests > /tmp/t5.log 2>&1; grep -E "error:|Executed" /tmp/t5.log | tail -3`
Expected: compile error — no `init(from:)`.

- [ ] **Step 3: Add the deriving initializer**

In `ModalTokens.swift`:

```swift
    /// Derive tokens from the UIKit `Properties` that the UIKit renderer uses, so both renderers
    /// read ONE source of styling. Hand-transcribing these values is what previously shipped a
    /// wrong card width, wrong spacing and a wrong button style (spec C-0).
    /// `UIColor -> Color` and `UIFont -> Font` are lossless.
    public init(from properties: GBAlertModal.Properties) {
        self.cardCornerRadius = properties.contentProperty.cornerRadius
        self.interButtonSpacing = properties.space.interButton
        self.bannerSpacing = properties.space.banner
        self.titleSpacing = properties.space.title
        self.subtitleSpacing = properties.space.subtitle
        self.titleColor = Color(properties.titleColor)
        self.subtitleColor = Color(properties.subtitleColor)
        self.titleFont = Font(properties.titleFont)
        self.subtitleFont = Font(properties.subtitleFont)
        self.scrimColor = Color(properties.overlayColor)
        self.cardBackground = Color(properties.contentProperty.backgroundColor)
    }
```

> Map every stored property of the existing `ModalTokens`. If a token has no `Properties`
> counterpart (e.g. a SwiftUI-only layout constant), keep its literal default and add a comment
> naming why it has no source — do not silently invent a mapping.

- [ ] **Step 4: Run to verify it passes**

Expected: 3 tests PASS.

- [ ] **Step 5: Run the full library suite**

Expected: ≥248 passing, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add -A Library/
git commit -m "feat(swiftui): derive ModalTokens from Properties (spec C-0)

ModalTokens was hand-transcribed from the app preset because the quarantined
prototype could not reach Properties. That transcription shipped a wrong card
width, wrong spacing and a wrong button style, caught only by running on a
device. In the library both renderers can read one source, so tokens are now
derived and provenance is a constructor rather than a test to remember."
```

---

## Task 6: `SwiftUIModalRenderer` — present and dismiss (W2a)

**Files:**
- Create: `Sources/GBV3AlertModal/SwiftUI/SwiftUIModalRenderer.swift`
- Create: `Sources/GBV3AlertModal/SwiftUI/ModalHost.swift`
- Create: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/SwiftUIModalRendererTests.swift`

**Interfaces:**
- Consumes: `ModalRenderer`, `ModalID`, `ModalDescriptor`, `AlertHolder.make`, `GBAlertModal.resolve`, `ModalTokens.init(from:)`
- Produces:
  - `public final class SwiftUIModalRenderer: ObservableObject, ModalRenderer`
  - `public init(alertProperties: GBAlertModal.Properties, popupProperties: GBAlertModal.Properties? = nil)`
  - `public func register<D: ModalDescriptor>(_ type: D.Type, factory: @escaping Factory<D>)`
  - `public private(set) var presentations: [SwiftUIModalRenderer.Presentation]`
  - `public struct ModalHost<Content: View>: View` with `init(renderer:content:)`

> **Design constraint, verified:** `DataHolder.completion` is
> `((GBAlertModal, GBAlertModal.ActionType) -> Void)?` — it requires a non-optional `GBAlertModal`
> instance, which the SwiftUI renderer does not have and must not construct. So the renderer uses
> `AlertHolder.make` for **content mapping only** and routes view interactions through its own
> resolve gate. `holder.completion` is deliberately unused on this path.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import SwiftUI
@testable import GBV3AlertModal

@MainActor
final class SwiftUIModalRendererTests: XCTestCase {

    private func makeRenderer() -> SwiftUIModalRenderer {
        SwiftUIModalRenderer(alertProperties: GBAlertModal.Properties())
    }

    func testPresentAddsAPresentation() {
        let renderer = makeRenderer()
        let id = ModalID()
        renderer.present(
            AlertDialog(title: "T", subtitle: "S", primary: "OK"), id: id, resolve: { _ in }
        )
        XCTAssertEqual(renderer.presentations.count, 1)
        XCTAssertEqual(renderer.presentations.first?.id, id)
    }

    func testPresentResolvesStructureViaSharedResolver() {
        let renderer = makeRenderer()
        renderer.present(
            AlertDialog(title: "T", subtitle: "S", primary: "OK", secondary: "No"),
            id: ModalID(), resolve: { _ in }
        )
        let resolved = try? XCTUnwrap(renderer.presentations.first?.resolved)
        XCTAssertEqual(resolved?.showsSecondary, true)
    }

    func testDismissResolvesWithDismissedResultAndRemovesPresentation() {
        let renderer = makeRenderer()
        let id = ModalID()
        var result: AlertDialog.Result?
        renderer.present(
            AlertDialog(title: "T", subtitle: "S", primary: "OK"), id: id, resolve: { result = $0 }
        )
        renderer.dismiss(id)
        XCTAssertEqual(result, .dismissed)
        XCTAssertTrue(renderer.presentations.isEmpty)
    }

    func testInteractionResolvesOnceOnly() {
        let renderer = makeRenderer()
        let id = ModalID()
        var count = 0
        renderer.present(
            AlertDialog(title: "T", subtitle: "S", primary: "OK"), id: id, resolve: { _ in count += 1 }
        )
        renderer.presentations.first?.onAction(.primary)
        renderer.dismiss(id)
        XCTAssertEqual(count, 1, "the resolve gate must fire exactly once")
    }

    func testUnregisteredDescriptorResolvesDismissed() {
        struct Unknown: ModalDescriptor {
            typealias Result = AlertDialog.Result
            static var dismissedResult: Result { .dismissed }
        }
        let renderer = makeRenderer()
        var result: AlertDialog.Result?
        renderer.present(Unknown(), id: ModalID(), resolve: { result = $0 })
        XCTAssertEqual(result, .dismissed)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/SwiftUIModalRendererTests > /tmp/t6.log 2>&1; grep -E "error:" /tmp/t6.log | head -3`
Expected: compile error — `SwiftUIModalRenderer` does not exist.

- [ ] **Step 3: Implement the renderer**

Create `Sources/GBV3AlertModal/SwiftUI/SwiftUIModalRenderer.swift`:

```swift
import SwiftUI
import UIKit // ResolvedModal/Properties/DataHolder are UIKit-region types; free on iOS.

/// Renders modals as SwiftUI. Mirrors `UIKitModalRenderer`'s contract exactly — same descriptor,
/// same `AlertHolder` content mapping, same `ResolvedModal` structure — differing only in the
/// final render step. That is what makes the renderer-agnostic suite runnable against both.
@MainActor
public final class SwiftUIModalRenderer: ObservableObject, ModalRenderer {

    public typealias Factory<D: ModalDescriptor> =
        (D, @escaping (D.Result) -> Void) -> (GBAlertModal.Properties?, GBAlertModal.DataHolder)

    /// One live presentation. `onAction` is the view's only way to resolve; `holder.completion`
    /// is unusable here because it demands a `GBAlertModal` instance we never build.
    public struct Presentation: Identifiable {
        public let id: ModalID
        public let resolved: GBAlertModal.ResolvedModal
        public let holder: GBAlertModal.DataHolder
        public let tokens: ModalTokens
        public var isHidden: Bool
        public let onAction: (GBAlertModal.ActionType) -> Void
    }

    @Published public private(set) var presentations: [Presentation] = []

    private var factories: [ObjectIdentifier: Any] = [:]
    private var resolveDismissed: [ModalID: () -> Void] = [:]

    public init(
        alertProperties: GBAlertModal.Properties,
        popupProperties: GBAlertModal.Properties? = nil
    ) {
        register(AlertDialog.self) { descriptor, resolve in
            (alertProperties, UIKitModalRenderer.AlertHolder.make(for: descriptor, resolve: resolve))
        }
        if let popupProperties {
            register(PopupDialog.self) { descriptor, resolve in
                (popupProperties, UIKitModalRenderer.AlertHolder.make(for: descriptor, resolve: resolve))
            }
        }
    }

    public func register<D: ModalDescriptor>(_ type: D.Type, factory: @escaping Factory<D>) {
        factories[ObjectIdentifier(type)] = factory
    }

    public func present<D: ModalDescriptor>(
        _ descriptor: D, id: ModalID, resolve: @escaping (D.Result) -> Void
    ) {
        guard let factory = factories[ObjectIdentifier(D.self)] as? Factory<D> else {
            assertionFailure("No factory registered for \(D.self)")
            resolve(D.dismissedResult)
            return
        }

        var didResolve = false
        let gate: (D.Result) -> Void = { [weak self] result in
            guard !didResolve else { return }
            didResolve = true
            self?.teardown(id)
            resolve(result)
        }

        let (properties, holder) = factory(descriptor, gate)
        let effective = properties ?? GBAlertModal.Properties()
        let resolvedModal = GBAlertModal.resolve(
            properties: effective, holder: holder, isLandscape: false
        )

        presentations.append(
            Presentation(
                id: id,
                resolved: resolvedModal,
                holder: holder,
                tokens: ModalTokens(from: effective),
                isHidden: false,
                onAction: { [weak self] action in
                    guard let self, self.presentations.contains(where: { $0.id == id })
                    else { return }
                    self.route(action, for: id)
                }
            )
        )
        resolveDismissed[id] = { gate(D.dismissedResult) }
        actionRouters[id] = { action in
            switch action {
            case .primary:   gate(D.dismissedResult) // replaced below; see routing note
            case .secondary: gate(D.dismissedResult)
            case .close:     gate(D.dismissedResult)
            }
        }
    }

    public func dismiss(_ id: ModalID) {
        resolveDismissed[id]?()
    }

    private func teardown(_ id: ModalID) {
        presentations.removeAll { $0.id == id }
        resolveDismissed[id] = nil
        actionRouters[id] = nil
    }
}
```

> **Routing note — resolve this while implementing.** `gate` is typed `(D.Result) -> Void`, but
> `onAction` delivers a `GBAlertModal.ActionType`. For the standard family, `D.Result` is
> `AlertDialog.Result` and the mapping is `.primary → .primary`, `.secondary → .secondary`,
> `.close → .dismissed` — the same switch `AlertHolder.make` performs. The clean implementation
> is to store a per-id `(GBAlertModal.ActionType) -> Void` closure captured inside `present`,
> where `D` is still known, rather than the placeholder above. Write it that way; the sketch
> shows the shape, not the final code. `testInteractionResolvesOnceOnly` is what proves you got
> it right.

- [ ] **Step 4: Implement `ModalHost`**

Create `Sources/GBV3AlertModal/SwiftUI/ModalHost.swift`:

```swift
import SwiftUI

/// Overlays the renderer's live presentations on top of arbitrary content. The scrim must fill
/// the screen, so content is expanded to fill BEFORE `.overlay` — getting this backwards renders
/// the scrim inside a small centred box (a real bug already caught once on this codebase).
public struct ModalHost<Content: View>: View {
    @ObservedObject private var renderer: SwiftUIModalRenderer
    private let content: Content

    public init(renderer: SwiftUIModalRenderer, @ViewBuilder content: () -> Content) {
        self.renderer = renderer
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                ZStack {
                    ForEach(renderer.presentations) { presentation in
                        if !presentation.isHidden {
                            SwiftUIAlertModal(
                                resolved: presentation.resolved,
                                holder: presentation.holder,
                                tokens: presentation.tokens,
                                onAction: presentation.onAction
                            )
                        }
                    }
                }
            )
    }
}
```

- [ ] **Step 5: Run the renderer tests**

Expected: all 5 PASS.

- [ ] **Step 6: Run the full library suite**

Expected: ≥253 passing, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add -A Library/
git commit -m "feat(swiftui): SwiftUIModalRenderer present/dismiss + ModalHost

Implements ModalRenderer over SwiftUI state. Reuses AlertHolder.make for
content mapping and GBAlertModal.resolve for structure, so both renderers share
one chain and differ only in the final render step.

DataHolder.completion demands a non-optional GBAlertModal instance, which this
renderer never builds, so view interactions route through the renderer's own
resolve-once gate instead."
```

---

## Task 7: `update` and `setHidden` (W2b)

**Files:**
- Modify: `Sources/GBV3AlertModal/SwiftUI/SwiftUIModalRenderer.swift`
- Modify: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/SwiftUIModalRendererTests.swift`

**Interfaces:**
- Consumes: Task 6's `Presentation`
- Produces: `func update<D: ModalDescriptor>(_ id: ModalID, to descriptor: D)`, `func setHidden(_ id: ModalID, _ isHidden: Bool)`

- [ ] **Step 1: Write the failing tests**

Append to `SwiftUIModalRendererTests`:

```swift
    func testUpdateReplacesContentInPlaceWithoutResolving() {
        let renderer = makeRenderer()
        let id = ModalID()
        var resolveCount = 0
        renderer.present(
            AlertDialog(title: "A", subtitle: "S", primary: "OK"), id: id,
            resolve: { _ in resolveCount += 1 }
        )
        renderer.update(id, to: AlertDialog(title: "B", subtitle: "S", primary: "OK"))

        XCTAssertEqual(renderer.presentations.count, 1, "update must not add a presentation")
        XCTAssertEqual(renderer.presentations.first?.id, id, "identity must be stable — no blink")
        XCTAssertEqual(renderer.presentations.first?.holder.title, "B")
        XCTAssertEqual(resolveCount, 0, "update must not resolve the token")
    }

    func testSetHiddenKeepsPresentationLive() {
        let renderer = makeRenderer()
        let id = ModalID()
        var resolveCount = 0
        renderer.present(
            AlertDialog(title: "T", subtitle: "S", primary: "OK"), id: id,
            resolve: { _ in resolveCount += 1 }
        )
        renderer.setHidden(id, true)
        XCTAssertEqual(renderer.presentations.count, 1, "hiding must not tear down")
        XCTAssertEqual(renderer.presentations.first?.isHidden, true)
        XCTAssertEqual(resolveCount, 0, "hiding must not resolve the token")

        renderer.setHidden(id, false)
        XCTAssertEqual(renderer.presentations.first?.isHidden, false)
    }
```

- [ ] **Step 2: Run to verify they fail**

Expected: compile error — `update`/`setHidden` unimplemented (the protocol requires them, so the
type will not compile until Task 6 stubbed them; if stubbed as no-ops, the assertions fail).

- [ ] **Step 3: Implement both**

```swift
    /// Rebuild content IN PLACE. The presentation keeps its index and `id`, so SwiftUI diffs the
    /// card's contents rather than remounting it — this is the no-blink swap (spec D4). Never
    /// remove-then-insert, which is a real dismiss+present.
    public func update<D: ModalDescriptor>(_ id: ModalID, to descriptor: D) {
        guard
            let index = presentations.firstIndex(where: { $0.id == id }),
            let factory = factories[ObjectIdentifier(D.self)] as? Factory<D>,
            let router = actionRouters[id]
        else { return }

        let (properties, holder) = factory(descriptor, { _ in
            assertionFailure("update must not install a new resolve path; the original gate owns it")
        })
        let effective = properties ?? GBAlertModal.Properties()
        presentations[index] = Presentation(
            id: id,
            resolved: GBAlertModal.resolve(properties: effective, holder: holder, isLandscape: false),
            holder: holder,
            tokens: ModalTokens(from: effective),
            isHidden: presentations[index].isHidden,
            onAction: presentations[index].onAction
        )
        _ = router
    }

    /// Toggle visibility WITHOUT teardown or resolution — a coordinator hides the modal while its
    /// owning screen is covered and restores it on return.
    public func setHidden(_ id: ModalID, _ isHidden: Bool) {
        guard let index = presentations.firstIndex(where: { $0.id == id }) else { return }
        presentations[index].isHidden = isHidden
    }
```

> The `factory(descriptor, …)` call needs a resolve closure but must not create a second gate.
> If asserting inside it proves awkward under Swift 6 concurrency, store the original
> `(D.Result) -> Void` gate per id at `present` time and pass it here instead.

- [ ] **Step 4: Run to verify they pass**

Expected: both PASS.

- [ ] **Step 5: Run the full library suite**

Expected: ≥255 passing, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add -A Library/
git commit -m "feat(swiftui): SwiftUIModalRenderer update + setHidden

update rebuilds content in place at a stable index and id so SwiftUI diffs the
card rather than remounting it (the no-blink swap, spec D4). setHidden toggles
visibility without teardown or token resolution, which is what coordinator
hide/restore relies on."
```

---

## Task 8: C-2 parity gate — run the renderer-agnostic suite against both renderers (W2c)

**This is the stop-or-continue gate.** ~62 existing tests are renderer-agnostic. If the SwiftUI
renderer cannot pass them unchanged, stop and reassess before investing in W4–W6.

**Files:**
- Create: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Support/RendererFixtures.swift`
- Create: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/RendererParityTests.swift`

**Interfaces:**
- Consumes: `UIKitModalRenderer`, `SwiftUIModalRenderer`, `DefaultModalExecutor`
- Produces: `enum RendererKind: CaseIterable`, `func makeRenderer(_ kind: RendererKind) -> ModalRenderer`

- [ ] **Step 1: Write the fixture factory**

```swift
import UIKit
@testable import GBV3AlertModal

/// Both renderers implement the same contract, so executor- and coordinator-level behaviour must
/// be identical. Tests parameterised over this enum are the parity proof (spec C-2) — no new
/// assertions are authored, the existing semantics are simply re-run against the new backend.
enum RendererKind: String, CaseIterable {
    case uiKit, swiftUI
}

@MainActor
func makeRenderer(_ kind: RendererKind, window: UIWindow? = nil) -> ModalRenderer {
    switch kind {
    case .uiKit:
        return UIKitModalRenderer(
            alertProperties: GBAlertModal.Properties(),
            windowProvider: { window ?? UIWindow(frame: UIScreen.main.bounds) }
        )
    case .swiftUI:
        return SwiftUIModalRenderer(alertProperties: GBAlertModal.Properties())
    }
}
```

- [ ] **Step 2: Write the parity tests**

```swift
import XCTest
@testable import GBV3AlertModal

/// C-2: identical semantics across backends. Each case loops both renderers so a divergence
/// names the offending kind in the failure message.
@MainActor
final class RendererParityTests: XCTestCase {

    func testPresentThenPrimaryResolvesPrimary() async {
        for kind in RendererKind.allCases {
            let executor = DefaultModalExecutor(renderer: makeRenderer(kind))
            let token = executor.present(AlertDialog(title: "T", subtitle: "S", primary: "OK"))
            resolveFirstPresentation(on: executor, with: .primary, kind: kind)
            let result = await token.result
            XCTAssertEqual(result, .primary, "renderer \(kind.rawValue) diverged")
        }
    }

    func testDismissResolvesDismissed() async {
        for kind in RendererKind.allCases {
            let executor = DefaultModalExecutor(renderer: makeRenderer(kind))
            let token = executor.present(AlertDialog(title: "T", subtitle: "S", primary: "OK"))
            token.dismiss()
            let result = await token.result
            XCTAssertEqual(result, .dismissed, "renderer \(kind.rawValue) diverged")
        }
    }

    func testSetHiddenDoesNotResolve() async {
        for kind in RendererKind.allCases {
            let renderer = makeRenderer(kind)
            let executor = DefaultModalExecutor(renderer: renderer)
            let token = executor.present(AlertDialog(title: "T", subtitle: "S", primary: "OK"))
            renderer.setHidden(token.id, true)
            renderer.setHidden(token.id, false)
            token.dismiss()
            let result = await token.result
            XCTAssertEqual(result, .dismissed, "renderer \(kind.rawValue) resolved on hide")
        }
    }
}
```

> `resolveFirstPresentation(on:with:kind:)` is a helper you must write in
> `RendererFixtures.swift`: for `.swiftUI` it calls the renderer's
> `presentations.first?.onAction(action)`; for `.uiKit` it calls
> `live.values.first?.modal.dismissAndEmit(event: action)` — the same mechanism
> `Tier0DemoScreenSmokeTests` already uses. Verify the exact UIKit method name in
> `GBAlertModal+Events.swift` before writing it.
>
> Verify `DefaultModalExecutor.present`'s real signature and `ModalToken`'s API
> (`.result`, `.dismiss()`, `.id`) in `Core/ModalExecutor.swift` and `Core/ModalToken.swift` —
> adapt these tests to the actual names rather than assuming.

- [ ] **Step 3: Run the parity tests**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/RendererParityTests > /tmp/t8.log 2>&1; grep -E "Test Case .* (passed|failed)|Executed" /tmp/t8.log | tail -10`
Expected: all pass for **both** kinds.

- [ ] **Step 4: GATE — evaluate before continuing**

**If all parity tests pass:** the SwiftUI renderer is semantically equivalent at the
executor level. Continue to Task 9.

**If they fail for `.swiftUI` only:** STOP. Do not proceed to Task 9 or start W4–W6. Report
which behaviours diverged and why. This is the cheapest available signal that the two-renderer
approach costs more than the spec assumed, and the spec (§8) designates this exact point as the
place to reassess.

- [ ] **Step 5: Run the full library suite**

Expected: ≥258 passing, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add -A Library/
git commit -m "test(swiftui): C-2 renderer parity — executor semantics across both backends

Parameterises executor-level behaviour over UIKitModalRenderer and
SwiftUIModalRenderer. No new assertions are authored; existing semantics are
re-run against the new backend, which is the parity proof the spec asks for.

This is the stop-or-continue gate: a SwiftUI-only failure here means the
two-renderer approach costs more than the design assumed."
```

---

## Task 9: Coordinator parity (W3)

**Files:**
- Modify: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/RendererParityTests.swift`

**Interfaces:**
- Consumes: `RootScreenModalCoordinator`, `RendererKind`, `makeRenderer`
- Produces: no production API

- [ ] **Step 1: Read the existing coordinator tests**

Run: `grep -n "func test" Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/RootScreenModalCoordinatorTests.swift`
Expected: 24 test names covering serial / dedup / priority / interrupt / drain.

- [ ] **Step 2: Write the parity tests for the coordinator's five behaviours**

Append to `RendererParityTests`, one test per behaviour, each looping `RendererKind.allCases`.
Port the assertions from `RootScreenModalCoordinatorTests` — do not invent new semantics.

```swift
    func testSerialPresentationAcrossRenderers() async {
        for kind in RendererKind.allCases {
            let coordinator = RootScreenModalCoordinator(renderer: makeRenderer(kind))
            // Port the body of RootScreenModalCoordinatorTests' serial-presentation test here,
            // substituting `coordinator`. Assert the same ordering invariant, with
            // "renderer \(kind.rawValue)" in every failure message.
            _ = coordinator
        }
    }
```

> Repeat for dedup, priority, interrupt and drain. Read each source test and port its body
> verbatim — the point of this task is that the SwiftUI backend satisfies the *existing*
> contract, so inventing new assertions would defeat it. Check
> `RootScreenModalCoordinator`'s real initializer signature in `Core/RootScreenModalCoordinator.swift`.

- [ ] **Step 3: Run them**

Expected: all pass for both kinds. A `.swiftUI`-only failure is the same stop signal as Task 8.

- [ ] **Step 4: Run the full library suite**

Expected: ≥263 passing, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add -A Library/
git commit -m "test(swiftui): coordinator parity across both renderers (W3)

Ports RootScreenModalCoordinatorTests' serial/dedup/priority/interrupt/drain
assertions to run against both backends. Assertions are ported verbatim rather
than rewritten: the claim under test is that the SwiftUI backend satisfies the
existing contract."
```

---

## Task 10: Prove the C-3a geometry harness on one shape

Scales to full coverage in the W4–W6 plan. This task only proves the machinery works.

**Files:**
- Create: `Sources/GBV3AlertModal/SwiftUI/ModalGeometryProbe.swift`
- Modify: `Sources/GBV3AlertModal/SwiftUI/SwiftUIAlertModal.swift`
- Create: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/GeometryDifferentialTests.swift`

**Interfaces:**
- Produces: `enum ModalElement: String` (`card`, `banner`, `title`, `subtitle`, `primary`, `secondary`, `close`), `struct ModalGeometryKey: PreferenceKey`, `View.modalGeometryProbe(_ element: ModalElement)`

- [ ] **Step 1: Write the probe**

```swift
import SwiftUI

/// Named layout elements whose frames are compared against the UIKit renderer's (spec C-3a).
public enum ModalElement: String, Hashable, Sendable {
    case card, banner, title, subtitle, primary, secondary, close
}

/// Publishes measured frames so tests can compare SwiftUI's layout to UIKit's WITHOUT pixels.
/// This is an observability seam, not test scaffolding: these are the same boundaries the
/// descriptor already renders. Only DEBUG builds collect, so release binaries carry nothing.
public struct ModalGeometryKey: PreferenceKey {
    public static var defaultValue: [ModalElement: CGRect] { [:] }
    public static func reduce(
        value: inout [ModalElement: CGRect], nextValue: () -> [ModalElement: CGRect]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

public extension View {
    /// Report this view's frame in the global coordinate space under `element`.
    func modalGeometryProbe(_ element: ModalElement) -> some View {
        #if DEBUG
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ModalGeometryKey.self,
                    value: [element: proxy.frame(in: .global)]
                )
            }
        )
        #else
        self
        #endif
    }
}
```

> `GeometryReader` + `PreferenceKey` is used rather than `onGeometryChange`, which is iOS 16+
> and would breach the iOS 15 floor.

- [ ] **Step 2: Attach probes in `SwiftUIAlertModal`**

Add `.modalGeometryProbe(.card)` to the card container, `.title` to the title `Text`,
`.primary` to the primary button. Leave the rest for the W4–W6 plan.

- [ ] **Step 3: Write the differential test**

```swift
import XCTest
import SwiftUI
@testable import GBV3AlertModal

/// C-3a: compare SwiftUI's computed layout against UIKit's — the SHIPPING implementation, not a
/// recorded baseline. A recorded snapshot can only detect drift from itself; it cannot catch
/// wrong-but-consistent design, and did not (the card width, spacing and button style were all
/// wrong while snapshots were green).
@MainActor
final class GeometryDifferentialTests: XCTestCase {

    private static let tolerance: CGFloat = 1.0

    func testCardWidthMatchesUIKit() throws {
        let dialog = AlertDialog(title: "Title", subtitle: "Subtitle", primary: "OK")
        let properties = GBAlertModal.Properties()
        let size = CGSize(width: 390, height: 844)

        let uiKitWidth = try measureUIKitCardWidth(dialog: dialog, properties: properties, in: size)
        let swiftUIWidth = try measureSwiftUICardWidth(dialog: dialog, properties: properties, in: size)

        XCTAssertEqual(
            swiftUIWidth, uiKitWidth, accuracy: Self.tolerance,
            "SwiftUI card width \(swiftUIWidth) diverges from UIKit \(uiKitWidth)"
        )
    }
}
```

> Write `measureUIKitCardWidth` by building a `GBAlertModal`, adding it to a sized `UIWindow`,
> calling `layoutIfNeeded()`, and reading the content container's frame — find its accessor in
> `GBAlertModal+ViewGraph.swift`. Write `measureSwiftUICardWidth` by hosting
> `SwiftUIAlertModal` in a `UIHostingController` sized to `size`, forcing layout, and reading the
> `ModalGeometryKey` preference via `.onPreferenceChange` into a captured box.
>
> **If the two widths genuinely differ, that is a real finding — report it, do not widen the
> tolerance to make it pass.** The tolerance exists for sub-pixel rounding, not for disagreement.

- [ ] **Step 4: Run it**

Expected: PASS, or a concrete divergence to report.

- [ ] **Step 5: Run the full library suite**

Expected: ≥264 passing, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add -A Library/
git commit -m "test(swiftui): C-3a geometry differential harness, proven on card width

Adds a DEBUG-only GeometryReader/PreferenceKey probe and compares SwiftUI's
computed layout against the UIKit renderer's. The baseline is the shipping
implementation rather than a recording, so this catches wrong-but-consistent
layout, which a self-recorded snapshot provably cannot.

Proves the machinery on one element; full coverage lands with W4-W6."
```

---

## Self-Review

**Spec coverage:**

| Spec item | Task |
|---|---|
| T3 Tier-0 demo → GalleryPresets | 1 |
| T5 one target + folders + Core-purity test | 2 |
| T7 no resolver surgery | 4 (SwiftUI calls `resolve` unchanged) |
| C-1 delete `ResolvedAlert` | 4 |
| C-0 token provenance | 5 |
| W1 promote surface | 3 |
| W2 `SwiftUIModalRenderer` | 6, 7 |
| C-2 parity | 8 |
| W3 coordinator parity | 9 |
| C-3a geometry harness | 10 |
| D8-revised `style:` token | **W4–W6 plan** — deliberately deferred past the gate |
| T6 20-shape coverage | **W4–W6 plan** |
| W5 SHSans / C-4 pixel diff | **W4–W6 plan** |

**Known gaps, stated rather than hidden:**

1. **Task 6's routing sketch is incomplete by design.** The `ActionType → D.Result` mapping is
   described in prose with the correct approach named, because writing it requires the generic
   context. `testInteractionResolvesOnceOnly` is the check that catches a wrong implementation.
2. **Task 9's test bodies are not written out.** They are ports of 24 existing tests; reproducing
   them here would be transcription, and the instruction to port verbatim is the actual
   requirement. The implementer must read the source tests.
3. **Several signatures need verification against source before use** — flagged inline at each
   site (`AlertDialog.init` labels, `GBAlertModal.resolve` call form, `Properties`/`ContentProperty`
   inits, `DefaultModalExecutor.present`, `ModalToken` API, `RootScreenModalCoordinator.init`,
   `GBAlertModal.dismissAndEmit`). These were not verified while writing the plan; every site
   says so and tells the implementer to check before running.
4. **Expected test counts are cumulative lower bounds** (239 → 264). If a task's count comes in
   below its floor, tests were lost in a move — investigate before proceeding rather than
   accepting the new number.
