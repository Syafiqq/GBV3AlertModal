import Foundation

/// Serial, screen-owned policy layer between `ModalExecutor` and `ModalRenderer`. One modal at a
/// time (dimmed-fullscreen geometry — two would be visual garbage); the rest queue. Installed by a
/// root/tab screen that also drives its visibility lifecycle. `nil` coordinator on the executor =
/// today's unbounded direct path; this type is the opt-in ordering policy.
///
/// Owns each pending request's token STRONGLY until it resolves: a fire-and-forget `present()` whose
/// token the caller discards must still show and resolve when its turn comes. That ownership is why
/// teardown must drain (resolve every still-pending token) — otherwise a queued request could never
/// resolve and `await token.result` would hang. Every entered request resolves exactly once.
@MainActor
public final class RootScreenModalCoordinator {
    private let renderer: ModalRenderer

    /// One queued request. Closures strongly retain the descriptor + token, so the coordinator owns
    /// pending tokens' lifetimes; `resolveDismissed` is the drain hook.
    private struct Pending {
        let id: ModalID
        let key: AnyHashable?
        let priority: Int
        let show: () -> Void
        let resolveDismissed: () -> Void
    }

    private var queue: [Pending] = []
    private var current: Pending?          // strongly holds the shown request
    private var activeKeys: Set<AnyHashable> = [] // dedup: keys of shown + queued requests
    private var isHidden = false           // owning screen covered: hold the shown modal + pause advancing

    public init(renderer: ModalRenderer) { self.renderer = renderer }

    @discardableResult
    func present<D: ModalDescriptor>(
        _ descriptor: D, dedupKey: AnyHashable? = nil, priority: Int = 0, interrupt: Bool = false
    ) -> ModalToken<D.Result> {
        let token = ModalToken<D.Result>(dismissedValue: D.dismissedResult)

        if let key = dedupKey, activeKeys.contains(key) {
            token.resolve(D.dismissedResult) // drop-new, but still resolve (invariant); never enqueue
            return token
        }
        if let key = dedupKey { activeKeys.insert(key) }

        // A dismiss-mode await (`presentAndWait`) that gets CANCELLED resolves the token itself and
        // then calls `onDrop`. Without this hook that drop is a no-op, so the renderer's gate never
        // fires, `finish()` never runs, and `current` stays populated FOREVER — every later
        // `present` on this screen queues behind an orphaned modal, unrecoverably, because the
        // caller of `presentAndWait` discarded the token and has nothing left to `dismiss`. This
        // mirrors the direct path in `DefaultModalExecutor.present`.
        //
        // `[weak self]` for the same reason that path uses it: `onDrop` lives ON the token, and this
        // coordinator owns pending tokens STRONGLY through `Pending`'s closures, so a strong `self`
        // here would be a retain cycle. No weak-token dance is needed to reach `dismiss(_:)`: the id
        // is captured BY VALUE (`ModalID` is a struct), so the closure retains nothing.
        let id = token.id
        token.onDrop = { [weak self] in self?.dismiss(id) }

        let pending = Pending(
            id: token.id,
            key: dedupKey,
            priority: priority,
            show: { [weak self] in
                guard let self else { return }
                self.renderer.present(descriptor, id: token.id) { [weak self] result in
                    token.resolve(result)
                    self?.finish(dedupKey)
                }
            },
            resolveDismissed: { token.resolve(D.dismissedResult) }
        )

        if interrupt {
            // Kill-switch: jump the whole queue and preempt the shown modal. Tearing down `current`
            // resolves it (via its gate) and finish() then advances to this interrupter at queue front.
            queue.insert(pending, at: 0)
            if let current { renderer.dismiss(current.id) } else { showNextIfIdle() }
        } else {
            enqueue(pending)
            showNextIfIdle()
        }
        return token
    }

    /// Insert by priority — higher first, stable FIFO within equal priority. `current` is not in
    /// `queue`, so the shown modal is never reordered: this is the app's `rearrangeDialog` (pin the
    /// shown one, order the rest).
    /// ponytail: no aging — a low-priority request can starve under a steady stream of higher ones.
    /// Fine for a student app's bounded interaction rate; add priority-aging if starvation shows up.
    private func enqueue(_ pending: Pending) {
        let index = queue.firstIndex { $0.priority < pending.priority } ?? queue.count
        queue.insert(pending, at: index)
    }

    private func showNextIfIdle() {
        guard !isHidden, current == nil, !queue.isEmpty else { return }
        current = queue.removeFirst()
        current?.show()
    }

    private func finish(_ key: AnyHashable?) {
        if let key { activeKeys.remove(key) }
        current = nil
        showNextIfIdle()
    }

    /// The owning screen is tearing down. Resolve every still-pending request (shown + queued)
    /// `.dismissed` and tear down the visible modal — the conservation invariant across teardown.
    public func drain() {
        let pending = (current.map { [$0] } ?? []) + queue
        let shownID = current?.id
        queue.removeAll()
        current = nil
        activeKeys.removeAll()
        if let shownID { renderer.dismiss(shownID) }   // visible modal: tear the view down
        pending.forEach { $0.resolveDismissed() }        // exactly-once resolves all, incl. the shown one
    }

    /// Owning screen was covered (tab push): hold the shown modal in place and stop advancing.
    public func hide() {
        isHidden = true
        if let current { renderer.setHidden(current.id, true) }
    }

    /// Owning screen returned (tab pop): reveal the shown modal and resume advancing the queue.
    public func show() {
        isHidden = false
        if let current { renderer.setHidden(current.id, false) }
        showNextIfIdle()
    }

    /// Dismiss a specific request by id. Shown → tear down (its gate resolves + advances). Queued →
    /// remove it, free its dedup key, and resolve it `.dismissed` (a queued dismiss must not resurface
    /// later). Unknown/already-resolved → no-op.
    func dismiss(_ id: ModalID) {
        if current?.id == id {
            renderer.dismiss(id)
        } else if let index = queue.firstIndex(where: { $0.id == id }) {
            let pending = queue.remove(at: index)
            if let key = pending.key { activeKeys.remove(key) }
            pending.resolveDismissed()
        }
    }
}
