import UIKit
@testable import GBV3AlertModal

/// Renders `modal` into a fixed-size host and forces a full layout pass so it can be
/// captured deterministically with `assertSnapshot`.
///
/// `GBAlertModal` reads `UIWindow.isLandscape` (via `UIApplication.shared.windows.first?.windowScene`)
/// while computing its content width, so the modal is hosted inside a real, key `UIWindow`
/// attached to the active `UIWindowScene` rather than a detached plain `UIView`. This keeps
/// `layoutSubviews()` / `adjustSvContentContainerConstraintWidth` deterministic across runs.
@discardableResult
func renderForSnapshot(_ modal: GBAlertModal, size: CGSize) -> UIView {
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

    return window
}
