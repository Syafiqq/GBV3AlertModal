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

// MARK: - The title's last resort: shrink, never truncate

extension ModalLayout {
    /// **How far the TITLE may shrink before it is allowed to give up anything else — the floor of
    /// rung 2.**
    ///
    /// `0.75`, and the number is not arbitrary: it is exactly the `minimumScaleFactor` this label
    /// carried for years (`generateLabelForTitleDesign`, and still today in the shipped app's
    /// `V2AlertModal.swift:607`). Keeping it means the shrink RANGE a Geniebook title can occupy is
    /// unchanged from what has always shipped — only its TRIGGER moved, from first resort (shrink
    /// before wrapping, then truncate at two lines) to last resort (wrap freely; shrink only once the
    /// subtitle has surrendered everything; never truncate).
    ///
    /// It is also enough for the case that forced the issue: a 121-glyph title in the 256pt content
    /// column needs 172pt at 24pt, and the landscape card can offer ~110pt. At 0.75 the font is 18pt,
    /// the same text re-wraps to ~5 lines of 21.5pt ≈ 107.5pt, and it fits with every glyph intact.
    ///
    /// Shared by BOTH renderers: `ModalTokens.titleMinimumScaleFactor` is initialised from this
    /// constant rather than transcribing it, so SwiftUI's `minimumScaleFactor` and UIKit's computed
    /// fit cannot drift apart (`test_theShrinkFloor_isOneSharedNumber`).
    static var titleMinimumScaleFactor: CGFloat { 0.75 }

    /// The coarse grid the fit search walks. 0.05 is deliberately coarse: it bounds the search at six
    /// measurements, and — more importantly — it QUANTISES the answer, so a fractional-point wobble in
    /// the available height cannot make the chosen scale oscillate between two neighbouring values on
    /// successive layout passes.
    static var titleFontScaleStep: CGFloat { 0.05 }

    /// **The largest font scale at which the title still fits, or the floor.**
    ///
    /// Pure and closure-driven so it is unit-testable without a `UILabel`, a window or a layout pass:
    /// the caller supplies `heightAtScale`, which measures the real attributed string at a candidate
    /// scale. Walks DOWN from 1 on the `step` grid and returns the first scale that fits; if even
    /// `floor` does not fit, it returns `floor` — never anything smaller, and never a signal to
    /// truncate. That is rung 3: below the floor the title keeps all of its glyphs and the layout
    /// gives way elsewhere.
    ///
    /// Integer stepping (`1 - step * i`) rather than repeated subtraction, so the last rung lands
    /// exactly on `floor` instead of on 0.7499999 worth of accumulated float drift.
    ///
    /// The 0.5pt slack in the fit test is the same sub-pixel allowance the rest of this module uses:
    /// `boundingRect` and `UILabel.intrinsicContentSize` round a multi-line height slightly
    /// differently, and half a point of that must not cost a whole step of font size.
    static func titleFontScale(
            availableHeight: CGFloat,
            floor: CGFloat = ModalLayout.titleMinimumScaleFactor,
            step: CGFloat = ModalLayout.titleFontScaleStep,
            heightAtScale: (CGFloat) -> CGFloat
    ) -> CGFloat {
        guard availableHeight > 0, floor > 0, floor < 1, step > 0 else {
            return 1
        }
        let steps = Int((((1 - floor) / step).rounded()))
        for index in 0...Swift.max(steps, 0) {
            let scale = Swift.max(1 - step * CGFloat(index), floor)
            if heightAtScale(scale) <= availableHeight + 0.5 {
                return scale
            }
        }
        return floor
    }
}

// MARK: - Text measurement, shared by both renderers

extension ModalLayout {
    /// The height `text` needs when wrapped at `width`, with no line limit.
    ///
    /// `.usesLineFragmentOrigin` + `.usesFontLeading` is the multi-line measurement pair — without the
    /// first, `boundingRect` measures a SINGLE line and every answer is wrong in the same direction as
    /// the `preferredMaxLayoutWidth` defect this ladder sits on top of.
    ///
    /// Lives here, not on `GBAlertModal`, because BOTH renderers measure with it: UIKit's rung 2 walks
    /// the scale grid against it, and `titleFloorHeight` below turns it into SwiftUI's minimum row
    /// height. One measurement function means the two cannot compute different floors for the same
    /// string.
    static func textHeight(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
        guard width > 0, width.isFinite else {
            return 0
        }
        return text.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
        ).height
    }

    /// **The floor of rung 2, expressed as a HEIGHT: what the title needs once it has shrunk as far as
    /// it is allowed to.**
    ///
    /// UIKit does not need this — its rung 2 walks the scale grid and the label's own intrinsic height
    /// follows the chosen font. SwiftUI does: `minimumScaleFactor` caps how small the GLYPHS get, but
    /// nothing stops the FRAME being proposed less than even those glyphs need, and a `Text` in a
    /// too-small frame clips. Measured: the pressured title was allocated 64.7pt where the
    /// floor-scaled text needs 85.9pt, and the missing 21pt came out of the string. So the SwiftUI row
    /// carries this as a `.frame(minHeight:)` — a floor on the space, to match the floor on the scale.
    ///
    /// **It can never make a row TALLER than it would otherwise be**, which is what makes it safe to
    /// apply unconditionally: the same string in a SMALLER font at the SAME width always needs less
    /// height (shorter lines, and more characters fit on each), so this value is ≤ the row's nominal
    /// ideal height by construction. Whenever the layout can give the title its ideal — every
    /// unpressured shape, i.e. every shape the differential harness compares — the floor is inert.
    ///
    /// Returns 0 (no floor) for a non-finite width. That is the property-less caller
    /// (`ModalTokens.standard` has no `Properties` to derive a content width from, so
    /// `contentMaxWidth` is `.infinity`): there is no width to wrap against, so there is no honest
    /// floor to compute, and previews/demos keep exactly today's layout.
    static func titleFloorHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        guard !text.isEmpty, width > 0, width.isFinite else {
            return 0
        }
        let flooredFont = font.withSize(font.pointSize * titleMinimumScaleFactor)
        return textHeight(NSAttributedString(string: text, attributes: [.font: flooredFont]), width: width)
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
