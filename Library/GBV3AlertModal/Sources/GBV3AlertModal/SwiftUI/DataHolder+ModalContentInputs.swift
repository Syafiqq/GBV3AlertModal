import UIKit

/// `GBAlertModal.DataHolder`'s conformance to `ModalContentInputs`, declared here rather than beside
/// the struct in `Components/GBAlertModal+DataHolder.swift` — that file is frozen for Pass 5 (§5,
/// "Touch UIKit... Components/... stay frozen"); an extension in a different file of the SAME module
/// is ordinary Swift and needs no change there.
///
/// Seven of the eleven requirements are already exact matches on `DataHolder`'s own stored
/// properties (`closeOnTapOverlay`, `title`, `subtitle`, `primaryAction`, `secondaryAction`,
/// `showCloseButton`, `dismissOnAction`) and need no code here at all. Only the four that `resolve`
/// used to compute INLINE from a `UIImage`/`NSAttributedString`/`UIView` are added below.
extension GBAlertModal.DataHolder: ModalContentInputs {
    /// Non-nil AND non-degenerate — the same check `resolve` used to perform on `holder.banner`
    /// itself before this protocol existed.
    public var hasBanner: Bool {
        guard let banner else { return false }
        return banner.size.width > 0 && banner.size.height > 0
    }

    public var hasAttributedTitle: Bool {
        (titleAttributed?.length ?? 0) > 0
    }

    public var hasAttributedSubtitle: Bool {
        (subtitleAttributed?.length ?? 0) > 0
    }

    public var hasSubtitleCustomView: Bool {
        subtitleCustomView != nil
    }
}
