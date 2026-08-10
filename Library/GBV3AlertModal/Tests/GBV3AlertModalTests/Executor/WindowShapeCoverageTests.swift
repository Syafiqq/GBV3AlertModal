import SwiftUI
import XCTest
@testable import GBV3AlertModal

/// **The rootRenderer half of the same acceptance gate `EmbeddedShapeCoverageTests` sets for
/// mainUIRenderer — "all 26 real shapes also available", now for `WindowModalRenderer` too.**
///
/// Reuses `GenieShapeCatalog.shapes` VERBATIM (`Shape.present` is `any ModalRenderer`-typed
/// precisely so both renderer coverage tests can share the 26 definitions). Only the RENDERER SETUP
/// is new — same 17 catalog `ModalProperties` presets and banner-substitution trick
/// `EmbeddedShapeCoverageTests` already established, retargeted at `WindowModalRenderer`, which
/// additionally needs a real `UIWindow` (it installs `UIHostingController`s directly into one,
/// unlike `EmbeddedModalRenderer`'s caller-embedded `@Published` array) — same `windowProvider`
/// fixture pattern `RendererFixtures.swift`'s `.window` case already uses.
///
/// Same bar as the Embedded gate, not a repeat of per-shape structural assertions: every shape
/// presents and has SOMETHING installed in the window to draw.
@MainActor
final class WindowShapeCoverageTests: XCTestCase {

    // MARK: - Renderer setup — the WindowModalRenderer equivalent of EmbeddedShapeCoverageTests.makeRenderer()

    /// A real, key `UIWindow` — `WindowModalRenderer` installs hosting controllers directly into it,
    /// so a stub/zero-frame window would still work structurally, but a real one matches every other
    /// `.window`-backed fixture in this test target (`RendererFixtures.swift`).
    static func makeWindow() -> UIWindow {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        return window
    }

    static func makeRenderer(window: UIWindow) -> WindowModalRenderer {
        let renderer = WindowModalRenderer(
            alertProperties: GeniePresets.standardModalProperties(),
            popupProperties: GeniePresets.popupModalProperties(),
            windowProvider: { window }
        )
        for (style, properties) in EmbeddedShapeCoverageTests.stylePresets {
            renderer.register(style: style, properties: properties)
        }
        registerStandardFamily(on: renderer)
        renderer.registerBuiltInDescriptors()
        return renderer
    }

    /// Same deviation `EmbeddedShapeCoverageTests.registerStandardFamily` documents: this test
    /// bundle owns no main-bundle assets, so every named banner resolves nil unless substituted.
    static func registerStandardFamily(on renderer: WindowModalRenderer) {
        renderer.register(AlertDialog.self) { [weak renderer] descriptor, _ in
            (renderer?.properties(for: descriptor.style), withSubstitutedBanner(for: descriptor))
        }
        renderer.register(PopupDialog.self) { [weak renderer] descriptor, _ in
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

    /// Every one of the 26 real shapes presents on `WindowModalRenderer` and actually installs a
    /// hosting controller into the window — the `.window` backend's structural equivalent of "has a
    /// body to draw" (there is no `Presentation.customContent`/`.content` here; `Live
    /// .hostingController` is the one signal that something was drawn — see `present`'s own doc on
    /// the "routable, no body" outcome this would otherwise be indistinguishable from).
    func test_allTwentySixShapes_presentOnWindowModalRenderer_withABodyToDraw() {
        let window = Self.makeWindow()
        let renderer = Self.makeRenderer(window: window)
        var failures: [String] = []

        for shape in GenieShapeCatalog.shapes {
            let id = ModalID()
            shape.present(renderer, id)

            guard let live = renderer.live[id] else {
                failures.append("\(shape.name): did not present at all")
                continue
            }
            guard live.hostingController != nil else {
                failures.append("\(shape.name): presented but installed nothing in the window")
                continue
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "shapes with no coverage on WindowModalRenderer:\n" + failures.joined(separator: "\n")
        )
        XCTAssertEqual(renderer.live.count, GenieShapeCatalog.names.count)
    }

    /// The banner-substitution deviation, pinned the same way the Embedded gate pins it: a shape
    /// that NAMES a banner asset resolves `hasBanner` on this renderer too.
    func test_bannerNamingShapes_showBanner_viaTheSubstitution() throws {
        let window = Self.makeWindow()
        let renderer = Self.makeRenderer(window: window)
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
            let live = try XCTUnwrap(renderer.live[id])
            XCTAssertTrue(live.resolved.showsBanner, "\(name): banner substitution did not apply")
        }
    }
}
