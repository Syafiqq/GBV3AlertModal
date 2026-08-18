@testable import GBV3AlertModalCore
@testable import GBV3AlertModalUIKit
import XCTest
import UIKit

/// Unit tests for `ModalLayout`, the pure extraction of the constraint arithmetic that used to
/// live inline in `GBAlertModal`'s `adjust*` methods (now `GBAlertModal+Layout.swift`). Every
/// expected number here is derived by hand-evaluating the ORIGINAL formulas — nothing is guessed.
final class ModalLayoutTests: XCTestCase {
    // MARK: - resolveContentWidths
    //
    // Mirrors the original `resolvedContentWidths()` switch over `ResolvedModal.WidthResolution`
    // (see `GBAlertModal.swift` pre-Task-6 / `GBAlertModal+Layout.swift` post-Task-6):
    //   .flexible            -> (nil, nil)
    //   .fixed(x)            -> (x, nil)
    //   .max(y)              -> (nil, y)
    //   .fixedAndMax(f, m)   -> (f, m)

    func test_resolveContentWidths_flexible_returnsNilNil() {
        let result = ModalLayout.resolveContentWidths(.flexible)
        XCTAssertNil(result.fixed)
        XCTAssertNil(result.max)
    }

    func test_resolveContentWidths_fixed_returnsFixedOnly() {
        let result = ModalLayout.resolveContentWidths(.fixed(320))
        XCTAssertEqual(result.fixed, 320)
        XCTAssertNil(result.max)
    }

    func test_resolveContentWidths_max_returnsMaxOnly() {
        let result = ModalLayout.resolveContentWidths(.max(480))
        XCTAssertNil(result.fixed)
        XCTAssertEqual(result.max, 480)
    }

    func test_resolveContentWidths_fixedAndMax_returnsBoth() {
        let result = ModalLayout.resolveContentWidths(.fixedAndMax(fixed: 320, max: 480))
        XCTAssertEqual(result.fixed, 320)
        XCTAssertEqual(result.max, 480)
    }

    // MARK: - resolveContainerOffsets
    //
    // Mirrors `adjustVwContainerConstraint`'s four `.offset(...)` calls:
    //   top:      properties?.margin?.top ?? .zero
    //   leading:  properties?.margin?.left ?? .zero
    //   bottom:   -(properties?.margin?.bottom ?? .zero)
    //   trailing: -(properties?.margin?.right ?? .zero)

    func test_resolveContainerOffsets_nilMargin_returnsAllZero() {
        let result = ModalLayout.resolveContainerOffsets(margin: nil)
        XCTAssertEqual(result.top, 0)
        XCTAssertEqual(result.leading, 0)
        XCTAssertEqual(result.bottom, 0)
        XCTAssertEqual(result.trailing, 0)
    }

    func test_resolveContainerOffsets_populatedMargin_topLeadingPositiveBottomTrailingNegated() {
        let margin = UIEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        let result = ModalLayout.resolveContainerOffsets(margin: margin)
        XCTAssertEqual(result.top, 10)
        XCTAssertEqual(result.leading, 20)
        XCTAssertEqual(result.bottom, -30)
        XCTAssertEqual(result.trailing, -40)
    }

    // MARK: - resolveContentPadding
    //
    // Mirrors `adjustSvContentContainerConstraint`'s eight `.offset(...)` calls, reading from
    // `UIMinMaxEdgeInsets` (top/left/bottom/right, each with Min/Max):
    //   topMin: padding?.topMin ?? .zero          topMax: padding?.topMax ?? .zero
    //   leadingMin: padding?.leftMin ?? .zero     leadingMax: padding?.leftMax ?? .zero
    //   bottomMin: -(padding?.bottomMin ?? .zero) bottomMax: -(padding?.bottomMax ?? .zero)
    //   trailingMin: -(padding?.rightMin ?? .zero) trailingMax: -(padding?.rightMax ?? .zero)

    func test_resolveContentPadding_nilPadding_returnsAllZero() {
        let result = ModalLayout.resolveContentPadding(padding: nil)
        XCTAssertEqual(result.topMin, 0)
        XCTAssertEqual(result.topMax, 0)
        XCTAssertEqual(result.leadingMin, 0)
        XCTAssertEqual(result.leadingMax, 0)
        XCTAssertEqual(result.bottomMin, 0)
        XCTAssertEqual(result.bottomMax, 0)
        XCTAssertEqual(result.trailingMin, 0)
        XCTAssertEqual(result.trailingMax, 0)
    }

    func test_resolveContentPadding_populatedPadding_minMaxPositiveBottomTrailingNegated() {
        let padding = UIMinMaxEdgeInsets(
                top: (1, 2),
                left: (3, 4),
                bottom: (5, 6),
                right: (7, 8)
        )
        let result = ModalLayout.resolveContentPadding(padding: padding)
        XCTAssertEqual(result.topMin, 1)
        XCTAssertEqual(result.topMax, 2)
        XCTAssertEqual(result.leadingMin, 3)
        XCTAssertEqual(result.leadingMax, 4)
        XCTAssertEqual(result.bottomMin, -5)
        XCTAssertEqual(result.bottomMax, -6)
        XCTAssertEqual(result.trailingMin, -7)
        XCTAssertEqual(result.trailingMax, -8)
    }

    // MARK: - bannerHeightMultiplier
    //
    // Used by `GBAlertModal+ViewGraph.swift`'s `installConstraints` for the `bannerRatio == nil`
    // path: `height = width * multiplier`, where `multiplier = imageSize.height / imageSize.width`.

    func test_bannerHeightMultiplier_16x9_returns0_5625() {
        let result = ModalLayout.bannerHeightMultiplier(imageSize: CGSize(width: 160, height: 90))
        XCTAssertEqual(result ?? -1, 0.5625, accuracy: 0.0001)
    }

    func test_bannerHeightMultiplier_9x16_returns1_7778() {
        let result = ModalLayout.bannerHeightMultiplier(imageSize: CGSize(width: 90, height: 160))
        XCTAssertEqual(result ?? -1, 1.7778, accuracy: 0.0001)
    }

    func test_bannerHeightMultiplier_square_returns1_0() {
        let result = ModalLayout.bannerHeightMultiplier(imageSize: CGSize(width: 100, height: 100))
        XCTAssertEqual(result ?? -1, 1.0, accuracy: 0.0001)
    }

    func test_bannerHeightMultiplier_zeroWidth_returnsNil() {
        let result = ModalLayout.bannerHeightMultiplier(imageSize: CGSize(width: 0, height: 100))
        XCTAssertNil(result)
    }

    func test_bannerHeightMultiplier_zeroHeight_returnsNil() {
        let result = ModalLayout.bannerHeightMultiplier(imageSize: CGSize(width: 100, height: 0))
        XCTAssertNil(result)
    }

    func test_bannerHeightMultiplier_zeroSize_returnsNil() {
        let result = ModalLayout.bannerHeightMultiplier(imageSize: .zero)
        XCTAssertNil(result)
    }

    func test_bannerHeightMultiplier_negativeSize_returnsNil() {
        let result = ModalLayout.bannerHeightMultiplier(imageSize: CGSize(width: -10, height: 10))
        XCTAssertNil(result)
    }
}
