import XCTest
import Foundation
@testable import GBV3AlertModal

/// **Absolute pins of SwiftUI's OWN computed geometry — Pass 5 step 2
/// (`2026-08-07-uikit-retirement.md` §3).**
///
/// Recorded from the differential gate's live numbers while it was still green, by a throwaway
/// recorder test run once and deleted (`git log` for `PinRecorderTests` if the generation method
/// needs revisiting). These are NOT a comparison against UIKit — the gate did that; this only
/// re-asks SwiftUI the same question it already answered, so a future change to
/// `AlertModalScaffold`/`ModalTokens`/`SwiftUIAlertModal` that moves a number is still caught after
/// `DifferentialGeometryTests` is deleted.
///
/// **What this gives up, stated once rather than left implicit:** the ability to detect UIKit
/// drifting away from these numbers. That is acceptable only because UIKit is frozen and about to be
/// inert (§6a) — if that stops being true, these pins stop being a substitute for the gate.
///
/// Step 3 (mutation-verification, with the gate switched off) is what proves these pins actually
/// catch what the gate caught, before the gate is deleted in step 4.
@MainActor
final class GeometryPinsTests: XCTestCase {

    func test_standardOneButton_portrait() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "standard-one-button")),
            size: DifferentialGeometry.host
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 168.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 24.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 60.6667, w: 256.0000, h: 19.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 93.0000, w: 256.0000, h: 48.0000
        )
    }

    func test_standardOneButton_landscape() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "standard-one-button")),
            size: DifferentialGeometry.landscapeHost
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 168.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 24.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 60.6667, w: 256.0000, h: 19.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 93.0000, w: 256.0000, h: 48.0000
        )
    }

    func test_standardTwoButton_portrait() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "standard-two-button")),
            size: DifferentialGeometry.host
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 243.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 24.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 60.6667, w: 256.0000, h: 38.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 112.0000, w: 256.0000, h: 48.0000
        )
        assertPinned(
            frames, .secondaryButton,
            x: 133.3333, y: 171.0000, w: 53.3333, h: 48.0000
        )
    }

    func test_standardTwoButton_landscape() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "standard-two-button")),
            size: DifferentialGeometry.landscapeHost
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 243.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 24.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 60.6667, w: 256.0000, h: 38.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 112.0000, w: 256.0000, h: 48.0000
        )
        assertPinned(
            frames, .secondaryButton,
            x: 133.3333, y: 171.0000, w: 53.3333, h: 48.0000
        )
    }

    func test_titleNilError_portrait() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "title-nil-error")),
            size: DifferentialGeometry.host
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 169.3333
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 24.0000, w: 256.0000, h: 57.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 94.3333, w: 256.0000, h: 48.0000
        )
    }

    func test_closeButtonDismiss_portrait() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "close-button-dismiss")),
            size: DifferentialGeometry.host
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 187.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 24.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 60.6667, w: 256.0000, h: 38.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 112.0000, w: 256.0000, h: 48.0000
        )
        assertPinned(
            frames, .closeButton,
            x: 272.0000, y: 0.0000, w: 48.0000, h: 48.0000
        )
    }

    func test_obliqueRedLeaveConfirm_portrait() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "oblique-red-leave-confirm")),
            size: DifferentialGeometry.host
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 243.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 24.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 60.6667, w: 256.0000, h: 38.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 112.0000, w: 256.0000, h: 48.0000
        )
        assertPinned(
            frames, .secondaryButton,
            x: 133.3333, y: 171.0000, w: 53.3333, h: 48.0000
        )
    }

    func test_obliqueRedLeaveConfirm_landscape() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "oblique-red-leave-confirm")),
            size: DifferentialGeometry.landscapeHost
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 243.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 24.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 60.6667, w: 256.0000, h: 38.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 112.0000, w: 256.0000, h: 48.0000
        )
        assertPinned(
            frames, .secondaryButton,
            x: 133.3333, y: 171.0000, w: 53.3333, h: 48.0000
        )
    }

    func test_permissionDeniedSettings_portrait() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "permission-denied-settings")),
            size: DifferentialGeometry.host
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 316.0000, h: 235.0000
        )
        assertPinned(
            frames, .title,
            x: 30.0000, y: 20.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 30.0000, y: 60.6667, w: 256.0000, h: 38.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 33.0000, y: 116.0000, w: 256.0000, h: 48.0000
        )
        assertPinned(
            frames, .secondaryButton,
            x: 111.1667, y: 175.0000, w: 93.6667, h: 48.0000
        )
    }

    func test_permissionDeniedSettings_landscape() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "permission-denied-settings")),
            size: DifferentialGeometry.landscapeHost
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 316.0000, h: 235.0000
        )
        assertPinned(
            frames, .title,
            x: 30.0000, y: 20.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 30.0000, y: 60.6667, w: 256.0000, h: 38.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 33.0000, y: 116.0000, w: 256.0000, h: 48.0000
        )
        assertPinned(
            frames, .secondaryButton,
            x: 111.1667, y: 175.0000, w: 93.6667, h: 48.0000
        )
    }

    func test_onboardingWelcomeNobanner_portrait() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "onboarding-welcome-nobanner")),
            size: DifferentialGeometry.host
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 200.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 32.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 76.6667, w: 256.0000, h: 19.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 117.0000, w: 256.0000, h: 48.0000
        )
    }

    func test_onboardingWelcomeNobanner_landscape() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "onboarding-welcome-nobanner")),
            size: DifferentialGeometry.landscapeHost
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 200.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 32.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 76.6667, w: 256.0000, h: 19.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 117.0000, w: 256.0000, h: 48.0000
        )
    }

    func test_longSubtitleUnscrolled_portrait() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "long-subtitle-unscrolled")),
            size: DifferentialGeometry.host
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 778.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 16.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 52.6667, w: 256.0000, h: 645.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 711.0000, w: 256.0000, h: 48.0000
        )
    }

    func test_longSubtitleUnscrolled_landscape() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "long-subtitle-unscrolled")),
            size: DifferentialGeometry.landscapeHost
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 294.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 16.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 52.6667, w: 256.0000, h: 161.3333
        )
        assertPinned(
            frames, .primaryButton,
            x: 35.0000, y: 227.0000, w: 256.0000, h: 48.0000
        )
    }

    func test_noPrimarySecondaryOnly_portrait() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "no-primary-secondary-only")),
            size: DifferentialGeometry.host
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 168.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 24.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 60.6667, w: 256.0000, h: 19.3333
        )
        assertPinned(
            frames, .secondaryButton,
            x: 118.3333, y: 96.0000, w: 83.3333, h: 48.0000
        )
    }

    func test_noButtonsTitleSubtitle_portrait() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "no-buttons-title-subtitle")),
            size: DifferentialGeometry.host
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 123.0000
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 24.0000, w: 256.0000, h: 28.6667
        )
        assertPinned(
            frames, .subtitle,
            x: 32.0000, y: 60.6667, w: 256.0000, h: 38.3333
        )
    }

    func test_noButtonsTitleOnly_portrait() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "no-buttons-title-only")),
            size: DifferentialGeometry.host
        )
        assertPinned(
            frames, .card,
            x: 0.0000, y: 0.0000, w: 320.0000, h: 76.6667
        )
        assertPinned(
            frames, .title,
            x: 32.0000, y: 24.0000, w: 256.0000, h: 28.6667
        )
    }

    func test_bannerWide_landscape() {
        let frames = DifferentialGeometry.swiftUIFrames(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "banner-wide")),
            size: DifferentialGeometry.landscapeHost
        )
        assertPinnedOriginAndHeight(
            frames, .card,
            x: 0.0000, y: 0.0000, h: 294.0000
        )
        assertPinnedOriginAndHeight(
            frames, .banner,
            x: 32.0000, y: 20.0000, h: 102.2396
        )
        assertPinnedOriginAndHeight(
            frames, .title,
            x: 32.0000, y: 138.2396, h: 28.6667
        )
        assertPinnedOriginAndHeight(
            frames, .subtitle,
            x: 32.0000, y: 182.9062, h: 19.0938
        )
        assertPinnedOriginAndHeight(
            frames, .primaryButton,
            x: 35.0000, y: 223.0000, h: 48.0000
        )
    }

    // MARK: - Layer visuals

    func test_standardOneButton_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "standard-one-button"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_standardTwoButton_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "standard-two-button"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_titleNilError_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "title-nil-error"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_closeButtonDismiss_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "close-button-dismiss"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_obliqueRedLeaveConfirm_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "oblique-red-leave-confirm"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_permissionDeniedSettings_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "permission-denied-settings"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_onboardingWelcomeNobanner_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "onboarding-welcome-nobanner"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_streakPopupBanner_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "streak-popup-banner"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_databaseErrorBanner_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "database-error-banner"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_bannerComparable_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "banner-comparable"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_bannerWide_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "banner-wide"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_longSubtitleUnscrolled_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "long-subtitle-unscrolled"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertEqual(visuals.primaryButton, ModalTokens.LayerVisual(cornerRadius: 8.0000, shadowOffset: CGSize(width: -3.0000, height: 3.0000), shadowRadius: 0.0000))
    }

    func test_noPrimarySecondaryOnly_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "no-primary-secondary-only"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertNil(visuals.primaryButton)
    }

    func test_noButtonsTitleSubtitle_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "no-buttons-title-subtitle"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertNil(visuals.primaryButton)
    }

    func test_noButtonsTitleOnly_layerVisuals() {
        let visuals = DifferentialGeometry.swiftUILayerVisuals(
            try! XCTUnwrap(DifferentialGeometry.shape(named: "no-buttons-title-only"))
        )
        XCTAssertEqual(visuals.card, ModalTokens.LayerVisual(cornerRadius: 16.0000, shadowOffset: CGSize(width: 0.0000, height: 0.0000), shadowRadius: 0.0000))
        XCTAssertNil(visuals.primaryButton)
    }


    // MARK: - Helpers

    private func assertPinned(
        _ frames: [ModalGeometryElement: CGRect],
        _ element: ModalGeometryElement,
        x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let rect = frames[element] else {
            XCTFail(
                "'\(element.rawValue)' missing from SwiftUI frames — it was present when this pin "
                    + "was recorded",
                file: file, line: line
            )
            return
        }
        XCTAssertEqual(
            rect.minX, x, accuracy: DifferentialGeometry.tolerance,
            "'\(element.rawValue)' minX drifted from its pinned value", file: file, line: line
        )
        XCTAssertEqual(
            rect.minY, y, accuracy: DifferentialGeometry.tolerance,
            "'\(element.rawValue)' minY drifted from its pinned value", file: file, line: line
        )
        XCTAssertEqual(
            rect.width, w, accuracy: DifferentialGeometry.tolerance,
            "'\(element.rawValue)' width drifted from its pinned value", file: file, line: line
        )
        XCTAssertEqual(
            rect.height, h, accuracy: DifferentialGeometry.tolerance,
            "'\(element.rawValue)' height drifted from its pinned value", file: file, line: line
        )
    }

    /// `banner-wide` in landscape only: WIDTH is deliberately not pinned here, matching
    /// `DifferentialGeometryTests.test_geometry_landscape_bannerWide_agreesOnEveryOriginAndHeight`,
    /// whose own doc explains why (UIKit's landscape column and SwiftUI's disagree by design — see
    /// `test_bannerWide_landscape_theWidthGapIsTheColumnRule`). Everything else about this shape is
    /// pinned like any other; only this one element, in this one orientation, drops one field.
    private func assertPinnedOriginAndHeight(
        _ frames: [ModalGeometryElement: CGRect],
        _ element: ModalGeometryElement,
        x: CGFloat, y: CGFloat, h: CGFloat,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let rect = frames[element] else {
            XCTFail(
                "'\(element.rawValue)' missing from SwiftUI frames — it was present when this pin "
                    + "was recorded",
                file: file, line: line
            )
            return
        }
        XCTAssertEqual(
            rect.minX, x, accuracy: DifferentialGeometry.tolerance,
            "'\(element.rawValue)' minX drifted from its pinned value", file: file, line: line
        )
        XCTAssertEqual(
            rect.minY, y, accuracy: DifferentialGeometry.tolerance,
            "'\(element.rawValue)' minY drifted from its pinned value", file: file, line: line
        )
        XCTAssertEqual(
            rect.height, h, accuracy: DifferentialGeometry.tolerance,
            "'\(element.rawValue)' height drifted from its pinned value", file: file, line: line
        )
    }
}
