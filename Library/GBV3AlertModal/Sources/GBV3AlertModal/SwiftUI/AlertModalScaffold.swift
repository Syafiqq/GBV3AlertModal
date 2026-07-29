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
        self.content = content
    }

    public var body: some View {
        ZStack {
            scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onOverlayTap?() }

            card
                // The CARD's cap — `contentMaxWidth + leftMax + rightMax`, i.e. the width UIKit's
                // `vwContainer` ends up with, NOT the width `ContentProperty` states (that one caps
                // the content container inside `card`). Feeding the content width in here is the
                // 64pt-narrow-card defect D-1; see `ModalTokens.cardMaxWidth`.
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
                        // 48, from `tokens.closeButtonSize` — UIKit's `size == 48` on
                        // `btCloseAction`. This was 44 (the HIG minimum), which put the glyph 2pt
                        // further from both card edges than the shipping modal does (D-5).
                        .frame(width: tokens.closeButtonSize, height: tokens.closeButtonSize)
                        .contentShape(Rectangle())
                        .modalGeometryProbe(.closeButton)
                    }
                }
                .padding(.vertical, tokens.cardMarginV)     // card→screen margin: 40 v / 20 h
                .padding(.horizontal, tokens.cardMarginH)
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
    /// 1. `.frame(maxWidth: .infinity).frame(maxWidth: contentMaxWidth)` — the content container
    ///    takes its stated width and no more (`.medium` fixed width, clamped by the `.high` max).
    /// 2. `.padding(.leading/.trailing, leftMin/rightMin)` — the RIGID minima (`.required`).
    /// 3. `.frame(maxWidth: .infinity)` — fill whatever the card's own cap left, centring the
    ///    content in it (`.low` equalities + `.low` centring). The card is capped at
    ///    `cardMaxWidth` by the caller in `body`, so this resolves to
    ///    `min(available, content + leftMax + rightMax)` and the effective padding is the leftover,
    ///    which equals `leftMax`/`rightMax` whenever there is room and compresses toward the minima
    ///    when there is not.
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
    /// **ONE STATED LIMIT.** Vertically the MAX insets are applied rigidly (`.padding(.top,
    /// topMax)` / `.padding(.bottom, bottomMax)`) — top and bottom independently, which is the D-2
    /// fix, but with no compression toward `topMin`/`bottomMin`. Vertical compression only engages
    /// when the card cannot fit its content between the vertical margins, and in UIKit what happens
    /// then is that `svSubtitleContainer` (a `UIScrollView` whose visible height is tied to its
    /// content at `.low`) SHRINKS AND SCROLLS. SwiftUI renders the subtitle as a bare `Text` with no
    /// scroll container, so it cannot do that at all — modelling the vertical minima alone would
    /// produce a card that compresses its padding and then still grows off-screen, which is a
    /// different wrong answer rather than a closer one. That structural gap is recorded as task 17's
    /// finding D-7 and excluded explicitly in `DifferentialGeometrySupport`; closing it needs a
    /// scrolling subtitle slot, not a padding change.
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
        // (1) the CONTENT cap — `ContentProperty`'s stated width, applied to the content container
        //     exactly as UIKit applies it to `svContentContainer`. TWO frames, because "fill, but
        //     never past the cap" is not expressible as one: the inner `.infinity` is UIKit's
        //     `width == fixedWidth` at `.medium` (the container takes its stated width whatever its
        //     children want, so a row that hugs does not narrow the card), the outer is the
        //     `width <= maxWidth` at `.high` that clamps it.
        .frame(maxWidth: .infinity)
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
        .padding(.top, tokens.contentPadding.topMax)
        .padding(.bottom, tokens.contentPadding.bottomMax)
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
