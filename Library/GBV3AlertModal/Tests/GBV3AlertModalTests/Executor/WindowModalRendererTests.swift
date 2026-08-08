import UIKit
import XCTest
@testable import GBV3AlertModal

/// `WindowModalRenderer`'s own contract — the SwiftUI-native, UIKit-free counterpart of
/// `UIKitModalRendererTests`, same shape: real window, real install/teardown, resolve-once gate.
/// Only the standard family is registered in this increment (see the type's own doc).
@MainActor
final class WindowModalRendererTests: XCTestCase {

    private func makeWindow() -> UIWindow {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.makeKeyAndVisible()
        return w
    }

    private func makeRenderer(
        window: UIWindow, properties: ModalProperties = GeniePresets.standardModalProperties()
    ) -> WindowModalRenderer {
        WindowModalRenderer(alertProperties: properties, windowProvider: { window })
    }

    // MARK: - present / window installation

    func test_present_addsHostedContentToWindow() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()
        let before = window.subviews.count

        renderer.present(AlertDialog(title: "T", primary: "OK"), id: id) { _ in }

        XCTAssertGreaterThan(window.subviews.count, before, "presenting must add a real view to the window")
        XCTAssertNotNil(renderer.live[id])
        XCTAssertNotNil(renderer.live[id]?.hostingController, "the standard family always projects content")
    }

    func test_present_noWindowAvailable_resolvesDismissed() {
        let renderer = WindowModalRenderer(
            alertProperties: GeniePresets.standardModalProperties(), windowProvider: { nil }
        )
        let id = ModalID()
        var received: AlertDialog.Result?

        renderer.present(AlertDialog(title: "T", primary: "OK"), id: id) { received = $0 }

        XCTAssertEqual(received, .dismissed)
        XCTAssertNil(renderer.live[id])
    }

    func test_popupDialog_routesThroughItsOwnRegistration() {
        let window = makeWindow()
        let renderer = WindowModalRenderer(
            alertProperties: GeniePresets.standardModalProperties(),
            popupProperties: GeniePresets.popupModalProperties(),
            windowProvider: { window }
        )
        var result: AlertDialog.Result?

        renderer.present(PopupDialog(title: "T", subtitle: "S", primary: "OK"), id: ModalID()) {
            result = $0
        }
        renderer.live.values.first?.route?(.primary)

        XCTAssertEqual(result, .primary)
    }

    // MARK: - dismiss / teardown

    func test_dismiss_resolvesDismissed_andClearsRegistry_immediately() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()
        var received: AlertDialog.Result?

        renderer.present(AlertDialog(title: "T", primary: "OK"), id: id) { received = $0 }
        renderer.dismiss(id)

        // Resolve + registry teardown are synchronous — the coordinator's `finish()` needs `live[id]`
        // gone right away to advance its queue, same contract `UIKitModalRenderer` gives. Only the
        // hosted VIEW's removal is animated (below), same C5 split `GBAlertModal.hide()` itself uses.
        XCTAssertEqual(received, .dismissed)
        XCTAssertNil(renderer.live[id])
    }

    /// C5 animation parity: `teardown` fades the hosted view out (`GBAlertModal.hide()`'s own
    /// duration/curve) before removing it — mirrors `LayerB_WiringTests
    /// .test_hide_removesFromSuperviewAfterAnimation` exactly, since this renderer reuses that same
    /// `UIView.animate` call.
    func test_dismiss_removesHostedViewFromWindowAfterAnimation() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()
        let before = window.subviews.count

        renderer.present(AlertDialog(title: "T", primary: "OK"), id: id) { _ in }
        XCTAssertGreaterThan(window.subviews.count, before)

        renderer.dismiss(id)
        XCTAssertGreaterThan(
            window.subviews.count, before, "the view must still be fading, not yet removed"
        )

        let expectation = expectation(description: "dismiss removes the hosted view after its fade")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(window.subviews.count, before, "dismiss must remove the hosted view from the window")
    }

    // MARK: - action routing / resolve-once

    func test_userAction_resolvesMappedResult_once() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()
        var received: [AlertDialog.Result] = []

        renderer.present(AlertDialog(title: "T", primary: "OK", secondary: "No"), id: id) {
            received.append($0)
        }
        let route = renderer.live[id]?.route
        route?(.primary)   // resolves + tears down
        route?(.secondary) // stale handle — must be inert

        XCTAssertEqual(received, [.primary], "the resolve gate must fire exactly once")
        XCTAssertNil(renderer.live[id])
    }

    func test_actionRouting_mapsEveryActionType() {
        for (action, expected) in [
            (GBAlertModal.ActionType.primary, AlertDialog.Result.primary),
            (GBAlertModal.ActionType.secondary, AlertDialog.Result.secondary),
            (GBAlertModal.ActionType.close, AlertDialog.Result.dismissed)
        ] {
            let window = makeWindow()
            let renderer = makeRenderer(window: window)
            let id = ModalID()
            var result: AlertDialog.Result?

            renderer.present(AlertDialog(title: "T", primary: "OK", secondary: "No"), id: id) {
                result = $0
            }
            renderer.live[id]?.route?(action)

            XCTAssertEqual(result, expected)
        }
    }

    // MARK: - unregistered descriptors

    func test_unregisteredDescriptor_resolvesDismissed() {
        struct Unknown: ModalDescriptor {
            typealias Result = AlertDialog.Result
            static var dismissedResult: Result { .dismissed }
        }
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()
        var received: AlertDialog.Result?
        let before = window.subviews.count

        renderer.present(Unknown(), id: id) { received = $0 }

        XCTAssertEqual(received, .dismissed)
        XCTAssertNil(renderer.live[id])
        XCTAssertEqual(window.subviews.count, before, "an unregistered descriptor must install nothing")
    }

    /// **The gap the design doc flags explicitly**: a descriptor registered via `register(_:factory:)`
    /// alone (no content projection — there's no `register(_:view:)` on this renderer) must stay
    /// LIVE and ROUTABLE, not resolve immediately as if unregistered. Installs nothing in the window.
    func test_descriptorWithNoContentProjection_staysLiveAndRoutable_installsNothing() {
        struct Custom: ModalDescriptor {
            enum Result: Sendable, Equatable { case done, dismissed }
            static var dismissedResult: Result { .dismissed }
            var title: String
        }
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        renderer.register(Custom.self, route: { $0 == .primary ? .done : .dismissed }) { descriptor, _ in
            (nil, ModalContent())
        }
        let id = ModalID()
        var result: Custom.Result?
        let before = window.subviews.count

        renderer.present(Custom(title: "Step"), id: id) { result = $0 }

        XCTAssertNotNil(renderer.live[id], "a routable-but-invisible descriptor must still be live")
        XCTAssertEqual(window.subviews.count, before, "no content projection means nothing installs")

        renderer.live[id]?.route?(.primary)
        XCTAssertEqual(result, .done, "still routable despite having nothing to draw")
    }

    // MARK: - setHidden / update

    func test_setHidden_togglesVisibility_withoutResolving() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()
        var resolvedCount = 0

        renderer.present(AlertDialog(title: "T", primary: "OK"), id: id) { _ in resolvedCount += 1 }
        renderer.setHidden(id, true)

        XCTAssertEqual(renderer.live[id]?.hostingController?.view.isHidden, true)
        XCTAssertEqual(resolvedCount, 0)

        renderer.setHidden(id, false)
        XCTAssertEqual(renderer.live[id]?.hostingController?.view.isHidden, false)
    }

    func test_update_rebuildsInPlace_preservingIdentity() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()
        var resolvedCount = 0

        renderer.present(AlertDialog(title: "T", primary: "OK"), id: id) { _ in resolvedCount += 1 }
        let before = window.subviews.count
        renderer.update(id, to: AlertDialog(title: "T2", subtitle: "S2", primary: "Go", secondary: "No"))

        XCTAssertNotNil(renderer.live[id], "update must not tear down the presentation")
        XCTAssertEqual(window.subviews.count, before, "update must rebuild in place, not add a second view")
        XCTAssertEqual(resolvedCount, 0, "update must never resolve the token")
    }

    // MARK: - style fallback

    func test_unregisteredStyle_fallsBackToStandard() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        XCTAssertFalse(renderer.isRegistered(style: .popup))
        XCTAssertEqual(
            renderer.properties(for: .popup)?.contentProperty?.maxWidthPortrait,
            renderer.properties(for: .standard)?.contentProperty?.maxWidthPortrait
        )
    }

    func test_registeringAStyle_makesItDistinctFromStandard() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        renderer.register(style: .popup, properties: GeniePresets.popupModalProperties())

        XCTAssertTrue(renderer.isRegistered(style: .popup))
        XCTAssertNotEqual(
            renderer.properties(for: .popup)?.space?.banner,
            renderer.properties(for: .standard)?.space?.banner
        )
    }

    // MARK: - registerBuiltInDescriptors() — the 5 bespoke kinds

    /// Real content installs (a real view in the window) for every bespoke kind once opted in — same
    /// coverage `EmbeddedModalRendererTests` runs for `EmbeddedModalRenderer`.
    func test_registerBuiltInDescriptors_installsRealContent_forEveryBespokeKind() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        renderer.registerBuiltInDescriptors()
        let before = window.subviews.count

        renderer.present(
            TextInputDialog(title: "Rename", primary: "Save"), id: ModalID(), resolve: { _ in }
        )
        renderer.present(
            DatePickerDialog(initialDate: Date(), primary: "OK"), id: ModalID(), resolve: { _ in }
        )
        renderer.present(BadgeDialog(primary: "OK"), id: ModalID(), resolve: { _ in })
        renderer.present(LoadingDialog(primary: "OK"), id: ModalID(), resolve: { _ in })
        renderer.present(
            SatisfactionDialog(
                options: [.init(id: "1", symbolName: "face.smiling", label: "Good")], primary: "Submit"
            ),
            id: ModalID(), resolve: { _ in }
        )

        XCTAssertEqual(window.subviews.count, before + 5, "each bespoke kind must install a real view")
        XCTAssertEqual(renderer.live.count, 5)
    }

    /// Without opting in, the bespoke kinds stay exactly as unregistered as any unknown descriptor.
    func test_withoutRegisterBuiltInDescriptors_bespokeKindsStayUnregistered() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        var result: BadgeDialog.Result?
        let before = window.subviews.count

        renderer.present(BadgeDialog(primary: "OK"), id: ModalID()) { result = $0 }

        XCTAssertEqual(result, .dismissed)
        XCTAssertTrue(renderer.live.isEmpty)
        XCTAssertEqual(window.subviews.count, before)
    }

    /// The registered view resolves through this renderer's SAME teardown funnel `dismiss(_:)`
    /// exercises everywhere else — proves the real `TextInputModalView` (not a test stand-in)
    /// participates correctly, without needing to host it and simulate typing (its own behavior is
    /// unchanged and tested elsewhere).
    func test_textInputBespokeKind_resolvesThroughItsOwnView() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        renderer.registerBuiltInDescriptors()
        var result: TextInputDialog.Result?
        let id = ModalID()

        renderer.present(
            TextInputDialog(title: "Rename", initialText: "Old", primary: "Save"),
            id: id, resolve: { result = $0 }
        )
        renderer.dismiss(id)

        // Resolve + registry teardown are synchronous (see `test_dismiss_resolvesDismissed_
        // andClearsRegistry_immediately`); the hosted view's removal is animated (C5) and is covered
        // by `test_dismiss_removesHostedViewFromWindowAfterAnimation` — not re-asserted here.
        XCTAssertEqual(result, .dismissed)
        XCTAssertTrue(renderer.live.isEmpty)
    }
}
