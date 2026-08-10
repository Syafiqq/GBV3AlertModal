import XCTest
import UIKit
@testable import GBV3AlertModal

/// The host window from the most recent `renderForSnapshot` call, retained only so it can be
/// torn down again.
///
/// Creating `UIWindow(windowScene:)` registers the window in `scene.windows`, which retains
/// it for the scene's lifetime — `makeKeyAndVisible` only changes *which* window is key, it
/// does not release the others. Left alone, every render leaks a window (and its modal, and
/// that modal's keyboard observers). Detaching the window from its scene (`windowScene = nil`)
/// removes it from `scene.windows` so it — and everything it holds — can deallocate.
///
/// CRITICAL: this host must not survive past the test that created it. It used to be torn down
/// only lazily, on the *next* `renderForSnapshot` call, which let one window persist across the
/// test-method boundary. Once `@MainActor async` tests were added to the target, the Swift
/// concurrency runtime that XCTest spins up drains autorelease pools / the run loop at points
/// the old lifecycle didn't expect: the window a previous test left retained here got torn down
/// into a zombie, and the next synchronous `renderForSnapshot` crashed (SIGSEGV / EXC_BAD_ACCESS)
/// the moment it touched `previous.isHidden`. Tearing the host down in an `addTeardownBlock`
/// after every render (below) guarantees this is `nil` across every test boundary, so no stale
/// UIKit object is ever dereferenced by a later test.
// nonisolated(unsafe): only ever touched on the main thread (see the note above — XCTest test
// bodies and teardown blocks both run on main), so there is no real race to guard.
nonisolated(unsafe) private var previousSnapshotHostWindow: UIWindow?

/// Detaches the retained host window from its scene and releases every strong path into it, so
/// no UIKit object survives the test that created it. Idempotent and safe to call when nothing
/// is retained. Runs on the main thread (XCTest teardown blocks and test bodies both do).
// @MainActor: mutates `UIWindow` properties (`isHidden`, `rootViewController`, `subviews`,
// `windowScene`), which are @MainActor-isolated under Swift 6 — matches the doc comment above
// (already true at runtime; now also true at compile time).
@MainActor
func tearDownSnapshotHost() {
    guard let window = previousSnapshotHostWindow else { return }
    window.isHidden = true
    window.rootViewController = nil
    window.subviews.forEach { $0.removeFromSuperview() }
    window.windowScene = nil
    previousSnapshotHostWindow = nil
}

extension XCTestCase {
    /// Renders `modal` into a fixed-size host and forces a full layout pass so it can be
    /// captured deterministically with `assertSnapshot`.
    ///
    /// `GBAlertModal` derives `isLandscape` from its own `bounds` (`bounds.width > bounds.height`)
    /// while computing its content width, so hosting inside a real, key `UIWindow` sized to
    /// `size` is what drives that branch deterministically — the modal is pinned to its parent's
    /// edges, so its bounds after layout match the host size passed in here.
    // @MainActor: builds/renders a real `UIWindow` and the @MainActor `GBAlertModal`, so this
    // helper must run on the main actor under Swift 6 — every caller is (or becomes) @MainActor.
    @MainActor
    @discardableResult
    func renderForSnapshot(_ modal: GBAlertModal, size: CGSize) -> UIView {
        // Tear down any host still retained from an earlier render (e.g. an earlier render in
        // this same test) before creating a new one, so windows don't accumulate.
        tearDownSnapshotHost()

        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: .zero)
        }
        window.frame = CGRect(origin: .zero, size: size)
        window.backgroundColor = .white
        window.isHidden = false
        window.makeKeyAndVisible()

        modal.show(parent: window, completion: {})

        window.setNeedsLayout()
        window.layoutIfNeeded()

        previousSnapshotHostWindow = window
        // Release the host at the end of THIS test so it never crosses a test boundary — in
        // particular the boundary with the target's `@MainActor async` tests, which is what
        // turned the previously long-lived host into a use-after-free.
        addTeardownBlock { tearDownSnapshotHost() }
        return window
    }
}
