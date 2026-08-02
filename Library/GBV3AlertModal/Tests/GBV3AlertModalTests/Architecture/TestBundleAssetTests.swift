import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **The premise behind the banner differential row.**
///
/// Both renderers resolve artwork from the MAIN bundle by default, and this test target has none —
/// which is exactly why `bannerIsUnresolvableInTheLibraryBundle` excluded every banner from the gate.
/// `ModalImage.bundleIdentifier` is the seam that fixes it, and this proves the seam actually works
/// before anything is gated through it. A banner row over an asset that silently fails to resolve
/// would report "absent on both" and PASS, which is the vacuous agreement this suite exists to
/// prevent.
final class TestBundleAssetTests: XCTestCase {

    /// The identifier of the SPM resource bundle this target owns.
    static var testBundleIdentifier: String? { Bundle.module.bundleIdentifier }

    func test_theTestBundleHasAnIdentifier() throws {
        let identifier = try XCTUnwrap(
            Self.testBundleIdentifier,
            "the test resource bundle has no identifier, so ModalImage cannot name it"
        )
        XCTAssertFalse(identifier.isEmpty)
    }

    func test_theBannerAssetResolves_throughModalImage() throws {
        let image = ModalImage("gb_test_banner", bundleIdentifier: Self.testBundleIdentifier)

        let bundle = try XCTUnwrap(image.bundle, "ModalImage could not resolve the named bundle")
        let uiImage = try XCTUnwrap(
            UIImage(named: image.assetName, in: bundle, compatibleWith: nil),
            "the asset did not load from the test bundle — a banner row over it would compare nothing"
        )
        // 16:9, so the natural-aspect path has a real ratio to honour rather than a square.
        XCTAssertEqual(uiImage.size.width / uiImage.size.height, 16.0 / 9.0, accuracy: 0.01)
    }

    /// An unresolvable identifier degrades to the main bundle rather than to no image, so a typo in
    /// a caller's identifier does not silently blank the banner.
    func test_anUnknownBundleIdentifier_degradesToTheMainBundle() {
        let image = ModalImage("gb_test_banner", bundleIdentifier: "com.example.does.not.exist")
        XCTAssertNil(image.bundle, "an unknown identifier must resolve to nil, i.e. the main bundle")
    }

    /// **`ModalImage.pointSize` directly, not just transitively through the differential shape.**
    ///
    /// `gb_test_banner.imageset` only ships a "1x" file (`Contents.json` has no filename for the 2x
    /// or 3x slots), so it resolves at 1x on every simulator regardless of the run's display scale —
    /// which means POINTS and PIXELS are the same 160x90 here. That is exactly what makes this a weak
    /// points-vs-pixels check: it cannot fail in a way that would distinguish "reports points" from
    /// "reports pixels". It still proves `pointSize` reads a real, non-zero size off the resolved
    /// asset through the bundle-scoped `ModalImage` path — see `BannerGeometryTruthTests`' doc for
    /// why the points/pixels distinction matters for a REAL (multi-scale) asset.
    func test_pointSize_reportsTheTestBannersSize() {
        let image = ModalImage("gb_test_banner", bundleIdentifier: Self.testBundleIdentifier)
        XCTAssertEqual(image.pointSize, CGSize(width: 160, height: 90))
    }

    /// The other half of `pointSize`'s doc contract: a name that does not resolve collapses to
    /// `.zero`, mirroring `UIImage(named:)` returning `nil` rather than crashing or fabricating a
    /// size. This is what lets `ModalTokens.bannerGeometry` collapse the slot instead of measuring a
    /// missing asset as if it had geometry.
    func test_pointSize_isZero_whenTheAssetDoesNotResolve() {
        let image = ModalImage("gb_this_asset_does_not_exist", bundleIdentifier: Self.testBundleIdentifier)
        XCTAssertEqual(image.pointSize, .zero)
    }
}
