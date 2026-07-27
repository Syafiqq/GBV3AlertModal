// SwiftUIAlertModalSmokeTests.swift
import SwiftUI
import UIKit
import XCTest
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
}
