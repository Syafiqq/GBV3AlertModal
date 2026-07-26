import XCTest
@testable import GBV3AlertModal

/// The executor's optional coordinator slot: `nil` = today's unbounded direct path; installed =
/// requests route through the serial/dedup policy. Reuses `SpyRenderer` from the coordinator tests.
@MainActor
final class ModalExecutorCoordinatorTests: XCTestCase {
    private func alert(_ t: String) -> AlertDialog { AlertDialog(title: t, primary: "OK") }

    func test_withoutCoordinator_directPathAcceptsOverlap() {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer)

        _ = executor.present(alert("A"))
        _ = executor.present(alert("B"))

        XCTAssertEqual(renderer.shown.count, 2, "no coordinator = unbounded direct path (overlap accepted)")
    }

    func test_withCoordinator_presentsRouteThroughSerialQueue() {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer)
        executor.coordinator = RootScreenModalCoordinator(renderer: renderer)

        _ = executor.present(alert("A"))
        _ = executor.present(alert("B"))

        XCTAssertEqual(renderer.shown.count, 1, "with a coordinator installed, presents serialize")
    }

    func test_withCoordinator_dedupKeyDropsDuplicate() {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer)
        executor.coordinator = RootScreenModalCoordinator(renderer: renderer)

        _ = executor.present(alert("A"), dedupKey: "k")
        let dup = executor.present(alert("A-dup"), dedupKey: "k")

        XCTAssertEqual(renderer.shown.count, 1, "duplicate key routed to coordinator and dropped")

        let resolved = expectation(description: "dropped duplicate resolves")
        var result: AlertDialog.Result?
        Task { result = await dup.result; resolved.fulfill() }
        wait(for: [resolved], timeout: 1.0)
        XCTAssertEqual(result, .dismissed)
    }

    func test_clearingCoordinator_drainsPreviousQueue() {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer)
        executor.coordinator = RootScreenModalCoordinator(renderer: renderer)

        let t1 = executor.present(alert("A")) // shown via coordinator
        let t2 = executor.present(alert("B")) // queued

        let drained = expectation(description: "outgoing coordinator drains on handoff")
        var results: [AlertDialog.Result?] = []
        Task { results = [await t1.result, await t2.result]; drained.fulfill() }

        executor.coordinator = nil // handoff back to the direct path must drain the outgoing queue

        wait(for: [drained], timeout: 1.0)
        XCTAssertEqual(results, [.dismissed, .dismissed])
    }
}
