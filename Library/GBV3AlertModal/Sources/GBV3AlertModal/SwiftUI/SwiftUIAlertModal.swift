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
                    // The row's WIDTH first (UIKit's `lbTitle` fills the content width and centres
                    // its text inside it), because it is what decides where the text wraps.
                    .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))
                    // Then NO TRUNCATION, ever — see `NeverTruncates`. This is the counterpart of
                    // `generateLabelForTitleDesign`'s `numberOfLines = 0` +
                    // `lineBreakMode = .byWordWrapping`.
                    .modifier(NeverTruncates())
                    .modalGeometryProbe(.title)
                    .padding(.bottom, tokens.gapBelowTitle)
                    // OUTERMOST, and it has to be: `layoutPriority` is read by the enclosing
                    // container (`AlertModalScaffold`'s VStack) off the view it actually holds, so a
                    // `.padding` applied after it would be the view the VStack sees. This is the
                    // SwiftUI analogue of UIKit's vertical compression resistance, and the ORDERING
                    // is the directive: the title (1) out-ranks the subtitle (0), so when the VStack
                    // has less height than its children want, the subtitle is what gives way.
                    // Magnitudes are not comparable to UIKit's 0…1000 scale — only the order is.
                    .layoutPriority(Self.titleLayoutPriority)
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
                // Same no-truncation guarantee as the title — `generateLabelForSubtitleDesign` has
                // always been `numberOfLines = 0`, and it now states `.byWordWrapping` too.
                .modifier(NeverTruncates())
                .modalGeometryProbe(.subtitle)
                .padding(.bottom, tokens.gapBelowSubtitle)
                // The LOWER rung of the directive's ordering — see `subtitleLayoutPriority`.
                .layoutPriority(Self.subtitleLayoutPriority)
        case let .attributed(attributed):
            // The UIKit path stores an NSAttributedString on the holder. SwiftUI renders the
            // bridged value; styling is limited to the whitelisted bold/color/link subgrammar.
            Text(AttributedString(attributed))
                .multilineTextAlignment(.center)
                .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))
                .modifier(NeverTruncates())
                .modalGeometryProbe(.subtitle)
                .padding(.bottom, tokens.gapBelowSubtitle)
                .layoutPriority(Self.subtitleLayoutPriority)
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

/// **Unlimited lines, full size, no ellipsis — the SwiftUI half of the no-truncation directive.**
///
/// The owner directive is "title and subtitle should no truncated, title with more content compression
/// (title will still live while subtitle begin to wrap)", and it applies to BOTH renderers. On the
/// UIKit side it is `numberOfLines = 0` + `lineBreakMode = .byWordWrapping` with no
/// `adjustsFontSizeToFitWidth` (see `generateLabelForTitleDesign`). Here it is two modifiers, and both
/// are load-bearing:
///
/// * `lineLimit(nil)` — no cap on the line count. Stated rather than left implicit, because this is
///   the property the directive is ABOUT: this row previously carried `lineLimit(1)` plus a
///   `minimumScaleFactor` (the `ShrinkToFitSingleLine` ruler/overlay, now deleted), which reproduced
///   UIKit's old shrink-onto-one-line ladder faithfully — including its ellipsis on any title too wide
///   to shrink onto that line. Both sides now wrap instead, which is what the owner asked for and what
///   the example's `long-title` fixture has always expected.
/// * `fixedSize(horizontal: false, vertical: true)` — take the IDEAL height for the given width,
///   whatever height the container proposes. Without it, a `Text` handed less height than it needs
///   truncates with an ellipsis, and a height-pressured card is exactly that situation. Horizontal is
///   deliberately `false`: the row's width is set by `ContentRowWidth` (applied BEFORE this) and the
///   text must wrap inside it, not push it wider.
///
/// **What this costs, stated rather than hidden.** `fixedSize` means these rows never yield, so a card
/// whose content genuinely exceeds the screen grows past `cardMarginV` instead of truncating. That is
/// the pre-existing structural gap D-7 (SwiftUI has no scrolling subtitle slot — UIKit's
/// `svSubtitleContainer` is a `UIScrollView` whose height tie breaks under pressure), and this
/// modifier does not close it. It does pick a side: overflow, never an ellipsis, which is the
/// directive's own priority. `layoutPriority` still expresses the title-over-subtitle ORDER for every
/// allocation the VStack does make.
private struct NeverTruncates: ViewModifier {
    func body(content: Content) -> some View {
        content
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension SwiftUIAlertModal {
    /// **The SwiftUI analogue of UIKit's vertical compression-resistance ordering.**
    ///
    /// `ModalLayout.Priority` puts the title (900) above the subtitle label (750) and far above the
    /// subtitle SLOT's height tie (250/749). SwiftUI's `layoutPriority` is a `Double` on an
    /// unrelated scale, so only the ORDER carries over — which is all the directive states. Two
    /// named constants rather than bare literals in the body, so the ordering is one visible fact
    /// that a reader (and `TitleSubtitleTruncationTests`) can check instead of two magic numbers.
    static var titleLayoutPriority: Double { 1 }
    /// SwiftUI's default. Stated explicitly because the ordering is the point: if this ever rises to
    /// meet `titleLayoutPriority`, the directive is silently gone.
    static var subtitleLayoutPriority: Double { 0 }
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
