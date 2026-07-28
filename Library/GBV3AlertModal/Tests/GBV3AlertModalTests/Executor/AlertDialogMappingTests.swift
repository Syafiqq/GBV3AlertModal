import XCTest
import UIKit
@testable import GBV3AlertModal

/// The executor does not change rendering — it only builds a `DataHolder`. This asserts the
/// AlertDialog→DataHolder mapping produces the SAME render decisions the Layer-A resolver
/// already guards, using `GBAlertModal.resolve(...)` as the oracle. No new snapshots.
@MainActor final class AlertDialogMappingTests: XCTestCase {
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

    func test_stringInit_liftsToAttributedString() {
        let d = AlertDialog(title: "Hi", subtitle: "There", primary: "OK")
        XCTAssertEqual(d.title.map { String($0.characters) }, "Hi")
        XCTAssertEqual(d.subtitle.map { String($0.characters) }, "There")
    }

    func test_bothInits_equivalentForPlainText() {
        let s = AlertDialog(title: "Hi", subtitle: "There", primary: "OK")
        let a = AlertDialog(title: AttributedString("Hi"), subtitle: AttributedString("There"), primary: "OK")
        XCTAssertEqual(s.title, a.title)
        XCTAssertEqual(s.subtitle, a.subtitle)
    }

    func test_bareInit_isUnambiguous_resolvesToStringPath() {
        // Compiles only because the AttributedString init does not default title/subtitle.
        let d = AlertDialog(primary: "OK")
        XCTAssertNil(d.title)
        XCTAssertNil(d.subtitle)
    }
}
