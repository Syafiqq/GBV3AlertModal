import Foundation
import UIKit
import SnapKit

internal extension GBAlertModal {
    func configureButtonActionStyle(_ button: UIButton, title: String, style: ActionStyle) {
        button.setTitle(title, for: .normal)
        configureButtonActionStyle(button, style: style)
    }

    func configureButtonActionStyle(_ button: UIButton, style: ActionStyle) {
        switch style {
        case .capsule(let style):
            button.layer.borderWidth = 0.0
            button.layer.borderColor = nil
            button.setImage(nil, for: .normal)
            button.titleLabel?.font = style.titleFont
            if button.isEnabled {
                button.backgroundColor = style.backgroundColor
                button.setTitleColor(style.titleColor, for: .normal)
            } else {
                button.backgroundColor = style.backgroundDisableColor
                button.setTitleColor(style.titleDisableColor, for: .normal)
            }
        case .capsuleOutlined(let style):
            button.layer.borderWidth = style.borderWidth ?? 0
            button.setImage(nil, for: .normal)
            button.titleLabel?.font = style.titleFont
            if button.isEnabled {
                button.backgroundColor = style.backgroundColor
                button.setTitleColor(style.titleColor, for: .normal)
                button.layer.borderColor = style.borderColor
            } else {
                button.backgroundColor = style.backgroundDisableColor
                button.setTitleColor(style.titleDisableColor, for: .normal)
                button.layer.borderColor = style.borderDisableColor
            }
        case .plain(let style):
            button.titleLabel?.font = style.titleFont
            if button.isEnabled {
                button.setTitleColor(style.titleColor, for: .normal)
            } else {
                button.setTitleColor(style.titleDisableColor, for: .normal)
            }
        case .obliqueBottomLeft(let style):
            button.titleLabel?.font = style.titleFont
            if button.isEnabled {
                button.backgroundColor = style.unPressedColor
                button.setTitleColor(style.titleColor, for: .normal)
                updateObliqueBottomLeftStyleUnPressed(button, style: style)
            } else {
                button.backgroundColor = style.disabledColor
                button.setTitleColor(style.titleDisableColor, for: .normal)
                updateObliqueBottomLeftStyleDisabled(button, style: style)
            }
        }
    }

    func configureButtonActionConstraint(_ button: UIButton, parent: UIView, style: ActionStyle) {
        switch style {
        case .capsule,
             .capsuleOutlined:
            button.snp.makeConstraints { (make: ConstraintMaker) in
                // Align
                make.edges
                        .equalToSuperview()
            }

            parent.snp.makeConstraints { (make: ConstraintMaker) in
                // Pin
                make.height
                        .equalTo(48)
                        .priority(ModalLayout.Priority.buttonSlotHeight)
            }
        case .plain:
            button.snp.makeConstraints { (make: ConstraintMaker) in
                // Align
                make.top
                        .equalToSuperview()
                make.leading
                        .greaterThanOrEqualToSuperview()

                make.center
                        .equalToSuperview()
            }

            parent.snp.makeConstraints { (make: ConstraintMaker) in
                // Pin
                make.height
                        .equalTo(48)
                        .priority(ModalLayout.Priority.buttonSlotHeight)
            }
        case .obliqueBottomLeft:
            button.snp.makeConstraints { (make: ConstraintMaker) in
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

            parent.snp.makeConstraints { (make: ConstraintMaker) in
                // Pin
                make.height
                        .equalTo(48)
                        .priority(ModalLayout.Priority.buttonSlotHeight)
            }
        }
    }

    func updateObliqueBottomLeftStylePressed(_ button: UIButton, style: ActionStyle.ObliqueBottomLeftTheme) {
        guard button.isEnabled else {
            updateObliqueBottomLeftStyleDisabled(button, style: style)
            return
        }
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

    func updateObliqueBottomLeftStyleUnPressed(_ button: UIButton, style: ActionStyle.ObliqueBottomLeftTheme) {
        guard button.isEnabled else {
            updateObliqueBottomLeftStyleDisabled(button, style: style)
            return
        }
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

    func updateObliqueBottomLeftStyleDisabled(_ button: UIButton, style: ActionStyle.ObliqueBottomLeftTheme) {
        UIView.animate(
                withDuration: 0.1,
                delay: 0,
                options: UIView.AnimationOptions.curveEaseIn,
                animations: { [weak self] in
                    guard self != nil else {
                        return
                    }
                    button.backgroundColor = style.disabledColor
                    button.transform = .identity.translatedBy(x: -3, y: 3)
                    button.layer.removeSketchShadow()
                },
                completion: { _ in }
        )
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
