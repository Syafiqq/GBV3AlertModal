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

    private var resolved: Result?
    private var waiters: [CheckedContinuation<Result, Never>] = []

    public init() {}

    /// Suspends until resolved; returns the cached value immediately once resolved (replayable).
    public var result: Result {
        get async {
            if let resolved { return resolved }
            return await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    /// Called only by the renderer, exactly-once per token (extra calls are ignored).
    func resolve(_ value: Result) {
        guard resolved == nil else { return }
        resolved = value
        let pending = waiters
        waiters.removeAll()
        for continuation in pending { continuation.resume(returning: value) }
    }
}
