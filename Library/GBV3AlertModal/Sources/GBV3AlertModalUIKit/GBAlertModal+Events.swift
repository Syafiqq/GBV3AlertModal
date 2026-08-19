import GBV3AlertModalCore

import Foundation
import UIKit

// MARK: - EVENTS

extension GBAlertModal {
    // MARK: ViewModel
    func registerEvents() {
        // Gestures
        let tapRecognizerOverlay = UITapGestureRecognizer(target: self, action: #selector(onOverlayTapped))
        vwOverlay?.addGestureRecognizer(tapRecognizerOverlay)
        vwOverlay?.isUserInteractionEnabled = true
        self.tapRecognizerOverlay = tapRecognizerOverlay

        // Buttons
        btPrimaryAction?.addTarget(self, action: #selector(onPrimaryActionTapped), for: .touchUpInside)
        btPrimaryAction?.addTarget(self, action: #selector(onActionButtonPressed(_:)), for: .touchDown)
        btPrimaryAction?.addTarget(self, action: #selector(onActionButtonPressed(_:)), for: .touchDragEnter)
        btPrimaryAction?.addTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchDragExit)
        btPrimaryAction?.addTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchUpInside)
        btPrimaryAction?.addTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchUpOutside)
        btSecondaryAction?.addTarget(self, action: #selector(onSecondaryActionTapped), for: .touchUpInside)
        btSecondaryAction?.addTarget(self, action: #selector(onActionButtonPressed(_:)), for: .touchDown)
        btSecondaryAction?.addTarget(self, action: #selector(onActionButtonPressed(_:)), for: .touchDragEnter)
        btSecondaryAction?.addTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchDragExit)
        btSecondaryAction?.addTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchUpInside)
        btSecondaryAction?.addTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchUpOutside)

        btCloseAction?.addTarget(self, action: #selector(onCloseTapped), for: .touchUpInside)
    }

    func unregisterEvents() {
        // Gestures
        if let tapRecognizerOverlay = tapRecognizerOverlay {
            vwOverlay?.removeGestureRecognizer(tapRecognizerOverlay)
        }
        tapRecognizerOverlay = nil

        // Buttons
        btPrimaryAction?.removeTarget(self, action: #selector(onPrimaryActionTapped), for: .touchUpInside)
        btPrimaryAction?.removeTarget(self, action: #selector(onActionButtonPressed(_:)), for: .touchDown)
        btPrimaryAction?.removeTarget(self, action: #selector(onActionButtonPressed(_:)), for: .touchDragEnter)
        btPrimaryAction?.removeTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchDragExit)
        btPrimaryAction?.removeTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchUpInside)
        btPrimaryAction?.removeTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchUpOutside)
        btSecondaryAction?.removeTarget(self, action: #selector(onSecondaryActionTapped), for: .touchUpInside)
        btSecondaryAction?.removeTarget(self, action: #selector(onActionButtonPressed(_:)), for: .touchDown)
        btSecondaryAction?.removeTarget(self, action: #selector(onActionButtonPressed(_:)), for: .touchDragEnter)
        btSecondaryAction?.removeTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchDragExit)
        btSecondaryAction?.removeTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchUpInside)
        btSecondaryAction?.removeTarget(self, action: #selector(onActionButtonUnPressed(_:)), for: .touchUpOutside)

        btCloseAction?.removeTarget(self, action: #selector(onCloseTapped), for: .touchUpInside)
    }
}
