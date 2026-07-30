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

// MARK: - The vertical priority ladder

extension ModalLayout {
    /// **THE VERTICAL PRIORITY LADDER of the card's content rows, in ONE place.**
    ///
    /// These numbers used to be literals spread across `GBAlertModal+ViewGraph.swift`'s
    /// `installConstraints` plus two UIKit DEFAULTS that were only mentioned in prose (the title
    /// label's and the subtitle label's 750 compression resistance). The owner directive "title and
    /// subtitle should no truncated, title with more content compression (title will still live
    /// while subtitle begin to wrap)" is an ORDERING statement about exactly those numbers, so they
    /// are stated here — as one ladder a test can assert the order of — instead of being inferred
    /// from a platform default at three call sites.
    ///
    /// Top to bottom, and WHY each rung sits where it does:
    ///
    /// | rung | value | what it is |
    /// | --- | --- | --- |
    /// | `titleCompressionResistance` | **900** | `lbTitle`'s vertical resistance. Raised from
    ///   UIKit's 750 default so the title out-ranks EVERY other content rung: it keeps its font
    ///   size and however many lines it needs (`numberOfLines = 0`), and the subtitle is what gives
    ///   way. Deliberately NOT `.required` (1000) — see below. |
    /// | `bannerMaxHeight` | 751 | `vwBanner.height <= bannerMaxHeight`. An explicit cap the caller
    ///   asked for; it out-ranks the natural-aspect driver so a capped banner stays capped. |
    /// | `subtitleCompressionResistance` | **750** | `lbSubtitle`'s vertical resistance — UIKit's
    ///   default, now stated explicitly because the directive's ordering depends on it being BELOW
    ///   the title's. It must stay ABOVE `subtitleSlotHeight*` (see the next two rows): the label
    ///   is what refuses to shrink, which is what turns "the slot is too short" into SCROLLING
    ///   instead of into a truncated subtitle. |
    /// | `subtitleSlotHeightOverBanner` | 749 | `svSubtitleContainer.frameLayoutGuide.height ==
    ///   contentLayoutGuide.height`, on the natural-aspect banner path only — above the banner's
    ///   700 driver so a very tall banner yields to the subtitle rather than starving it. |
    /// | `bannerNaturalAspect` | 700 | `vwBanner.height == vwBanner.width * imageH/imageW`. |
    /// | `bannerFixedHeight` | 251 | `vwBanner.height == bannerFixedHeight`; inert whenever the 700
    ///   driver is installed (i.e. on the `bannerRatio == nil` path). |
    /// | `subtitleSlotHeight` | 250 (`.defaultLow`) | the same frame/content height tie on every
    ///   other path. **This is the SUBTITLE-YIELDS mechanism**: it is the weakest content rung, so
    ///   when the card cannot fit everything between its margins this equality is what breaks, the
    ///   scroll's visible height shrinks below its content height, and the subtitle scrolls —
    ///   full-size, unshrunk, un-truncated — while the title keeps every line. |
    /// | `bannerImageIntrinsic` | 249 | `ivBanner`'s own vertical resistance, dropped below every
    ///   content rung so a 2000px-tall image's intrinsic height cannot fight the text. |
    ///
    /// **Why the title is 900 and not `.required`.** The card is bounded by `.required` margin
    /// constraints on `vwContainer` and `.required` minimum padding on `svContentContainer`, so a
    /// title taller than the whole card is a genuinely unsatisfiable system. At 1000 Auto Layout
    /// would have to break one of those `.required` constraints and would log
    /// "Unable to simultaneously satisfy constraints"; at 900 it breaks the title's own resistance
    /// instead, which is a normal, silent resolution. 900 is above every other content rung, so the
    /// title still yields LAST — after the subtitle slot (250/749), after the banner (700) and after
    /// the banner image (249).
    enum Priority {
        // Computed rather than `static let`: a stored static of a non-`Sendable` type is a Swift 6
        // strict-concurrency error, and `UILayoutPriority`'s conformance is SDK-version-dependent.
        // These are constants either way — there is no state here to share.
        static var titleCompressionResistance: UILayoutPriority { UILayoutPriority(900) }
        static var bannerMaxHeight: UILayoutPriority { UILayoutPriority(751) }
        static var subtitleCompressionResistance: UILayoutPriority { UILayoutPriority(750) }
        static var subtitleSlotHeightOverBanner: UILayoutPriority { UILayoutPriority(749) }
        static var bannerNaturalAspect: UILayoutPriority { UILayoutPriority(700) }
        static var bannerFixedHeight: UILayoutPriority { UILayoutPriority(251) }
        static var subtitleSlotHeight: UILayoutPriority { .defaultLow }
        static var bannerImageIntrinsic: UILayoutPriority { UILayoutPriority(249) }
    }
}
