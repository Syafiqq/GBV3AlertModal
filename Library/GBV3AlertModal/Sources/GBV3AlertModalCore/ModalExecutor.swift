/// The VM-facing front door. Pure descriptors in; a token out. No UIKit types cross this API.
@MainActor
public protocol ModalExecutor {
    /// `dedupKey`/`priority`/`interrupt` are honored only when a coordinator is installed (they need a
    /// queue); on the direct path they are inert.
    @discardableResult
    func present<D: ModalDescriptor>(_ descriptor: D, dedupKey: AnyHashable?, priority: Int, interrupt: Bool) -> ModalToken<D.Result>
    func update<D: ModalDescriptor>(_ token: ModalToken<D.Result>, to descriptor: D)
    func dismiss<R>(_ token: ModalToken<R>)
}

public extension ModalExecutor {
    /// The common front door (bare descriptor, defaults for the rest).
    @discardableResult
    func present<D: ModalDescriptor>(_ descriptor: D) -> ModalToken<D.Result> {
        present(descriptor, dedupKey: nil, priority: 0, interrupt: false)
    }

    /// One-line show-and-wait for simple/input dialogs. Named distinctly from `present` because
    /// `async let` binds to the sync overload's return type regardless of `async`, making a same-
    /// named convenience ambiguous at that call site.
    func presentAndWait<D: ModalDescriptor>(_ descriptor: D) async -> D.Result {
        let token = present(descriptor, dedupKey: nil, priority: 0, interrupt: false)
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
    public var coordinator: MainTabModalCoordinator? {
        didSet { oldValue?.drain() }
    }

    public init(renderer: ModalRenderer) { self.renderer = renderer }

    @discardableResult
    public func present<D: ModalDescriptor>(_ descriptor: D, dedupKey: AnyHashable? = nil, priority: Int = 0, interrupt: Bool = false) -> ModalToken<D.Result> {
        if let coordinator {
            // The coordinator wires `token.onDrop` itself (see `MainTabModalCoordinator.present`),
            // so a cancelled `presentAndWait` tears the shown modal down and ADVANCES the queue on
            // this path too — the same guarantee the direct path below gives.
            return coordinator.present(descriptor, dedupKey: dedupKey, priority: priority, interrupt: interrupt)
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
        // Direct to renderer: works for a shown modal (coordinated or not). ponytail: updating a
        // still-QUEUED modal is a no-op — it shows with its original descriptor. Add coordinator-side
        // queued rebuild only if a real stateful-while-queued case appears.
        renderer.update(token.id, to: descriptor)
    }

    public func dismiss<R>(_ token: ModalToken<R>) {
        // Route through the coordinator so a QUEUED token is removed + resolved, not silently ignored
        // (a bare renderer.dismiss only knows shown modals, so a queued dismiss would resurface later).
        if let coordinator { coordinator.dismiss(token.id) } else { renderer.dismiss(token.id) }
    }
}
