import UIKit

/// **The SwiftUI half's own holder — `Sendable`, and carrying no `UIImage`/`UIView`/
/// `NSAttributedString`.**
///
/// Pass 5 step 6 (`2026-08-07-uikit-retirement.md` §3): the replacement for
/// `UIKitModalRenderer.AlertHolder.make`'s `GBAlertModal.DataHolder` on the paths that build one
/// purely to feed `GBAlertModal.resolve`'s structural decisions — this renderer never reads
/// `DataHolder.completion` (see `SwiftUIModalRenderer`'s own doc for why), so a holder built here
/// never needed the UIKit-typed fields in the first place.
///
/// `ModalContentInputs` is every question `resolve` asks — see that protocol. This type answers
/// them directly, as `Bool`/`String`, rather than by carrying an object `resolve` would inspect.
/// **The one field this type does NOT carry is the actual styled subtitle content** for the
/// `.attributed` case: `resolve` only needs to know THAT it is attributed, never the runs
/// themselves, and `SwiftUIAlertModal` re-derives the real `NSAttributedString` from `config`
/// directly where it is actually rendered (`subtitlePayload`) — computed twice from the same pure
/// `ModalText.split`, never stored on a `Sendable` value.
public struct ModalContent: ModalContentInputs, Sendable {
    public let closeOnTapOverlay: Bool
    public let hasBanner: Bool
    public let title: String?
    public let hasAttributedTitle: Bool
    public let subtitle: String?
    public let hasAttributedSubtitle: Bool
    public let hasSubtitleCustomView: Bool
    public let primaryAction: String?
    public let secondaryAction: String?
    public let showCloseButton: Bool
    public let dismissOnAction: Bool

    public init(
        closeOnTapOverlay: Bool = false,
        hasBanner: Bool = false,
        title: String? = nil,
        hasAttributedTitle: Bool = false,
        subtitle: String? = nil,
        hasAttributedSubtitle: Bool = false,
        hasSubtitleCustomView: Bool = false,
        primaryAction: String? = nil,
        secondaryAction: String? = nil,
        showCloseButton: Bool = false,
        dismissOnAction: Bool = false
    ) {
        self.closeOnTapOverlay = closeOnTapOverlay
        self.hasBanner = hasBanner
        self.title = title
        self.hasAttributedTitle = hasAttributedTitle
        self.subtitle = subtitle
        self.hasAttributedSubtitle = hasAttributedSubtitle
        self.hasSubtitleCustomView = hasSubtitleCustomView
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.showCloseButton = showCloseButton
        self.dismissOnAction = dismissOnAction
    }
}

extension ModalContent {
    /// The standard family (`AlertDialog`, `PopupDialog`, …) — the SwiftUI-native mirror of
    /// `UIKitModalRenderer.AlertHolder.make`'s mapping. Same decisions, verbatim: `hasBanner` still
    /// asks whether `descriptor.image` resolves in its bundle (the identical
    /// `UIImage(named:in:compatibleWith:)` probe), it just never keeps the result — nothing here
    /// stores a `UIImage`, so there is nothing non-`Sendable` to carry.
    public static func make(for descriptor: StandardAlertContent) -> ModalContent {
        let (titlePlain, titleAttr) = ModalText.split(descriptor.title)
        let (subtitlePlain, subtitleAttr) = ModalText.split(descriptor.subtitle)
        let hasBanner = descriptor.image.flatMap {
            UIImage(named: $0.assetName, in: $0.bundle, compatibleWith: nil)
        } != nil
        return ModalContent(
            closeOnTapOverlay: descriptor.closeOnTapOverlay,
            hasBanner: hasBanner,
            title: titlePlain,
            hasAttributedTitle: (titleAttr?.length ?? 0) > 0,
            subtitle: subtitlePlain,
            hasAttributedSubtitle: (subtitleAttr?.length ?? 0) > 0,
            primaryAction: descriptor.primary,
            secondaryAction: descriptor.secondary,
            showCloseButton: descriptor.showCloseButton,
            dismissOnAction: false // the renderer's own gate owns teardown, same as AlertHolder.make
        )
    }

    /// The mirror of `UIKitModalRenderer.TextInputHolder.make` — same mapping, minus the `UITextField`
    /// itself: `hasSubtitleCustomView` records that a custom view WOULD occupy the subtitle slot,
    /// confirmed inert on this backend (see `SwiftUIModalRenderer`'s own doc on `makePresentation`),
    /// kept for structural parity. No `showCloseButton` field on `TextInputDialog` — always `false`,
    /// same as the UIKit holder never setting it either.
    public static func make(for descriptor: TextInputDialog) -> ModalContent {
        let (titlePlain, titleAttr) = ModalText.split(descriptor.title)
        return ModalContent(
            closeOnTapOverlay: descriptor.closeOnTapOverlay,
            title: titlePlain,
            hasAttributedTitle: (titleAttr?.length ?? 0) > 0,
            hasSubtitleCustomView: true,
            primaryAction: descriptor.primary,
            secondaryAction: descriptor.secondary,
            dismissOnAction: false
        )
    }
}
