import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **Closes the ambient-font/colour gap on the subtitle's `.attributed` render path.**
///
/// `AttributedTextBridge.swiftUIRenderable` only converts a run that ALREADY carries an explicit
/// `.uiKit.font`/`.uiKit.foregroundColor` — a run with neither (the untouched portion of a
/// partially-styled subtitle, e.g. `GenieShapeCatalog.badgeUnlockSubtitle`'s "you unlocked the "
/// prefix) is left exactly as the caller wrote it: no font, no colour. `subtitleView`'s `.plain`
/// case has always applied `.font(tokens.subtitleFont.font)` + `.foregroundColor(tokens.palette
/// .subtitleText)` as the AMBIENT default a run without an explicit attribute falls back to; the
/// `.attributed` case never did, so an unstyled run inside a mixed subtitle rendered at SwiftUI's
/// system default (`.body`, ~17pt) instead of the modal's configured subtitle font — matching
/// UIKit's own equivalent gap (`ModalLayout.renderedFont`'s doc: `lbSubtitle.font` is never
/// assigned) rather than fixing it.
///
/// This test proves the fix rather than trusting the description: a token subtitle font far outside
/// the system-default range (60pt) is set, only PART of the subtitle is explicitly styled (and
/// deliberately at a much SMALLER explicit font, 10pt, so an explicit run's own styling visibly wins
/// over the ambient default rather than the two being indistinguishable), and the measured height
/// is checked against a floor only reachable if the unstyled portion actually rendered at 60pt.
// @MainActor: hosts a `UIHostingController` in a real `UIWindow`.
@MainActor
final class AttributedSubtitleFontFallbackTests: XCTestCase {

    /// "Unstyled prefix text that should inherit the token subtitle font instead of the system
    /// default. " (no attributes) + "Styled word" (explicit 10pt bold — smaller than the ambient
    /// 60pt, so it is unmistakable which portion picked up which font).
    private var mixedSubtitle: AttributedString {
        var unstyled = AttributedString(
            "Unstyled prefix text that should inherit the token subtitle font instead of the "
                + "system default. "
        )
        var styled = AttributedString("Styled word")
        styled.uiKit.font = .boldSystemFont(ofSize: 10)
        unstyled.append(styled)
        return unstyled
    }

    private func shape() -> DifferentialGeometry.Shape {
        DifferentialGeometry.Shape(
            name: "mixed-run-subtitle",
            dialog: AlertDialog(title: "Title", subtitle: nil, primary: "Okay")
                .settingAttributedSubtitle(mixedSubtitle),
            properties: GeniePresets.standardProperties()
        )
    }

    /// Premise: the fixture really is classified `.attributed` (a styled run is present), not
    /// `.plain` — otherwise this test would be proving nothing about the branch it targets.
    func test_premise_theFixtureIsClassifiedAttributed() {
        let (plain, attributed) = ModalText.split(mixedSubtitle)
        XCTAssertNil(plain, "the fixture must classify as attributed, or this test targets nothing")
        XCTAssertNotNil(attributed)
    }

    /// A token subtitle font of 60pt — line height ~72pt. A short sentence wrapped at that size in a
    /// 256pt column spans several lines; the system-default (`.body`, ~17pt) equivalent would fit in
    /// far less than half the height. 250pt is a floor comfortably above what 17pt could ever
    /// produce for this text at this width, and comfortably below what 60pt produces — it
    /// discriminates the fix from its absence rather than merely checking "some positive height".
    func test_unstyledRunInAMixedSubtitle_inheritsTheTokenFont_notSystemDefault() throws {
        var tokens = ModalTokens(from: GeniePresets.standardProperties())
        tokens.subtitleFont = .system(size: 60, weight: .regular)

        let frames = DifferentialGeometry.swiftUIFrames(shape(), tokens: tokens, size: DifferentialGeometry.host)
        let subtitle = try XCTUnwrap(frames[.subtitle], "the subtitle was never measured")

        XCTAssertGreaterThan(
            subtitle.height, 250,
            "the unstyled portion of a mixed subtitle (\(subtitle.height)pt) did not inherit the "
                + "60pt token subtitle font — it is rendering at SwiftUI's system default instead, "
                + "exactly the gap this test exists to close"
        )
    }
}

private extension AlertDialog {
    /// Test-only: `AlertDialog`'s public init takes `subtitle: AttributedString?` directly, but the
    /// String-convenience overload this file would otherwise resolve to cannot express a mixed-run
    /// value — this makes the canonical init's intent explicit at the call site.
    func settingAttributedSubtitle(_ subtitle: AttributedString) -> AlertDialog {
        var copy = self
        copy.subtitle = subtitle
        return copy
    }
}
