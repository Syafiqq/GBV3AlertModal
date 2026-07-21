import UIKit

/// Pure, unit-testable geometry the view uses to build its constraints. Every function here is a
/// straight extraction of arithmetic that used to live inline in `GBAlertModal.swift`'s
/// `adjust*` methods (now `GBAlertModal+Layout.swift`, see Task 6) — nil-coalescing defaults and
/// sign flips only, no `UIView`/window state and no SnapKit. `GBAlertModal+Layout.swift` is the
/// sole caller; it takes each result and applies it via `SnapKit`'s `ConstraintMaker`.
enum ModalLayout {
    /// Mirrors the original `resolvedContentWidths()` (formerly private in `GBAlertModal.swift`,
    /// now delegated to from `GBAlertModal+Layout.swift`): unpacks `ResolvedModal.WidthResolution`
    /// into the independent fixed/max values that `adjustSvContentContainerConstraint` and
    /// `adjustSvContentContainerConstraintWidth` each conditionally apply via their own `if let`.
    static func resolveContentWidths(
            _ contentWidth: GBAlertModal.ResolvedModal.WidthResolution
    ) -> (fixed: CGFloat?, max: CGFloat?) {
        switch contentWidth {
        case .flexible:
            return (nil, nil)
        case .fixed(let fixed):
            return (fixed, nil)
        case .max(let max):
            return (nil, max)
        case .fixedAndMax(let fixed, let max):
            return (fixed, max)
        }
    }

    /// Mirrors the four `.offset(...)` values `adjustVwContainerConstraint` applies to
    /// `vwContainer`'s top/leading/bottom/trailing constraints. `bottom` and `trailing` are
    /// pre-negated exactly as they are applied (`-(properties?.margin?.bottom ?? .zero)` /
    /// `-(properties?.margin?.right ?? .zero)`), so the caller can pass each straight to `.offset(...)`.
    static func resolveContainerOffsets(
            margin: UIEdgeInsets?
    ) -> (top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        (
                top: margin?.top ?? .zero,
                leading: margin?.left ?? .zero,
                bottom: -(margin?.bottom ?? .zero),
                trailing: -(margin?.right ?? .zero)
        )
    }

    /// Mirrors the eight `.offset(...)` values `adjustSvContentContainerConstraint` applies to
    /// `svContentContainer`'s top/leading/bottom/trailing min/max constraints. `bottomMin`,
    /// `bottomMax`, `trailingMin`, `trailingMax` are pre-negated exactly as applied
    /// (`-(properties?.padding?.bottomMin ?? .zero)`, etc.), so the caller can pass each straight
    /// to `.offset(...)`. `leading`/`trailing` here read from `UIMinMaxEdgeInsets`'s `left`/`right`
    /// fields — the model type's naming, not renamed.
    static func resolveContentPadding(
            padding: UIMinMaxEdgeInsets?
    ) -> (
            topMin: CGFloat, topMax: CGFloat,
            leadingMin: CGFloat, leadingMax: CGFloat,
            bottomMin: CGFloat, bottomMax: CGFloat,
            trailingMin: CGFloat, trailingMax: CGFloat
    ) {
        (
                topMin: padding?.topMin ?? .zero,
                topMax: padding?.topMax ?? .zero,
                leadingMin: padding?.leftMin ?? .zero,
                leadingMax: padding?.leftMax ?? .zero,
                bottomMin: -(padding?.bottomMin ?? .zero),
                bottomMax: -(padding?.bottomMax ?? .zero),
                trailingMin: -(padding?.rightMin ?? .zero),
                trailingMax: -(padding?.rightMax ?? .zero)
        )
    }

    /// Height-to-width multiplier for a banner rendered at its image's NATURAL aspect ratio
    /// (used by `GBAlertModal+ViewGraph.swift`'s `installConstraints` when `bannerRatio` is
    /// `nil` — the back-compat `bannerRatio`-provided path is untouched and does not call this).
    /// `height = width * multiplier`, so a 16:9 (wide) image returns `9/16 == 0.5625` and a
    /// 9:16 (tall) image returns `16/9 == 1.777...`. Nil/zero-guarded: any non-positive width or
    /// height (including `UIImage()`'s degenerate `.zero` size) returns `nil` so the caller can
    /// fall back rather than divide by zero / propagate a nonsensical multiplier.
    static func bannerHeightMultiplier(imageSize: CGSize) -> CGFloat? {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return nil
        }
        return imageSize.height / imageSize.width
    }
}
