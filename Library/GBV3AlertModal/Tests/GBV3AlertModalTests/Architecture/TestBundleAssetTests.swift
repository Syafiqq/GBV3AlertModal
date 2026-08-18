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

}
