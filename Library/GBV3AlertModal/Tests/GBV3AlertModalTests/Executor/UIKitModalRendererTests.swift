import XCTest
import UIKit
@testable import GBV3AlertModal

@MainActor
final class UIKitModalRendererTests: XCTestCase {
    private func makeWindow() -> UIWindow {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.makeKeyAndVisible()
        return w
    }

    private func makeRenderer(window: UIWindow) -> UIKitModalRenderer {
        UIKitModalRenderer(alertProperties: GeniePresets.standardProperties(),
                           windowProvider: { window })
    }

    func test_present_addsModalToWindow() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()

        renderer.present(AlertDialog(title: "T", primary: "OK"), id: id) { _ in }

        XCTAssertTrue(window.subviews.contains { $0 is GBAlertModal })
        XCTAssertNotNil(renderer.live[id])
    }

    func test_dismiss_resolvesDismissed_andClearsRegistry() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()
        var received: AlertDialog.Result?

        renderer.present(AlertDialog(title: "T", primary: "OK"), id: id) { received = $0 }
        renderer.dismiss(id)

        XCTAssertEqual(received, .dismissed)
        XCTAssertNil(renderer.live[id])
    }

    func test_userAction_resolvesMappedResult_once() {
        let window = makeWindow()
        let renderer = makeRenderer(window: window)
        let id = ModalID()
        var received: [AlertDialog.Result] = []

        renderer.present(AlertDialog(title: "T", primary: "OK", secondary: "No"), id: id) {
            received.append($0)
        }
        let modal = renderer.live[id]?.modal
        modal?.dismissAndEmit(event: .primary) // simulate primary tap → routes through completion
        modal?.dismissAndEmit(event: .secondary) // gate already fired → ignored

        XCTAssertEqual(received, [.primary])
        XCTAssertNil(renderer.live[id])
    }
}
