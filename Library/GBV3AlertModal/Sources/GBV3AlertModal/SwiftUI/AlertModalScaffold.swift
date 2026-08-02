import SwiftUI
import UIKit // for `NSLayoutConstraint.Axis` — the vocabulary `ResolvedModal.buttonAxis` speaks.

/// How the banner row — which lives inside the caller's `content` closure — learns the geometry the
/// scaffold computed from its `GeometryReader`. An environment value rather than a `PreferenceKey`
/// on purpose: preferences flow UP from content, which is the measurement cycle the brief's §7
/// warns about. This flows DOWN from the container.
private struct ModalBannerGeometryKey: EnvironmentKey {
    static let defaultValue = ModalTokens.BannerGeometry.zero
}

extension EnvironmentValues {
    var modalBannerGeometry: ModalTokens.BannerGeometry {
        get { self[ModalBannerGeometryKey.self] }
        set { self[ModalBannerGeometryKey.self] = newValue }
    }
}

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
    /// `GBAlertModal.ResolvedModal.buttonsMatchParent` verbatim — `Properties`'
    /// `buttonActionShouldMatchParent`, which UIKit applies as
    /// `svMainActionContainer.alignment = .fill` vs `.center` (`GBAlertModal+Style.swift`).
    ///
    /// It decides whether the PRIMARY button spans the content width or hugs its own label, because
    /// `configureButtonActionConstraint`'s `.obliqueBottomLeft` branch pins the button to all four
    /// edges of its slot — so the slot's alignment is the button's width. The SECONDARY button is
    /// unaffected on purpose: the `.plain` branch constrains it `leading >= superview.leading` +
    /// `center == superview.center`, so it hugs its label whatever its slot does.
    ///
    /// Defaults to `true`, which is what every real Genie preset sets and what this scaffold did
    /// unconditionally before the flag was threaded (task 17, finding D-4).
    public var buttonsMatchParent: Bool = true
    /// The banner artwork's point size, or `.zero` when this modal has no banner. Drives
    /// `ModalTokens.bannerGeometry`, which the banner row reads back out of the environment.
    public let bannerArtworkSize: CGSize
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
        buttonsMatchParent: Bool = true,
        bannerArtworkSize: CGSize = .zero,
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
        self.buttonsMatchParent = buttonsMatchParent
        self.bannerArtworkSize = bannerArtworkSize
        self.content = content
    }

    public var body: some View {
        // **The card is BOUNDED by the space it has.**
        //
        // UIKit's counterpart is `adjustVwContainerConstraint`: `top >= safeArea + margin` and
        // `bottom <= safeArea − margin`, both `.required`, so an over-tall card compresses its
        // content rather than growing off-screen. SwiftUI had no equivalent — the card simply took
        // its content's height and the excess was cut by `clipShape`, which is what an over-stuffed
        // landscape card was observed doing on device.
        //
        // The reader is the container's own size, so nothing the card contains can influence it.
        GeometryReader { proxy in
            let bannerGeometry = tokens.bannerGeometry(
                imageSize: bannerArtworkSize,
                availableCardWidth: max(0, proxy.size.width - tokens.cardMarginH * 2)
            )
            ZStack {
                scrim
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onOverlayTap?() }

                // The geometry is passed as a PARAMETER as well as published to the environment, and
                // the two are not redundant: `card` needs it for its own frames, and a view cannot
                // read an environment value it publishes on its own descendant. The `.environment`
                // injection stays for `BannerSlot`, which is built inside the caller's `content`
                // closure and so is a genuine descendant.
                card(bannerGeometry: bannerGeometry)
                    .environment(\.modalBannerGeometry, bannerGeometry)
                // The CARD's cap — `contentMaxWidth + leftMax + rightMax`, i.e. the width UIKit's
                // `vwContainer` ends up with, NOT the width `ContentProperty` states (that one caps
                // the content container inside `card`). Feeding the content width in here is the
                // 64pt-narrow-card defect D-1; see `ModalTokens.cardMaxWidth`.
                //
                // …or the banner's column plus that same max padding, when wide artwork has widened
                // the column. UIKit's `vwContainer` has NO width constraint at all, only the margin
                // inequalities, so it takes whatever the content plus its `.low` max padding asks
                // for, bounded by the margins. Measured: a 320pt asset in a 256pt column produces a
                // 350pt card, not a 320pt one. `bannerGeometry` is `.zero` with no banner, so this
                // `max` is the identity for every shape that has none.
                //
                // **This is also what keeps `bannerGeometry`'s ceiling honest.** That ceiling is
                // derived from the HOST (`proxy.size.width − 2·cardMarginH`), not from
                // `cardMaxWidth`, so on a host wider than `cardMaxWidth + 2·cardMarginH` it names
                // more room than a card pinned at `cardMaxWidth` could hand over — and `BannerSlot`'s
                // frame is RIGID, so a column wider than its container clips rather than compresses.
                // Growing the card by the SAME `column` closes that: the card ends up
                // `min(host − 2·cardMarginH, max(cardMaxWidth, column + leftMax + rightMax))`, so
                // either the host clamps it — and then `column ≤ host − 2·cardMarginH − leftMin −
                // rightMin` by the ceiling itself — or it does not, and the card is at least
                // `column + leftMax + rightMax ≥ column + leftMin + rightMin`. The slot fits either
                // way, and `test_bannerWide_theSlotNeverOverflowsTheCard_atAnyHostWidth` asserts the
                // consequence at three host widths rather than trusting the algebra.
                .frame(maxWidth: max(
                    tokens.cardMaxWidth,
                    bannerGeometry.column
                        + tokens.contentPadding.leftMax + tokens.contentPadding.rightMax
                ))   // fills to margin, capped (not fixed width)
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
                        // 48, from `tokens.closeButtonSize` — UIKit's `size == 48` on
                        // `btCloseAction`. This was 44 (the HIG minimum), which put the glyph 2pt
                        // further from both card edges than the shipping modal does (D-5).
                        .frame(width: tokens.closeButtonSize, height: tokens.closeButtonSize)
                        .contentShape(Rectangle())
                        .modalGeometryProbe(.closeButton)
                    }
                }
                    // The cap, applied BEFORE the margin padding so the two compose the way UIKit's
                    // inequality pair does: the card may occupy the container minus its margins and
                    // not one point more.
                    .frame(maxHeight: max(0, proxy.size.height - tokens.cardMarginV * 2))
                    .padding(.vertical, tokens.cardMarginV)     // card→screen margin: 40 v / 20 h
                    .padding(.horizontal, tokens.cardMarginH)
            }
            // `GeometryReader` aligns its content top-leading; the modal is centred, so the ZStack is
            // given the reader's full size back rather than being left in the corner.
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    /// **The card, and the three LEVELS the preset's width and padding are applied at.**
    ///
    /// This mirrors `GBAlertModal+Layout.swift`'s `adjustSvContentContainerConstraint`, which is a
    /// PRIORITY LADDER, not a set of fixed insets. UIKit installs, on `svContentContainer` inside
    /// `vwContainer`:
    ///
    /// * `leading >= superview + leftMin` and `trailing <= superview − rightMin` at **`.required`**;
    /// * `leading == superview + leftMax` and `trailing == superview − rightMax` at **`.low`**;
    /// * `width == fixedWidth` at `.medium` / `width <= maxWidth` at `.high`;
    /// * `center == superview` at `.low`.
    ///
    /// `vwContainer` itself has NO width constraint — only `leading >= safeArea + margin` /
    /// `trailing <= safeArea − margin` — so the card's width is whatever satisfying that ladder
    /// produces: `content + leftMax + rightMax` when it fits, and when it does not, the `.low`
    /// padding equalities give way (down to the `.required` minima) while the content keeps its
    /// stated width. The real `streakProperties` is the second case on a 390pt phone: it asks for
    /// 256 + 48 + 48 = 352 with only 350 available, so UIKit sheds ~1pt per side and the content
    /// stays 256 wide.
    ///
    /// The three modifiers below are that ladder, in order, and they reproduce both cases exactly:
    ///
    /// 1. `.frame(maxWidth: .infinity).frame(maxWidth: max(contentMaxWidth, bannerGeometry.column))`
    ///    — the content container takes its stated width and no more (`.medium` fixed width,
    ///    clamped by the `.high` max), EXCEPT that wide artwork widens the column past the stated
    ///    cap, which is UIKit's `ivBanner` compression resistance (750) outranking
    ///    `width == fixedWidth` at `.medium` (500). `bannerGeometry` is `.zero` with no banner, so
    ///    the `max` is the identity for every shape that has none.
    /// 2. `.padding(.leading/.trailing, leftMin/rightMin)` — the RIGID minima (`.required`).
    /// 3. `.frame(maxWidth: .infinity)` — fill whatever the card's own cap left, centring the
    ///    content in it (`.low` equalities + `.low` centring). The card is capped by the caller in
    ///    `body` at `max(cardMaxWidth, bannerGeometry.column + leftMax + rightMax)` — the same
    ///    banner term again, one level out — so this resolves to
    ///    `min(available, max(content, column) + leftMax + rightMax)` and the effective padding is
    ///    the leftover, which equals `leftMax`/`rightMax` whenever there is room and compresses
    ///    toward the minima when there is not.
    ///
    /// Step 3 also means the card FILLS its cap rather than hugging its content, which is UIKit's
    /// `width == fixedWidth` at `.medium` beating the content stack's hugging at 250. Every Genie
    /// preset sets `fixedWidth == maxWidth`; a preset that set a max WITHOUT a fixed width would hug
    /// in UIKit and fill here (recorded on `ModalTokens.init(from:)`'s audit).
    ///
    /// One further caveat, for the same reason: because step 3 CENTRES, an horizontally ASYMMETRIC
    /// max padding (`leftMax != rightMax`) would be split evenly instead of applied per side. No
    /// preset in the app is horizontally asymmetric — the asymmetry the real presets do have is
    /// vertical, and that one is honoured exactly below.
    ///
    /// **The vertical insets now COMPRESS from max toward min, as UIKit's do** — see
    /// `CompressibleVerticalPadding`. This used to be a stated limit ("applied rigidly at the max"),
    /// justified by a claim that stopped being true: that SwiftUI had no scroll container for the
    /// subtitle (it does — `ScrollableContent`, opt-in via `Properties.contentScrollable`).
    ///
    /// **The card CAN still grow off-screen, and an earlier version of this comment denied it.** It
    /// claimed the card "cannot" overflow because `body` caps it at its container's height. That
    /// cap is `.frame(maxHeight:)`, which only PROPOSES a height; `BannerSlot`'s frame is rigid
    /// (`.frame(height:)`), so a banner row reports a larger ideal than the proposal and SwiftUI
    /// centres the overflow rather than compressing it. Measured on the wide-banner shape in
    /// landscape: the card runs from ~11pt to ~375pt in a 390pt-tall host — ~364pt against a 310pt
    /// cap, i.e. it breaches the 40pt vertical card margin at both ends. This is the landscape
    /// regression §5 of the banner-height design spec covers, not a separate defect; it is not
    /// reachable in portrait, where the card is free to grow and nothing is yielding.
    ///
    /// Worth 16pt per edge on the real preset (24 against 16), and pinned by
    /// `test_theVerticalPadding_compressesTowardItsMinimum_underPressure`, which asserts the
    /// comparison rather than a literal: the same dialog roomy and pressured must not share a top
    /// inset, and the pressured one must never fall below `topMin`.
    ///
    /// **A function rather than a computed property, and `bannerGeometry` is why.** The value is
    /// computed in `body`'s `GeometryReader` and PUBLISHED to the environment on this very view, so
    /// an `@Environment(\.modalBannerGeometry)` stored property on the scaffold would resolve from
    /// the scaffold's OWN ambient environment — the one fixed before it published anything — and read
    /// `.zero` forever. Threading it as a parameter is the only way `card` can see the same number
    /// `BannerSlot` does. (Same trap, opposite side, as the one `BannerSlot`'s doc records.)
    private func card(bannerGeometry: ModalTokens.BannerGeometry) -> some View {
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
        // (1) the CONTENT cap — `ContentProperty`'s stated width, applied to the content container
        //     exactly as UIKit applies it to `svContentContainer`. TWO frames, because "fill, but
        //     never past the cap" is not expressible as one: the inner `.infinity` is UIKit's
        //     `width == fixedWidth` at `.medium` (the container takes its stated width whatever its
        //     children want, so a row that hugs does not narrow the card), the outer is the
        //     `width <= maxWidth` at `.high` that clamps it.
        .frame(maxWidth: .infinity)
        // The stated cap, or the banner's column when the artwork demands a wider one. UIKit has no
        // separate mechanism for this: `ivBanner`'s compression resistance (750) simply outranks
        // `svContentContainer`'s `width == fixedWidth` at `.medium` (500), so a wide banner widens
        // the column. `bannerGeometry` is `.zero` with no banner, so `max` is the identity for
        // every shape that has none.
        .frame(maxWidth: max(tokens.contentMaxWidth, bannerGeometry.column))
        // (2) the rigid MINIMUM horizontal padding (`.required` in UIKit).
        .padding(.leading, tokens.contentPadding.leftMin)
        .padding(.trailing, tokens.contentPadding.rightMin)
        // (3) fill the rest of the card and centre the content in it, so the effective padding is
        //     `leftMax`/`rightMax` when it fits and compresses toward the minima when it does not.
        .frame(maxWidth: .infinity)
        // Vertical insets: top and bottom INDEPENDENTLY (the real presets are asymmetric — the
        // permission alert is 20/12 and the streak popup 40/32), at their max. See the limit stated
        // in this property's doc comment for why the vertical minima are not modelled.
        // Vertical padding as a min/max PAIR, mirroring UIKit's `top >= topMin` (.required) beating
        // `top == topMax` (.low): the rigid minimum is real padding, and the difference is a
        // compressible strip that gives way when the card is against its cap.
        .padding(.top, tokens.contentPadding.topMin)
        .padding(.bottom, tokens.contentPadding.bottomMin)
        .modifier(
            CompressibleVerticalPadding(
                top: tokens.contentPadding.topMax - tokens.contentPadding.topMin,
                bottom: tokens.contentPadding.bottomMax - tokens.contentPadding.bottomMin
            )
        )
        .background(tokens.palette.cardBackground)
        // Radius read off `tokens.cardVisual` — the value the C-3b layer-visual test compares
        // `vwContainer.layer.cornerRadius` against, so the test cannot drift from what draws.
        .clipShape(RoundedRectangle(cornerRadius: tokens.cardVisual.cornerRadius, style: .continuous))
        .modalGeometryProbe(.card)
    }

    /// The oblique primary button, displaced inside its slot the way UIKit displaces it.
    ///
    /// `configureButtonActionConstraint`'s `.obliqueBottomLeft` branch pins `btPrimaryAction` to
    /// `vwPrimaryAction` with `top −3, leading +3, bottom −3, trailing +3` — the SAME SIZE as the
    /// 48pt slot, shifted up-and-right by 3 — so the (−3, +3) drop shadow falls INSIDE the slot
    /// instead of outside it. SwiftUI put the button AT the slot and let the shadow hang below and to
    /// the left, which put the whole visible rectangle 3pt down and 3pt left of the shipping one on
    /// every shape (task 17, finding D-3: Δx = Δy = 3.0 exactly, and invisible to a layer-visual
    /// comparison because both backends' frames and both backends' shadow parameters agreed
    /// individually — only their composition differed).
    ///
    /// Expressed as a ZERO-SUM `EdgeInsets` derived from `tokens.obliqueOffset`, not as `.offset(…)`:
    /// the insets cancel (`top + bottom == 0`, `leading + trailing == 0`), so the slot this occupies
    /// in the button run is still exactly `buttonHeight` and the rows below do not move — but the
    /// displacement is real LAYOUT, so it is what the geometry probe (and the differential gate)
    /// measures, and it is what a hit test sees. `.offset` would move the drawing only.
    ///
    /// The pressed state composes: `ObliquePrimaryStyle` offsets the button by `obliqueOffset`
    /// (−3, +3) while pressed, which cancels this displacement and lands it flush in its slot —
    /// exactly what UIKit's `transform = .identity.translatedBy(x: -3, y: 3)` does.
    private var primaryButton: some View {
        Button(action: onPrimary) {
            if isPrimaryLoading {
                ProgressView().tint(tokens.palette.onAccent)
            } else {
                Text(primaryTitle)
            }
        }
        .buttonStyle(ObliquePrimaryStyle(tokens: tokens, fillsWidth: buttonsMatchParent))
        .disabled(!primaryEnabled || isPrimaryLoading)
        .modalGeometryProbe(.primaryButton)
        .padding(
            EdgeInsets(
                top: -tokens.obliqueOffset.height,
                leading: -tokens.obliqueOffset.width,
                bottom: tokens.obliqueOffset.height,
                trailing: tokens.obliqueOffset.width
            )
        )
    }

    private func secondaryButton(_ title: String) -> some View {
        Button(action: onSecondary) { Text(title) }
            .buttonStyle(PlainSecondaryStyle(tokens: tokens))
            // INSIDE the caller's `.padding(.top, tokens.interButton)`, so this measures the button
            // and not the inter-button gap (UIKit's counterpart, `btSecondaryAction`, likewise
            // excludes the main-action stack's spacing).
            .modalGeometryProbe(.secondaryButton)
    }
}

/// **The give between `topMin`/`topMax` — padding that yields before the content does.**
///
/// UIKit expresses this as two constraints on `svContentContainer`: `top >= topMin` at `.required`
/// and `top == topMax` at `.low`, so the inset sits at its max until the card runs out of room and
/// then compresses toward the min. SwiftUI has no min/max padding modifier, and the obvious
/// substitutes both fail: a `Spacer` collapses to its minimum inside a hugging container (which this
/// card is), and computing the give from a measured content height feeds that measurement back into
/// the layout it came from.
///
/// What works is a strip with a FLEXIBLE height (`maxHeight`, no fixed height) carrying a NEGATIVE
/// layout priority. In a `VStack` the lowest priority is served last, so the strips take their full
/// `maxHeight` whenever the card has room — the unpressured case, where this is inert and the padding
/// reads exactly `topMax` — and are the first thing squeezed when the card is against its cap, down
/// to zero, i.e. to `topMin`.
///
/// The `maxHeight` is load-bearing and was got wrong first: `.frame(height:)` is RIGID, so the strips
/// kept their full height under pressure and nothing compressed — the test caught it, reporting a
/// pressured inset still sitting at the full 24.0. A fixed frame does not become compressible by
/// being given a low priority.
private struct CompressibleVerticalPadding: ViewModifier {
    let top: CGFloat
    let bottom: CGFloat

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(maxHeight: top).layoutPriority(-1)
            content
            Color.clear.frame(maxHeight: bottom).layoutPriority(-1)
        }
    }
}
