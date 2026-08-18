import GBV3AlertModalCore

import UIKit

class GBRoundedButton: UIButton {
    @IBInspectable var rounded: Bool = false {
        didSet {
            updateCornerRadius()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateCornerRadius()
    }

    func updateCornerRadius() {
        layer.cornerRadius = rounded ? frame.size.height / 2 : 0
    }
}
