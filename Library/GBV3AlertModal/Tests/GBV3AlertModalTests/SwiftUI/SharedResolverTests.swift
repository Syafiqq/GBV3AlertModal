import XCTest
@testable import GBV3AlertModal

/// C-1: the SwiftUI path consumes the SAME resolver as UIKit, so structural equivalence is a
/// property of the code, not of a comparison harness. These tests pin the shared chain.
@MainActor
final class SharedResolverTests: XCTestCase {

    /// `primaryActionStyle`/`secondaryActionStyle` must be non-nil for `resolve` to report
    /// `showsPrimary`/`showsSecondary` true — the resolver requires BOTH the action string AND a
    /// non-nil UIKit `ActionStyle` (see `GBAlertModal+ResolvedModal.swift`, mirrored by
    /// `LayerA_ResolverTests.test_resolve_primary_hiddenWhenStyleMissing`). A bare
    /// `GBAlertModal.Properties()` therefore makes `showsPrimary`/`showsSecondary` FALSE even when
    /// the dialog has both actions — deliberately deviating here from the plan's literal snippet
    /// (which used `GBAlertModal.Properties()`) to keep this pinning test actually true. The
    /// style's payload is irrelevant to this test; only its presence is.
    private func resolved(for dialog: AlertDialog) -> GBAlertModal.ResolvedModal {
        let holder = UIKitModalRenderer.AlertHolder.make(for: dialog, resolve: { _ in })
        return GBAlertModal.resolve(
            properties: GBAlertModal.Properties(
                primaryActionStyle: .plain(.init()),
                secondaryActionStyle: .plain(.init())
            ),
            holder: holder,
            isLandscape: false
        )
    }

    func testTwoButtonDialogResolvesBothActions() {
        let dialog = AlertDialog(title: "T", subtitle: "S", primary: "OK", secondary: "Cancel")
        let r = resolved(for: dialog)
        XCTAssertTrue(r.showsTitle)
        XCTAssertTrue(r.showsPrimary)
        XCTAssertTrue(r.showsSecondary)
        XCTAssertEqual(r.subtitle, .plain("S"))
    }

    func testOneButtonDialogHasNoSecondary() {
        let dialog = AlertDialog(title: "T", subtitle: "S", primary: "OK")
        XCTAssertFalse(resolved(for: dialog).showsSecondary)
    }

    func testCloseButtonFlagRoundTrips() {
        let dialog = AlertDialog(title: "T", subtitle: "S", primary: "OK", showCloseButton: true)
        XCTAssertTrue(resolved(for: dialog).showsCloseButton)
    }
}
