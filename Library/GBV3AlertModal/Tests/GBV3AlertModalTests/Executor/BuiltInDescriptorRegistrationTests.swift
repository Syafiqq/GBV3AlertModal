import Foundation
import UIKit
import XCTest
@testable import GBV3AlertModal

/// A descriptor kind NOTHING registers, on either backend — the probe for the unregistered path.
private struct DiagnosticProbeDialog: ModalDescriptor {
    typealias Result = AlertDialog.Result
    static var dismissedResult: Result { .dismissed }
}

/// Two things that used to fail completely silently:
///
/// 1. An unregistered descriptor produced NO diagnostic anywhere in the library (the sole
///    `assertionFailure` was deleted for renderer parity, which was the right goal by the wrong
///    means). Both renderers now call `onUnregisteredDescriptor`, symmetrically, and neither traps.
/// 2. The library shipped five descriptors plus both halves of their wiring and registered NONE of
///    them, so a consumer had to hand-write ten registrations and a missed one yielded no modal, an
///    immediate `.dismissed`, and no trace. `registerBuiltInDescriptors()` is the opt-in wiring.
@MainActor
final class BuiltInDescriptorRegistrationTests: XCTestCase {

    private func makeUIKit() -> (UIKitModalRenderer, UIWindow) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        let renderer = UIKitModalRenderer(
            alertProperties: GeniePresets.standardProperties(),
            windowProvider: { window }
        )
        return (renderer, window)
    }

    private func makeSwiftUI() -> SwiftUIModalRenderer {
        SwiftUIModalRenderer(alertProperties: GeniePresets.standardProperties())
    }

    /// One of each of the five shipped descriptors, presented through the `ModalRenderer` protocol so
    /// the SAME calls drive both backends. Returns their ids in registration order.
    private func presentAllFive(on renderer: ModalRenderer) -> [ModalID] {
        let ids = (0..<5).map { _ in ModalID() }
        renderer.present(
            TextInputDialog(title: "Rename", placeholder: "Name", primary: "Save"),
            id: ids[0], resolve: { _ in }
        )
        renderer.present(
            DatePickerDialog(title: "Pick", initialDate: Date(timeIntervalSince1970: 0), primary: "OK"),
            id: ids[1], resolve: { _ in }
        )
        renderer.present(
            BadgeDialog(title: AttributedString("Badges"), primary: "View my badges"),
            id: ids[2], resolve: { _ in }
        )
        renderer.present(
            LoadingDialog(title: AttributedString("Generating"), primary: "Continue", secondary: "Cancel"),
            id: ids[3], resolve: { _ in }
        )
        renderer.present(
            SatisfactionDialog(
                title: AttributedString("How was it?"),
                options: [SatisfactionDialog.Option(id: "a", symbolName: "star.fill", label: "Good")],
                primary: "Send"
            ),
            id: ids[4], resolve: { _ in }
        )
        return ids
    }

    // MARK: - the diagnostic fires, symmetrically on both backends

    func test_unregisteredDescriptor_firesDiagnostic_onUIKitRenderer() {
        let (renderer, _) = makeUIKit()
        var reported: [String] = []
        renderer.onUnregisteredDescriptor = { reported.append(String(describing: $0)) }

        var result: AlertDialog.Result?
        renderer.present(DiagnosticProbeDialog(), id: ModalID(), resolve: { result = $0 })

        XCTAssertEqual(reported.count, 1, "an unregistered descriptor must be reported exactly once")
        XCTAssertTrue(
            reported.first?.contains("DiagnosticProbeDialog") == true,
            "the hook must name the offending descriptor type, got \(reported)"
        )
        XCTAssertEqual(result, .dismissed, "the graceful resolve is unchanged — the hook is purely additive")
        XCTAssertTrue(renderer.live.isEmpty, "and still nothing goes live")
    }

    func test_unregisteredDescriptor_firesDiagnostic_onSwiftUIRenderer() {
        let renderer = makeSwiftUI()
        var reported: [String] = []
        renderer.onUnregisteredDescriptor = { reported.append(String(describing: $0)) }

        var result: AlertDialog.Result?
        renderer.present(DiagnosticProbeDialog(), id: ModalID(), resolve: { result = $0 })

        XCTAssertEqual(reported.count, 1, "the SwiftUI backend must report it too — parity includes the diagnostic")
        XCTAssertTrue(
            reported.first?.contains("DiagnosticProbeDialog") == true,
            "the hook must name the offending descriptor type, got \(reported)"
        )
        XCTAssertEqual(result, .dismissed)
        XCTAssertTrue(renderer.presentations.isEmpty)
    }

    // MARK: - registerBuiltInDescriptors() makes the five shipped descriptors resolvable

    func test_registerBuiltInDescriptors_theFiveResolve_onUIKitRenderer() {
        let (renderer, _) = makeUIKit()
        var reported: [String] = []
        renderer.onUnregisteredDescriptor = { reported.append(String(describing: $0)) }

        renderer.registerBuiltInDescriptors()
        let ids = presentAllFive(on: renderer)

        XCTAssertEqual(reported, [], "after registerBuiltInDescriptors() none of the five may hit the unregistered path")
        XCTAssertEqual(
            ids.filter { renderer.live[$0] != nil }.count, 5,
            "all five shipped descriptors must go live on the UIKit backend"
        )
    }

    func test_registerBuiltInDescriptors_theFiveResolve_onSwiftUIRenderer() {
        let renderer = makeSwiftUI()
        var reported: [String] = []
        renderer.onUnregisteredDescriptor = { reported.append(String(describing: $0)) }

        renderer.registerBuiltInDescriptors()
        let ids = presentAllFive(on: renderer)

        XCTAssertEqual(reported, [], "after registerBuiltInDescriptors() none of the five may hit the unregistered path")
        XCTAssertEqual(renderer.presentations.count, 5, "all five must produce a presentation")
        XCTAssertEqual(
            ids.filter { id in renderer.presentations.contains { $0.id == id } }.count, 5,
            "and each of the five, by id"
        )
        XCTAssertTrue(
            renderer.presentations.allSatisfy(ModalPresentationBody.hasBody),
            "the view half must be registered too, not just the factory — otherwise the modal draws nothing"
        )
    }

    /// The five are UNREGISTERED until asked for: `registerBuiltInDescriptors()` is opt-in precisely
    /// so it cannot silently change existing behaviour or clobber a consumer's own registration.
    func test_withoutRegisterBuiltInDescriptors_theFiveStillReportUnregistered_onBothRenderers() {
        let (uiKit, _) = makeUIKit()
        var uiKitReported = 0
        uiKit.onUnregisteredDescriptor = { _ in uiKitReported += 1 }
        _ = presentAllFive(on: uiKit)
        XCTAssertEqual(uiKitReported, 5, "opt-in: nothing is registered by init")

        let swiftUI = makeSwiftUI()
        var swiftUIReported = 0
        swiftUI.onUnregisteredDescriptor = { _ in swiftUIReported += 1 }
        _ = presentAllFive(on: swiftUI)
        XCTAssertEqual(swiftUIReported, 5, "opt-in on both backends, identically")
    }
}
