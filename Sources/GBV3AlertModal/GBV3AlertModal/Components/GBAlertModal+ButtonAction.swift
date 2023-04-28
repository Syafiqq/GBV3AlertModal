import Foundation
import UIKit
import SnapKit

public extension GBAlertModal {
    enum ActionStyle {
        case capsule(CapsuleThemedAction)
        case outline(OutlineThemedAction)
        case dimension3(SpaceThemedAction)
        case spaceThemeOutline
    }
}

public extension GBAlertModal.ActionStyle {
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

    struct OutlineThemedAction {
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
    func configureButtonActionConstraint(_ button: UIButton, parent: UIView, style: ActionStyle) {
        switch style {
        case .capsule,
             .outline:
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
        case .dimension3:
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
        case .outline(let style):
            button.layer.borderWidth = style.borderWidth ?? 0
            button.layer.borderColor = style.borderColor
            button.backgroundColor = style.backgroundColor
            button.setTitleColor(style.titleColor, for: .normal)
            button.setImage(nil, for: .normal)
            button.titleLabel?.font = style.titleFont
        case .dimension3(let style):
            button.backgroundColor = style.unPressedColor
            button.setTitleColor(style.titleColor, for: .normal)
            button.titleLabel?.font = style.titleFont
            updateSpaceThemedButtonStyleUnPressed(button, style: style)
        case .spaceThemeOutline:
            break
        }
    }

    func updateSpaceThemedButtonStylePressed(_ button: UIButton, style: ActionStyle.SpaceThemedAction) {
        UIView.animate(
                withDuration: 0.1,
                delay: 0,
                options: UIView.AnimationOptions.curveEaseIn,
                animations: { [weak self] in
                    guard self != nil else {
                        return
                    }
                    button.backgroundColor = style.pressedColor
                    button.transform = .identity.translatedBy(x: -3, y: 3)
                    button.layer.removeSketchShadow()
                },
                completion: { _ in }
        )
    }

    func updateSpaceThemedButtonStyleUnPressed(_ button: UIButton, style: ActionStyle.SpaceThemedAction) {
        UIView.animate(
                withDuration: 0.1,
                delay: 0,
                options: UIView.AnimationOptions.curveEaseOut,
                animations: { [weak self] in
                    guard self != nil else {
                        return
                    }
                    button.backgroundColor = style.unPressedColor
                    button.transform = .identity
                    button.layer.applySketchShadow(
                            color: style.shadowColor,
                            alpha: 1.0,
                            x: -3.0,
                            y: 3.0,
                            blur: 0.0
                    )
                },
                completion: { _ in }
        )
    }
}

internal extension GBAlertModal {
    func generateButtonForActionDesign(style: ActionStyle) -> UIButton {
        switch style {
        case .capsule,
             .outline:
            return generateButtonForCapsuleThemedDesign()
        case .dimension3:
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
