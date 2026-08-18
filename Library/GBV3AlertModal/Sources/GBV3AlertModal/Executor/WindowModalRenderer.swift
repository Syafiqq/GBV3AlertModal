import SwiftUI
import UIKit

/// **rootRenderer — the SwiftUI-native alternative to `UIKitModalRenderer` at the true window
/// level.** Genuinely UIKit-free public API (`Factory<D>` is `(ModalProperties?, ModalContent)`,
/// same as `SwiftUIModalRenderer`); imports `UIKit` internally for the one thing this scope
/// genuinely needs it for — installing SwiftUI content into a real `UIWindow`, same reason
/// `UIKitModalRenderer` lives in `Executor/` and not `SwiftUI/`.
///
/// **No queue, by design.** Unlike `SwiftUIModalRenderer` (meant to sit behind
/// `MainTabModalCoordinator`, one dialog live at a time, scoped to a specific screen),
/// window-level presentations are rare and one-off — the same "overlap accepted" stance
/// `UIKitModalRenderer`'s own doc states. A caller wanting serialization installs a coordinator
/// over this renderer exactly as they would over any other; this type itself stays direct-present.
///
/// **Per-presentation hosting, not a shared `@Published` array.** `SwiftUIModalRenderer` needs
/// `ObservableObject`/`@Published` because a CALLER embeds `ModalHost` somewhere in their
/// own SwiftUI tree and that tree must re-render when presentations change. This renderer has no
/// such caller-owned host: it installs its own `UIHostingController` per presentation directly into
/// the window, exactly the shape `UIKitModalRenderer.present` already uses for its own `GBAlertModal`
/// view — one modal, one view, added/removed imperatively. `SwiftUIAlertModal` already draws its own
/// full-screen scrim (`AlertModalScaffold`), so the hosted view needs no overlay/EmptyView-passthrough
/// trick `ModalHost` needs — it fills the window and IS the presentation, nothing to composite
/// with.
///
/// Scoped, like `SwiftUIModalRenderer`, to the standard family (`AlertDialog`/`PopupDialog`) for
/// now — see that type's doc for why.
@MainActor
public final class WindowModalRenderer: ModalRenderer {

    public typealias Factory<D: ModalDescriptor> =
        (D, @escaping (D.Result) -> Void) -> (ModalProperties?, ModalContent)

    /// Builds the SwiftUI body for a bespoke descriptor — same role as `SwiftUIModalRenderer
    /// .ContentBuilder`/`SwiftUIModalRenderer.ContentBuilder`. Handed the resolve GATE directly
    /// (not routed through `route`), because these views own their own state and resolve themselves
    /// at interaction time — the same reason `SwiftUIModalRenderer.registerBuiltInDescriptors` never
    /// sets `route` for the five bespoke kinds, only `view`.
    public typealias ContentBuilder<D: ModalDescriptor> =
        (D, @escaping (D.Result) -> Void) -> AnyView

    private struct Registration<D: ModalDescriptor> {
        let factory: (D, @escaping (D.Result) -> Void) -> (ModalProperties?, ModalContent)
        let route: ((ModalAction) -> D.Result)?
        let content: ((D) -> AlertDialog)?
        let view: ContentBuilder<D>?
    }

    /// One installed presentation: the hosting controller actually mounted in the window, plus the
    /// teardown/rebuild handles every renderer's `live` dictionary carries. Internal, not private —
    /// matching `UIKitModalRenderer.Live`/`SwiftUIModalRenderer.Live`, since `var live` below is
    /// internal for `@testable` assertions and must be at least as visible as its value type.
    struct Live {
        /// Structure only — same shared chain every backend runs (`GBAlertModal.resolve`), kept
        /// purely for `@testable` introspection (`RendererHarness.resolvedSubtitle`, the parity gate).
        /// Never read by rendering: `SwiftUIAlertModal`/the registered bespoke view each re-resolve
        /// internally from `config`/`properties`, same as every other backend's own doc states. `var`
        /// so `update(_:to:)` can refresh it in place via `live[id]?.resolved = ...`.
        var resolved: ResolvedModal
        /// `nil` for a descriptor registered with no content projection — still live and routable,
        /// nothing installed in the window. See `present`'s own doc on this. `UIHostingController`
        /// is a class, so `rootView` can still be reassigned on rebuild without this being `var`.
        let hostingController: UIHostingController<AnyView>?
        /// `ActionType -> Void`, looked up via `live[id]?.route` by the hosted view's `onAction`
        /// closure — same "captured now, dereferenced later via id" pattern `SwiftUIModalRenderer
        /// .present` uses, so a stale closure after teardown is inert rather than dangling.
        let route: ((ModalAction) -> Void)?
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
            factory: factory, route: previous?.route, content: previous?.content, view: previous?.view
        )
    }

    public func register<D: ModalDescriptor>(
        _ type: D.Type,
        route: @escaping (ModalAction) -> D.Result,
        factory: @escaping Factory<D>
    ) {
        let previous = registrations[ObjectIdentifier(type)] as? Registration<D>
        registrations[ObjectIdentifier(type)] = Registration<D>(
            factory: factory, route: route, content: previous?.content, view: previous?.view
        )
    }

    /// Register the SwiftUI body for a descriptor kind — same rules as `SwiftUIModalRenderer
    /// .register(_:view:)`: does not require a factory (a neutral one is installed so the
    /// presentation is still tearable-down), and the two registrations are independent.
    public func register<D: ModalDescriptor>(
        _ type: D.Type,
        view: @escaping (D, @escaping (D.Result) -> Void) -> AnyView
    ) {
        let previous = registrations[ObjectIdentifier(type)] as? Registration<D>
        let neutralFactory: (D, @escaping (D.Result) -> Void) -> (ModalProperties?, ModalContent) =
            { _, _ in (nil, ModalContent()) }
        registrations[ObjectIdentifier(type)] = Registration<D>(
            factory: previous?.factory ?? neutralFactory,
            route: previous?.route,
            content: previous?.content,
            view: view
        )
    }

    /// OPT-IN registration of the five bespoke descriptors — same rule and same VERBATIM view
    /// constructions as `SwiftUIModalRenderer.registerBuiltInDescriptors()` (see that type for why
    /// these views are reusable, top-level, UIKit-free types).
    public func registerBuiltInDescriptors() {
        registrations[ObjectIdentifier(TextInputDialog.self)] = Registration<TextInputDialog>(
            factory: { [weak self] descriptor, _ in
                (self?.properties(for: .standard), ModalContent.make(for: descriptor))
            },
            route: nil, content: nil,
            view: { [weak self] descriptor, resolve in
                AnyView(
                    TextInputModalView(
                        descriptor: descriptor, tokens: self?.tokens(for: .standard) ?? .standard,
                        resolve: resolve
                    )
                )
            }
        )
        registrations[ObjectIdentifier(DatePickerDialog.self)] = Registration<DatePickerDialog>(
            factory: { [weak self] descriptor, _ in
                (self?.properties(for: .standard), ModalContent.make(for: descriptor))
            },
            route: nil, content: nil,
            view: { [weak self] descriptor, resolve in
                AnyView(
                    DatePickerModalView(
                        descriptor: descriptor, tokens: self?.tokens(for: .standard) ?? .standard,
                        resolve: resolve
                    )
                )
            }
        )
        registrations[ObjectIdentifier(BadgeDialog.self)] = Registration<BadgeDialog>(
            factory: { [weak self] descriptor, _ in
                (self?.properties(for: descriptor.style), ModalContent.make(for: descriptor))
            },
            route: nil, content: nil,
            view: { [weak self] descriptor, resolve in
                AnyView(
                    BadgeModalView(
                        descriptor: descriptor,
                        tokens: self?.tokens(for: descriptor.style) ?? .standard,
                        resolve: resolve
                    )
                )
            }
        )
        registrations[ObjectIdentifier(LoadingDialog.self)] = Registration<LoadingDialog>(
            factory: { [weak self] descriptor, _ in
                (self?.properties(for: descriptor.style), ModalContent.make(for: descriptor))
            },
            route: nil, content: nil,
            view: { [weak self] descriptor, resolve in
                AnyView(
                    LoadingModalView(
                        descriptor: descriptor,
                        tokens: self?.tokens(for: descriptor.style) ?? .standard,
                        resolve: resolve
                    )
                )
            }
        )
        registrations[ObjectIdentifier(SatisfactionDialog.self)] = Registration<SatisfactionDialog>(
            factory: { [weak self] descriptor, _ in
                (self?.properties(for: descriptor.style), ModalContent.make(for: descriptor))
            },
            route: nil, content: nil,
            view: { [weak self] descriptor, resolve in
                AnyView(
                    SatisfactionModalView(
                        descriptor: descriptor,
                        tokens: self?.tokens(for: descriptor.style) ?? .standard,
                        resolve: resolve
                    )
                )
            }
        )
    }

    /// `ModalTokens` for a style, off the same style map `properties(for:)` reads.
    private func tokens(for style: ModalStyle) -> ModalTokens {
        guard let properties = properties(for: style) else { return .standard }
        return ModalTokens(from: properties)
    }

    private func registerStandard<D>(
        _ type: D.Type
    ) where D: ModalDescriptor & StandardAlertContent, D.Result == AlertDialog.Result {
        let factory: (D, @escaping (D.Result) -> Void) -> (ModalProperties?, ModalContent) =
            { [weak self] descriptor, _ in
                (self?.properties(for: descriptor.style), ModalContent.make(for: descriptor))
            }
        let route: (ModalAction) -> AlertDialog.Result = { action in
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
            factory: factory, route: route, content: content, view: nil
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

        let (properties, holder) = registration.factory(descriptor, gate)
        let effective = properties ?? ModalProperties()
        let tokens = ModalTokens(from: effective)
        // `SwiftUIAlertModal`/a registered bespoke view each re-resolve internally from
        // `config`/`properties` for actual RENDERING (see `SwiftUIAlertModal`'s own doc) — this
        // resolve is purely for `Live.resolved`, the parity-harness introspection point
        // (`RendererHarness.resolvedSubtitle`), same role `SwiftUIModalRenderer.Presentation
        // .resolved` plays.
        let resolved = GBAlertModal.resolve(inputs: effective, content: holder, isLandscape: false)

        var router: ((ModalAction) -> Void)?
        if let route = registration.route {
            router = { action in gate(route(action)) }
        }

        // Precedence mirrors `ModalPresentationBody.view(for:)`: a `register(_:view:)` body is the
        // WHOLE modal (its own `AlertModalScaffold`) and wins over the standard `content` projection.
        // `registration.view` is handed `gate` directly — bespoke views resolve themselves at
        // interaction time, no `route` needed (see `ContentBuilder`'s own doc). Neither present means
        // a `register(_:factory:)`-only registration — matches `ModalPresentationBody`'s own
        // "routable, no body" outcome: still live, still resolvable via `dismiss(_:)`/`route`,
        // nothing installed in the window.
        var hostingController: UIHostingController<AnyView>?
        if let view = registration.view {
            let controller = UIHostingController(rootView: view(descriptor, gate))
            Self.install(controller, in: window)
            hostingController = controller
        } else if let content = registration.content {
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
            resolved: resolved,
            hostingController: hostingController,
            route: router,
            resolveDismissed: { gate(D.dismissedResult) },
            rebuild: { [weak self] anyDescriptor in
                guard let self, let next = anyDescriptor as? D else { return }
                let (nextProperties, nextHolder) = registration.factory(next, gate)
                let nextEffective = nextProperties ?? ModalProperties()
                self.live[id]?.resolved = GBAlertModal.resolve(
                    inputs: nextEffective, content: nextHolder, isLandscape: false
                )
                if let view = registration.view {
                    self.live[id]?.hostingController?.rootView = view(next, gate)
                    return
                }
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

    /// `live[id] = nil` fires synchronously — the same immediate "no longer routable" signal
    /// `UIKitModalRenderer.teardown` gives (its coordinator's `finish()` needs it to advance the
    /// queue right away). Only the hosted view's removal animates, and it does so via the literal
    /// same call `GBAlertModal.hide()` makes: fade `alpha` to 0 over 0.2s, then
    /// `removeFromSuperview()` in the completion. This renderer already imports `UIKit` for window
    /// installation, so reusing `UIView.animate` here (rather than a SwiftUI `withAnimation`, which
    /// has nothing to interpolate — the view is installed imperatively, not via `ForEach`) is the
    /// same kind of internal-only UIKit use `install(_:in:)` already makes.
    private func teardown(_ id: ModalID) {
        let view = live[id]?.hostingController?.view
        live[id] = nil
        guard let view else { return }
        UIView.animate(
            withDuration: 0.2,
            animations: { view.alpha = 0 },
            completion: { _ in view.removeFromSuperview() }
        )
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
    /// same reasoning `ModalHost`'s base content states, just with no app content underneath
    /// to preserve (this IS the topmost layer, by construction of being window-level).
    private static func install(_ controller: UIHostingController<AnyView>, in window: UIWindow) {
        controller.view.backgroundColor = .clear
        controller.view.frame = window.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(controller.view)
    }

    private static func actionType(for result: AlertDialog.Result) -> ModalAction {
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
