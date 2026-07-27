import UIKit

/// A `UIButton` that reproduces the (iOS-15-deprecated) `contentEdgeInsets` behaviour without the
/// deprecated API and without adopting `UIButton.Configuration` (which would take over the whole
/// legacy title/colour/background styling). It insets the content rect and grows the intrinsic size
/// by the same amount — so the title's available width (and therefore `adjustsFontSizeToFitWidth`
/// auto-shrink) matches the old `contentEdgeInsets` exactly. Pixel-identical to the prior behaviour.
class InsetButton: UIButton {
    var contentInsets: UIEdgeInsets = .zero {
        didSet { invalidateIntrinsicContentSize() }
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(
            width: base.width + contentInsets.left + contentInsets.right,
            height: base.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func contentRect(forBounds bounds: CGRect) -> CGRect {
        super.contentRect(forBounds: bounds).inset(by: contentInsets)
    }
}

class GBRoundedButton: InsetButton {
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
