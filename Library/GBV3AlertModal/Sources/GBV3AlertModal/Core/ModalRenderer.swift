import Foundation

@MainActor
public protocol ModalRenderer: AnyObject {
    func present<D: ModalDescriptor>(_ descriptor: D, id: ModalID, resolve: @escaping (D.Result) -> Void)
    func update<D: ModalDescriptor>(_ id: ModalID, to descriptor: D)
    func dismiss(_ id: ModalID)
    /// Toggle a live presentation's visibility WITHOUT tearing it down or resolving its token — used
    /// by a coordinator to hide the modal while its owning screen is covered, and restore it on return.
    func setHidden(_ id: ModalID, _ isHidden: Bool)
}

/// The library's ONE diagnostic channel. Both renderers' `onUnregisteredDescriptor` hooks default to
/// the function below, so the two backends cannot drift in what they report and a release build
/// carries no message and no I/O at all.
enum ModalDiagnostics {
    /// An unregistered descriptor is a HANDLED outcome (nothing is shown and the token resolves
    /// `dismissedResult` immediately) — which is exactly why it needs a trace: without one, a
    /// missing registration is indistinguishable from a user dismissing the modal instantly.
    ///
    /// `#if DEBUG` and deliberately NOT `assertionFailure`: trapping would crash consumers' debug
    /// builds and re-break renderer parity, which is why the sole `assertionFailure` on this path was
    /// removed in the first place. `renderer` names the backend so a log line identifies which of the
    /// two registries was missing the entry.
    static func logUnregisteredDescriptor(_ type: Any.Type, renderer: String) {
        #if DEBUG
        print("""
        [GBV3AlertModal] \(renderer): no factory is registered for \(type). Nothing will be shown \
        and its token resolves dismissedResult immediately. Register it with register(_:factory:) \
        (plus register(_:view:) on SwiftUIModalRenderer), or call registerBuiltInDescriptors() for \
        the descriptors this library ships.
        """)
        #endif
    }
}
