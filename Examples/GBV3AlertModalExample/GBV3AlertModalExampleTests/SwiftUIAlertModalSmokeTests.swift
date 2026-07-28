// SwiftUIAlertModalSmokeTests.swift
import SwiftUI
import UIKit
import XCTest
import ViewInspector
import GBV3AlertModal
@testable import GBV3AlertModalExample

// @MainActor: hosts SwiftUI/UIKit views in a UIWindow, which is main-actor under Swift 6.
@MainActor
final class SwiftUIAlertModalSmokeTests: XCTestCase {

    /// Hosts a SwiftUI view in a throwaway key window and forces a layout pass,
    /// mirroring DialogCatalogSmokeTests. Returns the host so the caller asserts + tears down.
    private func host<V: View>(_ view: V) -> (UIWindow, UIHostingController<V>) {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        return (window, host)
    }

    private func teardown(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    /// Pure-SwiftUI content (e.g. `Text`) renders straight to `CALayer` sublayers on this SDK
    /// without necessarily creating a child `UIView` — only UIKit-interop content (e.g. a
    /// `ProgressView`'s backing `UIActivityIndicatorView`) shows up in `.subviews`. Checking
    /// either confirms the hosting controller actually built non-trivial content.
    private func hasBuiltViewGraph(_ view: UIView) -> Bool {
        !view.subviews.isEmpty || !(view.layer.sublayers ?? []).isEmpty
    }

    private func assertBuilds(_ config: AlertDialog, _ message: String) {
        let (window, host) = host(SwiftUIAlertModal(config: config) { _ in })
        defer { teardown(window) }
        XCTAssertFalse(host.view.bounds.isEmpty, "\(message): host view was not laid out")
        XCTAssertTrue(hasBuiltViewGraph(host.view), "\(message): view graph is empty")
    }

    func test_minimal_config_builds() {
        assertBuilds(
            AlertDialog(title: "Title", subtitle: "Subtitle", primary: "OK"),
            "minimal"
        )
    }

    func test_full_config_builds() {
        assertBuilds(
            AlertDialog(
                image: ModalImage("img_illust_onboarding"),
                title: "Help us improve",
                subtitle: "Take our quick survey and gain bubbles!",
                primary: "Proceed",
                secondary: "Not now",
                closeOnTapOverlay: true,
                showCloseButton: true
            ),
            "full"
        )
    }

    // MARK: presentation-state params (primaryEnabled / isPrimaryLoading)

    func test_primary_loading_state_builds() {
        let (window, host) = host(
            SwiftUIAlertModal(
                config: AlertDialog(title: "Generate your worksheet", subtitle: "This will use one credit.", primary: "Generate", secondary: "Cancel"),
                isPrimaryLoading: true
            ) { _ in }
        )
        defer { teardown(window) }
        XCTAssertFalse(host.view.bounds.isEmpty, "loading: host view was not laid out")
        XCTAssertTrue(hasBuiltViewGraph(host.view), "loading: view graph is empty")
    }

    func test_primary_disabled_state_builds() {
        let (window, host) = host(
            SwiftUIAlertModal(
                config: AlertDialog(title: "Title", subtitle: "Subtitle", primary: "OK"),
                primaryEnabled: false
            ) { _ in }
        )
        defer { teardown(window) }
        XCTAssertFalse(host.view.bounds.isEmpty, "disabled: host view was not laid out")
        XCTAssertTrue(hasBuiltViewGraph(host.view), "disabled: view graph is empty")
    }

    // MARK: Layer-B wiring — hosting-observable (no ViewInspector)

    /// The `isPrimaryLoading` branch must render a real spinner, not just the label. A hosted
    /// SwiftUI `ProgressView` is backed by a `UIActivityIndicatorView`, so its presence/absence
    /// is an observable per-field wiring assert without ViewInspector.
    func test_loading_state_renders_activity_indicator() {
        let cfg = AlertDialog(title: "Generate", subtitle: "Uses one credit.", primary: "Generate")
        let (loadingWindow, loadingHost) = host(SwiftUIAlertModal(config: cfg, isPrimaryLoading: true) { _ in })
        defer { teardown(loadingWindow) }
        XCTAssertNotNil(firstDescendant(UIActivityIndicatorView.self, in: loadingHost.view),
                        "loading primary should render a spinner")

        let (idleWindow, idleHost) = host(SwiftUIAlertModal(config: cfg, isPrimaryLoading: false) { _ in })
        defer { teardown(idleWindow) }
        XCTAssertNil(firstDescendant(UIActivityIndicatorView.self, in: idleHost.view),
                     "non-loading primary should show no spinner")
    }

    private func firstDescendant<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        for sub in view.subviews {
            if let hit = sub as? T { return hit }
            if let deep = firstDescendant(type, in: sub) { return deep }
        }
        return nil
    }

    // MARK: Task-4 design tokens & styles (pure — no hosting)

    /// Tokens are transcribed from the real `Presentation.UiKit.V3AlertModal` preset (spec D8).
    /// Pin them so an accidental edit that drifts from the app design is a failing test, not a silent regression.
    func test_modalTokens_match_real_V3AlertModal_preset() {
        XCTAssertEqual(ModalTokens.cornerRadius, 16)
        XCTAssertEqual(ModalTokens.gapBelowBanner, 16)
        XCTAssertEqual(ModalTokens.gapBelowTitle, 16)
        XCTAssertEqual(ModalTokens.gapBelowSubtitle, 24)
        XCTAssertEqual(ModalTokens.interButton, 8)
        XCTAssertEqual(ModalTokens.scrimOpacity, 0.6, accuracy: 0.001)
        XCTAssertEqual(ModalTokens.bannerAspectRatio, 1)
        XCTAssertTrue(ModalTokens.cardWidth == 256 || ModalTokens.cardWidth == 300,
                      "card width must be the phone (256) or pad (300) preset value")
    }

    func test_hex_color_decodes_rgb_channels() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color(hex: 0x038CD5)).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0x03 / 255, accuracy: 0.01)
        XCTAssertEqual(g, 0x8C / 255, accuracy: 0.01)
        XCTAssertEqual(b, 0xD5 / 255, accuracy: 0.01)
    }

    /// The signature primary shape must actually cut the bottom-left corner while keeping the body.
    func test_obliqueShape_cuts_bottom_left_corner_keeps_body() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 48)
        let path = ObliqueBottomLeftShape().path(in: rect)
        XCTAssertTrue(path.contains(CGPoint(x: 100, y: 24)), "body center should be filled")
        XCTAssertFalse(path.contains(CGPoint(x: 2, y: 46)), "bottom-left corner should be cut away")
        XCTAssertTrue(path.boundingRect.width <= rect.width + 0.5
                      && path.boundingRect.height <= rect.height + 0.5,
                      "shape must stay within its rect")
    }

    // MARK: Layer-B wiring — view introspection (ViewInspector)

    private func modal(_ config: AlertDialog) -> SwiftUIAlertModal {
        SwiftUIAlertModal(config: config) { _ in }
    }

    /// Each content field actually reaches a rendered `Text` (title/subtitle/primary/secondary label).
    func test_layerB_content_text_reaches_the_view() throws {
        let sut = modal(AlertDialog(title: "Title", subtitle: "Body", primary: "OK", secondary: "Cancel"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Title"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Body"))
        XCTAssertNoThrow(try sut.inspect().find(text: "OK"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Cancel"))
    }

    /// Button count reflects secondary + close wiring: minimal=1 (primary), +secondary=2, +close=3.
    func test_layerB_button_count_reflects_secondary_and_close() throws {
        XCTAssertEqual(try modal(AlertDialog(title: "T", primary: "OK"))
            .inspect().findAll(ViewType.Button.self).count, 1)
        XCTAssertEqual(try modal(AlertDialog(title: "T", primary: "OK", secondary: "Cancel"))
            .inspect().findAll(ViewType.Button.self).count, 2)
        XCTAssertEqual(try modal(AlertDialog(title: "T", primary: "OK", secondary: "Cancel", showCloseButton: true))
            .inspect().findAll(ViewType.Button.self).count, 3)
    }

    /// The banner `Image` renders only when an image is set (no banner, no close → no `Image` at all).
    func test_layerB_banner_image_present_only_when_image_set() throws {
        XCTAssertNoThrow(try modal(AlertDialog(image: ModalImage("img_illust_onboarding"), title: "T", primary: "OK"))
            .inspect().find(ViewType.Image.self))
        XCTAssertThrowsError(try modal(AlertDialog(title: "T", primary: "OK"))
            .inspect().find(ViewType.Image.self))
    }

    /// The close glyph (an SF Symbol `Image`) appears iff `showCloseButton`.
    func test_layerB_close_glyph_present_iff_flag() throws {
        XCTAssertNoThrow(try modal(AlertDialog(title: "T", primary: "OK", showCloseButton: true))
            .inspect().find(ViewType.Image.self))
        XCTAssertThrowsError(try modal(AlertDialog(title: "T", primary: "OK", showCloseButton: false))
            .inspect().find(ViewType.Image.self))
    }
}
