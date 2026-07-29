import SwiftUI

/// Overlays a `SwiftUIModalRenderer`'s live presentations on top of arbitrary content — the SwiftUI
/// counterpart of `UIKitModalRenderer`'s "add the modal to the key window".
///
/// The scrim must fill the screen, so content is expanded to fill BEFORE `.overlay`; getting that
/// order backwards renders the scrim inside a small centred box (a real bug already caught once on
/// this codebase).
@MainActor
public struct ModalHost<Content: View>: View {
    @ObservedObject private var renderer: SwiftUIModalRenderer
    private let content: Content

    public init(renderer: SwiftUIModalRenderer, @ViewBuilder content: () -> Content) {
        self.renderer = renderer
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                ZStack {
                    // IDENTITY: `ForEach` keys on `Presentation.id` (`ModalID`, stable for the whole
                    // life of a presentation), so a `presentations` diff — a second modal appearing,
                    // a `setHidden` toggle, an `update(_:to:)` rebuild — UPDATES each element in
                    // place instead of recreating it. That is what lets a registered custom view own
                    // `@State`: the typed text survives every diff except teardown.
                    ForEach(renderer.presentations) { presentation in
                        modal(for: presentation)
                            // `isHidden` is a VISIBILITY modifier, deliberately not an `if`.
                            // Removing the subtree would destroy that `@State` — and it would also
                            // diverge from UIKit, where `modal.isHidden` keeps the live
                            // `UITextField` and its text. These two modifiers are `UIView.isHidden`
                            // semantics: not drawn, not hit-testable, still alive.
                            .opacity(presentation.isHidden ? 0 : 1)
                            .allowsHitTesting(!presentation.isHidden)
                    }
                }
            )
    }

    /// Draws one presentation, preferring the consumer's registered view over the standard body.
    ///
    /// * `customContent` — a `register(_:view:)` body with the resolve gate already bound. It is the
    ///   WHOLE modal (its own `AlertModalScaffold`), because its buttons must read the `@State` it
    ///   owns; `ModalHost` cannot supply buttons that know about a value it cannot see.
    /// * `content` — the standard family's `AlertDialog` projection, rendered by `SwiftUIAlertModal`.
    /// * neither — a descriptor registered through `register(_:factory:)`/`register(_:route:factory:)`
    ///   with no view: routable, but with no body to draw. Skipped rather than guessed at.
    @ViewBuilder
    private func modal(for presentation: SwiftUIModalRenderer.Presentation) -> some View {
        if let customContent = presentation.customContent {
            customContent
        } else if let config = presentation.content {
            SwiftUIAlertModal(
                config: config,
                // The real, caller-supplied `Properties` this presentation was resolved with —
                // this is what keeps the view's own `GBAlertModal.resolve` call in step with
                // `presentation.resolved` (same pure function, same inputs).
                properties: presentation.properties,
                tokens: presentation.tokens,
                onAction: { result in presentation.onAction(Self.actionType(for: result)) }
            )
        }
    }

    /// `AlertDialog.Result` (what the view emits) → `GBAlertModal.ActionType` (what the renderer's
    /// router consumes). The exact inverse of the router's mapping in `registerStandard`, so a tap
    /// round-trips to the identical `Result` the UIKit path would have produced.
    private static func actionType(for result: AlertDialog.Result) -> GBAlertModal.ActionType {
        switch result {
        case .primary: return .primary
        case .secondary: return .secondary
        case .dismissed: return .close
        }
    }
}
