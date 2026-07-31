import XCTest
import SnapshotTesting
@testable import GBV3AlertModal

/// Stress test for the natural-image-aspect banner path (`bannerRatio == nil`, see
/// `GBAlertModal+ViewGraph.swift`'s `installConstraints` and `ModalLayout.bannerHeightMultiplier`).
///
/// Before this fix, `ivBanner`'s constraint block forced the banner into a SQUARE slot whenever
/// `bannerRatio` was set (the Genie preset always sets `bannerRatio: 1`); a `bannerRatio == nil`
/// banner used the old centered/intrinsic-size alignment. This suite exercises the NEW
/// `bannerRatio == nil` behavior across three source-image aspects (16:9 wide, 9:16 tall, 1:1
/// square) at both orientations, and asserts the title/subtitle/primary-action button are all
/// still fully laid out inside the modal's content container — i.e. not squeezed off, especially
/// under the tight landscape card height.
///
/// `bannerCap` (`bannerMaxHeight: 32`): this fixture's landscape card gives the content stack
/// only ~182pt of height (`standardProperties()`'s margin/padding vs an 844x390 landscape host).
/// The non-banner rows (2 dividers + title + subtitle + primary button) already need ~150pt of
/// that at their full natural size, so an UNCAPPED tall (9:16) or even square banner — asking for
/// up to 220pt — was found (empirically, by inspecting recorded snapshots + measured frames) to
/// starve the title/subtitle under Auto Layout's strict priority tiers, squeezing both toward
/// zero height. Capping the banner at 32pt leaves the rest of the content at its full natural
/// size (verified below: `lbTitle`/`lbSubtitle`/`btPrimaryAction` all end up non-zero and inside
/// `svContentContainer`'s bounds in every one of the 6 cases) and lets `scaleAspectFit` letterbox
/// the (now smaller) banner instead.
// @MainActor: builds/renders the @MainActor `GBAlertModal` and inspects its live UIKit view
// properties (`lbTitle`, `svContentContainer`, etc.), so it must run on the main actor under
// Swift 6.
@MainActor
final class BannerAspectStressTests: XCTestCase {
    let portrait = CGSize(width: 390, height: 844)
    let landscape = CGSize(width: 844, height: 390)
    let bannerCap: CGFloat = 32

    // MARK: - 16:9 (wide, short)

    func test_banner16x9_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardPropertiesNilBannerRatio(bannerMaxHeight: bannerCap),
                                  holder: GeniePresets.withBanner(width: 160, height: 90))
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
        assertContentNotSqueezed(modal)
    }

    func test_banner16x9_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardPropertiesNilBannerRatio(bannerMaxHeight: bannerCap),
                                  holder: GeniePresets.withBanner(width: 160, height: 90))
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
        assertContentNotSqueezed(modal)
    }

    // MARK: - 9:16 (tall, narrow)

    func test_banner9x16_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardPropertiesNilBannerRatio(bannerMaxHeight: bannerCap),
                                  holder: GeniePresets.withBanner(width: 90, height: 160))
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
        assertContentNotSqueezed(modal)
    }

    func test_banner9x16_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardPropertiesNilBannerRatio(bannerMaxHeight: bannerCap),
                                  holder: GeniePresets.withBanner(width: 90, height: 160))
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
        assertContentNotSqueezed(modal)
    }

    // MARK: - 1:1 (square)

    func test_banner1x1_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardPropertiesNilBannerRatio(bannerMaxHeight: bannerCap),
                                  holder: GeniePresets.withBanner(width: 100, height: 100))
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
        assertContentNotSqueezed(modal)
    }

    func test_banner1x1_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardPropertiesNilBannerRatio(bannerMaxHeight: bannerCap),
                                  holder: GeniePresets.withBanner(width: 100, height: 100))
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
        assertContentNotSqueezed(modal)
    }

    // MARK: - Uncapped natural aspect (portrait only — ample height, no cap needed)

    /// **The banner is cosmetic, so it never wins — not even against the card's own shape.**
    ///
    /// This test used to assert the opposite: that an uncapped `bannerRatio: nil` banner renders at
    /// its FULL natural aspect (391pt tall here) whenever the host has room. That contract predates
    /// the owner's ordering — "buttons > title > description > banner", with the banner explicitly
    /// "just cosmetic, not information" — and the two cannot both hold. `vwContainer.center` and
    /// `svContentContainer`'s padding-max equalities are all `.low` (250): they are what makes the
    /// card HUG its content rather than sprawl, and a banner that outranks them grows the card to
    /// 391pt of decoration around two lines of text. So `bannerNaturalAspect` now sits BELOW them.
    ///
    /// What survives is the part that was ever about correctness: the natural aspect is the banner's
    /// CEILING, derived from the image (a 9:16 source must never render WIDER than 9:16 and get
    /// cropped), `scaleAspectFit` letterboxes whatever height it is granted, and the content is
    /// untouched. `test_tallBanner_uncapped_titleAndSubtitleSurvive` below covers the same principle
    /// at the extreme.
    func test_banner9x16_uncapped_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardPropertiesNilBannerRatio(),
                                  holder: GeniePresets.withBanner(width: 90, height: 160))
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
        assertContentNotSqueezed(modal)

        guard let vwBanner = modal.vwBanner else {
            XCTFail("expected vwBanner to be non-nil")
            return
        }
        let aspect = vwBanner.bounds.height / vwBanner.bounds.width
        XCTAssertGreaterThan(vwBanner.bounds.height, 0, "the banner must still be visible")
        XCTAssertLessThanOrEqual(
            aspect, 160.0 / 90.0 + 0.01,
            "the source image's natural aspect is the banner's CEILING — a taller slot would crop or "
                + "stretch a 9:16 image rather than letterbox it"
        )
    }

    // MARK: - Tall uncapped banner must yield to title/subtitle (regression)

    /// A very tall banner (200x2000 → natural multiplier 10) with NO `bannerMaxHeight` set.
    /// The banner's natural-aspect height driver wants ~2200pt, far more than the portrait
    /// card can offer. Content is essential and must keep its intrinsic height; the banner is
    /// decorative and must COMPRESS (scaleAspectFit letterboxes it). Before the fix, the banner
    /// won the vertical-space competition and the title + subtitle collapsed to ~0 height.
    func test_tallBanner_uncapped_titleAndSubtitleSurvive() {
        let modal = GBAlertModal(properties: GeniePresets.standardPropertiesNilBannerRatio(),
                                  holder: GeniePresets.withBanner(width: 200, height: 2000))
        _ = renderForSnapshot(modal, size: portrait)

        let titleH = modal.lbTitle?.frame.height ?? -1
        let subtitleContainerH = modal.svSubtitleContainer?.frame.height ?? -1

        // Content wins: title + subtitle keep their intrinsic height; the banner (decorative)
        // compresses into the leftover space (scaleAspectFit letterboxes the tall image).
        XCTAssertGreaterThan(titleH, 0, "title must keep its intrinsic height, not collapse")
        XCTAssertGreaterThan(subtitleContainerH, 0, "subtitle must stay visible, not collapse")
        assertContentNotSqueezed(modal)
    }

    // MARK: - Behavioral assert helper

    /// Proof of "no squeeze-off": after render, the title, subtitle, and primary-action button
    /// all have non-zero height and their frames (converted into `svContentContainer`'s
    /// coordinate space) fall fully within its bounds.
    private func assertContentNotSqueezed(_ modal: GBAlertModal, file: StaticString = #filePath, line: UInt = #line) {
        guard let container = modal.svContentContainer else {
            XCTFail("expected svContentContainer to be non-nil", file: file, line: line)
            return
        }

        func assertVisible(_ view: UIView?, _ name: String) {
            guard let view else {
                XCTFail("expected \(name) to be non-nil", file: file, line: line)
                return
            }
            XCTAssertGreaterThan(view.bounds.height, 0,
                                  "\(name) must have non-zero height", file: file, line: line)

            let frameInContainer = view.convert(view.bounds, to: container)
            XCTAssertGreaterThanOrEqual(frameInContainer.minY, container.bounds.minY - 0.5,
                                         "\(name) must not be pushed above svContentContainer's top",
                                         file: file, line: line)
            XCTAssertLessThanOrEqual(frameInContainer.maxY, container.bounds.maxY + 0.5,
                                      "\(name) must not be pushed below svContentContainer's bottom (clipped/squeezed off)",
                                      file: file, line: line)
        }

        assertVisible(modal.lbTitle, "lbTitle")
        assertVisible(modal.lbSubtitle, "lbSubtitle")
        assertVisible(modal.btPrimaryAction, "btPrimaryAction")
    }
}
