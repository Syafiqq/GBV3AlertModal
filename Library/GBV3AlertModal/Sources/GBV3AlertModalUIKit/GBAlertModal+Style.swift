import GBV3AlertModalCore

import Foundation
import UIKit

// MARK: - STYLE

extension GBAlertModal {
    // Widened from `private` to `internal` in Task 1: called from `updateDialog` in
    // GBAlertModal+Lifecycle.swift and, as of Task 2, from `initViews` in
    // GBAlertModal+Model.swift (different files, same module).
    func adjustDialogViewStyle() {
        let resolved = makeResolvedModal()

        // Base View
        tintColor = properties?.baseTint

        // Overlay
        vwOverlay?.backgroundColor = properties?.overlayColor

        // Content Container
        vwContainer?.backgroundColor = properties?.contentProperty?.backgroundColor
        vwContainer?.layer.cornerRadius = properties?.contentProperty?.cornerRadius ?? .zero

        // Content Container Stack
        svContentContainer?.alignment = properties?.contentProperty?.childShouldMatchParent == true ? .fill : .center

        // Button Action Stack
        svMainActionContainer?.alignment = resolved.buttonsMatchParent ? .fill : .center

        // Button Action Orientation
        svMainActionContainer?.axis = resolved.buttonAxis.uiKitAxis

        // Close Button
        btCloseAction?.tintColor = properties?.closeButtonTint
        btCloseAction?.setImage(
                dataHolder?.closeImage ?? UIImage(
                        named: "ic_fa_xmark_24",
                        in: Bundle.module,
                        compatibleWith: nil
                ),
                for: .normal
        )
    }
}
