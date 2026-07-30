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

        // THE TITLE SURVIVED: still multi-line, still full size, still complete.
        XCTAssertEqual(title.font.pointSize, font.pointSize, "the title shrank under pressure")
        XCTAssertGreaterThan(
            title.bounds.height, font.lineHeight * 2.5,
            "the title lost lines under pressure — it is supposed to yield LAST"
        )
        assertNoTruncation(title, "title (under height pressure)")

        // AND THE SUBTITLE DID NOT TRUNCATE EITHER: it yields by SCROLLING, at full size. This is
        // the assertion that catches a `.byTruncatingTail` line-break mode coming back, which is
        // invisible whenever a label has all the room it wants.
        assertNoTruncation(subtitleLabel, "subtitle (under height pressure)")
    }

    /// The SwiftUI title's height must be the SAME under pressure as with room to spare.
    ///
    /// SwiftUI has no scrolling subtitle slot (D-7), so the "subtitle yields" half of the directive is
    /// UIKit-only and is not asserted here. What IS assertable is the half the owner emphasised — the
    /// title still lives — and it is the exact thing `fixedSize(vertical:)` buys: a proposal of less
    /// height than the title needs changes nothing about the title.
    func test_swiftUITitle_keepsItsFullHeight_underHeightPressure() throws {
        let shape = DifferentialGeometry.Shape(
            name: "directive-long-title-pressured",
            dialog: dialog(title: Self.longTitle, subtitle: Self.longSubtitle),
            properties: GeniePresets.standardProperties()
        )
        let font = try XCTUnwrap(shape.properties.titleFont)

        let roomy = try XCTUnwrap(swiftUITitleFrame(shape, size: portrait), "no title probe (roomy)")
        let squeezed = try XCTUnwrap(
            swiftUITitleFrame(shape, size: pressured), "no title probe (pressured)"
        )

        XCTAssertGreaterThan(
            roomy.height, font.lineHeight * 2.5,
            "premise: the roomy render must already be multi-line, or this comparison is vacuous"
        )
        XCTAssertEqual(
            squeezed.height, roomy.height, accuracy: DifferentialGeometry.tolerance,
            "the SwiftUI title LOST height under pressure (\(squeezed.height) against "
                + "\(roomy.height)) — a shorter Text is a truncated Text"
        )
    }

    // MARK: - (b) The ordering itself

    func test_theVerticalPriorityLadder_putsTheTitleAboveTheSubtitle() {
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
            ModalLayout.Priority.subtitleSlotHeightOverBanner.rawValue
        )
        XCTAssertGreaterThan(
            ModalLayout.Priority.subtitleSlotHeightOverBanner.rawValue,
            ModalLayout.Priority.bannerNaturalAspect.rawValue
        )
        XCTAssertGreaterThan(
            ModalLayout.Priority.bannerNaturalAspect.rawValue,
            ModalLayout.Priority.bannerFixedHeight.rawValue
        )
        XCTAssertGreaterThan(
            ModalLayout.Priority.bannerFixedHeight.rawValue,
            ModalLayout.Priority.subtitleSlotHeight.rawValue
        )
        XCTAssertGreaterThan(
            ModalLayout.Priority.subtitleSlotHeight.rawValue,
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
        DifferentialGeometry.pump(window) { sink.frames[.title] != nil }
        return sink.frames[.title]
    }
}
