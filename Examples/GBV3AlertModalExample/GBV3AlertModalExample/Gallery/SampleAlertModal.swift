//
//  SampleAlertModal.swift
//  GBV3AlertModalExample
//
//  Thin `GBAlertModal` subclass adding `show()` via the key window, mirroring
//  `Presentation.UiKit.V3AlertModal.show()` from the distribution app
//  (`Common/Common/Custom/Components/AlertModal/V3AlertModal.swift`) without
//  the `Dialogable` conformance / `AppCompatHelper` dependency it can't import.
//

import UIKit
import GBV3AlertModal

@MainActor
final class SampleAlertModal: GBAlertModal {
    /// Presents this modal over the current key window.
    /// Mirrors `V3AlertModal.show()`'s `AppCompatHelper.keyWindow` lookup using
    /// only public `UIKit` API (no distribution-only helpers available here).
    func show() {
        guard let parent = Self.keyWindow else {
            return
        }
        show(parent: parent, completion: {})
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
