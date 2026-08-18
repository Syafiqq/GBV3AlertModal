@testable import GBV3AlertModalCore
import XCTest

/// `presentAndWait` AND a coordinator are the two primitives `CoordinatorUsageExample` documents as
/// recommended (its examples 2 and 3), and their INTERSECTION had zero coverage: both pre-existing
/// cancellation tests (`ModalExecutorTests`) drive the direct, coordinator-less path.
///
/// The bug that hid there: `DefaultModalExecutor` wired `token.onDrop` only on the direct path, so a
/// cancelled `presentAndWait` under a coordinator resolved its token but never tore the modal down —
/// the queue's `current` stayed populated forever and every later `present` on that screen queued
/// behind an orphaned modal, unrecoverably (the caller discarded the token, so it could not even
/// `dismiss` it). `MainTabModalCoordinator.present` now wires `onDrop` itself.
///
/// Reuses `SpyRenderer` from `MainTabModalCoordinatorTests`.
@MainActor
final class CoordinatorCancellationTests: XCTestCase {
    private func alert(_ title: String) -> AlertDialog { AlertDialog(title: title, primary: "OK") }

    private func makeCoordinated() -> (DefaultModalExecutor, SpyRenderer) {
        let renderer = SpyRenderer()
        let executor = DefaultModalExecutor(renderer: renderer)
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)
        return (executor, renderer)
    }

    /// THE regression that matters: a cancelled `presentAndWait` must free the coordinator's
    /// `current` slot so the NEXT `present` reaches the renderer.
    ///
    /// DISCRIMINATION — revert the `token.onDrop` wiring in `MainTabModalCoordinator.present` and
    /// this test fails on its last assertion: `drop?()` becomes nil, so the renderer's gate never
    /// fires, `finish()` never runs, `current` stays "A" and "B" sits in the queue forever, giving
    /// `shownTitles == ["A"]`. (Note that the `.dismissed` assertion below would still pass in that
    /// world — `ModalToken.awaitCancelled` resolves the token itself. That is precisely why the
    /// queue-progress assertion, and not the result value, is the stall regression.)
    func test_coordinator_cancelledPresentAndWait_freesQueue_soNextPresentShows() async {
        let (executor, renderer) = makeCoordinated()

        // Built outside the Task so the child captures only `Sendable` values (the descriptor) and
        // the main-actor executor — never the test case.
        let descriptor = alert("A")
        let waiter = Task { await executor.presentAndWait(descriptor) }
        for _ in 0..<1000 where renderer.shown.isEmpty { await Task.yield() }
        XCTAssertEqual(renderer.shownTitles, ["A"], "premise: presentAndWait presented through the coordinator")

        waiter.cancel()
        let value = await waiter.value
        XCTAssertEqual(value, .dismissed, "a cancelled dismiss-mode await resolves .dismissed")
        XCTAssertEqual(
            renderer.dismissed.count, 1,
            "the cancelled await must tear its modal down THROUGH the coordinator — that is what advances the queue"
        )

        _ = executor.present(alert("B"))

        XCTAssertEqual(
            renderer.shownTitles, ["A", "B"],
            "a cancelled presentAndWait must not stall the queue: the next present has to reach the renderer"
        )
    }

    /// The token/renderer contract on that same path, asserted on its own: the cancelled token
    /// resolves `.dismissed` and no modal is left live. Alone this would NOT catch the stall (see the
    /// discrimination note above) — `liveCount` is the part that does.
    func test_coordinator_cancelledPresentAndWait_resolvesDismissed_andLeavesNothingLive() async {
        let (executor, renderer) = makeCoordinated()

        let descriptor = alert("A")
        let waiter = Task { await executor.presentAndWait(descriptor) }
        for _ in 0..<1000 where renderer.shown.isEmpty { await Task.yield() }

        waiter.cancel()
        let value = await waiter.value

        XCTAssertEqual(value, .dismissed)
        XCTAssertEqual(renderer.liveCount, 0, "the visible modal must not be orphaned by the cancellation")
    }
}
