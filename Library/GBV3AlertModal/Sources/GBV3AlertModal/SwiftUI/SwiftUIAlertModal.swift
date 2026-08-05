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
    private func resolved(from holder: GBAlertModal.DataHolder, isLandscape: Bool) -> GBAlertModal.ResolvedModal {
        GBAlertModal.resolve(
            properties: properties ?? Self.sentinelProperties,
            holder: holder,
            isLandscape: isLandscape
        )
    }

    /// **The orientation the resolver is told about, read from the screen rather than assumed.**
    ///
    /// This was hardcoded `false`, which meant `contentWidth` — the one orientation-sensitive field
    /// the resolver produces — always came back as the PORTRAIT width. Inert on every Genie preset,
    /// because each sets `fixedWidthPortrait == fixedWidthLandscape`, but wrong for any preset that
    /// distinguishes them, and it is why the differential harness hosted portrait only: a landscape
    /// comparison would have been measuring this assumption rather than the layout.
    ///
    /// Read from the modal's OWN container, matching what UIKit does. `GBAlertModal.makeResolvedModal`
    /// takes `isLandscape: bounds.width > bounds.height` from `self.bounds` — deliberately, and its
    /// comment says why: reading the window scene's real orientation would make the landscape width
    /// branch untestable, because a test host cannot rotate a device. Reading the container makes it
    /// a function of the size the modal was given.
    ///
    /// Using `UIScreen.main` here instead would have reintroduced exactly that problem from the other
    /// side: the differential harness sets a landscape WINDOW, and the screen would still have said
    /// portrait, so a landscape comparison would measure two different assumptions rather than two
    /// layouts.
    public var body: some View {
        GeometryReader { proxy in
            content(isLandscape: proxy.size.width > proxy.size.height)
        }
    }

    private func content(isLandscape: Bool) -> some View {
        // Computed exactly once per render: both `holder` and `resolved` are otherwise re-derived
        // (re-running `UIImage(named:)` / `ModalText.split` / the resolver) on every access.
        let holder = self.holder
        let resolved = self.resolved(from: holder, isLandscape: isLandscape)
        // **The banner's EXISTENCE, decided here and only here.**
        //
        // Two facts, both known before any layout runs: the resolver said this modal shows a banner,
        // and the named artwork actually resolves to a non-degenerate image. That second half is the
        // same predicate `DifferentialGeometry.bannerIsUnresolvableInTheLibraryBundle` applies, and
        // it is what makes an unresolvable asset `absentOnBoth` rather than SwiftUI-only.
        //
        // It used to be `BannerSlot` that decided, by gating its whole body on
        // `bannerGeometry.height > 0` — which made EXISTENCE a function of LAYOUT, because that
        // geometry only arrives once `AlertModalScaffold`'s `GeometryReader` has run. Anywhere the
        // reader does not run (a structural `inspect()`, a preview that never gets a size) the banner
        // vanished from the view tree altogether rather than merely being unsized. Existence is a
        // resolver decision; only SIZE is a layout decision, and the two are separated here.
        //
        // `resolved.showsBanner` is the WHOLE answer, and this used to ask half of it twice. The
        // shared resolver computes that flag from `holder.banner`, which
        // `UIKitModalRenderer.AlertHolder.make` produces with
        // `UIImage(named:in:compatibleWith:)` — the identical lookup `ModalImage.pointSize` runs —
        // and it is already "non-nil AND non-degenerate". Re-deriving `drawsBanner` from the point
        // size therefore recomputed a decision the resolver had made, from a second copy of the
        // same fact.
        let drawsBanner = resolved.showsBanner
        // The SIZE is the one thing the flag cannot carry, and `ModalTokens.bannerGeometry` needs
        // it before any layout runs (`.resizable()` discards it). Short-circuited on the flag, so a
        // modal with no banner never pays for the lookup at all.
        let bannerArtworkSize = drawsBanner ? (config.image?.pointSize ?? .zero) : .zero
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
            buttonsMatchParent: resolved.buttonsMatchParent,
            // Drives `ModalTokens.bannerGeometry` inside the scaffold's `GeometryReader`, which needs
            // the artwork's POINT size BEFORE layout — `.resizable()` throws it away. `.zero` when
            // this modal shows no banner, which collapses `bannerGeometry` to `.zero` and leaves
            // every non-banner shape's layout untouched.
            bannerArtworkSize: bannerArtworkSize
        ) {
            if drawsBanner, let image = config.image {
                BannerSlot(image: image, tokens: tokens)
            }
            titleAndSubtitle(resolved: resolved, holder: holder)
        }
    }

    /// The two text rows, in the order and with the priorities the directive states.
    @ViewBuilder
    private func titleAndSubtitle(
        resolved: GBAlertModal.ResolvedModal, holder: GBAlertModal.DataHolder
    ) -> some View {
            if resolved.showsTitle, let title = config.title {
                Text(title)
                    .font(tokens.titleFont)
                    .foregroundColor(tokens.palette.titleText)
                    .multilineTextAlignment(.center)
                    // The row's WIDTH first (UIKit's `lbTitle` fills the content width and centres
                    // its text inside it), because it is what decides where the text wraps.
                    .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))
                    // Then the ladder — see `NeverTruncates`. Counterpart of
                    // `generateLabelForTitleDesign`'s `numberOfLines = 0` + `.byWordWrapping`, and of
                    // `adjustTitleFontScale`'s shrink floor, which is the SAME number this reads.
                    .modifier(NeverTruncates(minimumScaleFactor: tokens.titleMinimumScaleFactor))
                    // …and the floor on the SPACE, not just on the glyph scale. `minimumScaleFactor`
                    // caps how small the text is DRAWN; nothing stops the row being proposed less than
                    // even that needs, and a `Text` in a too-small frame clips (measured: 64.7pt
                    // allocated where the floor-scaled text needed 85.9pt, and the difference was
                    // silently dropped). Provably inert whenever the row gets its ideal height — the
                    // same string in a smaller font never needs MORE height — so it cannot disturb an
                    // unpressured shape. See `ModalTokens.titleFloorHeight(for:)`.
                    .frame(minHeight: tokens.titleFloorHeight(for: String(title.characters)))
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

    // `textRows` sat here: a `Properties.contentScrollable` branch that wrapped `titleAndSubtitle`
    // in an outer `ScrollableContent` (title AND subtitle together) or passed it straight through.
    // Both the branch and the wrapper are DELETED. `SubtitleSlot` below scrolls the subtitle
    // unconditionally, which is what the flag was reaching for, and the outer wrapper's only
    // measurable remaining effect was to de-pressurise that slot so it reported content (1222pt)
    // where UIKit reported a viewport (645.3) — one row of the differential gate lost, nothing
    // gained. `card` now calls `titleAndSubtitle` directly.

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
            SubtitleSlot(
                floor: tokens.subtitleFloorHeight, fillsWidth: tokens.contentChildrenFillWidth
            ) {
                Text(subtitle)
                    .font(tokens.subtitleFont)
                    .foregroundColor(tokens.palette.subtitleText)
                    .multilineTextAlignment(.center)
                    .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))
                    // Same guarantee as the title, one rung lower: `layoutPriority` (below) makes
                    // this the row that is squeezed FIRST, and the scale factor means it answers by
                    // shrinking rather than by ellipsizing.
                    .modifier(NeverTruncates(minimumScaleFactor: tokens.titleMinimumScaleFactor))
            }
            .modalGeometryProbe(.subtitle)
            .padding(.bottom, tokens.gapBelowSubtitle)
            // The LOWER rung of the directive's ordering — see `subtitleLayoutPriority`.
            .layoutPriority(Self.subtitleLayoutPriority)
        case let .attributed(attributed):
            SubtitleSlot(
                floor: tokens.subtitleFloorHeight, fillsWidth: tokens.contentChildrenFillWidth
            ) {
                // The UIKit path stores an NSAttributedString on the holder. Bridged straight
                // through, its runs stay on UIKIT's attribute scope and SwiftUI's `Text` — which
                // reads its own — draws them completely unstyled. `AttributedTextBridge` re-scopes
                // colour and font so the emphasis the caller asked for survives. Styling stays
                // limited to the whitelisted bold/color/link subgrammar.
                Text(AttributedTextBridge.swiftUIRenderable(attributed))
                    .multilineTextAlignment(.center)
                    .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))
                    .modifier(NeverTruncates(minimumScaleFactor: tokens.titleMinimumScaleFactor))
            }
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

/// **The banner SLOT + picture, mirroring UIKit's `vwBanner`/`ivBanner` split.**
///
/// A dedicated `View`, not inline content in `SwiftUIAlertModal.content(isLandscape:)`, and that is
/// load-bearing rather than stylistic. `bannerGeometry` is published by `AlertModalScaffold` as an
/// `.environment(...)` modifier on `card` — a DESCENDANT of `SwiftUIAlertModal` in the render tree,
/// since `AlertModalScaffold` is what `SwiftUIAlertModal.body` returns. `@Environment` only flows
/// ancestor → descendant, so reading `\.modalBannerGeometry` as a stored property ON
/// `SwiftUIAlertModal` itself cannot see it: that property would be resolved from
/// `SwiftUIAlertModal`'s OWN ambient environment, fixed before `AlertModalScaffold` — its child —
/// ever computes anything, and permanently `.zero`. Worse, gating with a plain `if` inside the
/// `content` closure bakes that stale value in at closure-CONSTRUCTION time (when
/// `SwiftUIAlertModal.body` runs), not at the later point `card`'s `VStack` actually calls the
/// closure.
///
/// This type sidesteps both problems: it is constructed inside `content()`, so it becomes a genuine
/// descendant of `card` in the tree, and its OWN `@Environment` is resolved at ITS position — after
/// the scaffold has already published the real geometry.
///
/// **What this view decides is SIZE, never EXISTENCE.** The body used to be wrapped in
/// `if bannerGeometry.height > 0`, which read as a harmless "nothing measured yet, draw nothing" —
/// and was not. The geometry only becomes non-`.zero` once `AlertModalScaffold`'s `GeometryReader`
/// has run, so that guard made the banner's very presence in the view tree a consequence of layout:
/// under a structural (non-hosted) `inspect()`, where no reader evaluates, the `Image` was never
/// constructed at all and a wired-up banner read as a missing one. Whether there IS a banner is a
/// resolver decision plus a resolvable asset, and `SwiftUIAlertModal.content(isLandscape:)` makes it
/// there, before this view is built; by the time this body runs the answer is already yes. The
/// zero-artwork collapse that guard was reaching for is served by the SAME call-site check, on the
/// artwork's point size, which is known without measuring anything.
///
/// **One behavioural difference that removal left behind, recorded because it is real and
/// unreachable rather than because it needs fixing.** There is a narrow case where the artwork
/// RESOLVES with a non-zero point size — so the call site says yes and this view is built — and
/// `ModalTokens.bannerGeometry` still returns `.zero`: it does that when the ratio is not a usable
/// number, i.e. when `Properties.bannerRatio` is explicitly zero, negative, NaN or infinite (a
/// natural ratio derived from a non-zero size never is). The old `if bannerGeometry.height > 0`
/// guard skipped the whole body there and published NO `.banner` probe; this version emits a
/// zero-SIZE one instead. Downstream that is a `verdict: .onlySwiftUI` row in the differential
/// harness rather than an `absent (both)` — a visible, honest disagreement, and the harness's own
/// `assertNonDegenerate` would report the zero rect.
///
/// It is not reachable from any preset in the app: every one of them either omits `bannerRatio`
/// (natural aspect) or spells it as a ratio of two positive asset dimensions. No guard is added for
/// it — a branch nothing can reach is a branch nothing can test, and the honest zero-size probe is a
/// better failure mode than a silently absent one.
///
/// **This row does NOT honour `contentChildrenFillWidth`** — it applies no `ContentRowWidth`, where
/// the title and subtitle rows both do. Its width is the banner column, always, because that is
/// what UIKit's `vwBanner` resolves to. Inert for every shipping preset (all of them set the flag
/// `true`, so filling is what the other rows do anyway) and recorded here because it was recorded
/// nowhere: a preset that set it `false` would hug the title and subtitle while this row still
/// spanned the column.
private struct BannerSlot: View {
    let image: ModalImage
    let tokens: ModalTokens
    @Environment(\.modalBannerGeometry) private var bannerGeometry

    var body: some View {
        // UIKit models the banner as TWO views and so does this: `Color.clear` is the SLOT
        // (`vwBanner`), sized by `ModalTokens.bannerGeometry`; the image is `ivBanner`,
        // letterboxed inside it by `scaledToFit()` and imposing no size of its own.
        //
        // This used to be ONE view — `.resizable().scaledToFit()` with the aspect ratio applied
        // to the image and the width frame applied OUTSIDE it, so the ratio never received the
        // content column and settled on whatever vertical scrap the VStack offered: 26.8pt
        // against UIKit's 160.
        //
        // **The height frame is a `maxHeight`, and that is UIKit's yield semantics — not a
        // weaker version of them.** This was `.frame(width:height:)`, rigid, on the stated
        // reasoning that "the height must be REACHED, not merely bounded" and that
        // `.frame(maxHeight:)` therefore could not work here. Measured, that is false, and the
        // reason it is false is a property of THIS view specifically: `Color.clear` is GREEDY. It
        // expands to fill whatever it is offered, up to its `maxHeight`. So:
        //
        // * where the card is free to grow (portrait, and any roomy landscape card), the slot is
        //   offered at least `bannerGeometry.height` and takes exactly it — a `maxHeight` frame and
        //   a rigid one are indistinguishable, and every portrait frame is bit-identical under the
        //   two (`DifferentialGeometryTests`' portrait banner rows, unchanged across the switch);
        // * where the card is against its ceiling (landscape, every banner shape), the slot is
        //   offered only the residual and takes THAT.
        //
        // Which is `banner = min(itsOwnDesire, whateverIsLeft)` — exactly what UIKit's priority
        // ladder produces by putting every banner driver (`bannerNaturalAspect` 245,
        // `bannerFixedHeight` 243, `bannerImageIntrinsic` 241) below the card's `.low` 250 hugging.
        // Measured against the real `GBAlertModal` at 844x390: `banner-wide` 102.0 against UIKit's
        // 102.33, and the card lands on its cap (294.0) instead of reporting a 374.6pt ideal into a
        // 294pt slot and bleeding ~40pt past each vertical margin.
        //
        // **`.layoutPriority(-1)` is deliberately NOT here** — it was tried and is inert, to the
        // last decimal, on every probed shape in both orientations. The banner already yields
        // first without it: `Color.clear.frame(maxHeight:)` is the only child in the column with a
        // [0, h] range, and SwiftUI's `VStack` serves its stiffest children first. The evidence
        // that the ordering is right is the TITLE — under the rigid frame it was squeezed to 21.5pt
        // by `minimumScaleFactor`, and under `maxHeight` it returns to its natural 28.7 while the
        // banner absorbs the whole squeeze. Adding an inert modifier that would also put the banner
        // on the same rung as `CompressibleVerticalPadding`'s strips (which ARE at -1) is a change
        // with no measurement behind it.
        //
        // **What this does NOT fix, and what is gated because of it.** `ModalTokens.bannerGeometry`
        // is still a PORTRAIT rule for the COLUMN (see its doc). UIKit's height-constrained
        // residual arbitration also shrinks the banner's WIDTH demand, through the required
        // `ivBanner.width == ivBanner.height * ratio` tie: measured in landscape, `ivBanner` is
        // 172pt wide inside a 256pt `vwBanner`, so the image never asks for more than
        // `contentMaxWidth` and UIKit's column does not grow at all there.
        //
        // The rule for that IS known — `column = clamp(max(contentMaxWidth, resolvedHeight * ratio))`,
        // measured to 0.17pt over 264 configurations — and it is unreachable HERE for an ordering
        // reason rather than an arithmetic one: `resolvedHeight` is the number the frame below
        // yields to, produced bottom-up during layout, while the column is proposed top-down by
        // `AlertModalScaffold` on `card`, this view's ANCESTOR. The full argument, and the two
        // measurements that close off the escapes, are in `ModalTokens.bannerGeometry`'s doc.
        //
        // `banner-wide` is gated in landscape on every ORIGIN and every HEIGHT
        // (`test_geometry_landscape_bannerWide_agreesOnEveryOriginAndHeight`), with the width
        // exclusion's mechanism pinned separately; `banner-comparable` is gated there in full.
        Color.clear
            .frame(width: bannerGeometry.column)
            .frame(maxHeight: bannerGeometry.height)
            .overlay {
                // `Image(_:bundle:)` with a nil bundle IS `Image(_:)`, so the default path is
                // unchanged — this only adds the ability to name a non-main bundle.
                Image(image.assetName, bundle: image.bundle)
                    .resizable()
                    .scaledToFit()   // preserve the artwork's aspect (no distortion)
            }
            // NO `.clipped()`, and its removal is deliberate rather than an oversight. It was inert
            // TWICE OVER: an `.overlay` is proposed its host's size and `scaledToFit` only ever
            // shrinks inside that, so the picture cannot leave the slot at any resolved height; and
            // UIKit's `vwBanner` — the view this slot IS — never sets `clipsToBounds` either. The
            // only view that clips on either backend is the CARD (`vwContainer.clipsToBounds = true`
            // in `GBAlertModal+Model.swift`, `clipShape` in `AlertModalScaffold.card`), and it still
            // does. Keeping a no-op here would have read as a mirror of a UIKit property that does
            // not exist.
            //
            // Probed on the SLOT, the counterpart of UIKit's `vwBanner` — not of the picture
            // inside it, and not of `vwBannerAndBelowDivider`.
            .modalGeometryProbe(.banner)
            // Paired with the slot, so an unmeasured slot carries no gap either: a `.zero`
            // geometry must occupy no vertical space at all, exactly as UIKit's `vwBanner`
            // collapses rather than leaving a 12pt hole under nothing.
            .padding(.bottom, bannerGeometry.height > 0 ? tokens.gapBelowBanner : 0)
    }
}

/// **UIKit's `svSubtitleContainer`, in SwiftUI — the slot that yields where a `Text` cannot.**
///
/// This is finding D-7, closed. UIKit gives the subtitle its own `UIScrollView`, whose height is tied
/// to its content at `ModalLayout.Priority.subtitleSlotHeight` (`.defaultLow`, 250) and floored at
/// `subtitleSlotFloor` (850). So the slot resolves to
/// **`clamp(whatever the card can spare, floor, contentHeight)`** — measured on `banner-comparable` at
/// 844x390, a 19.0pt viewport over a 38.33pt label, i.e. UIKit clips half its own ordinary one-line
/// subtitle purely because landscape puts the card against its ceiling.
///
/// A bare `Text` cannot express that range and no modifier on it can. `.frame(minHeight:maxHeight:)`
/// around a `Text` is RIGID at the text's own height, because a flexible frame reports
/// `clamp(childHeight, min, max)` and `Text` answers every height proposal with the height its glyphs
/// need: with `maxHeight` set to the ideal, the clamp is the identity and the row refuses to yield.
/// That is exactly what the differential gate measured — SwiftUI kept the full 38.3 and the banner
/// below it paid the 19.33 UIKit had taken out of the subtitle.
///
/// The fix is the mirror of `BannerSlot`'s: put a view with a genuinely FLEXIBLE height under the
/// frame. A `ScrollView` reports `[0, ∞)`, so `.frame(minHeight: floor, maxHeight: contentHeight)`
/// turns it into `[floor, contentHeight]` — the same interval Auto Layout arbitrates over, arrived at
/// rather than computed. And it is a real scroll, so the clipped remainder stays reachable, which is
/// what `svSubtitleContainer` does too.
///
/// ## Why it is inert when the content fits
///
/// `maxHeight` resolves to `min(ideal, offered)`. Every card with room offers at least the ideal, so
/// the slot is exactly its content's height — the same frame the bare `Text` had. Measured: every
/// portrait frame in `DifferentialGeometryTests` is unchanged to the last recorded decimal.
///
/// ## Unconditional, and that is the point
///
/// There is no flag on it, and there is no longer one to read. UIKit builds `svSubtitleContainer` for
/// every subtitle it draws and compresses it whenever the card is short, so a SwiftUI counterpart
/// gated on anything would diverge on every ungated pressured shape — which is every banner shape in
/// landscape. `Properties.contentScrollable` used to gate a SEPARATE outer scroll around title and
/// subtitle together; it is deleted, because this slot already delivers the scrolling subtitle it was
/// asked for and UIKit never had a counterpart for the outer wrapper.
///
/// The floor lives here rather than on the `Text` (where it used to be, as `.frame(minHeight:)`)
/// because the floor UIKit installs is a `>=` on the CONTAINER, not on the label. On the `Text` it was
/// inert by construction — a non-empty label is already at least one line tall.
private struct SubtitleSlot<Content: View>: View {
    /// `ModalTokens.subtitleFloorHeight` — one line, the same number UIKit's `>=` carries.
    let floor: CGFloat
    /// `ContentProperty.childShouldMatchParent`. A `ScrollView` is greedy ACROSS its scroll axis as
    /// well as along it, so a hugging row needs its width clamped back to its content's; a filling
    /// row wants exactly the greed it already has.
    let fillsWidth: Bool
    @ViewBuilder let content: () -> Content

    /// The content's ideal size, measured from inside the scroll — where the height proposal is
    /// unbounded and the content therefore reports what it WANTS. `nil` until the first measurement
    /// lands, which is the one pass where the scroll is greedy; the preference is delivered in the
    /// same layout cycle, so the settled layout is the capped one.
    @State private var ideal: CGSize?

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            content()
                // A BACKGROUND reader, not a wrapping `GeometryReader`: a wrapping one would impose
                // its own sizing on the very thing being measured.
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: SubtitleIdealSizeKey.self, value: proxy.size)
                    }
                )
        }
        .frame(maxWidth: fillsWidth ? .infinity : ideal?.width)
        .frame(minHeight: floor, maxHeight: ideal?.height)
        .onPreferenceChange(SubtitleIdealSizeKey.self) { size in
            // Guarded: an unconditional write re-renders with the same value on every pass, which is
            // a layout loop rather than a settled layout.
            if size.height > 0, ideal != size {
                ideal = size
            }
        }
    }
}

/// The subtitle content's ideal size, published from inside `SubtitleSlot`'s scroll.
private struct SubtitleIdealSizeKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(
            width: Swift.max(value.width, next.width), height: Swift.max(value.height, next.height)
        )
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

/// **Wrap freely; shrink as a last resort; never truncate — the SwiftUI half of the ladder.**
///
/// The owner directive is "title and subtitle should no truncated, title with more content compression
/// (title will still live while subtitle begin to wrap)", and it resolves to three rungs on BOTH
/// renderers. Here they are two modifiers plus the caller's `layoutPriority`:
///
/// * `lineLimit(nil)` — no cap on the line count, the counterpart of UIKit's `numberOfLines = 0`. This
///   row previously carried `lineLimit(1)` plus a hidden ruler/overlay (`ShrinkToFitSingleLine`, now
///   deleted) that reproduced UIKit's OLD shrink-onto-one-line-then-ellipsize ladder faithfully. Both
///   sides wrap now.
/// * `minimumScaleFactor(floor)` — rung 2. It engages only when the proposed space is too small for
///   the text AS WRAPPED, which is exactly "after wrapping, and after the lower-priority row has
///   yielded": with unlimited lines and a width already fixed by `ContentRowWidth`, there is nothing
///   for a scale factor to do until the HEIGHT runs short. Below the floor SwiftUI would truncate, and
///   that is the same cliff UIKit has at `ModalLayout.titleMinimumScaleFactor`; the floor is chosen
///   (see that constant) so real content reaches it with room to spare.
///
/// **`fixedSize(vertical:)` was here and is deliberately GONE.** It made the row report its ideal
/// height whatever was proposed, which did guarantee no truncation — by never yielding at all, so the
/// card overflowed and `minimumScaleFactor` could never engage. Rungs 1 and 2 both need the rows to be
/// squeezable; with `fixedSize` neither the subtitle could yield nor the title could shrink.
///
/// **What replaces it on the TITLE is a floor, not a fixed size** (`.frame(minHeight:)` at the call
/// site, from `ModalTokens.titleFloorHeight(for:)`). `minimumScaleFactor` alone was not enough and the
/// gate proved it: it caps how small the glyphs are DRAWN, but the row was still proposed 64.7pt where
/// the floor-scaled text needed 85.9pt, and a `Text` in a too-small frame clips. A floor bounds the
/// yielding at exactly the point the scale factor stops helping, while leaving every point ABOVE it
/// yieldable — so rungs 1 and 2 keep working and rung 3 stays "never".
///
/// The SUBTITLE's floor is not here but on its SLOT (`SubtitleSlot`, via `minHeight`), which is where
/// UIKit puts it too — a `>=` on `svSubtitleContainer`, not on `lbSubtitle`. It is rung 1's yielder, so
/// what bounds it has to be the thing that yields.
///
/// Applied to the subtitle as well as the title. The two are ordered by `layoutPriority`, not by
/// capability: the subtitle is squeezed FIRST and answers by shrinking rather than ellipsizing. This
/// used to be described as "the closest SwiftUI can come to UIKit's scrolling subtitle slot", with the
/// slot itself listed as the unclosable structural gap D-7. **That is out of date: the slot exists**
/// (`SubtitleSlot`) and it clips-and-scrolls the way `svSubtitleContainer` does, so scaling is now the
/// rung ABOVE clipping rather than a substitute for it.
private struct NeverTruncates: ViewModifier {
    let minimumScaleFactor: CGFloat

    func body(content: Content) -> some View {
        content
            .lineLimit(nil)
            .minimumScaleFactor(minimumScaleFactor)
    }
}

extension SwiftUIAlertModal {
    /// **The SwiftUI analogue of UIKit's vertical compression-resistance ordering.**
    ///
    /// `ModalLayout.Priority` puts the title (900) above the subtitle label (750) and far above the
    /// subtitle SLOT's height tie (`.defaultLow`, 250). SwiftUI's `layoutPriority` is a `Double` on an
    /// unrelated scale, so only the ORDER carries over — which is all the directive states. Two
    /// named constants rather than bare literals in the body, so the ordering is one visible fact
    /// that a reader (and `TitleSubtitleTruncationTests`) can check instead of two magic numbers.
    static var titleLayoutPriority: Double { 1 }
    /// **Below SwiftUI's DEFAULT, which is what puts it below the BANNER too — and that is measured,
    /// not stylistic.**
    ///
    /// It was `0` (the default) while the only ordering that mattered was title-over-subtitle. It has
    /// to be negative now, because with `SubtitleSlot` the subtitle is finally able to yield and the
    /// question becomes WHO yields first — and the answer has to be UIKit's answer.
    ///
    /// UIKit's, measured on `banner-comparable` across a 120pt sweep of host heights: **the subtitle
    /// slot yields all the way to its floor before the banner gives up a single point.** At 844x430
    /// the banner is still 160.0 and the viewport is already 19.33 of a 38.33pt label; only from
    /// 844x415 down does the banner start to move, and from there the subtitle sits on its floor and
    /// the banner absorbs every further point.
    ///
    /// That order looks backwards against `ModalLayout.Priority` — the banner's drivers are 245/243/241,
    /// BELOW the subtitle slot's `.defaultLow` (250), and `TitleSubtitleTruncationTests` asserts
    /// exactly that. It is not backwards: those three set the banner's height, but what DEFENDS the
    /// banner's height under pressure is `ivBanner`'s WIDTH compression resistance (750) reaching the
    /// height through the required `width == height * ratio` tie. So the effective ladder is subtitle
    /// slot (250) → banner (750) → subtitle floor (850), and the subtitle really does go first.
    ///
    /// SwiftUI expresses that as a group ordering: the VStack serves higher `layoutPriority` first
    /// and hands the lowest whatever is left, while still reserving every child's MINIMUM — so the
    /// subtitle takes `clamp(residual, floor, contentHeight)` and the banner's greedy
    /// `.frame(maxHeight:)` takes the rest. Measured against UIKit at every 10pt step from 844x450 to
    /// 844x330: identical to within 0.09pt on every row.
    ///
    /// Only the ORDER carries over; the magnitude is on an unrelated scale to UIKit's 0…1000.
    static var subtitleLayoutPriority: Double { -1 }
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
