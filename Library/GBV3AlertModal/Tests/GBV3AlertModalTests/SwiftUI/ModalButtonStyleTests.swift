import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// The two fixed `ButtonStyle`s' COLOUR DECISIONS, asserted through the same pure functions their
/// view bodies call (`labelColor(tokens:isEnabled:)`) — so re-pointing a body at the wrong token
/// fails here rather than only on a device.
@MainActor
final class ModalButtonStyleColorTests: XCTestCase {

    /// **S3, at the view layer.** `oblique-red-leave-confirm` is `standardProperties()` with a RED
    /// oblique primary and the standard `.plain` secondary (`titleColor: .systemBlue`).
    ///
    /// DISCRIMINATION: under the old body — `foregroundColor(isEnabled ? tokens.palette.accent : …)`
    /// — this shape's secondary label was `accent`, i.e. RED. Both assertions below would fail
    /// (`.systemBlue != .systemRed`), and they fail again for anyone who re-points
    /// `PlainSecondaryStyle` at `palette.accent` later. A test that asserted the secondary label
    /// merely equals `standard`'s literal would NOT have discriminated: for the standard preset the
    /// primary and secondary colours coincide, which is exactly why this bug survived 25 shapes.
    func test_secondaryLabelColor_isTheSecondaryThemeColour_notTheAccent() {
        let tokens = ModalTokens(from: GeniePresets.obliqueRedProperties())

        XCTAssertEqual(tokens.palette.accent, Color(uiColor: .systemRed), "premise: RED primary")
        let label = PlainSecondaryStyle.labelColor(tokens: tokens, isEnabled: true)
        XCTAssertEqual(
            label, Color(uiColor: .systemBlue),
            "the secondary label must be the SECONDARY theme's titleColor"
        )
        XCTAssertNotEqual(label, tokens.palette.accent, "…and never the primary theme's accent")
    }

    /// The disabled half of the same split: the plain theme's `titleDisableColor` (`.lightGray`) is
    /// a different colour from the oblique theme's `disabledColor` (`.gray`) in this preset, so
    /// reading `palette.disabled` here fails.
    func test_secondaryDisabledColor_isThePlainThemeDisableColour() {
        let tokens = ModalTokens(from: GeniePresets.obliqueRedProperties())

        XCTAssertEqual(tokens.palette.disabled, Color(uiColor: .gray), "premise: distinct")
        let label = PlainSecondaryStyle.labelColor(tokens: tokens, isEnabled: false)
        XCTAssertEqual(label, Color(uiColor: .lightGray))
        XCTAssertNotEqual(label, tokens.palette.disabled)
    }

    /// The primary label switches to `onAccentDisabled` when disabled — `titleDisableColor`, which
    /// UIKit has always applied and SwiftUI ignored.
    func test_primaryLabelColor_usesTheDisabledTitleColour_whenDisabled() {
        let theme = GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
            titleColor: .systemPink,
            titleDisableColor: .systemMint
        )
        let tokens = ModalTokens(from: GBAlertModal.Properties(primaryActionStyle: .obliqueBottomLeft(theme)))

        XCTAssertEqual(
            ObliquePrimaryStyle.labelColor(tokens: tokens, isEnabled: true),
            Color(uiColor: .systemPink)
        )
        XCTAssertEqual(
            ObliquePrimaryStyle.labelColor(tokens: tokens, isEnabled: false),
            Color(uiColor: .systemMint)
        )
    }
}
