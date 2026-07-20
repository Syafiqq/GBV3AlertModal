import Foundation
import UIKit

// MARK: - CALLBACK

extension GBAlertModal {
    @objc
    func onOverlayTapped(_ sender: UITapGestureRecognizer) {
        guard dataHolder?.closeOnTapOverlay == true else {
            return
        }

        switch sender.state {
        case .ended:
            dismissAndEmit(event: .close)
        default:
            break
        }
    }

    @objc
    func onPrimaryActionTapped() {
        dismissAndEmit(event: .primary)
    }

    @objc
    func onSecondaryActionTapped() {
        dismissAndEmit(event: .secondary)
    }

    @objc
    func onActionButtonPressed(_ sender: UIButton) {
        if sender === btPrimaryAction,
           let primaryActionStyle = properties?.primaryActionStyle,
           case ActionStyle.obliqueBottomLeft(let style) = primaryActionStyle {
            updateObliqueBottomLeftStylePressed(sender, style: style)
        } else if sender === btSecondaryAction,
                  let secondaryActionStyle = properties?.secondaryActionStyle,
                  case ActionStyle.obliqueBottomLeft(let style) = secondaryActionStyle {
            updateObliqueBottomLeftStylePressed(sender, style: style)
        }
    }

    @objc
    func onActionButtonUnPressed(_ sender: UIButton) {
        if sender === btPrimaryAction,
           let primaryActionStyle = properties?.primaryActionStyle,
           case ActionStyle.obliqueBottomLeft(let style) = primaryActionStyle {
            updateObliqueBottomLeftStyleUnPressed(sender, style: style)
        } else if sender === btSecondaryAction,
                  let secondaryActionStyle = properties?.secondaryActionStyle,
                  case ActionStyle.obliqueBottomLeft(let style) = secondaryActionStyle {
            updateObliqueBottomLeftStyleUnPressed(sender, style: style)
        }
    }

    @objc
    func onCloseTapped() {
        dismissAndEmit(event: .close)
    }
}
