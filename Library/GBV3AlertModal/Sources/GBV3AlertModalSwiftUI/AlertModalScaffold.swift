import GBV3AlertModalCore

import SwiftUI

/// The only SwiftUI layout variants. Ordinary spacing and inset changes belong in `.default`;
/// these extra presets exist because their subtitle is a control or an arbitrary view.
public enum ModalLayoutPreset: Sendable, Equatable {
    case `default`
    case datePickerSubtitle
    case customSubtitle
}

private struct ModalUsesExternalContentScrollKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var modalUsesExternalContentScroll: Bool {
        get { self[ModalUsesExternalContentScrollKey.self] }
        set { self[ModalUsesExternalContentScrollKey.self] = newValue }
    }
}

/// The shared modal chrome (spec D1's bespoke-content surface): full-screen scrim + centered card +
/// primary/secondary buttons + optional close, wrapped around a caller-supplied `@ViewBuilder` body.
/// Never dismisses itself. `SwiftUIAlertModal` is this with a built-in standard body; bespoke dialogs
/// (satisfaction picker, badge grid, worksheet) supply their own content instead of a `subtitleCustomView`.
public struct AlertModalScaffold<Content: View>: View {
    @State private var modalContentIdealHeight: CGFloat?
    @State private var cardRowsIdealHeight: CGFloat?
    public let tokens: ModalTokens
    public let layoutPreset: ModalLayoutPreset
    public var scrim: Color
    /// `nil` → NO primary button, mirroring `svMainActionContainer` simply not being handed a
    /// `vwPrimaryAction`. Optional since Pass 2; see `StandardAlertContent.primary`.
    public let primaryTitle: String?
    public var isPrimaryLoading: Bool = false
    public var primaryEnabled: Bool = true
    public let onPrimary: () -> Void
    public var secondaryTitle: String? = nil
    /// The counterpart of `primaryEnabled`, added with `AlertDialog.secondaryEnabled` — the gallery's
    /// `variant-button-states` entry disables the SECONDARY, and there was nothing to carry it.
    public var secondaryEnabled: Bool = true
    public var onSecondary: () -> Void = {}
    public var showClose: Bool = false
    public var onClose: () -> Void = {}
    /// Fires on scrim tap; `nil` = scrim not interactive. The caller decides what a tap means.
    public var onOverlayTap: (() -> Void)? = nil
    /// How primary/secondary stack — `GBAlertModal.ResolvedModal.buttonAxis` verbatim, so the
    /// SwiftUI card obeys the SAME resolver decision the UIKit main-action stack does. Defaults to
    /// `.vertical`, which is also what `resolve` returns when `Properties` sets no orientation.
    ///
    /// **`SwiftUI.Axis`, not `NSLayoutConstraint.Axis`** — this used to be the latter, and the
    /// comment here defended it: the UIKit enum is "the exact type `ResolvedModal.buttonAxis` and
    /// `Properties.buttonActionOrientation` speak", so translating it would add "a second
    /// vocabulary to keep in sync for no behavioural gain."
    ///
    /// That weighed the wrong thing. The gain was never behavioural — it is that constructing this
    /// PUBLIC SwiftUI view no longer requires the caller to `import UIKit` for a two-case enum.
    /// The resolver keeps speaking UIKit's vocabulary (it must: `UIStackView.axis` takes exactly
    /// that type and the UIKit renderer is frozen); the translation happens once, at this
    /// boundary, in `init(resolved:)`'s caller. The mapping is total and cannot fail.
    public var buttonAxis: Axis = .vertical
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
    /// Whether the content contains a banner. Its size and aspect remain owned by SwiftUI's Image.
    public let hasBanner: Bool
    public let content: Content

    public init(
        tokens: ModalTokens = .standard,
        layoutPreset: ModalLayoutPreset = .default,
        scrim: Color? = nil,
        primaryTitle: String?,
        isPrimaryLoading: Bool = false,
        primaryEnabled: Bool = true,
        onPrimary: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryEnabled: Bool = true,
        onSecondary: @escaping () -> Void = {},
        showClose: Bool = false,
        onClose: @escaping () -> Void = {},
        onOverlayTap: (() -> Void)? = nil,
        buttonAxis: Axis = .vertical,
        buttonsMatchParent: Bool = true,
        hasBanner: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.tokens = tokens
        self._modalContentIdealHeight = State(initialValue: nil)
        self._cardRowsIdealHeight = State(initialValue: nil)
        self.layoutPreset = layoutPreset
        // `scrim`'s default depends on `tokens`, which a default *argument* expression can't
        // reference (Swift default args can't read other parameters) — resolved here instead.
        self.scrim = scrim ?? tokens.palette.scrim
        self.primaryTitle = primaryTitle
        self.isPrimaryLoading = isPrimaryLoading
        self.primaryEnabled = primaryEnabled
        self.onPrimary = onPrimary
        self.secondaryTitle = secondaryTitle
        self.secondaryEnabled = secondaryEnabled
        self.onSecondary = onSecondary
        self.showClose = showClose
        self.onClose = onClose
        self.onOverlayTap = onOverlayTap
        self.buttonAxis = buttonAxis
        self.buttonsMatchParent = buttonsMatchParent
        self.hasBanner = hasBanner
        self.content = content()
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
                card(availableHeight: max(0, proxy.size.height - tokens.cardMarginV * 2))
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
                // WIDTH frame is RIGID (`.frame(width:)`, not `maxWidth`; only its height yields), so
                // a column wider than its container OVERFLOWS rather than compressing. It does not
                // even clip: the slot carries no `.clipped()` and UIKit's `vwBanner` sets no
                // `clipsToBounds` either, so the excess would be visible until the card's own
                // `clipShape` cut it.
                // Growing the card by the SAME `column` closes that: the card ends up
                // `min(host − 2·cardMarginH, max(cardMaxWidth, column + leftMax + rightMax))`, so
                // either the host clamps it — and then `column ≤ host − 2·cardMarginH − leftMin −
                // rightMin` by the ceiling itself — or it does not, and the card is at least
                // `column + leftMax + rightMax ≥ column + leftMin + rightMin`. The slot fits either
                // way, and `test_bannerWide_theSlotNeverOverflowsTheCard_atAnyHostWidth` asserts the
                // consequence at three host widths rather than trusting the algebra.
                .frame(maxWidth: tokens.cardMaxWidth)
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
    /// subtitle (it does — `SwiftUIAlertModal.SubtitleSlot`, unconditionally, mirroring UIKit's
    /// `svSubtitleContainer`).
    ///
    /// **The card CAN still grow off-screen in principle, and the mechanism is worth keeping in
    /// view — but the one shape that actually did has been fixed.** The cap this view is given in
    /// `body` is `.frame(maxHeight:)`, which only PROPOSES a height: a RIGID child can report a
    /// larger ideal than the proposal and SwiftUI centres the overflow rather than compressing it.
    /// `BannerSlot`'s frame used to be exactly such a child (`.frame(width:height:)`), and the
    /// wide-banner shape in landscape measured 374.6pt of card against a 294pt ceiling — bleeding
    /// ~40pt past the vertical margin at both ends.
    ///
    /// That slot now applies its height as a `.frame(maxHeight:)` over a greedy `Color.clear`, so it
    /// yields the residual instead of insisting (see `BannerSlot`'s doc), and both banner shapes now
    /// land on the ceiling exactly: 374.6 -> 294.0 and 312.6 -> 294.0. They are consequently inside
    /// `test_landscape_cardFitsWithinItsSafeArea`, whose cap is the SAFE AREA (the height both
    /// backends are actually given) rather than `cardMarginV`, which the Genie presets zero. Under a
    /// `cardMarginV` cap that test passed with the rigid slot still in place; under the safe-area cap
    /// it does not. The tight guarantee is still the differential one.
    ///
    /// The general statement stands: ANY rigid vertical child added below here can reintroduce the
    /// overflow, because the cap is still only a proposal. It is not reachable in portrait, where
    /// the card is free to grow and nothing is yielding.
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
    private func card(availableHeight: CGFloat) -> some View {
        // `buttonAxis` is the resolver's decision (`Properties.buttonActionOrientation`), obeyed
        // here the way the UIKit main-action `UIStackView` obeys it: `.horizontal` → HStack,
        // `.vertical` → the (default) vertical run. The vertical branch is spelled inline rather
        // than in a nested VStack so it stays byte-for-byte the layout that shipped before.
        fittingCardRows(availableHeight: availableHeight)
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
        .frame(maxWidth: tokens.contentMaxWidth)
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

    @ViewBuilder
    private func fittingCardRows(availableHeight: CGFloat) -> some View {
        if hasBanner {
            // SwiftUIAlertModal supplies its own measured title/subtitle scroll group for banner
            // dialogs. Keeping the rows here lets that group and the banner compete for the card's
            // bounded proposal while the fixed actions retain the highest priority.
            cardRows
        } else if let cardRowsIdealHeight, cardRowsIdealHeight > availableHeight {
            pressuredCardRows
                .frame(maxHeight: availableHeight)
        } else {
            cardRows
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ModalCardRowsIdealHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                }
                .onPreferenceChange(ModalCardRowsIdealHeightKey.self) { height in
                    if height > 0, cardRowsIdealHeight != height {
                        cardRowsIdealHeight = height
                    }
                }
        }
    }

    private var cardRows: some View {
        VStack(spacing: 0) {
            modalContent
            buttonRows.layoutPriority(2)
        }
    }

    /// When the full card cannot fit, only the descriptive content scrolls. Actions remain visible
    /// and reachable at the bottom of the card, matching their role as persistent modal controls.
    private var pressuredCardRows: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                modalContent
                    .environment(\.modalUsesExternalContentScroll, true)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ModalContentIdealHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
            }
            // Scroll only when needed. A bare ScrollView greedily consumes the whole card-height
            // proposal even for short content, which stretched every ordinary dialog and created
            // the large empty region reported in the badge modal.
            .frame(maxHeight: modalContentIdealHeight)
            .onPreferenceChange(ModalContentIdealHeightKey.self) { height in
                if height > 0, modalContentIdealHeight != height {
                    modalContentIdealHeight = height
                }
            }
            buttonRows.layoutPriority(2)
        }
    }

    private var modalContent: some View {
        // `Content` may be a multi-child `@ViewBuilder` tuple (banner, title, subtitle). Keep its
        // vertical layout explicit before applying a frame or environment modifier. A naked tuple
        // can be flattened by its immediate VStack, but once wrapped for the pressured scroll path
        // those children otherwise share the same origin and visually overlap.
        VStack(spacing: 0) {
            content
        }
            .frame(maxWidth: layoutPreset == .customSubtitle ? .infinity : nil, alignment: .center)
    }

    @ViewBuilder
    private var buttonRows: some View {
        if primaryTitle != nil || secondaryTitle != nil {
            if buttonAxis == .horizontal {
                HStack(spacing: tokens.interButton) {
                    if let primaryTitle { primaryButton(primaryTitle) }
                    if let secondaryTitle { secondaryButton(secondaryTitle) }
                }
            } else {
                if let primaryTitle { primaryButton(primaryTitle) }
                if let secondaryTitle {
                    secondaryButton(secondaryTitle)
                        .padding(.top, primaryTitle == nil ? 0 : tokens.interButton)
                }
            }
        }
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
    /// Picks the SwiftUI look for the primary slot — `.capsuleOutlined`/`.capsule` when
    /// `properties.primaryActionStyle` actually said so (`ModalTokens.primaryCapsuleOutlined`/
    /// `.primaryCapsule`, checked in that order since they are mutually exclusive by construction —
    /// see `ModalTokens.init(from:)`), the fixed oblique look otherwise. Only the oblique branch
    /// carries the ±3 offset padding: that trick exists to pull the oblique shadow INSIDE its slot
    /// (see the doc below), and capsule/capsuleOutlined have no shadow to pull in — UIKit pins them
    /// with a plain `edges.equalToSuperview()`, no offset.
    @ViewBuilder
    private func primaryButton(_ title: String) -> some View {
        if let outlined = tokens.primaryCapsuleOutlined {
            Button(action: onPrimary) { primaryLabel(title, tint: outlined.title) }
                .buttonStyle(
                    CapsuleOutlinedButtonStyle(visual: outlined, tokens: tokens, fillsWidth: buttonsMatchParent)
                )
                .disabled(!primaryEnabled || isPrimaryLoading)
                .modalGeometryProbe(.primaryButton)
        } else if let capsule = tokens.primaryCapsule {
            Button(action: onPrimary) { primaryLabel(title, tint: capsule.title) }
                .buttonStyle(CapsuleButtonStyle(visual: capsule, tokens: tokens, fillsWidth: buttonsMatchParent))
                .disabled(!primaryEnabled || isPrimaryLoading)
                .modalGeometryProbe(.primaryButton)
        } else if tokens.primaryIsPlain {
            Button(action: onPrimary) { Text(title) }
                .buttonStyle(PlainSecondaryStyle(tokens: tokens))
                .disabled(!primaryEnabled || isPrimaryLoading)
                .modalGeometryProbe(.primaryButton)
        } else {
            Button(action: onPrimary) { primaryLabel(title, tint: tokens.palette.onAccent) }
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
    }

    @ViewBuilder
    private func primaryLabel(_ title: String, tint: Color) -> some View {
        if isPrimaryLoading {
            ProgressView().tint(tint)
        } else {
            Text(title)
        }
    }

    /// Same precedence as `primaryButton`: `.capsuleOutlined`/`.capsule` when
    /// `properties.secondaryActionStyle` said so, the fixed plain text look otherwise.
    ///
    /// **`fillsWidth: buttonsMatchParent`, not `false`, on the capsule branches.** The hug behaviour
    /// documented on `PlainSecondaryStyle` is a property of `.plain`'s OWN UIKit constraint
    /// (`configureButtonActionConstraint`'s `.plain` case: `leading >= superview.leading` +
    /// `center == superview.center`, never pinned to the trailing edge) — it is not a blanket "the
    /// secondary slot always hugs" rule. `.capsule`/`.capsuleOutlined` get the SAME
    /// `edges.equalToSuperview()` constraint as `.obliqueBottomLeft` regardless of which slot they
    /// are in, so a capsule secondary fills its slot exactly like a capsule primary does.
    @ViewBuilder
    private func secondaryButton(_ title: String) -> some View {
        if let outlined = tokens.secondaryCapsuleOutlined {
            Button(action: onSecondary) { Text(title) }
                .buttonStyle(
                    CapsuleOutlinedButtonStyle(visual: outlined, tokens: tokens, fillsWidth: buttonsMatchParent)
                )
                .disabled(!secondaryEnabled)
                .modalGeometryProbe(.secondaryButton)
        } else if let capsule = tokens.secondaryCapsule {
            Button(action: onSecondary) { Text(title) }
                .buttonStyle(
                    CapsuleButtonStyle(visual: capsule, tokens: tokens, fillsWidth: buttonsMatchParent)
                )
                .disabled(!secondaryEnabled)
                .modalGeometryProbe(.secondaryButton)
        } else {
            Button(action: onSecondary) { Text(title) }
                .buttonStyle(PlainSecondaryStyle(tokens: tokens))
                .disabled(!secondaryEnabled)
                // INSIDE the caller's `.padding(.top, tokens.interButton)`, so this measures the
                // button and not the inter-button gap (UIKit's counterpart, `btSecondaryAction`,
                // likewise excludes the main-action stack's spacing).
                .modalGeometryProbe(.secondaryButton)
        }
    }
}

private struct ModalContentIdealHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ModalCardRowsIdealHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
///
/// **What this deliberately does NOT reproduce, and why nothing can.** These strips are OUTSIDE the
/// card's content `VStack`, so they are spent BEFORE the rows inside it: padding yields first, then
/// the subtitle. That is UIKit's answer wherever UIKit has one answer. In the 15pt landscape band
/// (`banner-comparable` at 844x417…431) UIKit does the opposite — subtitle to its floor, padding
/// re-expanded — and the two orderings cannot both be expressed, because the choice between them is
/// not a rule. `svContentContainer`'s `top == topMax` (SnapKit `.low`) and `svSubtitleContainer`'s
/// height tie (`ModalLayout.Priority.subtitleSlotHeight`) are BOTH `defaultLow` (250), so every split
/// of a given deficit costs Auto Layout the same and it returns whichever vertex of that tied face its
/// simplex reaches: measured, the same modal at 844x440 gives a 18.67pt inset over a 38.33pt subtitle
/// viewport laid out fresh, and 24.00 over 27.33 after a pass at a smaller size. SwiftUI's layout has
/// no previous pass to depend on, so there is nothing single-valued to match. Reversing the ordering
/// here to win the band would lose 844x432…455, which is the wider range and the one every real
/// landscape phone size sits nearer. Pinned by `DifferentialGeometryTests`'
/// `test_uiKitVerticalCompression_isPathDependent_soTheBandHasNoTargetToMatch`.
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

// MARK: - Axis bridge

extension ResolvedModal.ButtonAxis {
    /// Maps the platform-neutral resolver decision at the SwiftUI rendering edge.
    var swiftUIAxis: Axis {
        switch self {
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        }
    }
}
