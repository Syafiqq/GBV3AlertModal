import SwiftUI

/// Overlays an `EmbeddedModalRenderer`'s live presentations on top of arbitrary content — the
/// UIKit-free mirror of `ModalHost`, for `EmbeddedModalRenderer` instead of `SwiftUIModalRenderer`.
///
/// Same scrim-fills-first-then-overlay ordering `ModalHost` documents (getting it backwards renders
/// the scrim inside a small centred box — a real bug already caught once on this codebase, for the
/// original host).
@MainActor
public struct EmbeddedModalHost<Content: View>: View {
    @ObservedObject private var renderer: EmbeddedModalRenderer
    private let content: Content

    public init(renderer: EmbeddedModalRenderer, @ViewBuilder content: () -> Content) {
        self.renderer = renderer
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                ZStack {
                    // Same IDENTITY rule as `ModalHost`: `ForEach` keys on `Presentation.id`
                    // (`ModalID`), so a `presentations` diff updates each element in place.
                    ForEach(renderer.presentations) { presentation in
                        modal(for: presentation)
                            // Visibility, not removal — same `UIView.isHidden` semantics `ModalHost`
                            // uses: not drawn, not hit-testable, still alive.
                            .opacity(presentation.isHidden ? 0 : 1)
                            .allowsHitTesting(!presentation.isHidden)
                    }
                }
            )
    }

    /// Prefers the consumer's registered view over the standard body — same precedence
    /// `ModalPresentationBody.view(for:)` uses, for the same reason: a `register(_:view:)` body is
    /// the WHOLE modal (its own `AlertModalScaffold`), because its buttons must read the `@State` it
    /// owns. `content` alone (no `customContent`) is the standard family, drawn by `SwiftUIAlertModal`.
    /// Neither means the kind is routable but has nothing to draw — a `register(_:factory:)`-only
    /// registration — skipped rather than guessed at.
    @ViewBuilder
    private func modal(for presentation: EmbeddedModalRenderer.Presentation) -> some View {
        if let customContent = presentation.customContent {
            customContent
        } else if let config = presentation.content {
            SwiftUIAlertModal(
                config: config,
                properties: presentation.properties,
                tokens: presentation.tokens,
                onAction: { result in presentation.onAction(actionType(for: result)) }
            )
        }
    }

    /// `AlertDialog.Result` (what the view emits) → `GBAlertModal.ActionType` (what the renderer's
    /// router consumes) — the exact inverse of `EmbeddedModalRenderer.registerStandard`'s `route`,
    /// same mapping `ModalPresentationBody.actionType(for:)` uses.
    private func actionType(for result: AlertDialog.Result) -> GBAlertModal.ActionType {
        switch result {
        case .primary: return .primary
        case .secondary: return .secondary
        case .dismissed: return .close
        }
    }
}
