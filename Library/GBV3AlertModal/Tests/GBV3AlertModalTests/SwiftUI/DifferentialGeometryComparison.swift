import Foundation
import SwiftUI
import UIKit
@testable import GBV3AlertModal

/// **Differential geometry: SwiftUI's computed layout against UIKit's MEASURED layout, in one
/// process, from one descriptor (spec C-3).**
///
/// Split out of `DifferentialGeometrySupport.swift` (Pass 5, step 1 —
/// `2026-08-07-uikit-retirement.md` §3): this half is the COMPARISON built on top of
/// `SwiftUIGeometry.swift`'s measurement machinery, and it dies once its numbers are recorded as
/// absolute pins (§3 steps 2–4). `uiKitFrames`/`makeUIKitModal` are NOT here — see
/// `SwiftUIGeometry.swift`'s header for why.
///
/// ## Why this is not a snapshot suite
///
/// This repo has a documented, expensive history with recorded baselines: the SwiftUI card's width,
/// its spacing and its "oblique" button style were ALL wrong while the SwiftUI snapshot suite was
/// fully green, because a recorded snapshot can only detect drift FROM ITSELF — never
/// wrong-but-consistent design. Only a human holding an iPhone caught it.
///
/// The replacement is to compare against the SHIPPING implementation instead of against a recording.
/// `UIKitModalRenderer`/`GBAlertModal` is the source of truth for what a Geniebook modal looks like;
/// it is Auto Layout, so its numbers can be MEASURED (add it to a sized `UIWindow`, `layoutIfNeeded`,
/// read `.frame`). `SwiftUIAlertModal` is instrumented with `GeometryReader` + a `PreferenceKey`
/// (`ModalGeometryProbe`, `#if DEBUG`) so its computed frames can be read the same way. Both are
/// driven from the SAME `AlertDialog` descriptor and the SAME `GBAlertModal.Properties`, and — this
/// is the part a snapshot cannot do — the SAME `DataHolder`, produced once by
/// `UIKitModalRenderer.AlertHolder.make` and handed to both. So any difference observed is the
/// renderer, not the fixture.
///
/// ## Normalisation, and the ONE thing that is deliberately not compared
///
/// Every element is reported RELATIVE TO THE CARD'S ORIGIN, and the card itself is reported as
/// `CGRect(origin: .zero, size:)`. That is, the card's absolute POSITION in the host is excluded.
/// The reason is that it is a harness artifact and nothing else: UIKit pins `vwContainer` to
/// `safeAreaLayoutGuide` (so its absolute origin depends on whatever safe-area insets the CI
/// simulator's scene reports), while the SwiftUI card is centred inside `padding(cardMarginV/H)`
/// with no safe-area participation. Both CENTRE the card, so the position carries no design
/// information; the card's SIZE — the number that shipped wrong — is compared in full, and so is
/// every element's position INSIDE the card.
///
/// Nothing else is normalised, and the 0.5pt `tolerance` — sub-pixel rounding at 2x/3x and nothing
/// more — is never widened to absorb a disagreement.
///
/// ## The one MEASUREMENT exclusion, by name
///
/// **A hugging label's width is compared against UIKit's whole-point ROUNDING of it, not against the
/// raw number** (`hugWidthElements` + `agreesOnAHuggedLabel`, both below, where the mechanism and its
/// bounds are stated in full). It applies to the secondary button only — the one element whose width
/// UIKit takes from a text label rather than from a container — because
/// `UILabel.intrinsicContentSize` rounds a text width up to a whole point while SwiftUI's `Text` does
/// not: 54.0 against 53.3 for the same string in the same font. It is a NARROWER predicate, not a
/// wider tolerance (integral, non-negative, sub-point, with y/height/centre still at 0.5pt), and
/// `test_discriminationGuard_theHuggedLabelExclusionIsNarrow` proves a whole point cannot get through
/// it. Rows accepted this way print as `agree (label rounding)`, never as `agree`.
///
/// ## The one STRUCTURAL gap — D-7, now CLOSED, and what is left in its place
///
/// **This section used to describe a gap: UIKit's subtitle lives in a `UIScrollView`
/// (`svSubtitleContainer`) that compresses under pressure, and `SwiftUIAlertModal` rendered a bare
/// `Text`, which cannot. That is fixed.** `SwiftUIAlertModal.SubtitleSlot` is the counterpart — a
/// `ScrollView` under `.frame(minHeight: floor, maxHeight: contentHeight)`, which is the same
/// `[floor, content]` interval Auto Layout arbitrates over — and it is UNCONDITIONAL, because UIKit's
/// is. What the old text got right and is worth keeping: the two backends must not merely arrive at
/// the same number, they must clip the same way, and no tolerance may be widened to hide it.
///
/// **The UIKit rule, measured** (`banner-comparable`, 844 wide, host height swept 450 → 330 in 10pt
/// steps — the probe is deleted, the numbers are not):
///
/// | host | UIKit viewport | UIKit banner | note |
/// |---|---|---|---|
/// | 844x450 | 38.33 (= content) | 160.0 (= ideal) | nothing under pressure |
/// | 844x430 | 19.33 | 160.0 | the SUBTITLE has yielded; the banner has not moved |
/// | 844x415 | 19.0 (= floor) | 159.3 | subtitle on its floor, banner starts to pay |
/// | 844x390 | 19.0 | 134.33 | landscape phone — half a one-line subtitle, clipped |
/// | 844x330 | 19.0 | 74.33 | banner absorbs every further point |
///
/// So `viewport == clamp(whatever is left, subtitleSlotFloorHeight, contentHeight)`, and **the
/// subtitle yields BEFORE the banner** — which looks backwards against `ModalLayout.Priority` and is
/// not; see `SwiftUIAlertModal.subtitleLayoutPriority` for the 750-through-the-aspect-tie mechanism.
/// SwiftUI reproduces it to within **0.09pt on every row at every step of that sweep**.
///
/// Note the regime: this is an ORDINARY one-line-per-38pt subtitle clipped purely because landscape
/// puts the card on its ceiling. Every banner shape is in it in landscape — it was never about
/// deliberately long text, which is why the long-subtitle shape alone could not have found it.
///
/// **What this bought, in gates:** `banner-comparable` is now gated in landscape through the ordinary
/// `assertAgrees` (`test_geometry_landscape_bannerComparable`), and the 19.33pt mechanism pin that
/// stood in for it is deleted. `long-subtitle-unscrolled` compares a 1222pt subtitle's viewport
/// element-for-element in BOTH orientations (645.33 against 645.33 portrait, 161.33 against 161.33
/// landscape). Both have explicit non-vacuity premises, because an agreement between two unpressured
/// cards would prove nothing about any of this.
///
/// ## What genuinely remains — ONE item, and it is not D-7
///
/// `contentScrollable` used to be the other one: `long-subtitle-scrolling`'s `subtitle` row could not
/// be compared, because the flag's outer `ScrollableContent` wrapped title AND subtitle and left the
/// subtitle slot unpressured (reporting 1222 where UIKit's viewport was 645.3). **The flag is now
/// DELETED** — the subtitle scrolls unconditionally through `SubtitleSlot` — so that shape, the
/// inequality exception it needed, and its scroll-premise test are all gone, and the one remaining
/// long-subtitle shape (`long-subtitle-unscrolled`) goes through the ordinary `assertAgrees` in both
/// orientations with its subtitle row included.
///
/// * **Vertical content padding compression, in a 15pt band — and it is UNMATCHABLE, not unbuilt.**
///   Measured on `banner-comparable` at 844 wide in 1pt steps: identical at every host height from
///   844x455 down to 844x432 and from 844x416 down to 844x330, divergent in **844x417…431**, where
///   UIKit pins its subtitle viewport to its 19pt floor and re-expands the top inset to
///   `topMax − (deficit − subtitleGive) / 2` (16 → up to 23.67), while SwiftUI sheds padding first
///   and holds 16.
///
///   **Two earlier explanations of this were wrong and are corrected here.** It is NOT
///   `componentSpacing` (800) outranking the subtitle slot (250): the three gap dividers hold their
///   full 8/8/16 through the entire band and never yield a point. And it is NOT a missing min/max
///   padding primitive: `AlertModalScaffold.CompressibleVerticalPadding` is one, and it matches
///   UIKit exactly wherever UIKit's answer is single-valued.
///
///   The real obstruction is that **UIKit has no single answer to match.** `svContentContainer`'s
///   `top == topMax` (SnapKit `.low`) and `svSubtitleContainer`'s height tie
///   (`Priority.subtitleSlotHeight`) are BOTH `defaultLow` (250), so every split of a given deficit
///   between "shed padding" and "clip the subtitle" costs Auto Layout exactly the same and the
///   optimum is a face rather than a point. Demonstrated, not argued: the same modal at 844x440
///   reports a 18.67pt top inset over a 38.33pt viewport laid out fresh, and 24.00 over 27.33 after
///   a pass at 844x300 — 16pt apart from identical inputs, on nineteen consecutive host heights.
///   SwiftUI's layout is a pure function of (tree, proposed size) and reproduces the FRESH branch;
///   matching the band instead would mean inverting the ladder, which breaks 844x432…455, where
///   UIKit's fresh branch needs the ordering SwiftUI already has. Both pinned by
///   `DifferentialGeometryTests`' `test_theTwoCompressionRungs_areTheSamePriority_soTheOptimumIsATiedFace`
///   and `test_uiKitVerticalCompression_isPathDependent_soTheBandHasNoTargetToMatch`.
///
/// Do NOT "close" it by widening the tolerance to fit.
extension DifferentialGeometry {

    // MARK: - Verdicts

    enum Verdict: String {
        case agree
        /// A HUG-WIDTH element whose only difference is UIKit's whole-point rounding of a label's
        /// intrinsic width — the one measurement exclusion in this harness, printed as its own verdict
        /// so a reader of the table can never mistake it for an unqualified `agree`. See
        /// `agreesOnAHuggedLabel`, which states the mechanism and bounds it.
        case agreeWithinLabelRounding = "agree (label rounding)"
        case differ = "DIFFER"
        /// Neither backend drew this element. For `banner` this is the documented exclusion (see
        /// `bannerIsUnresolvableInTheLibraryBundle`); for the others it means the shape genuinely
        /// has no such slot, and the two backends AGREE that it has none.
        case absentOnBoth = "absent (both)"
        case onlyUIKit = "ONLY UIKit"
        case onlySwiftUI = "ONLY SwiftUI"

        /// Anything a reviewer must act on. `absentOnBoth` is agreement about an absence, not a gap.
        var isDisagreement: Bool {
            switch self {
            case .agree, .agreeWithinLabelRounding, .absentOnBoth: return false
            case .differ, .onlyUIKit, .onlySwiftUI: return true
            }
        }
    }

    struct Row {
        let element: ModalGeometryElement
        let uiKit: CGRect?
        let swiftUI: CGRect?
        let verdict: Verdict
    }

    /// True when two rects agree on origin AND size to within `tolerance` on every edge.
    ///
    /// **This is the predicate for every element except the hug-width ones, and it is not negotiable:**
    /// `test_discriminationGuard_toleranceIsSubPixelOnly` proves 1.0pt of x, of width and of height are
    /// each rejected here, and the nine per-shape tests are gated on it.
    static func agrees(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    /// **The elements whose WIDTH is a text label's intrinsic width rather than a slot's.**
    ///
    /// Only the secondary button: `configureButtonActionConstraint`'s `.plain` branch constrains it
    /// `leading >= superview.leading` + `center == superview.center`, so it is as wide as its label
    /// plus `contentEdgeInsets` and centred in its slot. Everything else in the vocabulary takes its
    /// width from a container — the card and the content rows from the preset's width, the primary
    /// button from its slot, the close button from a hardcoded 48 — and every one of those is compared
    /// with `agrees` at the full 0.5pt tolerance.
    ///
    /// The primary button is deliberately NOT here even though it hugs when
    /// `buttonActionShouldMatchParent` is false: no preset in the app sets that, so adding it would
    /// widen the exclusion for a case nothing measures. If a preset ever does, this set is where it
    /// belongs — with the same mechanism argument, which applies unchanged.
    static let hugWidthElements: Set<ModalGeometryElement> = [.secondaryButton]

    /// **THE ONE MEASUREMENT EXCLUSION IN THIS HARNESS, and the mechanism that bounds it.**
    ///
    /// `UILabel.intrinsicContentSize` rounds a text width UP to a whole point; SwiftUI's `Text`
    /// reports it at display-scale resolution. So a button that hugs the SAME string in the SAME font
    /// measures **54.0** on UIKit and **53.3** on SwiftUI (measured, `standard-two-button` and
    /// `oblique-red-leave-confirm`), and because the button is CENTRED in its slot, half of that 0.7pt
    /// lands on `minX` as well. Neither number is wrong and neither backend can be made to produce the
    /// other's without overriding a platform text metric — which would be a worse defect than the one
    /// it hides.
    ///
    /// So this is not a wider tolerance; it is a DIFFERENT, NARROWER predicate that only accepts the
    /// shape of that specific rounding:
    ///
    /// * `y` and `height` must agree at the normal 0.5pt tolerance — unchanged;
    /// * the CENTRE must agree at the normal 0.5pt tolerance, because both backends centre the button
    ///   in the same slot. A hug that drifted sideways is still reported; only the arithmetic
    ///   consequence of the width is absorbed, and the leading edge is not compared separately because
    ///   it is `centre − width/2` and would double-count the same fact;
    /// * UIKit's width must be **integral** (it is a ceiling), must be **>= SwiftUI's** (a ceiling is
    ///   never smaller) and must be **< 1pt wider**. A one-point design difference fails all three
    ///   tests it can fail: 55.0 against 53.3 is a whole point too wide, 54.5 against 53.8 is not
    ///   integral, and 53.0 against 53.3 is narrower than the value it is supposed to round up.
    ///
    /// `test_discriminationGuard_theHuggedLabelExclusionIsNarrow` pins all of that. If a future change
    /// makes SwiftUI's hug width genuinely wrong, this predicate reports it.
    ///
    /// **The first version of this had a hole, and that guard is how we know.** It began with
    /// `if agrees(uiKit, swiftUI) { return true }` as a shortcut for "identical measurements need no
    /// exclusion" — which quietly re-admitted the general 0.5pt tolerance on the WIDTH, so a UIKit
    /// width 0.3pt NARROWER than SwiftUI's (impossible for a ceiling, and therefore a signal that
    /// something other than rounding is happening) was accepted. The width is now compared ONLY by the
    /// two relationships the mechanism permits: exactly equal, or an integral ceiling. In the
    /// narrowing direction this predicate is deliberately STRICTER than `agrees` — which can only ever
    /// report more disagreements, never fewer.
    static func agreesOnAHuggedLabel(uiKit: CGRect, swiftUI: CGRect) -> Bool {
        // Non-width geometry, at the normal tolerance, on the CENTRE rather than the leading edge (a
        // hug's `minX` is `centre − width/2`, so comparing it too would double-count the width fact).
        guard abs(uiKit.midX - swiftUI.midX) <= tolerance,
              abs(uiKit.minY - swiftUI.minY) <= tolerance,
              abs(uiKit.height - swiftUI.height) <= tolerance else { return false }

        let widthDelta = uiKit.width - swiftUI.width
        // (1) Identical widths: no exclusion is in play at all. This path must stay open — a
        //     SwiftUI-vs-SwiftUI self comparison takes it, and `agrees` cannot be used to express it
        //     because its 0.5pt slack is exactly what leaked. `epsilon` is float noise, not tolerance.
        let epsilon: CGFloat = 0.01
        if abs(widthDelta) <= epsilon { return true }
        // (2) Otherwise UIKit's width must BE the whole-point ceiling of SwiftUI's: integral, strictly
        //     wider (a ceiling is never narrower than its input), and by less than a point.
        let uiKitWidthIsIntegral = abs(uiKit.width - uiKit.width.rounded()) <= epsilon
        return uiKitWidthIsIntegral && widthDelta > epsilon && widthDelta < 1
    }

    static func compare(
        uiKit: [ModalGeometryElement: CGRect],
        swiftUI: [ModalGeometryElement: CGRect]
    ) -> [Row] {
        ModalGeometryElement.allCases.map { element -> Row in
            switch (uiKit[element], swiftUI[element]) {
            case (nil, nil):
                return Row(element: element, uiKit: nil, swiftUI: nil, verdict: .absentOnBoth)
            case let (lhs?, nil):
                return Row(element: element, uiKit: lhs, swiftUI: nil, verdict: .onlyUIKit)
            case let (nil, rhs?):
                return Row(element: element, uiKit: nil, swiftUI: rhs, verdict: .onlySwiftUI)
            case let (lhs?, rhs?):
                if agrees(lhs, rhs) {
                    return Row(element: element, uiKit: lhs, swiftUI: rhs, verdict: .agree)
                }
                // The ONE exclusion, applied to the ONE element class it is argued for. Everything
                // else falls straight through to DIFFER at the 0.5pt tolerance.
                if hugWidthElements.contains(element),
                   agreesOnAHuggedLabel(uiKit: lhs, swiftUI: rhs) {
                    return Row(
                        element: element, uiKit: lhs, swiftUI: rhs,
                        verdict: .agreeWithinLabelRounding
                    )
                }
                return Row(element: element, uiKit: lhs, swiftUI: rhs, verdict: .differ)
            }
        }
    }

    static func rows(for shape: Shape, size: CGSize = host) -> [Row] {
        compare(uiKit: uiKitFrames(shape, size: size), swiftUI: swiftUIFrames(shape, size: size))
    }

    // MARK: - Layer visuals (spec C-3b)

    /// The two surfaces that HAVE a layer identity. Frames cannot express either of them.
    struct LayerVisuals: Equatable {
        var card: ModalTokens.LayerVisual
        /// `nil` when the shape draws no primary button.
        var primaryButton: ModalTokens.LayerVisual?
    }

    /// Read off the REAL `CALayer`s the UIKit renderer configured, after hosting and layout.
    ///
    /// `vwContainer.layer.cornerRadius` is set by `adjustDialogViewStyle`; the primary button's
    /// three values are set by `configureButtonActionStyle`'s `.obliqueBottomLeft` branch via
    /// `CALayer.applySketchShadow(x: -3, y: 3, blur: 0)` — which stores `blur / 2` in
    /// `shadowRadius`, i.e. 0. That call happens inside a `UIView.animate` block, which runs its
    /// animations closure synchronously, so the MODEL layer values are already final here.
    static func uiKitLayerVisuals(_ shape: Shape) -> LayerVisuals {
        let modal = makeUIKitModal(shape)
        let window = makeWindow()
        defer { teardown(window) }
        modal.show(parent: window, completion: {})
        window.setNeedsLayout()
        window.layoutIfNeeded()

        // A missing `vwContainer` is a hard bug, not a shape variation — the -1 sentinel makes the
        // comparison fail loudly instead of quietly comparing nothing.
        var card = ModalTokens.LayerVisual(
            cornerRadius: -1, shadowOffset: CGSize(width: -1, height: -1), shadowRadius: -1
        )
        if let container = modal.vwContainer {
            card = visual(of: container.layer)
        }
        var primaryButton: ModalTokens.LayerVisual?
        if let button = modal.btPrimaryAction {
            primaryButton = visual(of: button.layer)
        }
        return LayerVisuals(card: card, primaryButton: primaryButton)
    }

    /// Reads the three compared properties off one real layer, gated on whether the shadow is
    /// actually DRAWN.
    ///
    /// The gate is load-bearing and is not a tolerance: `CALayer`'s DEFAULTS are
    /// `shadowOffset == (0, -3)` and `shadowRadius == 3` with `shadowOpacity == 0`. A view that was
    /// never given a shadow — `vwContainer` is exactly that — therefore reports a non-zero offset
    /// and radius for a shadow that renders nothing at all. Comparing those raw numbers against the
    /// SwiftUI card's declared "no shadow" would report a divergence where the two renderers agree
    /// perfectly. So an invisible shadow is normalised to no shadow, which is the visual fact;
    /// `shadowOpacity > 0` keeps every REAL shadow (the oblique drop is set at opacity 1) fully
    /// compared, offset and radius included.
    static func visual(of layer: CALayer) -> ModalTokens.LayerVisual {
        let draws = layer.shadowOpacity > 0
        return ModalTokens.LayerVisual(
            cornerRadius: layer.cornerRadius,
            shadowOffset: draws ? layer.shadowOffset : .zero,
            shadowRadius: draws ? layer.shadowRadius : 0
        )
    }

    /// The SwiftUI side's DECLARED layer identity — the values `ObliquePrimaryStyle` and
    /// `AlertModalScaffold.card` render from (see `ModalTokens.LayerVisual`'s doc for why this is a
    /// declared value and not a hosted-layer read: `clipShape` is a mask and `.shadow` is a filter,
    /// neither of which lowers to a settable `CALayer` property).
    ///
    /// **`primaryButton` is gated on the shape actually HAVING one**, and it has to be: the UIKit
    /// side reports `nil` when `btPrimaryAction` was never built, so returning the token value
    /// unconditionally compared a declared visual against an absent button and called it a
    /// divergence. The gate asks the SHARED resolver — the same question `AlertModalScaffold`'s
    /// button run now asks — rather than re-deriving "is there a primary" from the descriptor, so
    /// the two cannot drift. Vacuous before Pass 2, when every descriptor had a primary button.
    static func swiftUILayerVisuals(_ shape: Shape, tokens: ModalTokens? = nil) -> LayerVisuals {
        let tokens = tokens ?? ModalTokens(from: shape.properties)
        let holder = UIKitModalRenderer.AlertHolder.make(for: shape.dialog, resolve: { _ in })
        let resolved = GBAlertModal.resolve(
            properties: shape.properties, holder: holder, isLandscape: false
        )
        return LayerVisuals(
            card: tokens.cardVisual,
            primaryButton: resolved.showsPrimary ? tokens.primaryButtonVisual : nil
        )
    }

    /// **Corroboration, narrow on purpose:** every DISTINCT non-zero `shadowOffset` found on the
    /// layer tree SwiftUI lowered the hosted modal to.
    ///
    /// SwiftUI is not required to express `.shadow(...)` as a `CALayer` shadow — it usually renders
    /// it into its own drawing layer — so an EMPTY result proves nothing and the caller treats it
    /// as "not lowered". A NON-empty result, though, is a real cross-check: the offsets SwiftUI put
    /// on actual layers must include the token offset, or the two backends disagree about the
    /// oblique drop even though the frames match.
    ///
    /// One property, one predicate, no structural claims about the tree — this is not a hierarchy
    /// walk that any future change to SwiftUI's internals can break, because nothing here asserts
    /// what the tree contains.
    static func swiftUIHostedShadowOffsets(_ shape: Shape) -> Set<CGSizeKey> {
        let root = ProbeHost(sink: Sink()) {
            SwiftUIAlertModal(
                config: shape.dialog,
                properties: shape.properties,
                tokens: ModalTokens(from: shape.properties),
                onAction: { _ in }
            )
        }
        let controller = UIHostingController(rootView: root)
        controller.view.frame = CGRect(origin: .zero, size: host)
        let window = makeWindow()
        defer { teardown(window) }
        window.rootViewController = controller
        // A short fixed settle: there is no readiness signal to wait on here, and the full budget
        // would spend 200ms of run loop for nothing.
        pump(window, budget: 3) { false }

        var offsets: Set<CGSizeKey> = []
        func visit(_ layer: CALayer) {
            if layer.shadowOffset != .zero, layer.shadowOpacity > 0 {
                offsets.insert(CGSizeKey(layer.shadowOffset))
            }
            layer.sublayers?.forEach(visit)
        }
        visit(controller.view.layer)
        return offsets
    }

    /// A `Set` key wrapper, so "did SwiftUI lower ANY shadow, and was it the right one" is
    /// expressible without depending on traversal order — and so a failure message prints the
    /// offsets rather than a reflection dump.
    struct CGSizeKey: Hashable, CustomStringConvertible {
        let width: CGFloat
        let height: CGFloat
        init(_ size: CGSize) {
            self.width = size.width
            self.height = size.height
        }
        var description: String { "(\(width), \(height))" }
    }

    /// **The safe-area insets a `makeWindow(size:)` host actually reports — read, never assumed.**
    ///
    /// This is the number that bounds the card's height, and it is NOT `cardMarginV`: UIKit's
    /// `adjustVwContainerConstraint` pins `vwContainer` against `safeAreaLayoutGuide`, and the
    /// `UIHostingController` that carries `AlertModalScaffold` hands its `GeometryReader` the
    /// safe-area-inset height too. So both backends lay out inside `host.height − top − bottom`
    /// whatever the preset's vertical margin says — and `GeniePresets.margin` deliberately says
    /// ZERO, which is exactly why a cap derived from `cardMarginV` alone is the whole host and
    /// asserts nothing.
    ///
    /// Measured on this device in landscape it is 62 + 34, but that pair is deliberately NOT
    /// written down in an assertion anywhere: it is a property of the simulator, so a test that
    /// hardcoded it would go red on a different device for a reason that is not a defect. Reading
    /// it back off the same window the measurements run in keeps the derived cap true on any host.
    static func safeAreaInsets(size: CGSize = host) -> UIEdgeInsets {
        let window = makeWindow(size: size)
        defer { teardown(window) }
        window.setNeedsLayout()
        window.layoutIfNeeded()
        return window.safeAreaInsets
    }

    // MARK: - Reporting

    static func format(_ rect: CGRect?) -> String {
        guard let rect else { return "—" }
        return String(
            format: "x %.1f y %.1f w %.1f h %.1f",
            rect.minX, rect.minY, rect.width, rect.height
        )
    }

    /// A human-readable table: element × UIKit × SwiftUI × verdict. Used verbatim as the failure
    /// message, so a red test reports the whole shape rather than the first bad edge.
    static func table(name: String, rows: [Row]) -> String {
        var lines = [
            "shape '\(name)' — frames relative to the card origin, tolerance \(tolerance)pt",
            "  element          | UIKit (measured)                 | SwiftUI (computed)               | verdict"
        ]
        for row in rows {
            lines.append(
                "  "
                    + row.element.rawValue.padding(toLength: 16, withPad: " ", startingAt: 0)
                    + " | " + format(row.uiKit).padding(toLength: 32, withPad: " ", startingAt: 0)
                    + " | " + format(row.swiftUI).padding(toLength: 32, withPad: " ", startingAt: 0)
                    + " | " + row.verdict.rawValue
            )
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - The banner exclusion, as a checkable fact

    /// `banner` is EXCLUDED from every shape, and this is the reason, expressed so a test can
    /// verify it instead of taking it on trust.
    ///
    /// `UIKitModalRenderer.AlertHolder.make` resolves a `ModalImage` with `UIImage(named:)` and
    /// `SwiftUIAlertModal` draws it with `Image(_ name:)`; BOTH search `Bundle.main`, which in the
    /// library test bundle is the test runner app and contains none of the app's 12 banner assets.
    /// So `GBAlertModal.resolve` reports `showsBanner == false` on both sides and neither backend
    /// draws a banner — the two AGREE, but about an absence.
    ///
    /// Substituting a generated image on the UIKit side only (what `GenieShapeCatalog` does, for a
    /// different purpose) would MANUFACTURE a divergence: UIKit would draw a banner slot and
    /// SwiftUI would draw nothing, and the report would blame the renderer for a fixture. There is
    /// no seam to inject an image into `SwiftUIAlertModal`'s `Image(name)` lookup, so a differential
    /// banner comparison is not expressible from this target at all. It needs the example app,
    /// which owns the assets. Recorded as a real coverage gap, not papered over.
    static func bannerIsUnresolvableInTheLibraryBundle(_ shape: Shape) -> Bool {
        guard let image = shape.dialog.image else { return false }
        // Resolve through the SAME path the renderers use. This checked `UIImage(named:)` with no
        // bundle, which was right while every asset came from the main bundle — and became wrong the
        // moment `ModalImage` could name its own: a bundle-scoped asset that BOTH renderers load
        // happily was reported unresolvable, so the shape built to close this very gap read as
        // excluded. Caught by `test_theBannerRow_actuallyMeasuresABanner`, which exists precisely
        // because "absent on both" passes quietly.
        return UIImage(named: image.assetName, in: image.bundle, compatibleWith: nil) == nil
    }
}
