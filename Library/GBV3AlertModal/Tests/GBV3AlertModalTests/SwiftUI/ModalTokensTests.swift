import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// `Color(hex:)` is deliberately `internal` (see the doc comment on the extension in
/// `ModalTokens.swift`): it's an extension on a type this library doesn't own, and making it
/// `public` would collide with the equally-common private `Color(hex:)` helper apps that link
/// this library are likely to already have. This test exercises it via `@testable import`,
/// which is why it lives here rather than in the example app's test target.
final class ModalTokensTests: XCTestCase {
    func test_hex_color_decodes_rgb_channels() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color(hex: 0x038CD5)).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0x03 / 255, accuracy: 0.01)
        XCTAssertEqual(g, 0x8C / 255, accuracy: 0.01)
        XCTAssertEqual(b, 0xD5 / 255, accuracy: 0.01)
    }
}

/// C-0: `ModalTokens` is DERIVED from `GBAlertModal.Properties`, never transcribed. A
/// hand-transcription is what previously shipped a wrong card width, wrong spacing and a wrong
/// button style, caught only by running on a physical device. Each test below constructs a
/// `Properties` with a DISTINCTIVE value (never today's `standard` default) and asserts the token
/// reflects it — proving provenance, not merely that `init(from:)` happens to reproduce `standard`.
final class ModalTokensProvenanceTests: XCTestCase {
    func test_cornerRadius_comesFromProperties() {
        let content = GBAlertModal.Properties.ContentProperty(cornerRadius: 21)
        let properties = GBAlertModal.Properties(contentProperty: content)
        XCTAssertEqual(ModalTokens(from: properties).cornerRadius, 21)
    }

    func test_interButtonSpacing_comesFromProperties() {
        let space = GBAlertModal.Properties.ComponentSpace(
            banner: 1, title: 2, subtitle: 3, interButton: 9
        )
        let properties = GBAlertModal.Properties(space: space)
        XCTAssertEqual(ModalTokens(from: properties).interButton, 9)
    }

    func test_gapBelowBannerTitleSubtitle_comeFromProperties() {
        let space = GBAlertModal.Properties.ComponentSpace(
            banner: 11, title: 22, subtitle: 33, interButton: 44
        )
        let properties = GBAlertModal.Properties(space: space)
        let tokens = ModalTokens(from: properties)
        XCTAssertEqual(tokens.gapBelowBanner, 11)
        XCTAssertEqual(tokens.gapBelowTitle, 22)
        XCTAssertEqual(tokens.gapBelowSubtitle, 33)
    }

    func test_titleColor_comesFromProperties() {
        let properties = GBAlertModal.Properties(titleColor: .magenta)
        XCTAssertEqual(ModalTokens(from: properties).palette.titleText, Color(uiColor: .magenta))
    }

    func test_subtitleFontSize_comesFromProperties() {
        let font = UIFont.systemFont(ofSize: 31, weight: .light)
        let properties = GBAlertModal.Properties(subtitleFont: font)
        XCTAssertEqual(ModalTokens(from: properties).subtitleFont, Font(font))
    }

    func test_scrim_comesFromProperties_overlayColor() {
        let properties = GBAlertModal.Properties(overlayColor: .systemGreen)
        XCTAssertEqual(ModalTokens(from: properties).palette.scrim, Color(uiColor: .systemGreen))
    }

    func test_cardMargin_comesFromProperties() {
        let properties = GBAlertModal.Properties(margin: UIEdgeInsets(top: 7, left: 13, bottom: 7, right: 13))
        let tokens = ModalTokens(from: properties)
        XCTAssertEqual(tokens.cardMarginV, 7)
        XCTAssertEqual(tokens.cardMarginH, 13)
    }

    func test_contentPadding_comesFromProperties_usingMax() {
        let padding = UIMinMaxEdgeInsets(
            top: (5, 17), left: (5, 29), bottom: (5, 17), right: (5, 29)
        )
        let properties = GBAlertModal.Properties(padding: padding)
        let tokens = ModalTokens(from: properties)
        XCTAssertEqual(tokens.contentPaddingV, 17)
        XCTAssertEqual(tokens.contentPaddingH, 29)
    }

    func test_bannerMaxHeight_comesFromProperties() {
        let properties = GBAlertModal.Properties(bannerMaxHeight: 201)
        XCTAssertEqual(ModalTokens(from: properties).bannerMaxHeight, 201)
    }

    func test_cardBackground_comesFromProperties_contentProperty() {
        let content = GBAlertModal.Properties.ContentProperty(backgroundColor: .systemPurple)
        let properties = GBAlertModal.Properties(contentProperty: content)
        XCTAssertEqual(ModalTokens(from: properties).palette.cardBackground, Color(uiColor: .systemPurple))
    }

    /// The fixed SwiftUI primary button only has real colours for `ActionStyle.obliqueBottomLeft`
    /// (spec D8) — its theme is where `accent`/`accentPressed`/`disabled`/`shadow`/`onAccent` derive.
    func test_accentColors_comeFromProperties_obliqueBottomLeftTheme() {
        let theme = GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
            unPressedColor: .systemYellow,
            pressedColor: .systemTeal,
            disabledColor: .systemGray,
            titleColor: .systemPink
        )
        let properties = GBAlertModal.Properties(primaryActionStyle: .obliqueBottomLeft(theme))
        let tokens = ModalTokens(from: properties)
        XCTAssertEqual(tokens.palette.accent, Color(uiColor: .systemYellow))
        XCTAssertEqual(tokens.palette.accentPressed, Color(uiColor: .systemTeal))
        XCTAssertEqual(tokens.palette.disabled, Color(uiColor: .systemGray))
        XCTAssertEqual(tokens.palette.onAccent, Color(uiColor: .systemPink))
    }

    /// A `primaryActionStyle` that ISN'T `.obliqueBottomLeft` has no colours this fixed SwiftUI
    /// style can use — `standard`'s literals must survive untouched rather than a guess.
    func test_accentColors_keepStandardLiterals_whenActionStyleIsNotOblique() {
        let properties = GBAlertModal.Properties(primaryActionStyle: .plain(.init(titleColor: .red)))
        let tokens = ModalTokens(from: properties)
        XCTAssertEqual(tokens.palette.accent, ModalTokens.standard.palette.accent)
        XCTAssertEqual(tokens.palette.accentPressed, ModalTokens.standard.palette.accentPressed)
    }

    /// Fields with NO `Properties` counterpart (button geometry, oblique offset) must stay at
    /// `standard`'s literal even when other, unrelated fields are supplied.
    func test_noCounterpartFields_stayAtStandardLiterals() {
        let properties = GBAlertModal.Properties(titleColor: .magenta)
        let tokens = ModalTokens(from: properties)
        XCTAssertEqual(tokens.buttonCornerRadius, ModalTokens.standard.buttonCornerRadius)
        XCTAssertEqual(tokens.buttonHeight, ModalTokens.standard.buttonHeight)
        XCTAssertEqual(tokens.obliqueOffset.width, ModalTokens.standard.obliqueOffset.width)
        XCTAssertEqual(tokens.obliqueOffset.height, ModalTokens.standard.obliqueOffset.height)
    }
}
