import UIKit

extension GBAlertModal {
    /// Pure, deterministic description of every render *decision* `GBAlertModal` makes for a
    /// given `(properties, holder, orientation)` input — which views are shown, the subtitle
    /// kind, button axis/alignment, the dismiss/overlay flags, and the resolved content width.
    ///
    /// This is a **verbatim mirror** of the inline decisions in the view's render pipeline
    /// (`registerDialogView`, `adjustDialogViewStyle`, `adjustSvContentContainerConstraint*`).
    /// It intentionally changes no behavior; the view routes its decisions through
    /// `resolve(...)` so this type can be exhaustively unit-tested and later used as the
    /// SwiftUI equivalence spec.
    public struct ResolvedModal: Equatable {
        /// Which subtitle representation is rendered. Precedence mirrors `registerDialogView`:
        /// a non-empty plain `subtitle` wins over a non-empty `subtitleAttributed`, which wins
        /// over a `subtitleCustomView`; otherwise `.none`.
        public enum SubtitleKind: Equatable {
            case none
            case plain(String)
            case attributed
            case custom
        }

        /// Resolved width constraint(s) applied to the content container. The view applies a
        /// fixed-width constraint and a max-width constraint independently, so both can be
        /// present at once (`.fixedAndMax`) — this mirrors the two independent `if let`s in
        /// `adjustSvContentContainerConstraint`.
        public enum WidthResolution: Equatable {
            case flexible
            case fixed(CGFloat)
            case max(CGFloat)
            case fixedAndMax(fixed: CGFloat, max: CGFloat)
        }

        public var showsBanner: Bool
        public var showsTitle: Bool
        public var subtitle: SubtitleKind
        public var showsPrimary: Bool
        public var showsSecondary: Bool
        public var showsCloseButton: Bool
        public var buttonAxis: NSLayoutConstraint.Axis
        public var buttonsMatchParent: Bool
        public var dismissOnAction: Bool
        public var closeOnTapOverlay: Bool
        public var contentWidth: WidthResolution
    }

    /// Compute the render decisions for the given input. Pure: orientation is passed in
    /// (`isLandscape`) rather than read from `UIWindow`, so the result is deterministic and
    /// unit-testable. The view passes whatever it currently computes.
    /// `nonisolated`: genuinely pure (value inputs only, no main-actor state), so it is callable
    /// off the main actor — matching its role as the exhaustive, testable resolver.
    nonisolated public static func resolve(
            properties: Properties?,
            holder: DataHolder,
            isLandscape: Bool
    ) -> ResolvedModal {
        // Banner — `registerDialogView`: `if let banner = dataHolder?.banner`. A degenerate
        // (nil OR zero-size) image reserves no banner slot: a zero-size `UIImage()` has no
        // pixels to render and would otherwise leave an empty gap above the title.
        let showsBanner: Bool = {
            guard let banner = holder.banner else { return false }
            return banner.size.width > 0 && banner.size.height > 0
        }()

        // Title — `registerDialogView`: non-empty plain title, else non-empty attributed title.
        let hasPlainTitle = (holder.title?.isEmpty == false)
        let hasAttributedTitle = ((holder.titleAttributed?.length ?? 0) > 0)
        let showsTitle = hasPlainTitle || hasAttributedTitle

        // Subtitle — `registerDialogView`: plain (non-empty) > attributed (length > 0) > custom.
        let subtitle: ResolvedModal.SubtitleKind
        if let plain = holder.subtitle, !plain.isEmpty {
            subtitle = .plain(plain)
        } else if let attributed = holder.subtitleAttributed, attributed.length > 0 {
            subtitle = .attributed
        } else if holder.subtitleCustomView != nil {
            subtitle = .custom
        } else {
            subtitle = .none
        }

        // Actions — `registerDialogView`: requires BOTH the action string and its style.
        let showsPrimary = holder.primaryAction != nil && properties?.primaryActionStyle != nil
        let showsSecondary = holder.secondaryAction != nil && properties?.secondaryActionStyle != nil

        // Close — `registerDialogView`: `dataHolder?.showCloseButton == true` (vwContainer is
        // always present once the base design is built).
        let showsCloseButton = holder.showCloseButton == true

        // Button axis / alignment — `adjustDialogViewStyle`. When no orientation is set the
        // main-action stack keeps its generated default of `.vertical`.
        let buttonAxis = properties?.buttonActionOrientation ?? .vertical
        let buttonsMatchParent = properties?.buttonActionShouldMatchParent == true

        // Runtime flags — consumed by the overlay-tap / dismiss callbacks.
        let dismissOnAction = holder.dismissOnAction
        let closeOnTapOverlay = holder.closeOnTapOverlay

        // Content width — `adjustSvContentContainerConstraint`: fixed and max are independent,
        // each preferring the current orientation and falling back to the other.
        let contentProperty = properties?.contentProperty
        let fixedWidth = isLandscape
                ? contentProperty?.fixedWidthLandscape ?? contentProperty?.fixedWidthPortrait
                : contentProperty?.fixedWidthPortrait ?? contentProperty?.fixedWidthLandscape
        let maxWidth = isLandscape
                ? contentProperty?.maxWidthLandscape ?? contentProperty?.maxWidthPortrait
                : contentProperty?.maxWidthPortrait ?? contentProperty?.maxWidthLandscape

        let contentWidth: ResolvedModal.WidthResolution
        switch (fixedWidth, maxWidth) {
        case let (fixed?, max?):
            contentWidth = .fixedAndMax(fixed: fixed, max: max)
        case let (fixed?, nil):
            contentWidth = .fixed(fixed)
        case let (nil, max?):
            contentWidth = .max(max)
        case (nil, nil):
            contentWidth = .flexible
        }

        return ResolvedModal(
                showsBanner: showsBanner,
                showsTitle: showsTitle,
                subtitle: subtitle,
                showsPrimary: showsPrimary,
                showsSecondary: showsSecondary,
                showsCloseButton: showsCloseButton,
                buttonAxis: buttonAxis,
                buttonsMatchParent: buttonsMatchParent,
                dismissOnAction: dismissOnAction,
                closeOnTapOverlay: closeOnTapOverlay,
                contentWidth: contentWidth
        )
    }
}
