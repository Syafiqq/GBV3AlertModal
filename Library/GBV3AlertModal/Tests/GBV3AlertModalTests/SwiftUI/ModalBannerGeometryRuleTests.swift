import XCTest
@testable import GBV3AlertModal

/// The two banner rules as a PURE function — no views, no window, no Auto Layout.
/// `BannerGeometryTruthTests` is the other half: it proves the rules match UIKit. This one proves
/// `ModalTokens` implements the rules. Neither is sufficient alone.
final class ModalBannerGeometryRuleTests: XCTestCase {
    /// Column 256, padding 20/32 per side, matching the app's real iPhone preset
    /// (`V3AlertModal+GBV3AlertModal.swift`: 256 on iPhone, 300 on iPad).
    private func tokens(ratio: CGFloat?, cap: CGFloat?) -> ModalTokens {
        ModalTokens(
            cornerRadius: 16,
            contentMaxWidth: 256,
            cardMarginV: 40,
            cardMarginH: 20,
            contentPadding: UIMinMaxEdgeInsets(
                top: (20, 32), left: (20, 32), bottom: (20, 32), right: (20, 32)
            ),
            contentChildrenFillWidth: true,
            bannerRatio: ratio,
            bannerMaxHeight: cap,
            gapBelowBanner: 16,
            gapBelowTitle: 12,
            gapBelowSubtitle: 24,
            interButton: 8,
            titleFont: .system(size: 24, weight: .bold),
            subtitleFont: .system(size: 16),
            palette: ModalTokens.standard.palette
        )
    }

    /// 390pt host, 20pt horizontal card margin -> 350pt of card, 310pt of column ceiling.
    private let available: CGFloat = 350

    func test_artworkNarrowerThanColumn_columnStaysAtContentMaxWidth() {
        let g = tokens(ratio: 1, cap: nil)
            .bannerGeometry(imageSize: CGSize(width: 160, height: 90), availableCardWidth: available)
        XCTAssertEqual(g.column, 256, accuracy: 0.01)
        XCTAssertEqual(g.height, 160, accuracy: 0.01)   // max(90, 160/1) = 160
    }

    func test_artworkWiderThanColumn_columnGrows() {
        let g = tokens(ratio: 320.0 / 190.0, cap: 256)
            .bannerGeometry(imageSize: CGSize(width: 320, height: 190), availableCardWidth: available)
        XCTAssertEqual(g.column, 310, accuracy: 0.01)   // demand 320, clamped by the 310 ceiling
        XCTAssertEqual(g.height, 310 / (320.0 / 190.0), accuracy: 0.01)   // 184.06
    }

    func test_capLimitsTheColumnDemand_notJustTheHeight() {
        // cap 216 * ratio 1.397 = 301.8, which is BELOW the artwork's 320 — so the cap, not the
        // artwork, sets the demand. Measured UIKit: column 302.
        let g = tokens(ratio: 320.0 / 229.0, cap: 216)
            .bannerGeometry(imageSize: CGSize(width: 320, height: 229), availableCardWidth: available)
        XCTAssertEqual(g.column, 216 * (320.0 / 229.0), accuracy: 0.01)   // 301.83
        XCTAssertEqual(g.height, 216, accuracy: 0.01)
    }

    func test_hugeArtwork_clampsToTheCeiling() {
        let g = tokens(ratio: 292.0 / 190.0, cap: 256)
            .bannerGeometry(imageSize: CGSize(width: 1168, height: 760), availableCardWidth: available)
        XCTAssertEqual(g.column, 310, accuracy: 0.01)
        XCTAssertEqual(g.height, 310 / (292.0 / 190.0), accuracy: 0.01)   // 201.7
    }

    func test_nilRatio_usesTheArtworksOwnAspect() {
        let g = tokens(ratio: nil, cap: nil)
            .bannerGeometry(imageSize: CGSize(width: 160, height: 90), availableCardWidth: available)
        XCTAssertEqual(g.column, 256, accuracy: 0.01)
        // r = 160/90; max(90, 160/r) = 90; column/r = 144. min -> 90.
        XCTAssertEqual(g.height, 90, accuracy: 0.01)
    }

    func test_capBelowEverything_wins() {
        let g = tokens(ratio: 1, cap: 40)
            .bannerGeometry(imageSize: CGSize(width: 160, height: 90), availableCardWidth: available)
        XCTAssertEqual(g.height, 40, accuracy: 0.01)
    }

    func test_zeroArtwork_collapses() {
        let g = tokens(ratio: 1, cap: nil)
            .bannerGeometry(imageSize: .zero, availableCardWidth: available)
        XCTAssertEqual(g.column, 0, accuracy: 0.01)
        XCTAssertEqual(g.height, 0, accuracy: 0.01)
    }

    func test_infiniteContentMaxWidth_doesNotProduceAnInfiniteColumn() {
        // `ModalTokens.standard` uses `contentMaxWidth: .infinity` (no Properties to derive a cap
        // from). The ceiling must still bound it.
        var t = ModalTokens.standard
        t.bannerRatio = 1
        t.bannerMaxHeight = nil
        let g = t.bannerGeometry(imageSize: CGSize(width: 160, height: 90), availableCardWidth: available)
        XCTAssertTrue(g.column.isFinite, "an infinite contentMaxWidth escaped the ceiling")
        XCTAssertTrue(g.height.isFinite)
    }
}
