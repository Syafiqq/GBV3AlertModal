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

// MARK: - The subtitle's floor: it yields, but not all the way to nothing

extension ModalLayout {
    /// **How far the SUBTITLE may yield: down to ONE LINE, and no further.**
    ///
    /// Rung 1 makes the subtitle the row that gives way, and that was measured working — in the
    /// pressured landscape card it gave way *entirely*: the slot's frame height went to zero, so the
    /// body text was not scrolled, it was gone, with no scroll indicator and nothing to scroll. A
    /// reader saw a title and a button and no explanation of either. "The subtitle begins to wrap"
    /// does not mean "the subtitle disappears", and a zero-height scroll slot is truncation by
    /// another name — the one outcome the whole ladder exists to forbid.
    ///
    /// So the yield is bounded. One line is the smallest floor that is still honest (the reader gets
    /// real words plus a scroll affordance), and it is the largest floor that cannot disturb an
    /// unpressured shape: every non-empty label is already at least one line tall, so the floor is
    /// `<=` the slot's content height by construction and the `frame == content` tie (250) satisfies
    /// it for free whenever it holds.
    ///
    /// **It is a floor, not a guarantee**, and deliberately: at `Priority.subtitleSlotFloor` (850) it
    /// still ranks below the title (900). On a card that cannot fit one line of each — the landscape
    /// `longTitle` fixture, where a 214pt ceiling leaves 110pt for a title that needs 107.4 at its own
    /// floor — this is what gives way, because the directive's ordering says the title outlives the
    /// subtitle. That case is the recorded landscape hard ceiling, whose real fix is a scrolling title
    /// slot; the floor's job is every OTHER shape, where the subtitle was vanishing for no reason at
    /// all.
    ///
    /// Read by BOTH renderers — UIKit installs it as a `>=` on the slot at
    /// `Priority.subtitleSlotFloor`, SwiftUI as the subtitle row's `.frame(minHeight:)` — so the two
    /// cannot protect different amounts of text.
    static func subtitleFloorHeight(font: UIFont) -> CGFloat {
        font.lineHeight
    }

    /// The font `text` actually renders its FIRST line in, falling back to `fallback`.
    ///
    /// The subtitle label is never assigned a `font`: both subtitle paths write an `attributedText`
    /// carrying its own `.font` (the `.plain` path from `Properties.subtitleFont`, the `.attributed`
    /// path from the caller's string). So `UILabel.font` is the 17pt system default and reading it
    /// would measure a line of a font nothing draws — which for the real preset's 16pt subtitle would
    /// reserve a floor slightly TALLER than the line it protects.
    static func renderedFont(_ text: NSAttributedString?, fallback: UIFont) -> UIFont {
        guard let text, text.length > 0,
              let font = text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont else {
            return fallback
        }
        return font
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
    /// **THE ORDER, as the owner stated it:** buttons > title > description (subtitle) > banner.
    /// Everything below is that sentence expressed as numbers. Two things in the table are NOT
    /// content rungs and must not be read as part of that order:
    ///
    /// * `bannerMaxHeight` is a `<=` CAP, not a size driver. A cap held FIRMLY keeps the banner
    ///   SMALL, which protects the text — so it belongs near the top, and lowering it would let a
    ///   banner grow past the size the caller asked for. "The banner yields last" is a statement
    ///   about the constraints that make the banner BIG (`bannerNaturalAspect`, `bannerFixedHeight`,
    ///   `bannerImageIntrinsic`), all of which now sit below every text rung.
    /// * `componentSpacing` is whitespace, which is cheaper than any content.
    ///
    /// Top to bottom, and WHY each rung sits where it does:
    ///
    /// | rung | value | what it is |
    /// | --- | --- | --- |
    /// | `buttonSlotHeight` | **`.required`** | each action slot's `height == 48`. The buttons are
    ///   the one thing on the card that must never shrink: a squeezed button is a broken tap target,
    ///   and a dialog whose action cannot be pressed is worse than one whose text is scrolled. They
    ///   were already `.required` implicitly (a SnapKit constraint with no stated priority); naming
    ///   it puts the top of the ladder in the same table as the rest, where a test can assert it. |
    /// | `bannerMaxHeight` | **950** | `vwBanner.height <= bannerMaxHeight` — the explicit cap a
    ///   caller asked for. A CAP, so high priority means the banner stays small: this is the
    ///   constraint that stops a tall banner eating the card, and it out-ranks every driver below. |
    /// | `titleCompressionResistance` | **900** | `lbTitle`'s vertical resistance. Raised from
    ///   UIKit's 750 default so the title out-ranks EVERY other content rung: it keeps its font
    ///   size and however many lines it needs (`numberOfLines = 0`), and the subtitle is what gives
    ///   way. Deliberately NOT `.required` (1000) — see below. |
    /// | `subtitleSlotFloor` | **850** | `svSubtitleContainer.height >= one line`. Rung 1 says the
    ///   subtitle yields first; this says how far. Without it the slot yields to ZERO and the body
    ///   text does not scroll, it VANISHES — measured on the landscape card, where three of the four
    ///   ordinary shapes were rendering the subtitle sliced in half or not at all.
    ///
    ///   **BELOW the title's 900, and that placement is the whole design.** Above it, the title
    ///   would be the one to give up glyphs whenever the two genuinely cannot both fit — which
    ///   inverts the directive's ordering. Measured on the `longTitle` landscape fixture: the card
    ///   is capped at 214pt (safe area 294 − 40/40 margins), leaving 110pt for title + subtitle, and
    ///   the floor-scaled title alone needs 107.4. At 950 the title lost 23 of 139 glyphs to buy the
    ///   subtitle its line. At 850 the floor is what breaks in that impossible case, and the title
    ///   keeps every glyph — while every shape where the two DON'T conflict still gets its line of
    ///   body text. See `ModalLayout.subtitleFloorHeight`.
    ///
    ///   Above the subtitle LABEL's own 750, so it is the SLOT that holds the line open rather than
    ///   the label refusing to shrink. |
    /// | `componentSpacing` | **800** | the three inter-component GAPS
    ///   (`vwBannerAndBelowDivider`, `vwTitleAndBelowDivider`, `vwSubtitleAndBelowDivider`), each
    ///   `height == space` at this priority under a `<=` cap at `.required`.
    ///
    ///   These used to be `.required` outright, which meant **decorative whitespace outranked every
    ///   word on the card**. Measured on the popup preset in landscape: 16 + 24 = 40pt of gap held
    ///   firm inside a 174pt content budget while the subtitle was squeezed to nothing — the card
    ///   drew a title, a void, and two buttons. The real app reaches exactly this
    ///   (`V2LiveKitOnlineLessonViewController` locks iPhone to landscape and presents two-button
    ///   `popupProperties` dialogs with a banner, title and subtitle).
    ///
    ///   At 800 the gaps sit BELOW the subtitle's floor (850) and the title (900), so a cramped card
    ///   spends its whitespace before it spends its text — but ABOVE nothing else it needs to beat,
    ///   and the `<=` cap stays `.required` so a gap can only ever shrink, never grow past what the
    ///   preset asked for. On any card with room the equality holds exactly and nothing moves. |
    /// | `subtitleCompressionResistance` | **750** | `lbSubtitle`'s vertical resistance — UIKit's
    ///   default, now stated explicitly because the directive's ordering depends on it being BELOW
    ///   the title's. It must stay ABOVE `subtitleSlotHeight` (next row): the label is what refuses
    ///   to shrink, which is what turns "the slot is too short" into SCROLLING instead of into a
    ///   truncated subtitle. |
    /// | `subtitleSlotHeight` | **`.defaultLow`** (250) | `svSubtitleContainer.frameLayoutGuide.height
    ///   == contentLayoutGuide.height`. **This is the SUBTITLE-YIELDS mechanism**: the weakest TEXT
    ///   rung, so when the card cannot fit everything between its margins this equality is what
    ///   breaks, the scroll's visible height shrinks below its content height, and the subtitle
    ///   scrolls — full-size, unshrunk, un-truncated — while the title keeps every line. Bounded
    ///   below by `subtitleSlotFloor`, so it scrolls rather than disappearing. |
    /// | `bannerNaturalAspect` | **245** | `vwBanner.height == vwBanner.width * imageH/imageW`. |
    /// | `bannerFixedHeight` | **243** | `vwBanner.height == bannerFixedHeight`; inert whenever the
    ///   natural-aspect driver is installed (i.e. on the `bannerRatio == nil` path). |
    /// | `bannerImageIntrinsic` | **241** | `ivBanner`'s own vertical resistance, below every other
    ///   content rung so a 2000px-tall image's intrinsic height cannot fight anything. |
    /// | *(the card hug)* | 250 (`.low`) | NOT a rung of this ladder, but the reason the numbers
    ///   above stop where they do. `vwContainer.center == superview` and `svContentContainer`'s
    ///   four `== superview + paddingMax` constraints are all `.low`, and together they are what
    ///   makes the card HUG its content instead of filling the screen. |
    ///
    /// **Why the banner does not simply go below 250 — and a correction to this paragraph's own
    /// numbers, made in Task 6.** The obvious reading of "banner last" is to drop its drivers under
    /// every text rung, and `subtitleSlotHeight` is `.defaultLow` (250) — so the banner lands at
    /// 245ish. This paragraph used to claim the fix was to move `subtitleSlotHeight` UP to 300 and
    /// lift the banner drivers into the 290/280/270 gap that opened above the hug. That never
    /// shipped: `subtitleSlotHeight` is `.defaultLow` (see the table above, itself corrected in
    /// Task 6 from a stale 300/290/280/270), and the banner drivers sit at 245/243/241 — below the
    /// hug, exactly where the "obvious reading" above lands. Measured once, on an earlier ladder, a
    /// 9:16 banner with room to spare in PORTRAIT rendered at 0.625 natural aspect instead of 1.778
    /// because the hug (250) outbid its own aspect driver (245); whether that failure mode still
    /// applies to the numbers that actually ship is not re-derived here.
    /// `BannerGeometryTruthTests` is the source of truth for the geometry the current numbers
    /// produce, not this paragraph's arithmetic.
    ///
    /// **Why the title is 900 and not `.required`.** The card is bounded by `.required` margin
    /// constraints on `vwContainer` and `.required` minimum padding on `svContentContainer`, so a
    /// title taller than the whole card is a genuinely unsatisfiable system. At 1000 Auto Layout
    /// would have to break one of those `.required` constraints and would log
    /// "Unable to simultaneously satisfy constraints"; at 900 it breaks the title's own resistance
    /// instead, which is a normal, silent resolution. 900 is above every other content rung, so the
    /// title still yields LAST — after the subtitle slot (`.defaultLow`, 250), after the banner
    /// (245) and after the banner image (241).
    enum Priority {
        // Computed rather than `static let`: a stored static of a non-`Sendable` type is a Swift 6
        // strict-concurrency error, and `UILayoutPriority`'s conformance is SDK-version-dependent.
        // These are constants either way — there is no state here to share.
        static var buttonSlotHeight: UILayoutPriority { .required }
        static var bannerMaxHeight: UILayoutPriority { UILayoutPriority(950) }
        static var titleCompressionResistance: UILayoutPriority { UILayoutPriority(900) }
        static var subtitleSlotFloor: UILayoutPriority { UILayoutPriority(850) }
        static var componentSpacing: UILayoutPriority { UILayoutPriority(800) }
        static var subtitleCompressionResistance: UILayoutPriority { UILayoutPriority(750) }
        static var subtitleSlotHeight: UILayoutPriority { .defaultLow }
        static var bannerNaturalAspect: UILayoutPriority { UILayoutPriority(245) }
        static var bannerFixedHeight: UILayoutPriority { UILayoutPriority(243) }
        static var bannerImageIntrinsic: UILayoutPriority { UILayoutPriority(241) }
    }
}
