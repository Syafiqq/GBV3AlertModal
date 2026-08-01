import XCTest
import SwiftUI
import UIKit
@testable import GBV3AlertModal

final class ModalTextTests: XCTestCase {
    func test_nil_mapsToNothing() {
        let (p, a) = ModalText.split(nil)
        XCTAssertNil(p); XCTAssertNil(a)
    }

    func test_plain_mapsToPlainString() {
        let (p, a) = ModalText.split(AttributedString("Body"))
        XCTAssertEqual(p, "Body")
        XCTAssertNil(a)
    }

    func test_styled_mapsToAttributed_losslessForWhitelistedKeys() throws {
        var s = AttributedString("Bold")
        s.foregroundColor = UIColor.red
        s.font = .boldSystemFont(ofSize: 17)
        let (p, a) = ModalText.split(s)
        XCTAssertNil(p)
        let ns = try XCTUnwrap(a)
        XCTAssertEqual(ns.string, "Bold")
        let attrs = ns.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual(attrs[.foregroundColor] as? UIColor, .red)
        XCTAssertEqual((attrs[.font] as? UIFont)?.pointSize, 17)
        XCTAssertTrue((attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }

    func test_link_bridgesToNSLinkAttribute() {
        var s = AttributedString("tap")
        s.link = URL(string: "https://x.test")
        let ns = try! XCTUnwrap(ModalText.split(s).attributed)
        XCTAssertEqual(ns.attribute(.link, at: 0, effectiveRange: nil) as? URL,
                       URL(string: "https://x.test"))
    }

    func test_markdownWithNoMarkup_mapsToPlain() {
        let s = try! AttributedString(markdown: "Just plain text, no markup")
        let (p, a) = ModalText.split(s)
        XCTAssertEqual(p, "Just plain text, no markup")
        XCTAssertNil(a)
    }

    /// **This used to be `testSwiftUIScopedColorStaysPlain`, and colour no longer does.**
    ///
    /// The old claim — a SwiftUI-scoped attribute must not flip the string onto the attributed path,
    /// because it would bridge under a `SwiftUI.*` key `UILabel` ignores and render unstyled — was
    /// right about the mechanism and is now handled better: `split` CONVERTS SwiftUI colour onto
    /// UIKit's scope, so it renders instead of being discarded
    /// (`ModalTextSwiftUIScopeTests.test_ambientForegroundColor_reachesUIKitAsARenderedAttribute`).
    ///
    /// FONT is the case where the old reasoning still holds exactly, because there is no
    /// `Font -> UIFont` direction to convert through. So the "stays plain" contract is kept here,
    /// on the attribute that still needs it.
    func testSwiftUIScopedFontStaysPlain() {
        var text = AttributedString("Hello")
        text.swiftUI.font = .largeTitle
        let (plain, attributed) = ModalText.split(text)
        XCTAssertEqual(plain, "Hello")
        XCTAssertNil(attributed)
    }
}

// MARK: - SwiftUI-scoped colour is converted, not discarded

/// The ambient form (`a.foregroundColor = .red`) binds to SwiftUI's attribute scope even with no
/// SwiftUI import in the file, and bridges to a `SwiftUI.ForegroundColor` key `UILabel` ignores —
/// so the text used to render completely unstyled. `split` now re-scopes it onto UIKit.
final class ModalTextSwiftUIScopeTests: XCTestCase {

    func test_ambientForegroundColor_reachesUIKitAsARenderedAttribute() throws {
        var text = AttributedString("Styled")
        text.foregroundColor = .red        // ambient == SwiftUI scope, the trap

        let (plain, attributed) = ModalText.split(text)

        XCTAssertNil(plain, "a coloured run must not degrade to plain now that it can be converted")
        let attributedString = try XCTUnwrap(attributed)
        let colour = attributedString.attribute(
            .foregroundColor, at: 0, effectiveRange: nil
        ) as? UIColor
        XCTAssertNotNil(
            colour,
            "the bridged string carries no NSColor — the SwiftUI-scoped colour was not converted, "
                + "so UILabel would draw this text with no styling at all"
        )
    }

    /// An explicit `.uiKit.` scope is a stronger statement than the ambient one and must win.
    func test_anExplicitUIKitColour_isNotOverwritten() throws {
        var text = AttributedString("Styled")
        text.uiKit.foregroundColor = .green
        text.swiftUI.foregroundColor = .red

        let (_, attributed) = ModalText.split(text)
        let colour = try XCTUnwrap(
            try XCTUnwrap(attributed).attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        )
        var green: CGFloat = 0
        colour.getRed(nil, green: &green, blue: nil, alpha: nil)
        XCTAssertGreaterThan(green, 0.5, "the explicit UIKit colour was overwritten by the ambient one")
    }

    /// **The stated asymmetry.** There is no `Font -> UIFont` direction, so a SwiftUI-scoped font
    /// cannot be converted and still degrades to plain — where the resolver's default styling
    /// applies, which beats an attributed string UIKit would draw unstyled.
    func test_aSwiftUIScopedFont_stillDegradesToPlain() {
        var text = AttributedString("Sized")
        text.font = .largeTitle          // ambient == SwiftUI scope, and unconvertible

        let (plain, attributed) = ModalText.split(text)

        XCTAssertEqual(plain, "Sized")
        XCTAssertNil(attributed)
    }
}

