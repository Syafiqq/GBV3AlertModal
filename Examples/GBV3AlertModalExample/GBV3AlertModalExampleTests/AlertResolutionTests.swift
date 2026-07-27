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

    func test_dismissOnOverlayTap_mirrors_flag() {
        XCTAssertTrue(ResolvedAlert(cfg(closeOnTapOverlay: true)).dismissOnOverlayTap)
        XCTAssertFalse(ResolvedAlert(cfg(closeOnTapOverlay: false)).dismissOnOverlayTap)
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
}
