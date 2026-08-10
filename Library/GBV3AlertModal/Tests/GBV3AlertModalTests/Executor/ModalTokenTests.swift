import XCTest
@testable import GBV3AlertModal

final class ModalTokenTests: XCTestCase {
    @MainActor
    func test_resolve_isOnce_andReplaysToLaterAwaiters() async {
        let token = ModalToken<Int>(dismissedValue: -1)
        token.resolve(1)
        token.resolve(2) // second resolve ignored
        let first = await token.result
        let second = await token.result // replays the same value
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)
    }

    @MainActor
    func test_result_deliversToWaiterOnLaterResolve() async {
        let token = ModalToken<Int>(dismissedValue: -1)
        let waiter = Task { await token.result }
        await Task.yield() // let `waiter` suspend on the continuation before we resolve
        token.resolve(42)
        let value = await waiter.value
        XCTAssertEqual(value, 42)
    }

    @MainActor
    func test_eachToken_hasDistinctID() {
        XCTAssertNotEqual(ModalToken<Int>(dismissedValue: -1).id,
                          ModalToken<Int>(dismissedValue: -1).id)
    }

    // MARK: - Await cancellation (enqueue-readiness)

    /// Detach mode (a VM holding the token): cancelling one incidental await must resume THAT waiter
    /// with the dismissed value, leave the token unresolved, and NOT tear the modal down.
    @MainActor
    func test_detachMode_cancelledAwait_detachesWaiter_leavesTokenOpen() {
        let token = ModalToken<Int>(dismissedValue: -1)
        var dropped = false
        token.onDrop = { dropped = true }

        let detached = expectation(description: "cancelled waiter resumes with the dismissed value")
        var detachedValue: Int?
        let waiter = Task { @MainActor in
            detachedValue = await token.result
            detached.fulfill()
        }
        waiter.cancel()
        wait(for: [detached], timeout: 2)

        XCTAssertEqual(detachedValue, -1, "detached waiter should resume with the dismissed value")
        XCTAssertFalse(dropped, "detach must not fire onDrop / tear the modal down")

        // token was still open — a later real resolve should still deliver
        let delivered = expectation(description: "later resolve delivers")
        var freshValue: Int?
        let second = Task { @MainActor in
            freshValue = await token.result
            delivered.fulfill()
        }
        token.resolve(99)
        wait(for: [delivered], timeout: 2)
        _ = second
        XCTAssertEqual(freshValue, 99)
    }

    /// Dismiss mode (await owns the modal, e.g. `presentAndWait`): cancelling the await must fire
    /// `onDrop` (tear the modal down) and resolve with the dismissed value.
    @MainActor
    func test_dismissMode_cancelledAwait_firesOnDrop_andResolvesDismissed() {
        let token = ModalToken<Int>(dismissedValue: -1)
        token.dismissOnAwaitCancel = true
        var dropped = false
        token.onDrop = { dropped = true }

        let exp = expectation(description: "dismiss-mode cancel resolves with the dismissed value")
        var value: Int?
        let waiter = Task { @MainActor in
            value = await token.result
            exp.fulfill()
        }
        waiter.cancel()
        wait(for: [exp], timeout: 2)

        XCTAssertEqual(value, -1, "dismiss-mode cancel resolves with the dismissed value")
        XCTAssertTrue(dropped, "dismiss-mode cancel must fire onDrop")
    }

    /// Cancellation after the token already resolved is a no-op: the resolved value replays.
    @MainActor
    func test_cancelledAwait_afterResolve_replaysResolvedValue() async {
        let token = ModalToken<Int>(dismissedValue: -1)
        token.resolve(7)

        let waiter = Task { @MainActor in await token.result }
        waiter.cancel()
        let value = await waiter.value // resolved value replays; cancellation irrelevant

        XCTAssertEqual(value, 7)
    }
}
