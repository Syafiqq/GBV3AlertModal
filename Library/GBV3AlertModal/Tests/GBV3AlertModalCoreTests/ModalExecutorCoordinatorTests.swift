@testable import GBV3AlertModalCore
import XCTest

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
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        _ = executor.present(alert("A"))
        _ = executor.present(alert("B"))

        XCTAssertEqual(renderer.shown.count, 1, "with a coordinator installed, presents serialize")
    }

    func test_withCoordinator_dedupKeyDropsDuplicate() {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer)
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        _ = executor.present(alert("A"), dedupKey: "k")
        let dup = executor.present(alert("A-dup"), dedupKey: "k")

        XCTAssertEqual(renderer.shown.count, 1, "duplicate key routed to coordinator and dropped")

        let resolved = expectation(description: "dropped duplicate resolves")
        var result: AlertDialog.Result?
        Task { result = await dup.result; resolved.fulfill() }
        wait(for: [resolved], timeout: 1.0)
        XCTAssertEqual(result, .dismissed)
    }

    func test_withCoordinator_priorityRoutedThroughFrontDoor() {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer)
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        _ = executor.present(alert("A"), priority: 0) // shown
        _ = executor.present(alert("B"), priority: 1)
        _ = executor.present(alert("C"), priority: 5)
        renderer.userResolveLast(AlertDialog.Result.primary) // A resolves

        XCTAssertEqual(renderer.lastShownTitle, "C", "priority routes through the executor to the coordinator")
    }

    func test_withCoordinator_interruptRoutedThroughFrontDoor() {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer)
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        let a = executor.present(alert("A")) // shown
        _ = executor.present(alert("B"), interrupt: true)

        XCTAssertEqual(renderer.lastShownTitle, "B", "interrupt routes through and preempts")
        XCTAssertEqual(renderer.dismissed, [a.id])
    }

    func test_clearingCoordinator_drainsPreviousQueue() {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer)
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        let t1 = executor.present(alert("A")) // shown via coordinator
        let t2 = executor.present(alert("B")) // queued

        let drained = expectation(description: "outgoing coordinator drains on handoff")
        var results: [AlertDialog.Result?] = []
        Task { results = [await t1.result, await t2.result]; drained.fulfill() }

        executor.coordinator = nil // handoff back to the direct path must drain the outgoing queue

        wait(for: [drained], timeout: 1.0)
        XCTAssertEqual(results, [.dismissed, .dismissed])
    }

    // MARK: hardening — unbounded direct path, dismiss/update through the coordinator

    func test_directPath_isUnbounded_manyModalsOverlap() {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer) // no coordinator

        _ = executor.present(alert("A"))
        _ = executor.present(alert("B"))
        _ = executor.present(alert("C"))

        XCTAssertEqual(renderer.shown.count, 3, "no coordinator = unbounded; all three overlap")
    }

    func test_withCoordinator_dismissShownToken_resolvesAndAdvances() {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer)
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        let ta = executor.present(alert("A")) // shown
        _ = executor.present(alert("B"))      // queued

        executor.dismiss(ta)

        XCTAssertEqual(renderer.shownTitles, ["A", "B"], "dismissing the shown modal advances the queue")
        let resolved = expectation(description: "shown dismiss resolves")
        var result: AlertDialog.Result?
        Task { result = await ta.result; resolved.fulfill() }
        wait(for: [resolved], timeout: 1.0)
        XCTAssertEqual(result, .dismissed)
    }

    func test_withCoordinator_dismissQueuedToken_resolvesAndNeverShows() {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer)
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        _ = executor.present(alert("A"))      // shown
        let tb = executor.present(alert("B")) // queued

        executor.dismiss(tb) // cancel the queued request

        let resolved = expectation(description: "queued dismiss resolves")
        var result: AlertDialog.Result?
        Task { result = await tb.result; resolved.fulfill() }
        wait(for: [resolved], timeout: 1.0)
        XCTAssertEqual(result, .dismissed, "dismissing a queued token resolves it")

        renderer.userResolveLast(AlertDialog.Result.primary) // resolve A
        XCTAssertEqual(renderer.shownTitles, ["A"], "a dismissed queued modal must never appear")
    }
}
