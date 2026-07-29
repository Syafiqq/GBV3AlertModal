import Foundation
import SwiftUI

/// Pure-SwiftUI mirror of `GBAlertModal`'s content: `AlertModalScaffold` (shared chrome) with a
/// built-in standard body (banner/title/subtitle). Holds NO branching logic beyond `ResolvedAlert`
/// slot decisions; routes taps through `resolve(_:_:)`. Never dismisses itself; the caller reacts
/// to `onAction` (matches the executor teardown contract). Styling is fixed design (`ModalTokens`).
public struct SwiftUIAlertModal: View {
    public let config: AlertDialog
    /// Presentation state — NOT part of `AlertDialog`. The caller owns this; the view only reads it.
    public var primaryEnabled: Bool = true
    public var isPrimaryLoading: Bool = false
    public let onAction: (AlertDialog.Result) -> Void

    public init(
        config: AlertDialog,
        primaryEnabled: Bool = true,
        isPrimaryLoading: Bool = false,
        onAction: @escaping (AlertDialog.Result) -> Void
    ) {
        self.config = config
        self.primaryEnabled = primaryEnabled
        self.isPrimaryLoading = isPrimaryLoading
        self.onAction = onAction
    }

    private var resolved: ResolvedAlert { ResolvedAlert(config) }

    public var body: some View {
        AlertModalScaffold(
            primaryTitle: config.primary,
            isPrimaryLoading: isPrimaryLoading,
            primaryEnabled: primaryEnabled,
            onPrimary: { route(.primaryTapped) },
            secondaryTitle: resolved.showsSecondary ? config.secondary : nil,
            onSecondary: { route(.secondaryTapped) },
            showClose: resolved.showsClose,
            onClose: { route(.closeTapped) },
            onOverlayTap: { route(.overlayTapped) }
        ) {
            if resolved.showsBanner, let name = config.image?.assetName {
                Image(name)
                    .resizable()
                    .scaledToFit()   // preserve the image's natural aspect ratio (no distortion)
                    .frame(maxHeight: ModalTokens.bannerMaxHeight)
                    .padding(.bottom, ModalTokens.gapBelowBanner)
            }
            if resolved.showsTitle, let title = config.title {
                Text(title)
                    .font(ModalTokens.titleFont)
                    .foregroundColor(ModalTokens.Palette.titleText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, ModalTokens.gapBelowTitle)
            }
            if resolved.showsSubtitle, let subtitle = config.subtitle {
                Text(subtitle)
                    .font(ModalTokens.subtitleFont)
                    .foregroundColor(ModalTokens.Palette.subtitleText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, ModalTokens.gapBelowSubtitle)
            }
        }
    }

    /// The one place interaction becomes outcome. `nil` = no-op (e.g. overlay tap when disabled).
    private func route(_ interaction: AlertInteraction) {
        resolve(interaction, config).map(onAction)
    }
}

// MARK: - Slot resolution (private to this file)
//
// The example app's `AlertResolution.swift` (`ResolvedAlert` / `AlertInteraction` / `resolve`)
// deliberately stays in the example app for this task (Task 3 of the SwiftUI tier-1 plan) — it is
// scheduled for deletion in Task 4, once `SwiftUIAlertModal` is rewired to consume the library's own
// `ResolvedModal` instead. Until then this view needs the *same* slot-visibility / routing logic to
// compile standalone inside the library module, so it is duplicated here as private, file-scoped
// declarations (not part of the public API). This is intentionally throwaway: Task 4 deletes it.

/// A discrete user interaction with the modal. Pure enum so routing is testable without a view.
private enum AlertInteraction {
    case primaryTapped, secondaryTapped, closeTapped, overlayTapped
}

/// Which slots the modal renders, derived purely from the config.
private struct ResolvedAlert {
    let showsBanner: Bool
    let showsTitle: Bool
    let showsSubtitle: Bool
    let showsSecondary: Bool
    let showsClose: Bool

    init(_ config: AlertDialog) {
        func present(_ s: AttributedString?) -> Bool { !(s?.characters.isEmpty ?? true) }
        showsBanner = config.image != nil
        showsTitle = present(config.title)
        showsSubtitle = present(config.subtitle)
        showsSecondary = !(config.secondary ?? "").isEmpty
        showsClose = config.showCloseButton
    }
}

/// The outcome an interaction produces, or `nil` for a no-op (overlay tap when disabled).
private func resolve(_ interaction: AlertInteraction, _ config: AlertDialog) -> AlertDialog.Result? {
    switch interaction {
    case .primaryTapped:   return .primary
    case .secondaryTapped: return .secondary
    case .closeTapped:     return .dismissed
    case .overlayTapped:   return config.closeOnTapOverlay ? .dismissed : nil
    }
}
