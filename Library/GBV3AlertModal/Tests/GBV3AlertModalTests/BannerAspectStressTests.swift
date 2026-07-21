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

    /// With no `bannerMaxHeight`, the banner should render at its full natural aspect
    /// (`height == width * imageSize.height/imageSize.width`) when there's room for it, proving
    /// the new constraint path (not just the capped fallback) actually derives the right height.
    func test_banner9x16_uncapped_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardPropertiesNilBannerRatio(),
                                  holder: GeniePresets.withBanner(width: 90, height: 160))
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
        assertContentNotSqueezed(modal)

        guard let vwBanner = modal.vwBanner else {
            XCTFail("expected vwBanner to be non-nil")
            return
        }
        // width 220 (256 fixed card width minus padding) * (160/90) ~= 391, well within the
        // portrait host's available height.
        XCTAssertEqual(vwBanner.bounds.height / vwBanner.bounds.width, 160.0 / 90.0, accuracy: 0.01)
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
