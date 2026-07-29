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
                    ForEach(renderer.presentations) { presentation in
                        modal(for: presentation)
                    }
                }
            )
    }

    /// Draws one presentation. `presentation.content` is `nil` for descriptors registered through
    /// `register(_:factory:)` (no `StandardAlertContent`, so no built-in SwiftUI body) — those are
    /// skipped rather than guessed at; a consumer hosts them itself.
    @ViewBuilder
    private func modal(for presentation: SwiftUIModalRenderer.Presentation) -> some View {
        if !presentation.isHidden, let config = presentation.content {
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
