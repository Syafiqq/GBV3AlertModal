# Modal Executor Capability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a VM-facing, SwiftUI-ready modal-presentation *capability* to the `GBV3AlertModal` library — a pure descriptor + token + renderer seam — built and tested entirely inside this module.

**Architecture:** A ViewModel calls `ModalExecutor.present(descriptor)` with a **pure, `Sendable` descriptor** (content only) and gets a `ModalToken` whose `result` is awaited. The concrete `DefaultModalExecutor` forwards to a `UIKitModalRenderer`, which owns all UIKit: it looks up a registered factory to build a `GBAlertModal`, shows it on a window, and funnels every teardown path through a single resolve-once gate. Style lives in the renderer (injected `Properties`), never in the descriptor. Two seams only — no coordinator, overlap accepted.

**Tech Stack:** Swift (library authored in Swift 5 language mode, tools 5.9), UIKit, SnapKit, XCTest via `xcodebuild` on an iOS Simulator.

## Global Constraints

- **This task touches ONLY** `Library/GBV3AlertModal/Sources/GBV3AlertModal/**`, `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/**`. **No distribution-app files. No app call-site migration.** (Migration is a separate downstream task.)
- **No new dependencies.**
- **Descriptors are pure value types conforming to `Sendable`; all UIKit is confined to the renderer.**
- **Concurrency:** all UIKit-facing types are `@MainActor`; `ModalDescriptor`/`Result` are `Sendable`. Authored in the library's existing **Swift 5 language mode** (annotations are valid there). Do NOT change `swift-tools-version` or flip the package to Swift 6 mode.
- **Style is injected at renderer construction** (`GBAlertModal.Properties`); the library ships no Geniebook design tokens.
- **Tests run from** `Library/GBV3AlertModal/` with:
  `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/<Class>[/<method>]`
  (iPhone 17 is the available booted simulator; adjust `name=` if yours differs — `xcrun simctl list devices`).
- **TDD, one behavior per test, frequent commits.** Reuse the existing `GeniePresets` and `UIImage.gbv3TestSolid` test support — do not duplicate them.

---

### Task 1: Pure descriptor protocol + `AlertDialog` + mapping-equivalence test

**Files:**
- Create: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/ModalDescriptor.swift`
- Create: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/Descriptors/AlertDialog.swift`
- Create: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/UIKitModalRenderer+Holder.swift` (the descriptor→`DataHolder` mapping, so the renderer and the test share one source of truth)
- Test: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/AlertDialogMappingTests.swift`

**Interfaces:**
- Produces:
  - `protocol ModalDescriptor: Sendable { associatedtype Result: Sendable; static var dismissedResult: Result { get } }`
  - `struct ModalImage: Sendable, Equatable { let assetName: String; init(_:) }`
  - `struct AlertDialog: ModalDescriptor` with `enum Result: Sendable, Equatable { case primary, secondary, dismissed }` and fields `image, title, subtitle, primary, secondary, closeOnTapOverlay, showCloseButton`
  - `enum UIKitModalRenderer.AlertHolder { static func make(for: AlertDialog, resolve:) -> GBAlertModal.DataHolder }` (namespaced holder builder; the `UIKitModalRenderer` class itself arrives in Task 3)

- [ ] **Step 1: Write the failing test**

```swift
// AlertDialogMappingTests.swift
import XCTest
import UIKit
@testable import GBV3AlertModal

/// The executor does not change rendering — it only builds a `DataHolder`. This asserts the
/// AlertDialog→DataHolder mapping produces the SAME render decisions the Layer-A resolver
/// already guards, using `GBAlertModal.resolve(...)` as the oracle. No new snapshots.
final class AlertDialogMappingTests: XCTestCase {
    func test_alertDialog_mapsToExpectedResolvedModal() {
        let descriptor = AlertDialog(
            title: "Title", subtitle: "Body", primary: "OK", secondary: "Cancel"
        )
        let holder = UIKitModalRenderer.AlertHolder.make(for: descriptor) { _ in }
        let resolved = GBAlertModal.resolve(
            properties: GeniePresets.standardProperties(), holder: holder, isLandscape: false
        )

        XCTAssertTrue(resolved.showsTitle)
        XCTAssertEqual(resolved.subtitle, .plain("Body"))
        XCTAssertTrue(resolved.showsPrimary)
        XCTAssertTrue(resolved.showsSecondary)
        XCTAssertFalse(resolved.showsBanner)
        // Gate owns teardown → the built-in AlertDialog holder bakes dismissOnAction=false.
        XCTAssertFalse(resolved.dismissOnAction)
    }

    func test_alertDialogResult_dismissedResultIsDismissed() {
        XCTAssertEqual(AlertDialog.dismissedResult, .dismissed)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/AlertDialogMappingTests`
Expected: FAIL to compile — `AlertDialog` / `UIKitModalRenderer.AlertHolder` undefined.

- [ ] **Step 3: Write `ModalDescriptor.swift`**

```swift
import Foundation

/// A pure, UIKit-free description of *what* to present. The renderer maps it to a UIKit view.
public protocol ModalDescriptor: Sendable {
    associatedtype Result: Sendable
    /// The result the renderer resolves with when the modal is torn down without a user action.
    static var dismissedResult: Result { get }
}

/// An asset-catalog image reference (a name, not a `UIImage`) so descriptors stay `Sendable`.
public struct ModalImage: Sendable, Equatable {
    public let assetName: String
    public init(_ assetName: String) { self.assetName = assetName }
}
```

- [ ] **Step 4: Write `Descriptors/AlertDialog.swift`**

```swift
import Foundation

/// The general-purpose alert/confirm dialog: content only. Style is fixed by the renderer.
public struct AlertDialog: ModalDescriptor {
    public enum Result: Sendable, Equatable { case primary, secondary, dismissed }
    public static var dismissedResult: Result { .dismissed }

    public var image: ModalImage?
    public var title: String?
    public var subtitle: String?
    public var primary: String
    public var secondary: String?
    public var closeOnTapOverlay: Bool
    public var showCloseButton: Bool

    public init(
        image: ModalImage? = nil,
        title: String? = nil,
        subtitle: String? = nil,
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

- [ ] **Step 5: Write `UIKitModalRenderer+Holder.swift`**

```swift
import UIKit

extension UIKitModalRenderer {
    /// Descriptor→`DataHolder` mapping for the built-in `AlertDialog`. Kept separate so the
    /// mapping is unit-testable without a window (Task 1) and reused by the factory (Task 3).
    public enum AlertHolder {
        public static func make(
            for descriptor: AlertDialog,
            resolve: @escaping (AlertDialog.Result) -> Void
        ) -> GBAlertModal.DataHolder {
            GBAlertModal.DataHolder(
                closeOnTapOverlay: descriptor.closeOnTapOverlay,
                banner: descriptor.image.flatMap { UIImage(named: $0.assetName) },
                title: descriptor.title,
                subtitle: descriptor.subtitle,
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
    }
}
```

> This file references `UIKitModalRenderer` (defined in Task 3). To compile Task 1 in isolation, add a one-line forward stub at the top of the file — `@MainActor public final class UIKitModalRenderer {}` — and DELETE that stub in Task 3 Step 3 when the real class lands. (Noted again in Task 3.)

- [ ] **Step 6: Run test to verify it passes**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/AlertDialogMappingTests`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor
git commit -m "feat(executor): pure ModalDescriptor + AlertDialog + holder mapping"
```

---

### Task 2: `ModalToken` — resolve-once, async replay

**Files:**
- Create: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/ModalToken.swift`
- Test: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/ModalTokenTests.swift`

**Interfaces:**
- Produces:
  - `struct ModalID: Hashable, Sendable { init() }`
  - `@MainActor final class ModalToken<Result: Sendable> { let id: ModalID; var result: Result { get async }; func resolve(_:) }` (`resolve` is `internal` — only the renderer calls it)

- [ ] **Step 1: Write the failing test**

```swift
// ModalTokenTests.swift
import XCTest
@testable import GBV3AlertModal

final class ModalTokenTests: XCTestCase {
    @MainActor
    func test_resolve_isOnce_andReplaysToLaterAwaiters() async {
        let token = ModalToken<Int>()
        token.resolve(1)
        token.resolve(2) // second resolve ignored
        let first = await token.result
        let second = await token.result // replays the same value
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)
    }

    @MainActor
    func test_result_deliversToWaiterOnLaterResolve() async {
        let token = ModalToken<Int>()
        let waiter = Task { await token.result }
        await Task.yield() // let `waiter` suspend on the continuation before we resolve
        token.resolve(42)
        let value = await waiter.value
        XCTAssertEqual(value, 42)
    }

    @MainActor
    func test_eachToken_hasDistinctID() {
        XCTAssertNotEqual(ModalToken<Int>().id, ModalToken<Int>().id)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/ModalTokenTests`
Expected: FAIL to compile — `ModalToken` / `ModalID` undefined.

- [ ] **Step 3: Write `ModalToken.swift`**

```swift
import Foundation

/// Opaque identity for a live presentation. New value per instance.
public struct ModalID: Hashable, Sendable {
    private let raw: UUID
    public init() { raw = UUID() }
}

/// Handle a ViewModel may hold: identity + an opt-in, replayable async result.
/// NEVER holds the UIView. `@MainActor`-isolated, so its resolve/replay state needs no lock.
@MainActor
public final class ModalToken<Result: Sendable> {
    public let id = ModalID()

    private var resolved: Result?
    private var waiters: [CheckedContinuation<Result, Never>] = []

    public init() {}

    /// Suspends until resolved; returns the cached value immediately once resolved (replayable).
    public var result: Result {
        get async {
            if let resolved { return resolved }
            return await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    /// Called only by the renderer, exactly-once per token (extra calls are ignored).
    func resolve(_ value: Result) {
        guard resolved == nil else { return }
        resolved = value
        let pending = waiters
        waiters.removeAll()
        for continuation in pending { continuation.resume(returning: value) }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/ModalTokenTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/ModalToken.swift Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/ModalTokenTests.swift
git commit -m "feat(executor): ModalToken with resolve-once + async replay"
```

---

### Task 3: `ModalRenderer` + `UIKitModalRenderer` (registry, key window, resolve-once gate)

**Files:**
- Create: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/ModalRenderer.swift`
- Create: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/UIKitModalRenderer.swift`
- Modify: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/UIKitModalRenderer+Holder.swift` (remove the Task 1 forward stub)
- Test: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/UIKitModalRendererTests.swift`

**Interfaces:**
- Consumes: `AlertDialog`, `UIKitModalRenderer.AlertHolder.make(for:resolve:)`, `ModalID`, `GBAlertModal(properties:holder:)`, `GBAlertModal.show(parent:completion:)`, `GBAlertModal.hide()`, `GBAlertModal.updateDialog(holder:properties:)`, `GBAlertModal.dismissAndEmit(event:)`.
- Produces:
  - `@MainActor protocol ModalRenderer: AnyObject { func present<D: ModalDescriptor>(_:id:resolve:); func update<D: ModalDescriptor>(_ id:to:); func dismiss(_ id:) }`
  - `@MainActor final class UIKitModalRenderer: ModalRenderer` with `init(alertProperties:windowProvider:)`, `register<D>(_:factory:)`, `typealias Factory<D>`, and internal `live` for `@testable` assertions.

- [ ] **Step 1: Write the failing test**

```swift
// UIKitModalRendererTests.swift
import XCTest
import UIKit
@testable import GBV3AlertModal

@MainActor
final class UIKitModalRendererTests: XCTestCase {
    private func makeWindow() -> UIWindow {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.makeKeyAndVisible()
        return w
    }

    private func makeRenderer(window: UIWindow) -> UIKitModalRenderer {
        UIKitModalRenderer(alertProperties: GeniePresets.standardProperties(),
                           windowProvider: { window })
    }

    func test_present_addsModalToWindow() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()

        renderer.present(AlertDialog(title: "T", primary: "OK"), id: id) { _ in }

        XCTAssertTrue(window.subviews.contains { $0 is GBAlertModal })
        XCTAssertNotNil(renderer.live[id])
    }

    func test_dismiss_resolvesDismissed_andClearsRegistry() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()
        var received: AlertDialog.Result?

        renderer.present(AlertDialog(title: "T", primary: "OK"), id: id) { received = $0 }
        renderer.dismiss(id)

        XCTAssertEqual(received, .dismissed)
        XCTAssertNil(renderer.live[id])
    }

    func test_userAction_resolvesMappedResult_once() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()
        var received: [AlertDialog.Result] = []

        renderer.present(AlertDialog(title: "T", primary: "OK", secondary: "No"), id: id) {
            received.append($0)
        }
        let modal = renderer.live[id]?.modal
        modal?.dismissAndEmit(event: .primary) // simulate primary tap → routes through completion
        modal?.dismissAndEmit(event: .secondary) // gate already fired → ignored

        XCTAssertEqual(received, [.primary])
        XCTAssertNil(renderer.live[id])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/UIKitModalRendererTests`
Expected: FAIL to compile — `ModalRenderer` / `UIKitModalRenderer` members undefined.

- [ ] **Step 3: Remove the Task 1 forward stub**

In `UIKitModalRenderer+Holder.swift`, delete the line added in Task 1 Step 5:
`@MainActor public final class UIKitModalRenderer {}`
(The real class is defined in Step 5 below.)

- [ ] **Step 4: Write `ModalRenderer.swift`**

```swift
import UIKit

@MainActor
public protocol ModalRenderer: AnyObject {
    func present<D: ModalDescriptor>(_ descriptor: D, id: ModalID, resolve: @escaping (D.Result) -> Void)
    func update<D: ModalDescriptor>(_ id: ModalID, to descriptor: D)
    func dismiss(_ id: ModalID)
}
```

- [ ] **Step 5: Write `UIKitModalRenderer.swift`**

```swift
import UIKit

/// The ONLY place UIKit lives. Builds a `GBAlertModal` from a registered factory, shows it on a
/// window, and funnels every teardown path through one resolve-once gate. Overlap accepted.
@MainActor
public final class UIKitModalRenderer: ModalRenderer {
    /// Builds `(Properties?, DataHolder)` for a descriptor. `resolve` closes over the token gate.
    public typealias Factory<D: ModalDescriptor> =
        (D, @escaping (D.Result) -> Void) -> (GBAlertModal.Properties?, GBAlertModal.DataHolder)

    struct Live {
        let modal: GBAlertModal
        let resolveDismissed: () -> Void
        let rebuild: (Any) -> Void
    }

    var live: [ModalID: Live] = [:]           // internal for @testable assertions
    private var factories: [ObjectIdentifier: Any] = [:]
    private let windowProvider: () -> UIWindow?

    public init(
        alertProperties: GBAlertModal.Properties,
        windowProvider: @escaping () -> UIWindow? = { UIKitModalRenderer.keyWindow }
    ) {
        self.windowProvider = windowProvider
        register(AlertDialog.self) { descriptor, resolve in
            (alertProperties, AlertHolder.make(for: descriptor, resolve: resolve))
        }
    }

    /// Register a factory for a descriptor kind. Consumers add their own descriptors this way.
    public func register<D: ModalDescriptor>(_ type: D.Type, factory: @escaping Factory<D>) {
        factories[ObjectIdentifier(type)] = factory
    }

    public func present<D: ModalDescriptor>(
        _ descriptor: D, id: ModalID, resolve: @escaping (D.Result) -> Void
    ) {
        guard let factory = factories[ObjectIdentifier(D.self)] as? Factory<D> else {
            assertionFailure("No factory registered for \(D.self)")
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
        let modal = GBAlertModal(properties: properties, holder: holder)
        guard let window = windowProvider() else { return }
        modal.show(parent: window, completion: {})

        live[id] = Live(
            modal: modal,
            resolveDismissed: { gate(D.dismissedResult) },
            rebuild: { [weak self] anyDescriptor in
                guard let self, let next = anyDescriptor as? D else { return }
                let (p, h) = factory(next, gate)
                self.live[id]?.modal.updateDialog(holder: h, properties: p)
            }
        )
    }

    public func update<D: ModalDescriptor>(_ id: ModalID, to descriptor: D) {
        live[id]?.rebuild(descriptor)
    }

    public func dismiss(_ id: ModalID) {
        live[id]?.resolveDismissed()
    }

    private func teardown(_ id: ModalID) {
        guard let entry = live[id] else { return }
        if entry.modal.superview != nil { entry.modal.hide() }
        live[id] = nil
    }

    public static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/UIKitModalRendererTests`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor
git add Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/UIKitModalRendererTests.swift
git commit -m "feat(executor): UIKitModalRenderer with factory registry + resolve-once gate"
```

---

### Task 4: `ModalExecutor` + `DefaultModalExecutor` (present / update / dismiss / async)

**Files:**
- Create: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/ModalExecutor.swift`
- Test: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/ModalExecutorTests.swift`

**Interfaces:**
- Consumes: `ModalRenderer`, `UIKitModalRenderer`, `ModalToken`, `AlertDialog`.
- Produces:
  - `@MainActor protocol ModalExecutor { func present<D>(_:) -> ModalToken<D.Result>; func update<D>(_:to:); func dismiss<R>(_:) }`
  - extension `func present<D>(_:) async -> D.Result`
  - `@MainActor final class DefaultModalExecutor: ModalExecutor { init(renderer:) }`

- [ ] **Step 1: Write the failing test**

```swift
// ModalExecutorTests.swift
import XCTest
import UIKit
@testable import GBV3AlertModal

@MainActor
final class ModalExecutorTests: XCTestCase {
    private func makeExecutor() -> (DefaultModalExecutor, UIKitModalRenderer) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        let renderer = UIKitModalRenderer(alertProperties: GeniePresets.standardProperties(),
                                          windowProvider: { window })
        return (DefaultModalExecutor(renderer: renderer), renderer)
    }

    func test_present_thenDismiss_resolvesDismissed() async {
        let (executor, _) = makeExecutor()
        let token = executor.present(AlertDialog(title: "T", primary: "OK"))
        executor.dismiss(token)
        let result = await token.result
        XCTAssertEqual(result, .dismissed)
    }

    func test_present_userTap_resolvesPrimary() async {
        let (executor, renderer) = makeExecutor()
        let token = executor.present(AlertDialog(title: "T", primary: "OK"))
        renderer.live[token.id]?.modal.dismissAndEmit(event: .primary)
        let result = await token.result
        XCTAssertEqual(result, .primary)
    }

    func test_asyncConvenience_returnsResult() async {
        let (executor, renderer) = makeExecutor()
        // Kick off the await, then drive the tap once the modal is live.
        async let result = executor.present(AlertDialog(title: "T", primary: "OK"))
        await Task.yield()
        // The convenience presented via the same renderer; grab the single live modal.
        renderer.live.values.first?.modal.dismissAndEmit(event: .primary)
        let value = await result
        XCTAssertEqual(value, .primary)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/ModalExecutorTests`
Expected: FAIL to compile — `ModalExecutor` / `DefaultModalExecutor` undefined.

- [ ] **Step 3: Write `ModalExecutor.swift`**

```swift
import UIKit

/// The VM-facing front door. Pure descriptors in; a token out. No UIKit types cross this API.
@MainActor
public protocol ModalExecutor {
    @discardableResult
    func present<D: ModalDescriptor>(_ descriptor: D) -> ModalToken<D.Result>
    func update<D: ModalDescriptor>(_ token: ModalToken<D.Result>, to descriptor: D)
    func dismiss<R>(_ token: ModalToken<R>)
}

public extension ModalExecutor {
    /// One-line show-and-wait for simple/input dialogs. `.result` disambiguates the overload.
    func present<D: ModalDescriptor>(_ descriptor: D) async -> D.Result {
        await present(descriptor).result
    }
}

@MainActor
public final class DefaultModalExecutor: ModalExecutor {
    private let renderer: ModalRenderer
    public init(renderer: ModalRenderer) { self.renderer = renderer }

    @discardableResult
    public func present<D: ModalDescriptor>(_ descriptor: D) -> ModalToken<D.Result> {
        let token = ModalToken<D.Result>()
        renderer.present(descriptor, id: token.id) { [weak token] result in
            token?.resolve(result)
        }
        return token
    }

    public func update<D: ModalDescriptor>(_ token: ModalToken<D.Result>, to descriptor: D) {
        renderer.update(token.id, to: descriptor)
    }

    public func dismiss<R>(_ token: ModalToken<R>) {
        renderer.dismiss(token.id)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/ModalExecutorTests`
Expected: PASS (3 tests). If Swift reports the async/sync `present` overload as ambiguous at any call site, rename the async convenience to `presentAndWait` and update the test — see the estimate note (§A).

- [ ] **Step 5: Commit**

```bash
git add Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/ModalExecutor.swift Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/ModalExecutorTests.swift
git commit -m "feat(executor): ModalExecutor + DefaultModalExecutor with async convenience"
```

---

### Task 5: Stateful `update` end-to-end + a custom registered descriptor (capability demo)

**Files:**
- Test: `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/ExecutorStatefulTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–4, plus `GBAlertModal.lbTitle` (public getter) to assert a re-render.
- Produces: nothing new in `Sources/` — this task proves `update(token,to:)` re-renders the same instance, and that a consumer can `register` its own descriptor kind (a stateful one) without editing the library.

- [ ] **Step 1: Write the failing test**

```swift
// ExecutorStatefulTests.swift
import XCTest
import UIKit
@testable import GBV3AlertModal

/// A consumer-defined STATEFUL descriptor, registered from outside the library — proves the
/// extension mechanism and the `update(token,to:)` re-render path (the Gc2Gs shape, minus app UI).
private struct StepDialog: ModalDescriptor {
    enum Result: Sendable, Equatable { case done, dismissed }
    static var dismissedResult: Result { .dismissed }
    var title: String
}

@MainActor
final class ExecutorStatefulTests: XCTestCase {
    private func makeStack() -> (DefaultModalExecutor, UIKitModalRenderer) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        let renderer = UIKitModalRenderer(alertProperties: GeniePresets.standardProperties(),
                                          windowProvider: { window })
        renderer.register(StepDialog.self) { descriptor, resolve in
            let holder = GBAlertModal.DataHolder(
                title: descriptor.title,
                primaryAction: "Next",
                dismissOnAction: false,
                completion: { _, action in
                    resolve(action == .primary ? .done : .dismissed)
                }
            )
            return (GeniePresets.standardProperties(), holder)
        }
        return (DefaultModalExecutor(renderer: renderer), renderer)
    }

    func test_update_reRendersSameInstance_withNewContent() {
        let (executor, renderer) = makeStack()
        let token = executor.present(StepDialog(title: "Step 1"))
        let modalBefore = renderer.live[token.id]?.modal
        XCTAssertEqual(modalBefore?.lbTitle?.text, "Step 1")

        executor.update(token, to: StepDialog(title: "Step 2"))

        let modalAfter = renderer.live[token.id]?.modal
        XCTAssertTrue(modalBefore === modalAfter)          // same instance, not swapped
        XCTAssertEqual(modalAfter?.lbTitle?.text, "Step 2") // re-rendered
    }

    func test_statefulDialog_resolvesOnce_afterUpdates() async {
        let (executor, renderer) = makeStack()
        let token = executor.present(StepDialog(title: "Step 1"))
        executor.update(token, to: StepDialog(title: "Step 2"))
        renderer.live[token.id]?.modal.dismissAndEmit(event: .primary)
        let result = await token.result
        XCTAssertEqual(result, .done)
        XCTAssertNil(renderer.live[token.id]) // torn down + registry cleared
    }
}
```

- [ ] **Step 2: Run test to verify it fails, then passes**

Run: `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalTests/ExecutorStatefulTests`
Expected: initially FAIL only if a regression exists in Tasks 3–4; otherwise PASS (2 tests) — this task adds no `Sources/` code, it verifies the `update` + `register` capability built earlier. If `lbTitle` is not populated synchronously, add `renderer.live[token.id]?.modal.layoutIfNeeded()` before the assertion.

- [ ] **Step 3: Commit**

```bash
git add Library/GBV3AlertModal/Tests/GBV3AlertModalTests/Executor/ExecutorStatefulTests.swift
git commit -m "test(executor): stateful update re-render + consumer-registered descriptor"
```

---

## Self-Review

**Spec coverage (against the estimate §5 “THIS project — the capability”):**
- Phase 1 (seam: descriptor/token/executor/renderer, `@MainActor`/`Sendable`) → Tasks 1–4. ✓
- Phase 2 (`UIKitRenderer` key-window + `windowProvider` + registry + resolve-once gate + `AlertDialog` + `present async`) → Tasks 3–4. ✓
- Phase 3 (extension mechanism: consumer registers descriptor kinds) → `register(_:factory:)` in Task 3, exercised by a consumer descriptor in Task 5. ✓
- Phase 4 (`update(token,to:)` stateful + `dismissOnAction:false` resolve-once) → Task 3 (`update`/gate) + Task 5 (end-to-end). ✓
- Phase 5 (demonstrate + test one per kind; Layer-A-style tests, no new snapshots) → fire-and-forget/await (Tasks 3–4), stateful (Task 5), mapping-equivalence via Layer-A resolver (Task 1). ✓
- **Deliberately deferred (documented in the estimate, NOT this plan):** `PopupDialog` (trivial second descriptor), `presentRaw{UIView}` escape hatch (migration-only), Rx `Single` adapter (app-side, optional), coordinator/queue, SwiftUI renderer. Building them now is YAGNI for the capability.

**Placeholder scan:** none — every code and test step contains complete, compiling source.

**Type consistency:** `ModalDescriptor.dismissedResult`, `AlertDialog.Result{primary,secondary,dismissed}`, `ModalToken<Result>.result`/`resolve`, `UIKitModalRenderer.Factory<D> = (D, @escaping (D.Result)->Void) -> (Properties?, DataHolder)`, `AlertHolder.make(for:resolve:)`, `ModalExecutor.present/update/dismiss`, `ModalID` — names match across Tasks 1–5. The Task 1 forward stub for `UIKitModalRenderer` is created in Task 1 Step 5 and removed in Task 3 Step 3.

**Scope guardrail:** every file path is under `Library/GBV3AlertModal/Sources/` or `Library/GBV3AlertModal/Tests/`. No distribution-app or Example file is modified. `AlertDialog` is wired to no real call site.
