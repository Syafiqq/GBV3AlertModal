import GBV3AlertModalCore

//
// Created by engineering on 27/4/23.
//

import UIKit

extension UIStackView {
    // MARK: Manipulate Subview
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach {
            removeArrangedSubViewProperly($0)
        }
    }

    @discardableResult
    func removeArrangedSubViewProperly(_ view: UIView) -> UIView {
        removeArrangedSubview(view)
        NSLayoutConstraint.deactivate(view.constraints)
        view.removeFromSuperview()
        return view
    }
}
