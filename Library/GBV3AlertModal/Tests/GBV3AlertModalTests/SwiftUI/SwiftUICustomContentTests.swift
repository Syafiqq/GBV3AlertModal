import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// W3: the custom-content seam on the SwiftUI backend — `SwiftUIModalRenderer.register(_:view:)`.
///
/// It closes two gaps the C-2 parity gate surfaced, which were really one gap:
///
/// * **E2 — nothing to draw.** The renderer could only project a descriptor down to `AlertDialog`,
///   which has no input field and no bespoke body, so a custom descriptor rendered nothing.
/// * **E1 — nothing to carry.** `route` is `(ActionType) -> D.Result`, registered BEFORE
///   presentation, so it structurally could not carry a value read at interaction time.
///   `TextInputDialog.Result.submitted(String)` was unreachable.
///
/// The registered view is handed the renderer's resolve GATE, so it resolves with a value it holds
/// at tap time — exactly what `UIKitModalRenderer.TextInputHolder` does when it reads `field.text`
/// inside `holder.completion`. These tests drive that gate directly rather than hosting a SwiftUI
/// view and simulating typing: the seam is the renderer plumbing, and the plumbing is what has to
/// carry an arbitrary `D.Result` from inside the view all the way to the token.
@MainActor
final class SwiftUICustomContentTests: XCTestCase {

    private func makeRenderer(
        properties: GBAlertModal.Properties = GeniePresets.standardProperties()
    ) -> SwiftUIModalRenderer {
        SwiftUIModalRenderer(alertProperties: properties)
    }

    private func textInput() -> TextInputDialog {
        TextInputDialog(
            title: "Rename", placeholder: "Name", initialText: "Old",
            primary: "Save", secondary: "Cancel"
        )
    }

    // MARK: - E1: a value read at interaction time reaches the token

    /// THE gap-closing test. The registered view captures the resolve gate and later calls it with
    /// a `String` only the view could know — the stand-in for `@State` text a `TextField` owns.
    /// No `(ActionType) -> Result` route could produce this value.
    func test_registeredView_carriesSubmittedText_toTheToken() throws {
        let renderer = makeRenderer()
        var submit: ((TextInputDialog.Result) -> Void)?
        renderer.register(TextInputDialog.self, view: { _, resolve in
            submit = resolve
            return AnyView(EmptyView())
        })
        var result: TextInputDialog.Result?
        let id = ModalID()

        renderer.present(textInput(), id: id, resolve: { result = $0 })
        try XCTUnwrap(submit)(.submitted("New name"))

        XCTAssertEqual(result, .submitted("New name"), "the typed value must reach the token")
        XCTAssertTrue(renderer.presentations.isEmpty, "resolving must tear the presentation down")
        XCTAssertNil(renderer.live[id], "and clear the live entry, through the one teardown funnel")
    }

    /// The same round-trip for the other input descriptor, whose payload is a `Date` rather than a
    /// `String` — so this is testing the generic seam, not a `String`-shaped coincidence.
    func test_registeredView_carriesSubmittedDate_toTheToken() throws {
        let renderer = makeRenderer()
        var submit: ((DatePickerDialog.Result) -> Void)?
        renderer.register(DatePickerDialog.self, view: { _, resolve in
            submit = resolve
            return AnyView(EmptyView())
        })
        var result: DatePickerDialog.Result?
        let picked = Date(timeIntervalSince1970: 2_000_000)

        renderer.present(
            DatePickerDialog(title: "Pick a date",
                             initialDate: Date(timeIntervalSince1970: 1_000_000),
                             primary: "OK"),
            id: ModalID(),
            resolve: { result = $0 }
        )
        try XCTUnwrap(submit)(.submitted(picked))

        XCTAssertEqual(result, .submitted(picked))
        XCTAssertTrue(renderer.presentations.isEmpty)
    }

    /// The view's gate is the SAME resolve-once gate every other path funnels through: a second
    /// submit, and a `dismiss` after it, are both inert. Without this a view holding a stale
    /// `resolve` (SwiftUI keeps view values around across teardown) could resolve a dead token.
    func test_registeredView_gateResolvesExactlyOnce() throws {
        let renderer = makeRenderer()
        var submit: ((TextInputDialog.Result) -> Void)?
        renderer.register(TextInputDialog.self, view: { _, resolve in
            submit = resolve
            return AnyView(EmptyView())
        })
        var received: [TextInputDialog.Result] = []
        let id = ModalID()

        renderer.present(textInput(), id: id, resolve: { received.append($0) })
        let gate = try XCTUnwrap(submit)
        gate(.submitted("first"))
        gate(.submitted("second"))   // stale handle — must be inert
        renderer.dismiss(id)         // gate already fired — must be inert

        XCTAssertEqual(received, [.submitted("first")])
    }

    // MARK: - E2: the descriptor now has a body to draw

    /// The library's own `TextInputDialog` content, registered exactly the way
    /// `InputDialogTests` registers the UIKit holder. `ModalHost` draws `customContent`, so a
    /// non-nil value here IS "this descriptor renders on the SwiftUI backend".
    func test_libraryTextInputView_isInstalledAsTheBody() throws {
        let renderer = makeRenderer()
        let properties = GeniePresets.standardProperties()
        renderer.register(TextInputDialog.self) { _, _ in
            (properties, GBAlertModal.DataHolder())
        }
        renderer.register(TextInputDialog.self, view: { descriptor, resolve in
            SwiftUIModalRenderer.TextInputContent.make(
                for: descriptor, tokens: ModalTokens(from: properties), resolve: resolve
            )
        })

        renderer.present(textInput(), id: ModalID(), resolve: { _ in })

        let presentation = try XCTUnwrap(renderer.presentations.first)
        XCTAssertNotNil(presentation.customContent, "the registered view is what ModalHost draws")
        XCTAssertNil(presentation.content, "a custom descriptor projects no AlertDialog")
        XCTAssertEqual(
            presentation.tokens.cardMaxWidth, 256,
            "the factory's real Properties still drive the presentation's tokens"
        )
    }

    func test_libraryDatePickerView_isInstalledAsTheBody() throws {
        let renderer = makeRenderer()
        renderer.register(DatePickerDialog.self, view: { descriptor, resolve in
            SwiftUIModalRenderer.DatePickerContent.make(for: descriptor, resolve: resolve)
        })

        renderer.present(
            DatePickerDialog(initialDate: Date(timeIntervalSince1970: 0), primary: "OK"),
            id: ModalID(),
            resolve: { _ in }
        )

        XCTAssertNotNil(try XCTUnwrap(renderer.presentations.first).customContent)
    }

    /// A view registration alone is enough to present: `register(_:view:)` installs a neutral
    /// factory when none exists, so the seam does not force a two-call registration ritual. The
    /// fallback is visible in the tokens (`.standard`'s uncapped width, not the preset's 256).
    func test_registeringViewOnly_presentsWithFallbackProperties() throws {
        let renderer = makeRenderer()
        renderer.register(TextInputDialog.self, view: { descriptor, resolve in
            SwiftUIModalRenderer.TextInputContent.make(for: descriptor, resolve: resolve)
        })

        renderer.present(textInput(), id: ModalID(), resolve: { _ in })

        let presentation = try XCTUnwrap(renderer.presentations.first)
        XCTAssertNotNil(presentation.customContent)
        XCTAssertEqual(presentation.tokens.cardMaxWidth, ModalTokens.standard.cardMaxWidth)
    }

    /// Regression guard on the branch `ModalHost` takes: a descriptor with only a factory (or only
    /// a factory + route) still has NO body, and must not pretend otherwise.
    func test_factoryOnlyRegistration_hasNoCustomContent() throws {
        let renderer = makeRenderer()
        renderer.register(
            TextInputDialog.self,
            route: { _ in TextInputDialog.Result.dismissed }
        ) { _, _ in
            (GeniePresets.standardProperties(), GBAlertModal.DataHolder())
        }

        renderer.present(textInput(), id: ModalID(), resolve: { _ in })

        let presentation = try XCTUnwrap(renderer.presentations.first)
        XCTAssertNil(presentation.customContent)
        XCTAssertNil(presentation.content)
    }

    // MARK: - the four registration handles are independent

    /// `register(_:factory:)` must not clobber a previously registered view — the same
    /// carry-forward rule that already protects `route` and `content`. Registering the standard
    /// `AlertDialog` exercises all four handles at once.
    func test_factoryReRegistration_preservesTheRegisteredView() throws {
        let renderer = makeRenderer()
        renderer.register(AlertDialog.self, view: { _, _ in AnyView(EmptyView()) })
        renderer.register(AlertDialog.self) { descriptor, resolve in
            (
                GeniePresets.popupProperties(),
                UIKitModalRenderer.AlertHolder.make(for: descriptor, resolve: resolve)
            )
        }
        var result: AlertDialog.Result?

        renderer.present(
            AlertDialog(title: "T", subtitle: "S", primary: "OK", secondary: "No"),
            id: ModalID(),
            resolve: { result = $0 }
        )

        let presentation = try XCTUnwrap(renderer.presentations.first)
        XCTAssertNotNil(presentation.customContent, "the view must survive a factory re-registration")
        XCTAssertNotNil(presentation.content, "so must the standard content projection")
        presentation.onAction(.primary)
        XCTAssertEqual(result, .primary, "and so must the router")
    }

    /// The mirror image: `register(_:view:)` must not clobber the factory, route or content that
    /// were already there. `gapBelowSubtitle` is 24 under `popupProperties()` and 16 under
    /// `standardProperties()`, so it proves the EARLIER factory's `Properties` are still in play.
    func test_viewRegistration_preservesFactoryRouteAndContent() throws {
        let renderer = makeRenderer()
        renderer.register(AlertDialog.self) { descriptor, resolve in
            (
                GeniePresets.popupProperties(),
                UIKitModalRenderer.AlertHolder.make(for: descriptor, resolve: resolve)
            )
        }
        renderer.register(AlertDialog.self, view: { _, _ in AnyView(EmptyView()) })
        var result: AlertDialog.Result?

        renderer.present(
            AlertDialog(title: "T", subtitle: "S", primary: "OK", secondary: "No"),
            id: ModalID(),
            resolve: { result = $0 }
        )

        let presentation = try XCTUnwrap(renderer.presentations.first)
        XCTAssertEqual(presentation.tokens.gapBelowSubtitle, 24, "the factory must survive")
        XCTAssertNotNil(presentation.content, "the content projection must survive")
        XCTAssertNotNil(presentation.customContent)
        presentation.onAction(.secondary)
        XCTAssertEqual(result, .secondary, "the router must survive")
    }

    // MARK: - update / hide keep the body alive

    /// `update(_:to:)` rebuilds the body from the NEW descriptor (symmetrically with `content`) and
    /// must not resolve the token — the executor invariant the parity gate leans on.
    func test_update_rebuildsTheCustomBody_withoutResolving() throws {
        let renderer = makeRenderer()
        var built: [String] = []
        renderer.register(TextInputDialog.self, view: { descriptor, _ in
            built.append(descriptor.primary)
            return AnyView(EmptyView())
        })
        var resolvedCount = 0
        let id = ModalID()

        renderer.present(textInput(), id: id, resolve: { _ in resolvedCount += 1 })
        renderer.update(id, to: TextInputDialog(placeholder: "Name", primary: "Go"))

        XCTAssertEqual(built, ["Save", "Go"], "the body must be rebuilt from the new descriptor")
        XCTAssertEqual(renderer.presentations.count, 1, "update must not add a presentation")
        XCTAssertNotNil(try XCTUnwrap(renderer.presentations.first).customContent)
        XCTAssertEqual(resolvedCount, 0, "update must never resolve the token")
    }

    /// `setHidden` is visibility only — the presentation, and therefore the body owning the typed
    /// text, stays alive. (`ModalHost` renders `isHidden` with `.opacity`/`.allowsHitTesting`
    /// rather than an `if` for exactly this reason.)
    func test_setHidden_keepsTheCustomBodyAlive() throws {
        let renderer = makeRenderer()
        var buildCount = 0
        renderer.register(TextInputDialog.self, view: { _, _ in
            buildCount += 1
            return AnyView(EmptyView())
        })
        let id = ModalID()

        renderer.present(textInput(), id: id, resolve: { _ in })
        renderer.setHidden(id, true)

        let presentation = try XCTUnwrap(renderer.presentations.first)
        XCTAssertTrue(presentation.isHidden)
        XCTAssertNotNil(presentation.customContent)
        XCTAssertEqual(buildCount, 1, "hiding must not rebuild the body")
    }

    // MARK: - the views' own action mapping

    /// The input views resolve through a pure `(ActionType, value) -> Result` mapping kept out of
    /// the view body (the split `SwiftUIAlertModal.subtitlePayload` already uses), so it is
    /// assertable without hosting SwiftUI. It must stay byte-for-byte the switch
    /// `UIKitModalRenderer.TextInputHolder`/`DatePickerHolder` perform in `holder.completion` —
    /// that identity is what makes the two backends produce the same result for the same tap.
    func test_textInputView_mapsActionsLikeTheUIKitHolder() {
        XCTAssertEqual(
            TextInputModalView.result(for: .primary, text: "New name"), .submitted("New name")
        )
        XCTAssertEqual(TextInputModalView.result(for: .secondary, text: "New name"), .dismissed)
        XCTAssertEqual(TextInputModalView.result(for: .close, text: "New name"), .dismissed)
    }

    func test_datePickerView_mapsActionsLikeTheUIKitHolder() {
        let picked = Date(timeIntervalSince1970: 2_000_000)
        XCTAssertEqual(DatePickerModalView.result(for: .primary, date: picked), .submitted(picked))
        XCTAssertEqual(DatePickerModalView.result(for: .secondary, date: picked), .dismissed)
        XCTAssertEqual(DatePickerModalView.result(for: .close, date: picked), .dismissed)
    }

    /// End-to-end through the REAL library view rather than a stand-in: registering
    /// `TextInputContent` and driving its mapping produces the same `.submitted(text)` the gate
    /// carried in `test_registeredView_carriesSubmittedText_toTheToken`. This is the wiring
    /// `TextInputModalView.body` performs (`onPrimary: { resolve(Self.result(...)) }`), with the
    /// `@State` value supplied by the test instead of by a keyboard.
    func test_libraryTextInputView_submitsThroughTheGate() throws {
        let renderer = makeRenderer()
        var submit: ((TextInputDialog.Result) -> Void)?
        renderer.register(TextInputDialog.self, view: { descriptor, resolve in
            submit = resolve
            return SwiftUIModalRenderer.TextInputContent.make(for: descriptor, resolve: resolve)
        })
        var result: TextInputDialog.Result?

        renderer.present(textInput(), id: ModalID(), resolve: { result = $0 })
        try XCTUnwrap(submit)(TextInputModalView.result(for: .primary, text: "New name"))

        XCTAssertEqual(result, .submitted("New name"))
    }
}
