import SwiftUI
import UIKit

/// **rootRenderer — the SwiftUI-native alternative to `UIKitModalRenderer` at the true window
/// level.** Genuinely UIKit-free public API (`Factory<D>` is `(ModalProperties?, ModalContent)`,
/// same as `EmbeddedModalRenderer`); imports `UIKit` internally for the one thing this scope
/// genuinely needs it for — installing SwiftUI content into a real `UIWindow`, same reason
/// `UIKitModalRenderer` lives in `Executor/` and not `SwiftUI/`.
///
/// **No queue, by design.** Unlike `EmbeddedModalRenderer` (meant to sit behind
/// `RootScreenModalCoordinator`, one dialog live at a time, scoped to a specific screen),
/// window-level presentations are rare and one-off — the same "overlap accepted" stance
/// `UIKitModalRenderer`'s own doc states. A caller wanting serialization installs a coordinator
/// over this renderer exactly as they would over any other; this type itself stays direct-present.
///
/// **Per-presentation hosting, not a shared `@Published` array.** `EmbeddedModalRenderer` needs
/// `ObservableObject`/`@Published` because a CALLER embeds `EmbeddedModalHost` somewhere in their
/// own SwiftUI tree and that tree must re-render when presentations change. This renderer has no
/// such caller-owned host: it installs its own `UIHostingController` per presentation directly into
/// the window, exactly the shape `UIKitModalRenderer.present` already uses for its own `GBAlertModal`
/// view — one modal, one view, added/removed imperatively. `SwiftUIAlertModal` already draws its own
/// full-screen scrim (`AlertModalScaffold`), so the hosted view needs no overlay/EmptyView-passthrough
/// trick `EmbeddedModalHost` needs — it fills the window and IS the presentation, nothing to composite
/// with.
///
/// Scoped, like `EmbeddedModalRenderer`, to the standard family (`AlertDialog`/`PopupDialog`) for
/// now — see that type's doc for why.
@MainActor
public final class WindowModalRenderer: ModalRenderer {

    public typealias Factory<D: ModalDescriptor> =
        (D, @escaping (D.Result) -> Void) -> (ModalProperties?, ModalContent)

    private struct Registration<D: ModalDescriptor> {
        let factory: (D, @escaping (D.Result) -> Void) -> (ModalProperties?, ModalContent)
        let route: ((GBAlertModal.ActionType) -> D.Result)?
        let content: ((D) -> AlertDialog)?
    }

    /// One installed presentation: the hosting controller actually mounted in the window, plus the
    /// teardown/rebuild handles every renderer's `live` dictionary carries. Internal, not private —
    /// matching `UIKitModalRenderer.Live`/`EmbeddedModalRenderer.Live`, since `var live` below is
    /// internal for `@testable` assertions and must be at least as visible as its value type.
    struct Live {
        /// `nil` for a descriptor registered with no content projection — still live and routable,
        /// nothing installed in the window. See `present`'s own doc on this. `UIHostingController`
        /// is a class, so `rootView` can still be reassigned on rebuild without this being `var`.
        let hostingController: UIHostingController<AnyView>?
        /// `ActionType -> Void`, looked up via `live[id]?.route` by the hosted view's `onAction`
        /// closure — same "captured now, dereferenced later via id" pattern `EmbeddedModalRenderer
        /// .present` uses, so a stale closure after teardown is inert rather than dangling.
        let route: ((GBAlertModal.ActionType) -> Void)?
        let resolveDismissed: () -> Void
        let rebuild: (Any) -> Void
    }

    var live: [ModalID: Live] = [:]   // internal for @testable assertions, as on the other renderers
    private var registrations: [ObjectIdentifier: Any] = [:]
    private var styleProperties: [ModalStyle: ModalProperties] = [:]
    private let windowProvider: (() -> UIWindow?)?

    public var onUnregisteredDescriptor: ((Any.Type) -> Void)? = { type in
        ModalDiagnostics.logUnregisteredDescriptor(type, renderer: "WindowModalRenderer")
    }

    public init(
        alertProperties: ModalProperties,
        popupProperties: ModalProperties? = nil,
        windowProvider: (() -> UIWindow?)? = nil
    ) {
        self.windowProvider = windowProvider
        styleProperties[.standard] = alertProperties
        if let popupProperties {
            styleProperties[.popup] = popupProperties
        }

        registerStandard(AlertDialog.self)
        if popupProperties != nil {
            registerStandard(PopupDialog.self)
        }
    }

    public func register(style: ModalStyle, properties: ModalProperties) {
        styleProperties[style] = properties
    }

    public func properties(for style: ModalStyle) -> ModalProperties? {
        styleProperties[style] ?? styleProperties[.standard]
    }

    public func isRegistered(style: ModalStyle) -> Bool {
        styleProperties[style] != nil
    }

    /// Register a factory for a descriptor kind. No `ActionType -> Result` mapping — use
    /// `register(_:route:factory:)` for anything a user can act on.
    public func register<D: ModalDescriptor>(_ type: D.Type, factory: @escaping Factory<D>) {
        let previous = registrations[ObjectIdentifier(type)] as? Registration<D>
        registrations[ObjectIdentifier(type)] = Registration<D>(
            factory: factory, route: previous?.route, content: previous?.content
        )
    }

    public func register<D: ModalDescriptor>(
        _ type: D.Type,
        route: @escaping (GBAlertModal.ActionType) -> D.Result,
        factory: @escaping Factory<D>
    ) {
        let previous = registrations[ObjectIdentifier(type)] as? Registration<D>
        registrations[ObjectIdentifier(type)] = Registration<D>(
            factory: factory, route: route, content: previous?.content
        )
    }

    private func registerStandard<D>(
        _ type: D.Type
    ) where D: ModalDescriptor & StandardAlertContent, D.Result == AlertDialog.Result {
        let factory: (D, @escaping (D.Result) -> Void) -> (ModalProperties?, ModalContent) =
            { [weak self] descriptor, _ in
                (self?.properties(for: descriptor.style), ModalContent.make(for: descriptor))
            }
        let route: (GBAlertModal.ActionType) -> AlertDialog.Result = { action in
            switch action {
            case .primary: return AlertDialog.Result.primary
            case .secondary: return AlertDialog.Result.secondary
            case .close: return AlertDialog.Result.dismissed
            }
        }
        let content: (D) -> AlertDialog = { descriptor in
            let state = descriptor as? ButtonEnablement
            return AlertDialog(
                image: descriptor.image,
                title: descriptor.title,
                subtitle: descriptor.subtitle,
                primary: descriptor.primary,
                secondary: descriptor.secondary,
                primaryEnabled: state?.primaryEnabled ?? true,
                secondaryEnabled: state?.secondaryEnabled ?? true,
                closeOnTapOverlay: descriptor.closeOnTapOverlay,
                showCloseButton: descriptor.showCloseButton,
                style: descriptor.style
            )
        }
        registrations[ObjectIdentifier(type)] = Registration<D>(
            factory: factory, route: route, content: content
        )
    }

    // MARK: - ModalRenderer

    public func present<D: ModalDescriptor>(
        _ descriptor: D, id: ModalID, resolve: @escaping (D.Result) -> Void
    ) {
        guard let registration = registrations[ObjectIdentifier(D.self)] as? Registration<D> else {
            onUnregisteredDescriptor?(D.self)
            resolve(D.dismissedResult)
            return
        }
        guard let window = windowProvider?() ?? Self.keyWindow else {
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

        // `holder` (the `ModalContent`) is unused here: unlike `EmbeddedModalRenderer`, this renderer
        // never calls `GBAlertModal.resolve` itself — `SwiftUIAlertModal` already re-resolves
        // internally from `config`/`properties` (see its own doc), and nothing here needs the
        // resolved value for introspection the way a parity-harness `Presentation` would.
        let (properties, _) = registration.factory(descriptor, gate)
        let effective = properties ?? ModalProperties()
        let tokens = ModalTokens(from: effective)

        var router: ((GBAlertModal.ActionType) -> Void)?
        if let route = registration.route {
            router = { action in gate(route(action)) }
        }

        // `registration.content` is `nil` for a descriptor registered via `register(_:factory:)`/
        // `register(_:route:factory:)` alone (no `register(_:view:)` equivalent exists on this
        // renderer) — matches `ModalPresentationBody.view(for:)`'s own "routable, no body" outcome:
        // still live, still resolvable via `dismiss(_:)`/`route`, nothing installed in the window.
        var hostingController: UIHostingController<AnyView>?
        if let content = registration.content {
            let controller = UIHostingController(
                rootView: Self.view(
                    config: content(descriptor), properties: effective, tokens: tokens,
                    onAction: { [weak self] result in
                        guard let route = self?.live[id]?.route else { return }
                        route(Self.actionType(for: result))
                    }
                )
            )
            Self.install(controller, in: window)
            hostingController = controller
        }

        live[id] = Live(
            hostingController: hostingController,
            route: router,
            resolveDismissed: { gate(D.dismissedResult) },
            rebuild: { [weak self] anyDescriptor in
                guard let self, let next = anyDescriptor as? D else { return }
                let (nextProperties, _) = registration.factory(next, gate)
                let nextEffective = nextProperties ?? ModalProperties()
                guard let content = registration.content else { return }
                self.live[id]?.hostingController?.rootView = Self.view(
                    config: content(next),
                    properties: nextEffective,
                    tokens: ModalTokens(from: nextEffective),
                    onAction: { [weak self] result in
                        guard let route = self?.live[id]?.route else { return }
                        route(Self.actionType(for: result))
                    }
                )
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
        live[id]?.hostingController?.view.isHidden = isHidden
    }

    // MARK: - Internals

    private func teardown(_ id: ModalID) {
        live[id]?.hostingController?.view.removeFromSuperview()
        live[id] = nil
    }

    private static func view(
        config: AlertDialog,
        properties: ModalProperties,
        tokens: ModalTokens,
        onAction: @escaping (AlertDialog.Result) -> Void
    ) -> AnyView {
        AnyView(
            SwiftUIAlertModal(config: config, properties: properties, tokens: tokens, onAction: onAction)
        )
    }

    /// Installs a hosting controller's view as a transparent, edge-pinned overlay of `window`.
    /// `SwiftUIAlertModal` draws its own full-screen scrim, so the container itself stays clear —
    /// same reasoning `EmbeddedModalHost`'s base content states, just with no app content underneath
    /// to preserve (this IS the topmost layer, by construction of being window-level).
    private static func install(_ controller: UIHostingController<AnyView>, in window: UIWindow) {
        controller.view.backgroundColor = .clear
        controller.view.frame = window.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(controller.view)
    }

    private static func actionType(for result: AlertDialog.Result) -> GBAlertModal.ActionType {
        switch result {
        case .primary: return .primary
        case .secondary: return .secondary
        case .dismissed: return .close
        }
    }

    /// INTERNAL fallback when no `windowProvider` was supplied — same lookup
    /// `UIKitModalRenderer.keyWindow` performs, duplicated rather than shared: each renderer owns its
    /// own small plumbing, and this is 4 lines.
    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
