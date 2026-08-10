import UIKit
import XCTest
@testable import GBV3AlertModal

/// `ModalTokens.bannerLayout` — the PRECEDENCE between the three banner fields. It is not a free
/// choice: it mirrors the UIKit constraint priorities in `GBAlertModal+ViewGraph.swift`'s
/// `installConstraints` (cap 950 > natural-aspect driver 245 > fixed height 243), so these tests are
/// the record of that mirroring.
///
/// `BannerLayout` no longer HAS a `height` field — the assertions below are what pins that.
/// `bannerFixedHeight` was carried there and applied on the ratio path; that was wrong, because it
/// sits below the card's `.low` (250) hugging as well as below the image's compression resistance
/// (750), so UIKit ignores it on BOTH paths (measured zero effect at every size tried,
/// `BannerGeometryTruthTests.test_bannerFixedHeight_isInert_onTheRatioPath` and
/// `..._onTheNaturalAspectPath`). Applying it was a live divergence on every real preset that sets
/// both `bannerRatio` and `bannerFixedHeight`, which is all of them. It was first neutralised by
/// hardcoding `height: nil`, then deleted outright; these tests moved from "`height` is `nil`" to
/// "a `fixedHeight` in `Properties` reaches NOTHING in `BannerLayout`", which is the claim that
/// actually matters and the one that survives the field's removal.
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

    /// `bannerRatio != nil` removes the natural-aspect driver in UIKit, but the fixed height is STILL
    /// inert there — it sits below the card's `.low` (250) hugging, which wins the tie before the
    /// fixed height ever gets a say. See `BannerGeometryTruthTests.test_bannerFixedHeight_isInert_
    /// onTheRatioPath`. The ratio still shapes the slot; the fixed height contributes nothing.
    ///
    /// The `184` passed in is the load-bearing part: `BannerLayout` is `Equatable` over ALL its
    /// fields, so an exact match against `(aspectRatio: 320/229, maxHeight: 216)` says the fixed
    /// height reached nothing at all — not that it landed in a field asserted to be `nil`.
    func test_ratioPath_ignoresTheFixedHeight_asUIKitDoes() {
        XCTAssertEqual(
            layout(ratio: 320.0 / 229.0, maxHeight: 216, fixedHeight: 184),
            ModalTokens.BannerLayout(aspectRatio: 320.0 / 229.0, maxHeight: 216)
        )
    }

    /// `bannerRatio == nil` installs the natural-aspect driver at 245, which OUT-RANKS the fixed
    /// height at 243 — so UIKit ignores `bannerFixedHeight` there, and so must SwiftUI. Applying it
    /// anyway would be a divergence in the opposite direction. See
    /// `BannerGeometryTruthTests.test_bannerFixedHeight_isInert_onTheNaturalAspectPath`.
    func test_naturalAspectPath_ignoresTheFixedHeight_asUIKitDoes() {
        // 999 is deliberately absurd: if any field of the result carried it, this equality fails.
        XCTAssertEqual(
            layout(maxHeight: 144, fixedHeight: 999),
            ModalTokens.BannerLayout(aspectRatio: nil, maxHeight: 144)
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
            layout(), ModalTokens.BannerLayout(aspectRatio: nil, maxHeight: nil)
        )
        XCTAssertNil(ModalTokens(from: GeniePresets.standardProperties()).bannerLayout.maxHeight)
    }

    /// End-to-end over a REAL preset: the streak popup's 200:168 ratio and 168 cap reach the SwiftUI
    /// layout intact — its `bannerFixedHeight` (also 168) does not, because it is inert on the ratio
    /// path (see `test_ratioPath_ignoresTheFixedHeight_asUIKitDoes` above).
    func test_realStreakPreset_reachesTheLayout() {
        XCTAssertEqual(
            ModalTokens(from: GeniePresets.streakProperties()).bannerLayout,
            ModalTokens.BannerLayout(aspectRatio: 200.0 / 168.0, maxHeight: 168)
        )
    }
}
