import Foundation
import UIKit
import SnapKit

public extension GBAlertModal {
    enum ActionStyle {
    }
}

public extension GBAlertModal.ActionStyle {
}

internal extension GBAlertModal {
    func configureButtonActionStyle(_ button: UIButton, title: String, style: ActionStyle) {
    }

    func configureButtonActionConstraint(_ button: UIButton, parent: UIView, style: ActionStyle) {
    }
}

internal extension GBAlertModal {
    func generateButtonForActionDesign(style: ActionStyle) -> UIButton {
        fatalError("not yet implemented")
    }
}
