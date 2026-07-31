import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **The owner directive, tested on BOTH renderers.**
///
/// > "title and subtitle should no truncated, title with more content compression (title will still
/// > live while subtitle begin to wrap)"
///
/// Two claims, and each is asserted by MECHANISM rather than by a recorded picture:
///
/// 1. **Nothing truncates.** `assertNoTruncation` lays the label's own attributed string out through
///    TextKit using the label's LIVE geometry (its laid-out `bounds`, its `numberOfLines`, its
///    `lineBreakMode`) and requires that (a) every glyph is placed and (b) no line fragment has a
///    TRUNCATED glyph range — which is precisely the range `UILabel` replaces with an ellipsis. That
///    is not a proxy for "no ellipsis"; it is the thing itself.
/// 2. **The title out-ranks the subtitle.** Asserted on the priority ladder, on the live views' actual
///    resistance values, and — the part that matters — on a REAL height-pressured render, where the
///    title must keep every line while the subtitle's scroll slot is squeezed below its content height.
///
/// ## What each test would report if truncation came back
///
/// This is the question that decides whether these tests test the directive or merely pass alongside
/// it, so it is answered per regression:
///
/// * restore `numberOfLines = 2` → `assertNoTruncation` goes RED twice over: the TextKit container
///   inherits the label's `maximumNumberOfLines`, so glyphs past line 2 are never placed (claim (a))
///   AND line 2 gets a truncated glyph range (claim (b)). `test_uiKitTitle_wrapsToManyLines` also
///   fails on the line count.
/// * restore `adjustsFontSizeToFitWidth = true` + `minimumScaleFactor` → the label draws one SHRUNK
///   line. `test_uiKitTitle_wrapsToManyLines` fails on the line count and on the point size
///   (the rendered `font.pointSize` is asserted against the preset's), and the SwiftUI/UIKit height
///   comparison fails because SwiftUI no longer shrinks at all.
/// * restore `lineBreakMode = .byTruncatingTail` → invisible while the label has room, so this is NOT
///   caught by the roomy fixture. It IS caught by the height-pressured one, which is why that test
///   exists and why it asserts on the subtitle label too: under pressure a truncating-tail label
///   ellipsizes and `assertNoTruncation`'s claim (b) fires.
/// * restore SwiftUI's `lineLimit(1)` → `test_swiftUITitle_wrapsToTheSameHeightUIKitDoes` fails by
///   several line heights; removing `fixedSize` instead is caught by
///   `test_swiftUITitle_keepsItsFullHeight_underHeightPressure`, which compares the pressured
///   measurement against the roomy one.
///
/// A note on what is NOT claimed: on SwiftUI there is no scrolling subtitle slot (structural gap D-7,
/// recorded in `DifferentialGeometrySupport`), so "the subtitle yields" is a UIKit-only mechanism. The
/// SwiftUI side of claim (2) is the ORDER (`titleLayoutPriority` > `subtitleLayoutPriority`) plus the
/// fact that the title's height is unaffected by pressure.
// @MainActor: builds `GBAlertModal`, `UIWindow` and `UIHostingController`.
@MainActor
final class TitleSubtitleTruncationTests: XCTestCase {

    // MARK: - Fixtures

    /// The same string the example app's `long-title` snapshot fixture uses, so the library gate and
    /// that baseline are talking about one case.
    private static let longTitle =
        "This is a deliberately very long title that must wrap across several lines inside the "
            + "fixed-width card without truncating"

    private static let longSubtitle = String(
        repeating: "This subtitle keeps going and going so the scroll slot has to engage. ", count: 20
    ).trimmingCharacters(in: .whitespaces)

    private let portrait = CGSize(width: 390, height: 844)
    /// The pressured host: a 390pt-tall card budget (margin 40/40) that cannot fit a five-line title,
    /// a very long subtitle and a 48pt button at once — so something MUST yield, and the directive
    /// says which.
    private let pressured = CGSize(width: 844, height: 390)

    private func dialog(title: String, subtitle: String) -> AlertDialog {
        AlertDialog(title: title, subtitle: subtitle, primary: "OK")
    }

    /// One fixture, both renderers — the same `AlertDialog` + `Properties` pair, mapped to a
    /// `DataHolder` by the SAME `AlertHolder.make` the executor's UIKit renderer uses (exactly how
    /// `DifferentialGeometry` builds its two sides).
    private func modal(_ dialog: AlertDialog) -> GBAlertModal {
        GBAlertModal(
            properties: GeniePresets.standardProperties(),
            holder: UIKitModalRenderer.AlertHolder.make(for: dialog, resolve: { _ in })
        )
    }

    // MARK: - (a) Neither renderer truncates

    func test_uiKitTitle_isConfiguredWithNoTruncationLadder() throws {
        let modal = self.modal(dialog(title: Self.longTitle, subtitle: "Short body."))
        renderForSnapshot(modal, size: portrait)
        let title = try XCTUnwrap(modal.lbTitle)

        XCTAssertEqual(
            title.numberOfLines, 0,
            "the title must be allowed as many lines as it needs — a line CAP is what makes UILabel "
                + "truncate in the first place"
        )
        XCTAssertEqual(
            title.lineBreakMode, .byWordWrapping,
            "UILabel's default is .byTruncatingTail, which ellipsizes the moment the label is given "
                + "less height than it asked for"
        )
        XCTAssertFalse(
            title.adjustsFontSizeToFitWidth,
            "shrink-to-fit is the first rung of the ladder that ends in truncation, and with "
                + "numberOfLines == 0 it has nothing left to do"
        )
    }

    func test_uiKitTitle_wrapsToManyLines_atFullSize_withoutTruncating() throws {
        let modal = self.modal(dialog(title: Self.longTitle, subtitle: "Short body."))
        renderForSnapshot(modal, size: portrait)
        let title = try XCTUnwrap(modal.lbTitle)
        let font = try XCTUnwrap(GeniePresets.standardProperties().titleFont)

        // FULL SIZE: the rendered font is the preset's font, not a scaled-down copy of it.
        XCTAssertEqual(
            title.font.pointSize, font.pointSize,
            "the title must not shrink — this is the point size actually rendered"
        )
        // MANY LINES: a ~120-character title in a 256pt-wide content column at bold 24 needs about
        // five. Asserted as ">= 3 line heights" so it is a statement about wrapping, not a
        // transcription of a metric.
        XCTAssertGreaterThan(
            title.bounds.height, font.lineHeight * 2.5,
            "the title occupies fewer than three lines, so it did not wrap: height "
                + "\(title.bounds.height) against a \(font.lineHeight)pt line"
        )
        // NOT TRUNCATED: every glyph placed, no ellipsis in any line fragment.
        assertNoTruncation(title, "title")
    }

    /// The SwiftUI half of claim (1), stated the only way a `Text` allows: by its measured HEIGHT.
    ///
    /// There is no readable "was I ellipsized" flag on a SwiftUI `Text`. But a truncated `Text` is
    /// SHORTER than the full string needs — that is what truncation IS — so a title occupying three
    /// or more line boxes has demonstrably not been squeezed onto one and ellipsized. This is the
    /// robust half; the strict cross-renderer comparison is the next test.
    func test_swiftUITitle_wrapsToMultipleLines_ratherThanTruncating() throws {
        let shape = longTitleShape(name: "directive-long-title")
        let font = try XCTUnwrap(shape.properties.titleFont)

        let swiftUI = try XCTUnwrap(
            DifferentialGeometry.swiftUIFrames(shape)[.title],
            "no SwiftUI probe published a title frame"
        )
        XCTAssertGreaterThan(
            swiftUI.height, font.lineHeight * 2.5,
            "the SwiftUI title occupies fewer than three lines — it is on one line (shrunk or "
                + "ellipsized), not wrapped"
        )
    }

    /// **The strict version, and an extension of the differential gate to a long title.**
    ///
    /// Both renderers must wrap the SAME string in the SAME font at the SAME row width to the SAME
    /// height. The UIKit side has just been proven (above) to hold the whole string, so agreement here
    /// carries that proof across to SwiftUI; disagreement means one of them is dropping text or
    /// breaking lines differently, and either is a real finding rather than a test artifact. The nine
    /// differential shapes cannot see this: every one of their titles is short.
    func test_swiftUITitle_wrapsToTheSameHeightUIKitDoes() throws {
        let shape = longTitleShape(name: "directive-long-title")

        let uiKit = try XCTUnwrap(
            DifferentialGeometry.uiKitFrames(shape)[.title],
            "the UIKit reader measured no title"
        )
        let swiftUI = try XCTUnwrap(
            DifferentialGeometry.swiftUIFrames(shape)[.title],
            "no SwiftUI probe published a title frame"
        )
        XCTAssertEqual(
            swiftUI.height, uiKit.height, accuracy: DifferentialGeometry.tolerance,
            "the two renderers wrap the same title to different heights (UIKit \(uiKit.height), "
                + "SwiftUI \(swiftUI.height)). Whichever is shorter is dropping text."
        )
    }

    private func longTitleShape(name: String) -> DifferentialGeometry.Shape {
        DifferentialGeometry.Shape(
            name: name,
            dialog: dialog(title: Self.longTitle, subtitle: "Short body."),
            properties: GeniePresets.standardProperties()
        )
    }

    // MARK: - (a) Root cause: the title wraps at the CONTENT width, not the CARD width

    /// **The regression test for the defect the first attempt at this directive shipped.**
    ///
    /// `numberOfLines = 0` and 900 compression resistance were both correct and both insufficient: the
    /// label was reporting an intrinsic height for the text wrapped at the CARD's width (350 portrait,
    /// 804 landscape, 320 for the banner shapes) rather than at the 256pt CONTENT width it actually
    /// gets, because `preferredMaxLayoutWidth` was never set. Auto Layout then handed it exactly the
    /// height it asked for — so the tail lines were dropped with no constraint capping anything, and no
    /// amount of compression resistance could have helped. **Resistance cannot defend a wrong intrinsic
    /// size.**
    ///
    /// The symptom tests above caught it (111 of 121 glyphs, 143.3pt against SwiftUI's 172.0). This one
    /// names the CAUSE, so a regression reports "the title is measuring itself against the wrong width"
    /// instead of "the title truncated, somewhere, for some reason".
    func test_theTitleWrapsAtTheContentWidth_notTheCardWidth_portrait() throws {
        try assertTitleWrapsAtTheContentWidth(hostSize: portrait)
    }

    /// The same fact in LANDSCAPE, where the gap was widest (the card is ~804 wide, so the stale
    /// reading was TWO lines against six) — and where the differential harness structurally cannot
    /// look, since it hosts portrait only.
    func test_theTitleWrapsAtTheContentWidth_notTheCardWidth_landscape() throws {
        try assertTitleWrapsAtTheContentWidth(hostSize: pressured)
    }

    private func assertTitleWrapsAtTheContentWidth(
        hostSize: CGSize,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let properties = GeniePresets.standardProperties()
        let modal = GBAlertModal(
            properties: properties,
            holder: UIKitModalRenderer.AlertHolder.make(
                for: dialog(title: Self.longTitle, subtitle: "Short body."), resolve: { _ in }
            )
        )

        renderForSnapshot(modal, size: hostSize)

        let title = try XCTUnwrap(modal.lbTitle)
        // This preset states the same 256 for portrait and landscape, so one expectation serves both
        // hosts. (`resolvedContentWidths` picks the orientation's own reading; a preset that made them
        // differ would need this expectation to follow suit.)
        let contentWidth = try XCTUnwrap(properties.contentProperty?.fixedWidthPortrait)
        let text = try XCTUnwrap(title.attributedText)

        // PREMISE: the label really is the content width, so "wrapped at the card width" is a
        // statement about a DIFFERENT number and not a restatement of the same one.
        XCTAssertEqual(
            title.bounds.width, contentWidth, accuracy: 0.5,
            "premise: the title should be laid out at the content width", file: file, line: line
        )
        XCTAssertEqual(
            title.preferredMaxLayoutWidth, contentWidth, accuracy: 0.5,
            "the title is measuring its height against the wrong width — this is the channel that "
                + "tells a numberOfLines == 0 label how wide it will be, and an unset (0) value makes "
                + "UIKit fill it in from whatever width an earlier layout pass happened to give it",
            file: file, line: line
        )

        // The height the string genuinely needs AT THAT WIDTH, measured independently of the label.
        let needed = text.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height
        XCTAssertGreaterThanOrEqual(
            title.bounds.height, needed - 0.5,
            "the title was given \(title.bounds.height)pt but the text needs \(needed)pt at "
                + "\(contentWidth)pt wide — it is short by "
                + "\((needed - title.bounds.height) / title.font.lineHeight) line(s)",
            file: file, line: line
        )
    }

    // MARK: - (b) Under height pressure the SUBTITLE yields, not the title

    func test_underHeightPressure_theSubtitleYields_andTheTitleSurvives_onUIKit() throws {
        let modal = self.modal(dialog(title: Self.longTitle, subtitle: Self.longSubtitle))
        renderForSnapshot(modal, size: pressured)

        let title = try XCTUnwrap(modal.lbTitle)
        let subtitleLabel = try XCTUnwrap(modal.lbSubtitle)
        let slot = try XCTUnwrap(modal.svSubtitleContainer)
        let font = try XCTUnwrap(GeniePresets.standardProperties().titleFont)

        // THE SUBTITLE YIELDED: its scroll slot is visibly shorter than its content, i.e. the
        // `.low`-priority frame/content height tie broke and the subtitle shrink-and-scrolls.
        XCTAssertLessThan(
            slot.bounds.height, slot.contentSize.height - 0.5,
            "the subtitle slot was NOT squeezed (frame \(slot.bounds.height), content "
                + "\(slot.contentSize.height)) — this fixture does not put the card under height "
                + "pressure, so it proves nothing about who yields first"
        )

        // THE TITLE SURVIVED — and "survived" now means the owner's rung 2, not "untouched": it may
        // SHRINK once the subtitle has nothing left to give, but only down to the floor, and it may
        // never lose a glyph. On the reference simulator this fixture engages rung 2 (the landscape
        // card can offer ~110pt against the 172pt the title wants at full size, so the scale lands at
        // the 0.75 floor); the assertion is written as an invariant rather than as that number, so a
        // host with different safe-area insets exercises the same contract instead of going flaky.
        let floor = ModalLayout.titleMinimumScaleFactor
        XCTAssertLessThanOrEqual(
            title.font.pointSize, font.pointSize + 0.01,
            "the title grew — rung 2 only ever scales DOWN"
        )
        XCTAssertGreaterThanOrEqual(
            title.font.pointSize, font.pointSize * floor - 0.01,
            "the title shrank BELOW the floor (\(title.font.pointSize)pt against a "
                + "\(font.pointSize * floor)pt floor). Rung 2 stops at the floor; there is no rung 3."
        )
        XCTAssertGreaterThan(
            title.bounds.height, font.lineHeight * 2.5,
            "the title collapsed to a line or two under pressure — even at the floor it should still "
                + "be wrapping, because shrinking re-wraps rather than dropping lines"
        )
        // The one that matters: whatever scale it settled at, every glyph is still laid out.
        assertNoTruncation(title, "title (under height pressure)")

        // AND THE SUBTITLE DID NOT TRUNCATE EITHER: it yields by SCROLLING, at full size. This is
        // the assertion that catches a `.byTruncatingTail` line-break mode coming back, which is
        // invisible whenever a label has all the room it wants.
        assertNoTruncation(subtitleLabel, "subtitle (under height pressure)")

    }

    /// **The regression test for what "the subtitle yields" shipped as.**
    ///
    /// Rung 1 was measured working and was still wrong: on the landscape card the slot's frame height
    /// went to ZERO — or worse, to a fraction of a line, so the body text was drawn sliced in half by
    /// the button below it. Measured on the LayerC shapes before the floor existed: 0.0pt with a
    /// banner, 9.3pt on the two-button shape (a 19.1pt line showing its top half). The subtitle was
    /// not scrolled — there was nothing to scroll and no indicator saying so.
    ///
    /// **The fixture is a SHORT title with a long subtitle**, which is the point: this is the case
    /// where nothing forces the collapse. The card has room for one line of body text; the slot gave
    /// it up anyway, because its height tie was the weakest rung and no floor stopped it at a
    /// sensible place. Contrast `test_whenOneLineOfEachCannotFit_theTitleWins`, which covers the case
    /// where the room genuinely is not there.
    func test_underHeightPressure_theSubtitleYieldsToOneLine_andNoFurther() throws {
        let modal = self.modal(dialog(title: "Heads up", subtitle: Self.longSubtitle))
        renderForSnapshot(modal, size: pressured)

        let slot = try XCTUnwrap(modal.svSubtitleContainer)
        let subtitleFont = try XCTUnwrap(GeniePresets.standardProperties().subtitleFont)
        let floor = modal.subtitleSlotFloorHeight

        // PREMISE 1: the floor is one line of the font actually rendered — not of `UILabel`'s 17pt
        // default, which is what `lbSubtitle.font` reads (nothing ever assigns it; the text carries
        // its own `.font`).
        XCTAssertEqual(
            floor, subtitleFont.lineHeight, accuracy: 0.01,
            "the floor was measured against the wrong font"
        )
        // PREMISE 2: this fixture really is pressured, or "it did not collapse" proves nothing.
        XCTAssertLessThan(
            slot.bounds.height, slot.contentSize.height - 0.5, "premise: the slot must be squeezed"
        )

        XCTAssertGreaterThanOrEqual(
            slot.bounds.height, floor - 0.5,
            "the subtitle slot is \(slot.bounds.height)pt — below the \(floor)pt one-line floor. "
                + "Below a full line the body text is drawn sliced or not at all, which is the defect "
                + "this floor exists to stop."
        )
        // And the floor is a floor, not a fixed height: an unpressured card still gives the subtitle
        // everything it asks for.
        let roomy = self.modal(dialog(title: "Heads up", subtitle: "Short body."))
        renderForSnapshot(roomy, size: portrait)
        let roomySlot = try XCTUnwrap(roomy.svSubtitleContainer)
        XCTAssertEqual(
            roomySlot.bounds.height, roomySlot.contentSize.height, accuracy: 0.5,
            "an unpressured subtitle slot must still equal its content height — the floor is not "
                + "supposed to be load-bearing here"
        )
    }

    /// **The popup preset in landscape — a real app state, and the case whitespace used to win.**
    ///
    /// `popupProperties` pairs bigger padding (20 vs 16) with much bigger gaps (16 + 24 = 40pt against
    /// the standard preset's 8 + 16), which left a 174pt content budget carrying 40pt of decorative
    /// space at `.required`. The subtitle lost, every time.
    ///
    /// Not synthetic: `V2LiveKitOnlineLessonViewController` locks iPhone to landscape in
    /// `viewDidLoad` and presents two-button `popupProperties` dialogs (banner + title + subtitle)
    /// from that screen, as does the V1 lesson controller. A student in a live class on a phone sees
    /// exactly this card.
    func test_thePopupPresetInLandscape_keepsItsSubtitle_bySpendingWhitespace() throws {
        let modal = GBAlertModal(
            properties: GeniePresets.popupProperties(), holder: GeniePresets.twoButton()
        )
        renderForSnapshot(modal, size: pressured)

        let slot = try XCTUnwrap(modal.svSubtitleContainer)
        let subtitleLabel = try XCTUnwrap(modal.lbSubtitle)
        let floor = modal.subtitleSlotFloorHeight

        XCTAssertGreaterThanOrEqual(
            slot.bounds.height, floor - 0.5,
            "the popup's subtitle slot is \(slot.bounds.height)pt against a \(floor)pt one-line "
                + "floor — the card is drawing a void where the body text belongs"
        )
        assertNoTruncation(subtitleLabel, "popup subtitle (landscape)")

        // THE WHITESPACE INVARIANT: a gap may shrink, but never EXCEED what the preset asked for.
        //
        // This used to assert that a gap actually DID shrink, and that was true when the landscape
        // card was capped at 214pt (safe area 294 − 40/40 margins). Zeroing the vertical margin
        // raised the ceiling to 294 and the content budget from 174 to 254, so this shape now fits
        // with room to spare and spends nothing — measured, the gaps come out at exactly the
        // preset's 40. The mechanism is unchanged and still ranked below the text
        // (`Priority.componentSpacing`); it simply is not needed here any more, which is the point
        // of the margin change. `test_theGapsAreExact_wheneverTheCardHasRoom` covers the roomy case.
        let space = try XCTUnwrap(GeniePresets.popupProperties().space)
        let gaps = [
            modal.vwBannerAndBelowDivider, modal.vwTitleAndBelowDivider,
            modal.vwSubtitleAndBelowDivider
        ].compactMap { $0?.bounds.height }.reduce(0, +)
        XCTAssertLessThanOrEqual(
            gaps, space.title + space.subtitle + 0.5,
            "a gap grew PAST the preset's value — the `<=` cap is `.required` and must never break"
        )
    }

    /// The same preset with ROOM: every gap is exactly what the preset asked for. This is what makes
    /// the shrink safe to apply unconditionally — it is invisible until the card is cramped.
    func test_theGapsAreExact_wheneverTheCardHasRoom() throws {
        let modal = GBAlertModal(
            properties: GeniePresets.popupProperties(), holder: GeniePresets.twoButton()
        )
        renderForSnapshot(modal, size: portrait)
        let space = try XCTUnwrap(GeniePresets.popupProperties().space)

        XCTAssertEqual(
            try XCTUnwrap(modal.vwTitleAndBelowDivider).bounds.height, space.title, accuracy: 0.5,
            "an unpressured card must render the preset's exact title gap"
        )
        XCTAssertEqual(
            try XCTUnwrap(modal.vwSubtitleAndBelowDivider).bounds.height, space.subtitle,
            accuracy: 0.5,
            "an unpressured card must render the preset's exact subtitle gap"
        )
    }

    /// **The other side of the floor: it is a floor, not a guarantee.**
    ///
    /// The landscape card is capped at 214pt (safe area 294 − 40/40 margins), which leaves 110pt for
    /// title + subtitle once the button and padding are taken. A 139-glyph title needs 107.4 of that
    /// AT ITS OWN 0.75 FLOOR, so one line of each does not fit and something must lose text. The
    /// directive settles which: "title with more content compression" — the title outlives the
    /// subtitle, so `Priority.subtitleSlotFloor` sits BELOW `titleCompressionResistance` and the floor
    /// is what breaks.
    ///
    /// This is the test that fails if someone "fixes" the collapse by promoting the floor above the
    /// title — which reads like an improvement and silently starts truncating titles instead. (That
    /// exact inversion was tried and measured: 23 of 139 glyphs lost.)
    ///
    /// The underlying conflict is the recorded landscape hard ceiling, whose real fix is a scrolling
    /// title slot mirroring `svSubtitleContainer`. Until then this pins WHICH way it fails.
    func test_whenOneLineOfEachCannotFit_theTitleWins() throws {
        // EIGHT repetitions, not the four `GeniePresets.longTitle()` carries. Zeroing the vertical
        // margin raised the landscape ceiling 214 -> 294, and at four repetitions this shape now
        // FITS — the title renders at full size and nothing has to lose anything, which made the
        // test's own premise assertion fail rather than its claim. The contract being pinned here is
        // "when it genuinely cannot fit, the TITLE is what survives", so the fixture is made harder
        // to keep that case reachable instead of the test being retired.
        let overlongTitle = String(repeating: "Long title wraps across many lines ", count: 8)
            .trimmingCharacters(in: .whitespaces)
        let modal = GBAlertModal(
            properties: GeniePresets.standardProperties(),
            holder: GeniePresets.longTitle().copy(title: overlongTitle)
        )
        renderForSnapshot(modal, size: pressured)

        let title = try XCTUnwrap(modal.lbTitle)
        let slot = try XCTUnwrap(modal.svSubtitleContainer)
        let subtitleFont = try XCTUnwrap(GeniePresets.standardProperties().subtitleFont)

        // PREMISE: this really is the impossible case — the title alone, already at its shrink floor,
        // wants more than the budget minus one subtitle line.
        XCTAssertEqual(
            modal.titleFontScaleApplied, ModalLayout.titleMinimumScaleFactor, accuracy: 0.001,
            "premise: the title must already be at its shrink floor, or nothing is impossible here"
        )
        XCTAssertLessThan(
            slot.bounds.height, modal.subtitleSlotFloorHeight,
            "premise: the floor must be the thing that broke"
        )

        // THE CLAIM IS AN ORDERING, NOT A SURVIVAL GUARANTEE. At this extreme BOTH rows run out:
        // the subtitle's floor breaks first (asserted above) and then, with the card at its hard
        // ceiling, the title's own 900 resistance breaks too and it clips — measured, 262 of 279
        // glyphs at the 0.75 floor in a 214pt card. That is rung 3, the recorded landscape hard
        // ceiling, whose real fix is a scrolling title slot.
        //
        // What this test pins is WHICH ONE GIVES WAY FIRST, because that is what the owner directive
        // settles and what a priority inversion would silently reverse: the subtitle is already
        // below its floor while the title is still holding the entire remaining budget.
        XCTAssertGreaterThan(
            title.bounds.height, slot.bounds.height,
            "the subtitle slot (\(slot.bounds.height)pt) is not smaller than the title "
                + "(\(title.bounds.height)pt) — the directive says the title outlives the subtitle, "
                + "so a card that cannot fit both must have spent the subtitle first"
        )
        // And the title is still holding essentially all of the content budget it can reach.
        XCTAssertGreaterThan(
            title.bounds.height, ModalLayout.subtitleFloorHeight(font: subtitleFont) * 3,
            "the title collapsed rather than holding the budget it won"
        )
    }

    /// The SwiftUI half of the same floor. No scroll slot exists there (structural gap D-7), so the
    /// claim is on the ROW: pressured or not, it is never given less than one line.
    ///
    /// Same SHORT-title fixture as the UIKit test, and for the same reason — this is the avoidable
    /// case, which is the one both renderers must agree on. In the IMPOSSIBLE case they diverge by
    /// construction: UIKit's floor is a priority that Auto Layout can break in the title's favour,
    /// while SwiftUI's `.frame(minHeight:)` is absolute and simply overflows. Recording that here
    /// rather than building machinery to reconcile it, since the underlying conflict is the landscape
    /// hard ceiling and its fix (a scrolling title slot) changes both sides anyway.
    func test_swiftUISubtitle_underHeightPressure_keepsAtLeastOneLine() throws {
        let shape = DifferentialGeometry.Shape(
            name: "directive-subtitle-floor",
            dialog: dialog(title: "Heads up", subtitle: Self.longSubtitle),
            properties: GeniePresets.standardProperties()
        )
        let floor = ModalTokens(from: shape.properties).subtitleFloorHeight
        XCTAssertGreaterThan(floor, 0, "premise: the tokens carry a floor at all")

        let squeezed = try XCTUnwrap(
            swiftUIFrame(shape, element: .subtitle, size: pressured), "no subtitle probe (pressured)"
        )
        XCTAssertGreaterThanOrEqual(
            squeezed.height, floor - DifferentialGeometry.tolerance,
            "the SwiftUI subtitle row is \(squeezed.height)pt against a \(floor)pt one-line floor — "
                + "it was squeezed out rather than merely being the row that yields"
        )
    }

    /// **The SwiftUI content region scrolls instead of giving anything up.**
    ///
    /// `ScrollableContent` wraps banner/title/subtitle (buttons stay outside, always tappable), so a
    /// card too short for its copy shrinks the VIEWPORT and leaves the content at its natural size.
    /// The claim here is exactly that: the pressured title occupies the SAME height as the
    /// unpressured one. Nothing is scaled, nothing is sliced, nothing is dropped.
    ///
    /// **This is a UIKit/SwiftUI divergence, and a deliberate one.** UIKit keeps its subtitle-only
    /// `svSubtitleContainer` and its rung-2 font shrink, because this module ships to the production
    /// app as an SPM dependency and restructuring its view tree is a change every consumer inherits.
    /// A consequence worth stating plainly: inside a scroll the content is offered unbounded height,
    /// so SwiftUI's `minimumScaleFactor` never fires — the shrink rung is INERT on this backend, and
    /// scrolling is the whole mechanism rather than the last resort.
    ///
    /// `DifferentialGeometry` is unaffected because it compares unpressured portrait shapes, where
    /// `ScrollableContent` is provably inert (its `maxHeight` cap equals the content's ideal height,
    /// so the region is exactly the frame it had before the scroll existed — all eight shapes green).
    func test_swiftUIContent_scrollsRatherThanShrinking_underPressure() throws {
        let shape = DifferentialGeometry.Shape(
            name: "directive-scrollable-content",
            dialog: dialog(title: Self.longTitle, subtitle: Self.longSubtitle),
            properties: GeniePresets.standardProperties().copy(contentScrollable: true)
        )
        let font = try XCTUnwrap(shape.properties.titleFont)

        let roomy = try XCTUnwrap(swiftUIFrame(shape, element: .title, size: portrait), "no roomy probe")
        let squeezed = try XCTUnwrap(
            swiftUIFrame(shape, element: .title, size: pressured), "no pressured probe"
        )

        XCTAssertGreaterThan(
            roomy.height, font.lineHeight * 2.5,
            "premise: the roomy title must already be multi-line, or this proves nothing"
        )
        XCTAssertEqual(
            squeezed.height, roomy.height, accuracy: DifferentialGeometry.tolerance,
            "the pressured title is \(squeezed.height)pt against \(roomy.height)pt roomy — the "
                + "content region is supposed to SCROLL, leaving its content at natural size. A "
                + "shorter pressured title means something is compressing or clipping it instead."
        )
    }

    /// **Opting in is what turns the scroll on — nothing else changes behind a preset's back.**
    ///
    /// The same fixture at the same pressured size, with and without `contentScrollable`. Without it
    /// the title is compressed (rung 2 scales it toward the 0.75 floor); with it the title keeps its
    /// full natural height and the viewport scrolls instead. Both are legitimate; the point is that
    /// the DEFAULT is the old one, so every shape already in the app is untouched by this feature.
    func test_theScroll_isOptInPerPreset() throws {
        let dialog = self.dialog(title: Self.longTitle, subtitle: Self.longSubtitle)
        let plain = DifferentialGeometry.Shape(
            name: "opt-in-off", dialog: dialog, properties: GeniePresets.standardProperties()
        )
        let scrolling = DifferentialGeometry.Shape(
            name: "opt-in-on", dialog: dialog,
            properties: GeniePresets.standardProperties().copy(contentScrollable: true)
        )

        let plainTitle = try XCTUnwrap(swiftUIFrame(plain, element: .title, size: pressured))
        let scrollingTitle = try XCTUnwrap(swiftUIFrame(scrolling, element: .title, size: pressured))

        XCTAssertGreaterThan(
            scrollingTitle.height, plainTitle.height + DifferentialGeometry.tolerance,
            "the scrolling preset's title (\(scrollingTitle.height)pt) should be TALLER than the "
                + "non-scrolling one's (\(plainTitle.height)pt) — it keeps its natural size while the "
                + "viewport shrinks. Equal heights mean the flag did nothing."
        )
    }

    /// **The banner stays OUTSIDE the scroll, so the ladder still governs it.**
    ///
    /// The first attempt wrapped banner + title + subtitle together. Inside a scroll nothing competes
    /// for space — each row takes its natural size in order — so the banner went first and claimed the
    /// entire viewport, pushing the title and subtitle out of sight on the landscape survey card. That
    /// inverts the owner's ordering ("banner never be a winner, it is just cosmetic, not information")
    /// exactly where it matters most.
    ///
    /// Scoping the scroll to the TEXT rows restores it structurally: the banner is a sibling of the
    /// scroll, governed by `Priority.bannerNaturalAspect` and friends, all of which sit below every
    /// text rung. This asserts the observable consequence — turning the scroll on does not change the
    /// banner's geometry, because the banner is not inside it.
    func test_theBanner_isNotInsideTheScroll() throws {
        let dialog = self.dialog(title: Self.longTitle, subtitle: Self.longSubtitle)
        let plain = DifferentialGeometry.Shape(
            name: "banner-outside-off", dialog: dialog, properties: GeniePresets.standardProperties()
        )
        let scrolling = DifferentialGeometry.Shape(
            name: "banner-outside-on", dialog: dialog,
            properties: GeniePresets.standardProperties().copy(contentScrollable: true)
        )

        // The card is the stand-in the library bundle CAN measure: the banner asset itself does not
        // resolve here (see `DifferentialGeometry.bannerIsUnresolvableInTheLibraryBundle`), but the
        // claim "the scroll does not change what sits outside it" is observable on the card's width,
        // which no scrolling of the text rows may alter.
        let plainCard = try XCTUnwrap(swiftUIFrame(plain, element: .card, size: pressured))
        let scrollingCard = try XCTUnwrap(swiftUIFrame(scrolling, element: .card, size: pressured))

        XCTAssertEqual(
            scrollingCard.width, plainCard.width, accuracy: DifferentialGeometry.tolerance,
            "turning the scroll on changed the card's WIDTH — the scroll is supposed to affect the "
                + "vertical extent of the text rows and nothing else"
        )
    }

    /// **The vertical content padding compresses from max toward min, as UIKit's does.**
    ///
    /// UIKit states it as two constraints on `svContentContainer`: `top >= topMin` at `.required`
    /// beating `top == topMax` at `.low`. SwiftUI applied `topMax` rigidly and never gave the 16pt
    /// per edge back — recorded as half of finding D-7, and justified by two claims that have since
    /// stopped being true (no SwiftUI scroll container, and a card that could grow off-screen).
    ///
    /// Asserted as a COMPARISON rather than against a literal, so it states the mechanism: the same
    /// dialog, unpressured and pressured, must not have the same top inset — and the pressured one
    /// must never fall below the rigid minimum.
    func test_theVerticalPadding_compressesTowardItsMinimum_underPressure() throws {
        let padding = try XCTUnwrap(GeniePresets.standardProperties().padding)
        let roomy = DifferentialGeometry.Shape(
            name: "padding-roomy",
            dialog: dialog(title: "Heads up", subtitle: "Short body."),
            properties: GeniePresets.standardProperties()
        )
        let overlong = String(repeating: "Long title wraps across many lines ", count: 8)
            .trimmingCharacters(in: .whitespaces)
        let squeezed = DifferentialGeometry.Shape(
            name: "padding-squeezed",
            dialog: dialog(title: overlong, subtitle: Self.longSubtitle),
            properties: GeniePresets.standardProperties()
        )

        func topInset(_ shape: DifferentialGeometry.Shape) throws -> CGFloat {
            let card = try XCTUnwrap(swiftUIFrame(shape, element: .card, size: pressured))
            let title = try XCTUnwrap(swiftUIFrame(shape, element: .title, size: pressured))
            return title.minY - card.minY
        }

        let roomyInset = try topInset(roomy)
        let squeezedInset = try topInset(squeezed)

        // ROOMY: the full max, i.e. this is inert whenever the card has room — which is why every
        // differential shape and every snapshot stayed green.
        XCTAssertEqual(
            roomyInset, padding.topMax, accuracy: DifferentialGeometry.tolerance,
            "an unpressured card must render the preset's MAX top inset"
        )
        // PRESSURED: it gave some back...
        XCTAssertLessThan(
            squeezedInset, roomyInset - DifferentialGeometry.tolerance,
            "the pressured card kept its full \(roomyInset)pt top inset — the padding is supposed to "
                + "yield before the content does, the way UIKit's `.low` equality does"
        )
        // ...but never past the rigid minimum.
        XCTAssertGreaterThanOrEqual(
            squeezedInset, padding.topMin - DifferentialGeometry.tolerance,
            "the top inset fell below `topMin` (\(padding.topMin)pt), which UIKit pins as .required"
        )
    }

    /// **One floor, read by both renderers** — the subtitle's counterpart of
    /// `test_theShrinkFloor_isOneSharedNumber`, and the reason `subtitleUIFont` exists.
    func test_theSubtitleFloor_isOneSharedNumber() throws {
        let properties = GeniePresets.standardProperties()
        let font = try XCTUnwrap(properties.subtitleFont)
        let tokens = ModalTokens(from: properties)

        XCTAssertEqual(tokens.subtitleUIFont, font, "the measurement twin is not the rendered font")
        XCTAssertEqual(tokens.subtitleFont, Font(font))
        XCTAssertEqual(tokens.subtitleFloorHeight, ModalLayout.subtitleFloorHeight(font: font))

        // …and UIKit derives the SAME number from the live label, via the text's own `.font`.
        let modal = self.modal(dialog(title: "Heads up", subtitle: "Short body."))
        renderForSnapshot(modal, size: portrait)
        XCTAssertEqual(
            modal.subtitleSlotFloorHeight, tokens.subtitleFloorHeight, accuracy: 0.01,
            "the two renderers protect different amounts of subtitle"
        )

        // `standard` has no `Properties`; its literal twin must match the `Font` beside it.
        XCTAssertEqual(ModalTokens.standard.subtitleUIFont.pointSize, 16)
        XCTAssertEqual(ModalTokens.standard.subtitleFont, .system(size: 16, weight: .regular))
    }

    /// `renderedFont` is the piece that keeps the floor honest: the subtitle label is never assigned a
    /// `font`, so reading `UILabel.font` would measure the 17pt system default rather than the 16pt
    /// the preset actually draws. Asserted as a discrimination, not just a happy path.
    func test_theFloorReadsTheFontTheTextCarries_notTheLabelsDefault() {
        let label = UILabel()
        let drawn = UIFont.systemFont(ofSize: 40)
        XCTAssertNotEqual(label.font.pointSize, drawn.pointSize, "premise: the two must differ")

        label.attributedText = NSAttributedString(string: "Body", attributes: [.font: drawn])
        XCTAssertEqual(ModalLayout.renderedFont(label.attributedText, fallback: label.font), drawn)

        // No text, or text carrying no font: the fallback is the honest answer.
        XCTAssertEqual(ModalLayout.renderedFont(nil, fallback: label.font), label.font)
        XCTAssertEqual(
            ModalLayout.renderedFont(NSAttributedString(string: ""), fallback: label.font), label.font
        )
        XCTAssertEqual(
            ModalLayout.renderedFont(NSAttributedString(string: "Body"), fallback: label.font),
            label.font
        )
    }

    /// A `.custom` subtitle gets NO floor: "one line" is not a fact about an arbitrary caller view, and
    /// inventing one would move a snapshot for a reason nothing measured.
    func test_aCustomSubtitleView_getsNoFloor() {
        let custom = UIView()
        custom.translatesAutoresizingMaskIntoConstraints = false
        custom.heightAnchor.constraint(equalToConstant: 120).isActive = true

        let modal = GBAlertModal(
            properties: GeniePresets.standardProperties(),
            holder: GBAlertModal.DataHolder(
                title: "Heads up", subtitleCustomView: custom, primaryAction: "OK"
            )
        )
        renderForSnapshot(modal, size: portrait)

        XCTAssertNotNil(modal.svSubtitleContainer, "premise: the custom view took the subtitle slot")
        XCTAssertNil(modal.lbSubtitle, "premise: the custom path builds no label")
        XCTAssertEqual(modal.subtitleSlotFloorHeight, 0)
    }

    /// The SwiftUI title under pressure: it may SCALE, it may not lose text.
    ///
    /// This test used to assert the pressured height was IDENTICAL to the roomy one, which was the
    /// right contract while the row carried `fixedSize(vertical:)` — it simply never yielded. Rung 2
    /// replaced that: `minimumScaleFactor` lets the title shrink once the subtitle has given way, and
    /// a shrunk title is legitimately shorter. So the contract is now a RANGE, and its lower bound is
    /// the thing the directive actually forbids crossing:
    ///
    /// * never taller than the roomy render (rung 2 only scales down);
    /// * never shorter than the same string needs AT THE FLOOR SCALE. SwiftUI cannot be asked whether
    ///   it ellipsized, but a `Text` that dropped text is shorter than the floor-scaled layout of the
    ///   whole string — so this lower bound is exactly "it scaled instead of truncating".
    ///
    /// SwiftUI still has no scrolling subtitle slot (D-7), so the "subtitle scrolls" half stays
    /// UIKit-only; on SwiftUI the subtitle answers pressure by scaling, one priority rung earlier.
    func test_swiftUITitle_underHeightPressure_scalesAtMostToTheFloor_neverLosingText() throws {
        let shape = DifferentialGeometry.Shape(
            name: "directive-long-title-pressured",
            dialog: dialog(title: Self.longTitle, subtitle: Self.longSubtitle),
            properties: GeniePresets.standardProperties()
        )
        let font = try XCTUnwrap(shape.properties.titleFont)
        let contentWidth = try XCTUnwrap(shape.properties.contentProperty?.fixedWidthPortrait)

        let roomy = try XCTUnwrap(swiftUITitleFrame(shape, size: portrait), "no title probe (roomy)")
        let squeezed = try XCTUnwrap(
            swiftUITitleFrame(shape, size: pressured), "no title probe (pressured)"
        )

        XCTAssertGreaterThan(
            roomy.height, font.lineHeight * 2.5,
            "premise: the roomy render must already be multi-line, or this comparison is vacuous"
        )
        XCTAssertLessThanOrEqual(
            squeezed.height, roomy.height + DifferentialGeometry.tolerance,
            "the pressured title is TALLER than the unpressured one"
        )

        // The floor-scaled layout of the whole string at the same width — the shortest the ladder
        // permits while still drawing every glyph.
        let floorHeight = ModalLayout.titleFloorHeight(
            Self.longTitle, font: font, width: contentWidth
        )
        XCTAssertGreaterThanOrEqual(
            squeezed.height, floorHeight - DifferentialGeometry.tolerance,
            "the SwiftUI title (\(squeezed.height)pt) is shorter than the floor-scaled text needs "
                + "(\(floorHeight)pt) — below that it cannot be showing the whole string, so it "
                + "truncated instead of scaling"
        )
    }

    // MARK: - (b) The ordering itself

    func test_theVerticalPriorityLadder_putsTheTitleAboveTheSubtitle() {
        // The slot floor holds one line of subtitle open — but still BELOW the title, so on a card
        // that cannot fit one line of each it is the floor that breaks and the title keeps every
        // glyph. Promoting it above 900 inverts the directive (measured: the `longTitle` landscape
        // fixture lost 23 of 139 title glyphs to buy the subtitle its line).
        XCTAssertLessThan(
            ModalLayout.Priority.subtitleSlotFloor.rawValue,
            ModalLayout.Priority.titleCompressionResistance.rawValue,
            "the subtitle's floor must not out-rank the title — 'title with more content compression'"
        )
        // …and ABOVE the subtitle label's own resistance, so it is the SLOT that holds the line open
        // rather than the label refusing to shrink.
        XCTAssertGreaterThan(
            ModalLayout.Priority.subtitleSlotFloor.rawValue,
            ModalLayout.Priority.subtitleCompressionResistance.rawValue
        )
        // WHITESPACE IS THE CHEAPEST THING ON THE CARD. The gaps must yield before the subtitle's
        // last line and before the title — at `.required` (where they started) 40pt of decorative
        // space outranked every word, and the popup landscape card drew a title, a void and two
        // buttons.
        XCTAssertLessThan(
            ModalLayout.Priority.componentSpacing.rawValue,
            ModalLayout.Priority.subtitleSlotFloor.rawValue,
            "a cramped card must spend its whitespace before it spends its text"
        )
        XCTAssertLessThan(
            ModalLayout.Priority.componentSpacing.rawValue,
            ModalLayout.Priority.titleCompressionResistance.rawValue
        )
        XCTAssertGreaterThan(
            ModalLayout.Priority.titleCompressionResistance.rawValue,
            ModalLayout.Priority.subtitleCompressionResistance.rawValue,
            "'title with more content compression' — the title's vertical resistance must out-rank "
                + "the subtitle's"
        )
        // The subtitle LABEL must stay above the subtitle SLOT's height tie: that gap is what makes
        // an over-long subtitle SCROLL instead of being squeezed into an ellipsis.
        XCTAssertGreaterThan(
            ModalLayout.Priority.subtitleCompressionResistance.rawValue,
            ModalLayout.Priority.subtitleSlotHeight.rawValue
        )
        // The banner's own internal order is unchanged.
        XCTAssertGreaterThan(
            ModalLayout.Priority.bannerNaturalAspect.rawValue,
            ModalLayout.Priority.bannerFixedHeight.rawValue
        )
        XCTAssertGreaterThan(
            ModalLayout.Priority.bannerFixedHeight.rawValue,
            ModalLayout.Priority.bannerImageIntrinsic.rawValue
        )

        // And the title is NOT `.required`: a title taller than the whole card would then make the
        // card's own `.required` margin constraints unsatisfiable and log a broken-constraint dump.
        XCTAssertLessThan(
            ModalLayout.Priority.titleCompressionResistance.rawValue,
            UILayoutPriority.required.rawValue,
            "a `.required` title turns an over-tall title into an unsatisfiable constraint system"
        )
    }

    /// **The owner's ordering, stated as one chain: buttons > title > description > banner.**
    ///
    /// > "buttons should have the higher content compression / continue with title / then
    /// > description / then banner"
    ///
    /// Asserted end to end so the ladder cannot be reordered a rung at a time without this failing.
    /// The banner is represented by its DRIVERS — the constraints that make it big. `bannerMaxHeight`
    /// is deliberately excluded and checked separately below: it is a `<=` cap, so holding it FIRMLY
    /// keeps the banner small, and demoting it would do the opposite of what this ordering wants.
    func test_theLadderRunsButtonsThenTitleThenDescriptionThenBanner() {
        let buttons = ModalLayout.Priority.buttonSlotHeight.rawValue
        let title = ModalLayout.Priority.titleCompressionResistance.rawValue
        let description = [
            ModalLayout.Priority.subtitleSlotFloor,
            ModalLayout.Priority.subtitleCompressionResistance,
            ModalLayout.Priority.subtitleSlotHeight
        ].map(\.rawValue)
        let banner = [
            ModalLayout.Priority.bannerNaturalAspect,
            ModalLayout.Priority.bannerFixedHeight,
            ModalLayout.Priority.bannerImageIntrinsic
        ].map(\.rawValue)

        XCTAssertGreaterThan(
            buttons, title,
            "the buttons must outrank the title — a squeezed button is a broken tap target"
        )
        XCTAssertGreaterThan(
            title, description.max() ?? 0,
            "the title must outrank every description rung"
        )
        XCTAssertGreaterThan(
            description.min() ?? 0, banner.max() ?? 0,
            "EVERY description rung must outrank EVERY banner driver — a decorative image must not "
                + "take space from the body text (was: bannerNaturalAspect 700 against the slot's 250)"
        )

        // The cap is the exception, and points the other way ON PURPOSE.
        XCTAssertGreaterThan(
            ModalLayout.Priority.bannerMaxHeight.rawValue, title,
            "`bannerMaxHeight` is a `<=` CAP: held firmly it keeps the banner SMALL and protects the "
                + "text. Demoting it with the banner's drivers would let a banner exceed the size the "
                + "caller asked for."
        )
    }

    func test_theLiveLabels_carryTheLaddersPriorities() throws {
        let modal = self.modal(dialog(title: Self.longTitle, subtitle: Self.longSubtitle))
        renderForSnapshot(modal, size: portrait)

        let title = try XCTUnwrap(modal.lbTitle)
        let subtitle = try XCTUnwrap(modal.lbSubtitle)

        // The ladder is only worth asserting if the FACTORIES actually applied it.
        XCTAssertEqual(
            title.contentCompressionResistancePriority(for: .vertical),
            ModalLayout.Priority.titleCompressionResistance
        )
        XCTAssertEqual(
            subtitle.contentCompressionResistancePriority(for: .vertical),
            ModalLayout.Priority.subtitleCompressionResistance
        )
        XCTAssertGreaterThan(
            title.contentCompressionResistancePriority(for: .vertical).rawValue,
            subtitle.contentCompressionResistancePriority(for: .vertical).rawValue
        )
    }

    /// SwiftUI's counterpart of the same ordering. The magnitudes are on an unrelated scale to
    /// UIKit's 0…1000, so only the ORDER is comparable — and only the order is claimed.
    func test_theSwiftUILayoutPriorities_putTheTitleAboveTheSubtitle() {
        XCTAssertGreaterThan(
            SwiftUIAlertModal.titleLayoutPriority, SwiftUIAlertModal.subtitleLayoutPriority,
            "the SwiftUI title must out-rank the subtitle in its VStack, mirroring the UIKit ladder"
        )
    }

    // MARK: - Rung 2: the shrink floor and the fit search

    /// **One floor, read by both renderers.** UIKit searches against
    /// `ModalLayout.titleMinimumScaleFactor`; SwiftUI hands `ModalTokens.titleMinimumScaleFactor` to
    /// `minimumScaleFactor`. A hand-transcribed second copy is exactly how this field drifted before
    /// (the token carried 0.75 while UIKit hardcoded its own), so the token is INITIALISED from the
    /// constant and this pins that it still is.
    func test_theShrinkFloor_isOneSharedNumber() {
        XCTAssertEqual(
            ModalTokens.standard.titleMinimumScaleFactor, ModalLayout.titleMinimumScaleFactor,
            "the SwiftUI token and the UIKit constant are different numbers — the two renderers would "
                + "stop shrinking at different sizes"
        )
        XCTAssertEqual(
            ModalTokens(from: GeniePresets.standardProperties()).titleMinimumScaleFactor,
            ModalLayout.titleMinimumScaleFactor,
            "deriving tokens from Properties must not disturb the shared floor"
        )
        // The value itself: the same 0.75 this label carried for years, kept so the shrink RANGE is
        // unchanged and only its trigger moved (last resort, not first).
        XCTAssertEqual(ModalLayout.titleMinimumScaleFactor, 0.75)
    }

    /// **The height floor can never make a row TALLER — the property that lets it be applied
    /// unconditionally without disturbing a single passing shape.**
    ///
    /// `minimumScaleFactor` bounds the glyph size; `ModalTokens.titleFloorHeight(for:)` bounds the
    /// SPACE, because SwiftUI will otherwise propose a row less height than even the floor-scaled text
    /// needs and let it clip (measured: 64.7pt allocated, 85.9pt needed). The safety argument is that
    /// the same string in a SMALLER font at the SAME width never needs more height — so the floor is
    /// always ≤ the nominal height and is inert whenever the row gets its ideal. The differential
    /// harness only ever measures unpressured shapes, which is why it cannot move.
    ///
    /// Asserted over the real catalog titles, not one hand-picked string.
    func test_theHeightFloor_isNeverTallerThanTheNominalText() throws {
        let tokens = ModalTokens(from: GeniePresets.standardProperties())
        let font = try XCTUnwrap(GeniePresets.standardProperties().titleFont)
        let titles = [
            Self.longTitle,
            "You missed your streak!",       // the two differential shapes whose titles wrap to 2 lines
            "Something went wrong :(",
            "Failed",                        // and the short, single-line ones
            "Access Denied",
            "[API] Confirm action"
        ]

        for title in titles {
            let floor = tokens.titleFloorHeight(for: title)
            let nominal = ModalLayout.textHeight(
                NSAttributedString(string: title, attributes: [.font: font]),
                width: tokens.contentMaxWidth
            )
            XCTAssertGreaterThan(floor, 0, "'\(title)': the floor was not computed at all")
            XCTAssertLessThanOrEqual(
                floor, nominal,
                "'\(title)': the floor (\(floor)pt) is TALLER than the text needs at full size "
                    + "(\(nominal)pt), so applying it would grow an unpressured row and move a shape "
                    + "the differential harness has green"
            )
        }
    }

    /// A property-less caller (`standard`: no `Properties`, so no content width) gets NO floor rather
    /// than a floor measured against an infinite width. Previews, demos and the example app's
    /// SwiftUI-only snapshots therefore keep exactly the layout they have.
    func test_theHeightFloor_isAbsentWhenThereIsNoContentWidth() {
        XCTAssertEqual(ModalTokens.standard.contentMaxWidth, .infinity, "premise")
        XCTAssertEqual(ModalTokens.standard.titleFloorHeight(for: Self.longTitle), 0)
    }

    /// `titleUIFont` is `titleFont`'s measurement twin: `Font` cannot be measured and cannot be
    /// converted back to a `UIFont`, so the two must be assigned from ONE source. On the derived path
    /// they are; `standard` carries a literal, and this pins that literal to the `Font` beside it.
    func test_theStandardTitleFontAndItsMeasurementTwin_agree() {
        XCTAssertEqual(ModalTokens.standard.titleUIFont.pointSize, 24)
        XCTAssertEqual(ModalTokens.standard.titleFont, .system(size: 24, weight: .bold))

        // Derived: both come from the one `Properties.titleFont`.
        let font = UIFont.boldSystemFont(ofSize: 31)
        let tokens = ModalTokens(from: GBAlertModal.Properties(titleFont: font))
        XCTAssertEqual(tokens.titleUIFont, font)
        XCTAssertEqual(tokens.titleFont, Font(font))
    }

    /// The fit search, exercised as the pure function it is — no label, no window, no layout pass.
    /// This is where "walks down, stops at the floor, never goes below it" is pinned; the hosted tests
    /// above can only observe the OUTCOME of one particular fixture.
    func test_theFitSearch_walksDownToTheFirstScaleThatFits_andStopsAtTheFloor() {
        // Fits at full size -> no shrink at all.
        XCTAssertEqual(
            ModalLayout.titleFontScale(availableHeight: 200) { scale in 100 * scale }, 1
        )
        // Needs to step down: height 200 * scale must be <= 180, i.e. scale <= 0.9.
        XCTAssertEqual(
            ModalLayout.titleFontScale(availableHeight: 180) { scale in 200 * scale }, 0.9,
            accuracy: 0.001
        )
        // Nothing fits, even at the floor: return the FLOOR, never less. That is rung 3 — the title
        // keeps every glyph and the layout gives way somewhere else.
        XCTAssertEqual(
            ModalLayout.titleFontScale(availableHeight: 10) { scale in 1000 * scale },
            ModalLayout.titleMinimumScaleFactor,
            accuracy: 0.001
        )
        // The last rung lands EXACTLY on the floor rather than on accumulated float drift.
        var visited: [CGFloat] = []
        _ = ModalLayout.titleFontScale(availableHeight: 1) { scale in
            visited.append(scale)
            return 1000
        }
        XCTAssertEqual(visited.first, 1)
        XCTAssertEqual(visited.last ?? -1, ModalLayout.titleMinimumScaleFactor, accuracy: 0.0001)
        XCTAssertTrue(
            visited.allSatisfy { $0 >= ModalLayout.titleMinimumScaleFactor - 0.0001 },
            "the search probed a scale below the floor: \(visited)"
        )
    }

    /// Scaling must come off the NOMINAL string every time. If rung 2 ever scaled the label's current
    /// (already scaled) text, repeated layout passes would compound 0.75 × 0.75 × … down to nothing.
    func test_scalingIsAlwaysRelativeToTheNominalString() throws {
        let font = try XCTUnwrap(GeniePresets.standardProperties().titleFont)
        let nominal = NSAttributedString(string: "Title", attributes: [.font: font])

        let once = GBAlertModal.scaled(nominal, by: 0.75)
        let onceAgain = GBAlertModal.scaled(nominal, by: 0.75)
        let compounded = GBAlertModal.scaled(once, by: 0.75)

        let size: (NSAttributedString) -> CGFloat = { text in
            (text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize ?? -1
        }
        XCTAssertEqual(size(once), font.pointSize * 0.75, accuracy: 0.001)
        XCTAssertEqual(size(onceAgain), size(once), accuracy: 0.001, "scaling must be idempotent")
        XCTAssertEqual(
            size(compounded), font.pointSize * 0.75 * 0.75, accuracy: 0.001,
            "premise: scaling a scaled string DOES compound — which is why `adjustTitleFontScale` "
                + "keeps `titleNominalAttributedText` and never scales the label's current text"
        )
        // Scale 1 is the identity, and cheaply so.
        XCTAssertEqual(size(GBAlertModal.scaled(nominal, by: 1)), font.pointSize, accuracy: 0.001)
    }

    /// The nominal string is captured when the title is built, and reset to full size with it — so a
    /// re-rendered dialog (`updateDialog`) never inherits the previous one's shrink.
    func test_rebuildingTheTitle_resetsItToFullSize() throws {
        let modal = self.modal(dialog(title: Self.longTitle, subtitle: Self.longSubtitle))
        // ONE host for both renders: `show` installs edge constraints with `makeConstraints`, so
        // re-hosting the same modal would stack a second set. `updateDialog` rebuilds the content in
        // place, which is the path under test anyway.
        let host = renderForSnapshot(modal, size: pressured)

        modal.updateDialog(
            holder: UIKitModalRenderer.AlertHolder.make(
                for: dialog(title: "Title", subtitle: "Short body."), resolve: { _ in }
            ),
            properties: GeniePresets.standardProperties()
        )
        host.setNeedsLayout()
        host.layoutIfNeeded()

        let title = try XCTUnwrap(modal.lbTitle)
        let font = try XCTUnwrap(GeniePresets.standardProperties().titleFont)
        XCTAssertEqual(
            title.font.pointSize, font.pointSize, accuracy: 0.01,
            "a one-line title with room to spare must render at full size — the rebuilt title "
                + "inherited the previous one's shrink"
        )
        XCTAssertEqual(modal.titleFontScaleApplied, 1, accuracy: 0.001)
        assertNoTruncation(title, "rebuilt title")
    }

    // MARK: - Helpers

    /// **Lays the label's own string out the way the label does, and requires nothing to be lost.**
    ///
    /// `NSLayoutManager` is the engine `UILabel` draws through, so feeding it the label's LIVE
    /// geometry — the `bounds` Auto Layout actually gave it, its `numberOfLines`, its `lineBreakMode`
    /// — reproduces the label's own layout decisions. Two things are then required:
    ///
    /// 1. every glyph is laid out inside the container. A line CAP (or a squeezed height) leaves the
    ///    tail unplaced, which is truncation;
    /// 2. no line fragment reports a TRUNCATED glyph range. That range is exactly the glyphs UIKit
    ///    replaces with "…", so an empty result on every line is a direct "no ellipsis was drawn".
    ///
    /// The container is given 0.5pt of height slack — the same sub-pixel tolerance the differential
    /// harness uses — because `NSLayoutManager`'s and `UILabel`'s rounding of a multi-line height can
    /// legitimately differ in the last fractional point. It is slack on the CONTAINER, not on either
    /// claim: a dropped line is tens of points, not half of one.
    private func assertNoTruncation(
        _ label: UILabel,
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let text = label.attributedText, text.length > 0 else {
            XCTFail("'\(name)' has no attributed text to check", file: file, line: line)
            return
        }
        XCTAssertGreaterThan(
            label.bounds.width, 0, "'\(name)' was never laid out", file: file, line: line
        )

        let storage = NSTextStorage(attributedString: text)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(
            size: CGSize(width: label.bounds.width, height: label.bounds.height + 0.5)
        )

        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = label.numberOfLines
        container.lineBreakMode = label.lineBreakMode
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        let laidOut = layoutManager.glyphRange(for: container)
        XCTAssertEqual(
            laidOut.length, layoutManager.numberOfGlyphs,
            "'\(name)' does not fit the box it was given: \(laidOut.length) of "
                + "\(layoutManager.numberOfGlyphs) glyphs laid out in \(label.bounds.size) with "
                + "numberOfLines \(label.numberOfLines). UILabel truncates the remainder.",
            file: file, line: line
        )

        var ellipsized: [NSRange] = []
        layoutManager.enumerateLineFragments(
            forGlyphRange: NSRange(location: 0, length: layoutManager.numberOfGlyphs)
        ) { _, _, _, glyphRange, _ in
            let truncated = layoutManager.truncatedGlyphRange(
                inLineFragmentForGlyphAt: glyphRange.location
            )
            if truncated.location != NSNotFound {
                ellipsized.append(truncated)
            }
        }
        XCTAssertTrue(
            ellipsized.isEmpty,
            "'\(name)' is ELLIPSIZED — \(ellipsized.count) line fragment(s) replace glyphs with '…' "
                + "(\(ellipsized))",
            file: file, line: line
        )
    }

    /// The SwiftUI title row's frame at an arbitrary host size.
    ///
    /// `DifferentialGeometry.swiftUIFrames` is fixed to the harness's one 390×844 host (deliberately —
    /// a landscape comparison there would measure a known resolver divergence), so the pressured
    /// reading is taken here with the same probe/sink/pump machinery at a different size. Frames are
    /// returned in host coordinates; only the HEIGHT is compared, which no normalisation affects.
    private func swiftUITitleFrame(
        _ shape: DifferentialGeometry.Shape,
        size: CGSize
    ) -> CGRect? {
        swiftUIFrame(shape, element: .title, size: size)
    }

    private func swiftUIFrame(
        _ shape: DifferentialGeometry.Shape,
        element: ModalGeometryElement,
        size: CGSize
    ) -> CGRect? {
        let sink = DifferentialGeometry.Sink()
        let root = DifferentialGeometry.ProbeHost(sink: sink) {
            SwiftUIAlertModal(
                config: shape.dialog,
                properties: shape.properties,
                tokens: ModalTokens(from: shape.properties),
                onAction: { _ in }
            )
        }
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .clear

        let window = DifferentialGeometry.makeWindow()
        window.frame = CGRect(origin: .zero, size: size)
        defer { DifferentialGeometry.teardown(window) }
        controller.view.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        DifferentialGeometry.pump(window) { sink.frames[element] != nil }
        return sink.frames[element]
    }
}
