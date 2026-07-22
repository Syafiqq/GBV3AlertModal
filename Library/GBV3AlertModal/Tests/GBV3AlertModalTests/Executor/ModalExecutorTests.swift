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
        // `presentAndWait` synchronously presents (populating `renderer.live`) then suspends on the
        // result. Spin (bounded) until the modal is live instead of assuming a single `Task.yield()`
        // is enough — the async-let child's scheduling is not guaranteed after exactly one yield,
        // which made the fixed-yield version hang under some schedules.
        async let result = executor.presentAndWait(AlertDialog(title: "T", primary: "OK"))
        var modal: GBAlertModal?
        for _ in 0..<1000 where modal == nil {
            await Task.yield()
            modal = renderer.live.values.first?.modal
        }
        XCTAssertNotNil(modal, "presentAndWait never presented a modal")
        modal?.dismissAndEmit(event: .primary)
        let value = await result
        XCTAssertEqual(value, .primary)
    }
}
