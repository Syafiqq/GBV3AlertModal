import UIKit
@testable import GBV3AlertModal

/// Renders `modal` into a fixed-size host and forces a full layout pass so it can be
/// captured deterministically with `assertSnapshot`.
///
/// `GBAlertModal` derives `isLandscape` from its own `bounds` (`bounds.width > bounds.height`)
/// while computing its content width, so hosting inside a real, key `UIWindow` sized to
/// `size` is what drives that branch deterministically — the modal is pinned to its parent's
/// edges, so its bounds after layout match the host size passed in here.
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
