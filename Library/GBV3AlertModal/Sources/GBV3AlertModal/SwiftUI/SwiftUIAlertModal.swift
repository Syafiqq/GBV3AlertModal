import Foundation
import SwiftUI

/// Pure-SwiftUI mirror of `GBAlertModal`'s content: `AlertModalScaffold` (shared chrome) with a
/// built-in standard body (banner/title/subtitle). Holds NO hand-rolled slot logic — it runs the
/// SAME `GBAlertModal.resolve` resolver `GBAlertModal` (UIKit) itself runs, over the SAME
/// `AlertHolder.make` mapping (spec C-1). Never dismisses itself; the caller reacts to `onAction`
/// (matches the executor teardown contract). Styling is fixed design (`ModalTokens`).
///
/// **Equivalence scope**: this view feeds `resolve` a fixed sentinel `Properties` (see `resolved`
/// below) and `isLandscape: false`, whereas the UIKit renderer feeds real caller-supplied
/// `alertProperties` and live orientation. So equivalence with UIKit is guaranteed by construction
/// only for the fields derived purely from `holder` — `showsBanner`, `showsTitle`, `subtitle`,
/// `showsCloseButton`, `closeOnTapOverlay`, `dismissOnAction`. Fields derived from `properties`/
/// orientation — `showsPrimary`, `showsSecondary`, `buttonAxis`, `buttonsMatchParent`,
/// `contentWidth` — run through the same code path but on different inputs, so they CAN diverge
/// from a real UIKit render today. Real `Properties` get threaded through once a SwiftUI renderer
/// supplies them (planned for Task 6), which closes this gap.
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
    // (`UIKitModalRenderer.AlertHolder.make`); `resolved(from:)` is the library's own 11-field
    // `GBAlertModal.resolve`, run over that holder. Neither is duplicated here.
    //
    // The `Properties` passed to `resolve` exist only to satisfy its presence checks for
    // primary/secondary (both require a non-nil UIKit `ActionStyle`, not just the action
    // string — see `GBAlertModal+ResolvedModal.swift`). This view never renders an `ActionStyle`
    // (buttons are styled by `ModalButtonStyles`), so only the styles' NON-NILNESS matters here;
    // their payload is thrown away. See the type doc comment above for what this sentinel means
    // for equivalence scope.
    private var holder: GBAlertModal.DataHolder {
        UIKitModalRenderer.AlertHolder.make(for: config, resolve: { _ in })
    }

    /// Takes `holder` as a parameter (rather than reaching for `self.holder` again) so `body`
    /// can compute it exactly once per render and hand it to both this and `subtitleView` — the
    /// resolver call itself is cheap, but `self.holder` re-runs `UIImage(named:)` and
    /// `ModalText.split`, which isn't free to repeat.
    private func resolved(from holder: GBAlertModal.DataHolder) -> GBAlertModal.ResolvedModal {
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
        // Computed exactly once per render: both `holder` and `resolved` are otherwise re-derived
        // (re-running `UIImage(named:)` / `ModalText.split` / the resolver) on every access.
        let holder = self.holder
        let resolved = self.resolved(from: holder)
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
    /// free), but `resolved.subtitle` decides ONLY none/plain/attributed/custom — never supplies
    /// the rendered payload. That split matters: `resolved.subtitle`'s `.plain` case carries the
    /// STRIPPED `String` `ModalText.split` produced for the UIKit holder (plain-vs-styled is a
    /// UIKit-scoped classification — see `ModalText.swift`), which would silently drop SwiftUI-
    /// scoped styling (e.g. `subtitle.foregroundColor = .red`) a caller applied the natural way.
    /// So `.plain` renders `config.subtitle` — the descriptor's own `AttributedString` — directly,
    /// exactly like `showsTitle`/`title` above. `.attributed` is the one case that DOES read the
    /// payload off `holder`: the resolver only records THAT the subtitle is attributed, the
    /// `NSAttributedString` itself lives on `holder.subtitleAttributed`, and UIKit renders that
    /// bridged value as-is — so mirroring it here (rather than the descriptor's `AttributedString`)
    /// is the correct equivalence, not a shortcut.
    @ViewBuilder
    private func subtitleView(
        resolved: GBAlertModal.ResolvedModal,
        holder: GBAlertModal.DataHolder
    ) -> some View {
        switch resolved.subtitle {
        case .none:
            EmptyView()
        case .plain:
            if let subtitle = config.subtitle {
                Text(subtitle)
                    .font(ModalTokens.subtitleFont)
                    .foregroundColor(ModalTokens.Palette.subtitleText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, ModalTokens.gapBelowSubtitle)
            }
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
