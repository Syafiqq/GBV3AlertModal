import Foundation
import SwiftUI
import UIKit
@testable import GBV3AlertModal

/// **Differential geometry: SwiftUI's computed layout against UIKit's MEASURED layout, in one
/// process, from one descriptor (spec C-3).**
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
/// deliberately long text, which is why `long-subtitle-scrolling` alone could not have found it.
///
/// **What this bought, in gates:** `banner-comparable` is now gated in landscape through the ordinary
/// `assertAgrees` (`test_geometry_landscape_bannerComparable`), and the 19.33pt mechanism pin that
/// stood in for it is deleted. `long-subtitle-unscrolled` compares a 1222pt subtitle's viewport
/// element-for-element in BOTH orientations (645.33 against 645.33 portrait, 161.33 against 161.33
/// landscape). Both have explicit non-vacuity premises, because an agreement between two unpressured
/// cards would prove nothing about any of this.
///
/// ## What genuinely remains — two items, neither of them D-7
///
/// * **`contentScrollable`.** `long-subtitle-scrolling`'s `subtitle` row still cannot be compared,
///   and the reason is now a SwiftUI-only feature rather than a missing one: `ScrollableContent`
///   wraps title AND subtitle, so inside it the height proposal is unbounded and the subtitle slot is
///   never pressured (it reports the full 1222 where UIKit's viewport is 645.3). UIKit has no
///   counterpart wrapper. Still pinned by mechanism in
///   `test_geometry_longSubtitleScrolling_agreesExceptOnTheScrollViewport`; and since the subtitle
///   now scrolls without the flag, this is an input to whether the flag should exist at all
///   (`docs/superpowers/specs/2026-08-02-content-scrollable-review.md`).
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
/// Do NOT "close" either of them by widening the tolerance to fit.
// @MainActor: builds `GBAlertModal`, `UIWindow` and `UIHostingController`, all main-actor-isolated
// under Swift 6.
@MainActor
enum DifferentialGeometry {

    /// A phone-sized portrait host — the default both measurement functions use.
    ///
    /// It used to be the ONLY size, because `SwiftUIAlertModal` hardcoded `isLandscape: false` for
    /// the resolver: a landscape comparison would have measured that assumption rather than the
    /// layout. Both backends now read orientation from the container they are given
    /// (`GBAlertModal.makeResolvedModal` from `self.bounds`, `SwiftUIAlertModal` from a
    /// `GeometryReader`), so landscape is comparable and `landscapeHost` below is gated for real.
    static let host = CGSize(width: 390, height: 844)

    /// The same phone, rotated. Every landscape fix in this module was verified by snapshot and by
    /// eye until this existed; nothing compared SwiftUI's landscape geometry against UIKit's
    /// measured numbers.
    static let landscapeHost = CGSize(width: 844, height: 390)

    /// **An iPad-WIDTH host — named, because its two siblings above are.**
    ///
    /// It exists for one job: it is wider than `cardMaxWidth + 2·cardMarginH`, which is the regime
    /// where `AlertModalScaffold`'s host-derived column ceiling names more room than a card pinned at
    /// `cardMaxWidth` could hand over. Both phone hosts are narrower, so neither exercises that
    /// branch (`test_bannerWide_theSlotNeverOverflowsTheCard_atAnyHostWidth`).
    ///
    /// **iPad-WIDTH, not an iPad.** It is a `UIWindow` of these dimensions on whatever simulator is
    /// running, so the trait collection, the size classes, the display scale and
    /// `UIDevice.current.userInterfaceIdiom` all remain the host device's. Nothing here is evidence
    /// about iPad hardware; it is evidence about the width arithmetic.
    static let iPadWidthHost = CGSize(width: 1024, height: 1366)

    /// Sub-pixel only. Auto Layout resolves to fractional points and SwiftUI rounds to the display
    /// scale, so a shared edge can legitimately land half a point apart; anything larger is a
    /// design difference. Deliberately NOT tunable per shape.
    static let tolerance: CGFloat = 0.5

    // MARK: - Shapes

    /// One comparable shape: a descriptor plus the `Properties` preset it is drawn with.
    ///
    /// Both are the real catalog values. The example app's `SwiftUICatalog` / `DialogCatalog` cannot
    /// be reached from the library test target (different target, and the example test target uses
    /// explicit file membership), so these are library-side fixtures built from `GeniePresets`,
    /// which is itself transcribed from the app's presets.
    struct Shape {
        let name: String
        let dialog: AlertDialog
        let properties: GBAlertModal.Properties
    }

    /// **Thirteen shapes, chosen to vary the fields the two backends read differently.**
    ///
    /// Covered: the standard 1-button and 2-button shapes; a nil-title shape; a close-button shape;
    /// the oblique-RED shape (a different `ObliqueBottomLeftTheme`); the permission-alert preset and
    /// the streak preset (both with ASYMMETRIC vertical padding, which is the interesting case for
    /// `ModalTokens.contentPadding` — and the streak preset is additionally the one that engages
    /// UIKit's horizontal padding COMPRESSION, asking for 352pt of card in 350pt of room); the popup
    /// preset (32pt uniform padding, different
    /// `ComponentSpace`); and the error-banner preset (popup + banner ratio/cap/fixed height).
    ///
    /// Plus the three added for the banner work: `banner-comparable` (an artwork NARROWER than the
    /// content column, so the column stays at `contentMaxWidth`), `banner-wide` (artwork wider than
    /// the column, the regime eight of the app's nine real banner assets are in), and
    /// `long-subtitle-scrolling` (a subtitle long enough to engage UIKit's slot at any size, with
    /// SwiftUI's outer `ScrollableContent` switched on).
    ///
    /// Plus `long-subtitle-unscrolled` for D-7: the same 1222pt subtitle with `contentScrollable`
    /// OFF, which is the configuration UIKit actually has a counterpart for and the one that made the
    /// subtitle row comparable.
    ///
    /// NOT covered, and why: the three bespoke descriptors (`BadgeDialog`, `LoadingDialog`,
    /// `SatisfactionDialog`) and the two input descriptors (`TextInputDialog`,
    /// `DatePickerDialog`) — those render through `register(_:view:)` bodies that build their OWN
    /// scaffold and have no `GBAlertModal` counterpart view graph to measure against, so there is
    /// nothing differential to do. Landscape is gated for the five non-banner shapes, for
    /// `long-subtitle-unscrolled` and for `banner-comparable` in full, and for `banner-wide` on
    /// everything but width (`landscapeHost` below, and `DifferentialGeometryTests`' landscape
    /// section).
    static var shapes: [Shape] {
        [
            Shape(
                name: "standard-one-button",
                dialog: AlertDialog(
                    title: "Failed",
                    subtitle: "You don't have microphone.",
                    primary: "Okay",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties()
            ),
            Shape(
                name: "standard-two-button",
                dialog: AlertDialog(
                    title: "[API] Confirm action",
                    subtitle: "[API] Are you sure you want to proceed?",
                    primary: "Yes",
                    secondary: "No",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties()
            ),
            Shape(
                name: "title-nil-error",
                // `String?.none`, not a bare `nil`: `AlertDialog` has a String and an
                // AttributedString initializer, and this pins the String one.
                dialog: AlertDialog(
                    title: String?.none,
                    subtitle: "[API] The operation couldn't be completed. (NSURLErrorDomain error -1009.)",
                    primary: "Okay",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties()
            ),
            Shape(
                name: "close-button-dismiss",
                dialog: AlertDialog(
                    title: "Access Denied",
                    subtitle: "[API] You are not allowed to send messages in this class right now.",
                    primary: "Close",
                    closeOnTapOverlay: true,
                    showCloseButton: true
                ),
                properties: GeniePresets.standardProperties()
            ),
            Shape(
                name: "oblique-red-leave-confirm",
                dialog: AlertDialog(
                    title: "You're leaving?",
                    subtitle: "The live class has not ended yet. Are you sure you want to leave?",
                    primary: "Yes",
                    secondary: "No",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.obliqueRedProperties()
            ),
            Shape(
                name: "permission-denied-settings",
                dialog: AlertDialog(
                    title: "Allow Permission",
                    subtitle: "Allow Geniebook to access your camera in your device's settings.",
                    primary: "Settings",
                    secondary: "Not now",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.permissionAlertProperties()
            ),
            Shape(
                name: "onboarding-welcome-nobanner",
                dialog: AlertDialog(
                    title: "Hello there!",
                    subtitle: "Let's explore Geniebook!",
                    primary: "I'm ready"
                ),
                properties: GeniePresets.popupProperties()
            ),
            Shape(
                name: "streak-popup-banner",
                dialog: AlertDialog(
                    image: ModalImage("streak_lose"),
                    title: "You missed your streak!",
                    subtitle: "[API] You missed your 7 days streak and 15 extra bubbles. "
                        + "Save your streak by doing 5 questions!",
                    primary: "Continue"
                ),
                properties: GeniePresets.streakProperties()
            ),
            Shape(
                name: "database-error-banner",
                dialog: AlertDialog(
                    image: ModalImage("img_database_error"),
                    title: "Something went wrong :(",
                    subtitle: "We're fixing our servers as fast as we can.\nTake a break and try again later.",
                    primary: "Okay"
                ),
                properties: GeniePresets.errorBannerProperties()
            ),
            /// **The first shape whose BANNER is actually compared.**
            ///
            /// Every other banner shape here draws nothing on either side: both renderers resolve
            /// artwork from the main bundle, this target has none, and `bannerIsUnresolvableInThe
            /// LibraryBundle` therefore reports `absent (both)` — agreement about an absence, which
            /// is not a measurement. `ModalImage.bundleIdentifier` closes that: the asset lives in
            /// this target's own resource bundle, so both backends draw a real 16:9 image and the
            /// `.banner` row finally carries two frames.
            ///
            /// `TestBundleAssetTests` gates the premise — that the asset resolves at all — because a
            /// banner row over an unresolvable name would go back to `absent (both)` and PASS.
            Shape(
                name: "banner-comparable",
                dialog: AlertDialog(
                    image: ModalImage(
                        "gb_test_banner", bundleIdentifier: Bundle.module.bundleIdentifier
                    ),
                    title: "Heads up",
                    subtitle: "A banner the gate can actually measure.",
                    primary: "Okay"
                ),
                properties: GeniePresets.standardProperties()
            ),
            /// **The banner shape whose artwork is WIDER than the content column.**
            ///
            /// Eight of the app's nine real banner assets are (`img_gc2gs_prompt_*` at 320x190pt is
            /// this one, verbatim). UIKit lets the artwork push the column past `contentMaxWidth` —
            /// `ivBanner`'s compression resistance (750) outranks `width == fixedWidth` at
            /// `.medium` (500) — and before this shape existed nothing on the SwiftUI side could
            /// see that. Measured cost when it was missed: card 30pt narrow, banner 72pt tall.
            ///
            /// Expected on both sides: card 350, column 310, banner height 184.06.
            Shape(
                name: "banner-wide",
                dialog: AlertDialog(
                    image: ModalImage(
                        "gb_test_banner_wide", bundleIdentifier: Bundle.module.bundleIdentifier
                    ),
                    title: "Heads up",
                    subtitle: "A banner wider than the column it sits in.",
                    primary: "Okay"
                ),
                properties: GeniePresets.popupProperties()
                    .copy(bannerRatio: 320.0 / 190.0, bannerMaxHeight: 256)
            ),
            /// **The shape that ENGAGES the scroll — the half of D-7 the gate could not see.**
            ///
            /// Every shape above is short enough that UIKit's `svSubtitleContainer` is exactly its
            /// label's height, so the gate was comparing a scroll slot against a `Text` in the one
            /// case where the two happen to coincide. This subtitle is long enough to overflow even
            /// the portrait card, so UIKit's slot genuinely shrinks-and-scrolls and the comparison
            /// is finally against the mechanism rather than around it.
            ///
            /// `contentScrollable` is ON so BOTH backends scroll. With it off, SwiftUI would render
            /// the whole subtitle and the two would differ for a reason already recorded — this
            /// shape exists to measure the SCROLLING paths against each other.
            Shape(
                name: "long-subtitle-scrolling",
                dialog: AlertDialog(
                    title: "Heads up",
                    subtitle: String(
                        // FORTY, not twenty. At twenty the subtitle came to 611pt and the portrait
                        // card — whose ceiling the zeroed vertical margin raised — simply FIT it, so
                        // the slot equalled its content and the row was vacuous. The premise test
                        // `test_theScrollingShape_actuallyScrolls` caught that, which is the whole
                        // reason it exists.
                        repeating: "This subtitle keeps going so the slot has to engage. ", count: 40
                    ).trimmingCharacters(in: .whitespaces),
                    primary: "Okay",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties().copy(contentScrollable: true)
            ),
            /// **The same subtitle WITHOUT `contentScrollable` — the shape that closes D-7's last
            /// exception, because it is the one UIKit actually has a counterpart for.**
            ///
            /// `long-subtitle-scrolling` above cannot compare its `subtitle` row, and the reason is
            /// no longer the missing subtitle viewport: `SubtitleSlot` supplies that now,
            /// unconditionally. The reason is the SwiftUI-ONLY outer scroll that `contentScrollable`
            /// turns on — it wraps title AND subtitle, so inside it the height proposal is unbounded
            /// and the subtitle slot is never pressured, while UIKit (which has no such wrapper)
            /// compresses its `svSubtitleContainer` as usual.
            ///
            /// Drop the flag and the two are measurably the same layout: SwiftUI's slot lands on
            /// UIKit's VIEWPORT to the point — **645.33 against 645.33** in portrait and **161.33
            /// against 161.33** in landscape, on a subtitle whose content is 1222pt. So this shape
            /// goes through the full `assertAgrees` in BOTH orientations, subtitle row included,
            /// which is the real comparison the inequality above was a placeholder for.
            Shape(
                name: "long-subtitle-unscrolled",
                dialog: AlertDialog(
                    title: "Heads up",
                    subtitle: String(
                        repeating: "This subtitle keeps going so the slot has to engage. ", count: 40
                    ).trimmingCharacters(in: .whitespaces),
                    primary: "Okay",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties()
            )
        ]
    }

    static func shape(named name: String) -> Shape? {
        shapes.first { $0.name == name }
    }

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

    // MARK: - UIKit measurement (the source of truth)

    /// Reads the real `GBAlertModal`'s laid-out frames. Not a computation and not a recording —
    /// Auto Layout resolved these numbers, in this process, at this host size.
    static func uiKitFrames(_ shape: Shape, size: CGSize = host) -> [ModalGeometryElement: CGRect] {
        let modal = makeUIKitModal(shape)
        let window = makeWindow(size: size)
        defer { teardown(window) }
        modal.show(parent: window, completion: {})
        window.setNeedsLayout()
        window.layoutIfNeeded()

        guard let card = modal.vwContainer else { return [:] }
        let cardFrame = modal.convert(card.bounds, from: card)
        var frames: [ModalGeometryElement: CGRect] = [
            // Position excluded by design — see the type doc.
            .card: CGRect(origin: .zero, size: cardFrame.size)
        ]
        func record(_ element: ModalGeometryElement, _ view: UIView?) {
            guard let view else { return }
            frames[element] = modal.convert(view.bounds, from: view)
                .offsetBy(dx: -cardFrame.minX, dy: -cardFrame.minY)
        }
        record(.banner, modal.vwBanner)
        record(.title, modal.lbTitle)
        record(.subtitle, modal.svSubtitleContainer)
        // The VISIBLE oblique rectangle, not its slot: `configureButtonActionConstraint` insets
        // `btPrimaryAction` by (+3, -3) from `vwPrimaryAction`, and the visible rect is what a user
        // sees. Comparing the slot instead would hide that inset.
        record(.primaryButton, modal.btPrimaryAction)
        record(.secondaryButton, modal.btSecondaryAction)
        record(.closeButton, modal.btCloseAction)
        return frames
    }

    /// The modal both halves of the comparison are built from. The `DataHolder` comes from
    /// `UIKitModalRenderer.AlertHolder.make` — the SAME mapping `SwiftUIAlertModal` runs internally
    /// — so the two sides cannot differ because of their fixture.
    static func makeUIKitModal(_ shape: Shape) -> GBAlertModal {
        GBAlertModal(
            properties: shape.properties,
            holder: UIKitModalRenderer.AlertHolder.make(for: shape.dialog, resolve: { _ in })
        )
    }

    // MARK: - SwiftUI measurement (in-view, via GeometryReader + PreferenceKey)

    /// Hosts `SwiftUIAlertModal` and returns whatever the probes published.
    ///
    /// Returns `[:]` when the card was never measured — the callers treat that as a HARD failure
    /// rather than as "no differences found". A harness that silently reports an empty set is
    /// exactly how 26 vacuous green assertions got written on this plan once already.
    static func swiftUIFrames(
        _ shape: Shape,
        tokens: ModalTokens? = nil,
        size: CGSize = host
    ) -> [ModalGeometryElement: CGRect] {
        let sink = Sink()
        let root = ProbeHost(sink: sink) {
            SwiftUIAlertModal(
                config: shape.dialog,
                properties: shape.properties,
                tokens: tokens ?? ModalTokens(from: shape.properties),
                onAction: { _ in }
            )
        }
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .clear
        controller.view.frame = CGRect(origin: .zero, size: size)

        let window = makeWindow(size: size)
        defer { teardown(window) }
        window.rootViewController = controller
        pump(window) { sink.frames[.card] != nil }

        let frames = sink.frames
        guard let card = frames[.card] else { return [:] }
        var normalised: [ModalGeometryElement: CGRect] = [
            .card: CGRect(origin: .zero, size: card.size)
        ]
        for (element, rect) in frames where element != .card {
            normalised[element] = rect.offsetBy(dx: -card.minX, dy: -card.minY)
        }
        return normalised
    }

    /// Where the probes' `PreferenceKey` deliveries land.
    ///
    /// `@unchecked Sendable` for the same reason `SnapshotSupport`'s host window is
    /// `nonisolated(unsafe)`: it is only ever touched on the main thread (SwiftUI delivers
    /// preferences there, and the reads happen in a `@MainActor` test body), so there is no real
    /// race to guard. The unchecked conformance also makes this compile whether or not the SDK
    /// annotates `onPreferenceChange`'s action `@Sendable`.
    final class Sink: @unchecked Sendable {
        private var storage: [ModalGeometryElement: CGRect] = [:]
        var frames: [ModalGeometryElement: CGRect] { storage }
        func record(_ value: [ModalGeometryElement: CGRect]) { storage = value }
    }

    /// Wraps the view under measurement and drains its geometry preference into `sink`.
    ///
    /// Deliberately in the TEST target: the production instrumentation is only the probes. Nothing
    /// in the library ever collects them, so there is no library-side plumbing to keep alive.
    @MainActor
    struct ProbeHost<Content: View>: View {
        let sink: Sink
        let content: Content

        init(sink: Sink, @ViewBuilder content: () -> Content) {
            self.sink = sink
            self.content = content()
        }

        var body: some View {
            content.onPreferenceChange(ModalGeometryPreferenceKey.self) { [sink] value in
                sink.record(value)
            }
        }
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
    static func swiftUILayerVisuals(_ shape: Shape, tokens: ModalTokens? = nil) -> LayerVisuals {
        let tokens = tokens ?? ModalTokens(from: shape.properties)
        return LayerVisuals(card: tokens.cardVisual, primaryButton: tokens.primaryButtonVisual)
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

    // MARK: - Hosting

    /// A key window sized to `host`, created the way `SnapshotSupport.renderForSnapshot` documents.
    ///
    /// Every caller pairs this with `teardown(_:)` in a `defer` IN THE SAME CALL. That is not
    /// tidiness: `UIWindow(windowScene:)` registers the window in `scene.windows`, which retains it
    /// for the scene's lifetime, and a host left alive across a test boundary on this target once
    /// became a zombie that crashed the next synchronous render (see `SnapshotSupport`'s note). No
    /// window created here ever outlives the function that made it.
    static func makeWindow(size: CGSize = host) -> UIWindow {
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: .zero)
        }
        window.frame = CGRect(origin: .zero, size: size)
        window.backgroundColor = .white
        window.isHidden = false
        window.makeKeyAndVisible()
        return window
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

    static func teardown(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
        window.subviews.forEach { $0.removeFromSuperview() }
        window.windowScene = nil
    }

    /// Lays out, commits the layer tree, and turns the run loop until `isReady()` — or until the
    /// budget runs out.
    ///
    /// SwiftUI delivers a preference change as part of its update cycle, which a single synchronous
    /// `layoutIfNeeded()` does not always complete; `CATransaction.flush()` commits what SwiftUI
    /// built (the same reason `GenieShapeCatalog.bodyEvidence` calls it before reading pixels), and
    /// the short run-loop turns give the update a chance to land. The budget is small and bounded;
    /// running out is reported by the caller as a failure, never as "no differences".
    static func pump(_ window: UIWindow, budget: Int = 40, until isReady: () -> Bool) {
        for _ in 0..<budget {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            CATransaction.flush()
            if isReady() { return }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.005))
        }
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
