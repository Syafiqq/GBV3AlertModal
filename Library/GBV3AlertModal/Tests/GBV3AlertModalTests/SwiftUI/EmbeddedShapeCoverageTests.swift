import SwiftUI
import XCTest
@testable import GBV3AlertModal

/// **The acceptance gate for goal #3 — "all 26 real shapes also available on the UIKit-free
/// renderer", not just `SwiftUIModalRenderer`.**
///
/// Reuses `GenieShapeCatalog.shapes`/`.names` VERBATIM (the 26 descriptor constructions are
/// renderer-agnostic — `Shape.present` was generalized to `any ModalRenderer` for exactly this) —
/// only the RENDERER SETUP is new: `EmbeddedModalRenderer`, the 17 `ModalProperties`-typed style
/// presets, and the same banner-substitution trick `GenieShapeCatalog.makeRenderer()` uses (this
/// test target owns no main-bundle assets, so every named banner resolves nil unless substituted).
///
/// Same bar `ShapeCoverageTests.test_manifest_coversAllTwentySixCatalogShapes` sets, not the full
/// per-shape assertion suite: every shape presents and has SOMETHING to draw. The per-shape
/// STRUCTURAL correctness (showsBanner/showsTitle/etc.) is already proven once, for the SAME shared
/// resolver every backend calls (`ShapeCoverageTests`, `LayerA_ResolverTests`) — re-asserting it
/// per-field a second time here would be a second copy of the same claim, not new coverage. What
/// IS new here: does the REGISTRY WIRING (style lookup, banner substitution, bespoke `view`
/// registration) work correctly on THIS renderer, for every one of the 26 real shapes.
@MainActor
final class EmbeddedShapeCoverageTests: XCTestCase {

    // MARK: - Renderer setup — the EmbeddedModalRenderer equivalent of GenieShapeCatalog.makeRenderer()

    static func makeRenderer() -> EmbeddedModalRenderer {
        let renderer = EmbeddedModalRenderer(alertProperties: GeniePresets.standardModalProperties())
        for (style, properties) in stylePresets {
            renderer.register(style: style, properties: properties)
        }
        registerStandardFamily(on: renderer)
        renderer.registerBuiltInDescriptors()
        return renderer
    }

    /// style → preset, the `ModalProperties` mirror of `GenieShapeCatalog.stylePresets`.
    static var stylePresets: [(ModalStyle, ModalProperties)] {
        [
            (.permissionAlert, GeniePresets.permissionAlertModalProperties()),
            (.obliqueRed, GeniePresets.obliqueRedModalProperties()),
            (.errorBanner, GeniePresets.errorBannerModalProperties()),
            (.forceUpdateBanner, GeniePresets.forceUpdateBannerModalProperties()),
            (.capBanner, GeniePresets.capBannerModalProperties()),
            (.quizBanner, GeniePresets.quizBannerModalProperties()),
            (.trialBanner, GeniePresets.quizBannerModalProperties()),
            (.aiNotesBanner, GeniePresets.aiNotesBannerModalProperties()),
            (.creditDeduction, GeniePresets.creditDeductionModalProperties()),
            (.streak, GeniePresets.streakModalProperties()),
            (.timerBanner, GeniePresets.timerBannerModalProperties()),
            (.exitWorksheetBanner, GeniePresets.exitWorksheetBannerModalProperties()),
            (.renameInput, GeniePresets.renameInputModalProperties()),
            (.datePickerInput, GeniePresets.datePickerInputModalProperties()),
            (.badgeUnlock, GeniePresets.badgeUnlockModalProperties()),
            (.badgeMulti, GeniePresets.badgeMultiModalProperties()),
            (.badgeDetail, GeniePresets.badgeDetailModalProperties())
        ]
    }

    /// Same deliberate deviation `GenieShapeCatalog.registerStandardFamily` documents: this test
    /// bundle owns no main-bundle assets, so every named banner resolves nil unless substituted.
    /// `ModalContent` has no `.copy()`, so this rebuilds one with `hasBanner` forced — every other
    /// field passed through unchanged from the real `ModalContent.make(for:)` mapping.
    static func registerStandardFamily(on renderer: EmbeddedModalRenderer) {
        renderer.register(AlertDialog.self) { [weak renderer] descriptor, _ in
            (renderer?.properties(for: descriptor.style), withSubstitutedBanner(for: descriptor))
        }
    }

    private static func withSubstitutedBanner<D: StandardAlertContent>(for descriptor: D) -> ModalContent {
        let content = ModalContent.make(for: descriptor)
        guard descriptor.image != nil, !content.hasBanner else { return content }
        return ModalContent(
            closeOnTapOverlay: content.closeOnTapOverlay,
            hasBanner: true,
            title: content.title,
            hasAttributedTitle: content.hasAttributedTitle,
            subtitle: content.subtitle,
            hasAttributedSubtitle: content.hasAttributedSubtitle,
            hasSubtitleCustomView: content.hasSubtitleCustomView,
            primaryAction: content.primaryAction,
            secondaryAction: content.secondaryAction,
            showCloseButton: content.showCloseButton,
            dismissOnAction: content.dismissOnAction
        )
    }

    // MARK: - THE MANIFEST GATE, for this renderer

    /// Same claim `ShapeCoverageTests.test_manifest_coversAllTwentySixCatalogShapes` makes for
    /// `SwiftUIModalRenderer`: every one of the 26 real shapes presents on `EmbeddedModalRenderer`
    /// and has something to draw. `GenieShapeCatalog.names`/`.shapes` are the SAME 26 definitions —
    /// under-delivery there (a dropped shape) already fails that test; this proves the SAME set also
    /// works on the UIKit-free renderer, not a re-count of the manifest itself.
    func test_allTwentySixShapes_presentOnEmbeddedModalRenderer_withABodyToDraw() {
        let renderer = Self.makeRenderer()
        var failures: [String] = []

        for shape in GenieShapeCatalog.shapes {
            let id = ModalID()
            shape.present(renderer, id)

            guard let presentation = renderer.presentations.first(where: { $0.id == id }) else {
                failures.append("\(shape.name): did not present at all")
                continue
            }
            guard presentation.customContent != nil || presentation.content != nil else {
                failures.append("\(shape.name): presented but has no body to draw")
                continue
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "shapes with no coverage on EmbeddedModalRenderer:\n" + failures.joined(separator: "\n")
        )
        XCTAssertEqual(renderer.presentations.count, GenieShapeCatalog.names.count)
    }

    /// The banner-substitution deviation, pinned the same way `ShapeCoverageTests
    /// .test_bannerSubstitution_isTheOnlyDeviationFromProduction` pins it for the other renderer:
    /// a shape that NAMES a banner asset must show one on this renderer too.
    func test_bannerNamingShapes_showBanner_viaTheSubstitution() throws {
        let renderer = Self.makeRenderer()
        let bannerShapeNames = [
            "database-error-banner", "force-update-banner", "worksheet-abused-cap-banner",
            "streak-popup-banner", "quiz-info-banner", "quiz-begin-banner", "ai-notes-ready-banner",
            "onboarding-trial-banner", "exit-worksheet-confirm-banner",
            "worksheet-ready-timer-banner", "worksheet-timeup-timer-banner"
        ]

        for name in bannerShapeNames {
            let shape = try XCTUnwrap(GenieShapeCatalog.shape(named: name))
            let id = ModalID()
            shape.present(renderer, id)
            let presentation = try XCTUnwrap(renderer.presentations.first(where: { $0.id == id }))
            XCTAssertTrue(presentation.holder.hasBanner, "\(name): banner substitution did not apply")
        }
    }
}
