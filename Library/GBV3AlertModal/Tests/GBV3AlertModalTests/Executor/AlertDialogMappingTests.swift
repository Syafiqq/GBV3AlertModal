import XCTest
import UIKit
@testable import GBV3AlertModal

/// The executor does not change rendering — it only builds a `DataHolder`. This asserts the
/// AlertDialog→DataHolder mapping produces the SAME render decisions the Layer-A resolver
/// already guards, using `GBAlertModal.resolve(...)` as the oracle. No new snapshots.
final class AlertDialogMappingTests: XCTestCase {
    func test_alertDialog_mapsToExpectedResolvedModal() {
        let descriptor = AlertDialog(
            title: "Title", subtitle: "Body", primary: "OK", secondary: "Cancel"
        )
        let holder = UIKitModalRenderer.AlertHolder.make(for: descriptor) { _ in }
        let resolved = GBAlertModal.resolve(
            properties: GeniePresets.standardProperties(), holder: holder, isLandscape: false
        )

        XCTAssertTrue(resolved.showsTitle)
        XCTAssertEqual(resolved.subtitle, .plain("Body"))
        XCTAssertTrue(resolved.showsPrimary)
        XCTAssertTrue(resolved.showsSecondary)
        XCTAssertFalse(resolved.showsBanner)
        // Gate owns teardown → the built-in AlertDialog holder bakes dismissOnAction=false.
        XCTAssertFalse(resolved.dismissOnAction)
    }

    func test_alertDialogResult_dismissedResultIsDismissed() {
        XCTAssertEqual(AlertDialog.dismissedResult, .dismissed)
    }
}
