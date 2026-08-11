//
//  CoordinatorUsageExample.swift
//  GBV3AlertModalTests
//
//  A runnable, tutorial-style tour of the modal executor + MainTabModalCoordinator API — the
//  same "host a real modal in a throwaway window and drive it" shape as the Example app's
//  DialogCatalogSmokeTests, but focused on *how a screen/VM calls the new API* rather than on any
//  one dialog's layout.
//
//  The consumer-facing lines are the ones to copy:
//    - `executor.present(descriptor, dedupKey:, priority:, interrupt:)` / `presentAndWait`
//    - `executor.coordinator = MainTabModalCoordinator(renderer:)`  (install / uninstall)
//    - `coordinator.hide()` / `.show()`  (tab push / pop)
//    - `await token.result`, `executor.dismiss(token)`
//  `tap(...)` is demo scaffolding: in the real app the user taps the button; a headless test emits
//  the action for it.
//

import UIKit
import XCTest
@testable import GBV3AlertModal

@MainActor
final class CoordinatorUsageExample: XCTestCase {

    // MARK: 1 — the simplest case: show an alert, read the result (no coordinator)

    func test_example_showAnAlertAndReadTheResult() async {
        let (executor, renderer, window) = makeStack(); defer { teardown(window) }

        // `present` returns a token immediately; the modal is on screen. Await the token for the
        // user's choice. Discard the token instead if you don't care about the result.
        let token = executor.present(AlertDialog(title: "Delete draft?", primary: "Delete", secondary: "Keep"))

        tap(renderer, token.id, .secondary) // user taps "Keep"

        let choice = await token.result
        XCTAssertEqual(choice, .secondary)
    }

    // MARK: 2 — one-line show-and-wait for simple/confirm dialogs

    func test_example_oneLineAwaitForSimpleAlerts() async {
        let (executor, renderer, window) = makeStack(); defer { teardown(window) }

        // `presentAndWait` is the ergonomic convenience: it shows the modal and suspends on the result.
        async let choice = executor.presentAndWait(
            AlertDialog(title: "Save changes?", primary: "Save", secondary: "Discard")
        )
        await untilShown(renderer)                 // (demo) let the modal appear before we "tap"
        tap(renderer, firstLiveID(renderer), .primary)

        let result = await choice
        XCTAssertEqual(result, .primary)
    }

    // MARK: 3 — install a coordinator so modals never stack (serial ordering)

    func test_example_installCoordinatorToSerializeModals() async {
        let (executor, renderer, window) = makeStack(); defer { teardown(window) }

        // A root/tab screen installs one coordinator. Now presents queue instead of overlapping.
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        let first = executor.present(AlertDialog(title: "First", primary: "OK"))
        let second = executor.present(AlertDialog(title: "Second", primary: "OK"))
        XCTAssertEqual(renderer.live.count, 1, "only the first is on screen; the second is queued")

        tap(renderer, first.id, .primary)          // user dismisses the first
        _ = await first.result

        XCTAssertNotNil(renderer.live[second.id], "the second shows automatically")
        tap(renderer, second.id, .primary)
        _ = await second.result
    }

    // MARK: 4 — dedup: collapse duplicate triggers with a key

    func test_example_dedupByKeyCollapsesDuplicates() async {
        let (executor, renderer, window) = makeStack(); defer { teardown(window) }
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        // Several failing requests each try to show the same "no internet" alert at once.
        let a = executor.present(AlertDialog(title: "No internet", primary: "Retry"), dedupKey: "no-internet")
        let b = executor.present(AlertDialog(title: "No internet", primary: "Retry"), dedupKey: "no-internet")

        XCTAssertEqual(renderer.live.count, 1, "the duplicate is dropped, not queued")
        let dropped = await b.result                 // a dropped duplicate still resolves (never hangs)
        XCTAssertEqual(dropped, .dismissed)

        tap(renderer, a.id, .primary); _ = await a.result
    }

    // MARK: 5 — priority: urgent modals jump the queue (but never preempt what's shown)

    func test_example_priorityShowsUrgentModalsFirst() async {
        let (executor, renderer, window) = makeStack(); defer { teardown(window) }
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        let tip = executor.present(AlertDialog(title: "Reading tip", primary: "OK"), priority: 0)      // shown
        let urgent = executor.present(AlertDialog(title: "Session expiring", primary: "Extend"), priority: 10)

        XCTAssertEqual(renderer.live.count, 1, "keep-current: the urgent one does not interrupt what's up")

        tap(renderer, tip.id, .primary); _ = await tip.result
        XCTAssertNotNil(renderer.live[urgent.id], "…but it jumps ahead of lower-priority queued items")

        tap(renderer, urgent.id, .primary); _ = await urgent.result
    }

    // MARK: 6 — interrupt: a per-request kill-switch that preempts the shown modal

    func test_example_interruptPreemptsTheShownModal() async {
        let (executor, renderer, window) = makeStack(); defer { teardown(window) }
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        let reading = executor.present(AlertDialog(title: "Reading tips", primary: "Got it"))
        // A session-end dialog must appear NOW, replacing whatever is on screen.
        let sessionEnd = executor.present(AlertDialog(title: "Session ended", primary: "OK"), interrupt: true)

        XCTAssertNotNil(renderer.live[sessionEnd.id], "the interrupter is on screen immediately")
        let preempted = await reading.result
        XCTAssertEqual(preempted, .dismissed, "the preempted modal resolves dismissed")

        tap(renderer, sessionEnd.id, .primary); _ = await sessionEnd.result
    }

    // MARK: 7 — tab lifecycle: hide on push, show on pop

    func test_example_hideOnTabPushShowOnTabPop() async {
        let (executor, renderer, window) = makeStack(); defer { teardown(window) }
        let coordinator = MainTabModalCoordinator(renderer: renderer)
        executor.coordinator = coordinator

        let token = executor.present(AlertDialog(title: "Welcome back", primary: "Continue"))

        coordinator.hide()  // screen pushed a child — hide the modal so it doesn't float over it
        XCTAssertEqual(renderer.live[token.id]?.modal.isHidden, true)

        coordinator.show()  // returned to the screen — bring it back
        XCTAssertEqual(renderer.live[token.id]?.modal.isHidden, false)

        tap(renderer, token.id, .primary); _ = await token.result
    }

    // MARK: 8 — screen teardown: clearing the coordinator drains anything pending

    func test_example_uninstallingCoordinatorDrainsPending() async {
        let (executor, renderer, window) = makeStack(); defer { teardown(window) }
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        let shown = executor.present(AlertDialog(title: "A", primary: "OK"))
        let queued = executor.present(AlertDialog(title: "B", primary: "OK"))

        executor.coordinator = nil // leaving the screen: the outgoing coordinator drains + resolves all

        let a = await shown.result
        let b = await queued.result
        XCTAssertEqual(a, .dismissed)
        XCTAssertEqual(b, .dismissed)
    }

    // MARK: 9 — fire-and-forget, then dismiss programmatically (even while queued)

    func test_example_fireAndForgetThenDismissProgrammatically() async {
        let (executor, renderer, window) = makeStack(); defer { teardown(window) }
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)

        _ = executor.present(AlertDialog(title: "Busy", primary: "OK"))         // occupies the slot
        let loading = executor.present(AlertDialog(title: "Loading…", primary: "Cancel")) // queued

        executor.dismiss(loading) // e.g. the data arrived: cancel the queued modal before it ever shows
        let result = await loading.result
        XCTAssertEqual(result, .dismissed)
    }

    // MARK: - demo scaffolding (not part of the API)

    private func makeStack() -> (DefaultModalExecutor, UIKitModalRenderer, UIWindow) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible()
        let renderer = UIKitModalRenderer(alertProperties: GeniePresets.standardProperties(),
                                          windowProvider: { window })
        return (DefaultModalExecutor(renderer: renderer), renderer, window)
    }

    /// Stands in for the user tapping a button; the real app never reaches into the renderer.
    private func tap(_ renderer: UIKitModalRenderer, _ id: ModalID, _ action: GBAlertModal.ActionType) {
        renderer.live[id]?.modal.dismissAndEmit(event: action)
    }

    private func untilShown(_ renderer: UIKitModalRenderer) async {
        for _ in 0..<1000 where renderer.live.isEmpty { await Task.yield() }
    }

    private func firstLiveID(_ renderer: UIKitModalRenderer) -> ModalID {
        renderer.live.keys.first ?? ModalID() // demo: exactly one modal is up
    }

    private func teardown(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
        window.subviews.forEach { $0.removeFromSuperview() }
        window.windowScene = nil
    }
}
