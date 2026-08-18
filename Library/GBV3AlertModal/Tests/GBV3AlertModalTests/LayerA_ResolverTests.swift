import XCTest
import UIKit
@testable import GBV3AlertModal

private struct SendableStructureInputs: ModalStructureInputs, Sendable {
    let hasPrimaryActionStyle = true
    let hasSecondaryActionStyle = true
    let buttonsAreHorizontal = true
    let buttonsMatchParent = true
    let fixedWidthPortrait: CGFloat? = 200
    let maxWidthPortrait: CGFloat? = 300
    let fixedWidthLandscape: CGFloat? = 400
    let maxWidthLandscape: CGFloat? = 500
}

private struct SendableContentInputs: ModalContentInputs, Sendable {
    let closeOnTapOverlay = true
    let hasBanner = true
    let title: String? = "Title"
    let hasAttributedTitle = false
    let subtitle: String? = "Subtitle"
    let hasAttributedSubtitle = false
    let hasSubtitleCustomView = false
    let primaryAction: String? = "Continue"
    let secondaryAction: String? = "Cancel"
    let showCloseButton = true
    let dismissOnAction = true
}

/// Compile witness: the Core resolver is synchronous, nonisolated, and accepts Sendable values.
private nonisolated func resolveFromNonisolatedContext() -> ResolvedModal {
    resolveModal(
        inputs: SendableStructureInputs(),
        content: SendableContentInputs(),
        isLandscape: false
    )
}

/// Layer A: unit tests for the pure `GBAlertModal.resolve(...)` resolver.
///
/// Task 3 seeded this suite with the banner-visibility decisions; Task 4 exhausts every
/// remaining structural branch. No rendering happens here — every test constructs
/// `Properties`/`DataHolder` directly and asserts the returned `ResolvedModal`.
// @MainActor: several subtitle-precedence tests below build a bare `UIView()` to pass as
// `subtitleCustomView` — `UIView`'s initializer is @MainActor-isolated under Swift 6, even
// though `resolve(...)` itself is a nonisolated pure function.
@MainActor
final class LayerA_ResolverTests: XCTestCase {
    func test_coreResolverUsesNeutralButtonAxisFromNonisolatedContext() {
        let resolved = resolveFromNonisolatedContext()
        XCTAssertEqual(resolved.buttonAxis, .horizontal)
        XCTAssertEqual(ResolvedModal.ButtonAxis.vertical, .vertical)
    }

    // MARK: - Banner (seeded by Task 3)

    func test_resolve_bannerVisibleWhenImagePresent() {
        let holder = GBAlertModal.DataHolder(banner: UIImage.gbv3TestSolid(width: 4, height: 4))
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertTrue(r.showsBanner)
    }

    func test_resolve_noBannerWhenNil() {
        let r = GBAlertModal.resolve(properties: nil, holder: .default, isLandscape: false)
        XCTAssertFalse(r.showsBanner)
    }

    func test_resolve_noBannerWhenImageIsZeroSize() {
        let holder = GBAlertModal.DataHolder(banner: UIImage())
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertFalse(r.showsBanner)
    }

    // MARK: - Title (plain OR attributed, non-empty)

    func test_resolve_titleVisibleWhenPlainNonEmpty() {
        let holder = GBAlertModal.DataHolder(title: "Hello")
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertTrue(r.showsTitle)
    }

    func test_resolve_titleHiddenWhenPlainEmptyAndNoAttributed() {
        let holder = GBAlertModal.DataHolder(title: "")
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertFalse(r.showsTitle)
    }

    func test_resolve_titleVisibleWhenAttributedNonEmpty() {
        let holder = GBAlertModal.DataHolder(titleAttributed: NSAttributedString(string: "Hi"))
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertTrue(r.showsTitle)
    }

    func test_resolve_titleHiddenWhenAttributedEmpty() {
        let holder = GBAlertModal.DataHolder(titleAttributed: NSAttributedString(string: ""))
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertFalse(r.showsTitle)
    }

    func test_resolve_titleHiddenWhenBothNil() {
        let r = GBAlertModal.resolve(properties: nil, holder: .default, isLandscape: false)
        XCTAssertFalse(r.showsTitle)
    }

    func test_resolve_titleFallsBackToAttributedWhenPlainEmpty() {
        let holder = GBAlertModal.DataHolder(title: "", titleAttributed: NSAttributedString(string: "Hi"))
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertTrue(r.showsTitle)
    }

    // MARK: - Subtitle precedence: plain > attributed > custom > none

    func test_resolve_subtitle_plainOnly() {
        let holder = GBAlertModal.DataHolder(subtitle: "Sub")
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertEqual(r.subtitle, .plain("Sub"))
    }

    func test_resolve_subtitle_attributedOnly() {
        let holder = GBAlertModal.DataHolder(subtitleAttributed: NSAttributedString(string: "Sub"))
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertEqual(r.subtitle, .attributed)
    }

    func test_resolve_subtitle_customOnly() {
        let view = UIView()
        let holder = GBAlertModal.DataHolder(subtitleCustomView: view)
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertEqual(r.subtitle, .custom)
    }

    func test_resolve_subtitle_noneWhenNothingSet() {
        let r = GBAlertModal.resolve(properties: nil, holder: .default, isLandscape: false)
        XCTAssertEqual(r.subtitle, .none)
    }

    func test_resolve_subtitle_plainWinsOverAttributedAndCustom() {
        let view = UIView()
        let holder = GBAlertModal.DataHolder(
                subtitle: "Plain wins",
                subtitleAttributed: NSAttributedString(string: "Attributed"),
                subtitleCustomView: view
        )
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertEqual(r.subtitle, .plain("Plain wins"))
    }

    func test_resolve_subtitle_attributedWinsOverCustomWhenPlainNil() {
        let view = UIView()
        let holder = GBAlertModal.DataHolder(
                subtitleAttributed: NSAttributedString(string: "Attributed"),
                subtitleCustomView: view
        )
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertEqual(r.subtitle, .attributed)
    }

    func test_resolve_subtitle_emptyPlainFallsThroughToAttributed() {
        let holder = GBAlertModal.DataHolder(subtitle: "", subtitleAttributed: NSAttributedString(string: "Attributed"))
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertEqual(r.subtitle, .attributed)
    }

    func test_resolve_subtitle_emptyPlainFallsThroughToCustom() {
        let view = UIView()
        let holder = GBAlertModal.DataHolder(subtitle: "", subtitleCustomView: view)
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertEqual(r.subtitle, .custom)
    }

    func test_resolve_subtitle_emptyAttributedFallsThroughToCustom() {
        let view = UIView()
        let holder = GBAlertModal.DataHolder(
                subtitleAttributed: NSAttributedString(string: ""),
                subtitleCustomView: view
        )
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertEqual(r.subtitle, .custom)
    }

    func test_resolve_subtitle_emptyPlainAndEmptyAttributedFallsThroughToNone() {
        let holder = GBAlertModal.DataHolder(subtitle: "", subtitleAttributed: NSAttributedString(string: ""))
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertEqual(r.subtitle, .none)
    }

    // Task 10: locks the contract that an empty-but-non-nil `subtitle` (no attributed, no
    // custom view) resolves to `.none`, same as a nil subtitle — this is what
    // `buildSubtitleComponent`'s outer gate (`resolved.subtitle != .none`) now relies on to skip
    // building an empty subtitle scroll container.
    func test_resolve_subtitle_emptyPlainOnlyResolvesToNone() {
        let holder = GBAlertModal.DataHolder(subtitle: "")
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertEqual(r.subtitle, .none)
    }

    // MARK: - Button axis (buttonActionOrientation)

    func test_resolve_buttonAxis_horizontalWhenExplicit() {
        let properties = GBAlertModal.Properties(buttonActionOrientation: .horizontal)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertEqual(r.buttonAxis, .horizontal)
    }

    func test_resolve_buttonAxis_verticalWhenExplicit() {
        let properties = GBAlertModal.Properties(buttonActionOrientation: .vertical)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertEqual(r.buttonAxis, .vertical)
    }

    func test_resolve_buttonAxis_defaultsToVerticalWhenNil() {
        let properties = GBAlertModal.Properties(buttonActionOrientation: nil)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertEqual(r.buttonAxis, .vertical)
    }

    func test_resolve_buttonAxis_defaultsToVerticalWhenPropertiesNil() {
        let r = GBAlertModal.resolve(properties: nil, holder: .default, isLandscape: false)
        XCTAssertEqual(r.buttonAxis, .vertical)
    }

    // MARK: - buttonActionShouldMatchParent

    func test_resolve_buttonsMatchParent_trueWhenExplicitTrue() {
        let properties = GBAlertModal.Properties(buttonActionShouldMatchParent: true)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertTrue(r.buttonsMatchParent)
    }

    func test_resolve_buttonsMatchParent_falseWhenExplicitFalse() {
        let properties = GBAlertModal.Properties(buttonActionShouldMatchParent: false)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertFalse(r.buttonsMatchParent)
    }

    func test_resolve_buttonsMatchParent_falseWhenNil() {
        let properties = GBAlertModal.Properties(buttonActionShouldMatchParent: nil)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertFalse(r.buttonsMatchParent)
    }

    // MARK: - Primary / secondary action presence (string AND style both required)

    func test_resolve_primary_shownWhenStringAndStylePresent() {
        let properties = GBAlertModal.Properties(primaryActionStyle: .plain(.init()))
        let holder = GBAlertModal.DataHolder(primaryAction: "OK")
        let r = GBAlertModal.resolve(properties: properties, holder: holder, isLandscape: false)
        XCTAssertTrue(r.showsPrimary)
    }

    func test_resolve_primary_hiddenWhenStyleMissing() {
        let holder = GBAlertModal.DataHolder(primaryAction: "OK")
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertFalse(r.showsPrimary)
    }

    func test_resolve_primary_hiddenWhenStringMissing() {
        let properties = GBAlertModal.Properties(primaryActionStyle: .plain(.init()))
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertFalse(r.showsPrimary)
    }

    func test_resolve_primary_hiddenWhenBothMissing() {
        let r = GBAlertModal.resolve(properties: nil, holder: .default, isLandscape: false)
        XCTAssertFalse(r.showsPrimary)
    }

    func test_resolve_secondary_shownWhenStringAndStylePresent() {
        let properties = GBAlertModal.Properties(secondaryActionStyle: .plain(.init()))
        let holder = GBAlertModal.DataHolder(secondaryAction: "Cancel")
        let r = GBAlertModal.resolve(properties: properties, holder: holder, isLandscape: false)
        XCTAssertTrue(r.showsSecondary)
    }

    func test_resolve_secondary_hiddenWhenStyleMissing() {
        let holder = GBAlertModal.DataHolder(secondaryAction: "Cancel")
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertFalse(r.showsSecondary)
    }

    func test_resolve_secondary_hiddenWhenStringMissing() {
        let properties = GBAlertModal.Properties(secondaryActionStyle: .plain(.init()))
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertFalse(r.showsSecondary)
    }

    func test_resolve_secondary_hiddenWhenBothMissing() {
        let r = GBAlertModal.resolve(properties: nil, holder: .default, isLandscape: false)
        XCTAssertFalse(r.showsSecondary)
    }

    // MARK: - showsCloseButton / dismissOnAction / closeOnTapOverlay pass-through

    func test_resolve_showsCloseButton_trueWhenSet() {
        let holder = GBAlertModal.DataHolder(showCloseButton: true)
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertTrue(r.showsCloseButton)
    }

    func test_resolve_showsCloseButton_falseWhenUnset() {
        let holder = GBAlertModal.DataHolder(showCloseButton: false)
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertFalse(r.showsCloseButton)
    }

    func test_resolve_dismissOnAction_trueWhenSet() {
        let holder = GBAlertModal.DataHolder(dismissOnAction: true)
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertTrue(r.dismissOnAction)
    }

    func test_resolve_dismissOnAction_falseWhenUnset() {
        let holder = GBAlertModal.DataHolder(dismissOnAction: false)
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertFalse(r.dismissOnAction)
    }

    func test_resolve_closeOnTapOverlay_trueWhenSet() {
        let holder = GBAlertModal.DataHolder(closeOnTapOverlay: true)
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertTrue(r.closeOnTapOverlay)
    }

    func test_resolve_closeOnTapOverlay_falseWhenUnset() {
        let holder = GBAlertModal.DataHolder(closeOnTapOverlay: false)
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false)
        XCTAssertFalse(r.closeOnTapOverlay)
    }

    // MARK: - contentWidth: flexible (no content property / no widths)

    func test_resolve_contentWidth_flexibleWhenPropertiesNil() {
        let r = GBAlertModal.resolve(properties: nil, holder: .default, isLandscape: false)
        XCTAssertEqual(r.contentWidth, .flexible)
    }

    func test_resolve_contentWidth_flexibleWhenContentPropertyHasNoWidths() {
        let properties = GBAlertModal.Properties(contentProperty: .init())
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertEqual(r.contentWidth, .flexible)
    }

    // MARK: - contentWidth: fixed-only, crossed with isLandscape, both orientation values set

    func test_resolve_contentWidth_fixedOnly_pickPortraitInPortrait() {
        let contentProperty = GBAlertModal.Properties.ContentProperty(
                fixedWidthPortrait: 200,
                fixedWidthLandscape: 300
        )
        let properties = GBAlertModal.Properties(contentProperty: contentProperty)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertEqual(r.contentWidth, .fixed(200))
    }

    func test_resolve_contentWidth_fixedOnly_pickLandscapeInLandscape() {
        let contentProperty = GBAlertModal.Properties.ContentProperty(
                fixedWidthPortrait: 200,
                fixedWidthLandscape: 300
        )
        let properties = GBAlertModal.Properties(contentProperty: contentProperty)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: true)
        XCTAssertEqual(r.contentWidth, .fixed(300))
    }

    func test_resolve_contentWidth_fixedOnly_landscapeFallsBackToPortraitWhenLandscapeNil() {
        let contentProperty = GBAlertModal.Properties.ContentProperty(fixedWidthPortrait: 200)
        let properties = GBAlertModal.Properties(contentProperty: contentProperty)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: true)
        XCTAssertEqual(r.contentWidth, .fixed(200))
    }

    func test_resolve_contentWidth_fixedOnly_portraitFallsBackToLandscapeWhenPortraitNil() {
        let contentProperty = GBAlertModal.Properties.ContentProperty(fixedWidthLandscape: 300)
        let properties = GBAlertModal.Properties(contentProperty: contentProperty)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertEqual(r.contentWidth, .fixed(300))
    }

    // MARK: - contentWidth: max-only, crossed with isLandscape, both orientation values set

    func test_resolve_contentWidth_maxOnly_pickPortraitInPortrait() {
        let contentProperty = GBAlertModal.Properties.ContentProperty(
                maxWidthPortrait: 150,
                maxWidthLandscape: 250
        )
        let properties = GBAlertModal.Properties(contentProperty: contentProperty)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertEqual(r.contentWidth, .max(150))
    }

    func test_resolve_contentWidth_maxOnly_pickLandscapeInLandscape() {
        let contentProperty = GBAlertModal.Properties.ContentProperty(
                maxWidthPortrait: 150,
                maxWidthLandscape: 250
        )
        let properties = GBAlertModal.Properties(contentProperty: contentProperty)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: true)
        XCTAssertEqual(r.contentWidth, .max(250))
    }

    func test_resolve_contentWidth_maxOnly_landscapeFallsBackToPortraitWhenLandscapeNil() {
        let contentProperty = GBAlertModal.Properties.ContentProperty(maxWidthPortrait: 150)
        let properties = GBAlertModal.Properties(contentProperty: contentProperty)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: true)
        XCTAssertEqual(r.contentWidth, .max(150))
    }

    func test_resolve_contentWidth_maxOnly_portraitFallsBackToLandscapeWhenPortraitNil() {
        let contentProperty = GBAlertModal.Properties.ContentProperty(maxWidthLandscape: 250)
        let properties = GBAlertModal.Properties(contentProperty: contentProperty)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertEqual(r.contentWidth, .max(250))
    }

    // MARK: - contentWidth: fixed AND max independently applied, crossed with isLandscape

    func test_resolve_contentWidth_fixedAndMax_portrait() {
        let contentProperty = GBAlertModal.Properties.ContentProperty(
                fixedWidthPortrait: 200,
                maxWidthPortrait: 150,
                fixedWidthLandscape: 300,
                maxWidthLandscape: 250
        )
        let properties = GBAlertModal.Properties(contentProperty: contentProperty)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: false)
        XCTAssertEqual(r.contentWidth, .fixedAndMax(fixed: 200, max: 150))
    }

    func test_resolve_contentWidth_fixedAndMax_landscape() {
        let contentProperty = GBAlertModal.Properties.ContentProperty(
                fixedWidthPortrait: 200,
                maxWidthPortrait: 150,
                fixedWidthLandscape: 300,
                maxWidthLandscape: 250
        )
        let properties = GBAlertModal.Properties(contentProperty: contentProperty)
        let r = GBAlertModal.resolve(properties: properties, holder: .default, isLandscape: true)
        XCTAssertEqual(r.contentWidth, .fixedAndMax(fixed: 300, max: 250))
    }
}
