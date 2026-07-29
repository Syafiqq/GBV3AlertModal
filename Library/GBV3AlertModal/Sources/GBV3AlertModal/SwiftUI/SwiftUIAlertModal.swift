import Foundation
import SwiftUI

/// Pure-SwiftUI mirror of `GBAlertModal`'s content: `AlertModalScaffold` (shared chrome) with a
/// built-in standard body (banner/title/subtitle). Holds NO hand-rolled slot logic — it runs the
/// SAME `GBAlertModal.resolve` resolver `GBAlertModal` (UIKit) itself runs, over the SAME
/// `AlertHolder.make` mapping (spec C-1). Never dismisses itself; the caller reacts to `onAction`
/// (matches the executor teardown contract). Styling is fixed design (`ModalTokens`).
///
/// **Equivalence scope**: `properties` is the resolver's other input, and `SwiftUIModalRenderer`
/// supplies the REAL caller-supplied `alertProperties`/`popupProperties` for every presentation it
/// hosts (via `ModalHost`) — the same values the UIKit renderer feeds `resolve`. So on the rendered
/// path all TEN properties-and-holder-derived resolver fields now agree with UIKit by construction:
/// `showsBanner`, `showsTitle`, `subtitle`, `showsCloseButton`, `closeOnTapOverlay`,
/// `dismissOnAction`, `showsPrimary`, `showsSecondary`, `buttonAxis` and `buttonsMatchParent`.
///
/// Two caveats remain, both narrow and deliberate:
/// * `isLandscape` is still fixed to `false` here, so `contentWidth` (the one orientation-sensitive
///   field) can still differ from a UIKit render in landscape. The SwiftUI card is width-adaptive
///   (`ModalTokens.cardMaxWidth` is a CAP, not a fixed width), so nothing reads `contentWidth` yet.
/// * `showsPrimary` is RESOLVED correctly but not yet OBEYED: `AlertModalScaffold` requires a
///   primary button, so a `Properties` with a nil `primaryActionStyle` hides the primary on the
///   UIKit path while SwiftUI still draws it. `showsSecondary`/`buttonAxis` are both resolved AND
///   obeyed (see `body` and `AlertModalScaffold.card`).
///
/// A caller that omits `properties` (SwiftUI-only demos, previews, tests) still gets the fixed
/// sentinel described on `resolved(from:)` — for those there is no `Properties` in play at all,
/// so there is nothing to diverge from.
@MainActor
public struct SwiftUIAlertModal: View {
    public let config: AlertDialog
    /// The real `GBAlertModal.Properties` this modal is being rendered under, when the caller has
    /// one (`SwiftUIModalRenderer` always does). `nil` falls back to `sentinelProperties`.
    public let properties: GBAlertModal.Properties?
    /// Presentation state — NOT part of `AlertDialog`. The caller owns this; the view only reads it.
    public var primaryEnabled: Bool = true
    public var isPrimaryLoading: Bool = false
    public let tokens: ModalTokens
    public let onAction: (AlertDialog.Result) -> Void

    public init(
        config: AlertDialog,
        properties: GBAlertModal.Properties? = nil,
        primaryEnabled: Bool = true,
        isPrimaryLoading: Bool = false,
        tokens: ModalTokens = .standard,
        onAction: @escaping (AlertDialog.Result) -> Void
    ) {
        self.config = config
        self.properties = properties
        self.primaryEnabled = primaryEnabled
        self.isPrimaryLoading = isPrimaryLoading
        self.tokens = tokens
        self.onAction = onAction
    }

    // MARK: - Slot resolution (shared with UIKit — spec C-1)
    //
    // `holder` is the same descriptor→`DataHolder` mapping the executor's UIKit renderer uses
    // (`UIKitModalRenderer.AlertHolder.make`); `resolved(from:)` is the library's own 11-field
    // `GBAlertModal.resolve`, run over that holder. Neither is duplicated here.
    private var holder: GBAlertModal.DataHolder {
        UIKitModalRenderer.AlertHolder.make(for: config, resolve: { _ in })
    }

    /// Fallback for callers with no real `Properties` (previews, SwiftUI-only demos, tests). It
    /// exists only to satisfy `resolve`'s presence checks for primary/secondary, which require a
    /// non-nil UIKit `ActionStyle` and not just the action string (see
    /// `GBAlertModal+ResolvedModal.swift`). This view never renders an `ActionStyle` — buttons are
    /// styled by `ModalButtonStyles` — so only the styles' NON-NILNESS matters; their payload is
    /// thrown away. Computed (not a `static let`) so it needs no `Sendable` conformance from
    /// `Properties`, which is a UIKit-backed type.
    private static var sentinelProperties: GBAlertModal.Properties {
        GBAlertModal.Properties(
            primaryActionStyle: .plain(.init()),
            secondaryActionStyle: .plain(.init())
        )
    }

    /// Takes `holder` as a parameter (rather than reaching for `self.holder` again) so `body`
    /// can compute it exactly once per render and hand it to both this and `subtitleView` — the
    /// resolver call itself is cheap, but `self.holder` re-runs `UIImage(named:)` and
    /// `ModalText.split`, which isn't free to repeat.
    private func resolved(from holder: GBAlertModal.DataHolder) -> GBAlertModal.ResolvedModal {
        GBAlertModal.resolve(
            properties: properties ?? Self.sentinelProperties,
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
            tokens: tokens,
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
            onOverlayTap: { if resolved.closeOnTapOverlay { onAction(.dismissed) } },
            buttonAxis: resolved.buttonAxis
        ) {
            if resolved.showsBanner, let name = config.image?.assetName {
                Image(name)
                    .resizable()
                    .scaledToFit()   // preserve the image's natural aspect ratio (no distortion)
                    // The slot geometry `Properties` asks for: ratio, fixed height and cap, with
                    // the UIKit constraint precedence — see `ModalTokens.bannerLayout`.
                    .modifier(ModalBannerGeometry(layout: tokens.bannerLayout))
                    .padding(.bottom, tokens.gapBelowBanner)
            }
            if resolved.showsTitle, let title = config.title {
                Text(title)
                    .font(tokens.titleFont)
                    .foregroundColor(tokens.palette.titleText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, tokens.gapBelowTitle)
            }
            subtitleView(resolved: resolved, holder: holder)
        }
    }

    /// Renders whatever `subtitlePayload` selected. All the DECISION + PAYLOAD SELECTION logic
    /// lives in that pure function (testable without a view); this just switches on its result.
    @ViewBuilder
    private func subtitleView(
        resolved: GBAlertModal.ResolvedModal,
        holder: GBAlertModal.DataHolder
    ) -> some View {
        switch Self.subtitlePayload(resolved: resolved, config: config, holder: holder) {
        case .none:
            EmptyView()
        case let .plain(subtitle):
            Text(subtitle)
                .font(tokens.subtitleFont)
                .foregroundColor(tokens.palette.subtitleText)
                .multilineTextAlignment(.center)
                .padding(.bottom, tokens.gapBelowSubtitle)
        case let .attributed(attributed):
            // The UIKit path stores an NSAttributedString on the holder. SwiftUI renders the
            // bridged value; styling is limited to the whitelisted bold/color/link subgrammar.
            Text(AttributedString(attributed))
                .multilineTextAlignment(.center)
                .padding(.bottom, tokens.gapBelowSubtitle)
        case .custom:
            // A plain `AlertDialog` never populates `subtitleCustomView` (that field doesn't exist
            // on this descriptor), so this case is unreachable from `SwiftUIAlertModal` in practice.
            // Bespoke content is served by `AlertModalScaffold`'s `ViewBuilder` slot instead.
            EmptyView()
        }
    }
}

extension SwiftUIAlertModal {
    /// What `subtitleView` renders, once the DECISION (`ResolvedModal.SubtitleKind`) has been
    /// turned into an actual payload. A separate type (not just `SubtitleKind` reused) because the
    /// `.plain` payload is deliberately NOT `SubtitleKind.plain`'s associated `String` — see
    /// `subtitlePayload` below for why.
    enum SubtitlePayload {
        case none
        case plain(AttributedString)
        case attributed(NSAttributedString)
        case custom
    }

    /// The subtitle DECISION + PAYLOAD SELECTION, pulled out of the view body so it's a plain,
    /// synchronous function a test can call directly (no `View` construction, no hosting).
    ///
    /// `resolved.subtitle` (`ResolvedModal.SubtitleKind`) decides ONLY none/plain/attributed/
    /// custom — it never supplies the payload this function returns for `.plain`. That split
    /// matters: `SubtitleKind.plain`'s associated `String` is the STRIPPED text
    /// `ModalText.split` produced for the UIKit `holder` (plain-vs-styled is a UIKit-scoped
    /// classification — see `ModalText.swift`), which would silently drop SwiftUI-scoped styling
    /// (e.g. `subtitle.swiftUI.foregroundColor = .red`) a caller applied the natural way. So
    /// `.plain` here returns `config.subtitle` — the descriptor's own `AttributedString` — as-is,
    /// exactly like the `showsTitle`/`title` pairing in `body` above.
    ///
    /// `.attributed` is the one case that DOES read its payload off `holder`: the resolver only
    /// records THAT the subtitle is attributed, the `NSAttributedString` itself lives on
    /// `holder.subtitleAttributed`, and UIKit renders that bridged value as-is — so returning it
    /// here (rather than the descriptor's `AttributedString`) is the correct equivalence, not a
    /// shortcut.
    static func subtitlePayload(
        resolved: GBAlertModal.ResolvedModal,
        config: AlertDialog,
        holder: GBAlertModal.DataHolder
    ) -> SubtitlePayload {
        switch resolved.subtitle {
        case .none:
            return .none
        case .plain:
            guard let subtitle = config.subtitle else { return .none }
            return .plain(subtitle)
        case .attributed:
            return .attributed(holder.subtitleAttributed ?? NSAttributedString())
        case .custom:
            return .custom
        }
    }
}
