import SwiftUI
import GBV3AlertModal

/// Pure-SwiftUI mirror of `GBAlertModal`'s content: `AlertModalScaffold` (shared chrome) with a
/// built-in standard body (banner/title/subtitle). Holds NO branching logic beyond `ResolvedAlert`
/// slot decisions; routes taps through `resolve(_:_:)`. Never dismisses itself; the caller reacts
/// to `onAction` (matches the executor teardown contract). Styling is fixed design (`ModalTokens`).
struct SwiftUIAlertModal: View {
    let config: AlertDialog
    /// Presentation state — NOT part of `AlertDialog`. The caller owns this; the view only reads it.
    var primaryEnabled: Bool = true
    var isPrimaryLoading: Bool = false
    let onAction: (AlertDialog.Result) -> Void

    private var resolved: ResolvedAlert { ResolvedAlert(config) }

    var body: some View {
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
                    .aspectRatio(ModalTokens.bannerAspectRatio, contentMode: .fit)
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
