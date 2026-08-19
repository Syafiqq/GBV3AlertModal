import GBV3AlertModalCore

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
    private var buttonActionStyles: [ModalButtonStyle: GBAlertModal.ActionStyle] = [:]
    private let windowProvider: (() -> UIWindow?)?

    /// Called when `present(_:id:resolve:)` is handed a descriptor kind with NO registered factory —
    /// the one silent failure this renderer has (nothing is shown, the token resolves
    /// `dismissedResult` immediately, and that is indistinguishable from an instant user dismissal).
    ///
    /// Defaults to a `#if DEBUG` log; assign your own to route it into a logger, or `nil` to silence
    /// it. `SwiftUIModalRenderer` carries the IDENTICAL hook with the identical default, so the
    /// diagnostic is symmetric across the backends and neither one traps in a test build.
    public var onUnregisteredDescriptor: ((Any.Type) -> Void)? = { type in
        ModalDiagnostics.logUnregisteredDescriptor(type, renderer: "UIKitModalRenderer")
    }

    public init(
        alertProperties: GBAlertModal.Properties,
        popupProperties: GBAlertModal.Properties? = nil,
        windowProvider: (() -> UIWindow?)? = nil
    ) {
        self.windowProvider = windowProvider
        // The existing init SEEDS the style map — the signature is unchanged, so this is not a
        // breaking change and every existing consumer gets `.standard`/`.popup` for free.
        styleProperties[.standard] = alertProperties
        seedButtonStyles(from: alertProperties)
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

    /// OPT-IN registration of the five descriptors this library ships beyond the standard family:
    /// `TextInputDialog`, `DatePickerDialog`, `BadgeDialog`, `LoadingDialog`, `SatisfactionDialog`.
    /// Without this call those types exist but are UNREGISTERED, so presenting one shows nothing and
    /// resolves `dismissedResult` (see `onUnregisteredDescriptor`).
    ///
    /// Deliberately NOT called from `init`: doing so would change every existing consumer's
    /// behaviour silently and could clobber a registration they made themselves. Call it once right
    /// after init; any later `register(_:factory:)` for the same kind overrides the built-in, since
    /// registration is last-write-wins per descriptor TYPE.
    ///
    /// Styling comes from the style map (`properties(for:)`) and is read PER PRESENT, so
    /// `register(style:properties:)` restyles these without re-registering.
    /// `TextInputDialog`/`DatePickerDialog` carry no `style` field and use `.standard`.
    ///
    /// UIKIT COVERAGE, stated plainly — `SwiftUIModalRenderer.registerBuiltInDescriptors()` is the
    /// richer half: `BadgeDialog`'s badge GRID has no UIKit content view in this library (SwiftUI
    /// draws it with `BadgeModalView`), and `LoadingDialog.isLoading` has no UIKit expression at all
    /// (`GBAlertModal` has no busy-button state). Both still register their text + buttons and route
    /// their results faithfully. Register your own factory if you need the missing visuals.
    public func registerBuiltInDescriptors() {
        // `[weak self]` in every closure: they are stored in `self.factories`, exactly as in
        // `registerStandard`, so a strong capture would be a retain cycle.
        register(TextInputDialog.self) { [weak self] descriptor, resolve in
            (self?.properties(for: .standard),
             TextInputHolder.make(for: descriptor, resolve: resolve))
        }
        register(DatePickerDialog.self) { [weak self] descriptor, resolve in
            (self?.properties(for: .standard),
             DatePickerHolder.make(for: descriptor, resolve: resolve))
        }
        register(BadgeDialog.self) { [weak self] descriptor, resolve in
            (self?.properties(for: descriptor.style),
             BadgeHolder.make(for: descriptor, resolve: resolve))
        }
        register(LoadingDialog.self) { [weak self] descriptor, resolve in
            (self?.properties(for: descriptor.style),
             LoadingHolder.make(for: descriptor, resolve: resolve))
        }
        register(SatisfactionDialog.self) { [weak self] descriptor, resolve in
            (self?.properties(for: descriptor.style),
             SatisfactionHolder.make(for: descriptor, resolve: resolve))
        }
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
        if style == .standard { seedButtonStyles(from: properties) }
    }

    /// Registers the UIKit theme used when a descriptor selects this button style.
    public func register(buttonStyle: ModalButtonStyle, actionStyle: GBAlertModal.ActionStyle) {
        buttonActionStyles[buttonStyle] = actionStyle
    }

    private func seedButtonStyles(from properties: GBAlertModal.Properties) {
        if let style = properties.primaryActionStyle { seed(style) }
        if let style = properties.secondaryActionStyle { seed(style) }
    }

    private func seed(_ actionStyle: GBAlertModal.ActionStyle) {
        switch actionStyle {
        case .capsule: buttonActionStyles[.capsule] = actionStyle
        case .capsuleOutlined: buttonActionStyles[.capsuleOutlined] = actionStyle
        case .plain: buttonActionStyles[.plain] = actionStyle
        case .obliqueBottomLeft: buttonActionStyles[.oblique] = actionStyle
        }
    }

    func resolvedProperties(for descriptor: StandardAlertContent) -> GBAlertModal.Properties? {
        guard let properties = properties(for: descriptor.style) else { return nil }
        let primary = descriptor.primaryButtonStyle.flatMap { buttonActionStyles[$0] }
        let secondary = descriptor.secondaryButtonStyle.flatMap { buttonActionStyles[$0] }
        let orientation = descriptor.buttonOrientation.map {
            $0 == .horizontal ? NSLayoutConstraint.Axis.horizontal : .vertical
        }
        return properties.copy(
            buttonActionOrientation: orientation,
            primaryActionStyle: primary,
            secondaryActionStyle: secondary
        )
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
                self?.resolvedProperties(for: descriptor),
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
            // The hook is the only ADDITION: same resolve, but no longer traceless.
            onUnregisteredDescriptor?(D.self)
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
        Self.applyButtonEnablement(of: descriptor, to: modal)

        live[id] = Live(
            modal: modal,
            resolveDismissed: { gate(D.dismissedResult) },
            rebuild: { [weak self] anyDescriptor in
                guard let self, let next = anyDescriptor as? D else { return }
                let (p, h) = factory(next, gate)
                guard let modal = self.live[id]?.modal else { return }
                modal.updateDialog(holder: h, properties: p)
                // AFTER the rebuild, and that ordering is the whole point: `updateDialog` tears the
                // view graph down and builds a new one, so the buttons this touches do not exist
                // before it and any state applied earlier would be discarded. It is also why the
                // flag lives on the DESCRIPTOR rather than in a renderer method — `update(_:to:)`
                // is the channel, and this is it being honoured.
                Self.applyButtonEnablement(of: next, to: modal)
            }
        )
    }

    /// Applies `ButtonEnablement` if the descriptor carries it, using `GBAlertModal`'s OWN public
    /// post-construction API — the same two calls the stress gallery makes by hand. `GBAlertModal`
    /// is untouched.
    ///
    /// A runtime cast, and it is worth naming the one claim it costs: `registerStandard` notes that
    /// neither renderer casts a descriptor at `present` time, which keeps the STYLE lookup static
    /// and identical across backends. That still holds — style is read off `D` where `D` is known.
    /// This is a different question ("does this descriptor carry presentation state at all") asked
    /// of a `D` that is fully generic here, and both `changeXActionEnableState` calls no-op when the
    /// button was never built, so a wrong answer cannot produce a wrong render.
    private static func applyButtonEnablement(of descriptor: Any, to modal: GBAlertModal) {
        guard let state = descriptor as? ButtonEnablement else { return }
        modal.changePrimaryActionEnableState(isEnable: state.primaryEnabled)
        modal.changeSecondaryActionEnableState(isEnable: state.secondaryEnabled)
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

    /// INTERNAL: the fallback this renderer uses when no `windowProvider` was supplied. Not public —
    /// it is this renderer's own plumbing, nothing outside it referenced it, and an app that needs a
    /// key-window lookup has its own (the example app included).
    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
