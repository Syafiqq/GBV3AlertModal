// AlertResolutionTests.swift
import XCTest
import GBV3AlertModal
@testable import GBV3AlertModalExample

// @MainActor: `UIKitModalRenderer.AlertHolder.make` (used by `resolved(_:)`) is main-actor gated.
@MainActor
final class AlertResolutionTests: XCTestCase {

    // MARK: ResolvedModal (shared resolver, spec C-1) — slot visibility
    //
    // These used to construct this app's own hand-rolled 5-bool slot struct (now deleted). They
    // now run the SAME chain `SwiftUIAlertModal` and the UIKit renderer both use: `AlertHolder.make` (the
    // descriptor→`DataHolder` mapping) into `GBAlertModal.resolve` (the library's 11-field
    // resolver). See `SharedResolverTests` in the library test target for the pinning tests on
    // that chain itself; these exercise it against this app's own `cfg`/`alert` fixtures.
    private func resolved(_ config: AlertDialog) -> GBAlertModal.ResolvedModal {
        let holder = UIKitModalRenderer.AlertHolder.make(for: config, resolve: { _ in })
        return GBAlertModal.resolve(
            properties: GBAlertModal.Properties(
                primaryActionStyle: .plain(.init()),
                secondaryActionStyle: .plain(.init())
            ),
            holder: holder,
            isLandscape: false
        )
    }

    func test_banner_shows_iff_image_present() {
        XCTAssertTrue(resolved(cfg(image: ModalImage("img_illust_onboarding"))).showsBanner)
        XCTAssertFalse(resolved(cfg(image: nil)).showsBanner)
    }

    func test_title_shows_iff_nonEmpty() {
        XCTAssertTrue(resolved(cfg(title: "Hi")).showsTitle)
        XCTAssertFalse(resolved(cfg(title: nil)).showsTitle)
        XCTAssertFalse(resolved(cfg(title: "")).showsTitle)
    }

    func test_subtitle_shows_iff_nonEmpty() {
        XCTAssertNotEqual(resolved(cfg(subtitle: "Body")).subtitle, .none)
        XCTAssertEqual(resolved(cfg(subtitle: nil)).subtitle, .none)
        XCTAssertEqual(resolved(cfg(subtitle: "")).subtitle, .none)
    }

    func test_secondary_shows_iff_nonNil() {
        XCTAssertTrue(resolved(cfg(secondary: "Cancel")).showsSecondary)
        XCTAssertFalse(resolved(cfg(secondary: nil)).showsSecondary)
        // Behavior correction picked up from the shared resolver: unlike this app's old hand-rolled
        // slot struct (which isEmpty-checked `secondary`), `ResolvedModal.showsSecondary` mirrors
        // the real UIKit `registerDialogView` exactly — it nil-checks `secondaryAction` only. An
        // explicit non-nil empty string is a configured (if blank-titled) secondary action, so it
        // now shows, matching production instead of the example's own approximation.
        XCTAssertTrue(resolved(cfg(secondary: "")).showsSecondary)
    }

    func test_close_shows_iff_flag_set() {
        XCTAssertTrue(resolved(cfg(showCloseButton: true)).showsCloseButton)
        XCTAssertFalse(resolved(cfg(showCloseButton: false)).showsCloseButton)
    }

    // MARK: resolve — interaction routing

    func test_primary_tap_resolves_primary() {
        XCTAssertEqual(resolve(.primaryTapped, cfg()), .primary)
    }

    func test_secondary_tap_resolves_secondary() {
        XCTAssertEqual(resolve(.secondaryTapped, cfg(secondary: "Cancel")), .secondary)
    }

    func test_close_tap_resolves_dismissed() {
        XCTAssertEqual(resolve(.closeTapped, cfg(showCloseButton: true)), .dismissed)
    }

    func test_overlay_tap_resolves_dismissed_only_when_enabled() {
        XCTAssertEqual(resolve(.overlayTapped, cfg(closeOnTapOverlay: true)), .dismissed)
        XCTAssertNil(resolve(.overlayTapped, cfg(closeOnTapOverlay: false)))
    }

    // MARK: ResolvedModal — AttributedString era (matches the descriptor's AttributedString? type)

    func test_attributed_title_shows_when_present_hidden_when_empty() {
        XCTAssertTrue(resolved(alert(title: AttributedString("Hi"))).showsTitle)
        XCTAssertFalse(resolved(alert(title: AttributedString(""))).showsTitle)
    }

    func test_attributed_subtitle_shows_when_present_hidden_when_empty() {
        XCTAssertNotEqual(resolved(alert(subtitle: AttributedString("Body"))).subtitle, .none)
        XCTAssertEqual(resolved(alert(subtitle: AttributedString(""))).subtitle, .none)
    }

    /// The resolver's title/subtitle presence checks key on `String.isEmpty`, so a single space is
    /// non-empty and DOES show — same semantics this app's old hand-rolled slot struct pinned via
    /// its `present` helper. Pin it so a "trim" refactor is a decision.
    func test_whitespace_title_is_shown() {
        XCTAssertTrue(resolved(cfg(title: " ")).showsTitle)
    }

    // MARK: ResolvedModal — combinations & independence

    func test_all_slots_present_all_show() {
        let r = resolved(cfg(
            image: ModalImage("img_illust_onboarding"), title: "T", subtitle: "S",
            secondary: "Cancel", showCloseButton: true
        ))
        XCTAssertTrue(r.showsBanner && r.showsTitle && r.subtitle != .none && r.showsSecondary && r.showsCloseButton)
    }

    func test_showClose_independent_of_overlay_flag() {
        XCTAssertTrue(resolved(cfg(closeOnTapOverlay: false, showCloseButton: true)).showsCloseButton)
        XCTAssertFalse(resolved(cfg(closeOnTapOverlay: true, showCloseButton: false)).showsCloseButton)
    }

    // MARK: resolve — button routing is unconditional (only overlay is flag-gated)

    func test_close_and_secondary_routing_independent_of_show_flags() {
        // resolve() maps the interaction regardless of visibility flags; the VIEW gates what's tappable.
        XCTAssertEqual(resolve(.closeTapped, cfg(showCloseButton: false)), .dismissed)
        XCTAssertEqual(resolve(.secondaryTapped, cfg(secondary: nil)), .secondary)
    }

    // MARK: no-blink swap (D4) — returns a value to assign IN PLACE, never nil

    func test_noBlinkSwap_toggles_between_a_and_b() {
        let a = AlertDialog(title: "A", primary: "PrimA")
        let b = AlertDialog(title: "B", primary: "PrimB")
        XCTAssertEqual(noBlinkSwap(current: a, between: a, and: b).primary, "PrimB")
        XCTAssertEqual(noBlinkSwap(current: b, between: a, and: b).primary, "PrimA")
    }

    // MARK: helper — one place to vary a single field

    private func cfg(
        image: ModalImage? = nil,
        title: String? = "Title",
        subtitle: String? = "Subtitle",
        primary: String = "OK",
        secondary: String? = nil,
        closeOnTapOverlay: Bool = false,
        showCloseButton: Bool = false
    ) -> AlertDialog {
        AlertDialog(
            image: image, title: title, subtitle: subtitle,
            primary: primary, secondary: secondary,
            closeOnTapOverlay: closeOnTapOverlay, showCloseButton: showCloseButton
        )
    }

    /// Same as `cfg` but exercises the AttributedString init (title/subtitle typed AttributedString?).
    private func alert(
        title: AttributedString? = nil,
        subtitle: AttributedString? = nil
    ) -> AlertDialog {
        AlertDialog(title: title, subtitle: subtitle, primary: "OK")
    }
}
