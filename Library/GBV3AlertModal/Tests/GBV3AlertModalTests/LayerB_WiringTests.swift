import XCTest
import UIKit
@testable import GBV3AlertModal

/// Layer B: public-surface wiring coverage.
///
/// One assert per public config field / method: does it actually reach the view property
/// (or behavior) it's documented to control? No snapshots — either a direct view-property
/// assert (after `renderForSnapshot`) or a behavioral assert (state change / callback firing).
final class LayerB_WiringTests: XCTestCase {
    let portrait = CGSize(width: 390, height: 844)

    // MARK: - Small helpers

    /// `ActionType` isn't `Equatable` in the library, so compare with pattern matching instead
    /// of pulling in a retroactive conformance from the test target.
    private func assertAction(_ actual: GBAlertModal.ActionType?, is expected: GBAlertModal.ActionType, file: StaticString = #filePath, line: UInt = #line) {
        switch (actual, expected) {
        case (.primary?, .primary), (.secondary?, .secondary), (.close?, .close):
            return
        default:
            XCTFail("expected \(expected), got \(String(describing: actual))", file: file, line: line)
        }
    }

    private func constraint(
        in view: UIView,
        firstItem: AnyObject,
        attribute: NSLayoutConstraint.Attribute,
        relation: NSLayoutConstraint.Relation? = nil
    ) -> NSLayoutConstraint? {
        view.constraints.first {
            $0.firstItem === firstItem
                && $0.firstAttribute == attribute
                && (relation == nil || $0.relation == relation!)
        }
    }

    // MARK: - Properties: baseTint, overlayColor

    func test_baseTintAppliedToModalTintColor() {
        let props = GeniePresets.standardProperties().copy(baseTint: .systemPurple)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.tintColor, .systemPurple)
    }

    func test_overlayColorAppliedToOverlayView() {
        let props = GeniePresets.standardProperties().copy(overlayColor: .systemPink)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.vwOverlay?.backgroundColor, .systemPink)
    }

    // MARK: - Properties.contentProperty: cornerRadius, backgroundColor, childShouldMatchParent

    func test_contentCornerRadiusAppliedToContainer() {
        let cp = GBAlertModal.Properties.ContentProperty(cornerRadius: 37)
        let props = GeniePresets.standardProperties().copy(contentProperty: cp)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.vwContainer?.layer.cornerRadius, 37)
    }

    func test_contentBackgroundColorAppliedToContainer() {
        let cp = GBAlertModal.Properties.ContentProperty(backgroundColor: .systemTeal)
        let props = GeniePresets.standardProperties().copy(contentProperty: cp)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.vwContainer?.backgroundColor, .systemTeal)
    }

    func test_childShouldMatchParentTrue_stackAlignmentFill() {
        let cp = GBAlertModal.Properties.ContentProperty(childShouldMatchParent: true)
        let props = GeniePresets.standardProperties().copy(contentProperty: cp)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.svContentContainer?.alignment, .fill)
    }

    func test_childShouldMatchParentFalse_stackAlignmentCenter() {
        let cp = GBAlertModal.Properties.ContentProperty(childShouldMatchParent: false)
        let props = GeniePresets.standardProperties().copy(contentProperty: cp)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.svContentContainer?.alignment, .center)
    }

    /// contentProperty's 4 width fields (fixedWidthPortrait/maxWidthPortrait/fixedWidthLandscape/
    /// maxWidthLandscape) are exhaustively covered at the resolver level by
    /// `LayerA_ResolverTests.test_resolve_contentWidth_*` (12 tests). This one integration test
    /// additionally proves the resolved `.fixed` width actually reaches a real width constraint
    /// on the rendered content container. (Asserting the *constraint constant* rather than the
    /// final resolved `frame.width` deliberately: the fixed-width constraint is only
    /// `.priority(.medium)`, so the laid-out frame can legitimately end up wider than the
    /// requested value once content compression resistance is in the mix — that's correct
    /// Auto Layout behavior, not a wiring defect, and asserting on it would make this test flaky.)
    func test_contentFixedWidth_appliedAsWidthConstraintOnContentContainer() {
        let cp = GBAlertModal.Properties.ContentProperty(fixedWidthPortrait: 222, fixedWidthLandscape: 222)
        let props = GeniePresets.standardProperties().copy(contentProperty: cp)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)
        guard let sv = modal.svContentContainer else {
            XCTFail("expected svContentContainer")
            return
        }
        let c = sv.constraints.first { $0.firstItem === sv && $0.firstAttribute == .width && $0.secondItem == nil }
        XCTAssertEqual(c?.constant, 222)
    }

    // MARK: - Properties: margin, padding (constraint-constant introspection — no snapshot)

    func test_marginAppliedToContainerConstraints() {
        let margin = UIEdgeInsets(top: 11, left: 22, bottom: 33, right: 44)
        let props = GeniePresets.standardProperties().copy(margin: margin)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)

        guard let vwContainer = modal.vwContainer else {
            XCTFail("expected vwContainer")
            return
        }
        XCTAssertEqual(constraint(in: modal, firstItem: vwContainer, attribute: .top, relation: .greaterThanOrEqual)?.constant, 11)
        XCTAssertEqual(constraint(in: modal, firstItem: vwContainer, attribute: .leading, relation: .greaterThanOrEqual)?.constant, 22)
        XCTAssertEqual(constraint(in: modal, firstItem: vwContainer, attribute: .bottom, relation: .lessThanOrEqual)?.constant, -33)
        XCTAssertEqual(constraint(in: modal, firstItem: vwContainer, attribute: .trailing, relation: .lessThanOrEqual)?.constant, -44)
    }

    func test_paddingAppliedToContentContainerConstraints() {
        let padding = UIMinMaxEdgeInsets(top: (10, 20), left: (11, 21), bottom: (12, 22), right: (13, 23))
        let props = GeniePresets.standardProperties().copy(padding: padding)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)

        guard let vwContainer = modal.vwContainer, let sv = modal.svContentContainer else {
            XCTFail("expected vwContainer/svContentContainer")
            return
        }
        XCTAssertEqual(constraint(in: vwContainer, firstItem: sv, attribute: .top, relation: .greaterThanOrEqual)?.constant, 10)
        XCTAssertEqual(constraint(in: vwContainer, firstItem: sv, attribute: .leading, relation: .greaterThanOrEqual)?.constant, 11)
        XCTAssertEqual(constraint(in: vwContainer, firstItem: sv, attribute: .bottom, relation: .lessThanOrEqual)?.constant, -12)
        XCTAssertEqual(constraint(in: vwContainer, firstItem: sv, attribute: .trailing, relation: .lessThanOrEqual)?.constant, -13)
    }

    // MARK: - Properties: bannerRatio, bannerMaxHeight, bannerFixedHeight

    func test_bannerRatioAppliedAsWidthHeightMultiplier() {
        let props = GeniePresets.standardProperties().copy(bannerRatio: 2.5)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.withBanner())
        _ = renderForSnapshot(modal, size: portrait)

        guard let ivBanner = modal.ivBanner else {
            XCTFail("expected ivBanner")
            return
        }
        let ratioConstraint = ivBanner.constraints.first {
            $0.firstItem === ivBanner && $0.firstAttribute == .width && $0.secondAttribute == .height
        }
        XCTAssertEqual(ratioConstraint?.multiplier, 2.5)
    }

    func test_bannerMaxHeightAppliedAsHeightConstraint() {
        let props = GeniePresets.standardProperties().copy(bannerMaxHeight: 123)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.withBanner())
        _ = renderForSnapshot(modal, size: portrait)

        guard let vwBanner = modal.vwBanner else {
            XCTFail("expected vwBanner")
            return
        }
        let c = vwBanner.constraints.first { $0.firstAttribute == .height && $0.relation == .lessThanOrEqual }
        XCTAssertEqual(c?.constant, 123)
    }

    func test_bannerFixedHeightAppliedAsHeightConstraint() {
        let props = GeniePresets.standardProperties().copy(bannerFixedHeight: 77)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.withBanner())
        _ = renderForSnapshot(modal, size: portrait)

        guard let vwBanner = modal.vwBanner else {
            XCTFail("expected vwBanner")
            return
        }
        let c = vwBanner.constraints.first { $0.firstAttribute == .height && $0.relation == .equal && $0.secondItem == nil }
        XCTAssertEqual(c?.constant, 77)
    }

    // MARK: - Properties: titleFont/titleColor, subtitleFont/subtitleColor

    func test_titleFontApplied() {
        let props = GeniePresets.standardProperties().copy(titleFont: .systemFont(ofSize: 42))
        let modal = GBAlertModal(properties: props, holder: GeniePresets.twoButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.lbTitle?.font.pointSize, 42)
    }

    func test_titleColorApplied() {
        let props = GeniePresets.standardProperties().copy(titleColor: .systemGreen)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.twoButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.lbTitle?.textColor, .systemGreen)
    }

    func test_subtitleFontApplied() {
        let props = GeniePresets.standardProperties().copy(subtitleFont: .systemFont(ofSize: 42))
        let modal = GBAlertModal(properties: props, holder: GeniePresets.twoButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.lbSubtitle?.font.pointSize, 42)
    }

    func test_subtitleColorApplied() {
        let props = GeniePresets.standardProperties().copy(subtitleColor: .systemOrange)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.twoButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.lbSubtitle?.textColor, .systemOrange)
    }

    // MARK: - Properties: buttonActionShouldMatchParent, buttonActionOrientation (rendered view)
    // (structural correctness of these two already exhaustively covered by LayerA_ResolverTests;
    // these two confirm the resolved value actually reaches the live `svMainActionContainer`.)

    func test_buttonActionShouldMatchParent_reachesMainActionStackAlignment() {
        let props = GeniePresets.standardProperties().copy(buttonActionShouldMatchParent: true)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.twoButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.svMainActionContainer?.alignment, .fill)
    }

    func test_buttonActionOrientation_reachesMainActionStackAxis() {
        let props = GeniePresets.standardProperties().copy(buttonActionOrientation: .horizontal)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.twoButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.svMainActionContainer?.axis, .horizontal)
    }

    // MARK: - Properties: closeButtonTint

    func test_closeButtonTintApplied() {
        let props = GeniePresets.standardProperties().copy(closeButtonTint: .systemYellow)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.withCloseButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.btCloseAction?.tintColor, .systemYellow)
    }

    // MARK: - Properties.space: banner, title, subtitle, interButton

    func test_spaceInterButtonAppliedToMainActionStackSpacing() {
        let space = GBAlertModal.Properties.ComponentSpace(interButton: 19)
        let props = GeniePresets.standardProperties().copy(space: space)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.twoButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(modal.svMainActionContainer?.spacing, 19)
    }

    func test_spaceBannerAppliedToBannerDividerHeight() {
        // Needs a banner AND something below it (title) so `vwBannerAndBelowDivider` is created.
        let space = GBAlertModal.Properties.ComponentSpace(banner: 31)
        let props = GeniePresets.standardProperties().copy(space: space)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.withBanner())
        _ = renderForSnapshot(modal, size: portrait)

        guard let divider = modal.vwBannerAndBelowDivider else {
            XCTFail("expected vwBannerAndBelowDivider")
            return
        }
        let c = divider.constraints.first { $0.firstAttribute == .height }
        XCTAssertEqual(c?.constant, 31)
    }

    func test_spaceTitleAppliedToTitleDividerHeight() {
        // oneButton(): title + subtitle + primary button below it -> vwTitleAndBelowDivider created.
        let space = GBAlertModal.Properties.ComponentSpace(title: 17)
        let props = GeniePresets.standardProperties().copy(space: space)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)

        guard let divider = modal.vwTitleAndBelowDivider else {
            XCTFail("expected vwTitleAndBelowDivider")
            return
        }
        let c = divider.constraints.first { $0.firstAttribute == .height }
        XCTAssertEqual(c?.constant, 17)
    }

    func test_spaceSubtitleAppliedToSubtitleDividerHeight() {
        // oneButton(): subtitle + primary button below it -> vwSubtitleAndBelowDivider created.
        let space = GBAlertModal.Properties.ComponentSpace(subtitle: 23)
        let props = GeniePresets.standardProperties().copy(space: space)
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)

        guard let divider = modal.vwSubtitleAndBelowDivider else {
            XCTFail("expected vwSubtitleAndBelowDivider")
            return
        }
        let c = divider.constraints.first { $0.firstAttribute == .height }
        XCTAssertEqual(c?.constant, 23)
    }

    // MARK: - DataHolder: closeImage

    func test_closeImageAppliedToCloseButton() {
        let image = UIImage()
        let holder = GeniePresets.withCloseButton().copy(closeImage: image)
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: holder)
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertTrue(modal.btCloseAction?.image(for: .normal) === image)
    }

    // MARK: - Static defaults (Properties.default / ContentProperty.default / ComponentSpace.zero / DataHolder.default)

    func test_propertiesDefault_matchesDocumentedDefaults() {
        let d = GBAlertModal.Properties.default
        XCTAssertNil(d.baseTint)
        XCTAssertEqual(d.buttonActionShouldMatchParent, false)
    }

    func test_contentPropertyDefault_matchesDocumentedDefaults() {
        let d = GBAlertModal.Properties.ContentProperty.default
        XCTAssertEqual(d.cornerRadius, .zero)
        XCTAssertNil(d.fixedWidthPortrait)
    }

    func test_componentSpaceZero_matchesDocumentedDefaults() {
        let d = GBAlertModal.Properties.ComponentSpace.zero
        XCTAssertEqual(d.banner, .zero)
        XCTAssertEqual(d.interButton, .zero)
    }

    func test_dataHolderDefault_matchesDocumentedDefaults() {
        let d = GBAlertModal.DataHolder.default
        XCTAssertEqual(d.closeOnTapOverlay, false)
        XCTAssertEqual(d.dismissOnAction, false)
    }

    // MARK: - ActionStyle themes: capsule, capsuleOutlined, plain, obliqueBottomLeft

    func test_actionStyle_capsule_appliesTitleColorAndFontAndBackground() {
        let theme = GBAlertModal.ActionStyle.CapsuleTheme(
            backgroundColor: .systemBlue,
            backgroundDisableColor: .systemGray,
            titleColor: .white,
            titleDisableColor: .lightGray,
            titleFont: .systemFont(ofSize: 42)
        )
        let props = GeniePresets.standardProperties().copy(primaryActionStyle: .capsule(theme))
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)

        XCTAssertEqual(modal.btPrimaryAction?.titleColor(for: .normal), .white)
        XCTAssertEqual(modal.btPrimaryAction?.titleLabel?.font.pointSize, 42)
        XCTAssertEqual(modal.btPrimaryAction?.backgroundColor, .systemBlue)
    }

    func test_actionStyle_capsuleOutlined_appliesTitleColorFontAndBorder() {
        let theme = GBAlertModal.ActionStyle.CapsuleOutlineTheme(
            backgroundColor: .clear,
            backgroundDisableColor: .clear,
            titleColor: .systemRed,
            titleDisableColor: .lightGray,
            borderWidth: 3,
            borderColor: UIColor.systemRed.cgColor,
            borderDisableColor: UIColor.lightGray.cgColor,
            titleFont: .systemFont(ofSize: 42)
        )
        let props = GeniePresets.standardProperties().copy(primaryActionStyle: .capsuleOutlined(theme))
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)

        XCTAssertEqual(modal.btPrimaryAction?.titleColor(for: .normal), .systemRed)
        XCTAssertEqual(modal.btPrimaryAction?.titleLabel?.font.pointSize, 42)
        XCTAssertEqual(modal.btPrimaryAction?.layer.borderWidth, 3)
    }

    func test_actionStyle_plain_appliesTitleColorAndFont() {
        let theme = GBAlertModal.ActionStyle.PlainTheme(
            titleColor: .systemIndigo,
            titleDisableColor: .lightGray,
            titleFont: .systemFont(ofSize: 42)
        )
        let props = GeniePresets.standardProperties().copy(primaryActionStyle: .plain(theme))
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)

        XCTAssertEqual(modal.btPrimaryAction?.titleColor(for: .normal), .systemIndigo)
        XCTAssertEqual(modal.btPrimaryAction?.titleLabel?.font.pointSize, 42)
    }

    func test_actionStyle_obliqueBottomLeft_appliesTitleColorFontAndBackground() {
        let theme = GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
            unPressedColor: .systemBrown,
            pressedColor: .systemBlue,
            disabledColor: .lightGray,
            shadowColor: UIColor.black.cgColor,
            titleColor: .white,
            titleDisableColor: .lightGray,
            titleFont: .systemFont(ofSize: 42)
        )
        let props = GeniePresets.standardProperties().copy(primaryActionStyle: .obliqueBottomLeft(theme))
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)

        XCTAssertEqual(modal.btPrimaryAction?.titleColor(for: .normal), .white)
        XCTAssertEqual(modal.btPrimaryAction?.titleLabel?.font.pointSize, 42)
        XCTAssertEqual(modal.btPrimaryAction?.backgroundColor, .systemBrown)
    }

    // MARK: - Public methods

    func test_init_setsUpCoreOutlets() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: GeniePresets.oneButton())
        XCTAssertNotNil(modal.vwOverlay)
        XCTAssertNotNil(modal.vwContainer)
        XCTAssertNotNil(modal.svContentContainer)
    }

    // `init?(coder:)` is a mandated `fatalError` stub (never used programmatically) — invoking
    // it would crash the test process, so it's a justified skip rather than an untested branch.

    func test_show_addsToParentAndCallsCompletion() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: GeniePresets.oneButton())
        let host = UIView()
        var completionCalled = false
        modal.show(parent: host) { completionCalled = true }
        XCTAssertTrue(host.subviews.contains(modal))
        XCTAssertTrue(completionCalled)
    }

    func test_hide_removesFromSuperviewAfterAnimation() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: GeniePresets.oneButton())
        let host = UIView()
        modal.show(parent: host, completion: {})
        XCTAssertTrue(host.subviews.contains(modal))

        let expectation = expectation(description: "hide removes from superview")
        modal.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(host.subviews.contains(modal))
    }

    func test_dismiss_removesWhenDismissOnActionTrue() {
        let holder = GeniePresets.oneButton().copy(dismissOnAction: true)
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: holder)
        let host = UIView()
        modal.show(parent: host, completion: {})
        modal.dismiss()

        let expectation = expectation(description: "dismiss removes from superview")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(host.subviews.contains(modal))
    }

    func test_dismiss_doesNotRemoveWhenDismissOnActionFalse() {
        let holder = GeniePresets.oneButton().copy(dismissOnAction: false)
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: holder)
        let host = UIView()
        modal.show(parent: host, completion: {})
        modal.dismiss()

        let expectation = expectation(description: "no-op dismiss window")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(host.subviews.contains(modal))
    }

    func test_dismissAndEmit_emitsActionType() {
        var emitted: GBAlertModal.ActionType?
        let holder = GeniePresets.twoButton().copy(
            dismissOnAction: false,
            completion: { _, type in emitted = type }
        )
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: holder)
        modal.dismissAndEmit(event: .primary)
        assertAction(emitted, is: .primary)
    }

    func test_dismissAndEmit_respectsDismissOnActionTrue() {
        let holder = GeniePresets.twoButton().copy(dismissOnAction: true, completion: { _, _ in })
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: holder)
        let host = UIView()
        modal.show(parent: host, completion: {})
        modal.dismissAndEmit(event: .close)

        let expectation = expectation(description: "dismissAndEmit removes from superview")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(host.subviews.contains(modal))
    }

    func test_dismissAndEmit_passesSelfAsFirstArgument() {
        var receivedModal: GBAlertModal?
        let holder = GeniePresets.oneButton().copy(
            dismissOnAction: false,
            completion: { modal, _ in receivedModal = modal }
        )
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: holder)
        modal.dismissAndEmit(event: .secondary)
        XCTAssertTrue(receivedModal === modal)
    }

    func test_updateDialog_swapsContent() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(), holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)
        XCTAssertNil(modal.vwBanner)

        modal.updateDialog(holder: GeniePresets.withBanner(), properties: nil)
        XCTAssertNotNil(modal.vwBanner)
    }

    func test_changePrimaryActionEnableState_togglesButtonAndAppliesDisableTheme() {
        let theme = GBAlertModal.ActionStyle.CapsuleTheme(
            backgroundColor: .systemGreen,
            backgroundDisableColor: .systemGray,
            titleColor: .white,
            titleDisableColor: .darkGray,
            titleFont: .systemFont(ofSize: 20)
        )
        let props = GeniePresets.standardProperties().copy(primaryActionStyle: .capsule(theme))
        let modal = GBAlertModal(properties: props, holder: GeniePresets.oneButton())
        _ = renderForSnapshot(modal, size: portrait)

        modal.changePrimaryActionEnableState(isEnable: false)

        XCTAssertFalse(modal.btPrimaryAction!.isEnabled)
        XCTAssertEqual(modal.btPrimaryAction?.backgroundColor, .systemGray)
        XCTAssertEqual(modal.btPrimaryAction?.titleColor(for: .normal), .darkGray)
    }

    func test_changeSecondaryActionEnableState_togglesButtonAndAppliesDisableTheme() {
        let theme = GBAlertModal.ActionStyle.PlainTheme(
            titleColor: .systemBlue,
            titleDisableColor: .darkGray,
            titleFont: .systemFont(ofSize: 20)
        )
        let props = GeniePresets.standardProperties().copy(secondaryActionStyle: .plain(theme))
        let modal = GBAlertModal(properties: props, holder: GeniePresets.twoButton())
        _ = renderForSnapshot(modal, size: portrait)

        modal.changeSecondaryActionEnableState(isEnable: false)

        XCTAssertFalse(modal.btSecondaryAction!.isEnabled)
        XCTAssertEqual(modal.btSecondaryAction?.titleColor(for: .normal), .darkGray)
    }
}
