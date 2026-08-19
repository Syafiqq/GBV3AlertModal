import GBV3AlertModalCore

import Foundation
import SwiftUI

/// Pure-SwiftUI mirror of `GBAlertModal`'s content: `AlertModalScaffold` (shared chrome) with a
/// built-in standard body (banner/title/subtitle). Holds NO hand-rolled slot logic — it runs the
/// SAME `GBAlertModal.resolve` resolver `GBAlertModal` (UIKit) itself runs, over `ModalContent.make`'s
/// mapping (spec C-1; UIKit-typed until Pass 5 step 6, now the SwiftUI-native mirror of
/// `UIKitModalRenderer.AlertHolder.make` — same decisions, no `DataHolder`). Never dismisses itself;
/// the caller reacts to `onAction` (matches the executor teardown contract). Styling is fixed design
/// (`ModalTokens`).
///
/// **Equivalence scope**: `properties` is the resolver's other input, and `SwiftUIModalRenderer`
/// supplies the real caller-provided standard properties for every presentation it
/// hosts (via `ModalHost`) — the same values the UIKit renderer feeds `resolve`. So on the rendered
/// path all TEN properties-and-holder-derived resolver fields now agree with UIKit by construction:
/// `showsBanner`, `showsTitle`, `subtitle`, `showsCloseButton`, `closeOnTapOverlay`,
/// `dismissOnAction`, `showsPrimary`, `showsSecondary`, `buttonAxis` and `buttonsMatchParent`.
///
/// One caveat remains, narrow and deliberate:
/// * `isLandscape` is still fixed to `false` here, so `contentWidth` (the one orientation-sensitive
///   field) can still differ from a UIKit render in landscape. The card is width-adaptive
///   (`ModalTokens.cardMaxWidth` is a CAP, not a fixed width) — but the PORTRAIT reading of
///   `contentWidth` now does reach the layout, as `ModalTokens.contentMaxWidth` on the content
///   container (see `AlertModalScaffold.card`).
///
/// `showsPrimary` used to be the second caveat — resolved correctly and not obeyed, because
/// `AlertModalScaffold.primaryTitle` was a non-optional `String`. It is optional as of Pass 2, and
/// `card` passes `resolved.showsPrimary ? config.primary : nil`, so all ELEVEN resolver fields are
/// now both resolved and obeyed.
///
/// A caller that omits `properties` (SwiftUI-only demos, previews, tests) still gets the fixed
/// sentinel described on `resolved(from:)` — for those there is no `Properties` in play at all,
/// so there is nothing to diverge from.
@MainActor
public struct SwiftUIAlertModal: View {
    public let config: AlertDialog
    /// **The configuration the resolver reads, in EITHER vocabulary.**
    ///
    /// Was `GBAlertModal.Properties?`, which made a caller name a UIKit type to drive this view.
    /// It is `ModalStructureInputs` now — the five structural fields `GBAlertModal.resolve`
    /// actually reads — so `GBAlertModal.Properties` and `ModalProperties` both satisfy it and a
    /// SwiftUI-native caller can pass `ModalProperties` here with `ModalTokens(from:)` beside it.
    ///
    /// One resolver still, not two: see `ModalStructureInputs`. `nil` falls back to
    /// `sentinelProperties`.
    public let properties: ModalProperties
    /// Presentation state — NOT part of `AlertDialog`. The caller owns this; the view only reads it.
    public var primaryEnabled: Bool = true
    public var secondaryEnabled: Bool = true
    public var isPrimaryLoading: Bool = false
    public let tokens: ModalTokens
    public let onAction: (AlertDialog.Result) -> Void

    public init(
        config: AlertDialog,
        properties: ModalProperties? = nil,
        primaryEnabled: Bool = true,
        secondaryEnabled: Bool = true,
        isPrimaryLoading: Bool = false,
        tokens: ModalTokens = .standard,
        onAction: @escaping (AlertDialog.Result) -> Void
    ) {
        self.config = config
        self.properties = properties ?? Self.sentinelProperties
        self.primaryEnabled = primaryEnabled
        self.secondaryEnabled = secondaryEnabled
        self.isPrimaryLoading = isPrimaryLoading
        self.tokens = tokens
        self.onAction = onAction
    }

    // MARK: - Slot resolution (spec C-1)
    //
    // `modalContent` is `ModalContent.make(for:)` — the SwiftUI-native mirror of
    // `UIKitModalRenderer.AlertHolder.make`'s mapping (Pass 5 step 6); `resolved(from:)` is the
    // library's own 11-field `GBAlertModal.resolve`, run over it. Neither is duplicated here.
    private var modalContent: ModalContent {
        ModalContent.make(for: config)
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
    private static var sentinelProperties: ModalProperties {
        ModalProperties(
            buttonActionShouldMatchParent: true,
            primaryActionStyle: .plain(.init()),
            secondaryActionStyle: .plain(.init())
        )
    }

    /// Takes `content` as a parameter (rather than reaching for `self.modalContent` again) so `body`
    /// can compute it exactly once per render.
    private func resolved(from content: ModalContent, isLandscape: Bool) -> ResolvedModal {
        resolveModal(
            inputs: properties,
            content: content,
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
        // Computed exactly once per render so text splitting and resolution are not repeated.
        let content = self.modalContent
        let resolved = self.resolved(from: content, isLandscape: isLandscape)
        // Banner existence is a content decision; SwiftUI resolves and lays out the Image itself.
        let drawsBanner = resolved.showsBanner
        // Every row's TRAILING gap is conditional on something existing below it, because UIKit's
        // are: `buildDividers` creates `vwBannerAndBelowDivider` / `vwTitleAndBelowDivider` /
        // `vwSubtitleAndBelowDivider` only when a later component was actually built. That was
        // invisible while `primary` was a non-optional String — the main-action container then
        // ALWAYS existed, so every "is anything below me" test was trivially true and an
        // unconditional `.padding(.bottom, …)` matched. Making the button run absentable is what
        // makes the condition observable, so it is spelled out here.
        let payload = Self.subtitlePayload(resolved: resolved, config: config)
        let hasButtons = resolved.showsPrimary || resolved.showsSecondary
        let hasSubtitle = payload.rendersARow
        let hasTitle = resolved.showsTitle && config.title != nil
        return AlertModalScaffold(
            tokens: tokens,
            // `showsPrimary` is now OBEYED, not merely resolved — the divergence recorded in this
            // type's own doc comment and in `DivergenceCatalog.showsPrimaryNotObeyed`. The resolver
            // requires BOTH a primary action string AND a `primaryActionStyle`, so a `Properties`
            // with a nil style hides the primary on the UIKit path; it now hides it here too.
            primaryTitle: resolved.showsPrimary ? config.primary : nil,
            isPrimaryLoading: isPrimaryLoading,
            // BOTH sources, and disabled wins. `primaryEnabled` is this view's own property, owned
            // by a caller constructing `SwiftUIAlertModal` directly (`SatisfactionDemoView`);
            // `config.primaryEnabled` is the descriptor field the EXECUTOR path sets, changed
            // mid-presentation through `update(_:to:)`. Neither is redundant — they are two
            // different callers — and `&&` is the only combination where a caller who disables a
            // button cannot have it re-enabled by the other one's default.
            primaryEnabled: primaryEnabled && config.primaryEnabled,
            onPrimary: { onAction(.primary) },
            secondaryTitle: resolved.showsSecondary ? config.secondary : nil,
            secondaryEnabled: secondaryEnabled && config.secondaryEnabled,
            onSecondary: { onAction(.secondary) },
            showClose: resolved.showsCloseButton,
            onClose: { onAction(.dismissed) },
            // `resolved.closeOnTapOverlay` mirrors `content.closeOnTapOverlay` / `config.closeOnTapOverlay`
            // — reading it off the resolver keeps this decision flowing through the shared chain too.
            onOverlayTap: { if resolved.closeOnTapOverlay { onAction(.dismissed) } },
            // Map the Core resolver's neutral axis at the SwiftUI rendering edge.
            buttonAxis: resolved.buttonAxis.swiftUIAxis,
            // `Properties.buttonActionShouldMatchParent`, via the shared resolver — the same field
            // UIKit turns into `svMainActionContainer.alignment`. Resolved AND obeyed now; it used to
            // be resolved and dropped (task 17, finding D-4).
            buttonsMatchParent: resolved.buttonsMatchParent,
            hasBanner: drawsBanner
        ) {
            if drawsBanner, let image = config.image {
                BannerSlot(
                    image: image,
                    tokens: tokens,
                    hasContentBelow: hasTitle || hasSubtitle || hasButtons
                )
                // Artwork is decorative and yields before descriptive text or actions.
                .layoutPriority(-1)
                ModalMeasuredScrollView {
                    titleAndSubtitle(
                        resolved: resolved,
                        payload: payload,
                        hasSubtitle: hasSubtitle,
                        hasButtons: hasButtons
                    )
                }
                .layoutPriority(1)
            } else {
                titleAndSubtitle(
                    resolved: resolved,
                    payload: payload,
                    hasSubtitle: hasSubtitle,
                    hasButtons: hasButtons
                )
            }
        }
    }

    /// The two text rows, in the order and with the priorities the directive states.
    ///
    /// `hasSubtitle`/`hasButtons` are what UIKit's `buildDividers` consults: a row's trailing gap
    /// exists only when a later row does. Both are computed by the caller so the whole card agrees
    /// on one answer.
    @ViewBuilder
    private func titleAndSubtitle(
        resolved: ResolvedModal,
        payload: SubtitlePayload,
        hasSubtitle: Bool,
        hasButtons: Bool
    ) -> some View {
            if resolved.showsTitle, let title = config.title {
                Text(title)
                    .font(tokens.titleFont.font)
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
                    // The STYLED title, not `String(title.characters)`. `Text(title)` draws each run's
                    // own font where it has one — `.font(tokens.titleFont.font)` above is only the ambient
                    // default — so flattening to characters measured a font the view may not draw and
                    // produced a floor too short for the text it was protecting.
                    .modalGeometryProbe(.title)
                    // UIKit's `vwTitleAndBelowDivider`, which `buildDividers` creates only when
                    // `svSubtitleContainer != nil || svMainActionContainer != nil`.
                    .padding(.bottom, hasSubtitle || hasButtons ? tokens.gapBelowTitle : 0)
                    // OUTERMOST, and it has to be: `layoutPriority` is read by the enclosing
                    // container (`AlertModalScaffold`'s VStack) off the view it actually holds, so a
                    // `.padding` applied after it would be the view the VStack sees. This is the
                    // SwiftUI analogue of UIKit's vertical compression resistance, and the ORDERING
                    // is the directive: the title (1) out-ranks the subtitle (0), so when these rows
                    // are laid out without their shared scroll group, the subtitle gives way first.
                    // Magnitudes are not comparable to UIKit's 0…1000 scale — only the order is.
                    .layoutPriority(Self.titleLayoutPriority)
            }
            subtitleView(payload: payload, hasButtons: hasButtons)
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
    private func subtitleView(payload: SubtitlePayload, hasButtons: Bool) -> some View {
        switch payload {
        case .none:
            EmptyView()
        case let .plain(subtitle):
            SubtitleSlot(fillsWidth: tokens.contentChildrenFillWidth) {
                // Renderer-specific adaptation has already happened at the migration boundary.
                Text(subtitle)
                    .font(tokens.subtitleFont.font)
                    .foregroundColor(tokens.palette.subtitleText)
                    .multilineTextAlignment(.center)
                    .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))
                    // Same guarantee as the title, one rung lower: `layoutPriority` (below) makes
                    // this the row that is squeezed FIRST, and the scale factor means it answers by
                    // shrinking rather than by ellipsizing.
                    .modifier(NeverTruncates(minimumScaleFactor: tokens.titleMinimumScaleFactor))
            }
            .modalGeometryProbe(.subtitle)
            // UIKit's `vwSubtitleAndBelowDivider`: `svMainActionContainer != nil` is its only
            // condition, the subtitle being the last content row.
            .padding(.bottom, hasButtons ? tokens.gapBelowSubtitle : 0)
            // The lower rung of the title/subtitle ordering — see `subtitleLayoutPriority`.
            .layoutPriority(Self.subtitleLayoutPriority)
        case let .attributed(attributed):
            SubtitleSlot(fillsWidth: tokens.contentChildrenFillWidth) {
                // `.font`/`.foregroundColor` here are AMBIENT, same as the `.plain` case above —
                // they are what a run WITHOUT an explicit attribute falls back to. Their absence was
                // a real gap: a caller styling only PART of a subtitle (e.g. one bold word, the rest
                // untouched — `GenieShapeCatalog.badgeUnlockSubtitle`'s exact shape) got the untouched
                // runs rendered in SwiftUI's system default rather than `tokens.subtitleFont`/
                // `.subtitleText`, matching UIKit's OWN equivalent gap (`ModalLayout.renderedFont`'s
                // doc: `lbSubtitle.font` is never assigned, so an unstyled UIKit run falls back to the
                // 17pt system default too) rather than fixing it — this closes the SwiftUI side.
                // Explicit run styling still wins over this ambient default.
                Text(attributed)
                    .font(tokens.subtitleFont.font)
                    .foregroundColor(tokens.palette.subtitleText)
                    .multilineTextAlignment(.center)
                    .modifier(ContentRowWidth(fillsWidth: tokens.contentChildrenFillWidth))
                    .modifier(NeverTruncates(minimumScaleFactor: tokens.titleMinimumScaleFactor))
            }
            .modalGeometryProbe(.subtitle)
            // UIKit's `vwSubtitleAndBelowDivider`: `svMainActionContainer != nil` is its only
            // condition, the subtitle being the last content row.
            .padding(.bottom, hasButtons ? tokens.gapBelowSubtitle : 0)
            .layoutPriority(Self.subtitleLayoutPriority)
        case .custom:
            // A plain `AlertDialog` never populates `subtitleCustomView` (that field doesn't exist
            // on this descriptor), so this case is unreachable from `SwiftUIAlertModal` in practice.
            // Bespoke content is served by `AlertModalScaffold`'s `ViewBuilder` slot instead.
            EmptyView()
        }
    }
}

/// Banner artwork that flows within the proposed content width using its intrinsic aspect ratio.
private struct BannerSlot: View {
    let image: ModalImage
    let tokens: ModalTokens
    /// A banner with nothing below it needs no trailing gap.
    let hasContentBelow: Bool
    var body: some View {
        Image(image.assetName, bundle: image.bundle)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: tokens.bannerMaxHeight)
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
            .padding(.bottom, hasContentBelow ? tokens.gapBelowBanner : 0)
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
/// The fix is the mirror of `BannerSlot`'s: put a view with a genuinely flexible height under the
/// frame. Native layout proposes the available height, capped by the measured ideal, and the real
/// scroll keeps any clipped remainder reachable.
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
private struct SubtitleSlot<Content: View>: View {
    /// `ContentProperty.childShouldMatchParent`. A `ScrollView` is greedy ACROSS its scroll axis as
    /// well as along it, so a hugging row needs its width clamped back to its content's; a filling
    /// row wants exactly the greed it already has.
    let fillsWidth: Bool
    @ViewBuilder let content: () -> Content
    @Environment(\.modalUsesExternalContentScroll) private var usesExternalScroll

    /// The content's ideal size, measured from inside the scroll — where the height proposal is
    /// unbounded and the content therefore reports what it WANTS. `nil` until the first measurement
    /// lands, which is the one pass where the scroll is greedy; the preference is delivered in the
    /// same layout cycle, so the settled layout is the capped one.
    @State private var ideal: CGSize?

    @ViewBuilder
    var body: some View {
        if usesExternalScroll {
            content()
                .frame(maxWidth: fillsWidth ? .infinity : nil)
        } else {
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
            .frame(maxHeight: ideal?.height)
            .onPreferenceChange(SubtitleIdealSizeKey.self) { size in
                // Guarded: an unconditional write re-renders with the same value on every pass, which is
                // a layout loop rather than a settled layout.
                if size.height > 0, ideal != size {
                    ideal = size
                }
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
    /// `ModalLayout.Priority` puts the title (900) above the subtitle label (750). SwiftUI's
    /// `layoutPriority` is a `Double` on an unrelated scale, so only the order carries over. Banner
    /// dialogs protect both rows as one scrollable group; these constants still describe their
    /// internal ordering when that external group is absent.
    static var titleLayoutPriority: Double { 1 }
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
        case attributed(AttributedString)
        case custom

        /// Whether this payload puts an actual ROW in the card — the counterpart of UIKit's
        /// `svSubtitleContainer != nil`, which `buildDividers` reads to decide whether the row
        /// ABOVE gets a trailing gap.
        ///
        /// `.custom` is `false` because `subtitleView` renders `EmptyView()` for it: a plain
        /// `AlertDialog` has no `subtitleCustomView` field, so the case is unreachable from this
        /// view and reporting a row that never draws would put a phantom gap under the title.
        var rendersARow: Bool {
            switch self {
            case .none, .custom: return false
            case .plain, .attributed: return true
            }
        }
    }

    /// The subtitle DECISION + PAYLOAD SELECTION, pulled out of the view body so it's a plain,
    /// synchronous function a test can call directly (no `View` construction, no hosting).
    ///
    /// `resolved.subtitle` (`ResolvedModal.SubtitleKind`) decides ONLY none/plain/attributed/
    /// custom — it never supplies the payload this function returns for `.plain`. That split
    /// matters: both text cases return the descriptor's Core `AttributedString` directly so the
    /// view never reconstructs or reinterprets renderer-specific attribute scopes.
    static func subtitlePayload(
        resolved: ResolvedModal,
        config: AlertDialog
    ) -> SubtitlePayload {
        switch resolved.subtitle {
        case .none:
            return .none
        case .plain:
            guard let subtitle = config.subtitle else { return .none }
            return .plain(subtitle)
        case .attributed:
            guard let subtitle = config.subtitle else { return .none }
            return .attributed(subtitle)
        case .custom:
            return .custom
        }
    }

}
