// SwiftUIDemoScreenSmokeTests.swift
import SwiftUI
import UIKit
import XCTest
import GBV3AlertModal
@testable import GBV3AlertModalExample

@MainActor
final class SwiftUIDemoScreenSmokeTests: XCTestCase {

    private func layoutPass(_ window: UIWindow) {
        window.setNeedsLayout()
        window.layoutIfNeeded()
    }

    /// Pure-SwiftUI content (e.g. `Text`) renders straight to `CALayer` sublayers on this SDK
    /// without necessarily creating a child `UIView` — only UIKit-interop content (e.g. a
    /// `ProgressView`'s backing `UIActivityIndicatorView`) shows up in `.subviews`. Checking
    /// either confirms the hosting controller actually built non-trivial content.
    private func hasBuiltViewGraph(_ view: UIView) -> Bool {
        !view.subviews.isEmpty || !(view.layer.sublayers ?? []).isEmpty
    }

    func test_demoScreen_builds() {
        let host = UIHostingController(rootView: SwiftUIDemoScreen())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        layoutPass(window)
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty)
        XCTAssertTrue(hasBuiltViewGraph(host.view))
    }

    func test_gallery_exposes_swiftui_entry_point() {
        let gallery = GalleryViewController()
        gallery.loadViewIfNeeded()           // triggers viewDidLoad
        XCTAssertNotNil(
            gallery.navigationItem.rightBarButtonItem,
            "gallery should expose a nav-bar button to reach the SwiftUI demo"
        )
    }

    func test_gallery_exposes_tier0_entry_point() {
        let gallery = GalleryViewController()
        gallery.loadViewIfNeeded()
        XCTAssertEqual(gallery.navigationItem.rightBarButtonItems?.count, 2,
                       "gallery should expose both the SwiftUI and Tier 0 entry points")
    }

    /// Tier 0: the SwiftUI screen builds with a real executor injected (no SwiftUI modal of its own).
    func test_tier0_demo_screen_builds() {
        let executor = DefaultModalExecutor(renderer: UIKitModalRenderer(alertProperties: GBAlertModal.Properties()))
        let host = UIHostingController(rootView: Tier0DemoScreen(executor: executor))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        layoutPass(window)
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty)
        XCTAssertTrue(hasBuiltViewGraph(host.view))
    }

    // MARK: new stateful demo cases

    /// The "loading button" (Gc2Gs) case: the demo screen's fixture, hosted through
    /// `SwiftUIAlertModal` with `isPrimaryLoading: true`, mirrors the mid-flight render.
    func test_loading_demo_fixture_builds_with_spinner_state() {
        let host = UIHostingController(
            rootView: SwiftUIAlertModal(config: SwiftUIDemoScreen.demoLoading, isPrimaryLoading: true) { _ in }
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        layoutPass(window)
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty)
        XCTAssertTrue(hasBuiltViewGraph(host.view))
    }

    /// The validation-gate (Satisfaction) case: a bespoke view, not a config render.
    func test_satisfaction_demo_view_builds() {
        let host = UIHostingController(rootView: SatisfactionDemoView { _ in })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        layoutPass(window)
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty)
        XCTAssertTrue(hasBuiltViewGraph(host.view))
    }
}
