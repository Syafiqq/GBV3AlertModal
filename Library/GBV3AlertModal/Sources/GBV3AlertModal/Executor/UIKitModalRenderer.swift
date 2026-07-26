import UIKit

/// The ONLY place UIKit lives. Builds a `GBAlertModal` from a registered factory, shows it on a
/// window, and funnels every teardown path through one resolve-once gate. Overlap accepted.
@MainActor
public final class UIKitModalRenderer: ModalRenderer {
    /// Builds `(Properties?, DataHolder)` for a descriptor. `resolve` closes over the token gate.
    public typealias Factory<D: ModalDescriptor> =
        (D, @escaping (D.Result) -> Void) -> (GBAlertModal.Properties?, GBAlertModal.DataHolder)

    struct Live {
        let modal: GBAlertModal
        let resolveDismissed: () -> Void
        let rebuild: (Any) -> Void
    }

    var live: [ModalID: Live] = [:]           // internal for @testable assertions
    private var factories: [ObjectIdentifier: Any] = [:]
    private let windowProvider: (() -> UIWindow?)?

    public init(
        alertProperties: GBAlertModal.Properties,
        windowProvider: (() -> UIWindow?)? = nil
    ) {
        self.windowProvider = windowProvider
        register(AlertDialog.self) { descriptor, resolve in
            (alertProperties, AlertHolder.make(for: descriptor, resolve: resolve))
        }
    }

    /// Register a factory for a descriptor kind. Consumers add their own descriptors this way.
    public func register<D: ModalDescriptor>(_ type: D.Type, factory: @escaping Factory<D>) {
        factories[ObjectIdentifier(type)] = factory
    }

    public func present<D: ModalDescriptor>(
        _ descriptor: D, id: ModalID, resolve: @escaping (D.Result) -> Void
    ) {
        guard let factory = factories[ObjectIdentifier(D.self)] as? Factory<D> else {
            assertionFailure("No factory registered for \(D.self)")
            resolve(D.dismissedResult)
            return
        }

        var didResolve = false
        let gate: (D.Result) -> Void = { [weak self] result in
            guard !didResolve else { return }
            didResolve = true
            self?.teardown(id)
            resolve(result)
        }

        let (properties, holder) = factory(descriptor, gate)
        let modal = GBAlertModal(properties: properties, holder: holder)
        guard let window = windowProvider?() ?? UIKitModalRenderer.keyWindow else {
            resolve(D.dismissedResult)
            return
        }
        modal.show(parent: window, completion: {})

        live[id] = Live(
            modal: modal,
            resolveDismissed: { gate(D.dismissedResult) },
            rebuild: { [weak self] anyDescriptor in
                guard let self, let next = anyDescriptor as? D else { return }
                let (p, h) = factory(next, gate)
                self.live[id]?.modal.updateDialog(holder: h, properties: p)
            }
        )
    }

    public func update<D: ModalDescriptor>(_ id: ModalID, to descriptor: D) {
        live[id]?.rebuild(descriptor)
    }

    public func dismiss(_ id: ModalID) {
        live[id]?.resolveDismissed()
    }

    public func setHidden(_ id: ModalID, _ isHidden: Bool) {
        live[id]?.modal.isHidden = isHidden // ponytail: UIView toggle; keeps the modal in `live`, no teardown
    }

    private func teardown(_ id: ModalID) {
        guard let entry = live[id] else { return }
        if entry.modal.superview != nil { entry.modal.hide() }
        live[id] = nil
    }

    public static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
