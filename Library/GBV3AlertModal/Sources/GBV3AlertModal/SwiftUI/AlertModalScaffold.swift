import SwiftUI

/// The shared modal chrome (spec D1's bespoke-content surface): full-screen scrim + centered card +
/// primary/secondary buttons + optional close, wrapped around a caller-supplied `@ViewBuilder` body.
/// Never dismisses itself. `SwiftUIAlertModal` is this with a built-in standard body; bespoke dialogs
/// (satisfaction picker, badge grid, worksheet) supply their own content instead of a `subtitleCustomView`.
public struct AlertModalScaffold<Content: View>: View {
    public let tokens: ModalTokens
    public var scrim: Color
    public let primaryTitle: String
    public var isPrimaryLoading: Bool = false
    public var primaryEnabled: Bool = true
    public let onPrimary: () -> Void
    public var secondaryTitle: String? = nil
    public var onSecondary: () -> Void = {}
    public var showClose: Bool = false
    public var onClose: () -> Void = {}
    /// Fires on scrim tap; `nil` = scrim not interactive. The caller decides what a tap means.
    public var onOverlayTap: (() -> Void)? = nil
    @ViewBuilder public let content: () -> Content

    public init(
        tokens: ModalTokens = .standard,
        scrim: Color? = nil,
        primaryTitle: String,
        isPrimaryLoading: Bool = false,
        primaryEnabled: Bool = true,
        onPrimary: @escaping () -> Void,
        secondaryTitle: String? = nil,
        onSecondary: @escaping () -> Void = {},
        showClose: Bool = false,
        onClose: @escaping () -> Void = {},
        onOverlayTap: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tokens = tokens
        // `scrim`'s default depends on `tokens`, which a default *argument* expression can't
        // reference (Swift default args can't read other parameters) — resolved here instead.
        self.scrim = scrim ?? tokens.palette.scrim
        self.primaryTitle = primaryTitle
        self.isPrimaryLoading = isPrimaryLoading
        self.primaryEnabled = primaryEnabled
        self.onPrimary = onPrimary
        self.secondaryTitle = secondaryTitle
        self.onSecondary = onSecondary
        self.showClose = showClose
        self.onClose = onClose
        self.onOverlayTap = onOverlayTap
        self.content = content
    }

    public var body: some View {
        ZStack {
            scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onOverlayTap?() }

            card
                .frame(maxWidth: tokens.cardMaxWidth)   // fills to margin, capped (not fixed width)
                .overlay(alignment: .topTrailing) {
                    // Pinned to the CARD's top-right corner (real modal: top.trailing.equalToSuperview,
                    // 48pt tap target), not the screen corner.
                    if showClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark")   // simple outline X (owner preference), no circle
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(tokens.palette.subtitleText)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.vertical, tokens.cardMarginV)     // card→screen margin: 40 v / 20 h
                .padding(.horizontal, tokens.cardMarginH)
        }
    }

    private var card: some View {
        // ponytail: primary/secondary always stack vertically here — `ResolvedModal.buttonAxis`
        // (spec C-1) isn't threaded through yet. Harmless today: `SwiftUIAlertModal` feeds the
        // resolver a sentinel `Properties` with no `buttonActionOrientation`, so `buttonAxis`
        // always resolves to `.vertical` anyway. Becomes load-bearing once a SwiftUI renderer
        // threads real `Properties` in (planned Task 6) — that's when this VStack needs an
        // HStack/VStack switch on `buttonAxis`, not before.
        VStack(spacing: 0) {
            content()
            Button(action: onPrimary) {
                if isPrimaryLoading {
                    ProgressView().tint(tokens.palette.onAccent)
                } else {
                    Text(primaryTitle)
                }
            }
            .buttonStyle(ObliquePrimaryStyle(tokens: tokens))
            .disabled(!primaryEnabled || isPrimaryLoading)

            if let secondaryTitle {
                Button(action: onSecondary) { Text(secondaryTitle) }
                    .buttonStyle(PlainSecondaryStyle(tokens: tokens))
                    .padding(.top, tokens.interButton)
            }
        }
        .padding(.vertical, tokens.contentPaddingV)     // inner content inset: 24 v / 32 h
        .padding(.horizontal, tokens.contentPaddingH)
        .background(tokens.palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: tokens.cornerRadius, style: .continuous))
    }
}
