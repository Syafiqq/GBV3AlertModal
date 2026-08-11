import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// A consumer-defined descriptor with a result vocabulary the library cannot know — the shape the
/// app's own dialogs take (`StepDialog`, the input dialogs, …). Three distinct cases so the
/// `ActionType -> Result` route is exercised in full and no two actions can be confused.
private struct ParityStepDialog: ModalDescriptor {
    enum Result: Sendable, Equatable { case done, skipped, dismissed }
    static var dismissedResult: Result { .dismissed }
    var title: String
}

/// A descriptor that is NEVER registered on either backend. Its `dismissedResult` is deliberately a
/// case no route could ever produce, so asserting on it proves the renderer resolved with
/// `D.dismissedResult` specifically — not with some generic "dismissed" that happens to match.
private struct ParityUnregisteredDialog: ModalDescriptor {
    enum Result: Sendable, Equatable { case neverRoutable, gracefullyDismissed }
    static var dismissedResult: Result { .gracefullyDismissed }
}

/// Consumer-defined style presets, declared the way a consuming app declares its own.
private extension ModalStyle {
    static let parityBadge = ModalStyle("parity.badge")
    /// Never registered on either backend — the fallback probe.
    static let parityGhost = ModalStyle("parity.ghost")
}

/// The renderer's STYLING DECISION for one presentation, reduced to fields that (a) both backends
/// genuinely produce and (b) `GeniePresets.badgeProperties()` sets EXPLICITLY — so UIKit's
/// `globalProperties` merge cannot make two identical decisions read differently.
private struct StylingDecision: Equatable {
    let cornerRadius: CGFloat
    let contentMaxWidth: CGFloat
    let titleColor: UIColor?
    /// The fields added when the `Properties`→`ModalTokens` audit closed three drift channels
    /// (banner geometry, the close-button tint, the secondary label colour). Each is set
    /// EXPLICITLY and non-nil by `GeniePresets.standardProperties()` — which both
    /// `badgeProperties()` and the fallback case inherit — so the UIKit `globalProperties` merge
    /// cannot make two identical decisions read differently. `bannerFixedHeight`/`bannerMaxHeight`
    /// are deliberately NOT here: the preset leaves both nil, and a nil field is exactly what that
    /// merge could fill in from a consumer's globals.
    let bannerRatio: CGFloat?
    let closeButton: Color
    let secondaryLabel: Color
}

/// Built from the SAME `ModalTokens(from:)` derivation on both backends, over the `Properties` each
/// renderer actually presented with.
private func decision(from properties: GBAlertModal.Properties) -> StylingDecision {
    let tokens = ModalTokens(from: properties)
    return StylingDecision(
        cornerRadius: tokens.cornerRadius,
        contentMaxWidth: tokens.contentMaxWidth,
        titleColor: properties.titleColor,
        bannerRatio: tokens.bannerRatio,
        closeButton: tokens.palette.closeButton,
        secondaryLabel: tokens.palette.secondaryLabel
    )
}

/// **C-2 PARITY GATE.** Executor- and coordinator-level semantics run against BOTH `ModalRenderer`
/// backends, with ONE set of assertions.
///
/// Every test here loops `RendererKind.allCases`, builds a `RendererHarness` for that kind, and
/// then shares the descriptor, the interactions and the expectations. The harness is the only place
/// that knows which backend it is talking to, and it branches for exactly three reasons (window
/// lifetime, the tap mechanism, and consumer-descriptor registration) — see `RendererFixtures.swift`.
///
/// Failure messages name the kind (`"renderer uiKit diverged"`), so a red test says WHICH backend
/// broke. If SwiftUI genuinely diverges, that is this gate doing its job; the assertions are not to
/// be relaxed to make it green.
@MainActor
final class RendererParityTests: XCTestCase {

    private func alert(secondary: String? = "No") -> AlertDialog {
        AlertDialog(title: "T", subtitle: "S", primary: "OK", secondary: secondary)
    }

    private func stack(_ kind: RendererKind) -> (RendererHarness, DefaultModalExecutor) {
        let harness = RendererHarness(kind)
        return (harness, DefaultModalExecutor(renderer: harness.renderer))
    }

    // MARK: - A user action resolves the token with the mapped result

    /// The full `ActionType -> AlertDialog.Result` mapping in one loop: primary, secondary and the
    /// close/overlay path. Driving all three through the same shared `emit` is what makes a
    /// per-backend mapping bug (e.g. a renderer that mapped `.close` to `.secondary`) impossible to
    /// hide behind a single happy-path case.
    func test_userAction_resolvesMappedResult_onBothRenderers() async {
        let cases: [(GBAlertModal.ActionType, AlertDialog.Result)] = [
            (.primary, .primary),
            (.secondary, .secondary),
            (.close, .dismissed)
        ]
        for kind in RendererKind.allCases {
            for (action, expected) in cases {
                let (harness, executor) = stack(kind)
                let token = executor.present(alert())

                XCTAssertTrue(harness.isLive(token.id), "renderer \(kind.rawValue) never presented")
                harness.emit(action, on: token.id)

                let result = await token.result
                XCTAssertEqual(result, expected, "renderer \(kind.rawValue) diverged on \(action)")
                XCTAssertFalse(
                    harness.isLive(token.id),
                    "renderer \(kind.rawValue) diverged: resolving must tear the presentation down"
                )
            }
        }
    }

    // MARK: - Executor-driven dismissal

    func test_executorDismiss_resolvesDismissed_onBothRenderers() async {
        for kind in RendererKind.allCases {
            let (harness, executor) = stack(kind)
            let token = executor.present(alert())

            executor.dismiss(token)

            let result = await token.result
            XCTAssertEqual(result, .dismissed, "renderer \(kind.rawValue) diverged")
            XCTAssertEqual(
                harness.liveCount, 0,
                "renderer \(kind.rawValue) diverged: dismiss must tear the presentation down"
            )
        }
    }

    // MARK: - Resolve-once

    /// A second interaction after the first must not re-resolve. `staleEmitter` snapshots the view
    /// handle BEFORE the first action, so the follow-up calls go through a genuinely stale handle —
    /// exactly what a real UI holds after teardown — rather than an id lookup that would be a no-op
    /// for trivial reasons.
    ///
    /// What this reports if a backend misbehaved: a renderer that re-resolved would drive
    /// `.secondary` into the token; the token's own exactly-once guard would swallow the VALUE, so
    /// this test's discriminating assertion is `liveCount == 0` plus the renderer-level companion
    /// below (`test_rendererGate_firesExactlyOnce_onBothRenderers`), which counts gate firings.
    func test_secondInteraction_doesNotReResolve_onBothRenderers() async {
        for kind in RendererKind.allCases {
            let (harness, executor) = stack(kind)
            let token = executor.present(alert())
            let stale = harness.staleEmitter(for: token.id)

            stale(.primary)   // resolves + tears down
            stale(.secondary) // stale handle — must be inert
            harness.emit(.close, on: token.id) // no live entry — must be inert
            executor.dismiss(token)            // gate already fired — must be inert

            let result = await token.result
            XCTAssertEqual(result, .primary, "renderer \(kind.rawValue) diverged")
            XCTAssertEqual(
                harness.liveCount, 0,
                "renderer \(kind.rawValue) diverged: a resolved modal must not stay live"
            )
        }
    }

    /// The counting half of resolve-once, at the `ModalRenderer` call site itself (source-identical
    /// on both backends, so nothing here is even harness-mediated except the tap). If either
    /// renderer's gate lacked its `didResolve` guard, `received` would be `[.primary, .secondary]`
    /// on that backend and this fails naming it.
    func test_rendererGate_firesExactlyOnce_onBothRenderers() {
        for kind in RendererKind.allCases {
            let harness = RendererHarness(kind)
            let id = ModalID()
            var received: [AlertDialog.Result] = []

            harness.renderer.present(alert(), id: id) { received.append($0) }
            let stale = harness.staleEmitter(for: id)

            stale(.primary)
            stale(.secondary)
            harness.emit(.close, on: id)
            harness.renderer.dismiss(id)

            XCTAssertEqual(
                received, [.primary],
                "renderer \(kind.rawValue) diverged: the resolve gate must fire exactly once"
            )
            XCTAssertFalse(harness.isLive(id), "renderer \(kind.rawValue) diverged")
        }
    }

    // MARK: - setHidden never resolves

    /// Discrimination: if `setHidden` had resolved the token (with `.dismissed`), the token's
    /// exactly-once guard would make the LATER real `.secondary` interaction a no-op and the awaited
    /// result would come back `.dismissed`. Seeing `.secondary` is therefore positive proof the
    /// token was still open across hide/show — the same argument
    /// `MainTabModalCoordinatorTests.test_hide_doesNotResolveCurrentToken` makes against the spy.
    func test_setHidden_neverResolves_onBothRenderers() async {
        for kind in RendererKind.allCases {
            let (harness, executor) = stack(kind)
            let token = executor.present(alert())

            harness.renderer.setHidden(token.id, true)
            XCTAssertEqual(
                harness.isHidden(token.id), true,
                "renderer \(kind.rawValue) diverged: hiding must be observable"
            )
            XCTAssertTrue(
                harness.isLive(token.id),
                "renderer \(kind.rawValue) diverged: hiding must not tear the modal down"
            )

            harness.renderer.setHidden(token.id, false)
            XCTAssertEqual(
                harness.isHidden(token.id), false,
                "renderer \(kind.rawValue) diverged: showing must be observable"
            )

            harness.emit(.secondary, on: token.id)
            let result = await token.result
            XCTAssertEqual(
                result, .secondary,
                "renderer \(kind.rawValue) diverged: hide/show must leave the token open"
            )
        }
    }

    // MARK: - update never resolves and preserves identity

    /// Identity = the same `ModalID` is still live, there is still exactly ONE presentation, and the
    /// content actually changed. The content check reads `ResolvedModal.subtitle` — the output of
    /// the SAME pure resolver on both backends — so a renderer that swapped the presentation for a
    /// fresh one, or that failed to re-render, is caught rather than assumed.
    func test_update_neverResolves_andPreservesIdentity_onBothRenderers() async {
        for kind in RendererKind.allCases {
            let (harness, executor) = stack(kind)
            let token = executor.present(
                AlertDialog(title: "T1", subtitle: "S1", primary: "OK", secondary: "No")
            )
            XCTAssertEqual(
                harness.resolvedSubtitle(token.id), .plain("S1"),
                "renderer \(kind.rawValue): premise — the first descriptor is what is rendered"
            )

            executor.update(
                token, to: AlertDialog(title: "T2", subtitle: "S2", primary: "Go", secondary: "No")
            )

            XCTAssertTrue(
                harness.isLive(token.id),
                "renderer \(kind.rawValue) diverged: update must keep the same id live"
            )
            XCTAssertEqual(
                harness.liveCount, 1,
                "renderer \(kind.rawValue) diverged: update must not create a second presentation"
            )
            XCTAssertEqual(
                harness.resolvedSubtitle(token.id), .plain("S2"),
                "renderer \(kind.rawValue) diverged: update must re-render in place"
            )

            harness.emit(.primary, on: token.id)
            let result = await token.result
            XCTAssertEqual(
                result, .primary,
                "renderer \(kind.rawValue) diverged: update must never resolve the token"
            )
        }
    }

    // MARK: - Unregistered descriptor

    /// Both backends resolve an unregistered descriptor with `D.dismissedResult` and leave no live
    /// entry. (This used to be a real divergence: UIKit trapped on `assertionFailure`. It was
    /// removed in 5b64a37 precisely so this could become one shared behaviour.)
    func test_unregisteredDescriptor_resolvesDismissedResult_onBothRenderers() async {
        for kind in RendererKind.allCases {
            let (harness, executor) = stack(kind)

            let token = executor.present(ParityUnregisteredDialog())

            let result = await token.result
            XCTAssertEqual(
                result, .gracefullyDismissed,
                "renderer \(kind.rawValue) diverged: must resolve with the descriptor's dismissedResult"
            )
            XCTAssertEqual(
                harness.liveCount, 0,
                "renderer \(kind.rawValue) diverged: an unregistered descriptor must not go live"
            )
        }
    }

    // MARK: - Consumer-defined descriptor with its own result vocabulary

    /// THE behaviour the earlier gate-blocker was about. A descriptor defined outside the library,
    /// whose `Result` the renderer cannot know, resolves its OWN vocabulary on both backends —
    /// registered through `RendererHarness.registerCustom`, which shares the content mapping and the
    /// `ActionType -> Result` route and branches only on the wiring mechanism.
    ///
    /// All three actions are driven, so a backend that routed only `.primary` correctly (or that
    /// collapsed `.secondary` into the dismissed case) fails here naming itself.
    func test_customDescriptor_resolvesItsOwnVocabulary_onBothRenderers() async {
        let cases: [(GBAlertModal.ActionType, ParityStepDialog.Result)] = [
            (.primary, .done),
            (.secondary, .skipped),
            (.close, .dismissed)
        ]
        // .embedded excluded: registerCustom is UIKit-typed-argument, deliberately unsupported there
        // (RendererFixtures.swift's own doc on the method).
        for kind: RendererKind in [.uiKit, .swiftUI] {
            for (action, expected) in cases {
                let harness = RendererHarness(kind)
                harness.registerCustom(
                    ParityStepDialog.self,
                    properties: GeniePresets.standardProperties(),
                    holder: { descriptor in
                        GBAlertModal.DataHolder(
                            title: descriptor.title,
                            primaryAction: "Next",
                            secondaryAction: "Skip",
                            dismissOnAction: false // the renderer's gate owns teardown
                        )
                    },
                    route: { action in
                        switch action {
                        case .primary: return .done
                        case .secondary: return .skipped
                        case .close: return .dismissed
                        }
                    }
                )
                let executor = DefaultModalExecutor(renderer: harness.renderer)

                let token = executor.present(ParityStepDialog(title: "Step 1"))
                XCTAssertTrue(
                    harness.isLive(token.id),
                    "renderer \(kind.rawValue) never presented the custom descriptor"
                )
                harness.emit(action, on: token.id)

                let result = await token.result
                XCTAssertEqual(
                    result, expected,
                    "renderer \(kind.rawValue) diverged on custom \(action)"
                )
                XCTAssertEqual(
                    harness.liveCount, 0,
                    "renderer \(kind.rawValue) diverged: resolving a custom descriptor must tear it down"
                )
            }
        }
    }

    /// `executor.dismiss` on a custom descriptor must resolve with the DESCRIPTOR's dismissed case,
    /// not the standard family's. Guards the `D.dismissedResult` plumbing through both gates.
    func test_customDescriptor_executorDismiss_resolvesItsDismissedResult_onBothRenderers() async {
        // .embedded excluded: see the same note on the test above.
        for kind: RendererKind in [.uiKit, .swiftUI] {
            let harness = RendererHarness(kind)
            harness.registerCustom(
                ParityStepDialog.self,
                properties: GeniePresets.standardProperties(),
                holder: { GBAlertModal.DataHolder(title: $0.title, primaryAction: "Next") },
                route: { $0 == .primary ? .done : .skipped } // never yields `.dismissed`
            )
            let executor = DefaultModalExecutor(renderer: harness.renderer)

            let token = executor.present(ParityStepDialog(title: "Step 1"))
            executor.dismiss(token)

            let result = await token.result
            // `.dismissed` is unreachable through the route above, so it can only have come from
            // `ParityStepDialog.dismissedResult`.
            XCTAssertEqual(result, .dismissed, "renderer \(kind.rawValue) diverged")
            XCTAssertEqual(harness.liveCount, 0, "renderer \(kind.rawValue) diverged")
        }
    }

    // MARK: - PopupDialog — the second member of the standard family

    /// `PopupDialog` is a distinct descriptor type registered with its own `Properties` on both
    /// backends. Covers the "registered only when popup styling is supplied" branch on both.
    func test_popupDialog_resolvesPrimary_onBothRenderers() async {
        for kind in RendererKind.allCases {
            let (harness, executor) = stack(kind)

            let token = executor.present(
                PopupDialog(title: "T", subtitle: "S", primary: "OK", secondary: "No")
            )
            XCTAssertTrue(harness.isLive(token.id), "renderer \(kind.rawValue) never presented")
            harness.emit(.primary, on: token.id)

            let result = await token.result
            XCTAssertEqual(result, .primary, "renderer \(kind.rawValue) diverged")
        }
    }

    // MARK: - ModalStyle — the style token must mean the same thing on both backends

    /// **THE style parity gate.** One descriptor, one `register(style:properties:)` call (source-
    /// identical on both backends), and the SAME styling decision must come out of both renderers.
    ///
    /// A style token honoured by one backend only would be exactly the divergence this suite exists
    /// to prevent — a SwiftUI-only preset would silently render as `.standard` on the shipping UIKit
    /// path, or vice versa, with nothing to catch it.
    ///
    /// Discrimination: the decision is compared BOTH across the two renderers AND against the
    /// expected badge values. Cross-renderer equality alone would pass if both backends ignored
    /// `style` identically; the absolute values alone would not prove parity. Both together do.
    func test_styledDescriptor_producesTheSameStylingDecision_onBothRenderers() async throws {
        var decisions: [RendererKind: StylingDecision] = [:]

        // .embedded excluded: register(style:properties:)/effectiveProperties are UIKit-typed-
        // argument, deliberately unsupported there (RendererFixtures.swift's own docs).
        for kind: RendererKind in [.uiKit, .swiftUI] {
            let harness = RendererHarness(kind)
            harness.register(style: .parityBadge, properties: GeniePresets.badgeProperties())
            let executor = DefaultModalExecutor(renderer: harness.renderer)

            let token = executor.present(
                AlertDialog(title: "T", subtitle: "S", primary: "OK", style: .parityBadge)
            )
            XCTAssertTrue(harness.isLive(token.id), "renderer \(kind.rawValue) never presented")

            let properties = try XCTUnwrap(
                harness.effectiveProperties(token.id),
                "renderer \(kind.rawValue) exposed no effective Properties"
            )
            decisions[kind] = decision(from: properties)

            harness.emit(.primary, on: token.id)
            let result = await token.result
            XCTAssertEqual(
                result, .primary,
                "renderer \(kind.rawValue) diverged: a styled modal must still resolve normally"
            )
        }

        // The badge preset's own values: `.black` close tint and a `.systemBlue` secondary label
        // (`GeniePresets.plainTheme`), square banner ratio. The secondary label is asserted
        // ABSOLUTELY rather than against the accent, so a backend that fell back to the primary
        // theme's orange fails here too.
        let expected = StylingDecision(
            cornerRadius: 28,
            contentMaxWidth: 300,
            titleColor: .magenta,
            bannerRatio: 1,
            closeButton: Color(uiColor: .black),
            secondaryLabel: Color(uiColor: .systemBlue)
        )
        XCTAssertEqual(
            decisions[.uiKit], expected,
            "uiKit did not apply the registered style"
        )
        XCTAssertEqual(
            decisions[.swiftUI], expected,
            "swiftUI did not apply the registered style"
        )
        XCTAssertEqual(
            decisions[.uiKit], decisions[.swiftUI],
            "the backends diverged on the SAME style token — a style must not be backend-specific"
        )
    }

    /// The fallback half of the gate: an UNREGISTERED style degrades to `.standard` identically on
    /// both backends, and crashes neither. `.parityBadge` IS registered here, so falling back to
    /// `.standard` is provably distinct from picking whatever else happens to be in the map.
    func test_unregisteredStyle_fallsBackIdentically_onBothRenderers() async throws {
        let standard = decision(from: GeniePresets.standardProperties())
        var decisions: [RendererKind: StylingDecision] = [:]

        // .embedded excluded: see the same note on the style-parity test above.
        for kind: RendererKind in [.uiKit, .swiftUI] {
            let harness = RendererHarness(kind)
            harness.register(style: .parityBadge, properties: GeniePresets.badgeProperties())
            XCTAssertFalse(
                harness.isRegistered(style: .parityGhost),
                "renderer \(kind.rawValue): premise — the probe style must be unregistered"
            )
            let executor = DefaultModalExecutor(renderer: harness.renderer)

            let token = executor.present(
                AlertDialog(title: "T", primary: "OK", style: .parityGhost)
            )
            XCTAssertTrue(
                harness.isLive(token.id),
                "renderer \(kind.rawValue): an unregistered style must still present, never crash"
            )
            let properties = try XCTUnwrap(harness.effectiveProperties(token.id))
            decisions[kind] = decision(from: properties)

            harness.emit(.primary, on: token.id)
            let result = await token.result
            XCTAssertEqual(result, .primary, "renderer \(kind.rawValue) diverged")
        }

        XCTAssertEqual(decisions[.uiKit], standard, "uiKit did not fall back to .standard")
        XCTAssertEqual(decisions[.swiftUI], standard, "swiftUI did not fall back to .standard")
        XCTAssertNotEqual(
            decisions[.uiKit]?.cornerRadius, 28,
            "the fallback must not pick another registered style"
        )
        XCTAssertEqual(
            decisions[.uiKit], decisions[.swiftUI],
            "the backends diverged on the FALLBACK for an unregistered style"
        )
    }

    // MARK: - The red-primary shape: the secondary button keeps its OWN theme on both backends

    /// **S3 at the renderer level.** `oblique-red-leave-confirm` is the one real shape whose primary
    /// and secondary themes carry different colours (RED oblique primary, `.systemBlue` plain
    /// secondary). UIKit has always drawn the secondary from `secondaryActionStyle`'s own theme;
    /// SwiftUI coloured it from `palette.accent`, i.e. the PRIMARY theme, and therefore drew it RED.
    ///
    /// Both backends are driven through the same registered style here, and both must land on the
    /// secondary theme's colour. Cross-renderer equality alone would not discriminate (both could be
    /// wrong identically), so the absolute colour AND its inequality with the accent are asserted.
    func test_redPrimaryShape_keepsTheSecondaryThemeColour_onBothRenderers() async throws {
        let obliqueRed = ModalStyle("parity.obliqueRed")

        // .embedded excluded: see the same note on the style-parity test above.
        for kind: RendererKind in [.uiKit, .swiftUI] {
            let harness = RendererHarness(kind)
            harness.register(style: obliqueRed, properties: GeniePresets.obliqueRedProperties())
            let executor = DefaultModalExecutor(renderer: harness.renderer)

            let token = executor.present(
                AlertDialog(title: "Leave?", primary: "Leave", secondary: "Stay", style: obliqueRed)
            )
            let properties = try XCTUnwrap(harness.effectiveProperties(token.id))
            let tokens = ModalTokens(from: properties)

            XCTAssertEqual(
                tokens.palette.accent, Color(uiColor: .systemRed),
                "renderer \(kind.rawValue): premise — the primary theme is RED"
            )
            XCTAssertEqual(
                PlainSecondaryStyle.labelColor(tokens: tokens, isEnabled: true),
                Color(uiColor: .systemBlue),
                "renderer \(kind.rawValue) diverged: the secondary label must come from the SECONDARY theme"
            )
            XCTAssertNotEqual(
                tokens.palette.secondaryLabel, tokens.palette.accent,
                "renderer \(kind.rawValue) diverged: the secondary label must not be the primary accent"
            )

            harness.emit(.secondary, on: token.id)
            let result = await token.result
            XCTAssertEqual(result, .secondary, "renderer \(kind.rawValue) diverged")
        }
    }

    // MARK: - Overriding a built-in factory

    /// `register(_:factory:)` is source-identical on both backends and overriding the built-in
    /// `AlertDialog` factory is a documented extension point. On UIKit the routing rides along in
    /// the replacement holder; on SwiftUI the registry must PRESERVE the standard route. Same call,
    /// same assertion, both backends.
    func test_overridingBuiltInFactory_preservesRouting_onBothRenderers() async {
        // .embedded excluded: reRegisterStandardAlertFactory is UIKit-typed-argument, deliberately
        // unsupported there (RendererFixtures.swift's own doc).
        for kind: RendererKind in [.uiKit, .swiftUI] {
            let harness = RendererHarness(kind)
            harness.reRegisterStandardAlertFactory(properties: GeniePresets.popupProperties())
            let executor = DefaultModalExecutor(renderer: harness.renderer)

            let token = executor.present(alert())
            XCTAssertTrue(
                harness.isLive(token.id),
                "renderer \(kind.rawValue): an overridden factory must still present"
            )
            harness.emit(.primary, on: token.id)

            let result = await token.result
            XCTAssertEqual(
                result, .primary,
                "renderer \(kind.rawValue) diverged: overriding the factory must preserve routing"
            )
        }
    }

    // MARK: - presentAndWait cancellation tears the modal down

    /// The await owns the modal, so cancelling it must resolve `.dismissed` AND make the renderer
    /// tear the presentation down (`token.onDrop` → `executor.dismiss` → `renderer.dismiss`). The
    /// renderer is load-bearing for the second half.
    func test_presentAndWaitCancelled_tearsDown_onBothRenderers() async {
        for kind in RendererKind.allCases {
            let (harness, executor) = stack(kind)
            let descriptor = alert() // built outside the Task: `AlertDialog` is Sendable, `self` is not needed
            let waiter = Task { await executor.presentAndWait(descriptor) }

            // Bounded spin rather than a fixed number of yields: the child task's scheduling is not
            // guaranteed after exactly one yield (see ModalExecutorTests for the same pattern).
            var spins = 0
            while harness.liveCount == 0 && spins < 1000 {
                await Task.yield()
                spins += 1
            }
            XCTAssertEqual(
                harness.liveCount, 1,
                "renderer \(kind.rawValue): presentAndWait never presented a modal"
            )

            waiter.cancel()
            let value = await waiter.value

            XCTAssertEqual(value, .dismissed, "renderer \(kind.rawValue) diverged")
            XCTAssertEqual(
                harness.liveCount, 0,
                "renderer \(kind.rawValue) diverged: cancelling the wait must tear the modal down"
            )
        }
    }

    // MARK: - Coordinator-level, where the renderer is load-bearing

    /// Serial policy against a REAL renderer: the second request must not reach the renderer until
    /// the first resolves. `MainTabModalCoordinatorTests` proves this against `SpyRenderer`; the
    /// point of re-running it here is that the queue only advances when the renderer actually calls
    /// its resolve closure, which is renderer-owned behaviour.
    func test_coordinatorSerialisesPresents_onBothRenderers() async {
        for kind in RendererKind.allCases {
            let (harness, executor) = stack(kind)
            executor.coordinator = MainTabModalCoordinator(renderer: harness.renderer)

            let first = executor.present(AlertDialog(title: "A", subtitle: "S", primary: "OK"))
            let second = executor.present(AlertDialog(title: "B", subtitle: "S", primary: "OK"))

            XCTAssertTrue(harness.isLive(first.id), "renderer \(kind.rawValue): the first must show")
            XCTAssertFalse(
                harness.isLive(second.id),
                "renderer \(kind.rawValue) diverged: the second must queue, not overlap"
            )
            XCTAssertEqual(harness.liveCount, 1, "renderer \(kind.rawValue) diverged")

            harness.emit(.primary, on: first.id)

            XCTAssertTrue(
                harness.isLive(second.id),
                "renderer \(kind.rawValue) diverged: resolving the first must advance the queue"
            )
            let firstResult = await first.result
            XCTAssertEqual(firstResult, .primary, "renderer \(kind.rawValue) diverged")

            harness.emit(.secondary, on: second.id)
            let secondResult = await second.result
            XCTAssertEqual(secondResult, .secondary, "renderer \(kind.rawValue) diverged")
        }
    }

    /// `drain()` must resolve BOTH the shown token (via a real renderer teardown) and the queued one
    /// (which the renderer never saw), and leave nothing live.
    func test_coordinatorDrain_resolvesShownAndQueued_onBothRenderers() async {
        for kind in RendererKind.allCases {
            let (harness, executor) = stack(kind)
            let coordinator = MainTabModalCoordinator(renderer: harness.renderer)
            executor.coordinator = coordinator

            let shown = executor.present(AlertDialog(title: "A", subtitle: "S", primary: "OK"))
            let queued = executor.present(AlertDialog(title: "B", subtitle: "S", primary: "OK"))
            XCTAssertEqual(harness.liveCount, 1, "renderer \(kind.rawValue): premise — one shown")

            coordinator.drain()

            let shownResult = await shown.result
            let queuedResult = await queued.result
            XCTAssertEqual(
                shownResult, .dismissed,
                "renderer \(kind.rawValue) diverged: drain must resolve the shown token"
            )
            XCTAssertEqual(
                queuedResult, .dismissed,
                "renderer \(kind.rawValue) diverged: drain must resolve the queued token"
            )
            XCTAssertEqual(
                harness.liveCount, 0,
                "renderer \(kind.rawValue) diverged: drain must tear the visible modal down"
            )
        }
    }

    /// Hide/show against a REAL renderer: `MainTabModalCoordinatorTests` proves the
    /// queue-pausing and non-resolving behaviour against `SpyRenderer`; that only proves the
    /// COORDINATOR side of the contract. This re-runs it here because `hide()`/`show()` pause and
    /// resume by calling the renderer's OWN `setHidden(_:_:)` — untested against any of the three
    /// UIKit-free/SwiftUI renderers until now (only `RendererParityTests
    /// .test_setHidden_neverResolves_onBothRenderers` calls `setHidden` directly; nothing had driven
    /// it THROUGH a real coordinator's hide/show).
    func test_coordinatorHideShow_pausesQueueAdvance_andNeverResolves_onBothRenderers() async {
        for kind in RendererKind.allCases {
            let (harness, executor) = stack(kind)
            let coordinator = MainTabModalCoordinator(renderer: harness.renderer)
            executor.coordinator = coordinator

            let first = executor.present(AlertDialog(title: "A", subtitle: "S", primary: "OK"))
            let second = executor.present(AlertDialog(title: "B", subtitle: "S", primary: "OK"))
            XCTAssertTrue(harness.isLive(first.id), "renderer \(kind.rawValue): premise — first is shown")

            coordinator.hide()
            XCTAssertEqual(
                harness.isHidden(first.id), true,
                "renderer \(kind.rawValue) diverged: hide must hide the shown modal"
            )

            harness.emit(.primary, on: first.id) // resolves while hidden
            let firstResult = await first.result
            XCTAssertEqual(
                firstResult, .primary,
                "renderer \(kind.rawValue) diverged: hide must not swallow or alter the real resolve value"
            )
            XCTAssertFalse(
                harness.isLive(second.id),
                "renderer \(kind.rawValue) diverged: while hidden, the queue must not advance"
            )

            coordinator.show()
            XCTAssertTrue(
                harness.isLive(second.id),
                "renderer \(kind.rawValue) diverged: show must resume the queue"
            )
            XCTAssertEqual(
                harness.isHidden(second.id), false,
                "renderer \(kind.rawValue) diverged: show must unhide the newly-advanced modal"
            )

            harness.emit(.secondary, on: second.id)
            let secondResult = await second.result
            XCTAssertEqual(secondResult, .secondary, "renderer \(kind.rawValue) diverged")
        }
    }

    // MARK: - The one KNOWN DIVERGENCE, pinned rather than hidden

    /// **NOT a parity test.** It asserts that the two backends behave DIFFERENTLY, and it exists so
    /// the difference the harness papers over is visible in the suite and not only in a report.
    ///
    /// A consumer who writes the source-identical `register(_:factory:)` call with routing embedded
    /// in `DataHolder.completion` — the UIKit-native way, and what every existing consumer
    /// registration in this repo does — gets a modal that a user action resolves on UIKit and a
    /// modal that a user action CANNOT resolve on SwiftUI. `DataHolder.completion` demands a
    /// `GBAlertModal` instance the SwiftUI backend never builds, so it is never invoked there;
    /// `register(_:route:factory:)` is the SwiftUI-only remedy, and `RendererHarness.registerCustom`
    /// is where the parity tests above branch to apply it.
    ///
    /// Conservation still holds on SwiftUI — the presentation is resolvable via `dismiss`, so no
    /// token can hang; it is only unreachable by user ACTION. If SwiftUI ever gains
    /// completion-based routing this test will fail, which is the point: the pin must be updated
    /// deliberately, not drift.
    func test_KNOWN_DIVERGENCE_completionBasedRegistration_isActionResolvableOnUIKitOnly() {
        // --- UIKit: the completion is the routing, and a tap resolves.
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        let uiKit = UIKitModalRenderer(
            alertProperties: GeniePresets.standardProperties(),
            windowProvider: { window }
        )
        uiKit.register(ParityStepDialog.self) { descriptor, resolve in
            (
                GeniePresets.standardProperties(),
                GBAlertModal.DataHolder(
                    title: descriptor.title,
                    primaryAction: "Next",
                    dismissOnAction: false,
                    completion: { _, action in resolve(action == .primary ? .done : .skipped) }
                )
            )
        }
        let uiKitID = ModalID()
        var uiKitResult: ParityStepDialog.Result?
        uiKit.present(ParityStepDialog(title: "Step"), id: uiKitID) { uiKitResult = $0 }
        uiKit.live[uiKitID]?.modal.dismissAndEmit(event: .primary)
        XCTAssertEqual(
            uiKitResult, .done,
            "UIKit routes a consumer descriptor through DataHolder.completion"
        )

        // --- SwiftUI: the SAME registration source, and the same tap, resolves nothing.
        let swiftUI = SwiftUIModalRenderer(alertProperties: GeniePresets.standardProperties())
        swiftUI.register(ParityStepDialog.self) { descriptor, resolve in
            (
                GeniePresets.standardProperties(),
                GBAlertModal.DataHolder(
                    title: descriptor.title,
                    primaryAction: "Next",
                    dismissOnAction: false,
                    completion: { _, action in resolve(action == .primary ? .done : .skipped) }
                )
            )
        }
        let swiftUIID = ModalID()
        var swiftUIResult: ParityStepDialog.Result?
        swiftUI.present(ParityStepDialog(title: "Step"), id: swiftUIID) { swiftUIResult = $0 }
        swiftUI.presentations.first(where: { $0.id == swiftUIID })?.onAction(.primary)
        XCTAssertNil(
            swiftUIResult,
            "DIVERGENCE: SwiftUI has no DataHolder.completion channel, so the tap resolves nothing"
        )

        // Conservation holds anyway: dismissal still resolves it, so a token cannot hang.
        swiftUI.dismiss(swiftUIID)
        XCTAssertEqual(swiftUIResult, .dismissed)
    }
}
