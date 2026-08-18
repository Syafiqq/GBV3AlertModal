import UIKit

extension UIKitModalRenderer {
    /// Descriptor→`DataHolder` mapping for the built-in `AlertDialog`. Kept separate so the
    /// mapping is unit-testable without a window (Task 1) and reused by the factory (Task 3).
    @MainActor public enum AlertHolder {
        /// One mapping for the whole standard family (`AlertDialog`, `PopupDialog`, …). Result is
        /// always `AlertDialog.Result` — the shared vocabulary those descriptors resolve to.
        public static func make(
            for descriptor: StandardAlertContent,
            resolve: @escaping (AlertDialog.Result) -> Void
        ) -> GBAlertModal.DataHolder {
            let (titlePlain, titleAttr) = UIKitModalTextAdapter.split(descriptor.title)
            let (subPlain, subAttr) = UIKitModalTextAdapter.split(descriptor.subtitle)
            return GBAlertModal.DataHolder(
                closeOnTapOverlay: descriptor.closeOnTapOverlay,
                banner: descriptor.image.flatMap { UIImage(named: $0.assetName, in: $0.bundle, compatibleWith: nil) },
                title: titlePlain,
                titleAttributed: titleAttr,
                subtitle: subPlain,
                subtitleAttributed: subAttr,
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
