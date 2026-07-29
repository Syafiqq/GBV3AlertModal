import UIKit
import XCTest
@testable import GBV3AlertModal

/// W2a: `SwiftUIModalRenderer` is the second backend behind `ModalRenderer`. These tests pin the
/// renderer's own contract — present/dismiss/update/setHidden, resolve-once action routing, and the
/// threading of REAL `Properties` into the shared resolver. Task 8 then runs the renderer-agnostic
/// executor suite against both backends as the parity gate.
@MainActor
final class SwiftUIModalRendererTests: XCTestCase {

    /// `GeniePresets.standardProperties()`, not a bare `GBAlertModal.Properties()`: the shared
    /// resolver reports `showsPrimary`/`showsSecondary` only when the properties carry non-nil
    /// action STYLES (see `GBAlertModal+ResolvedModal.swift`). Same deliberate deviation from the
    /// plan's literal snippet that `SharedResolverTests` already documents — a bare `Properties()`
    /// would make the structure assertions below false for reasons unrelated to this renderer.
    private func makeRenderer(
        properties: GBAlertModal.Properties = GeniePresets.standardProperties()
    ) -> SwiftUIModalRenderer {
        SwiftUIModalRenderer(alertProperties: properties)
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
        // The standard-family content projection `ModalHost` draws from.
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

    // MARK: - real Properties reach the shared chain (the Task 4 gap, closed)

    /// The gap-closing evidence: `buttonAxis` is derived PURELY from
    /// `Properties.buttonActionOrientation`, so it can only come out `.horizontal` if the caller's
    /// real `Properties` reached `GBAlertModal.resolve` — a sentinel could never produce it.
    func test_present_threadsRealPropertiesIntoResolver_buttonAxis() throws {
        let horizontal = GeniePresets.standardProperties().copy(buttonActionOrientation: .horizontal)
        let renderer = makeRenderer(properties: horizontal)

        renderer.present(alert(secondary: "No"), id: ModalID(), resolve: { _ in })

        let resolved = try XCTUnwrap(renderer.presentations.first).resolved
        XCTAssertEqual(resolved.buttonAxis, .horizontal)
    }

    /// Control for the test above: the same renderer with the preset's own `.vertical` orientation
    /// resolves `.vertical`, so the assertion above is tracking the input and not a constant.
    func test_present_defaultPresetResolvesVerticalButtonAxis() throws {
        let renderer = makeRenderer()

        renderer.present(alert(secondary: "No"), id: ModalID(), resolve: { _ in })

        let resolved = try XCTUnwrap(renderer.presentations.first).resolved
        XCTAssertEqual(resolved.buttonAxis, .vertical)
    }

    /// The other half of the same proof, from the opposite direction: a `Properties` with NO action
    /// styles must make `showsSecondary` FALSE even though the dialog has a secondary action. The
    /// sentinel `SwiftUIAlertModal` falls back to always supplies styles, so a `true` here would
    /// mean the renderer was resolving against a sentinel rather than the caller's properties.
    func test_present_usesCallerProperties_notASentinel() throws {
        let renderer = makeRenderer(properties: GBAlertModal.Properties())

        renderer.present(alert(secondary: "No"), id: ModalID(), resolve: { _ in })

        let resolved = try XCTUnwrap(renderer.presentations.first).resolved
        XCTAssertFalse(resolved.showsPrimary)
        XCTAssertFalse(resolved.showsSecondary)
    }

    /// `ModalTokens` are derived per presentation from the SAME real `Properties`, not from
    /// `.standard` — `cardMaxWidth` comes from `contentProperty.maxWidthPortrait` (256 in the
    /// preset), whereas `.standard` ships `.infinity`.
    func test_present_derivesTokensFromRealProperties() throws {
        let renderer = makeRenderer()

        renderer.present(alert(), id: ModalID(), resolve: { _ in })

        let tokens = try XCTUnwrap(renderer.presentations.first).tokens
        XCTAssertEqual(tokens.cardMaxWidth, 256)
        XCTAssertNotEqual(ModalTokens.standard.cardMaxWidth, 256) // guards the test's premise
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

    // MARK: - action routing

    /// THE routing test. `onAction` is captured BEFORE the first interaction so the second call
    /// exercises a genuinely stale handle — exactly what a SwiftUI view holds after teardown.
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

    /// The full `ActionType -> AlertDialog.Result` mapping, which must stay identical to the switch
    /// `UIKitModalRenderer.AlertHolder.make` performs.
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

    /// `PopupDialog` is a DIFFERENT descriptor type registered with its own `Properties`, but shares
    /// `AlertDialog.Result` — the same-type constraint the router is built on. Proves the generic
    /// registration works for the whole standard family, not just `AlertDialog`.
    func test_popupDialog_routesThroughItsOwnRegistration() throws {
        let renderer = SwiftUIModalRenderer(
            alertProperties: GeniePresets.standardProperties(),
            popupProperties: GeniePresets.popupProperties()
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

    // MARK: - unregistered descriptors

    func test_unregisteredDescriptor_resolvesDismissed() {
        struct Unknown: ModalDescriptor {
            typealias Result = AlertDialog.Result
            static var dismissedResult: Result { .dismissed }
        }
        let renderer = makeRenderer()
        var result: AlertDialog.Result?

        renderer.present(Unknown(), id: ModalID(), resolve: { result = $0 })

        XCTAssertEqual(result, .dismissed)
        XCTAssertTrue(renderer.presentations.isEmpty)
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

        renderer.present(alert(), id: id, resolve: { _ in })
        renderer.setHidden(id, true)
        renderer.update(id, to: AlertDialog(title: "T2", subtitle: "S2", primary: "Go", secondary: "No"))

        let presentation = try XCTUnwrap(renderer.presentations.first)
        XCTAssertEqual(renderer.presentations.count, 1)
        XCTAssertEqual(presentation.id, id)
        XCTAssertTrue(presentation.isHidden)
        XCTAssertEqual(presentation.resolved.subtitle, .plain("S2"))
        XCTAssertTrue(presentation.resolved.showsSecondary)
        XCTAssertEqual(presentation.content?.primary, "Go")
    }
}
