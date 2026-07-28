import XCTest
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
}
