import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// `Color(hex:)` is deliberately `internal` (see the doc comment on the extension in
/// `ModalTokens.swift`): it's an extension on a type this library doesn't own, and making it
/// `public` would collide with the equally-common private `Color(hex:)` helper apps that link
/// this library are likely to already have. This test exercises it via `@testable import`,
/// which is why it lives here rather than in the example app's test target.
final class ModalTokensTests: XCTestCase {
    func test_hex_color_decodes_rgb_channels() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color(hex: 0x038CD5)).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0x03 / 255, accuracy: 0.01)
        XCTAssertEqual(g, 0x8C / 255, accuracy: 0.01)
        XCTAssertEqual(b, 0xD5 / 255, accuracy: 0.01)
    }
}
