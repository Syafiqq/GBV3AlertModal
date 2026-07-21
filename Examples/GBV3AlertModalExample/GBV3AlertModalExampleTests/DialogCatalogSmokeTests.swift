//
//  DialogCatalogSmokeTests.swift
//  GBV3AlertModalExampleTests
//
//  Task 7 (final) of the Dialog Gallery: a smoke test that iterates every
//  `DialogCatalog.entries` factory, hosts the resulting `SampleAlertModal` in
//  a throwaway `UIWindow`, forces a layout pass, and asserts the modal
//  actually built its view graph (`vwContainer != nil`). This catches a
//  factory that crashes outright or silently produces an empty modal —
//  it does not assert on exact layout/visual output (see the library's own
//  snapshot tests in `Library/GBV3AlertModal/Tests` for that).
//

import UIKit
import XCTest
@testable import GBV3AlertModalExample

final class DialogCatalogSmokeTests: XCTestCase {
    /// Hosts `modal` in a fresh, key `UIWindow` sized like an iPhone screen,
    /// forces layout, and returns the window so the caller can tear it down.
    ///
    /// `GBAlertModal.show(parent:completion:)` pins the modal to its parent's
    /// edges via SnapKit, so a real, laid-out window is what drives the
    /// modal's own `layoutSubviews` (and therefore its internal view graph
    /// construction) deterministically.
    private func host(_ modal: SampleAlertModal) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        window.makeKeyAndVisible()

        modal.show(parent: window, completion: {})

        window.setNeedsLayout()
        window.layoutIfNeeded()

        return window
    }

    /// Detaches `window` from its scene/hierarchy so it (and everything it
    /// holds — the modal, its subviews, any keyboard observers) can
    /// deallocate. Left alone, every iteration would leak a live window for
    /// the rest of the test process.
    private func teardown(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
        window.subviews.forEach { $0.removeFromSuperview() }
        window.windowScene = nil
    }

    func testCatalogHasTwentySixEntries() {
        XCTAssertEqual(DialogCatalog.entries.count, 26, "Dialog catalog is expected to have exactly 26 distinct shapes")
    }

    /// Builds every catalog entry, hosts it, and asserts the resulting
    /// `GBAlertModal` actually constructed its container view. A factory
    /// that crashes fails the test outright; a factory that silently
    /// produces an empty modal fails the `vwContainer` assertion below.
    func testEveryCatalogEntryBuildsAContainer() {
        for entry in DialogCatalog.entries {
            let modal = entry.make()
            let window = host(modal)

            XCTAssertNotNil(
                modal.vwContainer,
                "\(entry.name) (\(entry.category)) did not build vwContainer"
            )

            teardown(window)
        }
    }
}
