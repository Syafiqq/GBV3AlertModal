import Foundation
import UIKit
import SnapKit

// MARK: - VIEW GRAPH

internal extension GBAlertModal {
    // MARK: Views

    // Internal (extension default): called from `updateDialog` in
    // GBAlertModal+Lifecycle.swift (different file, same module).
    func unregisterDialogView() {
        svContentContainer?.removeAllArrangedSubviews()

        vwBanner?.removeFromSuperview()
        ivBanner?.removeFromSuperview()
        lbTitle?.removeFromSuperview()
        svSubtitleContainer?.removeFromSuperview()
        lbSubtitle?.removeFromSuperview()
        vwSubtitle?.removeFromSuperview()

        vwBannerAndBelowDivider?.removeFromSuperview()
        vwTitleAndBelowDivider?.removeFromSuperview()
        vwSubtitleAndBelowDivider?.removeFromSuperview()

        svMainActionContainer?.removeAllArrangedSubviews()
        svMainActionContainer?.removeFromSuperview()

        vwPrimaryAction?.removeFromSuperview()
        btPrimaryAction?.removeFromSuperview()
        vwSecondaryAction?.removeFromSuperview()
        btSecondaryAction?.removeFromSuperview()

        btCloseAction?.removeFromSuperview()
    }

    // Widened from `private` to `internal`: called from `updateDialog` in
    // GBAlertModal+Lifecycle.swift (different file, same module).
    //
    // Thin orchestrator: build each component (init + own subview wiring), then assemble the
    // stack-view graph, then install constraints — in the exact same order as the original
    // monolith so the produced view tree + constraints are unchanged.
    func registerDialogView() {
        let resolved = makeResolvedModal()

        // MARK: View Initialization
        buildBannerComponent(resolved)
        buildTitleComponent(resolved)
        buildSubtitleComponent(resolved)
        buildActionComponents(resolved)
        buildCloseComponent(resolved)
        buildDividers()

        // MARK: View Graph
        assembleViewGraph()

        // MARK: View Constraints
        installConstraints()
    }

    // MARK: Component Builders

    /// Creates + assigns `vwBanner` / `ivBanner` and nests the image inside the banner view.
    private func buildBannerComponent(_ resolved: ResolvedModal) {
        // Setup banner
        if resolved.showsBanner, let banner = dataHolder?.banner {
            let vwBanner = generateGenericViewDesign()
            let ivBanner = generateImageViewForBannerDesign()
            ivBanner.image = banner

            vwBanner.addSubview(ivBanner)

            self.vwBanner = vwBanner
            self.ivBanner = ivBanner
        } else {
            vwBanner = nil
            ivBanner = nil
        }
    }

    /// Creates + assigns `lbTitle` from either the plain or attributed title source.
    ///
    /// Also records the UNSCALED string in `titleNominalAttributedText` and resets
    /// `titleFontScaleApplied`: rung 2 of the no-truncation ladder scales the title's font as a last
    /// resort, and it must always scale from THIS string. Scaling an already-scaled label would
    /// compound on every layout pass, and a rebuilt title (`updateDialog`) must start at full size.
    private func buildTitleComponent(_ resolved: ResolvedModal) {
        // Setup title
        if resolved.showsTitle {
            if let title = dataHolder?.title,
               !title.isEmpty {
                let lbTitle = generateLabelForTitleDesign()
                let attributed = NSAttributedString(
                        string: title,
                        attributes: [
                            .font: properties?.titleFont,
                            .foregroundColor: properties?.titleColor
                        ].compactMapValues({ $0 })
                )
                lbTitle.attributedText = attributed
                titleNominalAttributedText = attributed
                titleFontScaleApplied = 1
                bindTitleFontScale(lbTitle)
                self.lbTitle = lbTitle
            } else if let title = dataHolder?.titleAttributed,
                      title.length > 0 {
                let lbTitle = generateLabelForTitleDesign()
                lbTitle.attributedText = title
                titleNominalAttributedText = title
                titleFontScaleApplied = 1
                bindTitleFontScale(lbTitle)
                self.lbTitle = lbTitle
            }
        } else {
            lbTitle = nil
            titleNominalAttributedText = nil
            titleFontScaleApplied = 1
        }
    }

    /// Runs rung 2 whenever the title's own frame for a pass has been assigned — the only moment its
    /// granted height (and its sibling subtitle slot's) is current. WEAK capture: the label is owned by
    /// the view graph the modal owns, so a strong capture would be a cycle.
    private func bindTitleFontScale(_ label: ModalTitleLabel) {
        label.onLayout = { [weak self] in
            self?.adjustTitleFontScale()
        }
    }

    /// **One inter-component gap: never taller than the preset asks, shrinkable when the card is
    /// cramped.**
    ///
    /// The three gap dividers used to be a plain `height == space`, i.e. `.required` — so decorative
    /// whitespace out-ranked every word on the card. Measured on the popup preset in landscape: 40pt
    /// of gap held firm inside a 174pt budget while the subtitle was squeezed to nothing, and the card
    /// drew a title, a void and two buttons. That is a real app state, not a synthetic one — the
    /// lesson screens lock iPhone to landscape and present two-button `popupProperties` dialogs.
    ///
    /// The `<=` stays `.required` (a gap may never exceed its design value, so no roomy card changes)
    /// and the `==` drops to `ModalLayout.Priority.componentSpacing`, below the subtitle's floor and
    /// the title. A card with room satisfies the equality exactly; a cramped one spends its
    /// whitespace before it spends its text.
    private func installGapHeight(_ divider: UIView, _ space: CGFloat) {
        divider.snp.makeConstraints { (make: ConstraintMaker) in
            make.height
                    .lessThanOrEqualTo(space)
            make.height
                    .equalTo(space)
                    .priority(ModalLayout.Priority.componentSpacing)
        }
    }

    /// Creates + assigns `svSubtitleContainer` and its inner `lbSubtitle` / `vwSubtitle`,
    /// nesting the resolved subtitle content inside the scroll container.
    private func buildSubtitleComponent(_ resolved: ResolvedModal) {
        // Setup subtitle
        if resolved.subtitle != .none {
            let svSubtitleContainer = generateScrollForCustomViewDesign()
            let vwSubtitle: UIView?
            switch resolved.subtitle {
            case .plain(let subtitle):
                let lbSubtitle = generateLabelForSubtitleDesign()
                lbSubtitle.attributedText = NSAttributedString(
                        string: subtitle,
                        attributes: [
                            .font: properties?.subtitleFont,
                            .foregroundColor: properties?.subtitleColor
                        ].compactMapValues({ $0 })
                )

                vwSubtitle = lbSubtitle
                self.lbSubtitle = lbSubtitle
            case .attributed:
                let lbSubtitle = generateLabelForSubtitleDesign()
                lbSubtitle.attributedText = dataHolder?.subtitleAttributed

                vwSubtitle = lbSubtitle
                self.lbSubtitle = lbSubtitle
            case .custom:
                vwSubtitle = dataHolder?.subtitleCustomView
                self.vwSubtitle = dataHolder?.subtitleCustomView
            case .none:
                vwSubtitle = nil
            }

            if let vwSubtitle {
                svSubtitleContainer.addSubview(vwSubtitle)

                self.svSubtitleContainer = svSubtitleContainer
            }
        } else {
            svSubtitleContainer = nil
            lbSubtitle = nil
            vwSubtitle = nil
        }
    }

    /// Creates + assigns the primary / secondary action views and the main action container
    /// that will host them, in the original init order (primary, secondary, container).
    // swiftlint:disable:next function_body_length
    private func buildActionComponents(_ resolved: ResolvedModal) {
        // Setup primaryAction
        if resolved.showsPrimary,
           let primaryAction = dataHolder?.primaryAction,
           let primaryActionStyle = properties?.primaryActionStyle {
            let vwPrimaryAction = generateGenericViewDesign()

            let btPrimaryAction = generateButtonForActionDesign(style: primaryActionStyle)
            configureButtonActionStyle(btPrimaryAction, title: primaryAction, style: primaryActionStyle)

            vwPrimaryAction.addSubview(btPrimaryAction)

            self.vwPrimaryAction = vwPrimaryAction
            self.btPrimaryAction = btPrimaryAction
        } else {
            vwPrimaryAction = nil
            btPrimaryAction = nil
        }

        // Setup secondaryAction
        if resolved.showsSecondary,
           let secondaryAction = dataHolder?.secondaryAction,
           let secondaryActionStyle = properties?.secondaryActionStyle {
            let vwSecondaryAction = generateGenericViewDesign()

            let btSecondaryAction = generateButtonForActionDesign(style: secondaryActionStyle)
            configureButtonActionStyle(btSecondaryAction, title: secondaryAction, style: secondaryActionStyle)

            vwSecondaryAction.addSubview(btSecondaryAction)

            self.vwSecondaryAction = vwSecondaryAction
            self.btSecondaryAction = btSecondaryAction
        } else {
            vwSecondaryAction = nil
            btSecondaryAction = nil
        }

        // Setup main action container
        if resolved.showsPrimary || resolved.showsSecondary {
            let svMainActionContainer = generateStackViewForMainButtonDesign()
            svMainActionContainer.spacing = properties?.space?.interButton ?? .zero

            self.svMainActionContainer = svMainActionContainer
        } else {
            svMainActionContainer = nil
        }
    }

    /// Creates + assigns `btCloseAction` and adds it directly onto `vwContainer`.
    private func buildCloseComponent(_ resolved: ResolvedModal) {
        // Setup close action
        if resolved.showsCloseButton,
           let vwContainer = vwContainer {
            let btCloseAction = generateButtonForCloseDesign()
            vwContainer.addSubview(btCloseAction)

            self.btCloseAction = btCloseAction
        } else {
            btCloseAction = nil
        }
    }

    /// Creates the inter-component spacer dividers. Each divider's presence depends on which
    /// other components exist, so this runs after all component builders (matching the original
    /// "Setup Divider" block that closed the View Initialization section).
    private func buildDividers() {
        // Setup Divider
        // Setup banner and its below
        if vwBanner != nil,
           lbTitle != nil || svSubtitleContainer != nil || svMainActionContainer != nil {
            let vwBannerAndBelowDivider = generateGenericViewDesign()

            self.vwBannerAndBelowDivider = vwBannerAndBelowDivider
        } else {
            vwBannerAndBelowDivider = nil
        }

        // Setup title and its below
        if lbTitle != nil,
           svSubtitleContainer != nil || svMainActionContainer != nil {
            let vwTitleAndBelowDivider = generateGenericViewDesign()

            self.vwTitleAndBelowDivider = vwTitleAndBelowDivider
        } else {
            vwTitleAndBelowDivider = nil
        }

        // Setup subtitle and its below
        if svSubtitleContainer != nil,
           svMainActionContainer != nil {
            let vwSubtitleAndBelowDivider = generateGenericViewDesign()

            self.vwSubtitleAndBelowDivider = vwSubtitleAndBelowDivider
        } else {
            vwSubtitleAndBelowDivider = nil
        }
    }

    // MARK: View Graph

    /// Wires the arranged-subview hierarchy: actions into the main action container, then the
    /// content rows into `svContentContainer`, in the original compile order.
    private func assembleViewGraph() {
        // Compile View

        [
            vwPrimaryAction,
            vwSecondaryAction
        ]
                .forEach {
                    guard let view = $0 else {
                        return
                    }
                    svMainActionContainer?.addArrangedSubview(view)
                }

        [
            vwBanner,
            vwBannerAndBelowDivider,
            lbTitle,
            vwTitleAndBelowDivider,
            svSubtitleContainer,
            vwSubtitleAndBelowDivider,
            svMainActionContainer
        ]
                .forEach {
                    guard let view = $0 else {
                        return
                    }
                    svContentContainer?.addArrangedSubview(view)
                }
    }

    // MARK: View Constraints

    /// Installs the SnapKit constraints for every built node, in the original constraint order.
    // swiftlint:disable:next function_body_length
    private func installConstraints() {
        // Banner
        // The image's natural-aspect multiplier (bannerRatio == nil path only) is computed once
        // here so both the vwBanner height-driver constraint and the ivBanner fill constraints
        // below can reference it.
        let bannerHeightMultiplier: CGFloat? = {
            guard properties?.bannerRatio == nil,
                  let image = ivBanner?.image else {
                return nil
            }
            return ModalLayout.bannerHeightMultiplier(imageSize: image.size)
        }()
        if let vwBanner {
            vwBanner.snp.makeConstraints { (make: ConstraintMaker) in
                // Pin
                // Natural-aspect height driver (bannerRatio == nil), priority 700. This sizes the
                // banner slot to the image's own aspect (height == width * imageH/imageW). It must
                // sit ABOVE the content-container's vertical content-hugging (`.defaultLow`, 250):
                // that hugging wants the stack as SHORT as possible, so a driver below 250 loses to
                // it and the banner COLLAPSES to a sliver even when there is ample room (verified —
                // dropping this below 250 letterboxes the image into a tiny centered strip). 700 is
                // comfortably above 250 so the banner expands to natural aspect whenever it fits.
                //
                // Yet the banner is decorative and must YIELD to essential content when space is
                // tight: a very tall image (e.g. 200x2000 → multiplier 10) otherwise asks for
                // thousands of points and, inside the margin-bounded card, starves the title and
                // subtitle to zero height. Two things make it yield without lowering this driver
                // (which would trip the collapse above): the title label's vertical compression
                // resistance (900 — `ModalLayout.Priority.titleCompressionResistance`, raised from
                // UIKit's 750 default by the no-truncation directive) out-ranks this 700 driver, and
                // the subtitle scroll's `frameLayoutGuide`-height tie is raised to 749 *only when
                // this natural-aspect path is active* (see the Subtitle block) so it too out-ranks
                // 700. The image view's own intrinsic vertical resistance is separately dropped to
                // 249 (see the ivBanner block) so the raw pixel height can't fight the content
                // either. Every rung named here lives in `ModalLayout.Priority`.
                if let bannerHeightMultiplier {
                    make.height
                            .equalTo(vwBanner.snp.width)
                            .multipliedBy(bannerHeightMultiplier)
                            .priority(ModalLayout.Priority.bannerNaturalAspect)
                }
                if let bannerMaxHeight = properties?.bannerMaxHeight {
                    make.height
                            .lessThanOrEqualTo(bannerMaxHeight)
                            .priority(ModalLayout.Priority.bannerMaxHeight)
                }
                if let bannerFixedHeight = properties?.bannerFixedHeight {
                    make.height
                            .equalTo(bannerFixedHeight)
                            .priority(ModalLayout.Priority.bannerFixedHeight)
                }
            }
        }
        if let ivBanner {
            ivBanner.snp.makeConstraints { (make: ConstraintMaker) in
                if let ratio = properties?.bannerRatio {
                    // Back-compat: bannerRatio provided — EXACT original behavior, unchanged.
                    // Align
                    make.top
                            .equalToSuperview()
                    make.leading
                            .greaterThanOrEqualToSuperview()
                    make.leading
                            .equalToSuperview()
                            .priority(.low)
                    make.center
                            .equalToSuperview()

                    // Pin
                    make.width
                            .equalTo(ivBanner.snp.height)
                            .multipliedBy(ratio)
                } else if bannerHeightMultiplier != nil {
                    // bannerRatio == nil + valid image: fill the card width and let the image's
                    // natural aspect (applied to vwBanner above) size the slot, instead of the
                    // old centered/intrinsic-size behavior.
                    make.top
                            .equalToSuperview()
                    make.leading
                            .equalToSuperview()
                    make.trailing
                            .equalToSuperview()
                    make.bottom
                            .equalToSuperview()

                    // The image view's INTRINSIC pixel height (e.g. 2000pt for a 200x2000 banner)
                    // otherwise fights the content: at UIImageView's default vertical compression
                    // resistance (750) it ties the subtitle LABEL (750) and out-ranks the subtitle
                    // SLOT's height tie, so a very tall image starves the text to zero height
                    // inside the margin-bounded card.
                    // The banner slot is sized by vwBanner's width-multiplier equality (above) and
                    // scaleAspectFit letterboxes the image, so the image view itself must impose no
                    // vertical size — drop its resistance below every content priority.
                    ivBanner.setContentCompressionResistancePriority(
                            ModalLayout.Priority.bannerImageIntrinsic,
                            for: .vertical
                    )
                } else {
                    // bannerRatio == nil and no usable image size (should not happen given
                    // `showsBanner` already gates on a non-zero-size image) — fall back to the
                    // original nil-ratio alignment so we degrade rather than mis-render.
                    make.top
                            .equalToSuperview()
                    make.leading
                            .greaterThanOrEqualToSuperview()
                    make.leading
                            .equalToSuperview()
                            .priority(.low)
                    make.center
                            .equalToSuperview()
                }
            }
        }

        // Banner divider
        if let vwBannerAndBelowDivider {
            installGapHeight(vwBannerAndBelowDivider, properties?.space?.banner ?? .zero)
        }

        // Subtitle
        if let svSubtitleContainer,
           let vwSubtitle = vwSubtitle ?? lbSubtitle {
            vwSubtitle.snp.makeConstraints { (make: ConstraintMaker) in
                make.edges
                        .equalTo(svSubtitleContainer.contentLayoutGuide)
                make.width
                        .equalTo(svSubtitleContainer.frameLayoutGuide)
                // Tie the scroll's VISIBLE (frame) height to its content height so the subtitle
                // keeps its intrinsic height rather than collapsing to a zero-height scroll slot,
                // while still yielding (shrink-and-scroll) to `.required` so a subtitle taller than
                // the card can't force the card past its margins.
                //
                // **This tie IS the subtitle-yields mechanism the owner directive builds on** —
                // "title will still live while subtitle begin to wrap". It is the weakest content
                // rung in `ModalLayout.Priority`, strictly below both the subtitle LABEL's own
                // resistance (750) and the title's (900), so it is the first thing to break when the
                // card runs out of height: the scroll's visible height drops below its content
                // height and the subtitle scrolls at full size, while the title keeps every line.
                //
                // Priority is conditional on the banner path:
                //  • `.low` (250) by default — the baseline. Under a tight (e.g. landscape) card
                //    the subtitle is then the weakest content and shrink-and-scrolls to fit, which
                //    is the recorded behavior of every non-natural-aspect dialog. Raising it
                //    globally would stop that compression and diff those landscape snapshots.
                //  • 749 when the natural-aspect banner path is active (`bannerHeightMultiplier`
                //    non-nil, i.e. bannerRatio == nil with a valid image). There the decorative
                //    banner's height driver sits at 700 (see the Banner block); the subtitle must
                //    out-rank it so a very tall banner yields to the subtitle instead of starving
                //    it to zero height. Still below `.required` (1000) so an over-tall subtitle
                //    keeps shrinking-and-scrolling. Scoping the bump to this path leaves every
                //    ratio-banner / bannerless dialog at `.low`, so their snapshots don't move.
                make.height
                        .equalTo(svSubtitleContainer.frameLayoutGuide)
                        .priority(
                                bannerHeightMultiplier != nil
                                        ? ModalLayout.Priority.subtitleSlotHeightOverBanner
                                        : ModalLayout.Priority.subtitleSlotHeight
                        )
            }

            // **And the floor on that yield.** The tie above is what lets the slot shrink; nothing
            // stopped it shrinking to ZERO, which is what the landscape card did — the subtitle was
            // not scrolled, it was gone (measured: 0.0pt with a banner, 9.3pt on the two-button
            // shape, i.e. a line sliced in half by the button below it).
            //
            // At 850: above the slot's own height tie (250/749) and above the subtitle label's 750,
            // so it holds the line open; but BELOW the title's 900, so on the one landscape shape
            // where the two genuinely cannot both fit, this is what gives way and the title keeps
            // every glyph. Inert whenever the tie above holds, since a non-empty label is already at
            // least one line tall. See `ModalLayout.subtitleFloorHeight`.
            let floor = subtitleSlotFloorHeight
            if floor > 0 {
                svSubtitleContainer.snp.makeConstraints { (make: ConstraintMaker) in
                    make.height
                            .greaterThanOrEqualTo(floor)
                            .priority(ModalLayout.Priority.subtitleSlotFloor)
                }
            }
        }

        // Title Divider
        if let vwTitleAndBelowDivider {
            installGapHeight(vwTitleAndBelowDivider, properties?.space?.title ?? .zero)
        }

        // Subtitle Divider
        if let vwSubtitleAndBelowDivider {
            installGapHeight(vwSubtitleAndBelowDivider, properties?.space?.subtitle ?? .zero)
        }

        // Primary Action
        if let vwPrimaryAction,
           let btPrimaryAction,
           let primaryActionStyle = properties?.primaryActionStyle {
            configureButtonActionConstraint(btPrimaryAction, parent: vwPrimaryAction, style: primaryActionStyle)
        }

        // Secondary Action
        if let vwSecondaryAction,
           let btSecondaryAction,
           let secondaryActionStyle = properties?.secondaryActionStyle {
            configureButtonActionConstraint(btSecondaryAction, parent: vwSecondaryAction, style: secondaryActionStyle)
        }

        // Close Action
        if let btCloseAction {
            btCloseAction.snp.makeConstraints { (make: ConstraintMaker) in
                make.top.trailing
                        .equalToSuperview()
                make.size
                        .equalTo(48)
                make.leading
                        .greaterThanOrEqualToSuperview()
                make.bottom
                        .lessThanOrEqualToSuperview()
            }
        }

        // Title wrap width. Not a SnapKit constraint but the same kind of fact — the width the title
        // label must measure its own height against (`preferredMaxLayoutWidth`), taken from the same
        // resolved content width that sizes `svContentContainer` above. Stated HERE, at build time, so
        // the very FIRST layout pass measures the title at the width it will actually have; without it
        // the label reports the height of the text wrapped at whatever width an earlier pass gave it —
        // the card's, not the content's — and silently drops the lines that no longer fit. The full
        // evidence and the reason this is preset-derived rather than bounds-derived are on
        // `adjustTitleWrapWidth`. `layoutSubviews` re-applies it (rotation, `updateDialog`).
        adjustTitleWrapWidth()
    }
}
