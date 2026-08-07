import Combine // `ObservableObject`/`@Published` (SwiftUI re-exports these; imported explicitly).
import SwiftUI

/// **The genuinely UIKit-free SwiftUI backend for `ModalRenderer`.**
///
/// Same shape as `SwiftUIModalRenderer` — a factory registry keyed by `ObjectIdentifier(D.self)`, a
/// resolve-once `gate` per presentation, a `live` dictionary, one `teardown` funnel — but its PUBLIC
/// vocabulary names no UIKit type anywhere: `Factory<D>` returns `(ModalProperties?, ModalContent)`,
/// not `(GBAlertModal.Properties?, GBAlertModal.DataHolder)`. Deliberately NOT sharing code with
/// `SwiftUIModalRenderer` — that type's registry is structurally tied to its own frozen public
/// `Factory<D>` (an owner decision, kept non-breaking for existing callers); this is a separate,
/// parallel implementation, the same relationship `UIKitModalRenderer` and `SwiftUIModalRenderer`
/// already have with each other.
///
/// Scoped, for now, to the standard family (`AlertDialog`/`PopupDialog`) — see `init`. The bespoke
/// descriptors (`TextInputDialog` and friends) are a later increment: their SwiftUI bodies
/// (`TextInputContent`, `BadgeContent`, …) are already UIKit-free and reusable unchanged when that
/// happens: only their `Registration` entries need writing, mirroring `SwiftUIModalRenderer
/// .registerBuiltInDescriptors()`.
///
/// Meant to be embedded inside existing content via `EmbeddedModalHost` (a screen-scoped overlay,
/// e.g. `MainTabBarViewController`'s own view hierarchy) — never a separate `UIWindow`. That's the
/// rootRenderer's job, a different presentation scope with its own (later, un-queued) renderer type.
@MainActor
public final class EmbeddedModalRenderer: ObservableObject, ModalRenderer {

    /// Builds `(ModalProperties?, ModalContent)` for a descriptor. `resolve` closes over the token
    /// gate. Same role as `SwiftUIModalRenderer.Factory`, retyped.
    public typealias Factory<D: ModalDescriptor> =
        (D, @escaping (D.Result) -> Void) -> (ModalProperties?, ModalContent)

    // MARK: - Presentation

    /// One live presentation — the UIKit-free mirror of `SwiftUIModalRenderer.Presentation`.
    public struct Presentation: Identifiable {
        public let id: ModalID
        /// INTERNAL bookkeeping, same status as on `SwiftUIModalRenderer.Presentation`: a host draws
        /// from `properties`/`tokens`/`content`, never from this.
        let resolved: GBAlertModal.ResolvedModal
        let holder: ModalContent
        /// The EFFECTIVE `ModalProperties` this presentation was resolved and tokenised with.
        public let properties: ModalProperties
        public let tokens: ModalTokens
        /// Standard-family content projected into `AlertDialog` — always non-nil here, since only
        /// the standard family is registered in this increment.
        public let content: AlertDialog?
        public var isHidden: Bool
        public let onAction: (GBAlertModal.ActionType) -> Void
    }

    // MARK: - Registry

    /// A descriptor kind's registration. Same shape as `SwiftUIModalRenderer.Registration`, retyped.
    private struct Registration<D: ModalDescriptor> {
        let factory: (D, @escaping (D.Result) -> Void) -> (ModalProperties?, ModalContent)
        let route: ((GBAlertModal.ActionType) -> D.Result)?
        let content: ((D) -> AlertDialog)?
    }

    /// Per-presentation teardown/rebuild/route handles. Same role as `SwiftUIModalRenderer.Live`.
    struct Live {
        let resolveDismissed: () -> Void
        let rebuild: (Any) -> Void
        let route: ((GBAlertModal.ActionType) -> Void)?
    }

    @Published public private(set) var presentations: [Presentation] = []

    private var registrations: [ObjectIdentifier: Any] = [:]
    private var styleProperties: [ModalStyle: ModalProperties] = [:]
    var live: [ModalID: Live] = [:]   // internal for @testable assertions, as on the other renderers

    /// Same diagnostic hook, same default, as `UIKitModalRenderer`/`SwiftUIModalRenderer` — symmetric
    /// across all three backends.
    public var onUnregisteredDescriptor: ((Any.Type) -> Void)? = { type in
        ModalDiagnostics.logUnregisteredDescriptor(type, renderer: "EmbeddedModalRenderer")
    }

    // MARK: - Init

    /// Registers ONLY the standard family — `AlertDialog` always, `PopupDialog` when `popupProperties`
    /// is supplied, exactly the rule both existing renderers use. Consumer descriptor kinds register
    /// through `register(_:factory:)`/`register(_:route:factory:)`.
    public init(alertProperties: ModalProperties, popupProperties: ModalProperties? = nil) {
        styleProperties[.standard] = alertProperties
        if let popupProperties {
            styleProperties[.popup] = popupProperties
        }

        registerStandard(AlertDialog.self)
        if popupProperties != nil {
            registerStandard(PopupDialog.self)
        }
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
    /// other two renderers — overriding the built-in `AlertDialog`/`PopupDialog` factory is a
    /// documented extension point, not a reset.
    public func register<D: ModalDescriptor>(_ type: D.Type, factory: @escaping Factory<D>) {
        let previous = registrations[ObjectIdentifier(type)] as? Registration<D>
        registrations[ObjectIdentifier(type)] = Registration<D>(
            factory: factory, route: previous?.route, content: previous?.content
        )
    }

    /// Register a factory together with the `ActionType -> Result` mapping — the counterpart of
    /// `DataHolder.completion` on this backend.
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

        var didResolve = false
        let gate: (D.Result) -> Void = { [weak self] result in
            guard !didResolve else { return }
            didResolve = true
            self?.teardown(id)
            resolve(result)
        }

        let (properties, holder) = registration.factory(descriptor, gate)

        var router: ((GBAlertModal.ActionType) -> Void)?
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
                    content: registration.content?(next)
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
    /// reaches a renderer (`EmbeddedModalHost` reads `properties`/`tokens`, never `resolved`), and the
    /// one orientation-sensitive resolver output every shipped preset states identically either way.
    private func makePresentation(
        id: ModalID,
        properties: ModalProperties?,
        holder: ModalContent,
        content: AlertDialog?,
        isHidden: Bool,
        onAction: @escaping (GBAlertModal.ActionType) -> Void
    ) -> Presentation {
        let effective = properties ?? ModalProperties()
        return Presentation(
            id: id,
            resolved: GBAlertModal.resolve(inputs: effective, content: holder, isLandscape: false),
            holder: holder,
            properties: effective,
            tokens: ModalTokens(from: effective),
            content: content,
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
        content: AlertDialog?
    ) {
        guard let index = presentations.firstIndex(where: { $0.id == id }) else { return }
        let previous = presentations[index]
        presentations[index] = makePresentation(
            id: id,
            properties: properties,
            holder: holder,
            content: content,
            isHidden: previous.isHidden,
            onAction: previous.onAction
        )
    }

    /// The single teardown funnel — every resolve path lands here exactly once.
    private func teardown(_ id: ModalID) {
        presentations.removeAll { $0.id == id }
        live[id] = nil
    }
}
