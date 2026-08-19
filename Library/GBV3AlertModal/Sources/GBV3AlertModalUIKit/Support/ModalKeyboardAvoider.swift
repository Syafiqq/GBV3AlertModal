import GBV3AlertModalCore

import UIKit

/// Pure, unit-testable mirror of the keyboard-avoidance geometry that used to live inline in
/// `GBAlertModal.adjustDialogPosition(_:)`. This type owns ONLY the arithmetic — resolving which
/// view is the "bottom" anchor, converting coordinates, observing keyboard notifications, and
/// applying the resulting transform all stay in `GBAlertModal` (see the `// MARK: - KEYBOARD`
/// extension in `GBAlertModal.swift`, which is the sole caller).
///
/// `offset(...)` is a verbatim translation of the two branches in `adjustDialogPosition(_:)`: it
/// takes the same values the view already had in scope (already converted to window
/// coordinates) and returns the same `vwContainer.transform.ty` the view would have computed.
/// `nil` means "the original guard bailed — leave the transform untouched", exactly like the
/// early `return` in the original code (it is intentionally NOT `0`: the view may already be
/// offset from a previous keyboard event, and the original code leaves that offset in place).
struct ModalKeyboardAvoider {
    /// Mirrors the branch-selecting condition at the top of `adjustDialogPosition(_:)`:
    /// `keyboardFrame.minY > (UIScreen.main.bounds.maxY - keyboardFrame.maxY)`, i.e. the keyboard
    /// has more empty space above it (between the screen top and the keyboard) than below it
    /// (between the keyboard and the screen bottom).
    func keyboardHasMoreSpaceAbove(keyboardFrame: CGRect, screenMaxY: CGFloat) -> Bool {
        keyboardFrame.minY > (screenMaxY - keyboardFrame.maxY)
    }

    /// Verbatim mirror of `adjustDialogPosition(_:)`'s arithmetic for both branches.
    ///
    /// - Parameters:
    ///   - keyboardHasMoreSpaceAbove: result of
    ///     `keyboardHasMoreSpaceAbove(keyboardFrame:screenMaxY:)`; selects which of the two
    ///     branches runs.
    ///   - keyboardFrame: the keyboard's frame in window/screen coordinates.
    ///   - anchorFrame: the frame, in window coordinates, of whichever view the caller resolved
    ///     as the "bottom" reference for this branch — `svMainActionContainer ??
    ///     svSubtitleContainer ?? lbTitle` when `keyboardHasMoreSpaceAbove` is `true`, or the
    ///     reverse priority (`lbTitle ?? svSubtitleContainer ?? svMainActionContainer`) when
    ///     `false` — already converted via `bottomViewSuperview.convert(bottomView.frame, to: nil)`.
    ///   - responderFrame: the first responder's frame in window coordinates, if any view is
    ///     currently first responder (`nil` otherwise), converted the same way.
    ///   - currentTransformY: `vwContainer.transform.ty` before this adjustment.
    ///   - screenMaxY: `UIScreen.main.bounds.maxY`.
    ///   - emptySpace: `kEmptySpaceForKeyboardExtension` (48pt in production).
    /// - Returns: the new `vwContainer.transform.ty` to apply, or `nil` when the original guard
    ///   would have bailed out without touching the transform.
    func offset(
            keyboardHasMoreSpaceAbove: Bool,
            keyboardFrame: CGRect,
            anchorFrame: CGRect,
            responderFrame: CGRect?,
            currentTransformY: CGFloat,
            screenMaxY: CGFloat,
            emptySpace: CGFloat
    ) -> CGFloat? {
        if keyboardHasMoreSpaceAbove {
            var difference = keyboardFrame.minY
                    - anchorFrame.maxY
                    - emptySpace

            if let responderFrame, difference + responderFrame.minY < 0 {
                difference = -responderFrame.minY
            }

            difference += currentTransformY

            guard difference < 0 else {
                return nil
            }
            return difference
        } else {
            var difference = keyboardFrame.maxY
                    - anchorFrame.minY
                    + emptySpace

            if let responderFrame, difference + responderFrame.maxY > screenMaxY {
                difference = screenMaxY - responderFrame.maxY
            }

            difference += currentTransformY

            guard difference > 0 else {
                return nil
            }
            return difference
        }
    }
}
