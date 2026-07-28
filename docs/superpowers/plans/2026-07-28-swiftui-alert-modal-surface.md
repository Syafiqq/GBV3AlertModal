# SwiftUI Alert Modal — Content/Descriptor Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the decided SwiftUI alert-modal *descriptor surface* — `AlertDialog` carrying `AttributedString` title/subtitle with a guarded UIKit round-trip — in the library, and keep the example prototype compiling; defer the SwiftUI *view* realizations until the Tier fork resolves.

**Architecture:** `AlertDialog` (a `Sendable` value descriptor in the library) changes its `title`/`subtitle` storage from `String?` to `AttributedString?`, exposed through two convenience inits (all-`String`, all-`AttributedString`) so existing plain callers are unchanged. The one live consumer — the UIKit renderer's `AlertHolder.make` mapping — splits each `AttributedString?` into the legacy `DataHolder`'s plain-`String?` vs `NSAttributedString?` fields, constrained to a whitelisted bold/color/link subgrammar with a golden round-trip test. The example app's SwiftUI prototype is updated only enough to compile against the new types, plus a dead-field cleanup.

**Tech Stack:** Swift 6 language mode, SwiftPM library target, XCTest, `xcodebuild` on an iOS Simulator (iOS-only package). Foundation `AttributedString` ⇄ `NSAttributedString` bridging.

## Global Constraints

- iOS floor: **15.0**. Swift **6 language mode**; library must stay strict-concurrency clean (0 warnings).
- **No new dependencies.** Snapshot dep (`swift-snapshot-testing`) is test-target only; not used here.
- **Additive only** on `AlertDialog`: no existing `String` call site may break. Drop `NSAttributedString` from the *new* public surface (it never appears on `AlertDialog`); the legacy `DataHolder` keeps its own `NSAttributedString?` fields untouched.
- **`AttributedString` is `Sendable`** — it may live on the descriptor. A `@ViewBuilder`/`UIImage`/`UIView` may **not**.
- **Whitelisted attribute subgrammar:** descriptor `AttributedString` styling is limited to **bold (`.font`/`.inlinePresentationIntent`), color (`.foregroundColor` as `UIColor`), and inline link (`.link`)** — Foundation-bridgeable keys only. SwiftUI-only attribute scopes do not bridge to `NSAttributedString.Key` and are out of contract.
- Library tests: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17'` (builds the package directly, honours `swiftSettings`).
- Example tests: `xcodebuild test -project Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17'` — a repo-root workspace shadows the scheme, so the `-project` form is required. Confirm executed-count > 0 (grep `Test case '<Class>.<method>()' passed`), never trust the SUCCEEDED banner alone.
- Spec: `docs/superpowers/specs/2026-07-28-swiftui-alert-modal-surface-design.md`.

---

## File Structure

**Phase 1 — Library descriptor (ships now, guarded):**
- Modify `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/Descriptors/AlertDialog.swift` — `title`/`subtitle` become `AttributedString?`; two inits.
- Create `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/Descriptors/ModalText.swift` — `AttributedString?` → `(plain: String?, attributed: NSAttributedString?)` split + whitelisted builders.
- Modify `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/UIKitModalRenderer+Holder.swift` — route split output into `DataHolder`.
- Create `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/ModalTextTests.swift` — split + golden round-trip.
- Modify `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/AlertDialogMappingTests.swift` — plain-vs-attributed mapping assertions; two-init equivalence.

**Phase 1 — Example compile-keep + cleanup:**
- Modify `Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/AlertResolution.swift` — `present(_:)` reads `AttributedString?`; remove dead `dismissOnOverlayTap`.
- Modify `Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/SwiftUIAlertModal.swift` — render `AttributedString` title/subtitle.
- Modify `Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/AlertResolutionTests.swift` — drop the dead-field test.

**Phase 2 — Example view realization (DEFERRED, gated on Tier fork; see Phase 2 header).**

---

# PHASE 1 — Library descriptor surface (ships now)

### Task 1: `AlertDialog` stores `AttributedString`, two inits

**Files:**
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/Descriptors/AlertDialog.swift`
- Test: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/AlertDialogMappingTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `AlertDialog.title: AttributedString?`, `AlertDialog.subtitle: AttributedString?`
  - `init(image: ModalImage? = nil, title: String? = nil, subtitle: String? = nil, primary: String, secondary: String? = nil, closeOnTapOverlay: Bool = false, showCloseButton: Bool = false)` — the plain path (unchanged ergonomics; lifts `String`→`AttributedString`).
  - `init(image: ModalImage? = nil, title: AttributedString?, subtitle: AttributedString?, primary: String, secondary: String? = nil, closeOnTapOverlay: Bool = false, showCloseButton: Bool = false)` — the rich path (title/subtitle **non-defaulted** to keep overload resolution unambiguous).

- [ ] **Step 1: Write the failing test** (append to `AlertDialogMappingTests.swift`)

```swift
func test_stringInit_liftsToAttributedString() {
    let d = AlertDialog(title: "Hi", subtitle: "There", primary: "OK")
    XCTAssertEqual(d.title.map { String($0.characters) }, "Hi")
    XCTAssertEqual(d.subtitle.map { String($0.characters) }, "There")
}

func test_bothInits_equivalentForPlainText() {
    let s = AlertDialog(title: "Hi", subtitle: "There", primary: "OK")
    let a = AlertDialog(title: AttributedString("Hi"), subtitle: AttributedString("There"), primary: "OK")
    XCTAssertEqual(s.title, a.title)
    XCTAssertEqual(s.subtitle, a.subtitle)
}

func test_bareInit_isUnambiguous_resolvesToStringPath() {
    // Compiles only because the AttributedString init does not default title/subtitle.
    let d = AlertDialog(primary: "OK")
    XCTAssertNil(d.title)
    XCTAssertNil(d.subtitle)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/AlertDialogMappingTests`
Expected: FAIL to compile (`title` is `String?`, no `AttributedString` init).

- [ ] **Step 3: Change storage + add the two inits** in `AlertDialog.swift`

```swift
import Foundation

public struct AlertDialog: ModalDescriptor {
    public enum Result: Sendable, Equatable { case primary, secondary, dismissed }
    public static var dismissedResult: Result { .dismissed }

    public var image: ModalImage?
    public var title: AttributedString?
    public var subtitle: AttributedString?
    public var primary: String
    public var secondary: String?
    public var closeOnTapOverlay: Bool
    public var showCloseButton: Bool

    /// Plain path — unchanged ergonomics for the ~114 existing String call sites.
    public init(
        image: ModalImage? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        primary: String,
        secondary: String? = nil,
        closeOnTapOverlay: Bool = false,
        showCloseButton: Bool = false
    ) {
        self.init(
            image: image,
            title: title.map(AttributedString.init),
            subtitle: subtitle.map(AttributedString.init),
            primary: primary,
            secondary: secondary,
            closeOnTapOverlay: closeOnTapOverlay,
            showCloseButton: showCloseButton
        )
    }

    /// Rich path — title/subtitle are NOT defaulted, so `AlertDialog(primary:)` can only
    /// resolve to the String init above (kills the all-text-omitted overload ambiguity).
    public init(
        image: ModalImage? = nil,
        title: AttributedString?,
        subtitle: AttributedString?,
        primary: String,
        secondary: String? = nil,
        closeOnTapOverlay: Bool = false,
        showCloseButton: Bool = false
    ) {
        self.image = image
        self.title = title
        self.subtitle = subtitle
        self.primary = primary
        self.secondary = secondary
        self.closeOnTapOverlay = closeOnTapOverlay
        self.showCloseButton = showCloseButton
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/AlertDialogMappingTests`
Expected: the three new tests PASS. (`test_alertDialog_mapsToExpectedResolvedModal` may fail to compile until Task 2 — that is expected; if the run stops at compile, proceed to Task 2 and run them together.)

- [ ] **Step 5: Commit**

```bash
git add Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/Descriptors/AlertDialog.swift \
        Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/AlertDialogMappingTests.swift
git commit -m "feat(descriptor): AlertDialog title/subtitle as AttributedString + two inits"
```

---

### Task 2: `ModalText` split + guarded UIKit round-trip

**Files:**
- Create: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/Descriptors/ModalText.swift`
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/UIKitModalRenderer+Holder.swift`
- Test: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/ModalTextTests.swift` (create)

**Interfaces:**
- Consumes: `AlertDialog.title/subtitle: AttributedString?` (Task 1).
- Produces:
  - `enum ModalText { static func split(_ text: AttributedString?) -> (plain: String?, attributed: NSAttributedString?) }`
  - `AlertHolder.make` now routes `split(...)` output into `DataHolder.title`/`.titleAttributed`/`.subtitle`/`.subtitleAttributed`.

**Split contract:** `nil` → `(nil, nil)`. An `AttributedString` with **no** styling runs → `(String(characters), nil)` so the resolver sees `.plain` and applies default font/color. Any styling run → `(nil, NSAttributedString(text))` so the resolver sees `.attributed` and renders as-is.

- [ ] **Step 1: Write the failing test** (`ModalTextTests.swift`)

```swift
import XCTest
import UIKit
@testable import GBV3AlertModal

final class ModalTextTests: XCTestCase {
    func test_nil_mapsToNothing() {
        let (p, a) = ModalText.split(nil)
        XCTAssertNil(p); XCTAssertNil(a)
    }

    func test_plain_mapsToPlainString() {
        let (p, a) = ModalText.split(AttributedString("Body"))
        XCTAssertEqual(p, "Body")
        XCTAssertNil(a)
    }

    func test_styled_mapsToAttributed_losslessForWhitelistedKeys() {
        var s = AttributedString("Bold")
        s.foregroundColor = UIColor.red
        s.font = .boldSystemFont(ofSize: 17)
        let (p, a) = ModalText.split(s)
        XCTAssertNil(p)
        let ns = try XCTUnwrap(a)
        XCTAssertEqual(ns.string, "Bold")
        let attrs = ns.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual(attrs[.foregroundColor] as? UIColor, .red)
        XCTAssertEqual((attrs[.font] as? UIFont)?.pointSize, 17)
    }

    func test_link_bridgesToNSLinkAttribute() {
        var s = AttributedString("tap")
        s.link = URL(string: "https://x.test")
        let ns = try! XCTUnwrap(ModalText.split(s).attributed)
        XCTAssertEqual(ns.attribute(.link, at: 0, effectiveRange: nil) as? URL,
                       URL(string: "https://x.test"))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/ModalTextTests`
Expected: FAIL to compile (`ModalText` undefined).

- [ ] **Step 3: Implement `ModalText.swift`**

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
        let isPlain = text.runs.allSatisfy { $0.attributes == AttributeContainer() }
        if isPlain { return (String(text.characters), nil) }
        return (nil, NSAttributedString(text))
    }
}
```

- [ ] **Step 4: Route the split into `AlertHolder.make`** (`UIKitModalRenderer+Holder.swift`)

```swift
public static func make(
    for descriptor: AlertDialog,
    resolve: @escaping (AlertDialog.Result) -> Void
) -> GBAlertModal.DataHolder {
    let (titlePlain, titleAttr) = ModalText.split(descriptor.title)
    let (subPlain, subAttr) = ModalText.split(descriptor.subtitle)
    return GBAlertModal.DataHolder(
        closeOnTapOverlay: descriptor.closeOnTapOverlay,
        banner: descriptor.image.flatMap { UIImage(named: $0.assetName) },
        title: titlePlain,
        titleAttributed: titleAttr,
        subtitle: subPlain,
        subtitleAttributed: subAttr,
        primaryAction: descriptor.primary,
        secondaryAction: descriptor.secondary,
        showCloseButton: descriptor.showCloseButton,
        dismissOnAction: false, // gate owns teardown; see UIKitModalRenderer
        completion: { _, action in
            switch action {
            case .primary: resolve(.primary)
            case .secondary: resolve(.secondary)
            case .close: resolve(.dismissed)
            }
        }
    )
}
```

- [ ] **Step 5: Update `AlertDialogMappingTests` for the plain/attributed routing**

Replace `test_alertDialog_mapsToExpectedResolvedModal` and add an attributed case:

```swift
func test_plainDescriptor_mapsToPlainSubtitle() {
    let holder = UIKitModalRenderer.AlertHolder.make(
        for: AlertDialog(title: "Title", subtitle: "Body", primary: "OK", secondary: "Cancel")
    ) { _ in }
    let resolved = GBAlertModal.resolve(
        properties: GeniePresets.standardProperties(), holder: holder, isLandscape: false
    )
    XCTAssertTrue(resolved.showsTitle)
    XCTAssertEqual(resolved.subtitle, .plain("Body"))
    XCTAssertFalse(resolved.dismissOnAction)
}

func test_styledDescriptor_mapsToAttributedSubtitle() {
    var body = AttributedString("Body")
    body.foregroundColor = .red
    let holder = UIKitModalRenderer.AlertHolder.make(
        for: AlertDialog(title: nil, subtitle: body, primary: "OK")
    ) { _ in }
    let resolved = GBAlertModal.resolve(
        properties: GeniePresets.standardProperties(), holder: holder, isLandscape: false
    )
    XCTAssertEqual(resolved.subtitle, .attributed)
}
```

- [ ] **Step 6: Run the library suite**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: full suite PASS (was 224/224). Confirm `ModalTextTests` + `AlertDialogMappingTests` execute.

- [ ] **Step 7: Commit**

```bash
git add Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/Descriptors/ModalText.swift \
        Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/UIKitModalRenderer+Holder.swift \
        Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/ModalTextTests.swift \
        Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/AlertDialogMappingTests.swift
git commit -m "feat(renderer): guarded AttributedString->DataHolder split (bold/color/link golden)"
```

---

### Task 3: Keep example prototype compiling + dead-field cleanup

**Files:**
- Modify: `Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/AlertResolution.swift`
- Modify: `Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/SwiftUIAlertModal.swift`
- Modify: `Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/AlertResolutionTests.swift`

**Interfaces:**
- Consumes: `AlertDialog.title/subtitle: AttributedString?` (Task 1).
- Produces: `ResolvedAlert` without the `dismissOnOverlayTap` field (overlay behavior stays in `resolve(_:_:)`).

- [ ] **Step 1: Update `ResolvedAlert` to read `AttributedString?` and drop the dead field** (`AlertResolution.swift`)

```swift
struct ResolvedAlert {
    let showsBanner: Bool
    let showsTitle: Bool
    let showsSubtitle: Bool
    let showsSecondary: Bool
    let showsClose: Bool

    init(_ config: AlertDialog) {
        func present(_ s: AttributedString?) -> Bool { !(s?.characters.isEmpty ?? true) }
        showsBanner = config.image != nil
        showsTitle = present(config.title)
        showsSubtitle = present(config.subtitle)
        showsSecondary = !(config.secondary ?? "").isEmpty
        showsClose = config.showCloseButton
    }
}
```

- [ ] **Step 2: Render `AttributedString` in the view** (`SwiftUIAlertModal.swift`)

The banner/title/subtitle branches read `config.title`/`config.subtitle` which are now `AttributedString?`. `Text(_ AttributedString)` exists, so:

```swift
if resolved.showsTitle, let title = config.title {
    Text(title)
        .font(.title2.bold())
        .multilineTextAlignment(.center)
}
if resolved.showsSubtitle, let subtitle = config.subtitle {
    Text(subtitle)
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
}
```

- [ ] **Step 3: Remove the dead-field test** (`AlertResolutionTests.swift`)

Delete `test_dismissOnOverlayTap_mirrors_flag` (lines ~38–41). Overlay behavior is already covered by the `resolve(.overlayTapped, ...)` test, which reads `config.closeOnTapOverlay` directly.

- [ ] **Step 4: Run the example unit suite**

Run: `xcodebuild test -project Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalExampleTests`
Expected: PASS; confirm executed-count > 0 (grep `Test case '…' passed`). If launch hits Mach -308: `xcrun simctl shutdown all` then reboot iPhone 17.

- [ ] **Step 5: Commit**

```bash
git add Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/AlertResolution.swift \
        Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/SwiftUIAlertModal.swift \
        Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/AlertResolutionTests.swift
git commit -m "chore(example): compile prototype against AttributedString; drop dead dismissOnOverlayTap"
```

---

# PHASE 2 — Example view realization (DEFERRED)

> **Gate:** D10 keeps the SwiftUI *views* in the example app until the owner picks a Tier
> (keep-local / Tier 0 / Tier 1). These tasks are decided (D1/D4/D5/D8) and low-risk, but they
> are **prototype evolution, not required for the Phase-1 library change to ship.** Execute only
> when evolving the prototype; skip if the Tier decision might discard these views.

### Task 4: `ModalTokens` + two `ButtonStyle`s (D8)
- Create `Examples/.../SwiftUI/ModalTokens.swift`: `enum ModalTokens { static let cornerRadius: CGFloat = 16; static let cardWidthPhone: CGFloat = 256; static let cardWidthPad: CGFloat = 300; static let spacing: CGFloat = 16; static let contentPadding: CGFloat = 24; static let scrimOpacity: Double = 0.6 }` — **values transcribed from the app's real `V3AlertModal` memoized preset**, not invented; verify against `Common/.../AlertModal/V3AlertModal*.swift`.
- Create `ObliquePrimaryStyle`/`PlainSecondaryStyle: ButtonStyle` matching the app (oblique primary, plain secondary).
- Replace the inline magic numbers/`Color.accentColor`/`Capsule()` in `SwiftUIAlertModal.swift` with token/style references. Judge by running the demo (no snapshot infra in the example target).

### Task 5: `AlertModalScaffold<Content: View>` (D1)
- Create `Examples/.../SwiftUI/AlertModalScaffold.swift`: the shared chrome (scrim + card + optional close + buttons) with a `@ViewBuilder content: () -> Content` body slot and `onAction: (AlertDialog.Result) -> Void`; never self-dismisses.
- Refactor `SwiftUIAlertModal` to be `AlertModalScaffold` with a built-in standard body (title/subtitle/image), proving the shared-chrome factoring.
- Port `SatisfactionDemoView` to compose `AlertModalScaffold { …rows… }` as the worked bespoke example.

### Task 6: No-blink in-place swap demo + test (D4)
- In `SwiftUIDemoScreen`, add an A→B "swap content" button that mutates `active = demoB` **without** an intermediate `active = nil`, and assert (behavioral, not snapshot) the slot is never nilled across the swap and identity is stable (no per-descriptor `.id`).

---

## Self-Review

**Spec coverage:** D1→Task 5 (scaffold) / structurally set up in Phase 1; D2→Task 1 (reuse AlertDialog); D3→Tasks 1–2; D4→Task 3 (dismissal) + Task 6 (no-blink); D5→Task 4 (fixed glyph via tokens; prototype already fixed); D6→unchanged (flags already on descriptor, Task 2 passes them through); D7→unchanged (`ModalImage` already there); D8→Task 4; D9→unchanged (existing `completion`→`resolve` wiring in `AlertHolder.make`); D10→Phase split (descriptor=library, views=example) + Task 2 guardrails. Cleanup→Task 3.

**Placeholder scan:** no TBD/TODO; Phase 2 is explicitly marked deferred with concrete file targets, not vague steps.

**Type consistency:** `ModalText.split` returns `(plain: String?, attributed: NSAttributedString?)` and is consumed with that exact tuple in `AlertHolder.make`. `AlertDialog.title/subtitle: AttributedString?` used consistently in Tasks 1–3. `DataHolder` init labels (`title`, `titleAttributed`, `subtitle`, `subtitleAttributed`) match `GBAlertModal+DataHolder.swift`.

**Known nuance:** the rich init's non-defaulted `title`/`subtitle` is the deliberate disambiguator; `test_bareInit_isUnambiguous_resolvesToStringPath` locks it.
