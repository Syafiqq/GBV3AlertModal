import Foundation

/// **Everything `GBAlertModal.resolve` reads from a `DataHolder` — all of it, and nothing else.**
///
/// The counterpart of `ModalStructureInputs` (see that protocol's doc for the measurement this one
/// repeats on the CONTENT side): `resolve` reads exactly these eleven things off a holder, all of
/// them presence/text questions — never a `UIImage`'s pixels, an `NSAttributedString`'s runs, or a
/// `UIView`'s subviews. So a `Sendable`, UIKit-free type can satisfy this protocol and feed the same
/// resolver `GBAlertModal.DataHolder` does (Pass 5 step 6,
/// `2026-08-07-uikit-retirement.md` §3).
///
/// `GBAlertModal.DataHolder` conforms for free — its stored properties already answer every one of
/// these questions (see `SwiftUI/DataHolder+ModalContentInputs.swift`, since `Components/` is frozen
/// this pass and the conformance lives on the SwiftUI side instead). `ModalContent` is the other
/// conformer: the SwiftUI-native replacement, carrying no `UIImage`/`NSAttributedString`/`UIView`.
///
/// **Not a caller-facing type**, exactly like `ModalStructureInputs`: nobody writes a conformance but
/// the two holder types, so `resolve` can take either without either knowing about the other.
public protocol ModalContentInputs {
    var closeOnTapOverlay: Bool { get }
    /// Non-nil AND non-degenerate, already resolved — `DataHolder`'s conformance folds in the same
    /// `size.width > 0 && size.height > 0` check `resolve` used to perform on `holder.banner` itself.
    var hasBanner: Bool { get }
    var title: String? { get }
    var hasAttributedTitle: Bool { get }
    var subtitle: String? { get }
    var hasAttributedSubtitle: Bool { get }
    var hasSubtitleCustomView: Bool { get }
    var primaryAction: String? { get }
    var secondaryAction: String? { get }
    var showCloseButton: Bool { get }
    var dismissOnAction: Bool { get }
}
