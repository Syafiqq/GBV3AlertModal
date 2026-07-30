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

    /// The fixed / max content-width constraints to apply. Moved verbatim from
    /// GBAlertModal.swift (Task 6), except the switch over `WidthResolution` itself is now
    /// `ModalLayout.resolveContentWidths(_:)` (pure, unit-tested) — this wrapper just supplies the
    /// live `makeResolvedModal().contentWidth` input. Stays `private`: only used by the two
    /// adjust* methods above, in this same file.
    private func resolvedContentWidths() -> (fixed: CGFloat?, max: CGFloat?) {
        ModalLayout.resolveContentWidths(makeResolvedModal().contentWidth)
    }
}
