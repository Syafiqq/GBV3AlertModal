import Foundation

/// Opaque identity for a live presentation. New value per instance.
public struct ModalID: Hashable, Sendable {
    private let raw: UUID
    public init() { raw = UUID() }
}

/// Handle a ViewModel may hold: identity + an opt-in, replayable async result.
/// NEVER holds the UIView. `@MainActor`-isolated, so its resolve/replay state needs no lock.
@MainActor
public final class ModalToken<Result: Sendable> {
    public let id = ModalID()

    /// Value delivered when the presentation ends without a user action — owner teardown or an
    /// await-cancellation. Seeded by the executor from the descriptor's `dismissedResult`.
    private let dismissedValue: Result

    /// When true (await owns the modal, e.g. `presentAndWait`), cancelling the await tears the modal
    /// down via `onDrop`. When false (a VM holds the token), a cancelled await only detaches that one
    /// waiter; the modal lives on.
    var dismissOnAwaitCancel = false

    /// Owner hook to tear the modal down when a dismiss-mode await is cancelled. The owner MUST
    /// capture weakly — a strong capture keeps the owner alive and defeats scope-based auto-cancel.
    var onDrop: (() -> Void)?

    private var resolved: Result?
    // Keyed so a single cancelled await can detach itself without disturbing other waiters.
    private var waiters: [UUID: CheckedContinuation<Result, Never>] = [:]

    public init(dismissedValue: Result) { self.dismissedValue = dismissedValue }

    /// Suspends until resolved; returns the cached value immediately once resolved (replayable).
    /// A cancelled await never strands its continuation: it either detaches (VM-held token) or tears
    /// the modal down (`dismissOnAwaitCancel`), resolving with `dismissedValue` either way.
    public var result: Result {
        get async {
            if let resolved { return resolved }
            let waiterID = UUID()
            return await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    if let resolved {
                        continuation.resume(returning: resolved) // resolved between the two checks
                    } else {
                        waiters[waiterID] = continuation
                    }
                }
            } onCancel: {
                // onCancel runs off the main actor; hop back. MainActor serialization guarantees the
                // waiter is already registered by the time this runs.
                Task { @MainActor in self.awaitCancelled(waiterID) }
            }
        }
    }

    /// Called by the current owner (renderer while shown, coordinator while queued), exactly-once per
    /// token — extra calls are ignored.
    func resolve(_ value: Result) {
        guard resolved == nil else { return }
        resolved = value
        onDrop = nil
        let pending = waiters
        waiters.removeAll()
        for continuation in pending.values { continuation.resume(returning: value) }
    }

    private func awaitCancelled(_ waiterID: UUID) {
        guard resolved == nil else { return } // already resolved; nothing parked to cancel
        if dismissOnAwaitCancel {
            let drop = onDrop            // resolve() clears onDrop, so capture first
            resolve(dismissedValue)      // resumes every waiter, including this one
            drop?()                      // then tear the modal down
        } else {
            guard let continuation = waiters.removeValue(forKey: waiterID) else { return }
            continuation.resume(returning: dismissedValue) // detach just this waiter; token stays open
        }
    }
}
