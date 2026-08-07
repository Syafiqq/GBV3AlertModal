import UIKit
@testable import GBV3AlertModal

/// The backends behind `ModalRenderer`. Parity tests loop this so a failure message can name
/// the offending kind (spec C-2).
///
/// `.embedded` (`EmbeddedModalRenderer`) is UIKit-vocabulary-free and, in this increment, registers
/// only the standard family — `effectiveProperties(_:)`/`registerCustom(...)` below are intentionally
/// NOT generalized to it (they're UIKit-typed by design), so tests using either method must loop
/// `[.uiKit, .swiftUI]` explicitly rather than `.allCases`.
enum RendererKind: String, CaseIterable {
    case uiKit
    case swiftUI
    case embedded
}

/// A renderer-agnostic driver for the parity gate.
///
/// **Why this is a harness and not the plan's bare `makeRenderer(_:) -> ModalRenderer`.** Three
/// things a parity test needs are NOT on the `ModalRenderer` protocol, and each of them differs in
/// its CALL SITE (never in its meaning) between the backends:
///
/// 1. **Lifetime.** `UIKitModalRenderer` needs a `UIWindow` that outlives the test; a factory that
///    creates one inline hands back a renderer whose window is already deallocated.
/// 2. **Interaction.** A "user tap" is `GBAlertModal.dismissAndEmit(event:)` on UIKit and
///    `Presentation.onAction(_:)` on SwiftUI. Both speak `GBAlertModal.ActionType`, so the harness
///    exposes ONE `emit(_:on:)` and the tests share it.
/// 3. **Registration of consumer descriptors.** VERIFIED CONSTRAINT: these are resolvable on both
///    backends but not through a source-identical call. UIKit embeds the routing in
///    `DataHolder.completion` (its native path); SwiftUI has no `completion` mechanism at all — the
///    routing is supplied explicitly to `register(_:route:factory:)`. `registerCustom` below is the
///    ONLY place that branches: the descriptor, the content mapping, the `ActionType -> Result`
///    route, the interactions and the assertions are all shared. If each backend got its own route
///    or its own assertions this would not be a parity test.
///
/// Everything else the harness exposes (`isLive`, `liveCount`, `isHidden`, `resolvedSubtitle`) is a
/// projection of renderer state that BOTH backends genuinely have, read through the same `ModalID`,
/// so one assertion can be written against both.
@MainActor
final class RendererHarness {

    /// The concrete backend. Held as an enum rather than closures so every branch is exhaustively
    /// checked by the compiler and no behaviour can silently go untested on one side.
    private enum Box {
        case uiKit(UIKitModalRenderer)
        case swiftUI(SwiftUIModalRenderer)
        case embedded(EmbeddedModalRenderer)
    }

    let kind: RendererKind
    /// Retained for the lifetime of the harness — `UIKitModalRenderer` only holds it via a
    /// `windowProvider` closure, so nothing else keeps it alive.
    private let window: UIWindow?
    private let box: Box

    /// Both backends are configured with the SAME `alertProperties` and the SAME `popupProperties`,
    /// so any difference a parity test observes is the renderer and not its styling input.
    init(_ kind: RendererKind) {
        self.kind = kind
        switch kind {
        case .uiKit:
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.makeKeyAndVisible()
            self.window = window
            self.box = .uiKit(
                UIKitModalRenderer(
                    alertProperties: GeniePresets.standardProperties(),
                    popupProperties: GeniePresets.popupProperties(),
                    windowProvider: { window }
                )
            )
        case .swiftUI:
            self.window = nil
            self.box = .swiftUI(
                SwiftUIModalRenderer(
                    alertProperties: GeniePresets.standardProperties(),
                    popupProperties: GeniePresets.popupProperties()
                )
            )
        case .embedded:
            self.window = nil
            self.box = .embedded(
                EmbeddedModalRenderer(
                    alertProperties: GeniePresets.standardModalProperties(),
                    popupProperties: GeniePresets.popupModalProperties()
                )
            )
        }
    }

    /// The backend under the protocol every parity test drives it through.
    var renderer: ModalRenderer {
        switch box {
        case .uiKit(let backend): return backend
        case .swiftUI(let backend): return backend
        case .embedded(let backend): return backend
        }
    }

    // MARK: - Interaction (the shared stand-in for a user tap)

    /// Drive a user action on a LIVE presentation, looked up by `id`.
    ///
    /// UIKit routes through the real `GBAlertModal` (its completion → the renderer's gate); SwiftUI
    /// routes through the real `Presentation.onAction` (its route → the renderer's gate). Both are
    /// the production path a tap takes, and both speak `GBAlertModal.ActionType`.
    func emit(_ action: GBAlertModal.ActionType, on id: ModalID) {
        switch box {
        case .uiKit(let backend):
            backend.live[id]?.modal.dismissAndEmit(event: action)
        case .swiftUI(let backend):
            backend.presentations.first(where: { $0.id == id })?.onAction(action)
        case .embedded(let backend):
            backend.presentations.first(where: { $0.id == id })?.onAction(action)
        }
    }

    /// A handle captured NOW and deliberately used AFTER the presentation is torn down — the stale
    /// view handle a real UI holds across teardown, on both backends. Distinct from `emit(_:on:)`,
    /// which re-looks-up by id and therefore cannot exercise the stale case at all.
    func staleEmitter(for id: ModalID) -> @MainActor (GBAlertModal.ActionType) -> Void {
        switch box {
        case .uiKit(let backend):
            // The `GBAlertModal` instance keeps its `dataHolder.completion` across `hide()`, so a
            // post-teardown call really does reach the renderer's gate and is stopped by its
            // `didResolve` flag — this is not a vacuous no-op on the UIKit side.
            let modal = backend.live[id]?.modal
            return { action in
                guard let modal else { return }
                modal.dismissAndEmit(event: action)
            }
        case .swiftUI(let backend):
            let onAction = backend.presentations.first(where: { $0.id == id })?.onAction
            return { action in
                guard let onAction else { return }
                onAction(action)
            }
        case .embedded(let backend):
            let onAction = backend.presentations.first(where: { $0.id == id })?.onAction
            return { action in
                guard let onAction else { return }
                onAction(action)
            }
        }
    }

    // MARK: - Observable renderer state (shared projections)

    /// Is `id` still a live presentation? Both renderers keep the same `live: [ModalID: Live]`
    /// registry and both clear it in `teardown`.
    func isLive(_ id: ModalID) -> Bool {
        switch box {
        case .uiKit(let backend): return backend.live[id] != nil
        case .swiftUI(let backend): return backend.live[id] != nil
        case .embedded(let backend): return backend.live[id] != nil
        }
    }

    /// How many presentations are live — catches "resolved but never torn down" and
    /// "update created a second presentation" on both backends.
    var liveCount: Int {
        switch box {
        case .uiKit(let backend): return backend.live.count
        case .swiftUI(let backend): return backend.live.count
        case .embedded(let backend): return backend.live.count
        }
    }

    /// The presentation's hidden flag: `UIView.isHidden` on UIKit, `Presentation.isHidden` on
    /// SwiftUI/embedded. `nil` when there is no live presentation for `id`.
    func isHidden(_ id: ModalID) -> Bool? {
        switch box {
        case .uiKit(let backend): return backend.live[id]?.modal.isHidden
        case .swiftUI(let backend): return backend.presentations.first(where: { $0.id == id })?.isHidden
        case .embedded(let backend): return backend.presentations.first(where: { $0.id == id })?.isHidden
        }
    }

    /// The `Properties` the LIVE presentation for `id` was actually built with — i.e. the renderer's
    /// STYLING DECISION, which is what a `ModalStyle` parity test needs to compare.
    ///
    /// CAVEAT, so assertions stay honest: UIKit returns `GBAlertModal.properties`, which
    /// `updateProperties` has already MERGED field-by-field against `globalProperties`; SwiftUI
    /// returns the un-merged `Presentation.properties`. `globalProperties` is an all-`nil`
    /// `Properties()` unless a consumer sets it, so the merge is a no-op — but only assert on fields
    /// the fixture sets EXPLICITLY (`GeniePresets.badgeProperties()` is built for exactly this), or
    /// a `nil` field could read differently on the two sides for reasons that are not the renderer.
    func effectiveProperties(_ id: ModalID) -> GBAlertModal.Properties? {
        switch box {
        case .uiKit(let backend):
            return backend.live[id]?.modal.properties
        case .swiftUI(let backend):
            return backend.presentations.first(where: { $0.id == id })?.properties
        case .embedded:
            // Deliberately unsupported: `EmbeddedModalRenderer.Presentation.properties` is
            // `ModalProperties`, not `GBAlertModal.Properties` — there is no UIKit-typed value to
            // return here without an adapter the plan explicitly declined to build. `nil` fails
            // loud (via `XCTUnwrap`) rather than silently comparing the wrong type. Callers of this
            // method must loop `[.uiKit, .swiftUI]` explicitly, never `.allCases`.
            return nil
        }
    }

    /// The subtitle RENDER DECISION for `id`, read through the SAME pure resolver
    /// (`GBAlertModal.resolve`) on both backends — UIKit via the live view's `makeResolvedModal()`,
    /// SwiftUI via the `Presentation.resolved` it computed at present/refresh time.
    ///
    /// Deliberately the `subtitle` field and not, say, `contentWidth`: subtitle resolution is
    /// orientation-independent, whereas UIKit derives `isLandscape` from the live view's bounds and
    /// SwiftUI pins it to `false`. Asserting on an orientation-dependent field would report a
    /// difference in test scaffolding as a renderer divergence.
    func resolvedSubtitle(_ id: ModalID) -> GBAlertModal.ResolvedModal.SubtitleKind? {
        switch box {
        case .uiKit(let backend):
            return backend.live[id]?.modal.makeResolvedModal().subtitle
        case .swiftUI(let backend):
            return backend.presentations.first(where: { $0.id == id })?.resolved.subtitle
        case .embedded(let backend):
            return backend.presentations.first(where: { $0.id == id })?.resolved.subtitle
        }
    }

    // MARK: - Registration

    /// Register a CONSUMER-DEFINED descriptor on whichever backend this harness wraps.
    ///
    /// The two arguments that carry meaning — `holder` (descriptor → content) and `route`
    /// (`ActionType` → the descriptor's own `Result` vocabulary) — are supplied ONCE by the caller
    /// and used by both branches. Only the wiring differs, and only because the backends genuinely
    /// differ there:
    ///
    /// - UIKit: the route is injected into `DataHolder.completion`, which is how a UIKit consumer
    ///   writes it today (see `ExecutorStatefulTests` / `UIKitModalRenderer+InputHolders`).
    /// - SwiftUI: `DataHolder.completion` demands a `GBAlertModal` instance this renderer never
    ///   builds, so the route is handed to `register(_:route:factory:)` instead.
    ///
    /// `route` is intentionally a PURE `(ActionType) -> D.Result` function: that is the whole of
    /// what THIS harness needs, and it keeps the parity assertions identical on both sides.
    ///
    /// It is NOT the limit of either backend any more. A result whose payload is read from a live
    /// input view at resolve time (`TextInputDialog.submitted(String)`) is expressible on UIKit via
    /// `holder.completion` and on SwiftUI via `SwiftUIModalRenderer.register(_:view:)`, whose view
    /// is handed the resolve gate directly — see `SwiftUICustomContentTests`.
    func registerCustom<D: ModalDescriptor>(
        _ type: D.Type,
        properties: GBAlertModal.Properties,
        holder: @escaping (D) -> GBAlertModal.DataHolder,
        route: @escaping (GBAlertModal.ActionType) -> D.Result
    ) {
        switch box {
        case .uiKit(let backend):
            backend.register(type) { descriptor, resolve in
                (
                    properties,
                    holder(descriptor).copy(completion: { _, action in resolve(route(action)) })
                )
            }
        case .swiftUI(let backend):
            backend.register(type, route: route) { descriptor, _ in
                (properties, holder(descriptor))
            }
        case .embedded:
            // Deliberately unsupported: `holder`/`properties` are UIKit-typed
            // (`GBAlertModal.DataHolder`/`.Properties`), and `EmbeddedModalRenderer.Factory` takes
            // `ModalProperties`/`ModalContent` — there is no adapter between them the plan declined
            // to build. Fails LOUD (not a silent no-registration, which would let the test proceed
            // and misreport as "unregistered descriptor" instead of naming this method as the cause).
            // Callers must loop `[.uiKit, .swiftUI]` explicitly, never `.allCases`.
            fatalError(
                "RendererHarness.registerCustom is not supported for .embedded — "
                    + "loop [.uiKit, .swiftUI] explicitly"
            )
        }
    }

    /// Register a `ModalStyle` preset on whichever backend this harness wraps.
    ///
    /// Both branch bodies are LITERALLY THE SAME EXPRESSION —
    /// `register(style:properties:)` is source-identical across the backends, by design. The
    /// `switch` exists only because Swift needs a concrete receiver to pick the overload; there is
    /// no semantic branch here, and that is precisely the claim the style parity test verifies.
    ///
    /// `properties` is `GBAlertModal.Properties`-typed, so `.embedded` (whose `register(style:
    /// properties:)` wants `ModalProperties`) is deliberately unsupported here too, same reasoning
    /// as `registerCustom` — fails loud rather than silently mistyping. `EmbeddedModalRendererTests`
    /// covers `.embedded`'s own style registration directly, in its own vocabulary.
    func register(style: ModalStyle, properties: GBAlertModal.Properties) {
        switch box {
        case .uiKit(let backend): backend.register(style: style, properties: properties)
        case .swiftUI(let backend): backend.register(style: style, properties: properties)
        case .embedded:
            fatalError(
                "RendererHarness.register(style:properties:) is not supported for .embedded — "
                    + "loop [.uiKit, .swiftUI] explicitly"
            )
        }
    }

    /// Whether `style` has a preset of its own on this backend — what makes a FALLBACK to
    /// `.standard` distinguishable from a deliberate `.standard`.
    func isRegistered(style: ModalStyle) -> Bool {
        switch box {
        case .uiKit(let backend): return backend.isRegistered(style: style)
        case .swiftUI(let backend): return backend.isRegistered(style: style)
        case .embedded(let backend): return backend.isRegistered(style: style)
        }
    }

    /// Re-register the built-in `AlertDialog` with a different `Properties` — the documented
    /// factory-override extension point.
    ///
    /// The two branch bodies are LITERALLY THE SAME EXPRESSION: `register(_:factory:)` is
    /// source-identical across the backends. The `switch` exists only because Swift needs a
    /// concrete receiver to pick the overload; there is no semantic branch here.
    func reRegisterStandardAlertFactory(properties: GBAlertModal.Properties) {
        switch box {
        case .uiKit(let backend):
            backend.register(AlertDialog.self) { descriptor, resolve in
                (properties, UIKitModalRenderer.AlertHolder.make(for: descriptor, resolve: resolve))
            }
        case .swiftUI(let backend):
            backend.register(AlertDialog.self) { descriptor, resolve in
                (properties, UIKitModalRenderer.AlertHolder.make(for: descriptor, resolve: resolve))
            }
        case .embedded:
            // Same UIKit-typed-argument reasoning as `registerCustom`/`register(style:properties:)`.
            fatalError(
                "RendererHarness.reRegisterStandardAlertFactory is not supported for .embedded — "
                    + "loop [.uiKit, .swiftUI] explicitly"
            )
        }
    }
}
