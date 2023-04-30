import Foundation
import UIKit
import SnapKit

public extension GBAlertModal {
    enum ActionStyle {
        case capsule(CapsuleTheme)
        case capsuleOutlined(CapsuleOutlineTheme)
        case plain(PlainTheme)
        case obliqueBottomLeft(ObliqueBottomLeftTheme)
    }
}

public extension GBAlertModal.ActionStyle {
    struct CapsuleTheme {
        public var backgroundColor: UIColor?
        public var titleColor: UIColor?
        public var titleFont: UIFont?

        public init(
                backgroundColor: UIColor? = nil,
                titleColor: UIColor? = nil,
                titleFont: UIFont? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.titleColor = titleColor
            self.titleFont = titleFont
        }
    }

    struct CapsuleOutlineTheme {
        public var backgroundColor: UIColor?
        public var titleColor: UIColor?
        public var borderWidth: CGFloat?
        public var borderColor: CGColor?
        public var titleFont: UIFont?

        public init(
                backgroundColor: UIColor? = nil,
                titleColor: UIColor? = nil,
                borderWidth: CGFloat? = nil,
                borderColor: CGColor? = nil,
                titleFont: UIFont? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.titleColor = titleColor
            self.borderWidth = borderWidth
            self.borderColor = borderColor
            self.titleFont = titleFont
        }
    }

    struct PlainTheme {
        public var titleColor: UIColor?
        public var titleFont: UIFont?

        public init(
                titleColor: UIColor? = nil,
                titleFont: UIFont? = nil
        ) {
            self.titleColor = titleColor
            self.titleFont = titleFont
        }
    }

    struct ObliqueBottomLeftTheme {
        public var unPressedColor: UIColor?
        public var pressedColor: UIColor?
        public var shadowColor: CGColor?
        public var titleColor: UIColor?
        public var titleFont: UIFont?

        public init(
                unPressedColor: UIColor? = nil,
                pressedColor: UIColor? = nil,
                shadowColor: CGColor? = nil,
                titleColor: UIColor? = nil,
                titleFont: UIFont? = nil
        ) {
            self.unPressedColor = unPressedColor
            self.pressedColor = pressedColor
            self.shadowColor = shadowColor
            self.titleColor = titleColor
            self.titleFont = titleFont
        }
    }
}

internal extension GBAlertModal {
    func configureButtonActionStyle(_ button: UIButton, title: String, style: ActionStyle) {
        button.setTitle(title, for: .normal)
        switch style {
        case .capsule(let style):
            button.layer.borderWidth = 0.0
            button.layer.borderColor = nil
            button.backgroundColor = style.backgroundColor
            button.setTitleColor(style.titleColor, for: .normal)
            button.setImage(nil, for: .normal)
            button.titleLabel?.font = style.titleFont
        case .capsuleOutlined(let style):
            button.layer.borderWidth = style.borderWidth ?? 0
            button.layer.borderColor = style.borderColor
            button.backgroundColor = style.backgroundColor
            button.setTitleColor(style.titleColor, for: .normal)
            button.setImage(nil, for: .normal)
            button.titleLabel?.font = style.titleFont
        case .plain(let style):
            button.setTitleColor(style.titleColor, for: .normal)
            button.titleLabel?.font = style.titleFont
        case .obliqueBottomLeft(let style):
            button.backgroundColor = style.unPressedColor
            button.setTitleColor(style.titleColor, for: .normal)
            button.titleLabel?.font = style.titleFont
            updateObliqueBottomLeftStyleUnPressed(button, style: style)
        }
    }

    func configureButtonActionConstraint(_ button: UIButton, parent: UIView, style: ActionStyle) {
        switch style {
        case .capsule,
             .capsuleOutlined:
            button.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                // Align
                make.edges
                        .equalToSuperview()
            }

            parent.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                // Pin
                make.height
                        .equalTo(48)
            }
        case .plain:
            button.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                // Align
                make.top
                        .equalToSuperview()
                make.leading
                        .greaterThanOrEqualToSuperview()

                make.center
                        .equalToSuperview()
            }

            parent.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                // Pin
                make.height
                        .equalTo(48)
            }
        case .obliqueBottomLeft:
            button.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                // Align
                make.top
                        .equalToSuperview()
                        .offset(-3)
                make.leading
                        .equalToSuperview()
                        .offset(3)
                make.bottom
                        .equalToSuperview()
                        .offset(-3)
                make.trailing
                        .equalToSuperview()
                        .offset(3)
            }

            parent.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                // Pin
                make.height
                        .equalTo(48)
            }
        }
    }
}

internal extension GBAlertModal {
    func generateButtonForActionDesign(style: ActionStyle) -> UIButton {
        switch style {
        case .capsule,
             .capsuleOutlined:
            return generateButtonForCapsuleThemedDesign()
        case .plain:
            return generateButtonForPlainThemedDesign()
        case .obliqueBottomLeft:
            return generateButtonForObliqueThemedDesign()
        }
    }

    func generateButtonForCapsuleThemedDesign() -> GBRoundedButton {
        let view = GBRoundedButton(type: .system)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.rounded = true
        view.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        view.titleLabel?.minimumScaleFactor = 0.5
        view.titleLabel?.adjustsFontSizeToFitWidth = true
        return view
    }

    func generateButtonForPlainThemedDesign() -> UIButton {
        let view = UIButton(type: .system)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        view.titleLabel?.minimumScaleFactor = 0.5
        view.titleLabel?.adjustsFontSizeToFitWidth = true
        return view
    }

    func generateButtonForObliqueThemedDesign() -> UIButton {
        let view = UIButton(type: .custom)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 8
        view.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        view.titleLabel?.minimumScaleFactor = 0.5
        view.titleLabel?.adjustsFontSizeToFitWidth = true
        return view
    }
}
