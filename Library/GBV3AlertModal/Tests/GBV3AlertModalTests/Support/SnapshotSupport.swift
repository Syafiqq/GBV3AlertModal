import UIKit
@testable import GBV3AlertModal

/// The host window from the previous `renderForSnapshot` call, retained only so it can be
/// torn down on the next call.
///
/// Creating `UIWindow(windowScene:)` registers the window in `scene.windows`, which retains
/// it for the scene's lifetime — `makeKeyAndVisible` only changes *which* window is key, it
/// does not release the others. Left alone, every render leaks a window (and its modal, and
/// that modal's keyboard observers) for the whole test process; across ~160 tests this
/// exhausts resources and the test runner crashes mid-suite at a nondeterministic point.
/// Detaching the previous window from its scene (`windowScene = nil`) removes it from
/// `scene.windows` so it — and everything it holds — can deallocate, keeping the live host
/// window count at ~1.
private var previousSnapshotHostWindow: UIWindow?

/// Renders `modal` into a fixed-size host and forces a full layout pass so it can be
/// captured deterministically with `assertSnapshot`.
///
/// `GBAlertModal` derives `isLandscape` from its own `bounds` (`bounds.width > bounds.height`)
/// while computing its content width, so hosting inside a real, key `UIWindow` sized to
/// `size` is what drives that branch deterministically — the modal is pinned to its parent's
/// edges, so its bounds after layout match the host size passed in here.
@discardableResult
func renderForSnapshot(_ modal: GBAlertModal, size: CGSize) -> UIView {
    // Tear down the previous render's host so windows don't accumulate in `scene.windows`.
    if let previous = previousSnapshotHostWindow {
        previous.isHidden = true
        previous.rootViewController = nil
        previous.subviews.forEach { $0.removeFromSuperview() }
        previous.windowScene = nil
    }

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
    return window
}
