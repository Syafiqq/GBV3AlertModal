import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **The two on-record banner-width divergences, pinned as cross-backend measurements — so closing
/// OR widening either one shows up here, by name, instead of by rumour.**
///
/// `docs/superpowers/notes/2026-08-08-uikit-swiftui-differences.md` names both as genuinely open:
///
/// - **D-B** — a `bannerRatio` that disagrees with its artwork's own aspect. Already pinned at the
///   isolated `ModalTokens.bannerGeometry` level by `BannerGeometryTruthTests
///   .test_ratioThatDisagreesWithItsArtwork_divergesFromTheRule`; this file adds the SAME divergence
///   measured through the full render (`SwiftUIAlertModal` vs `GBAlertModal`, hosted for real), so
///   both the rule and the shipped view are on record as agreeing it is real.
/// - **The landscape banner-wide column** — was flagged in that doc as "not gated by any test at
///   all": `GeometryPinsTests.test_bannerWide_landscape` measures this exact shape at this exact
///   host and deliberately excludes width from its assertion (see that test's own doc). This file is
///   the width assertion that test doesn't make.
///
/// Neither test argues the divergence should be fixed — see the differences doc for that
/// discussion. Both exist so a future change that moves either number (in either direction) is
/// something a person decides about, not something that slips by unnoticed.
@MainActor
final class BannerWidthDivergenceTests: XCTestCase {

    // MARK: - Landscape banner-wide column

    /// Cross-backend counterpart of `GeometryPinsTests.test_bannerWide_landscape`, which pins this
    /// shape's origin/height but deliberately not width. UIKit's height-constrained landscape banner
    /// shrinks its own WIDTH demand too (`height × ratio`); SwiftUI's rule is portrait-derived and
    /// does not follow suit — measured here as an exact, signed gap rather than "they differ".
    func test_bannerWide_landscape_theCardWidthDivergesFromUIKit() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-wide"))
        let uiKit = DifferentialGeometry.uiKitFrames(shape, size: DifferentialGeometry.landscapeHost)
        let swiftUI = DifferentialGeometry.swiftUIFrames(shape, size: DifferentialGeometry.landscapeHost)

        let uiKitCard = try XCTUnwrap(uiKit[.card], "UIKit reported no '.card' frame")
        let swiftUICard = try XCTUnwrap(swiftUI[.card], "SwiftUI reported no '.card' frame")

        // Premise: the two frames are comparable at all — origin/height still agree, matching
        // `GeometryPinsTests.test_bannerWide_landscape`'s own pin. Only width is at issue.
        XCTAssertEqual(uiKitCard.minX, swiftUICard.minX, accuracy: DifferentialGeometry.tolerance)
        XCTAssertEqual(uiKitCard.height, swiftUICard.height, accuracy: DifferentialGeometry.tolerance)

        XCTAssertEqual(
            uiKitCard.width, 320, accuracy: DifferentialGeometry.tolerance,
            "UIKit's measured landscape CARD width moved — update this pin (and the differences doc "
                + "if the divergence itself changed shape). Its own column caps at 256 (see the "
                + "differences doc); this is that column plus the 32pt/side max padding."
        )
        XCTAssertEqual(
            swiftUICard.width, 384, accuracy: DifferentialGeometry.tolerance,
            "SwiftUI's rule moved — update this pin"
        )
        XCTAssertGreaterThan(
            swiftUICard.width - uiKitCard.width, 32,
            "the landscape banner-wide gap has narrowed — if it has closed to ~0, the divergence "
                + "may be fixed: update docs/superpowers/notes/2026-08-08-uikit-swiftui-differences.md "
                + "and consider pinning width in GeometryPinsTests.test_bannerWide_landscape too"
        )
    }

    // MARK: - D-B: stated ratio disagrees with the artwork

    /// Full-render counterpart of `BannerGeometryTruthTests
    /// .test_ratioThatDisagreesWithItsArtwork_divergesFromTheRule`. Same 320x190 asset, same
    /// `bannerRatio: 1` mismatch (`GeniePresets.badgeProperties()`), same `iPadWidthHost` that test
    /// uses (needed here too: on a phone-width host both backends independently hit the SAME
    /// host-width ceiling — `390 - 2·cardMarginH` — and coincidentally agree at 350, which would
    /// make this test vacuous; `iPadWidthHost` is wide enough that neither backend clamps against
    /// it, so what is measured is the rule's own disagreement, not two unrelated ceilings), measured
    /// through the actual hosted views instead of the isolated `bannerGeometry` function.
    func test_bannerRatioMismatch_theCardWidthDivergesFromUIKit() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-ratio-mismatch"))
        let uiKit = DifferentialGeometry.uiKitFrames(shape, size: DifferentialGeometry.iPadWidthHost)
        let swiftUI = DifferentialGeometry.swiftUIFrames(shape, size: DifferentialGeometry.iPadWidthHost)

        let uiKitCard = try XCTUnwrap(uiKit[.card], "UIKit reported no '.card' frame")
        let swiftUICard = try XCTUnwrap(swiftUI[.card], "SwiftUI reported no '.card' frame")

        // The CARD-level gap (3.33pt) is smaller than `BannerGeometryTruthTests`' own
        // isolated-function COLUMN measurement (305.67 vs 320, 14.33pt) — the two are not the same
        // number and should not be expected to match: this measures the full render's `AlertDialog`
        // title/subtitle content too, not only `bannerGeometry`'s raw output. Both are real; this one
        // is what a person actually sees.
        XCTAssertEqual(
            uiKitCard.width, 380.67, accuracy: 1.0,
            "UIKit's measured CARD width moved — update this pin"
        )
        XCTAssertEqual(
            swiftUICard.width, 384, accuracy: DifferentialGeometry.tolerance,
            "SwiftUI's rule moved — update this pin"
        )
        XCTAssertGreaterThan(
            swiftUICard.width - uiKitCard.width, 1,
            "D-B's card-width gap has narrowed — if it has closed to ~0, the divergence may be "
                + "fixed: update docs/superpowers/notes/2026-08-08-uikit-swiftui-differences.md"
        )
    }
}
