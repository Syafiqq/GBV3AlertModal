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
///   field) can still differ from a UIKit render in landscape. The card is width-adaptive
///   (`ModalTokens.cardMaxWidth` is a CAP, not a fixed width) — but the PORTRAIT reading of
///   `contentWidth` now does reach the layout, as `ModalTokens.contentMaxWidth` on the content
///   container (see `AlertModalScaffold.card`).
/// * `showsPrimary` is RESOLVED correctly but not yet OBEYED: `AlertModalScaffold` requires a
///   primary button, so a `Properties` with a nil `primaryActionStyle` hides the primary on the
///   UIKit path while SwiftUI still draws it. `showsSecondary`, `buttonAxis` and
///   `buttonsMatchParent` are all resolved AND obeyed (see `body` and `AlertModalScaffold.card`).
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
    ///
    /// `buttonActionShouldMatchParent: true` is stated EXPLICITLY, and it is not cosmetic:
    /// `Properties.init` defaults that field to `false`, so a sentinel that omitted it would resolve
    /// `buttonsMatchParent == false` and — now that `AlertModalScaffold` actually obeys the flag —
    /// make the primary button HUG its label in every preview, demo and property-less test, which no
    /// real Genie preset does (they all set it `true`). The sentinel's job is to stand in for the real
    /// preset's SHAPE, so it has to state the real preset's value here rather than inherit an
    /// unrelated init default.
    private static var sentinelProperties: GBAlertModal.Properties {
        GBAlertModal.Properties(
            buttonActionShouldMatchParent: true,
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
            buttonAxis: resolved.buttonAxis,
            // `Properties.buttonActionShouldMatchParent`, via the shared resolver — the same field
            // UIKit turns into `svMainActionContainer.alignment`. Resolved AND obeyed now; it used to
            // be resolved and dropped (task 17, finding D-4).
            buttonsMatchParent: resolved.buttonsMatchParent
        ) {
            if resolved.showsBanner, let name = config.image?.assetName {
                Image(name)
                    .resizable()
                    .scaledToFit()   // preserve the image's natural aspect ratio (no distortion)
                    // The slot geometry `Properties` asks for: ratio, fixed height and cap, with
                    // the UIKit constraint precedence — see `ModalTokens.bannerLayout`.
                    .modifier(ModalBannerGeometry(layout: tokens.bannerLayout))
                    // Probed AFTER the slot geometry and BEFORE the gap, so it measures the banner
                    // SLOT — the counterpart of UIKit's `vwBanner`, not of `vwBannerAndBelowDivider`.
                    //
                    // Deliberately NOT given `ContentRowWidth`, unlike the title and subtitle rows:
                    // this row's width is driven by `bannerRatio`/`bannerFixedHeight`
                    // (`ModalBannerGeometry`), and the banner is the ONE element the differential
                    // gate cannot compare from the library test bundle (the assets live in the app —
                    // see `DifferentialGeometry.bannerIsUnresolvableInTheLibraryBundle`). Widening it
                    // to the content width here would be an unmeasured change to the one row nothing
                    // can check.
                    .modalGeometryProbe(.banner)
                    .padding(.bottom, tokens.gapBelowBanner)
            }
            if resolved.showsTitle, let title = config.title {
                Text(title)
                    .font(tokens.titleFont)
                    .foregroundColor(tokens.palette.titleText)
                    .multilineTextAlignment(.center)
                    // **SHRINK TO FIT ONE LINE — do not wrap.** `lbTitle` is built with
                    // `numberOfLines = 2`, `adjustsFontSizeToFitWidth = true` and
                    // `minimumScaleFactor = 0.75` (`generateLabelForTitleDesign`), and the MEASURED
                    // behaviour of that combination is a single shrunk line, not two full-size ones:
                    // the gate caught UIKit drawing two real titles (≈273pt and ≈284pt of text) as one
                    // 28.7pt line in a 256pt label while this `Text` wrapped them and made the card
                    // 28.7pt taller — cascading into the subtitle's and both buttons' y (task 17,
                    // Class B). `.lineLimit(2)` does NOT reproduce it: with unbounded height SwiftUI
                    // has room for two full-size lines, so it never engages the scale factor.
                    //
                    // ONE REGIME STILL DIVERGES, stated rather than hidden: for a title too wide even
                    // at 0.75 (i.e. wider than ~133% of the content width) UIKit spends its second
                    // line, while this truncates with an ellipsis. No shape in the differential suite
                    // or the 26-shape catalog is in that regime — the widest real title measured is
                    // ~107% — and closing it needs the shrink-vs-wrap DECISION, which means measuring
                    // the string against the row width (a `UIFont` in `ModalTokens` and a text
                    // measurement in the view). That is a redesign, not a modifier, and it would buy
                    // fidelity in a regime no shipped dialog occupies.
                    .lineLimit(1)
                    .minimumScaleFactor(tokens.titleMinimumScaleFactor)
                    // BEFORE the probe, so the probe measures the row the way UIKit's `lbTitle` is
                    // measured — filled to the content width, with the text centred inside it.
                    .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))
                    .modalGeometryProbe(.title)
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
                .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))
                .modalGeometryProbe(.subtitle)
                .padding(.bottom, tokens.gapBelowSubtitle)
        case let .attributed(attributed):
            // The UIKit path stores an NSAttributedString on the holder. SwiftUI renders the
            // bridged value; styling is limited to the whitelisted bold/color/link subgrammar.
            Text(AttributedString(attributed))
                .multilineTextAlignment(.center)
                .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))
                .modalGeometryProbe(.subtitle)
                .padding(.bottom, tokens.gapBelowSubtitle)
        case .custom:
            // A plain `AlertDialog` never populates `subtitleCustomView` (that field doesn't exist
            // on this descriptor), so this case is unreachable from `SwiftUIAlertModal` in practice.
            // Bespoke content is served by `AlertModalScaffold`'s `ViewBuilder` slot instead.
            EmptyView()
        }
    }
}

/// `ContentProperty.childShouldMatchParent`, expressed on ONE content row.
///
/// UIKit says it once, on the stack (`svContentContainer.alignment = .fill` vs `.center`); SwiftUI has
/// no stack-wide "children fill" switch, so each row states it. `.fill` makes `lbTitle` and
/// `svSubtitleContainer` span the content width — 256 on the real preset — with their own
/// `textAlignment = .center` centring the text inside that; `.center` makes each row hug.
///
/// Both look identical for centred text, which is exactly why this went unnoticed until the frames
/// were compared (task 17, finding D-6). It stops being invisible the moment anything puts a
/// background, a border or a tap target on a row — and the row's WIDTH is also what decides where the
/// text wraps when the row is narrower than the content area.
///
/// A `ViewModifier` rather than an `if` in the body: the two branches must stay ONE view identity, or
/// toggling the flag would tear down and rebuild the row.
private struct ContentRowWidth: ViewModifier {
    let fillsWidth: Bool

    func body(content: Content) -> some View {
        content.frame(maxWidth: fillsWidth ? CGFloat.infinity : nil)
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
