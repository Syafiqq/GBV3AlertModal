import Combine // `ObservableObject`/`@Published` (SwiftUI re-exports these; imported explicitly).
import SwiftUI
import UIKit // `Properties`/`DataHolder`/`ResolvedModal` are UIKit-region types; free on iOS.

/// The SwiftUI backend for `ModalRenderer`. Deliberately the SAME SHAPE as `UIKitModalRenderer`:
/// a factory registry keyed by `ObjectIdentifier(D.self)`, a resolve-once `gate` per presentation,
/// a `live` dictionary, and one `teardown` funnel every path goes through. It maps descriptors with
/// the SAME `UIKitModalRenderer.AlertHolder.make`, resolves structure with the SAME
/// `GBAlertModal.resolve`, and derives styling with the SAME `ModalTokens(from:)` — so the two
/// renderers differ only in the final render step, which is exactly what makes the executor test
/// suite runnable against both.
///
/// **Why `holder.completion` is unused here.** `DataHolder.completion` is
/// `((GBAlertModal, GBAlertModal.ActionType) -> Void)?` — it demands a non-optional `GBAlertModal`
/// INSTANCE, a UIKit view this renderer never builds. So `AlertHolder.make` is used for CONTENT
/// MAPPING ONLY and view interactions are routed through this renderer's own resolve-once gate
/// (see `Registration.route`).
@MainActor
public final class SwiftUIModalRenderer: ObservableObject, ModalRenderer {

    /// Builds `(Properties?, DataHolder)` for a descriptor. `resolve` closes over the token gate.
    /// Identical to `UIKitModalRenderer.Factory` so a consumer's custom registration is portable
    /// between the two renderers verbatim.
    public typealias Factory<D: ModalDescriptor> =
        (D, @escaping (D.Result) -> Void) -> (GBAlertModal.Properties?, GBAlertModal.DataHolder)

    // MARK: - Presentation

    /// One live presentation: everything a SwiftUI view needs to draw it, plus the only channel
    /// through which that view may resolve it.
    ///
    /// `resolved`/`tokens` are computed HERE (not in the view) from the real caller-supplied
    /// `properties`, so the renderer's state is the single source of truth a parity test can read
    /// without hosting a view.
    public struct Presentation: Identifiable {
        public let id: ModalID
        public let resolved: GBAlertModal.ResolvedModal
        public let holder: GBAlertModal.DataHolder
        /// The EFFECTIVE `Properties` this presentation was resolved and tokenised with — the ones
        /// the factory returned, i.e. the caller's real `alertProperties`/`popupProperties`.
        public let properties: GBAlertModal.Properties
        public let tokens: ModalTokens
        /// Standard-family content projected into `AlertDialog` (the shape `SwiftUIAlertModal`
        /// renders). `nil` for descriptors registered through `register(_:factory:)`, which carry
        /// no `StandardAlertContent` and therefore no built-in SwiftUI body — `ModalHost` draws
        /// nothing for those; a consumer hosts them itself off `holder`/`resolved`.
        public let content: AlertDialog?
        public var isHidden: Bool
        /// The view's ONLY way to resolve this presentation. Speaks `GBAlertModal.ActionType`, the
        /// same vocabulary `DataHolder.completion` uses, and is a no-op once the modal is torn down.
        public let onAction: (GBAlertModal.ActionType) -> Void
    }

    // MARK: - Registry

    /// A descriptor kind's registration. Bundling the factory with its (optional) action router and
    /// content projection is what makes routing statically type-safe: both are BUILT where `D` is
    /// concretely known, and recovered later by casting a STRUCT (`Any -> Registration<D>`), never
    /// by casting a function type — `gate as? (AlertDialog.Result) -> Void` is unreliable in Swift
    /// and fails silently in release builds.
    private struct Registration<D: ModalDescriptor> {
        let factory: Factory<D>
        /// `ActionType -> D.Result`. Supplied by `registerStandard` for the standard family (where
        /// the same-type constraint `D.Result == AlertDialog.Result` makes the mapping type-check
        /// at compile time), or by the consumer via `register(_:route:factory:)`.
        let route: ((GBAlertModal.ActionType) -> D.Result)?
        /// `D -> AlertDialog`. Non-nil only for the standard family (`D: StandardAlertContent`);
        /// custom descriptors have no SwiftUI body — see `register(_:route:factory:)`.
        let content: ((D) -> AlertDialog)?
    }

    /// Per-presentation teardown/rebuild/route handles. Mirrors `UIKitModalRenderer.Live`; the one
    /// missing field is the UIKit view, which this renderer has no equivalent of — the SwiftUI
    /// "view" is the `Presentation` value in `presentations`.
    struct Live {                      // internal, so `live` below can be too
        let resolveDismissed: () -> Void
        let rebuild: (Any) -> Void
        let route: ((GBAlertModal.ActionType) -> Void)?
    }

    @Published public private(set) var presentations: [Presentation] = []

    private var registrations: [ObjectIdentifier: Any] = [:]
    var live: [ModalID: Live] = [:]   // internal for @testable assertions, as in UIKitModalRenderer

    // MARK: - Init

    public init(
        alertProperties: GBAlertModal.Properties,
        popupProperties: GBAlertModal.Properties? = nil
    ) {
        registerStandard(AlertDialog.self, properties: alertProperties)
        // PopupDialog shares AlertDialog's content + result; only the Properties (style) differ.
        // Registered only when the consumer supplies popup styling — same rule as UIKit.
        if let popupProperties {
            registerStandard(PopupDialog.self, properties: popupProperties)
        }
    }

    /// Register a factory for a descriptor kind — the signature that is source-identical to
    /// `UIKitModalRenderer.register(_:factory:)`.
    ///
    /// A descriptor registered through THIS overload has no `ActionType -> Result` mapping, because
    /// only the consumer knows its result vocabulary. `holder.completion` (which is how the UIKit
    /// renderer routes such a descriptor) is unusable here — it demands a `GBAlertModal` instance —
    /// so the modal would be unresolvable by user action. Use `register(_:route:factory:)` instead
    /// for anything a user can act on; this overload is for descriptors that only ever end via
    /// `dismiss(_:)`.
    ///
    /// **Re-registering an already-registered kind PRESERVES its routing and content projection.**
    /// Overriding the built-in `AlertDialog`/`PopupDialog` factory is a documented extension point
    /// on the UIKit renderer, and wiping the router here would silently produce a modal that
    /// renders nothing and can never be resolved.
    public func register<D: ModalDescriptor>(_ type: D.Type, factory: @escaping Factory<D>) {
        let previous = registrations[ObjectIdentifier(type)] as? Registration<D>
        registrations[ObjectIdentifier(type)] = Registration<D>(
            factory: factory, route: previous?.route, content: previous?.content
        )
    }

    /// Register a factory together with the `ActionType -> Result` mapping the view needs to
    /// resolve it — the SwiftUI counterpart of the `holder.completion` closure a consumer writes
    /// for `UIKitModalRenderer`. The consumer supplies the mapping where `D` is concrete, so it
    /// stays fully static: nothing is cast, here or in `present`.
    ///
    /// This is what makes consumer-defined descriptors (`StepDialog`, `TextInputDialog`,
    /// `DatePickerDialog`, …) resolvable on BOTH backends, and therefore what lets the
    /// renderer-agnostic executor suite cover the extension point rather than silently narrowing
    /// to the standard family.
    ///
    /// KNOWN GAP, stated plainly: this routes such a descriptor, it does not RENDER it.
    /// `Presentation.content` stays `nil` (there is no `StandardAlertContent` to project from), so
    /// `ModalHost` draws nothing for it — a consumer hosts its own SwiftUI body off
    /// `Presentation.holder`/`.resolved`/`.onAction`. Custom-content rendering is genuinely not
    /// implemented on the SwiftUI path.
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

    /// The standard family (`AlertDialog`, `PopupDialog`, …) all resolve to `AlertDialog.Result`
    /// — verified: `PopupDialog` declares `typealias Result = AlertDialog.Result`. Constraining on
    /// that same-type requirement is what makes the `ActionType -> Result` mapping STATICALLY
    /// type-safe: inside this method `D.Result` canonicalises to `AlertDialog.Result`, so the
    /// router below is an ordinary typed closure rather than a runtime cast.
    ///
    /// The three-case mapping is the same switch `AlertHolder.make` performs on the UIKit path;
    /// they must stay identical.
    private func registerStandard<D>(
        _ type: D.Type, properties: GBAlertModal.Properties
    ) where D: ModalDescriptor & StandardAlertContent, D.Result == AlertDialog.Result {
        let factory: Factory<D> = { descriptor, resolve in
            (properties, UIKitModalRenderer.AlertHolder.make(for: descriptor, resolve: resolve))
        }
        let route: (GBAlertModal.ActionType) -> AlertDialog.Result = { action in
            switch action {
            case .primary: return AlertDialog.Result.primary
            case .secondary: return AlertDialog.Result.secondary
            case .close: return AlertDialog.Result.dismissed
            }
        }
        // Lossless within `StandardAlertContent` — every field of the protocol is carried over.
        let content: (D) -> AlertDialog = { descriptor in
            AlertDialog(
                image: descriptor.image,
                title: descriptor.title,
                subtitle: descriptor.subtitle,
                primary: descriptor.primary,
                secondary: descriptor.secondary,
                closeOnTapOverlay: descriptor.closeOnTapOverlay,
                showCloseButton: descriptor.showCloseButton
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
            // Same graceful resolve `UIKitModalRenderer` performs — one shared, tested behaviour.
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

        // ACTION ROUTING. `route` is `(ActionType) -> D.Result` and `gate` is `(D.Result) -> Void`,
        // so this composition type-checks statically — `D` is concrete at this point and no closure
        // is ever cast.
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
                // Resolved through `live` at call time, so a torn-down presentation held by a stale
                // SwiftUI view can no longer resolve anything.
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
        // Visibility only: the presentation stays in `presentations` and `live`, and its gate is
        // untouched — matching UIKit's `modal.isHidden` toggle.
        guard let index = presentations.firstIndex(where: { $0.id == id }) else { return }
        presentations[index].isHidden = isHidden
    }

    // MARK: - Internals

    /// Builds a `Presentation` by running the SHARED chain: `GBAlertModal.resolve` for structure and
    /// `ModalTokens(from:)` for styling, both over the EFFECTIVE properties.
    ///
    /// `isLandscape: false` matches the SwiftUI card, which is width-adaptive rather than
    /// orientation-switched; it is the one resolver input that is still fixed here.
    private func makePresentation(
        id: ModalID,
        properties: GBAlertModal.Properties?,
        holder: GBAlertModal.DataHolder,
        content: AlertDialog?,
        isHidden: Bool,
        onAction: @escaping (GBAlertModal.ActionType) -> Void
    ) -> Presentation {
        let effective = properties ?? GBAlertModal.Properties()
        return Presentation(
            id: id,
            resolved: GBAlertModal.resolve(
                properties: effective, holder: holder, isLandscape: false
            ),
            holder: holder,
            properties: effective,
            tokens: ModalTokens(from: effective),
            content: content,
            isHidden: isHidden,
            onAction: onAction
        )
    }

    /// Re-derives a live presentation from a rebuilt `(Properties?, DataHolder)`, preserving its
    /// identity, hidden state and action channel — the SwiftUI counterpart of
    /// `GBAlertModal.updateDialog(holder:properties:)`.
    private func refresh(
        _ id: ModalID,
        properties: GBAlertModal.Properties?,
        holder: GBAlertModal.DataHolder,
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

    /// The single teardown funnel — every resolve path (gate → user action, dismiss, executor
    /// teardown) lands here exactly once.
    private func teardown(_ id: ModalID) {
        presentations.removeAll { $0.id == id }
        live[id] = nil
    }
}
