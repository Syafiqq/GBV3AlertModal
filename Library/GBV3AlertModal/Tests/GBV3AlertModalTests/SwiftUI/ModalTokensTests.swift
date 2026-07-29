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

    /// Re-pins the scrim's 0.6 dim now that `ModalTokens.scrimOpacity` no longer exists as a
    /// separate token (folded into `palette.scrim` itself — see `ModalTokens.swift`): without this,
    /// nothing in either test target asserts `standard`'s scrim alpha at all, so the literal at
    /// `ModalTokens.swift`'s `standard` declaration could drift silently.
    func test_standard_scrim_alpha_is_0_6() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(ModalTokens.standard.palette.scrim).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(a, 0.6, accuracy: 0.01)
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

    /// Same scope caveat as `test_subtitleFont_comesFromProperties_viaFontBridge` below: this proves
    /// the derivation READS `properties.titleFont`, not that the `UIFont -> Font` bridge is faithful.
    func test_titleFont_comesFromProperties_viaFontBridge() {
        let font = UIFont.systemFont(ofSize: 41, weight: .ultraLight)
        let properties = GBAlertModal.Properties(titleFont: font)
        XCTAssertEqual(ModalTokens(from: properties).titleFont, Font(font))
    }

    /// NOTE on scope: this asserts the derivation reads `properties.subtitleFont` at all — that the
    /// `UIFont` genuinely flows from `Properties` into the token (provenance) — via the exact same
    /// internal `Font(UIFont)` bridge used on both sides of the comparison. It does NOT independently
    /// verify the bridge itself preserves size/weight (a bug in the bridge would pass here since
    /// both sides call it); that bridge was instead verified directly against the SwiftUI/CoreText
    /// SDK during implementation (see the task report), not by this XCTest.
    func test_subtitleFont_comesFromProperties_viaFontBridge() {
        let font = UIFont.systemFont(ofSize: 31, weight: .light)
        let properties = GBAlertModal.Properties(subtitleFont: font)
        XCTAssertEqual(ModalTokens(from: properties).subtitleFont, Font(font))
    }

    func test_subtitleColor_comesFromProperties() {
        let properties = GBAlertModal.Properties(subtitleColor: .systemOrange)
        XCTAssertEqual(ModalTokens(from: properties).palette.subtitleText, Color(uiColor: .systemOrange))
    }

    func test_cardMaxWidth_comesFromProperties_maxWidthPortrait() {
        let content = GBAlertModal.Properties.ContentProperty(maxWidthPortrait: 271)
        let properties = GBAlertModal.Properties(contentProperty: content)
        XCTAssertEqual(ModalTokens(from: properties).cardMaxWidth, 271)
    }

    /// A preset that pins a FIXED width and no max used to leave `cardMaxWidth` at `.infinity`,
    /// i.e. UIKit pinned the card and SwiftUI let it fill. The fixed width is folded in as a cap
    /// (see `init(from:)` for why a cap and not `.frame(width:)`).
    func test_cardMaxWidth_fallsBackToFixedWidth_whenNoMaxIsSet() {
        let content = GBAlertModal.Properties.ContentProperty(fixedWidthPortrait: 263)
        let properties = GBAlertModal.Properties(contentProperty: content)
        XCTAssertEqual(ModalTokens(from: properties).cardMaxWidth, 263)
    }

    /// The cap can never exceed the tighter of the two: in UIKit the max is a `<=` at `.high` and
    /// the fixed width an `==` at `.medium`, so the max wins whenever it is the smaller number.
    func test_cardMaxWidth_takesTheTighterOfFixedAndMax() {
        let content = GBAlertModal.Properties.ContentProperty(
            fixedWidthPortrait: 290, maxWidthPortrait: 244
        )
        let properties = GBAlertModal.Properties(contentProperty: content)
        XCTAssertEqual(ModalTokens(from: properties).cardMaxWidth, 244)
    }

    /// Portrait-first with a landscape fallback, mirroring `GBAlertModal.resolve`'s `contentWidth`.
    /// A preset that only states landscape widths used to derive NO cap at all.
    func test_cardMaxWidth_fallsBackToLandscapeWidths() {
        let content = GBAlertModal.Properties.ContentProperty(
            fixedWidthLandscape: 311, maxWidthLandscape: 337
        )
        let properties = GBAlertModal.Properties(contentProperty: content)
        XCTAssertEqual(ModalTokens(from: properties).cardMaxWidth, 311)
    }

    func test_closeButtonTint_comesFromProperties() {
        let properties = GBAlertModal.Properties(closeButtonTint: .systemBrown)
        XCTAssertEqual(
            ModalTokens(from: properties).palette.closeButton, Color(uiColor: .systemBrown)
        )
    }

    /// Discrimination for the close tint: `standard`'s literal is the SAME hex as `subtitleText`
    /// (0x333333), which is what the scaffold used as a stand-in before this token existed. So a
    /// derivation that still read `subtitleText` would pass a bare "equals standard" assertion —
    /// this one gives the two fields DIFFERENT values and pins the tint to its own source.
    func test_closeButtonTint_isNotTheSubtitleColor() {
        let properties = GBAlertModal.Properties(subtitleColor: .systemGreen, closeButtonTint: .systemBrown)
        let tokens = ModalTokens(from: properties)
        XCTAssertEqual(tokens.palette.closeButton, Color(uiColor: .systemBrown))
        XCTAssertNotEqual(tokens.palette.closeButton, tokens.palette.subtitleText)
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

    func test_bannerRatio_comesFromProperties() {
        let properties = GBAlertModal.Properties(bannerRatio: 320.0 / 229.0)
        XCTAssertEqual(ModalTokens(from: properties).bannerRatio, 320.0 / 229.0)
    }

    func test_bannerFixedHeight_comesFromProperties() {
        let properties = GBAlertModal.Properties(bannerFixedHeight: 183)
        XCTAssertEqual(ModalTokens(from: properties).bannerFixedHeight, 183)
    }

    /// The banner geometry is the ONE group that does not fall back to `standard`'s literals: a nil
    /// `Properties` field means "UIKit installs no such constraint", so keeping `standard`'s 160pt
    /// cap would apply a cap UIKit does not — and the real `V3AlertModal` preset
    /// (`GeniePresets.standardProperties()`) is exactly that case, `bannerMaxHeight: nil`.
    func test_bannerMaxHeight_isNilWhenPropertiesSetsNoCap() {
        let properties = GBAlertModal.Properties(bannerRatio: 1)
        XCTAssertNil(ModalTokens(from: properties).bannerMaxHeight)
        XCTAssertNotNil(ModalTokens.standard.bannerMaxHeight, "premise: standard DOES ship a cap")
    }

    func test_cardBackground_comesFromProperties_contentProperty() {
        let content = GBAlertModal.Properties.ContentProperty(backgroundColor: .systemPurple)
        let properties = GBAlertModal.Properties(contentProperty: content)
        XCTAssertEqual(ModalTokens(from: properties).palette.cardBackground, Color(uiColor: .systemPurple))
    }

    /// The fixed SwiftUI primary button only has real colours for `ActionStyle.obliqueBottomLeft`
    /// (spec D8) — its theme is where `accent`/`accentPressed`/`disabled`/`shadow`/`onAccent` derive.
    /// `shadowColor` is the only `CGColor` bridge in the whole derivation (everything else is
    /// `UIColor`), so it's asserted here alongside the other four rather than left uncovered.
    func test_accentColors_comeFromProperties_obliqueBottomLeftTheme() {
        let shadowColor = UIColor.systemIndigo.cgColor
        let theme = GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
            unPressedColor: .systemYellow,
            pressedColor: .systemTeal,
            disabledColor: .systemGray,
            shadowColor: shadowColor,
            titleColor: .systemPink
        )
        let properties = GBAlertModal.Properties(primaryActionStyle: .obliqueBottomLeft(theme))
        let tokens = ModalTokens(from: properties)
        XCTAssertEqual(tokens.palette.accent, Color(uiColor: .systemYellow))
        XCTAssertEqual(tokens.palette.accentPressed, Color(uiColor: .systemTeal))
        XCTAssertEqual(tokens.palette.disabled, Color(uiColor: .systemGray))
        XCTAssertEqual(tokens.palette.shadow, Color(cgColor: shadowColor))
        XCTAssertEqual(tokens.palette.onAccent, Color(uiColor: .systemPink))
    }

    /// `ObliquePrimaryStyle`'s label font is split from `PlainSecondaryStyle`'s (`primaryButtonFont`
    /// / `secondaryButtonFont`) because their real counterparts are two different `Properties`
    /// fields (`primaryActionStyle` / `secondaryActionStyle`), which can legitimately differ.
    func test_primaryButtonFont_comesFromProperties_obliqueBottomLeftTheme() {
        let font = UIFont.systemFont(ofSize: 21, weight: .black)
        let theme = GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(titleFont: font)
        let properties = GBAlertModal.Properties(primaryActionStyle: .obliqueBottomLeft(theme))
        XCTAssertEqual(ModalTokens(from: properties).primaryButtonFont, Font(font))
    }

    /// `PlainSecondaryStyle`'s real counterpart is `ActionStyle.plain` — the same case
    /// `SwiftUIAlertModal`'s sentinel `Properties` already uses for `secondaryActionStyle`.
    func test_secondaryButtonFont_comesFromProperties_plainTheme() {
        let font = UIFont.systemFont(ofSize: 13, weight: .thin)
        let theme = GBAlertModal.ActionStyle.PlainTheme(titleFont: font)
        let properties = GBAlertModal.Properties(secondaryActionStyle: .plain(theme))
        XCTAssertEqual(ModalTokens(from: properties).secondaryButtonFont, Font(font))
    }

    /// **S3.** The secondary label colour must come from the SECONDARY style's own `PlainTheme`,
    /// never from `palette.accent` (the PRIMARY oblique theme's colour).
    ///
    /// The two themes are deliberately given different colours, so this fails under any derivation
    /// that aliases the two — including "fixing" it by assigning `secondaryLabel = accent`.
    func test_secondaryLabel_comesFromSecondaryTheme_notThePrimaryAccent() {
        let properties = GBAlertModal.Properties(
            primaryActionStyle: .obliqueBottomLeft(
                GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(unPressedColor: .systemRed)
            ),
            secondaryActionStyle: .plain(
                GBAlertModal.ActionStyle.PlainTheme(titleColor: .systemTeal)
            )
        )
        let tokens = ModalTokens(from: properties)

        XCTAssertEqual(tokens.palette.accent, Color(uiColor: .systemRed), "premise: RED primary")
        XCTAssertEqual(tokens.palette.secondaryLabel, Color(uiColor: .systemTeal))
        XCTAssertNotEqual(
            tokens.palette.secondaryLabel, tokens.palette.accent,
            "the secondary label must not be the primary theme's accent"
        )
    }

    func test_secondaryDisabledLabel_comesFromPlainTheme_titleDisableColor() {
        let properties = GBAlertModal.Properties(
            primaryActionStyle: .obliqueBottomLeft(
                GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(disabledColor: .systemRed)
            ),
            secondaryActionStyle: .plain(
                GBAlertModal.ActionStyle.PlainTheme(titleDisableColor: .systemMint)
            )
        )
        let tokens = ModalTokens(from: properties)

        XCTAssertEqual(tokens.palette.disabled, Color(uiColor: .systemRed), "premise: distinct")
        XCTAssertEqual(tokens.palette.secondaryDisabled, Color(uiColor: .systemMint))
        XCTAssertNotEqual(tokens.palette.secondaryDisabled, tokens.palette.disabled)
    }

    /// UIKit sets the oblique button's disabled title from `titleDisableColor`
    /// (`configureButtonActionStyle`), a field SwiftUI ignored entirely while both states read
    /// `onAccent`. The two are given different colours here so an aliased derivation fails.
    func test_primaryDisabledLabel_comesFromObliqueTheme_titleDisableColor() {
        let theme = GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
            titleColor: .systemPink,
            titleDisableColor: .systemMint
        )
        let tokens = ModalTokens(from: GBAlertModal.Properties(primaryActionStyle: .obliqueBottomLeft(theme)))

        XCTAssertEqual(tokens.palette.onAccent, Color(uiColor: .systemPink), "premise: distinct")
        XCTAssertEqual(tokens.palette.onAccentDisabled, Color(uiColor: .systemMint))
        XCTAssertNotEqual(tokens.palette.onAccentDisabled, tokens.palette.onAccent)
    }

    /// A `secondaryActionStyle` that ISN'T `.plain` has no colours the fixed SwiftUI text button
    /// can use — the mirror of `test_accentColors_keepStandardLiterals_whenActionStyleIsNotOblique`.
    func test_secondaryColors_keepStandardLiterals_whenActionStyleIsNotPlain() {
        let properties = GBAlertModal.Properties(
            secondaryActionStyle: .capsule(.init(titleColor: .systemRed))
        )
        let tokens = ModalTokens(from: properties)
        XCTAssertEqual(tokens.palette.secondaryLabel, ModalTokens.standard.palette.secondaryLabel)
        XCTAssertEqual(tokens.palette.secondaryDisabled, ModalTokens.standard.palette.secondaryDisabled)
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
