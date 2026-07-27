// SwiftUIAlertModalSmokeTests.swift
import SwiftUI
import UIKit
import XCTest
import GBV3AlertModal
@testable import GBV3AlertModalExample

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

    private func assertBuilds(_ config: AlertDialog, _ message: String) {
        let (window, host) = host(SwiftUIAlertModal(config: config) { _ in })
        defer { teardown(window) }
        XCTAssertFalse(host.view.bounds.isEmpty, "\(message): host view was not laid out")
        XCTAssertFalse(host.view.subviews.isEmpty, "\(message): view graph is empty")
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
}
