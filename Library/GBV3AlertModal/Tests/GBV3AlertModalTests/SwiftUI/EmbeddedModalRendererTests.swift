import UIKit
import XCTest
@testable import GBV3AlertModal

/// `EmbeddedModalRenderer`'s own contract — present/dismiss/update/setHidden, style fallback, and
/// the resolve-once gate — the UIKit-free renderer's counterpart of `SwiftUIModalRendererTests`.
/// Only the standard family is registered in this increment (see the type's own doc), so this file
/// covers that surface only; consumer-descriptor/bespoke coverage is a later increment's test file.
@MainActor
final class EmbeddedModalRendererTests: XCTestCase {

    private func makeRenderer(
        properties: ModalProperties = GeniePresets.standardModalProperties()
    ) -> EmbeddedModalRenderer {
        EmbeddedModalRenderer(alertProperties: properties)
    }

    private func alert(secondary: String? = nil) -> AlertDialog {
        AlertDialog(title: "T", subtitle: "S", primary: "OK", secondary: secondary)
    }

    // MARK: - present

    func test_present_addsAPresentation() {
        let renderer = makeRenderer()
        let id = ModalID()

        renderer.present(alert(), id: id, resolve: { _ in })

        XCTAssertEqual(renderer.presentations.count, 1)
        XCTAssertEqual(renderer.presentations.first?.id, id)
        XCTAssertNotNil(renderer.live[id])
        XCTAssertEqual(renderer.presentations.first?.content?.primary, "OK")
    }

    func test_present_resolvesStructureViaSharedResolver() throws {
        let renderer = makeRenderer()

        renderer.present(alert(secondary: "No"), id: ModalID(), resolve: { _ in })

        let resolved = try XCTUnwrap(renderer.presentations.first?.resolved)
        XCTAssertTrue(resolved.showsTitle)
        XCTAssertTrue(resolved.showsPrimary)
        XCTAssertTrue(resolved.showsSecondary)
        XCTAssertEqual(resolved.subtitle, .plain("S"))
    }

    /// The UIKit-free counterpart of `SwiftUIModalRendererTests
    /// .test_present_usesCallerProperties_notASentinel`: an empty `ModalProperties` (no action
    /// styles) must make `showsPrimary`/`showsSecondary` FALSE, proving the renderer resolves
    /// against the CALLER's properties, not a sentinel.
    func test_present_usesCallerProperties_notASentinel() throws {
        let renderer = makeRenderer(properties: ModalProperties())

        renderer.present(alert(secondary: "No"), id: ModalID(), resolve: { _ in })

        let resolved = try XCTUnwrap(renderer.presentations.first).resolved
        XCTAssertFalse(resolved.showsPrimary)
        XCTAssertFalse(resolved.showsSecondary)
    }

    func test_present_derivesTokensFromRealProperties() throws {
        let renderer = makeRenderer()

        renderer.present(alert(), id: ModalID(), resolve: { _ in })

        let tokens = try XCTUnwrap(renderer.presentations.first).tokens
        XCTAssertEqual(tokens.contentMaxWidth, 256)
        XCTAssertNotEqual(ModalTokens.standard.contentMaxWidth, 256) // guards the test's premise
    }

    func test_popupDialog_routesThroughItsOwnRegistration() throws {
        let renderer = EmbeddedModalRenderer(
            alertProperties: GeniePresets.standardModalProperties(),
            popupProperties: GeniePresets.popupModalProperties()
        )
        var result: AlertDialog.Result?

        renderer.present(
            PopupDialog(title: "T", subtitle: "S", primary: "OK"),
            id: ModalID(),
            resolve: { result = $0 }
        )
        try XCTUnwrap(renderer.presentations.first).onAction(.primary)

        XCTAssertEqual(result, .primary)
    }

    // MARK: - dismiss / teardown

    func test_dismiss_resolvesDismissed_andRemovesPresentation() {
        let renderer = makeRenderer()
        let id = ModalID()
        var result: AlertDialog.Result?

        renderer.present(alert(), id: id, resolve: { result = $0 })
        renderer.dismiss(id)

        XCTAssertEqual(result, .dismissed)
        XCTAssertTrue(renderer.presentations.isEmpty)
        XCTAssertNil(renderer.live[id])
    }

    // MARK: - action routing / resolve-once

    /// THE resolve-once test, same shape as `SwiftUIModalRendererTests.test_interaction_
    /// resolvesExactlyOnce`: `onAction` captured BEFORE the first interaction so the second call is
    /// a genuinely stale handle, exactly what a SwiftUI view holds after teardown — the "double-
    /// resolve race" the gate exists to close.
    func test_interaction_resolvesExactlyOnce() throws {
        let renderer = makeRenderer()
        let id = ModalID()
        var received: [AlertDialog.Result] = []

        renderer.present(alert(secondary: "No"), id: id, resolve: { received.append($0) })
        let onAction = try XCTUnwrap(renderer.presentations.first).onAction

        onAction(.primary)      // resolves + tears down
        onAction(.secondary)    // stale handle — must be inert
        renderer.dismiss(id)    // gate already fired — must be inert

        XCTAssertEqual(received, [.primary], "the resolve gate must fire exactly once")
        XCTAssertTrue(renderer.presentations.isEmpty)
    }

    func test_actionRouting_mapsEveryActionType() throws {
        for (action, expected) in [
            (GBAlertModal.ActionType.primary, AlertDialog.Result.primary),
            (GBAlertModal.ActionType.secondary, AlertDialog.Result.secondary),
            (GBAlertModal.ActionType.close, AlertDialog.Result.dismissed)
        ] {
            let renderer = makeRenderer()
            var result: AlertDialog.Result?

            renderer.present(alert(secondary: "No"), id: ModalID(), resolve: { result = $0 })
            try XCTUnwrap(renderer.presentations.first).onAction(action)

            XCTAssertEqual(result, expected)
        }
    }

    // MARK: - unregistered descriptors

    func test_unregisteredDescriptor_resolvesDismissed() {
        struct Unknown: ModalDescriptor {
            typealias Result = AlertDialog.Result
            static var dismissedResult: Result { .dismissed }
        }
        let renderer = makeRenderer()
        var result: AlertDialog.Result?
        var loggedType: Any.Type?
        renderer.onUnregisteredDescriptor = { loggedType = $0 }

        renderer.present(Unknown(), id: ModalID(), resolve: { result = $0 })

        XCTAssertEqual(result, .dismissed)
        XCTAssertTrue(renderer.presentations.isEmpty)
        XCTAssertTrue(loggedType == Unknown.self)
    }

    // MARK: - setHidden / update

    func test_setHidden_togglesVisibility_withoutResolving() throws {
        let renderer = makeRenderer()
        let id = ModalID()
        var resolvedCount = 0

        renderer.present(alert(), id: id, resolve: { _ in resolvedCount += 1 })
        renderer.setHidden(id, true)

        let hidden = try XCTUnwrap(renderer.presentations.first)
        XCTAssertTrue(hidden.isHidden)
        XCTAssertEqual(renderer.presentations.count, 1, "hiding must not tear the modal down")
        XCTAssertEqual(resolvedCount, 0)

        renderer.setHidden(id, false)
        let shown = try XCTUnwrap(renderer.presentations.first)
        XCTAssertFalse(shown.isHidden)
    }

    func test_update_rebuildsInPlace_preservingIdentityAndHiddenState() throws {
        let renderer = makeRenderer()
        let id = ModalID()
        var resolvedCount = 0

        renderer.present(alert(), id: id, resolve: { _ in resolvedCount += 1 })
        renderer.setHidden(id, true)
        renderer.update(id, to: AlertDialog(title: "T2", subtitle: "S2", primary: "Go", secondary: "No"))

        let presentation = try XCTUnwrap(renderer.presentations.first)
        XCTAssertEqual(renderer.presentations.count, 1)
        XCTAssertEqual(presentation.id, id)
        XCTAssertTrue(presentation.isHidden)
        XCTAssertEqual(presentation.resolved.subtitle, .plain("S2"))
        XCTAssertTrue(presentation.resolved.showsSecondary)
        XCTAssertEqual(presentation.content?.primary, "Go")
        XCTAssertEqual(resolvedCount, 0, "update must never resolve the token")
    }

    // MARK: - style fallback

    func test_unregisteredStyle_fallsBackToStandard() {
        let renderer = makeRenderer()
        XCTAssertFalse(renderer.isRegistered(style: .popup))
        XCTAssertEqual(
            renderer.properties(for: .popup)?.contentProperty?.maxWidthPortrait,
            renderer.properties(for: .standard)?.contentProperty?.maxWidthPortrait
        )
    }

    func test_registeringAStyle_makesItDistinctFromStandard() {
        let renderer = makeRenderer()
        renderer.register(style: .popup, properties: GeniePresets.popupModalProperties())

        XCTAssertTrue(renderer.isRegistered(style: .popup))
        XCTAssertNotEqual(
            renderer.properties(for: .popup)?.space?.banner,
            renderer.properties(for: .standard)?.space?.banner
        )
    }
}
