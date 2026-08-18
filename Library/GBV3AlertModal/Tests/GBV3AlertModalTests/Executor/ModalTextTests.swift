import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

final class ModalTextTests: XCTestCase {
    func test_nilMapsToNothing() {
        let result = UIKitModalTextAdapter.split(nil)
        XCTAssertNil(result.plain)
        XCTAssertNil(result.attributed)
    }

    func test_plainMapsToPlainString() {
        let result = UIKitModalTextAdapter.split(AttributedString("Body"))
        XCTAssertEqual(result.plain, "Body")
        XCTAssertNil(result.attributed)
    }

    func test_uikitStylesMapLosslesslyToAttributedString() throws {
        var text = AttributedString("Bold")
        text.uiKit.foregroundColor = .red
        text.uiKit.font = .boldSystemFont(ofSize: 17)

        let result = UIKitModalTextAdapter.split(text)
        let attributed = try XCTUnwrap(result.attributed)
        let attributes = attributed.attributes(at: 0, effectiveRange: nil)

        XCTAssertNil(result.plain)
        XCTAssertEqual(attributes[.foregroundColor] as? UIColor, .red)
        XCTAssertEqual((attributes[.font] as? UIFont)?.pointSize, 17)
    }

    func test_linkMapsToNSLinkAttribute() throws {
        var text = AttributedString("tap")
        text.link = URL(string: "https://x.test")

        let attributed = try XCTUnwrap(UIKitModalTextAdapter.split(text).attributed)
        XCTAssertEqual(
            attributed.attribute(.link, at: 0, effectiveRange: nil) as? URL,
            URL(string: "https://x.test")
        )
    }

    func test_markdownWithoutConcreteUIKitStylingDegradesToPlain() throws {
        let text = try AttributedString(markdown: "Just plain text, no markup")
        let result = UIKitModalTextAdapter.split(text)

        XCTAssertEqual(result.plain, "Just plain text, no markup")
        XCTAssertNil(result.attributed)
    }

    func test_swiftUIOnlyStylingDegradesToPlain() {
        var text = AttributedString("Styled")
        text.swiftUI.foregroundColor = .red
        text.swiftUI.font = .headline

        let result = UIKitModalTextAdapter.split(text)

        XCTAssertEqual(result.plain, "Styled")
        XCTAssertNil(result.attributed)
    }
}
