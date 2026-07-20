import Foundation
import UIKit
import SnapKit

// MARK: - VIEW GRAPH

internal extension GBAlertModal {
    // MARK: Views

    // Widened from `private` to `internal`: called from `updateDialog` in
    // GBAlertModal+Lifecycle.swift (different file, same module).
    internal func unregisterDialogView() {
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
    internal func registerDialogView() {
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
    private func buildTitleComponent(_ resolved: ResolvedModal) {
        // Setup title
        if resolved.showsTitle {
            if let title = dataHolder?.title,
               !title.isEmpty {
                let lbTitle = generateLabelForTitleDesign()
                lbTitle.attributedText = NSAttributedString(
                        string: title,
                        attributes: [
                            .font: properties?.titleFont,
                            .foregroundColor: properties?.titleColor
                        ].compactMapValues({ $0 })
                )
                self.lbTitle = lbTitle
            } else if let title = dataHolder?.titleAttributed,
                      title.length > 0 {
                let lbTitle = generateLabelForTitleDesign()
                lbTitle.attributedText = title
                self.lbTitle = lbTitle
            }
        } else {
            lbTitle = nil
        }
    }

    /// Creates + assigns `svSubtitleContainer` and its inner `lbSubtitle` / `vwSubtitle`,
    /// nesting the resolved subtitle content inside the scroll container.
    private func buildSubtitleComponent(_ resolved: ResolvedModal) {
        // Setup subtitle
        if dataHolder?.subtitle != nil ||
                   dataHolder?.subtitleAttributed != nil ||
                   dataHolder?.subtitleCustomView != nil {
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
        if let vwBanner {
            vwBanner.snp.makeConstraints { (make: ConstraintMaker) in
                // Pin
                if let bannerMaxHeight = properties?.bannerMaxHeight {
                    make.height
                            .lessThanOrEqualTo(bannerMaxHeight)
                            .priority(UILayoutPriority(751))
                }
                if let bannerFixedHeight = properties?.bannerFixedHeight {
                    make.height
                            .equalTo(bannerFixedHeight)
                            .priority(UILayoutPriority(251))
                }
            }
        }
        if let ivBanner {
            ivBanner.snp.makeConstraints { (make: ConstraintMaker) in
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
                if let ratio = properties?.bannerRatio {
                    make.width
                            .equalTo(ivBanner.snp.height)
                            .multipliedBy(ratio)
                }
            }
        }

        // Banner divider
        if let vwBannerAndBelowDivider {
            vwBannerAndBelowDivider.snp.makeConstraints { (make: ConstraintMaker) in
                make.height
                        .equalTo(properties?.space?.banner ?? .zero)
            }
        }

        // Subtitle
        if let svSubtitleContainer,
           let vwSubtitle = vwSubtitle ?? lbSubtitle {
            vwSubtitle.snp.makeConstraints { (make: ConstraintMaker) in
                make.edges
                        .equalTo(svSubtitleContainer.contentLayoutGuide)
                make.width
                        .equalTo(svSubtitleContainer.frameLayoutGuide)
                make.height
                        .equalTo(svSubtitleContainer.frameLayoutGuide)
                        .priority(.low)
            }
        }

        // Title Divider
        if let vwTitleAndBelowDivider {
            vwTitleAndBelowDivider.snp.makeConstraints { (make: ConstraintMaker) in
                make.height
                        .equalTo(properties?.space?.title ?? .zero)
            }
        }

        // Subtitle Divider
        if let vwSubtitleAndBelowDivider {
            vwSubtitleAndBelowDivider.snp.makeConstraints { (make: ConstraintMaker) in
                make.height
                        .equalTo(properties?.space?.subtitle ?? .zero)
            }
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
    }
}
