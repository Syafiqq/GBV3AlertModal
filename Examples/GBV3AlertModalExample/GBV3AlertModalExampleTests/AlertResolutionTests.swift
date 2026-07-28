// AlertResolutionTests.swift
import XCTest
import GBV3AlertModal
@testable import GBV3AlertModalExample

final class AlertResolutionTests: XCTestCase {

    // MARK: ResolvedAlert — slot visibility

    func test_banner_shows_iff_image_present() {
        XCTAssertTrue(ResolvedAlert(cfg(image: ModalImage("x"))).showsBanner)
        XCTAssertFalse(ResolvedAlert(cfg(image: nil)).showsBanner)
    }

    func test_title_shows_iff_nonEmpty() {
        XCTAssertTrue(ResolvedAlert(cfg(title: "Hi")).showsTitle)
        XCTAssertFalse(ResolvedAlert(cfg(title: nil)).showsTitle)
        XCTAssertFalse(ResolvedAlert(cfg(title: "")).showsTitle)
    }

    func test_subtitle_shows_iff_nonEmpty() {
        XCTAssertTrue(ResolvedAlert(cfg(subtitle: "Body")).showsSubtitle)
        XCTAssertFalse(ResolvedAlert(cfg(subtitle: nil)).showsSubtitle)
        XCTAssertFalse(ResolvedAlert(cfg(subtitle: "")).showsSubtitle)
    }

    func test_secondary_shows_iff_nonEmpty() {
        XCTAssertTrue(ResolvedAlert(cfg(secondary: "Cancel")).showsSecondary)
        XCTAssertFalse(ResolvedAlert(cfg(secondary: nil)).showsSecondary)
        XCTAssertFalse(ResolvedAlert(cfg(secondary: "")).showsSecondary)
    }

    func test_close_shows_iff_flag_set() {
        XCTAssertTrue(ResolvedAlert(cfg(showCloseButton: true)).showsClose)
        XCTAssertFalse(ResolvedAlert(cfg(showCloseButton: false)).showsClose)
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

    // MARK: ResolvedAlert — AttributedString era (matches the descriptor's AttributedString? type)

    func test_attributed_title_shows_when_present_hidden_when_empty() {
        XCTAssertTrue(ResolvedAlert(alert(title: AttributedString("Hi"))).showsTitle)
        XCTAssertFalse(ResolvedAlert(alert(title: AttributedString(""))).showsTitle)
    }

    func test_attributed_subtitle_shows_when_present_hidden_when_empty() {
        XCTAssertTrue(ResolvedAlert(alert(subtitle: AttributedString("Body"))).showsSubtitle)
        XCTAssertFalse(ResolvedAlert(alert(subtitle: AttributedString(""))).showsSubtitle)
    }

    /// `present` keys on `.characters.isEmpty`, so a single space is non-empty and DOES show —
    /// same semantics as the UIKit `!(s ?? "").isEmpty`. Pin it so a "trim" refactor is a decision.
    func test_whitespace_title_is_shown() {
        XCTAssertTrue(ResolvedAlert(cfg(title: " ")).showsTitle)
    }

    // MARK: ResolvedAlert — combinations & independence

    func test_all_slots_present_all_show() {
        let r = ResolvedAlert(cfg(
            image: ModalImage("x"), title: "T", subtitle: "S",
            secondary: "Cancel", showCloseButton: true
        ))
        XCTAssertTrue(r.showsBanner && r.showsTitle && r.showsSubtitle && r.showsSecondary && r.showsClose)
    }

    func test_showClose_independent_of_overlay_flag() {
        XCTAssertTrue(ResolvedAlert(cfg(closeOnTapOverlay: false, showCloseButton: true)).showsClose)
        XCTAssertFalse(ResolvedAlert(cfg(closeOnTapOverlay: true, showCloseButton: false)).showsClose)
    }

    // MARK: resolve — button routing is unconditional (only overlay is flag-gated)

    func test_close_and_secondary_routing_independent_of_show_flags() {
        // resolve() maps the interaction regardless of visibility flags; the VIEW gates what's tappable.
        XCTAssertEqual(resolve(.closeTapped, cfg(showCloseButton: false)), .dismissed)
        XCTAssertEqual(resolve(.secondaryTapped, cfg(secondary: nil)), .secondary)
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
