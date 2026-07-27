import SwiftUI
import GBV3AlertModal

/// Pure-SwiftUI mirror of `GBAlertModal`'s content: a full-screen scrim with a centered card.
/// Holds NO branching logic — reads `ResolvedAlert` and routes taps through `resolve(_:_:)`.
/// Never dismisses itself; the caller reacts to `onAction` (matches the executor teardown contract).
struct SwiftUIAlertModal: View {
    let config: AlertDialog
    var scrim: Color = Color.black.opacity(0.6)
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
                .frame(maxWidth: 300)
                .padding(24)

            if resolved.showsClose {
                closeButton
            }
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            if resolved.showsBanner, let name = config.image?.assetName {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
            }
            if resolved.showsTitle, let title = config.title {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
            }
            if resolved.showsSubtitle, let subtitle = config.subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button { route(.primaryTapped) } label: {
                Group {
                    if isPrimaryLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(config.primary)
                    }
                }
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .disabled(!primaryEnabled || isPrimaryLoading)
            if resolved.showsSecondary, let secondary = config.secondary {
                Button { route(.secondaryTapped) } label: {
                    Text(secondary)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { route(.closeTapped) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
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
