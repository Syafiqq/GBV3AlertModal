import XCTest
import UIKit
@testable import GBV3AlertModal

/// Layer A: unit tests for the pure `GBAlertModal.resolve(...)` resolver.
///
/// Task 3 seeds this suite with the banner-visibility decisions; Task 4 exhausts the rest.
final class LayerA_ResolverTests: XCTestCase {
    func test_resolve_bannerVisibleWhenImagePresent() {
        let holder = GBAlertModal.DataHolder(banner: UIImage())
        let r = GBAlertModal.resolve(properties: nil, holder: holder, isLandscape: false, isPad: false)
        XCTAssertTrue(r.showsBanner)
    }

    func test_resolve_noBannerWhenNil() {
        let r = GBAlertModal.resolve(properties: nil, holder: .default, isLandscape: false, isPad: false)
        XCTAssertFalse(r.showsBanner)
    }
}
