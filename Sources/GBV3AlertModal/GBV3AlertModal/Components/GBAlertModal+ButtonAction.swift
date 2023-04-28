import Foundation
import UIKit
import SnapKit

public extension GBAlertModal {
    enum ActionStyle {
        case capsule(CapsuleThemedAction)
        case capsuleOutline(CapsuleOutlineThemedAction)
        case spaceTheme(SpaceThemedAction)
        case spaceThemeOutline
    }

    struct CapsuleThemedAction {
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

    struct CapsuleOutlineThemedAction {
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

    struct SpaceThemedAction {
        public var backgroundColor: UIColor?
        public var shadowColor: CGColor?
        public var titleColor: UIColor?
        public var titleFont: UIFont?

        public init(
                backgroundColor: UIColor? = nil,
                shadowColor: CGColor? = nil,
                titleColor: UIColor? = nil,
                titleFont: UIFont? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.shadowColor = shadowColor
            self.titleColor = titleColor
            self.titleFont = titleFont
        }
    }
}

internal extension GBAlertModal {
    func configureButtonActionConstraint(_ button: UIButton, parent: UIView, style: ActionStyle) {
        switch style {
        case .capsule,
             .capsuleOutline:
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
        case .spaceTheme:
            button.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                // Align
                make.top
                        .equalToSuperview()
                make.leading
                        .equalToSuperview()
                make.bottom
                        .equalToSuperview()
                make.trailing
                        .equalToSuperview()
            }

            parent.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                // Pin
                make.height
                        .equalTo(48)
            }
        case .spaceThemeOutline:
            break
        }
    }

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
        case .capsuleOutline(let style):
            button.layer.borderWidth = style.borderWidth ?? 0
            button.layer.borderColor = style.borderColor
            button.backgroundColor = style.backgroundColor
            button.setTitleColor(style.titleColor, for: .normal)
            button.setImage(nil, for: .normal)
            button.titleLabel?.font = style.titleFont
        case .spaceTheme(let style):
            button.backgroundColor = style.backgroundColor
            button.setTitleColor(style.titleColor, for: .normal)
            button.titleLabel?.font = style.titleFont
            button.layer.applySketchShadow(
                    color: style.shadowColor,
                    alpha: 1.0,
                    x: -2.0,
                    y: 3.0,
                    blur: 0.0
            )
        case .spaceThemeOutline:
            break
        }
    }
}

internal extension GBAlertModal {
    func generateButtonForActionDesign(style: ActionStyle) -> UIButton {
        switch style {
        case .capsule,
             .capsuleOutline:
            return generateButtonForCapsuleThemedDesign()
        case .spaceTheme:
            return generateButtonForSpaceThemedDesign()
        case .spaceThemeOutline:
            return generateButtonForCapsuleThemedDesign()
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

    func generateButtonForSpaceThemedDesign() -> UIButton {
        let view = UIButton(type: .custom)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 8
        view.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        view.titleLabel?.minimumScaleFactor = 0.5
        view.titleLabel?.adjustsFontSizeToFitWidth = true
        return view
    }
}
