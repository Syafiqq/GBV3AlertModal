import XCTest
@testable import GBV3AlertModal

final class ModalTokenTests: XCTestCase {
    @MainActor
    func test_resolve_isOnce_andReplaysToLaterAwaiters() async {
        let token = ModalToken<Int>()
        token.resolve(1)
        token.resolve(2) // second resolve ignored
        let first = await token.result
        let second = await token.result // replays the same value
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)
    }

    @MainActor
    func test_result_deliversToWaiterOnLaterResolve() async {
        let token = ModalToken<Int>()
        let waiter = Task { await token.result }
        await Task.yield() // let `waiter` suspend on the continuation before we resolve
        token.resolve(42)
        let value = await waiter.value
        XCTAssertEqual(value, 42)
    }

    @MainActor
    func test_eachToken_hasDistinctID() {
        XCTAssertNotEqual(ModalToken<Int>().id, ModalToken<Int>().id)
    }
}
