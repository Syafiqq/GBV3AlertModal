import GBV3AlertModalCore

import UIKit

extension UIKitModalRenderer {
    /// Builds the `DataHolder` for `TextInputDialog`: a `UITextField` in the modal's custom-content
    /// slot; a primary tap reads its text and resolves `.submitted(text)`. The field is captured by
    /// the completion and held strongly by the holder (`subtitleCustomView`), so it stays alive.
    @MainActor public enum TextInputHolder {
        public static func make(
            for descriptor: TextInputDialog,
            resolve: @escaping (TextInputDialog.Result) -> Void
        ) -> GBAlertModal.DataHolder {
            let field = UITextField()
            field.text = descriptor.initialText
            field.placeholder = descriptor.placeholder
            field.borderStyle = .roundedRect
            field.overrideUserInterfaceStyle = .light // legible dark text on the standard light card
            field.translatesAutoresizingMaskIntoConstraints = false
            field.heightAnchor.constraint(equalToConstant: 44).isActive = true

            let (titlePlain, titleAttr) = UIKitModalTextAdapter.split(descriptor.title)
            return GBAlertModal.DataHolder(
                closeOnTapOverlay: descriptor.closeOnTapOverlay,
                title: titlePlain,
                titleAttributed: titleAttr,
                subtitleCustomView: field,
                primaryAction: descriptor.primary,
                secondaryAction: descriptor.secondary,
                dismissOnAction: false, // gate owns teardown
                completion: { _, action in
                    switch action {
                    case .primary: resolve(.submitted(field.text ?? ""))
                    case .secondary, .close: resolve(.dismissed)
                    }
                }
            )
        }
    }

    /// Builds the `DataHolder` for `DatePickerDialog`: a `UIDatePicker` in the custom-content slot;
    /// a primary tap reads its date and resolves `.submitted(date)`.
    @MainActor public enum DatePickerHolder {
        public static func make(
            for descriptor: DatePickerDialog,
            resolve: @escaping (DatePickerDialog.Result) -> Void
        ) -> GBAlertModal.DataHolder {
            let picker = UIDatePicker()
            picker.datePickerMode = .date
            picker.date = descriptor.initialDate
            // Range BEFORE the date would clamp the initial value; UIDatePicker applies bounds as
            // they are set, so the order here is deliberate — date first, then the bounds that may
            // legitimately move it.
            picker.minimumDate = descriptor.minimumDate
            picker.maximumDate = descriptor.maximumDate
            picker.overrideUserInterfaceStyle = .light // legible dark wheels on the standard light card
            picker.translatesAutoresizingMaskIntoConstraints = false
            if #available(iOS 14.0, *) { picker.preferredDatePickerStyle = .wheels }

            let (titlePlain, titleAttr) = UIKitModalTextAdapter.split(descriptor.title)
            return GBAlertModal.DataHolder(
                closeOnTapOverlay: descriptor.closeOnTapOverlay,
                title: titlePlain,
                titleAttributed: titleAttr,
                subtitleCustomView: picker,
                primaryAction: descriptor.primary,
                secondaryAction: descriptor.secondary,
                dismissOnAction: false,
                completion: { _, action in
                    switch action {
                    case .primary: resolve(.submitted(picker.date))
                    case .secondary, .close: resolve(.dismissed)
                    }
                }
            )
        }
    }
}
