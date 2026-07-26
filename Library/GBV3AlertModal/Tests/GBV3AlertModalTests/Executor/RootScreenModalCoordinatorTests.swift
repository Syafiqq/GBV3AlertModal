import XCTest
@testable import GBV3AlertModal

/// A fake `ModalRenderer` that records presentations without a window, and lets a test drive
/// resolution (user tap) or dismissal the way the real UIKit renderer's gate would.
@MainActor
final class SpyRenderer: ModalRenderer {
    struct Shown {
        let id: ModalID
        let resolveWith: (Any) -> Void   // simulate a user action
        let resolveDismissed: () -> Void // simulate renderer teardown
    }
    private(set) var shown: [Shown] = []
    private(set) var dismissed: [ModalID] = []

    func present<D: ModalDescriptor>(_ descriptor: D, id: ModalID, resolve: @escaping (D.Result) -> Void) {
        shown.append(Shown(
            id: id,
            resolveWith: { resolve($0 as! D.Result) },
            resolveDismissed: { resolve(D.dismissedResult) }
        ))
    }

    func update<D: ModalDescriptor>(_ id: ModalID, to descriptor: D) {}

    func dismiss(_ id: ModalID) {
        dismissed.append(id)
        shown.first { $0.id == id }?.resolveDismissed()
    }

    private(set) var hidden: [ModalID: Bool] = [:]
    func setHidden(_ id: ModalID, _ isHidden: Bool) { hidden[id] = isHidden }

    // MARK: test drivers
    func userResolveLast(_ value: Any) { shown.last?.resolveWith(value) }
    var liveCount: Int { shown.count - dismissed.count }
}

@MainActor
final class RootScreenModalCoordinatorTests: XCTestCase {
    private func alert(_ t: String) -> AlertDialog { AlertDialog(title: t, primary: "OK") }

    func test_serial_secondRequestNotShownUntilFirstResolves() {
        let renderer = SpyRenderer()
        let coordinator = RootScreenModalCoordinator(renderer: renderer)

        _ = coordinator.present(alert("A"))
        _ = coordinator.present(alert("B"))

        XCTAssertEqual(renderer.shown.count, 1, "serial: only the first request is shown")

        renderer.userResolveLast(AlertDialog.Result.primary)

        XCTAssertEqual(renderer.shown.count, 2, "resolving the first advances the queue to the second")
    }

    func test_userResolution_forwardsChosenValueToToken() async {
        let renderer = SpyRenderer()
        let coordinator = RootScreenModalCoordinator(renderer: renderer)

        let token = coordinator.present(alert("A"))
        renderer.userResolveLast(AlertDialog.Result.secondary) // resolves synchronously

        let result = await token.result
        XCTAssertEqual(result, .secondary)
    }

    func test_dedup_duplicateKeyWhileInFlight_isNeverShown() {
        let renderer = SpyRenderer()
        let coordinator = RootScreenModalCoordinator(renderer: renderer)

        _ = coordinator.present(alert("A"), dedupKey: "k")
        _ = coordinator.present(alert("A-dup"), dedupKey: "k")
        renderer.userResolveLast(AlertDialog.Result.primary) // resolve the first

        // Without dedup the dropped one would surface here as the 2nd presentation.
        XCTAssertEqual(renderer.shown.count, 1, "a duplicate-key request must never be shown")
    }

    func test_dedup_droppedDuplicate_resolvesDismissed() {
        let renderer = SpyRenderer()
        let coordinator = RootScreenModalCoordinator(renderer: renderer)

        _ = coordinator.present(alert("A"), dedupKey: "k")
        let dup = coordinator.present(alert("A-dup"), dedupKey: "k")

        // Bounded wait — a dropped token that never resolves would hang; the timeout makes that a
        // clean failure instead of a stuck test (see brief §9 gotcha).
        let resolved = expectation(description: "dropped duplicate resolves")
        var result: AlertDialog.Result?
        Task { result = await dup.result; resolved.fulfill() }
        wait(for: [resolved], timeout: 1.0)

        XCTAssertEqual(result, .dismissed, "dropped duplicate must resolve (invariant), with dismissed")
    }

    func test_nilDedupKey_neverDedups() {
        let renderer = SpyRenderer()
        let coordinator = RootScreenModalCoordinator(renderer: renderer)

        _ = coordinator.present(alert("A"))            // nil key
        _ = coordinator.present(alert("B"))            // nil key — must NOT be treated as a duplicate
        renderer.userResolveLast(AlertDialog.Result.primary)

        XCTAssertEqual(renderer.shown.count, 2, "nil keys never dedup; the second still shows")
    }

    /// Conservation: every request that enters `present` gets exactly one resolution, across the
    /// exit paths that exist in PR-1 (normal-resolve + dedup-drop).
    func test_conservation_normalAndDedupDrop_allResolveExactlyOnce() {
        let renderer = SpyRenderer()
        let coordinator = RootScreenModalCoordinator(renderer: renderer)

        let t1 = coordinator.present(alert("A"), dedupKey: "k")
        let t2 = coordinator.present(alert("B"), dedupKey: "k") // dropped duplicate
        let t3 = coordinator.present(alert("C"))                // queued behind t1

        renderer.userResolveLast(AlertDialog.Result.primary)    // resolves t1, advances to t3
        renderer.userResolveLast(AlertDialog.Result.secondary)  // resolves t3

        let all = expectation(description: "all three resolve")
        var results: [AlertDialog.Result?] = []
        Task {
            results = [await t1.result, await t2.result, await t3.result]
            all.fulfill()
        }
        wait(for: [all], timeout: 1.0)

        XCTAssertEqual(results, [.primary, .dismissed, .secondary])
    }

    // MARK: teardown drain (third conservation path — owning screen dies)

    func test_teardownDrain_resolvesCurrentAndQueuedDismissed() {
        let renderer = SpyRenderer()
        let coordinator = RootScreenModalCoordinator(renderer: renderer)

        let t1 = coordinator.present(alert("A")) // shown
        let t2 = coordinator.present(alert("B")) // queued
        let t3 = coordinator.present(alert("C")) // queued

        let drained = expectation(description: "all pending resolve after drain")
        var results: [AlertDialog.Result?] = []
        Task { results = [await t1.result, await t2.result, await t3.result]; drained.fulfill() }

        coordinator.drain() // owning screen tears down

        wait(for: [drained], timeout: 1.0)
        XCTAssertEqual(results, [.dismissed, .dismissed, .dismissed])
    }

    func test_teardownDrain_dismissesTheVisibleModal() {
        let renderer = SpyRenderer()
        let coordinator = RootScreenModalCoordinator(renderer: renderer)

        let t1 = coordinator.present(alert("A")) // shown
        _ = coordinator.present(alert("B"))      // queued, never shown — no view to tear down

        coordinator.drain()

        XCTAssertEqual(renderer.dismissed, [t1.id], "only the visible modal needs a renderer teardown")
    }

    // MARK: visibility lifecycle (hide on tab push, show on pop)

    func test_hidden_resolvingCurrentDoesNotAdvanceUntilShown() {
        let renderer = SpyRenderer()
        let coordinator = RootScreenModalCoordinator(renderer: renderer)

        _ = coordinator.present(alert("A")) // shown
        _ = coordinator.present(alert("B")) // queued

        coordinator.hide()
        renderer.userResolveLast(AlertDialog.Result.primary) // A resolves while hidden

        XCTAssertEqual(renderer.shown.count, 1, "while hidden, the queue must not advance")

        coordinator.show()
        XCTAssertEqual(renderer.shown.count, 2, "showing resumes the queue")
    }

    func test_hide_doesNotResolveCurrentToken() {
        let renderer = SpyRenderer()
        let coordinator = RootScreenModalCoordinator(renderer: renderer)

        let t1 = coordinator.present(alert("A"))
        coordinator.hide()
        XCTAssertEqual(renderer.hidden[t1.id], true, "current modal is hidden")

        // If hide() had resolved the token, this real value would be ignored (exactly-once) and the
        // result below would be .dismissed. Seeing .secondary proves hide left the token open.
        renderer.userResolveLast(AlertDialog.Result.secondary)
        let resolved = expectation(description: "resolves with the real value, not from hide")
        var result: AlertDialog.Result?
        Task { result = await t1.result; resolved.fulfill() }
        wait(for: [resolved], timeout: 1.0)
        XCTAssertEqual(result, .secondary, "hide must not resolve the token")
    }

    func test_show_unhidesCurrentModal() {
        let renderer = SpyRenderer()
        let coordinator = RootScreenModalCoordinator(renderer: renderer)

        let t1 = coordinator.present(alert("A"))
        coordinator.hide()
        coordinator.show()

        XCTAssertEqual(renderer.hidden[t1.id], false, "show un-hides the current modal")
    }
}
