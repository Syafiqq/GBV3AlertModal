import Foundation
import UIKit
import SnapKit

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

    func generateButtonForActionDesign(type: ActionStyle) -> UIButton {
        fatalError("not yet implemented")
    }
}
