import UIKit
import XCTest
@testable import GBV3AlertModal

/// `ModalTokens.bannerLayout` — the PRECEDENCE between the three banner fields, which
/// `ModalBannerGeometry` then applies. It is not a free choice: it mirrors the UIKit constraint
/// priorities in `GBAlertModal+ViewGraph.swift`'s `installConstraints` (cap 751 > natural-aspect
/// driver 700 > fixed height 251), so these tests are the record of that mirroring.
@MainActor
final class ModalBannerLayoutTests: XCTestCase {

    private func layout(
        ratio: CGFloat? = nil, maxHeight: CGFloat? = nil, fixedHeight: CGFloat? = nil
    ) -> ModalTokens.BannerLayout {
        ModalTokens(
            from: GBAlertModal.Properties(
                bannerRatio: ratio, bannerMaxHeight: maxHeight, bannerFixedHeight: fixedHeight
            )
        ).bannerLayout
    }

    /// `bannerRatio != nil` removes the natural-aspect driver in UIKit, so the fixed height (251) is
    /// what sizes the slot — and the ratio shapes it.
    func test_ratioPath_pinsTheFixedHeightAndShapesTheSlot() {
        XCTAssertEqual(
            layout(ratio: 320.0 / 229.0, maxHeight: 216, fixedHeight: 184),
            ModalTokens.BannerLayout(aspectRatio: 320.0 / 229.0, height: 184, maxHeight: 216)
        )
    }

    /// `bannerRatio == nil` installs the natural-aspect driver at 700, which OUT-RANKS the fixed
    /// height at 251 — so UIKit ignores `bannerFixedHeight` there, and so must SwiftUI. Applying it
    /// anyway would be a divergence in the opposite direction.
    func test_naturalAspectPath_ignoresTheFixedHeight_asUIKitDoes() {
        XCTAssertEqual(
            layout(maxHeight: 144, fixedHeight: 999),
            ModalTokens.BannerLayout(aspectRatio: nil, height: nil, maxHeight: 144)
        )
    }

    /// The cap is the highest-priority constraint on either path, and the only one applied when
    /// nothing else is set.
    func test_capIsCarriedOnBothPaths() {
        XCTAssertEqual(layout(maxHeight: 160).maxHeight, 160)
        XCTAssertEqual(layout(ratio: 1, maxHeight: 160).maxHeight, 160)
    }

    /// A `Properties` with no banner geometry at all must produce NO geometry — three nils, not
    /// `standard`'s 160pt cap. `GeniePresets.standardProperties()` (the real `V3AlertModal` preset)
    /// is that case for the cap specifically.
    func test_noGeometryInProperties_producesNoGeometry() {
        XCTAssertEqual(
            layout(), ModalTokens.BannerLayout(aspectRatio: nil, height: nil, maxHeight: nil)
        )
        XCTAssertNil(ModalTokens(from: GeniePresets.standardProperties()).bannerLayout.maxHeight)
    }

    /// End-to-end over a REAL preset: the streak popup's 200:168 / 168 / 168 geometry reaches the
    /// SwiftUI layout intact.
    func test_realStreakPreset_reachesTheLayout() {
        XCTAssertEqual(
            ModalTokens(from: GeniePresets.streakProperties()).bannerLayout,
            ModalTokens.BannerLayout(aspectRatio: 200.0 / 168.0, height: 168, maxHeight: 168)
        )
    }
}
