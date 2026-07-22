import XCTest
import UIKit
@testable import GBV3AlertModal

@MainActor
final class ModalExecutorTests: XCTestCase {
    private func makeExecutor() -> (DefaultModalExecutor, UIKitModalRenderer) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        let renderer = UIKitModalRenderer(alertProperties: GeniePresets.standardProperties(),
                                          windowProvider: { window })
        return (DefaultModalExecutor(renderer: renderer), renderer)
    }

    func test_present_thenDismiss_resolvesDismissed() async {
        let (executor, _) = makeExecutor()
        let token = executor.present(AlertDialog(title: "T", primary: "OK"))
        executor.dismiss(token)
        let result = await token.result
        XCTAssertEqual(result, .dismissed)
    }

    func test_present_userTap_resolvesPrimary() async {
        let (executor, renderer) = makeExecutor()
        let token = executor.present(AlertDialog(title: "T", primary: "OK"))
        renderer.live[token.id]?.modal.dismissAndEmit(event: .primary)
        let result = await token.result
        XCTAssertEqual(result, .primary)
    }

    func test_asyncConvenience_returnsResult() async {
        let (executor, renderer) = makeExecutor()
        // Kick off the await, then drive the tap once the modal is live.
        async let result = executor.presentAndWait(AlertDialog(title: "T", primary: "OK"))
        await Task.yield()
        // The convenience presented via the same renderer; grab the single live modal.
        renderer.live.values.first?.modal.dismissAndEmit(event: .primary)
        let value = await result
        XCTAssertEqual(value, .primary)
    }
}
