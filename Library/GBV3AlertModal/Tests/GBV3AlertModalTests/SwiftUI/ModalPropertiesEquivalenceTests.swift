import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **The gate for a 250-line parallel type: the SAME preset, expressed both ways, must derive an
/// IDENTICAL `ModalTokens`.**
///
/// `ModalProperties` is a deliberate transcription of `GBAlertModal.Properties` (spec §3a: a
/// parallel type, not a translation layer), and `ModalTokens.init(from: ModalProperties)` is a
/// deliberate transcription of `init(from: GBAlertModal.Properties)`. The dominant failure mode for
/// both is not a subtle logic error — it is a field read into the wrong token, or dropped, or a
/// min/max pair swapped. That failure is invisible to every existing test, because each side is
/// self-consistent.
///
/// **This is deliberately NOT a field-by-field re-transcription.** A test that asserted
/// `tokens.gapBelowTitle == 8` once per field would be a third copy of the same list, wrong in the
/// same way if the reader misread the source. Building one preset both ways and comparing the whole
/// derived value means a mistake has to be made IDENTICALLY in three places to survive.
///
/// ## The one thing this cannot prove, stated plainly
///
/// Colours are given to the SwiftUI side as `Color(uiColor:)` of the very `UIColor` the UIKit side
/// gets, not as a native `Color` literal. That is forced: `Color(uiColor: .red)` and `Color.red` are
/// different values to `==` (different providers), so writing the SwiftUI preset "natively" would
/// fail on colour identity rather than on anything this test is about. So this proves the two
/// DERIVATIONS route the same colour to the same token — it does not prove `.red` and `UIColor.red`
/// render alike, which is a platform question and not this library's.
@MainActor
final class ModalPropertiesEquivalenceTests: XCTestCase {

    /// Every field set, and each to a DISTINCT value.
    ///
    /// Distinctness is the point: a derivation that read `subtitleColor` into `palette.titleText`
    /// would pass against a preset that used one colour twice. Same reasoning for the eight padding
    /// edges, the four widths and the four gaps — all different numbers, so a swap has nowhere to
    /// hide.
    private static let uiKit = GBAlertModal.Properties(
        baseTint: .systemPink,
        overlayColor: .systemTeal,
        contentProperty: GBAlertModal.Properties.ContentProperty(
            backgroundColor: .systemGray6,
            cornerRadius: 13,
            fixedWidthPortrait: 257,
            maxWidthPortrait: 258,
            fixedWidthLandscape: 259,
            maxWidthLandscape: 260,
            childShouldMatchParent: true
        ),
        margin: UIEdgeInsets(top: 21, left: 22, bottom: 23, right: 24),
        padding: UIMinMaxEdgeInsets(top: (1, 2), left: (3, 4), bottom: (5, 6), right: (7, 8)),
        bannerRatio: 1.75,
        bannerMaxHeight: 161,
        bannerFixedHeight: 162,   // no SwiftUI counterpart — see the assertion that pins its absence
        titleFont: .systemFont(ofSize: 25, weight: .heavy),
        titleColor: .systemIndigo,
        subtitleFont: .systemFont(ofSize: 17, weight: .light),
        subtitleColor: .systemBrown,
        buttonActionShouldMatchParent: true,
        buttonActionOrientation: .horizontal,
        primaryActionStyle: .obliqueBottomLeft(
            GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
                unPressedColor: .systemRed,
                pressedColor: .systemBlue,
                disabledColor: .systemGray,
                shadowColor: UIColor.systemOrange.cgColor,
                titleColor: .systemYellow,
                titleDisableColor: .systemMint,
                titleFont: .systemFont(ofSize: 18, weight: .black)
            )
        ),
        secondaryActionStyle: .plain(
            GBAlertModal.ActionStyle.PlainTheme(
                titleColor: .systemGreen,
                titleDisableColor: .systemPurple,
                titleFont: .systemFont(ofSize: 19, weight: .medium)
            )
        ),
        closeButtonTint: .systemCyan,
        space: GBAlertModal.Properties.ComponentSpace(banner: 9, title: 10, subtitle: 11, interButton: 12)
    )

    /// The same preset in SwiftUI's vocabulary. Read it beside the one above: the field names and
    /// the order are identical, which is the whole of §3a.
    private static let swiftUI = ModalProperties(
        baseTint: Color(uiColor: .systemPink),
        overlayColor: Color(uiColor: .systemTeal),
        contentProperty: ModalProperties.ContentProperty(
            backgroundColor: Color(uiColor: .systemGray6),
            cornerRadius: 13,
            fixedWidthPortrait: 257,
            maxWidthPortrait: 258,
            fixedWidthLandscape: 259,
            maxWidthLandscape: 260,
            childShouldMatchParent: true
        ),
        margin: EdgeInsets(top: 21, leading: 22, bottom: 23, trailing: 24),
        padding: UIMinMaxEdgeInsets(top: (1, 2), left: (3, 4), bottom: (5, 6), right: (7, 8)),
        bannerRatio: 1.75,
        bannerMaxHeight: 161,
        titleFont: .system(size: 25, weight: .heavy),
        titleColor: Color(uiColor: .systemIndigo),
        subtitleFont: .system(size: 17, weight: .light),
        subtitleColor: Color(uiColor: .systemBrown),
        buttonActionShouldMatchParent: true,
        buttonActionOrientation: .horizontal,
        primaryActionStyle: .obliqueBottomLeft(
            ModalProperties.ActionStyle.ObliqueBottomLeftTheme(
                unPressedColor: Color(uiColor: .systemRed),
                pressedColor: Color(uiColor: .systemBlue),
                disabledColor: Color(uiColor: .systemGray),
                shadowColor: Color(cgColor: UIColor.systemOrange.cgColor),
                titleColor: Color(uiColor: .systemYellow),
                titleDisableColor: Color(uiColor: .systemMint),
                titleFont: .system(size: 18, weight: .black)
            )
        ),
        secondaryActionStyle: .plain(
            ModalProperties.ActionStyle.PlainTheme(
                titleColor: Color(uiColor: .systemGreen),
                titleDisableColor: Color(uiColor: .systemPurple),
                titleFont: .system(size: 19, weight: .medium)
            )
        ),
        closeButtonTint: Color(uiColor: .systemCyan),
        space: ModalProperties.ComponentSpace(banner: 9, title: 10, subtitle: 11, interButton: 12)
    )

    // MARK: - The gate

    /// **`bannerFixedHeight` is the ONLY field the two derivations are allowed to differ on**, and
    /// it is compared explicitly here so the equality below can be unqualified. The field is
    /// measured inert on both UIKit paths and is deliberately absent from `ModalProperties`, so the
    /// SwiftUI derivation keeps `standard`'s nil.
    func test_theOnlyDerivedDifference_isTheDeadBannerField() {
        XCTAssertEqual(ModalTokens(from: Self.uiKit).bannerFixedHeight, 162)
        XCTAssertNil(
            ModalTokens(from: Self.swiftUI).bannerFixedHeight,
            "ModalProperties has no bannerFixedHeight, so the token must keep standard's nil"
        )
    }

    func test_bothVocabularies_deriveTheSameTokens() {
        var fromUIKit = ModalTokens(from: Self.uiKit)
        let fromSwiftUI = ModalTokens(from: Self.swiftUI)

        // Normalise the ONE documented difference, pinned on its own above, so what remains is an
        // unqualified equality over every other field.
        fromUIKit.bannerFixedHeight = nil

        XCTAssertEqual(fromUIKit, fromSwiftUI)
    }

    /// The comparison above is only worth anything if `ModalTokens`' `==` can say NO. `Equatable`
    /// here is synthesised, so this guards the synthesis actually covering the nested `Palette` and
    /// `UIMinMaxEdgeInsets` rather than some shallow identity.
    func test_theComparisonCanFail() {
        var moved = ModalTokens(from: Self.swiftUI)
        moved.palette.secondaryDisabled = Color(uiColor: .systemFill)
        XCTAssertNotEqual(ModalTokens(from: Self.swiftUI), moved)

        var padded = ModalTokens(from: Self.swiftUI)
        padded.contentPadding = UIMinMaxEdgeInsets(top: (1, 2), left: (3, 4), bottom: (5, 6), right: (7, 9))
        XCTAssertNotEqual(ModalTokens(from: Self.swiftUI), padded)

        var refonted = ModalTokens(from: Self.swiftUI)
        refonted.titleFont = .system(size: 25, weight: .bold)
        XCTAssertNotEqual(ModalTokens(from: Self.swiftUI), refonted)
    }

    // MARK: - One resolver, both vocabularies

    /// **The claim §5 was written to give up: both configurations decide the SAME structure.**
    ///
    /// The spec expected a SwiftUI-native config to force a second resolver, and accepted that
    /// "'by construction' stops being true and the gate becomes the only thing holding the two
    /// together". `GBAlertModal.resolve` turned out to read exactly five things from a
    /// configuration, so `ModalStructureInputs` lets both feed the one resolver — and this is the
    /// test that says so rather than the doc comment.
    ///
    /// BOTH orientations, because two of those five fields are orientation-sensitive and the
    /// preset states four DISTINCT widths: portrait must read 257/258 and landscape 259/260, so a
    /// derivation that dropped the landscape fallback would pass a portrait-only test.
    func test_bothVocabularies_resolveTheSameStructure() {
        let holder = UIKitModalRenderer.AlertHolder.make(
            for: AlertDialog(title: "T", subtitle: "S", primary: "OK", secondary: "No"),
            resolve: { _ in }
        )

        for isLandscape in [false, true] {
            XCTAssertEqual(
                GBAlertModal.resolve(inputs: Self.uiKit, holder: holder, isLandscape: isLandscape),
                GBAlertModal.resolve(inputs: Self.swiftUI, holder: holder, isLandscape: isLandscape),
                "the two vocabularies disagree at isLandscape: \(isLandscape)"
            )
        }
    }

    /// Non-vacuity for the above: a resolver that returned an all-default `ResolvedModal` for both
    /// inputs would satisfy it perfectly. These are the five fields a configuration actually
    /// decides, read off the SwiftUI side, each at a value only this preset produces.
    func test_theResolvedStructure_actuallyReflectsTheConfiguration() {
        let holder = UIKitModalRenderer.AlertHolder.make(
            for: AlertDialog(title: "T", subtitle: "S", primary: "OK", secondary: "No"),
            resolve: { _ in }
        )

        let portrait = GBAlertModal.resolve(inputs: Self.swiftUI, holder: holder, isLandscape: false)
        XCTAssertTrue(portrait.showsPrimary)
        XCTAssertTrue(portrait.showsSecondary)
        XCTAssertTrue(portrait.buttonsMatchParent)
        XCTAssertEqual(portrait.buttonAxis, .horizontal)
        XCTAssertEqual(portrait.contentWidth, .fixedAndMax(fixed: 257, max: 258))

        let landscape = GBAlertModal.resolve(inputs: Self.swiftUI, holder: holder, isLandscape: true)
        XCTAssertEqual(landscape.contentWidth, .fixedAndMax(fixed: 259, max: 260))
    }

    /// The `Properties` overload is now a forwarder. If it ever stops agreeing with the one it
    /// forwards to, every existing caller silently gets a different answer from the tests.
    func test_theLegacyOverload_forwardsToTheSameResolver() {
        let holder = UIKitModalRenderer.AlertHolder.make(
            for: AlertDialog(title: "T", subtitle: "S", primary: "OK", secondary: "No"),
            resolve: { _ in }
        )

        XCTAssertEqual(
            GBAlertModal.resolve(properties: Self.uiKit, holder: holder, isLandscape: false),
            GBAlertModal.resolve(inputs: Self.uiKit, holder: holder, isLandscape: false)
        )
    }

    /// A `ModalProperties`-driven `SwiftUIAlertModal` is the end-to-end point of the pass: a caller
    /// can now build the public SwiftUI view without naming a single UIKit type — `ModalProperties`
    /// for structure, `ModalTokens(from:)` for styling.
    func test_theViewAcceptsTheSwiftUIVocabulary() {
        let view = SwiftUIAlertModal(
            config: AlertDialog(title: "T", subtitle: "S", primary: "OK"),
            properties: Self.swiftUI,
            tokens: ModalTokens(from: Self.swiftUI),
            onAction: { _ in }
        )

        XCTAssertEqual(view.tokens, ModalTokens(from: Self.swiftUI))
        XCTAssertEqual(view.tokens.contentMaxWidth, 257, "min(fixed 257, max 258)")
    }

    // MARK: - Defaults

    /// **An empty config derives `standard` MINUS the banner fields — not `standard`.**
    ///
    /// Worth stating precisely, because the obvious phrasing ("an empty config derives `standard`")
    /// is false and this test asserted it on the first run. `standard` ships a 160pt
    /// `bannerMaxHeight`; both derivations assign the banner fields UNCONDITIONALLY, because there
    /// `nil` means "install no such constraint" rather than "no opinion" — so an empty config
    /// CLEARS the cap. `test_theBannerCap_isClearedByAConfigThatOmitsIt_onBothSides` below is the
    /// direct statement of that; this one pins that it is the ONLY divergence from `standard`, and
    /// that both vocabularies diverge identically.
    func test_anEmptyConfig_derivesStandardExceptTheBannerFields_onBothSides() {
        let fromUIKit = ModalTokens(from: GBAlertModal.Properties())
        let fromSwiftUI = ModalTokens(from: ModalProperties())

        XCTAssertEqual(fromUIKit, fromSwiftUI, "the two empty configs must agree with each other")

        var expected = ModalTokens.standard
        expected.bannerRatio = nil
        expected.bannerMaxHeight = nil
        expected.bannerFixedHeight = nil
        XCTAssertEqual(fromSwiftUI, expected)
    }

    /// The banner fields are assigned UNCONDITIONALLY on both paths, because nil is a positive
    /// statement there ("install no such constraint") rather than "no opinion". A config that says
    /// nothing must therefore CLEAR `standard`'s 160pt cap, not inherit it.
    func test_theBannerCap_isClearedByAConfigThatOmitsIt_onBothSides() {
        XCTAssertEqual(ModalTokens.standard.bannerMaxHeight, 160)
        XCTAssertNil(ModalTokens(from: GBAlertModal.Properties()).bannerMaxHeight)
        XCTAssertNil(ModalTokens(from: ModalProperties()).bannerMaxHeight)
    }
}
