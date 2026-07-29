import SwiftUI
import UIKit // for `NSLayoutConstraint.Axis` — the vocabulary `ResolvedModal.buttonAxis` speaks.

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
    /// How primary/secondary stack — `GBAlertModal.ResolvedModal.buttonAxis` verbatim, so the
    /// SwiftUI card obeys the SAME resolver decision the UIKit main-action stack does. Defaults to
    /// `.vertical`, which is also what `resolve` returns when `Properties` sets no orientation.
    ///
    /// Yes, this puts a UIKit type (`NSLayoutConstraint.Axis`) in a SwiftUI public API. Deliberate:
    /// it is the exact type `ResolvedModal.buttonAxis` and `Properties.buttonActionOrientation`
    /// speak, and translating it to a SwiftUI-native enum here would add a second vocabulary to
    /// keep in sync for no behavioural gain.
    public var buttonAxis: NSLayoutConstraint.Axis = .vertical
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
        buttonAxis: NSLayoutConstraint.Axis = .vertical,
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
        self.buttonAxis = buttonAxis
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
                        // Tinted from `palette.closeButton`, which `ModalTokens.init(from:)` derives
                        // from `Properties.closeButtonTint` — the SAME field the UIKit renderer
                        // applies as `btCloseAction?.tintColor` (`GBAlertModal+Style.swift`). This
                        // used to reuse `palette.subtitleText`, which was a stand-in that happened
                        // to look close on the real preset.
                        Button(action: onClose) {
                            Image(systemName: "xmark")   // simple outline X (owner preference), no circle
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(tokens.palette.closeButton)
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
        // `buttonAxis` is the resolver's decision (`Properties.buttonActionOrientation`), obeyed
        // here the way the UIKit main-action `UIStackView` obeys it: `.horizontal` → HStack,
        // `.vertical` → the (default) vertical run. The vertical branch is spelled inline rather
        // than in a nested VStack so it stays byte-for-byte the layout that shipped before.
        VStack(spacing: 0) {
            content()
            if buttonAxis == .horizontal {
                // FALLBACK-POLICY NOTE (pre-existing, deliberately unchanged): `tokens.interButton`
                // falls back to `standard`'s literal 8 when `Properties.space` is nil, whereas the
                // UIKit main-action stack uses `properties?.space?.interButton ?? .zero`. Inert for
                // the real preset (which supplies `space`), but `buttonAxis` is load-bearing now,
                // so the difference is recorded here rather than silently inherited.
                HStack(spacing: tokens.interButton) {
                    primaryButton
                    if let secondaryTitle { secondaryButton(secondaryTitle) }
                }
            } else {
                primaryButton
                if let secondaryTitle {
                    secondaryButton(secondaryTitle).padding(.top, tokens.interButton)
                }
            }
        }
        .padding(.vertical, tokens.contentPaddingV)     // inner content inset: 24 v / 32 h
        .padding(.horizontal, tokens.contentPaddingH)
        .background(tokens.palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: tokens.cornerRadius, style: .continuous))
    }

    private var primaryButton: some View {
        Button(action: onPrimary) {
            if isPrimaryLoading {
                ProgressView().tint(tokens.palette.onAccent)
            } else {
                Text(primaryTitle)
            }
        }
        .buttonStyle(ObliquePrimaryStyle(tokens: tokens))
        .disabled(!primaryEnabled || isPrimaryLoading)
    }

    private func secondaryButton(_ title: String) -> some View {
        Button(action: onSecondary) { Text(title) }
            .buttonStyle(PlainSecondaryStyle(tokens: tokens))
    }
}
