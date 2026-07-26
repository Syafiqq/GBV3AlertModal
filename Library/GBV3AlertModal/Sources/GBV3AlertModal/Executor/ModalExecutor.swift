/// The VM-facing front door. Pure descriptors in; a token out. No UIKit types cross this API.
@MainActor
public protocol ModalExecutor {
    /// `dedupKey` is honored only when a coordinator is installed (it needs a queue to dedup against);
    /// on the direct path it is inert.
    @discardableResult
    func present<D: ModalDescriptor>(_ descriptor: D, dedupKey: AnyHashable?) -> ModalToken<D.Result>
    func update<D: ModalDescriptor>(_ token: ModalToken<D.Result>, to descriptor: D)
    func dismiss<R>(_ token: ModalToken<R>)
}

public extension ModalExecutor {
    /// The common no-dedup front door.
    @discardableResult
    func present<D: ModalDescriptor>(_ descriptor: D) -> ModalToken<D.Result> {
        present(descriptor, dedupKey: nil)
    }

    /// One-line show-and-wait for simple/input dialogs. Named distinctly from `present` because
    /// `async let` binds to the sync overload's return type regardless of `async`, making a same-
    /// named convenience ambiguous at that call site.
    func presentAndWait<D: ModalDescriptor>(_ descriptor: D) async -> D.Result {
        let token = present(descriptor, dedupKey: nil)
        token.dismissOnAwaitCancel = true // the await owns the modal — cancelling it tears it down
        return await token.result
    }
}

@MainActor
public final class DefaultModalExecutor: ModalExecutor {
    private let renderer: ModalRenderer

    /// Optional serial/dedup policy. `nil` = the direct path below (today's unbounded behavior).
    /// Replacing or clearing it drains the outgoing coordinator (resolves its pending tokens) so no
    /// queued request is stranded across the handoff.
    public var coordinator: RootScreenModalCoordinator? {
        didSet { oldValue?.drain() }
    }

    public init(renderer: ModalRenderer) { self.renderer = renderer }

    @discardableResult
    public func present<D: ModalDescriptor>(_ descriptor: D, dedupKey: AnyHashable? = nil) -> ModalToken<D.Result> {
        if let coordinator {
            // ponytail: presentAndWait through a coordinator, if its await is cancelled, resolves the
            // token (no hang) but leaves the modal visible + the queue's `current` stuck — the
            // coordinator doesn't wire token.onDrop. Mediocristan; close with deferred scope/cancel.
            return coordinator.present(descriptor, dedupKey: dedupKey)
        }
        // Direct path (no coordinator): today's unbounded behavior. `dedupKey` is inert here — there
        // is no queue to dedup against. ponytail: dedup is a coordinator feature by design.
        let token = ModalToken<D.Result>(dismissedValue: D.dismissedResult)
        // Weak captures both ways: onDrop lives on the token, so a strong `token` capture would be a
        // cycle, and a strong `self` would outlive the executor.
        token.onDrop = { [weak self, weak token] in
            guard let self, let token else { return }
            self.dismiss(token)
        }
        renderer.present(descriptor, id: token.id) { [weak token] result in
            token?.resolve(result)
        }
        return token
    }

    public func update<D: ModalDescriptor>(_ token: ModalToken<D.Result>, to descriptor: D) {
        renderer.update(token.id, to: descriptor)
    }

    public func dismiss<R>(_ token: ModalToken<R>) {
        renderer.dismiss(token.id)
    }
}
