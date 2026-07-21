import XCTest
import UIKit
@testable import GBV3AlertModal

/// Task 11 (Tier 2): `GBAlertModal.DataHolder.subtitleCustomView` must survive without the
/// caller holding an external strong reference to it.
///
/// Root cause: `subtitleCustomView` was declared `weak`, so the ONLY strong reference to a
/// caller-constructed custom view was the local parameter inside `DataHolder.init` itself.
/// Once that initializer returns, that local goes out of scope — and if the caller built the
/// view inline (no separately-retained local of their own), nothing keeps it alive anymore.
/// This reproduces that exact "no reference survives the constructing scope" shape via a
/// private helper, matching how a real call site — e.g. `GBAlertModal(holder: someFactory())`
/// — composes across a function boundary. It does NOT rely on `GBAlertModal`'s own `init`
/// merely "capturing early": by the time `GBAlertModal.init(holder:)` runs, the holder it
/// receives has already crossed that scope boundary, so a fix that only grabs a strong
/// reference inside `GBAlertModal.init` would be too late — the weak field would already be
/// nil. The only fix that actually closes this window is making `DataHolder` itself hold the
/// view strongly.
final class SubtitleCustomViewLifetimeTests: XCTestCase {
    /// Builds a holder whose `subtitleCustomView` has exactly one strong reference — the local
    /// inside this function — before returning. No caller-visible variable retains the view.
    private func makeHolderWithInlineCustomView() -> GBAlertModal.DataHolder {
        let customView = UIView()
        customView.accessibilityIdentifier = "inline-subtitle-custom-view"
        return GBAlertModal.DataHolder(
            closeOnTapOverlay: true,
            title: "Title",
            subtitleCustomView: customView,
            primaryAction: "Okay",
            dismissOnAction: true
        )
    }

    func test_subtitleCustomView_survivesWithoutExternalStrongReference() {
        // The test itself never holds a strong reference to the view constructed inside
        // `makeHolderWithInlineCustomView()` — only `holder.subtitleCustomView` (and, after
        // the fix, the modal) does.
        let holder = makeHolderWithInlineCustomView()
        let modal = GBAlertModal(holder: holder)
        _ = renderForSnapshot(modal, size: CGSize(width: 390, height: 844))

        XCTAssertNotNil(
            modal.vwSubtitle,
            "the modal must retain its subtitleCustomView through installation so it survives " +
            "past the scope that constructed it — callers should not need to hold an external " +
            "strong reference just to keep the custom view alive"
        )
        XCTAssertEqual(
            modal.vwSubtitle?.accessibilityIdentifier, "inline-subtitle-custom-view",
            "the surviving view must be the exact custom view the caller supplied"
        )
        XCTAssertNotNil(
            modal.vwSubtitle?.superview,
            "the surviving custom view must actually be installed into the rendered hierarchy"
        )
    }
}
