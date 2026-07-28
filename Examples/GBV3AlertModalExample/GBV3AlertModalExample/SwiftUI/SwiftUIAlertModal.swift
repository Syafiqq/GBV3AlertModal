import SwiftUI
import GBV3AlertModal

/// Pure-SwiftUI mirror of `GBAlertModal`'s content: a full-screen scrim with a centered card.
/// Holds NO branching logic — reads `ResolvedAlert` and routes taps through `resolve(_:_:)`.
/// Never dismisses itself; the caller reacts to `onAction` (matches the executor teardown contract).
/// Styling is fixed design (`ModalTokens` + `ButtonStyle`s), never per-call (spec D8).
struct SwiftUIAlertModal: View {
    let config: AlertDialog
    var scrim: Color = ModalTokens.Palette.scrim.opacity(ModalTokens.scrimOpacity)
    /// Presentation state — NOT part of `AlertDialog`. The caller (demo screen / real app)
    /// owns this; the view only reads it. Mirrors the real app's enabled/loading primary button.
    var primaryEnabled: Bool = true
    var isPrimaryLoading: Bool = false
    let onAction: (AlertDialog.Result) -> Void

    private var resolved: ResolvedAlert { ResolvedAlert(config) }

    var body: some View {
        ZStack {
            scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { route(.overlayTapped) }

            card
                .frame(maxWidth: ModalTokens.cardWidth)
                .padding(24)

            if resolved.showsClose {
                closeButton
            }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
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
            Button { route(.primaryTapped) } label: {
                if isPrimaryLoading {
                    ProgressView().tint(ModalTokens.Palette.onAccent)
                } else {
                    Text(config.primary)
                }
            }
            .buttonStyle(ObliquePrimaryStyle())
            .disabled(!primaryEnabled || isPrimaryLoading)

            if resolved.showsSecondary, let secondary = config.secondary {
                Button { route(.secondaryTapped) } label: { Text(secondary) }
                    .buttonStyle(PlainSecondaryStyle())
                    .padding(.top, ModalTokens.interButton)
            }
        }
        .padding(ModalTokens.contentPadding)
        .background(ModalTokens.Palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModalTokens.cornerRadius, style: .continuous))
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { route(.closeTapped) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(ModalTokens.Palette.subtitleText)
                }
            }
            Spacer()
        }
        .padding(32)
    }

    /// The one place interaction becomes outcome. `nil` = no-op (e.g. overlay tap when disabled).
    private func route(_ interaction: AlertInteraction) {
        resolve(interaction, config).map(onAction)
    }
}
