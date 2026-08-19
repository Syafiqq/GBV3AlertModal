import Foundation

/// Platform-neutral render decisions shared by both rendering backends.
public struct ResolvedModal: Sendable, Equatable {
    public enum SubtitleKind: Sendable, Equatable {
        case none
        case plain(String)
        case attributed
        case custom
    }

    public enum WidthResolution: Sendable, Equatable {
        case flexible
        case fixed(CGFloat)
        case max(CGFloat)
        case fixedAndMax(fixed: CGFloat, max: CGFloat)
    }

    public enum ButtonAxis: Sendable, Equatable {
        case horizontal
        case vertical
    }

    public let showsBanner: Bool
    public let showsTitle: Bool
    public let subtitle: SubtitleKind
    public let showsPrimary: Bool
    public let showsSecondary: Bool
    public let showsCloseButton: Bool
    public let buttonAxis: ButtonAxis
    public let buttonsMatchParent: Bool
    public let dismissOnAction: Bool
    public let closeOnTapOverlay: Bool
    public let contentWidth: WidthResolution

    public init(
        showsBanner: Bool, showsTitle: Bool, subtitle: SubtitleKind,
        showsPrimary: Bool, showsSecondary: Bool, showsCloseButton: Bool,
        buttonAxis: ButtonAxis, buttonsMatchParent: Bool,
        dismissOnAction: Bool, closeOnTapOverlay: Bool,
        contentWidth: WidthResolution
    ) {
        self.showsBanner = showsBanner
        self.showsTitle = showsTitle
        self.subtitle = subtitle
        self.showsPrimary = showsPrimary
        self.showsSecondary = showsSecondary
        self.showsCloseButton = showsCloseButton
        self.buttonAxis = buttonAxis
        self.buttonsMatchParent = buttonsMatchParent
        self.dismissOnAction = dismissOnAction
        self.closeOnTapOverlay = closeOnTapOverlay
        self.contentWidth = contentWidth
    }
}

/// Unambiguous bridge used by the deprecated nested UIKit spelling. The bridge avoids qualifying
/// the type with the former aggregate module name, which no longer owns Core after the target split.
public typealias CoreResolvedModal = ResolvedModal

/// Resolves backend-independent rendering decisions from neutral input contracts.
nonisolated public func resolveModal(
    inputs: (any ModalStructureInputs)?,
    content: any ModalContentInputs,
    isLandscape: Bool
) -> ResolvedModal {
    let subtitle: ResolvedModal.SubtitleKind
    if let plain = content.subtitle, !plain.isEmpty {
        subtitle = .plain(plain)
    } else if content.hasAttributedSubtitle {
        subtitle = .attributed
    } else if content.hasSubtitleCustomView {
        subtitle = .custom
    } else {
        subtitle = .none
    }

    let fixedWidth = isLandscape
        ? inputs?.fixedWidthLandscape ?? inputs?.fixedWidthPortrait
        : inputs?.fixedWidthPortrait ?? inputs?.fixedWidthLandscape
    let maxWidth = isLandscape
        ? inputs?.maxWidthLandscape ?? inputs?.maxWidthPortrait
        : inputs?.maxWidthPortrait ?? inputs?.maxWidthLandscape
    let contentWidth: ResolvedModal.WidthResolution
    switch (fixedWidth, maxWidth) {
    case let (fixed?, max?): contentWidth = .fixedAndMax(fixed: fixed, max: max)
    case let (fixed?, nil): contentWidth = .fixed(fixed)
    case let (nil, max?): contentWidth = .max(max)
    case (nil, nil): contentWidth = .flexible
    }

    return ResolvedModal(
        showsBanner: content.hasBanner,
        showsTitle: content.title?.isEmpty == false || content.hasAttributedTitle,
        subtitle: subtitle,
        showsPrimary: content.primaryAction != nil && inputs?.hasPrimaryActionStyle == true,
        showsSecondary: content.secondaryAction != nil && inputs?.hasSecondaryActionStyle == true,
        showsCloseButton: content.showCloseButton,
        buttonAxis: inputs?.buttonsAreHorizontal == true ? .horizontal : .vertical,
        buttonsMatchParent: inputs?.buttonsMatchParent == true,
        dismissOnAction: content.dismissOnAction,
        closeOnTapOverlay: content.closeOnTapOverlay,
        contentWidth: contentWidth
    )
}
