import Foundation
import SwiftUI

/// Pure-SwiftUI mirror of `GBAlertModal`'s content: `AlertModalScaffold` (shared chrome) with a
/// built-in standard body (banner/title/subtitle). Holds NO branching logic beyond `ResolvedModal`
/// slot decisions — the SAME resolver `GBAlertModal` (UIKit) itself runs, so structural equivalence
/// between the two renderers is true by construction (spec C-1), not something a comparison harness
/// has to detect. Never dismisses itself; the caller reacts to `onAction` (matches the executor
/// teardown contract). Styling is fixed design (`ModalTokens`).
@MainActor
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

    // MARK: - Slot resolution (shared with UIKit — spec C-1)
    //
    // `holder` is the same descriptor→`DataHolder` mapping the executor's UIKit renderer uses
    // (`UIKitModalRenderer.AlertHolder.make`); `resolved` is the library's own 11-field
    // `GBAlertModal.resolve`, run over that holder. Neither is duplicated here.
    //
    // The `Properties` passed to `resolve` exist only to satisfy its presence checks for
    // primary/secondary (both require a non-nil UIKit `ActionStyle`, not just the action
    // string — see `GBAlertModal+ResolvedModal.swift`). This view never renders an `ActionStyle`
    // (buttons are styled by `ModalButtonStyles`), so only the styles' NON-NILNESS matters here;
    // their payload is thrown away.
    private var holder: GBAlertModal.DataHolder {
        UIKitModalRenderer.AlertHolder.make(for: config, resolve: { _ in })
    }

    private var resolved: GBAlertModal.ResolvedModal {
        GBAlertModal.resolve(
            properties: GBAlertModal.Properties(
                primaryActionStyle: .plain(.init()),
                secondaryActionStyle: .plain(.init())
            ),
            holder: holder,
            isLandscape: false
        )
    }

    public var body: some View {
        // Computed once per render (not per property access): `holder` re-runs `UIImage(named:)`
        // + `ModalText.split` and `resolved` re-runs the resolver, so re-fetching either via the
        // computed properties above on every use below would repeat that work several times over.
        let holder = self.holder
        let resolved = self.resolved
        return AlertModalScaffold(
            primaryTitle: config.primary,
            isPrimaryLoading: isPrimaryLoading,
            primaryEnabled: primaryEnabled,
            onPrimary: { onAction(.primary) },
            secondaryTitle: resolved.showsSecondary ? config.secondary : nil,
            onSecondary: { onAction(.secondary) },
            showClose: resolved.showsCloseButton,
            onClose: { onAction(.dismissed) },
            // `resolved.closeOnTapOverlay` mirrors `holder.closeOnTapOverlay` / `config.closeOnTapOverlay`
            // — reading it off the resolver keeps this decision flowing through the shared chain too.
            onOverlayTap: { if resolved.closeOnTapOverlay { onAction(.dismissed) } }
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
            subtitleView(resolved: resolved, holder: holder)
        }
    }

    /// Switches on the resolver's four-case `SubtitleKind` (richer than the old single
    /// `showsSubtitle` bool this view used to derive on its own — spec C-1 picks this up for
    /// free). `.attributed` needs `holder`, not just `resolved`: the resolver only records THAT
    /// the subtitle is attributed, not the `NSAttributedString` payload itself — that lives on
    /// the `DataHolder`, exactly where the UIKit view reads it from (`holder.subtitleAttributed`).
    @ViewBuilder
    private func subtitleView(
        resolved: GBAlertModal.ResolvedModal,
        holder: GBAlertModal.DataHolder
    ) -> some View {
        switch resolved.subtitle {
        case .none:
            EmptyView()
        case let .plain(text):
            Text(text)
                .font(ModalTokens.subtitleFont)
                .foregroundColor(ModalTokens.Palette.subtitleText)
                .multilineTextAlignment(.center)
                .padding(.bottom, ModalTokens.gapBelowSubtitle)
        case .attributed:
            // The UIKit path stores an NSAttributedString on the holder. SwiftUI renders the
            // bridged value; styling is limited to the whitelisted bold/color/link subgrammar.
            Text(AttributedString(holder.subtitleAttributed ?? NSAttributedString()))
                .multilineTextAlignment(.center)
                .padding(.bottom, ModalTokens.gapBelowSubtitle)
        case .custom:
            // A plain `AlertDialog` never populates `subtitleCustomView` (that field doesn't exist
            // on this descriptor), so this case is unreachable from `SwiftUIAlertModal` in practice.
            // Bespoke content is served by `AlertModalScaffold`'s `ViewBuilder` slot instead.
            EmptyView()
        }
    }
}
