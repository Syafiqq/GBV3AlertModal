import UIKit

extension UIKitModalRenderer {
    /// Descriptor→`DataHolder` mapping for the built-in `AlertDialog`. Kept separate so the
    /// mapping is unit-testable without a window (Task 1) and reused by the factory (Task 3).
    @MainActor public enum AlertHolder {
        public static func make(
            for descriptor: AlertDialog,
            resolve: @escaping (AlertDialog.Result) -> Void
        ) -> GBAlertModal.DataHolder {
            GBAlertModal.DataHolder(
                closeOnTapOverlay: descriptor.closeOnTapOverlay,
                banner: descriptor.image.flatMap { UIImage(named: $0.assetName) },
                title: descriptor.title,
                subtitle: descriptor.subtitle,
                primaryAction: descriptor.primary,
                secondaryAction: descriptor.secondary,
                showCloseButton: descriptor.showCloseButton,
                dismissOnAction: false, // gate owns teardown; see UIKitModalRenderer
                completion: { _, action in
                    switch action {
                    case .primary: resolve(.primary)
                    case .secondary: resolve(.secondary)
                    case .close: resolve(.dismissed)
                    }
                }
            )
        }
    }
}
