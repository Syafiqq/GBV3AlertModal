import Combine // `ObservableObject`/`@Published` (SwiftUI re-exports these; imported explicitly).
import SwiftUI

/// The SwiftUI-native backend for `ModalRenderer`.
///
/// A factory registry keyed by `ObjectIdentifier(D.self)`, with a resolve-once gate per
/// presentation, a live-presentation dictionary, and one teardown funnel. Its public vocabulary is
/// SwiftUI-native: factories return `(ModalProperties?, ModalContent)`.
///
/// The standard alert family is registered at initialization. Input, badge, loading, and
/// satisfaction descriptors are available through `registerBuiltInDescriptors()`.
///
/// `ModalHost` embeds presentations in the caller's SwiftUI hierarchy. Window-level installation
/// remains the separate responsibility of `WindowModalRenderer`.
@MainActor
public final class SwiftUIModalRenderer: ObservableObject, ModalRenderer {

    /// Builds `(ModalProperties?, ModalContent)` for a descriptor. `resolve` closes over the token
    /// gate.
    public typealias Factory<D: ModalDescriptor> =
        (D, @escaping (D.Result) -> Void) -> (ModalProperties?, ModalContent)

    /// Builds the SwiftUI body for a descriptor. This seam makes bespoke descriptors
    /// (`TextInputDialog` and friends) renderable, not merely routable.
    public typealias ContentBuilder<D: ModalDescriptor> =
        (D, @escaping (D.Result) -> Void) -> AnyView

    // MARK: - Presentation

    /// One live presentation.
    public struct Presentation: Identifiable {
        public let id: ModalID
        /// INTERNAL bookkeeping, same status as on `SwiftUIModalRenderer.Presentation`: a host draws
        /// from `properties`/`tokens`/`content`, never from this.
        let resolved: ResolvedModal
        let holder: ModalContent
        /// The EFFECTIVE `ModalProperties` this presentation was resolved and tokenised with.
        public let properties: ModalProperties
        public let tokens: ModalTokens
        /// Standard-family content projected into `AlertDialog`. `nil` for a bespoke descriptor
        /// registered through `register(_:view:)`, which carries no `StandardAlertContent`.
        public let content: AlertDialog?
        /// The consumer's own SwiftUI body, built ONCE per present/refresh by the `register(_:view:)`
        /// builder with the gate already bound. `ModalHost` draws this in PREFERENCE to
        /// `content` when both exist — same precedence `ModalPresentationBody.view(for:)` uses.
        public let customContent: AnyView?
        public var isHidden: Bool
        public let onAction: (ModalAction) -> Void
    }

    // MARK: - Registry

    /// A descriptor kind's registration. Same shape as `SwiftUIModalRenderer.Registration`, retyped.
    private struct Registration<D: ModalDescriptor> {
        let factory: (D, @escaping (D.Result) -> Void) -> (ModalProperties?, ModalContent)
        let route: ((ModalAction) -> D.Result)?
        let content: ((D) -> AlertDialog)?
        let view: ContentBuilder<D>?
    }

    /// Per-presentation teardown/rebuild/route handles. Same role as `SwiftUIModalRenderer.Live`.
    struct Live {
        let resolveDismissed: () -> Void
        let rebuild: (Any) -> Void
        let route: ((ModalAction) -> Void)?
    }

    @Published public private(set) var presentations: [Presentation] = []

    private var registrations: [ObjectIdentifier: Any] = [:]
    private var styleProperties: [ModalStyle: ModalProperties] = [:]
    var live: [ModalID: Live] = [:]   // internal for @testable assertions, as on the other renderers

    /// Same diagnostic hook, same default, as `UIKitModalRenderer`/`SwiftUIModalRenderer` — symmetric
    /// across all three backends.
    public var onUnregisteredDescriptor: ((Any.Type) -> Void)? = { type in
        ModalDiagnostics.logUnregisteredDescriptor(type, renderer: "SwiftUIModalRenderer")
    }

    // MARK: - Init

    /// Registers the unified standard `AlertDialog`. Consumer descriptor kinds register through
    /// `register(_:factory:)`/`register(_:route:factory:)`.
    public init(alertProperties: ModalProperties) {
        styleProperties[.standard] = alertProperties
        registerStandard(AlertDialog.self)
    }

    /// Register a design-system preset under a `ModalStyle` token. Source-identical rule to both
    /// existing renderers, so a consumer's preset table is portable across all three verbatim.
    public func register(style: ModalStyle, properties: ModalProperties) {
        styleProperties[style] = properties
    }

    /// Fallback: an unregistered style resolves to `.standard`, never traps, never renders un-styled.
    public func properties(for style: ModalStyle) -> ModalProperties? {
        styleProperties[style] ?? styleProperties[.standard]
    }

    public func isRegistered(style: ModalStyle) -> Bool {
        styleProperties[style] != nil
    }

    /// Register a factory for a descriptor kind. No `ActionType -> Result` mapping — use
    /// `register(_:route:factory:)` for anything a user can act on.
    ///
    /// Re-registering an already-registered kind PRESERVES its routing/content, same rule as the
    /// other two renderers — overriding the built-in `AlertDialog` factory is a
    /// documented extension point, not a reset.
    public func register<D: ModalDescriptor>(_ type: D.Type, factory: @escaping Factory<D>) {
        let previous = registrations[ObjectIdentifier(type)] as? Registration<D>
        registrations[ObjectIdentifier(type)] = Registration<D>(
            factory: factory, route: previous?.route, content: previous?.content, view: previous?.view
        )
    }

    /// Register a factory together with the `ActionType -> Result` mapping — the counterpart of
    /// `DataHolder.completion` on this backend.
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

    /// Register the SwiftUI body for a descriptor kind — the seam that makes a bespoke descriptor
    /// RENDERABLE, not merely routable. Same rules as `SwiftUIModalRenderer.register(_:view:)`:
    /// registering a view does NOT require a factory (a neutral `(nil, ModalContent())` is installed
    /// so the presentation still exists and is still tearable-down), and the two registrations are
    /// independent — neither clears the other.
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

    /// OPT-IN registration of the five bespoke descriptors, same rule as
    /// `SwiftUIModalRenderer.registerBuiltInDescriptors()`: each kind gets BOTH halves (a factory, so
    /// `Presentation.properties`/`.tokens` derive from real `ModalProperties`, and a `view`, so
    /// `ModalHost` has a body to draw) — the view constructions are VERBATIM the same view
    /// types `SwiftUIModalRenderer+BespokeViews.swift`/`+InputViews.swift` already use, since those
    /// are top-level, UIKit-free, and were never coupled to that renderer's registry.
    ///
    /// Deliberately NOT called from `init` — same reasoning as the other two renderers.
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

    /// The standard family, same shape as `SwiftUIModalRenderer.registerStandard` — `ModalContent
    /// .make`, not `UIKitModalRenderer.AlertHolder.make`; `resolve` unused for the same reason.
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

        var didResolve = false
        let gate: (D.Result) -> Void = { [weak self] result in
            guard !didResolve else { return }
            didResolve = true
            self?.teardown(id)
            resolve(result)
        }

        let (properties, holder) = registration.factory(descriptor, gate)

        var router: ((ModalAction) -> Void)?
        if let route = registration.route {
            router = { action in gate(route(action)) }
        }

        live[id] = Live(
            resolveDismissed: { gate(D.dismissedResult) },
            rebuild: { [weak self] anyDescriptor in
                guard let self, let next = anyDescriptor as? D else { return }
                let (nextProperties, nextHolder) = registration.factory(next, gate)
                self.refresh(
                    id,
                    properties: nextProperties,
                    holder: nextHolder,
                    content: registration.content?(next),
                    // Rebuilt from the NEW descriptor, symmetrically with `content` — same identity
                    // note `SwiftUIModalRenderer.present`'s rebuild carries: this does NOT reset the
                    // view's `@State` (same concrete body type at the same `ForEach` identity).
                    customContent: registration.view?(next, gate)
                )
            },
            route: router
        )

        presentations.append(
            makePresentation(
                id: id,
                properties: properties,
                holder: holder,
                content: registration.content?(descriptor),
                customContent: registration.view?(descriptor, gate),
                isHidden: false,
                onAction: { [weak self] action in
                    guard let route = self?.live[id]?.route else { return }
                    route(action)
                }
            )
        )
    }

    public func update<D: ModalDescriptor>(_ id: ModalID, to descriptor: D) {
        live[id]?.rebuild(descriptor)
    }

    public func dismiss(_ id: ModalID) {
        live[id]?.resolveDismissed()
    }

    public func setHidden(_ id: ModalID, _ isHidden: Bool) {
        guard let index = presentations.firstIndex(where: { $0.id == id }) else { return }
        presentations[index].isHidden = isHidden
    }

    // MARK: - Internals

    /// Builds a `Presentation` via the SAME shared chain every backend uses: `GBAlertModal.resolve`
    /// for structure, `ModalTokens(from:)` for styling — over the effective `ModalProperties`.
    /// Portrait-only for the same reason `SwiftUIModalRenderer.makePresentation` is: the value never
    /// reaches a renderer (`ModalHost` reads `properties`/`tokens`, never `resolved`), and the
    /// one orientation-sensitive resolver output every shipped preset states identically either way.
    private func makePresentation(
        id: ModalID,
        properties: ModalProperties?,
        holder: ModalContent,
        content: AlertDialog?,
        customContent: AnyView?,
        isHidden: Bool,
        onAction: @escaping (ModalAction) -> Void
    ) -> Presentation {
        let effective = properties ?? ModalProperties()
        return Presentation(
            id: id,
            resolved: GBAlertModal.resolve(inputs: effective, content: holder, isLandscape: false),
            holder: holder,
            properties: effective,
            tokens: ModalTokens(from: effective),
            content: content,
            customContent: customContent,
            isHidden: isHidden,
            onAction: onAction
        )
    }

    /// Re-derives a live presentation from a rebuilt `(ModalProperties?, ModalContent)`, preserving
    /// identity, hidden state and action channel.
    private func refresh(
        _ id: ModalID,
        properties: ModalProperties?,
        holder: ModalContent,
        content: AlertDialog?,
        customContent: AnyView?
    ) {
        guard let index = presentations.firstIndex(where: { $0.id == id }) else { return }
        let previous = presentations[index]
        presentations[index] = makePresentation(
            id: id,
            properties: properties,
            holder: holder,
            content: content,
            customContent: customContent,
            isHidden: previous.isHidden,
            onAction: previous.onAction
        )
    }

    /// The single teardown funnel — every resolve path lands here exactly once.
    ///
    /// Same split `SwiftUIModalRenderer.teardown` uses: `live[id] = nil` is synchronous (the
    /// coordinator's `finish()` needs it to advance the queue immediately), only the visual removal
    /// animates — `withAnimation` wraps the `presentations` mutation so `ModalHost`'s
    /// `.transition(.opacity)` fades the row out over the same 0.2s `GBAlertModal.hide()` uses,
    /// rather than the row vanishing instantly. `present`'s `presentations.append` stays unwrapped,
    /// so appearing is still instant — matching UIKit's un-animated `show()`.
    private func teardown(_ id: ModalID) {
        live[id] = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            presentations.removeAll { $0.id == id }
        }
    }
}
