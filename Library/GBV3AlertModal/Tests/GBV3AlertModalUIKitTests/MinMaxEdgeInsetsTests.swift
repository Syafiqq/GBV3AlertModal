@testable import GBV3AlertModalCore
@testable import GBV3AlertModalUIKit
import XCTest

final class MinMaxEdgeInsetsTests: XCTestCase {
    func testInitializerAndEqualityPreserveEveryEdge() {
        let insets = MinMaxEdgeInsets(
            top: (1, 2),
            left: (3, 4),
            bottom: (5, 6),
            right: (7, 8)
        )

        XCTAssertEqual(
            insets,
            MinMaxEdgeInsets(
                top: (1, 2),
                left: (3, 4),
                bottom: (5, 6),
                right: (7, 8)
            )
        )
        XCTAssertEqual(insets.copy(left: (30, 40)).leftMin, 30)
        XCTAssertEqual(insets.copy(left: (30, 40)).leftMax, 40)
        XCTAssertEqual(insets.copy(left: (30, 40)).topMin, 1)
    }

    func testDeprecatedUIKitSpellingRemainsSourceCompatible() {
        let legacy: UIMinMaxEdgeInsets = .init(top: (10, 20))
        let neutral: MinMaxEdgeInsets = legacy

        XCTAssertEqual(neutral.topMin, 10)
        XCTAssertEqual(neutral.topMax, 20)
    }
}
