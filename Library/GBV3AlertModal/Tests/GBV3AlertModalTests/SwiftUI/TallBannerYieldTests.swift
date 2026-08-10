import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **Closes the one gap `ModalBannerGeometryRuleTests.test_tallUncappedArtwork_
/// producesAnUnyieldingSlot_whereUIKitWouldYield` names but does not answer.**
///
/// That test proves `ModalTokens.bannerGeometry` returns a raw, unbounded 2000pt slot height for a
/// 200x2000 artwork with no cap — UIKit, measured, yields to 525pt (`BannerGeometryTruthTests
/// .test_tallUncappedArtwork_UIKitYieldsTheResidual_whereTheRuleDoesNot`) so the title/subtitle
/// survive. The rule test's own doc argues the overshoot never reaches the screen because
/// `BannerSlot` applies the height as `.frame(maxHeight:)` over a greedy `Color.clear`, which
/// resolves to `min(2000, whateverIsLeft)` — but that argument was never checked by hosting the
/// actual view and measuring, unlike UIKit's `BannerAspectStressTests
/// .test_tallBanner_uncapped_titleAndSubtitleSurvive`, which this test mirrors.
///
/// Same fixture UIKit's regression test uses: `GeniePresets.base()`'s title/subtitle/primary, a
/// 200x2000 artwork, `bannerRatio: nil`, no `bannerMaxHeight`. If `SwiftUIAlertModal` behaves like
/// UIKit's comment claims, this passes. If the greedy-`Color.clear` argument is wrong, this is where
/// that would show up — not as a green pure-function test, but as a squeezed title.
///
/// **Measured (390x844 portrait / 844x390 landscape), for the record:**
///
/// | | UIKit (measured, `BannerGeometryTruthTests`) | SwiftUI (measured, here) |
/// |---|---|---|
/// | portrait banner height | yields to 525pt | 618pt |
/// | portrait card height | bounded by content | 778pt of an 844pt host — the card itself grows |
/// | landscape banner height | (not measured by that suite) | 134pt |
/// | landscape card height | | 294pt of a 390pt host |
/// | title / subtitle / primary | survive, non-zero | survive, non-zero (28.7pt / 19.1pt / 48pt) |
///
/// **The claim this file exists to check holds — title/subtitle never get squeezed toward zero,
/// on either orientation.** But it holds by a DIFFERENT mechanism than UIKit's, not the same one:
/// UIKit's Auto Layout priority tiers make the *banner* yield to a modest, host-dependent residual.
/// SwiftUI's greedy-`Color.clear` slot instead lets the *card* grow to consume nearly the whole
/// portrait host (778 of 844pt) and hands the banner most of that growth — title/subtitle survive
/// because there was room to grow into, not because anything compressed the banner's demand. This
/// is a real, measured divergence in HOW the two backends handle this regime, not only in the
/// numbers — worth reading alongside the module's own framing that a divergence is "a question, not
/// automatically a bug" (`2026-08-05-backend-independence.md` §2). No shipping asset is in this
/// regime (`ModalBannerGeometryRuleTests`'s note), so it is not urgent, but it is now KNOWN rather
/// than architecturally assumed.
// @MainActor: hosts a `UIHostingController` in a real `UIWindow`.
@MainActor
final class TallBannerYieldTests: XCTestCase {

    /// `gb_test_banner_tall`: 200x2000, the exact aspect `ModalBannerGeometryRuleTests` and
    /// `BannerGeometryTruthTests` both name by number. `TestBundleAssetTests`-style premise below
    /// gates that it actually resolves, so a broken asset fails loudly rather than reporting two
    /// banner-less cards as agreement.
    private func shape(name: String) -> DifferentialGeometry.Shape {
        DifferentialGeometry.Shape(
            name: name,
            dialog: AlertDialog(
                image: ModalImage("gb_test_banner_tall", bundleIdentifier: Bundle.module.bundleIdentifier),
                title: "Title",
                subtitle: "This is the subtitle text for the alert modal.",
                primary: "Okay",
                closeOnTapOverlay: true
            ),
            properties: GeniePresets.standardPropertiesNilBannerRatio()
        )
    }

    func test_premise_theTallAssetResolvesAtTheExtremeAspect() throws {
        let image = ModalImage("gb_test_banner_tall", bundleIdentifier: Bundle.module.bundleIdentifier)
        let size = image.pointSize
        XCTAssertEqual(
            size, CGSize(width: 200, height: 2000),
            "'gb_test_banner_tall' did not resolve at 200x2000 — every assertion below would be "
                + "measuring the wrong regime, or nothing at all"
        )
    }

    /// Mirrors `BannerAspectStressTests.test_tallBanner_uncapped_titleAndSubtitleSurvive` exactly:
    /// same fixture, same portrait host, same claim — title and subtitle must keep non-zero height
    /// and stay inside the card, not get squeezed toward zero by an unbounded banner demand.
    func test_tallUncappedBanner_titleAndSubtitleSurvive_portrait() throws {
        let frames = DifferentialGeometry.swiftUIFrames(shape(name: "tall-uncapped"), size: DifferentialGeometry.host)
        try assertContentNotSqueezed(frames)
    }

    /// The tighter case UIKit's own suite reserves for the CAPPED shapes (a landscape host gives the
    /// content stack far less room) — run here too, uncapped, because it is where the formula's
    /// overshoot would be most likely to actually reach the screen if the `.frame(maxHeight:)`
    /// argument in `ModalTokens.bannerGeometry`'s doc were wrong.
    func test_tallUncappedBanner_titleAndSubtitleSurvive_landscape() throws {
        let frames = DifferentialGeometry.swiftUIFrames(
            shape(name: "tall-uncapped-landscape"), size: DifferentialGeometry.landscapeHost
        )
        try assertContentNotSqueezed(frames)
    }

    /// Proof of "no squeeze-off", the SwiftUI-hosted equivalent of `BannerAspectStressTests
    /// .assertContentNotSqueezed`: title and subtitle both have non-zero height and fall fully
    /// within the card's bounds (frames are already card-relative — `swiftUIFrames` normalises them).
    private func assertContentNotSqueezed(
        _ frames: [ModalGeometryElement: CGRect], file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let card = try XCTUnwrap(
            frames[.card], "no card frame was published — nothing was measured", file: file, line: line
        )

        func assertVisible(_ element: ModalGeometryElement, _ name: String) {
            guard let frame = frames[element] else {
                XCTFail("expected \(name) to be measured", file: file, line: line)
                return
            }
            XCTAssertGreaterThan(frame.height, 0, "\(name) must have non-zero height", file: file, line: line)
            XCTAssertGreaterThanOrEqual(
                frame.minY, card.minY - 0.5,
                "\(name) must not be pushed above the card's top", file: file, line: line
            )
            XCTAssertLessThanOrEqual(
                frame.maxY, card.maxY + 0.5,
                "\(name) must not be pushed below the card's bottom (clipped/squeezed off)",
                file: file, line: line
            )
        }

        assertVisible(.title, "title")
        assertVisible(.subtitle, "subtitle")
        assertVisible(.primaryButton, "primary button")
    }
}
