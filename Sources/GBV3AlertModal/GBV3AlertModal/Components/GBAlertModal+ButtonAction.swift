import Foundation
import UIKit
import SnapKit

public extension GBAlertModal {
    enum ActionStyle {
        case spaceTheme
        case spaceThemeOutline
        case capsule
        case capsuleOutline
    }
}

internal extension GBAlertModal {
    func configureButtonActionConstraint(_ action: UIButton, parent: UIView, style: ActionStyle) {
        switch style {
        case .capsule,
             .capsuleOutline:
            break
        case .spaceTheme:
            break
        case .spaceThemeOutline:
            break
        }
    }

    func configureButtonActionStyle(_ action: UIButton, title: String, style: ActionStyle) {
        switch style {
        case .capsule,
             .capsuleOutline:
            break
        case .spaceTheme:
            break
        case .spaceThemeOutline:
            break
        }
    }
}

internal extension GBAlertModal {
    func generateButtonForActionDesign(type: ActionStyle) -> UIButton {
        fatalError("not yet implemented")
    }

    func generateButtonForCapsuleThemedDesign() -> GBRoundedButton {
        let view = GBRoundedButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.rounded = true
        view.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        view.titleLabel?.minimumScaleFactor = 0.5
        view.titleLabel?.adjustsFontSizeToFitWidth = true
        return view
    }
}
