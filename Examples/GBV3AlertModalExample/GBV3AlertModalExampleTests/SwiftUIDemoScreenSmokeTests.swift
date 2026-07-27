// SwiftUIDemoScreenSmokeTests.swift
import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModalExample

final class SwiftUIDemoScreenSmokeTests: XCTestCase {

    func test_demoScreen_builds() {
        let host = UIHostingController(rootView: SwiftUIDemoScreen())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty)
        XCTAssertFalse(host.view.subviews.isEmpty)
    }

    func test_gallery_exposes_swiftui_entry_point() {
        let gallery = GalleryViewController()
        gallery.loadViewIfNeeded()           // triggers viewDidLoad
        XCTAssertNotNil(
            gallery.navigationItem.rightBarButtonItem,
            "gallery should expose a nav-bar button to reach the SwiftUI demo"
        )
    }
}
