import SwiftUI
import GBV3AlertModal

/// The shared modal chrome (spec D1's bespoke-content surface): full-screen scrim + centered card +
/// primary/secondary buttons + optional close, wrapped around a caller-supplied `@ViewBuilder` body.
/// Never dismisses itself. `SwiftUIAlertModal` is this with a built-in standard body; bespoke dialogs
/// (satisfaction picker, badge grid, worksheet) supply their own content instead of a `subtitleCustomView`.
struct AlertModalScaffold<Content: View>: View {
    var scrim: Color = ModalTokens.Palette.scrim.opacity(ModalTokens.scrimOpacity)
    let primaryTitle: String
    var isPrimaryLoading: Bool = false
    var primaryEnabled: Bool = true
    let onPrimary: () -> Void
    var secondaryTitle: String? = nil
    var onSecondary: () -> Void = {}
    var showClose: Bool = false
    var onClose: () -> Void = {}
    /// Fires on scrim tap; `nil` = scrim not interactive. The caller decides what a tap means.
    var onOverlayTap: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onOverlayTap?() }

            card
                .frame(maxWidth: ModalTokens.cardMaxWidth)   // fills to margin, capped (not fixed width)
                .overlay(alignment: .topTrailing) {
                    // Pinned to the CARD's top-right corner (real modal: top.trailing.equalToSuperview,
                    // 48pt tap target), not the screen corner.
                    if showClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark")   // simple outline X (owner preference), no circle
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(ModalTokens.Palette.subtitleText)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.vertical, ModalTokens.cardMarginV)     // card→screen margin: 40 v / 20 h
                .padding(.horizontal, ModalTokens.cardMarginH)
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            content()
            Button(action: onPrimary) {
                if isPrimaryLoading {
                    ProgressView().tint(ModalTokens.Palette.onAccent)
                } else {
                    Text(primaryTitle)
                }
            }
            .buttonStyle(ObliquePrimaryStyle())
            .disabled(!primaryEnabled || isPrimaryLoading)

            if let secondaryTitle {
                Button(action: onSecondary) { Text(secondaryTitle) }
                    .buttonStyle(PlainSecondaryStyle())
                    .padding(.top, ModalTokens.interButton)
            }
        }
        .padding(.vertical, ModalTokens.contentPaddingV)     // inner content inset: 24 v / 32 h
        .padding(.horizontal, ModalTokens.contentPaddingH)
        .background(ModalTokens.Palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ModalTokens.cornerRadius, style: .continuous))
    }
}
