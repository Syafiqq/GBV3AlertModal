import XCTest
@testable import GBV3AlertModal

/// **The UIKit banner rules, pinned against measured Auto Layout output.**
///
/// UIKit's banner geometry is emergent — `vwBanner` often carries NO height constraint at all, and
/// the slot's size falls out of `ivBanner`'s intrinsic content size meeting its default compression
/// resistance (750) through the `width == height * ratio` tie. Two closed-form rules reproduce it in
/// portrait; this suite is what fails if a priority in `ModalLayout.Priority` is retuned, which has
/// already happened once with only stale comments to show for it.
///
/// PORTRAIT ONLY, and deliberately so: in a height-constrained card UIKit distributes the remainder
/// across four sub-required tiers and the banner takes the residual (measured 102.3 for every real
/// preset regardless of ratio or cap). No closed form reaches that, and none is claimed here.
@MainActor
final class BannerGeometryTruthTests: XCTestCase {
    private let host = CGSize(width: 390, height: 844)

    /// The rules under test. Mirrors `ModalTokens.bannerGeometry` (Task 2) but is written out
    /// independently ON PURPOSE: a truth table that imports the implementation it is checking
    /// proves only that the code equals itself.
    private func predicted(
        imageSize: CGSize,
        ratio: CGFloat?,
        cap: CGFloat?,
        contentMaxWidth: CGFloat,
        leftMin: CGFloat,
        rightMin: CGFloat,
        availableCardWidth: CGFloat
    ) -> (column: CGFloat, height: CGFloat) {
        guard imageSize.width > 0, imageSize.height > 0 else { return (0, 0) }
        let r = ratio ?? (imageSize.width / imageSize.height)
        let capped = cap ?? .greatestFiniteMagnitude
        let ceiling = availableCardWidth - leftMin - rightMin
        let demand = min(imageSize.width, capped * r)
        let column = min(max(demand, contentMaxWidth), ceiling)
        let height = min(capped, column / r, max(imageSize.height, imageSize.width / r))
        return (column, height)
    }

    private func measure(
        _ properties: GBAlertModal.Properties,
        imageSize: CGSize
    ) -> (column: CGFloat, height: CGFloat, card: CGFloat) {
        let modal = GBAlertModal(
            properties: properties,
            holder: GeniePresets.withBanner(width: imageSize.width, height: imageSize.height)
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: host))
        window.isHidden = false
        modal.show(parent: window, completion: {})
        window.setNeedsLayout()
        window.layoutIfNeeded()
        let slot = modal.vwBanner?.frame ?? .zero
        let card = modal.vwContainer?.frame ?? .zero
        window.isHidden = true
        return (slot.width, slot.height, card.width)
    }

    private func assertRules(
        _ label: String,
        properties: GBAlertModal.Properties,
        imageSize: CGSize,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let measured = measure(properties, imageSize: imageSize)
        let padding = properties.padding ?? UIMinMaxEdgeInsets()
        let expected = predicted(
            imageSize: imageSize,
            ratio: properties.bannerRatio,
            cap: properties.bannerMaxHeight,
            contentMaxWidth: properties.contentProperty?.maxWidthPortrait ?? .infinity,
            leftMin: padding.leftMin,
            rightMin: padding.rightMin,
            availableCardWidth: host.width - (properties.margin?.left ?? 0) - (properties.margin?.right ?? 0)
        )
        XCTAssertEqual(
            measured.column, expected.column, accuracy: 0.5,
            "\(label): column rule broke — measured \(measured.column), rule says \(expected.column)",
            file: file, line: line
        )
        XCTAssertEqual(
            measured.height, expected.height, accuracy: 0.5,
            "\(label): height rule broke — measured \(measured.height), rule says \(expected.height)",
            file: file, line: line
        )
    }

    // MARK: - Artwork that fits inside the column

    func test_ratio1_artworkNarrowerThanColumn() {
        assertRules("160x90 r1 no cap",
                    properties: GeniePresets.standardProperties(),
                    imageSize: CGSize(width: 160, height: 90))
    }

    func test_ratio1_squareArtworkNarrowerThanColumn() {
        assertRules("160x160 r1 cap216",
                    properties: GeniePresets.popupProperties().copy(bannerRatio: 1, bannerMaxHeight: 216),
                    imageSize: CGSize(width: 160, height: 160))
    }

    func test_naturalAspect_artworkNarrowerThanColumn() {
        assertRules("160x90 rNil no cap",
                    properties: GeniePresets.standardPropertiesNilBannerRatio(),
                    imageSize: CGSize(width: 160, height: 90))
    }

    // MARK: - Artwork wider than the column (every real app asset but one)

    func test_gc2gsShape_artworkWiderThanColumn() {
        assertRules("320x190 r320:190 cap256",
                    properties: GeniePresets.popupProperties()
                        .copy(bannerRatio: 320.0 / 190.0, bannerMaxHeight: 256),
                    imageSize: CGSize(width: 320, height: 190))
    }

    func test_quizShape_capBindsBeforeTheColumn() {
        assertRules("320x229 r320:229 cap216",
                    properties: GeniePresets.popupProperties()
                        .copy(bannerRatio: 320.0 / 229.0, bannerMaxHeight: 216),
                    imageSize: CGSize(width: 320, height: 229))
    }

    func test_errorBannerShape_artworkJustUnderTheCeiling() {
        assertRules("295x256 r295:256 cap320",
                    properties: GeniePresets.errorBannerProperties(),
                    imageSize: CGSize(width: 295, height: 256))
    }

    func test_fasttrackShape_hugeArtworkClampsToTheCeiling() {
        assertRules("1168x760 r292:190 cap256",
                    properties: GeniePresets.popupProperties()
                        .copy(bannerRatio: 292.0 / 190.0, bannerMaxHeight: 256),
                    imageSize: CGSize(width: 1168, height: 760))
    }

    // MARK: - The cap

    func test_capBelowEverything_wins() {
        assertRules("160x90 r1 cap40",
                    properties: GeniePresets.standardProperties().copy(bannerMaxHeight: 40),
                    imageSize: CGSize(width: 160, height: 90))
    }

    // MARK: - The inert field, pinned so its removal from SwiftUI stays justified

    /// `bannerFixedHeight` sits at 243: below the card's hugging (250) going up, below the image's
    /// compression resistance (750) coming down. Measured zero effect at every size tried. SwiftUI
    /// drops it in Task 3 on the strength of this test.
    func test_bannerFixedHeight_isInert_onTheRatioPath() {
        let withFixed = measure(
            GeniePresets.standardProperties().copy(bannerFixedHeight: 200),
            imageSize: CGSize(width: 64, height: 64)
        )
        let without = measure(
            GeniePresets.standardProperties(),
            imageSize: CGSize(width: 64, height: 64)
        )
        XCTAssertEqual(withFixed.height, without.height, accuracy: 0.5,
                       "bannerFixedHeight changed the slot height — it is no longer inert, and "
                           + "ModalTokens.bannerLayout must start applying it again")
        XCTAssertEqual(withFixed.height, 64, accuracy: 0.5)
    }

    func test_bannerFixedHeight_isInert_onTheNaturalAspectPath() {
        let withFixed = measure(
            GeniePresets.standardPropertiesNilBannerRatio().copy(bannerFixedHeight: 200),
            imageSize: CGSize(width: 64, height: 64)
        )
        XCTAssertEqual(withFixed.height, 64, accuracy: 0.5,
                       "bannerFixedHeight is no longer inert on the natural-aspect path")
    }

    // MARK: - Degenerate

    func test_zeroSizeArtwork_collapsesTheSlot() {
        let measured = measure(GeniePresets.standardProperties(), imageSize: .zero)
        // Guard against a vacuous pass: if the modal never laid out at all, `vwBanner` would be
        // nil and both assertions below would read 0 from `?? .zero` regardless of whether the
        // slot actually collapsed. Proving the card built confirms the zeros mean something.
        XCTAssertGreaterThan(
            measured.card, 0,
            "the modal did not lay out at all, so the zero-size slot below proves nothing"
        )
        XCTAssertEqual(measured.column, 0, accuracy: 0.5)
        XCTAssertEqual(measured.height, 0, accuracy: 0.5)
    }
}
