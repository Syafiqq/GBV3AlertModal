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
    /// style→`Properties`: the design-system presets this renderer can draw. Lives HERE and not on
    /// the descriptor because `Core/` may not reference UIKit, so a `ModalStyle` can only ever carry
    /// a NAME — the mapping to real `Properties` is necessarily renderer-side.
    /// `SwiftUIModalRenderer` holds the identical map, seeded and read the identical way.
    private var styleProperties: [ModalStyle: GBAlertModal.Properties] = [:]
    private let windowProvider: (() -> UIWindow?)?

    public init(
        alertProperties: GBAlertModal.Properties,
        popupProperties: GBAlertModal.Properties? = nil,
        windowProvider: (() -> UIWindow?)? = nil
    ) {
        self.windowProvider = windowProvider
        // The existing init SEEDS the style map — the signature is unchanged, so this is not a
        // breaking change and every existing consumer gets `.standard`/`.popup` for free.
        styleProperties[.standard] = alertProperties
        if let popupProperties {
            styleProperties[.popup] = popupProperties
        }

        registerStandard(AlertDialog.self)
        // PopupDialog shares AlertDialog's content + result; only the Properties (style) differ.
        // Registered only when the consumer supplies popup styling — unchanged behaviour.
        if popupProperties != nil {
            registerStandard(PopupDialog.self)
        }
    }

    /// Register a factory for a descriptor kind. Consumers add their own descriptors this way.
    public func register<D: ModalDescriptor>(_ type: D.Type, factory: @escaping Factory<D>) {
        factories[ObjectIdentifier(type)] = factory
    }

    /// Register a design-system preset under a `ModalStyle` token. Any `AlertDialog` carrying that
    /// style is then rendered with these `Properties` — the extensible replacement for adding a new
    /// descriptor TYPE per style. Source-identical on `SwiftUIModalRenderer`.
    ///
    /// Re-registering a style replaces its `Properties`. Registering `.standard` replaces the
    /// preset seeded from `init(alertProperties:)`, which is also the fallback every unregistered
    /// style resolves to.
    public func register(style: ModalStyle, properties: GBAlertModal.Properties) {
        styleProperties[style] = properties
    }

    /// The `Properties` a descriptor carrying `style` will actually be rendered with.
    ///
    /// **Fallback, stated plainly:** an UNREGISTERED style resolves to the `.standard` entry. It
    /// never traps and never renders un-styled — the same graceful-degradation stance
    /// `present(_:id:resolve:)` takes for an unregistered descriptor. Pair it with
    /// `isRegistered(style:)` to tell "styled as standard on purpose" apart from "fell back",
    /// which is what makes the fallback observable rather than silent.
    public func properties(for style: ModalStyle) -> GBAlertModal.Properties? {
        styleProperties[style] ?? styleProperties[.standard]
    }

    /// Whether `style` has a preset of its own. `false` means a descriptor carrying it will be
    /// drawn with `.standard`.
    public func isRegistered(style: ModalStyle) -> Bool {
        styleProperties[style] != nil
    }

    /// Wire up one member of the standard family. The style lookup happens INSIDE the factory, i.e.
    /// at `present`/`update` time and per descriptor — that is what lets two `AlertDialog`s with
    /// different `style` tokens render differently through ONE registration. A consumer who
    /// overrides this registration via `register(_:factory:)` supplies their own `Properties` and
    /// opts out of the map, exactly as before.
    private func registerStandard<D>(_ type: D.Type)
    where D: ModalDescriptor & StandardAlertContent, D.Result == AlertDialog.Result {
        // `[weak self]`: the closure is stored in `self.factories`, so a strong capture would be a
        // retain cycle. It can only ever run from `present`/`rebuild`, i.e. while `self` is alive.
        register(type) { [weak self] descriptor, resolve in
            (
                self?.properties(for: descriptor.style),
                AlertHolder.make(for: descriptor, resolve: resolve)
            )
        }
    }

    public func present<D: ModalDescriptor>(
        _ descriptor: D, id: ModalID, resolve: @escaping (D.Result) -> Void
    ) {
        guard let factory = factories[ObjectIdentifier(D.self)] as? Factory<D> else {
            // Graceful resolve, no `assertionFailure`: this IS the specified contract for an
            // unregistered descriptor, and trapping would turn a handled, documented outcome into a
            // crash in consumers' debug builds. `SwiftUIModalRenderer` behaves identically, so the
            // path is one shared, tested behaviour rather than a per-renderer divergence.
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
