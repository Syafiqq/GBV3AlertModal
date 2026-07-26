/// The VM-facing front door. Pure descriptors in; a token out. No UIKit types cross this API.
@MainActor
public protocol ModalExecutor {
    @discardableResult
    func present<D: ModalDescriptor>(_ descriptor: D) -> ModalToken<D.Result>
    func update<D: ModalDescriptor>(_ token: ModalToken<D.Result>, to descriptor: D)
    func dismiss<R>(_ token: ModalToken<R>)
}

public extension ModalExecutor {
    /// One-line show-and-wait for simple/input dialogs. Named distinctly from `present` because
    /// `async let` binds to the sync overload's return type regardless of `async`, making a same-
    /// named convenience ambiguous at that call site.
    func presentAndWait<D: ModalDescriptor>(_ descriptor: D) async -> D.Result {
        let token = present(descriptor)
        token.dismissOnAwaitCancel = true // the await owns the modal — cancelling it tears it down
        return await token.result
    }
}

@MainActor
public final class DefaultModalExecutor: ModalExecutor {
    private let renderer: ModalRenderer
    public init(renderer: ModalRenderer) { self.renderer = renderer }

    @discardableResult
    public func present<D: ModalDescriptor>(_ descriptor: D) -> ModalToken<D.Result> {
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
