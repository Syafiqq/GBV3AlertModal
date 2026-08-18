@testable import GBV3AlertModalCore
@testable import GBV3AlertModalSwiftUI
@testable import GBV3AlertModalUIKit
import XCTest
import UIKit

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

    /// Cancelling a `presentAndWait` tears the modal down (dismiss mode) and resolves `.dismissed` —
    /// closing the orphan-token gap for the await-owns-the-modal path.
    func test_presentAndWait_cancelled_dismissesModal_andResolvesDismissed() async {
        let (executor, renderer) = makeExecutor()
        let waiter = Task { await executor.presentAndWait(AlertDialog(title: "T", primary: "OK")) }

        var modal: GBAlertModal?
        for _ in 0..<1000 where modal == nil {
            await Task.yield()
            modal = renderer.live.values.first?.modal
        }
        XCTAssertNotNil(modal, "presentAndWait never presented a modal")

        waiter.cancel()
        let value = await waiter.value

        XCTAssertEqual(value, .dismissed)
        XCTAssertTrue(renderer.live.isEmpty, "cancelling the wait must tear the modal down")
    }

    /// A VM-held `present` token: cancelling one incidental await must NOT dismiss the modal — it
    /// stays live and a real user tap still resolves it.
    func test_present_tokenHeld_cancelledAwait_leavesModalLive() async {
        let (executor, renderer) = makeExecutor()
        let token = executor.present(AlertDialog(title: "T", primary: "OK"))
        XCTAssertFalse(renderer.live.isEmpty)

        let incidental = Task { @MainActor in await token.result }
        incidental.cancel()
        _ = await incidental.value

        XCTAssertFalse(renderer.live.isEmpty, "incidental await cancel must not dismiss a token-held modal")

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
