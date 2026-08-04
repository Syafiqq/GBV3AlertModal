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
        // The COLUMN too, like every sibling above. A cap that low collapses the demand to
        // `cap * ratio` = 40, which is far under `contentMaxWidth`, so the column must stay at 256 —
        // the cap bounds the banner, it does not narrow the card. Asserting height alone left the
        // one shape where the cap dominates as the only row in this file with no column claim.
        XCTAssertEqual(g.column, 256, accuracy: 0.01)
    }

    func test_zeroArtwork_collapses() {
        let g = tokens(ratio: 1, cap: nil)
            .bannerGeometry(imageSize: .zero, availableCardWidth: available)
        XCTAssertEqual(g.column, 0, accuracy: 0.01)
        XCTAssertEqual(g.height, 0, accuracy: 0.01)
    }

    /// **The rigid slot has NO yield term, and this is the number that says so.**
    ///
    /// A 200x2000pt artwork with no ratio and no cap is the one regime where UIKit has explicit
    /// machinery to make the banner give way: the natural-aspect driver sits at
    /// `ModalLayout.Priority.bannerNaturalAspect` (245) and the image's own intrinsic resistance is
    /// dropped to `bannerImageIntrinsic` (241), both BELOW the title's compression resistance (900)
    /// and the subtitle slot's height tie (250), so UIKit shrinks the banner rather than starving
    /// the text. `GBAlertModal+ViewGraph.swift` names this exact 200x2000 case by number as the
    /// reason those priorities are where they are.
    ///
    /// `ModalTokens.bannerGeometry` has no equivalent term. It returns a **2000pt** slot height for
    /// a card whose whole host is 844pt tall, and `BannerSlot`'s frame is rigid, so nothing
    /// downstream shrinks it either. This test asserts what the rule ACTUALLY returns — it is not a
    /// statement that 2000 is right. It is here so the divergence is a pinned number rather than a
    /// rumour, and so that a future landscape/yield rule changes this assertion deliberately.
    ///
    /// No shipping asset is in this regime: all eight real banner assets are landscape or square,
    /// and all of them set a `bannerMaxHeight`, either of which alone keeps the height bounded.
    /// This belongs with the landscape rule work (design spec §5), not with the portrait rules the
    /// rest of this file pins.
    func test_tallUncappedArtwork_producesAnUnyieldingSlot_whereUIKitWouldYield() {
        let g = tokens(ratio: nil, cap: nil)
            .bannerGeometry(imageSize: CGSize(width: 200, height: 2000), availableCardWidth: available)

        // r = 200/2000 = 0.1. demand = 200, so column = max(200, contentMaxWidth 256) = 256,
        // under the 310 ceiling.
        XCTAssertEqual(g.column, 256, accuracy: 0.01)
        // min(column/r = 2560, max(2000, 200/r = 2000) = 2000) = 2000. No cap to bring it down, and
        // no term anywhere that lets the text push back.
        XCTAssertEqual(g.height, 2000, accuracy: 0.01)
    }

    // MARK: - The 300pt column (the app's iPad width)

    /// **The app states 256 on iPhone and 300 on iPad** (`V3AlertModal+GBV3AlertModal.swift`), and
    /// every rule test above runs at 256. These two run the same rules at 300.
    ///
    /// **What they prove and what they do not.** `bannerGeometry` is a pure function of the tokens
    /// and two `CGFloat`s, so exercising it at 300 proves the ARITHMETIC — that
    /// `max(demand, contentMaxWidth)` and the ceiling compose the same way at the wider column. They
    /// prove nothing about iPad hardware, and nothing about the app choosing 300 in the first place:
    /// no device, no trait collection and no idiom is involved anywhere in this file. The measured
    /// half — the same column against real Auto Layout output, on a 1024x1366 host — is
    /// `BannerGeometryTruthTests`' `test_column300_*`, and its own doc states the same limit.
    private func iPadTokens(ratio: CGFloat?, cap: CGFloat?) -> ModalTokens {
        var t = tokens(ratio: ratio, cap: cap)
        t.contentMaxWidth = 300
        return t
    }

    func test_column300_artworkNarrowerThanColumn_columnStaysAtContentMaxWidth() {
        // On a 1024pt host: 984pt of card, 944pt of column ceiling — nothing is clamped here.
        let g = iPadTokens(ratio: nil, cap: nil)
            .bannerGeometry(imageSize: CGSize(width: 160, height: 160), availableCardWidth: 984)
        XCTAssertEqual(g.column, 300, accuracy: 0.01)
        XCTAssertEqual(g.height, 160, accuracy: 0.01)   // r = 1; max(160, 160) = 160
    }

    func test_column300_artworkWiderThanColumn_columnGrowsPastThe300() {
        let g = iPadTokens(ratio: 400.0 / 250.0, cap: 256)
            .bannerGeometry(imageSize: CGSize(width: 400, height: 250), availableCardWidth: 984)
        // demand = min(400, 256 * 1.6 = 409.6) = 400, above the 300pt column and under the ceiling.
        XCTAssertEqual(g.column, 400, accuracy: 0.01)
        XCTAssertEqual(g.height, 250, accuracy: 0.01)   // min(256, 400/1.6 = 250, max(250, 250))
        // And the SAME artwork on a 390pt phone host clamps to that host's 310pt ceiling instead —
        // the branch the 300pt column shares with the 256pt one.
        let onAPhone = iPadTokens(ratio: 400.0 / 250.0, cap: 256)
            .bannerGeometry(imageSize: CGSize(width: 400, height: 250), availableCardWidth: available)
        XCTAssertEqual(onAPhone.column, 310, accuracy: 0.01)
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
