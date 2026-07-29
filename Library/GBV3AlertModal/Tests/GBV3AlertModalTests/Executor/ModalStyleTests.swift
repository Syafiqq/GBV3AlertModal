import UIKit
import XCTest
@testable import GBV3AlertModal

/// Two CONSUMER-DEFINED styles, declared exactly the way a consuming app declares its own presets.
/// That this compiles from outside `ModalStyle`'s own file IS the extensibility claim: a new app
/// preset needs no library change, which a closed `enum` could not offer.
private extension ModalStyle {
    /// Registered by the tests that exercise the happy path.
    static let badge = ModalStyle("badge")
    /// NEVER registered anywhere — the fallback probe.
    static let ghost = ModalStyle("ghost")
}

/// `ModalStyle`: the style token that decouples a design-system PRESET from the descriptor TYPE.
///
/// Before this, style identity WAS descriptor identity (`PopupDialog` is a content-identical twin of
/// `AlertDialog` that exists only to be registered with different `Properties`). The app has five
/// presets plus per-entry overrides, so that approach grows the type count with the design system.
/// These tests pin the three behaviours that make the token safe to adopt: the default is inert,
/// a registered style really does change the rendered styling, and an unregistered one degrades to
/// `.standard` instead of crashing or rendering un-styled.
@MainActor
final class ModalStyleTests: XCTestCase {

    // MARK: - The token itself

    func test_modalStyle_isNameKeyed_andBuiltInsAreDistinct() {
        XCTAssertEqual(ModalStyle("badge").name, "badge")
        XCTAssertEqual(ModalStyle.standard.name, "standard")
        XCTAssertEqual(ModalStyle.popup.name, "popup")
        XCTAssertNotEqual(ModalStyle.standard, ModalStyle.popup)
        // Name equality, not reference/declaration equality: the consumer's `ModalStyle("badge")`
        // and the renderer's `.badge` registration must be the SAME key.
        XCTAssertEqual(ModalStyle("badge"), ModalStyle.badge)
        XCTAssertEqual(Set([ModalStyle("badge"), ModalStyle.badge]).count, 1, "must hash by name")
    }

    // MARK: - Descriptor defaults (the ~114 existing call sites)

    /// Both `AlertDialog` initializers default to `.standard`, so no existing call site changes
    /// meaning. The third case proves the String convenience PASSES THE TOKEN THROUGH to the
    /// AttributedString canonical init rather than dropping it.
    func test_alertDialog_defaultsToStandard_onBothInits() {
        XCTAssertEqual(
            AlertDialog(title: "T", subtitle: "S", primary: "OK").style, .standard,
            "the String convenience must default to .standard"
        )
        XCTAssertEqual(
            AlertDialog(title: AttributedString("T"), subtitle: nil, primary: "OK").style, .standard,
            "the AttributedString canonical init must default to .standard"
        )
        XCTAssertEqual(
            AlertDialog(title: "T", primary: "OK", style: .badge).style, .badge,
            "the String convenience must forward the token to the canonical init"
        )
        XCTAssertEqual(
            AlertDialog(
                title: AttributedString("T"), subtitle: nil, primary: "OK", style: .badge
            ).style,
            .badge
        )
    }

    /// `PopupDialog` is retained for source compatibility and pinned to `.popup`, so the old
    /// type-per-style spelling and the new token resolve through the SAME map entry.
    func test_popupDialog_carriesThePopupStyle() {
        XCTAssertEqual(PopupDialog(title: "T", primary: "OK").style, .popup)
    }

    // MARK: - A registered style renders with ITS Properties

    /// Discrimination: the asserted fields are ones where `badgeProperties()` and
    /// `standardProperties()` genuinely differ, and each is checked against BOTH the expected badge
    /// value AND the standard value it must not equal — so a renderer that ignored `style` entirely
    /// (and silently used the `.standard` entry) fails here rather than passing by coincidence.
    func test_registeredStyle_rendersWithThatStylesProperties_onBothRenderers() async throws {
        let standardTokens = ModalTokens(from: GeniePresets.standardProperties())
        for kind in RendererKind.allCases {
            let harness = RendererHarness(kind)
            harness.register(style: .badge, properties: GeniePresets.badgeProperties())
            let executor = DefaultModalExecutor(renderer: harness.renderer)

            let token = executor.present(
                AlertDialog(title: "T", subtitle: "S", primary: "OK", style: .badge)
            )
            XCTAssertTrue(harness.isLive(token.id), "renderer \(kind.rawValue) never presented")
            let properties = try XCTUnwrap(
                harness.effectiveProperties(token.id), "renderer \(kind.rawValue)"
            )
            let tokens = ModalTokens(from: properties)

            XCTAssertEqual(tokens.cornerRadius, 28, "renderer \(kind.rawValue) ignored .badge")
            XCTAssertNotEqual(
                tokens.cornerRadius, standardTokens.cornerRadius,
                "renderer \(kind.rawValue): premise — the badge preset must differ from standard"
            )
            XCTAssertEqual(tokens.cardMaxWidth, 300, "renderer \(kind.rawValue) ignored .badge")
            XCTAssertNotEqual(tokens.cardMaxWidth, standardTokens.cardMaxWidth)
            XCTAssertEqual(
                properties.titleColor, UIColor.magenta,
                "renderer \(kind.rawValue): the style's titleColor must reach the render input"
            )

            // The styled modal is still a fully functional modal, not a styling-only side effect.
            harness.emit(.primary, on: token.id)
            let result = await token.result
            XCTAssertEqual(result, .primary, "renderer \(kind.rawValue) diverged")
        }
    }

    /// The token is per-DESCRIPTOR, not per-registration: two `AlertDialog`s presented through the
    /// one built-in registration render with different `Properties`. This is the property that makes
    /// the type-per-style explosion unnecessary.
    func test_twoStyles_shareOneRegistration_onBothRenderers() throws {
        for kind in RendererKind.allCases {
            let harness = RendererHarness(kind)
            harness.register(style: .badge, properties: GeniePresets.badgeProperties())
            let executor = DefaultModalExecutor(renderer: harness.renderer)

            let plain = executor.present(AlertDialog(title: "A", primary: "OK"))
            let badged = executor.present(AlertDialog(title: "B", primary: "OK", style: .badge))

            let plainRadius = try XCTUnwrap(harness.effectiveProperties(plain.id))
                .contentProperty?.cornerRadius
            let badgedRadius = try XCTUnwrap(harness.effectiveProperties(badged.id))
                .contentProperty?.cornerRadius
            XCTAssertEqual(plainRadius, 16, "renderer \(kind.rawValue)")
            XCTAssertEqual(badgedRadius, 28, "renderer \(kind.rawValue)")

            executor.dismiss(plain)
            executor.dismiss(badged)
        }
    }

    // MARK: - An unregistered style falls back to .standard, observably

    /// `.ghost` is never registered, while `.badge` IS — so "fell back to standard" is provably
    /// different from "picked some other registered style" and from "picked nothing". Nothing traps:
    /// the modal presents, styles as standard, and still resolves normally.
    func test_unregisteredStyle_fallsBackToStandard_withoutCrashing_onBothRenderers() async throws {
        let standardTokens = ModalTokens(from: GeniePresets.standardProperties())
        for kind in RendererKind.allCases {
            let harness = RendererHarness(kind)
            harness.register(style: .badge, properties: GeniePresets.badgeProperties())
            let executor = DefaultModalExecutor(renderer: harness.renderer)

            XCTAssertTrue(
                harness.isRegistered(style: .badge),
                "renderer \(kind.rawValue): premise — .badge IS registered"
            )
            XCTAssertFalse(
                harness.isRegistered(style: .ghost),
                "renderer \(kind.rawValue): premise — .ghost is NOT registered; this is the fallback"
            )

            let token = executor.present(AlertDialog(title: "T", primary: "OK", style: .ghost))
            XCTAssertTrue(
                harness.isLive(token.id),
                "renderer \(kind.rawValue): an unregistered STYLE must still present"
            )
            let properties = try XCTUnwrap(harness.effectiveProperties(token.id))
            let tokens = ModalTokens(from: properties)

            XCTAssertEqual(
                tokens.cornerRadius, standardTokens.cornerRadius,
                "renderer \(kind.rawValue): an unregistered style must fall back to .standard"
            )
            XCTAssertNotEqual(
                tokens.cornerRadius, 28,
                "renderer \(kind.rawValue): it must NOT pick some other registered style"
            )
            XCTAssertEqual(properties.titleColor, GeniePresets.standardProperties().titleColor)

            harness.emit(.primary, on: token.id)
            let result = await token.result
            XCTAssertEqual(
                result, .primary,
                "renderer \(kind.rawValue): a fallback-styled modal must still resolve"
            )
        }
    }

    // MARK: - Registration timing / precedence

    /// The lookup runs inside the FACTORY, i.e. per present — so a preset registered AFTER the
    /// renderer was built still applies, and `.standard` itself is replaceable.
    func test_stylesRegisteredAfterInit_apply_andStandardIsReplaceable_onBothRenderers() throws {
        for kind in RendererKind.allCases {
            let harness = RendererHarness(kind)
            let executor = DefaultModalExecutor(renderer: harness.renderer)

            harness.register(style: .standard, properties: GeniePresets.badgeProperties())
            let token = executor.present(AlertDialog(title: "T", primary: "OK"))

            let properties = try XCTUnwrap(harness.effectiveProperties(token.id))
            XCTAssertEqual(
                properties.contentProperty?.cornerRadius, 28,
                "renderer \(kind.rawValue): re-registering .standard must take effect"
            )
            executor.dismiss(token)
        }
    }

    /// `update(_:to:)` re-runs the factory, so it re-resolves the style too: a live modal can be
    /// restyled in place on both backends.
    func test_update_restylesInPlace_onBothRenderers() throws {
        for kind in RendererKind.allCases {
            let harness = RendererHarness(kind)
            harness.register(style: .badge, properties: GeniePresets.badgeProperties())
            let executor = DefaultModalExecutor(renderer: harness.renderer)

            let token = executor.present(AlertDialog(title: "T", primary: "OK"))
            XCTAssertEqual(
                try XCTUnwrap(harness.effectiveProperties(token.id)).contentProperty?.cornerRadius,
                16,
                "renderer \(kind.rawValue): premise — starts standard"
            )

            executor.update(token, to: AlertDialog(title: "T", primary: "OK", style: .badge))

            XCTAssertEqual(
                try XCTUnwrap(harness.effectiveProperties(token.id)).contentProperty?.cornerRadius,
                28,
                "renderer \(kind.rawValue): update must re-resolve the style"
            )
            XCTAssertEqual(harness.liveCount, 1, "renderer \(kind.rawValue)")
            executor.dismiss(token)
        }
    }

    // MARK: - PopupDialog keeps working through the same map

    /// Source compatibility: `PopupDialog` and `AlertDialog(style: .popup)` resolve to the SAME
    /// preset, because `PopupDialog.style` is pinned to `.popup` and both go through
    /// `properties(for:)`.
    func test_popupDialog_andPopupStyledAlert_resolveTheSamePreset_onBothRenderers() throws {
        for kind in RendererKind.allCases {
            let harness = RendererHarness(kind)   // seeded with popupProperties()
            let executor = DefaultModalExecutor(renderer: harness.renderer)

            let viaType = executor.present(PopupDialog(title: "T", primary: "OK"))
            let viaToken = executor.present(AlertDialog(title: "T", primary: "OK", style: .popup))

            let typeSpace = try XCTUnwrap(harness.effectiveProperties(viaType.id)).space
            let tokenSpace = try XCTUnwrap(harness.effectiveProperties(viaToken.id)).space
            // popupProperties() overrides ComponentSpace to 16/16/24/8; standard is 8/8/16/8.
            XCTAssertEqual(typeSpace?.subtitle, 24, "renderer \(kind.rawValue): premise")
            XCTAssertEqual(
                tokenSpace?.subtitle, typeSpace?.subtitle,
                "renderer \(kind.rawValue): .popup must reach the same preset PopupDialog does"
            )

            executor.dismiss(viaType)
            executor.dismiss(viaToken)
        }
    }
}
