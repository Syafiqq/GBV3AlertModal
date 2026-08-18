import GBV3AlertModalCore

import Foundation
import UIKit
import SnapKit

// MARK: - LAYOUT

extension GBAlertModal {
    // Moved verbatim from GBAlertModal.swift (Task 6). Implicitly `internal` (the extension's
    // default, same as the original's explicit `internal` inside a `private extension`): called
    // from `updateDialog` in GBAlertModal+Lifecycle.swift and from `initViews` in
    // GBAlertModal+Model.swift (different files, same module).
    func adjustBaseDialogConstraint() {
        if let vwContainer = vwContainer {
            adjustVwContainerConstraint(vwContainer)
        }
        if let svContentContainer = svContentContainer {
            adjustSvContentContainerConstraint(svContentContainer)
        }
    }

    // Moved verbatim from GBAlertModal.swift (Task 6). Implicitly `internal`: called from
    // `initDesign` in GBAlertModal+ViewFactory.swift (different file, same module), plus
    // `adjustBaseDialogConstraint` above. The four inset offsets are now resolved by
    // `ModalLayout.resolveContainerOffsets(margin:)` (pure, unit-tested); the SnapKit application
    // stays here.
    func adjustVwContainerConstraint(_ vwContainer: UIView) {
        let offsets = ModalLayout.resolveContainerOffsets(margin: properties?.margin)
        vwContainer.snp.remakeConstraints { (make: ConstraintMaker) in
            // Align
            make.top
                    .greaterThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(offsets.top)
            make.leading
                    .greaterThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(offsets.leading)
            make.bottom
                    .lessThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(offsets.bottom)
            make.trailing
                    .lessThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(offsets.trailing)

            make.center
                    .equalToSuperview()
                    .priority(.low)
        }
    }

    // Moved verbatim from GBAlertModal.swift (Task 6). Implicitly `internal`: called from
    // `initDesign` in GBAlertModal+ViewFactory.swift (different file, same module), plus
    // `adjustBaseDialogConstraint` above. The eight inset offsets are now resolved by
    // `ModalLayout.resolveContentPadding(padding:)` (pure, unit-tested); the SnapKit application
    // stays here.
    // swiftlint:disable:next function_body_length
    func adjustSvContentContainerConstraint(_ svContentContainer: UIView) {
        let padding = ModalLayout.resolveContentPadding(padding: properties?.padding)
        svContentContainer.snp.remakeConstraints { (make: ConstraintMaker) in
            make.top
                    .greaterThanOrEqualToSuperview()
                    .offset(padding.topMin)
            make.top
                    .equalToSuperview()
                    .offset(padding.topMax)
                    .priority(.low)

            make.leading
                    .greaterThanOrEqualToSuperview()
                    .offset(padding.leadingMin)
            make.leading
                    .equalToSuperview()
                    .offset(padding.leadingMax)
                    .priority(.low)

            make.bottom
                    .lessThanOrEqualToSuperview()
                    .offset(padding.bottomMin)
            make.bottom
                    .equalToSuperview()
                    .offset(padding.bottomMax)
                    .priority(.low)

            make.trailing
                    .lessThanOrEqualToSuperview()
                    .offset(padding.trailingMin)
            make.trailing
                    .equalToSuperview()
                    .offset(padding.trailingMax)
                    .priority(.low)

            make.center
                    .equalToSuperview()
                    .priority(.low)

            // Pin
            let (fixedWidth, maxWidth) = resolvedContentWidths()
            if let fixedWidth {
                make.width
                        .equalTo(fixedWidth)
                        .priority(.medium)
            }
            if let maxWidth {
                make.width
                        .lessThanOrEqualTo(maxWidth)
                        .priority(.high)
            }
        }
    }

    // Moved verbatim from GBAlertModal.swift (Task 6). Implicitly `internal`: called from
    // `layoutSubviews` in GBAlertModal+Lifecycle.swift (different file, same module).
    func adjustSvContentContainerConstraintWidth(_ svContentContainer: UIView) {
        svContentContainer.snp.updateConstraints { (make: ConstraintMaker) in
            // Pin
            let (fixedWidth, maxWidth) = resolvedContentWidths()
            if let fixedWidth {
                make.width
                        .equalTo(fixedWidth)
                        .priority(.medium)
            }
            if let maxWidth {
                make.width
                        .lessThanOrEqualTo(maxWidth)
                        .priority(.high)
            }
        }

        // The same number the container is being sized with is the number the title wraps at. Called
        // from here (i.e. from `layoutSubviews`) as well as at build time so a ROTATION — which flips
        // `resolvedContentWidths` between the portrait and landscape readings — re-wraps the title.
        adjustTitleWrapWidth()
    }

    /// **The width the TITLE wraps at, stated instead of inferred — the fix for a multi-line title
    /// that silently dropped lines.**
    ///
    /// `UILabel.intrinsicContentSize` for a `numberOfLines = 0` label is only meaningful once the
    /// label knows how wide it will be, and the channel for that is `preferredMaxLayoutWidth`. Left at
    /// its `0` default, UIKit fills it in during layout FROM THE LABEL'S CURRENT BOUNDS — so the height
    /// the label reports is the height of the text wrapped at whatever width some EARLIER layout pass
    /// happened to give it, and nothing re-measures it once the content container narrows the label to
    /// the preset's width. The measured evidence, three independent readings, all "the CARD's width
    /// rather than the CONTENT's":
    ///
    /// | fixture | card width | UIKit reported | correct at 256 |
    /// | --- | --- | --- | --- |
    /// | `streak-popup-banner` title (≈273pt wide) | 320 | 28.7 = **1 line** | 57.3 = 2 lines |
    /// | 121-char title, portrait host | ~350 | 143.3 = **5 lines** | 172.0 = 6 lines |
    /// | 121-char title, landscape host | ~804 | 57.3 = **2 lines** | 172.0 = 6 lines |
    ///
    /// This was invisible until the no-truncation directive: with `numberOfLines = 2` +
    /// `adjustsFontSizeToFitWidth` the label reported ONE shrunken line whatever its width, so a wrong
    /// wrap width could not change the answer. The moment the title was allowed to wrap, a stale wrap
    /// width started SILENTLY DROPPING LINES — which reads exactly like truncation (the tail glyphs are
    /// never laid out) even though nothing in the constraint graph is capping the label and its
    /// compression resistance is 900. **Resistance cannot defend a wrong intrinsic size**: Auto Layout
    /// was faithfully giving the label the height it asked for.
    ///
    /// So the wrap width is taken from the SAME resolved content width that sizes `svContentContainer`,
    /// which — with `childShouldMatchParent` (`svContentContainer.alignment == .fill`) — IS the label's
    /// width. It is a PRESET-derived constant, not a reading of the label's own bounds: that matters,
    /// because a bounds-derived `preferredMaxLayoutWidth` set from inside `layoutSubviews` feeds back
    /// into the intrinsic WIDTH whenever the stack is `.center`-aligned, and shrink-wraps a little
    /// further on every pass. A constant cannot oscillate, and the `> 0.5` guard makes this idempotent
    /// so the second pass invalidates nothing and the layout settles.
    ///
    /// Under `.center` alignment the label hugs, so this acts as a wrap CEILING (`<= 256`) rather than
    /// the exact width — which is the correct reading of the preset either way.
    ///
    /// **Not applied to `lbSubtitle`, deliberately.** The subtitle's width comes from a direct
    /// `width == svSubtitleContainer.frameLayoutGuide` constraint and it demonstrably already wraps at
    /// the content width: all nine differential shapes agree with SwiftUI on the subtitle row, and the
    /// height-pressured landscape case lays out every subtitle glyph. Setting the same value there
    /// would be an unmeasured change to a row that is currently correct.
    ///
    /// **When the preset states no width at all** (`WidthResolution.flexible`) this does nothing and
    /// `preferredMaxLayoutWidth` stays `0`, i.e. UIKit's own multi-pass convergence — unchanged
    /// behaviour for a configuration no Genie preset uses, and the one case where a bounds-derived
    /// value would be the only source of truth and could feed back on itself.
    func adjustTitleWrapWidth() {
        guard let lbTitle else {
            return
        }
        let (fixedWidth, maxWidth) = resolvedContentWidths()
        let wrapWidth: CGFloat?
        switch (fixedWidth, maxWidth) {
        case let (fixed?, max?):
            // The `<= max` sits at `.high` and the `== fixed` at `.medium`, so the effective width can
            // never exceed the smaller of the two.
            wrapWidth = Swift.min(fixed, max)
        case let (fixed?, nil):
            wrapWidth = fixed
        case let (nil, max?):
            wrapWidth = max
        case (nil, nil):
            wrapWidth = nil
        }
        guard let wrapWidth,
              wrapWidth > 0,
              abs(lbTitle.preferredMaxLayoutWidth - wrapWidth) > 0.5 else {
            return
        }
        lbTitle.preferredMaxLayoutWidth = wrapWidth
        lbTitle.invalidateIntrinsicContentSize()
    }

    // MARK: - Rung 2: the title shrinks rather than truncating

    /// **The title's LAST resort: shrink the font, never drop a glyph.**
    ///
    /// The owner's ladder, in full, and this method is only the middle rung:
    ///
    /// * **Rung 1 — the SUBTITLE yields.** Pure Auto Layout, nothing here: the title's 900 vertical
    ///   compression resistance beats the subtitle slot's `frame == content` tie (`.defaultLow`,
    ///   250, unconditionally), so an over-tall card shrinks the subtitle's visible height and it
    ///   scrolls. Most pressure never reaches rung 2 at all.
    /// * **Rung 2 — the TITLE shrinks** (this method), once rung 1 has nothing left to give. Down to
    ///   `ModalLayout.titleMinimumScaleFactor` (0.75), on a coarse grid, keeping `numberOfLines = 0`
    ///   throughout — so the text RE-WRAPS at the smaller size and every glyph survives.
    /// * **Rung 3 — there is none.** Below the floor the title stops shrinking and keeps all of its
    ///   text; whatever still does not fit is the layout's problem, not the string's.
    ///
    /// **Why this is computed rather than delegated to `adjustsFontSizeToFitWidth`.** That property is
    /// the old ladder's shrink rung, it is documented against the label's line count, and with
    /// `numberOfLines = 0` a label never overflows its WIDTH — it wraps — so there is nothing there to
    /// trigger it. What we need is a fit against the available HEIGHT, which UIKit does not offer.
    ///
    /// **The budget: `title + subtitle` heights, and that choice is the whole design.** The available
    /// height is read as the title's own laid-out height PLUS whatever the subtitle slot still holds —
    /// i.e. "everything the title could claim if the subtitle surrendered the lot", which is precisely
    /// rung 1 followed by rung 2. It also makes the computation a FIXED POINT, which a naive reading
    /// of `lbTitle.bounds.height` alone is not:
    ///
    /// * shrinking the title hands its freed points to the subtitle slot, so the SUM is unchanged and
    ///   the next pass computes the same scale and assigns nothing — the layout settles;
    /// * reading the title's height alone would instead see it "fitting exactly" at every scale (the
    ///   label always gets its own intrinsic height once it is small enough), so the title could never
    ///   grow back — a one-way ratchet that would survive a rotation back into portrait.
    ///
    /// Combined with the 0.05 quantisation and the `titleFontScaleApplied` equality guard, that is
    /// what makes it safe to run this during layout: a stable input, a quantised output, and no
    /// assignment when the answer has not changed — so a settled layout stops instead of looping.
    ///
    /// **Driven from `ModalTitleLabel.onLayout`**, i.e. from the title's OWN `layoutSubviews`, which is
    /// the first moment its granted height (and its sibling subtitle slot's) is this pass's value
    /// rather than the previous one's. `GBAlertModal.layoutSubviews` calls it too, as a safety net for
    /// a pass in which the title's frame did not change but its budget did. See `ModalTitleLabel`.
    func adjustTitleFontScale() {
        guard let lbTitle,
              let nominal = titleNominalAttributedText,
              nominal.length > 0 else {
            return
        }
        // The width the title wraps at — the same number `adjustTitleWrapWidth` gave the label. Its
        // own bounds are the fallback for the flexible-width presets that set no content width.
        let width = lbTitle.preferredMaxLayoutWidth > 0 ? lbTitle.preferredMaxLayoutWidth : lbTitle.bounds.width
        // The FULL budget — the subtitle's one-line floor is deliberately NOT subtracted here.
        //
        // It was, briefly, on the reasoning that the title should not plan to use points the floor
        // holds back. That was wrong, and measurably so: the floor sits BELOW the title's compression
        // resistance (`Priority.subtitleSlotFloor`, 850 against 900), so when the two genuinely cannot
        // both fit it is the FLOOR that breaks, not the title. Subtracting it made the title budget
        // for a conflict it always wins — on the `longTitle` landscape fixture that cost 23 of 139
        // glyphs to protect a line the constraint system then gave away anyway.
        let available = lbTitle.bounds.height + (svSubtitleContainer?.bounds.height ?? .zero)
        guard width > 0,
              available > 0 else {
            return
        }

        let scale = ModalLayout.titleFontScale(availableHeight: available) { candidate in
            ModalLayout.textHeight(Self.scaled(nominal, by: candidate), width: width)
        }

        // Idempotence: no assignment, no `invalidateIntrinsicContentSize`, no further layout pass.
        guard abs(scale - titleFontScaleApplied) > 0.001 else {
            return
        }
        titleFontScaleApplied = scale
        lbTitle.attributedText = Self.scaled(nominal, by: scale)
        // `UILabel.font` is only the DEFAULT for ranges the attributed string does not style, so it is
        // kept in step for the case where `Properties.titleFont` was nil and no `.font` attribute was
        // written at all. It is also what a test can read back to see the rendered point size.
        //
        // Both title paths in this library produce a SINGLE-font string (the plain path writes one
        // `.font` attribute over the whole range; the attributed path takes the caller's). A caller
        // passing a MULTI-font `titleAttributed` is still scaled correctly by the line above — this
        // assignment only moves the default underneath it.
        if let nominalFont = properties?.titleFont {
            lbTitle.font = scale < 1 ? nominalFont.withSize(nominalFont.pointSize * scale) : nominalFont
        }
        lbTitle.invalidateIntrinsicContentSize()
    }

    /// **The one line the subtitle slot never gives up — computed once, read twice.**
    ///
    /// `installConstraints` installs it as a `>=` on `svSubtitleContainer` and `adjustTitleFontScale`
    /// subtracts it from the title's budget. They MUST be the same number: a constraint holding back
    /// points the font search believes are available is precisely how the title ends up clipped.
    ///
    /// Zero when there is no subtitle LABEL — the `.custom` subtitle path puts a caller's view in the
    /// slot, and "one line" is not a fact about an arbitrary view. That path keeps exactly today's
    /// behaviour (and today's snapshots) rather than inheriting a floor invented for text.
    var subtitleSlotFloorHeight: CGFloat {
        guard let lbSubtitle else {
            return .zero
        }
        return ModalLayout.subtitleFloorHeight(
                font: ModalLayout.renderedFont(lbSubtitle.attributedText, fallback: lbSubtitle.font)
        )
    }

    /// `text` with every `.font` attribute scaled by `scale`. Returns the input unchanged at scale 1,
    /// so the full-size path allocates nothing.
    ///
    /// The ranges are collected BEFORE anything is written: mutating attributes inside
    /// `enumerateAttribute` over the same storage is a documented way to invalidate the enumeration.
    /// Ranges with no font attribute are left alone — they render in `UILabel.font`, which is scaled
    /// separately by the caller.
    static func scaled(_ text: NSAttributedString, by scale: CGFloat) -> NSAttributedString {
        guard scale < 1 else {
            return text
        }
        let whole = NSRange(location: 0, length: text.length)
        var fonts: [(NSRange, UIFont)] = []
        text.enumerateAttribute(.font, in: whole, options: []) { value, range, _ in
            guard let font = value as? UIFont else {
                return
            }
            fonts.append((range, font))
        }

        let scaledText = NSMutableAttributedString(attributedString: text)
        scaledText.beginEditing()
        for (range, font) in fonts {
            scaledText.addAttribute(.font, value: font.withSize(font.pointSize * scale), range: range)
        }
        scaledText.endEditing()
        return scaledText
    }

    /// The fixed / max content-width constraints to apply. Moved verbatim from
    /// GBAlertModal.swift (Task 6), except the switch over `WidthResolution` itself is now
    /// `ModalLayout.resolveContentWidths(_:)` (pure, unit-tested) — this wrapper just supplies the
    /// live `makeResolvedModal().contentWidth` input. Stays `private`: only used by the two
    /// adjust* methods above, in this same file.
    private func resolvedContentWidths() -> (fixed: CGFloat?, max: CGFloat?) {
        ModalLayout.resolveContentWidths(makeResolvedModal().contentWidth)
    }
}
