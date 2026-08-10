import XCTest
import UIKit
@testable import GBV3AlertModal

/// Unit tests for `ModalKeyboardAvoider`, the pure extraction of the geometry math that used to
/// live inline in `GBAlertModal.adjustDialogPosition(_:)`. Every expected number in this file is
/// derived by hand-evaluating the ORIGINAL formula (see `GBAlertModal.swift`,
/// `// MARK: - KEYBOARD` extension) against the fixture inputs below — nothing is guessed.
///
/// Branch selection mirrors `adjustDialogPosition`'s guard:
/// `keyboardFrame.minY > (screenMaxY - keyboardFrame.maxY)` ("keyboard has more space above it
/// than below it") selects the `keyboardHasMoreSpaceAbove == true` branch, which anchors on
/// `svMainActionContainer ?? svSubtitleContainer ?? lbTitle` and computes:
///   `difference = keyboardFrame.minY - anchorFrame.maxY - emptySpace` (then `+= currentTransformY`,
///   applied only when `difference < 0`).
/// The `false` branch anchors on `lbTitle ?? svSubtitleContainer ?? svMainActionContainer` and
/// computes:
///   `difference = keyboardFrame.maxY - anchorFrame.minY + emptySpace` (then `+= currentTransformY`,
///   applied only when `difference > 0`).
final class ModalKeyboardAvoiderTests: XCTestCase {
    private let avoider = ModalKeyboardAvoider()
    private let emptySpace: CGFloat = 48 // kEmptySpaceForKeyboardExtension in GBAlertModal.swift

    // MARK: - keyboardHasMoreSpaceAbove (branch selector)

    func test_keyboardHasMoreSpaceAbove_trueForTypicalDockedKeyboard() {
        // Docked keyboard: keyboardFrame.maxY == screenMaxY, so space-below is 0 and
        // space-above (minY) is whatever is left above it — always > 0.
        let screenMaxY: CGFloat = 844
        let keyboardFrame = CGRect(x: 0, y: 553, width: 390, height: 291)
        XCTAssertTrue(avoider.keyboardHasMoreSpaceAbove(keyboardFrame: keyboardFrame, screenMaxY: screenMaxY))
    }

    func test_keyboardHasMoreSpaceAbove_falseWhenKeyboardFloatsNearTop() {
        let screenMaxY: CGFloat = 800
        let keyboardFrame = CGRect(x: 0, y: 50, width: 300, height: 650) // space above 50, below 100
        XCTAssertFalse(avoider.keyboardHasMoreSpaceAbove(keyboardFrame: keyboardFrame, screenMaxY: screenMaxY))
    }

    // MARK: - Branch 1 (keyboardHasMoreSpaceAbove == true)

    func test_offset_keyboardEntirelyBelowDialog_returnsNilNoAdjustment() {
        // Keyboard docked at the bottom, well clear of the anchor view (350pt gap vs the 48pt
        // emptySpace threshold): difference = 553 - 450 - 48 = 55, which fails `difference < 0`,
        // so the ORIGINAL code's guard bails without touching the transform at all. Starting
        // from a fresh (identity) transform, that is behaviorally "offset 0" — the dialog does
        // not move.
        let screenMaxY: CGFloat = 844
        let keyboardFrame = CGRect(x: 0, y: 553, width: 390, height: 291) // minY 553, maxY 844
        let anchorFrame = CGRect(x: 20, y: 400, width: 350, height: 50) // maxY 450

        let hasMoreSpaceAbove = avoider.keyboardHasMoreSpaceAbove(keyboardFrame: keyboardFrame, screenMaxY: screenMaxY)
        XCTAssertTrue(hasMoreSpaceAbove)

        let result = avoider.offset(
                keyboardHasMoreSpaceAbove: hasMoreSpaceAbove,
                keyboardFrame: keyboardFrame,
                anchorFrame: anchorFrame,
                responderFrame: nil,
                currentTransformY: 0,
                screenMaxY: screenMaxY,
                emptySpace: emptySpace
        )
        XCTAssertNil(result)
    }

    func test_offset_keyboardOverlappingDialogBottom_equalsOverlapPlusEmptySpace() {
        // anchorFrame.maxY (650) sits 30pt below keyboardFrame.minY (620): a 30pt overlap.
        // Original formula: difference = keyboardFrame.minY - anchorFrame.maxY - emptySpace
        //                              = 620 - 650 - 48 = -78
        //                              = -(overlap) - emptySpace = -(30 + 48) = -78
        let screenMaxY: CGFloat = 800
        let anchorFrame = CGRect(x: 0, y: 600, width: 300, height: 50) // maxY 650
        let keyboardFrame = CGRect(x: 0, y: 620, width: 300, height: 180) // minY 620, maxY 800

        let hasMoreSpaceAbove = avoider.keyboardHasMoreSpaceAbove(keyboardFrame: keyboardFrame, screenMaxY: screenMaxY)
        XCTAssertTrue(hasMoreSpaceAbove)

        let overlap = anchorFrame.maxY - keyboardFrame.minY
        XCTAssertEqual(overlap, 30)

        let result = avoider.offset(
                keyboardHasMoreSpaceAbove: hasMoreSpaceAbove,
                keyboardFrame: keyboardFrame,
                anchorFrame: anchorFrame,
                responderFrame: nil,
                currentTransformY: 0,
                screenMaxY: screenMaxY,
                emptySpace: emptySpace
        )
        XCTAssertEqual(result, -(overlap + emptySpace))
        XCTAssertEqual(result, -78)
    }

    func test_offset_accumulatesExistingTransform() {
        // Same fixture as above, but the dialog was already shifted up by 20pt from a previous
        // keyboard event: `difference += currentTransformY` -> -78 + (-20) = -98.
        let screenMaxY: CGFloat = 800
        let anchorFrame = CGRect(x: 0, y: 600, width: 300, height: 50)
        let keyboardFrame = CGRect(x: 0, y: 620, width: 300, height: 180)

        let result = avoider.offset(
                keyboardHasMoreSpaceAbove: true,
                keyboardFrame: keyboardFrame,
                anchorFrame: anchorFrame,
                responderFrame: nil,
                currentTransformY: -20,
                screenMaxY: screenMaxY,
                emptySpace: emptySpace
        )
        XCTAssertEqual(result, -98)
    }

    func test_offset_keyboardCoveringMoreThanDialog_clampsToResponderTop() {
        // The keyboard covers almost the whole screen (minY 100), so the naive difference
        // (100 - 650 - 48 = -598) would push the first responder off the top of the screen.
        // Original formula clamps: `if difference + responderFrame.minY < 0 { difference =
        // -responderFrame.minY }` -> -598 + 120 = -478 < 0, so difference becomes -120.
        let screenMaxY: CGFloat = 800
        let anchorFrame = CGRect(x: 0, y: 600, width: 300, height: 50) // maxY 650
        let keyboardFrame = CGRect(x: 0, y: 100, width: 300, height: 700) // minY 100, maxY 800
        let responderFrame = CGRect(x: 0, y: 120, width: 300, height: 40) // minY 120

        let hasMoreSpaceAbove = avoider.keyboardHasMoreSpaceAbove(keyboardFrame: keyboardFrame, screenMaxY: screenMaxY)
        XCTAssertTrue(hasMoreSpaceAbove)

        let result = avoider.offset(
                keyboardHasMoreSpaceAbove: hasMoreSpaceAbove,
                keyboardFrame: keyboardFrame,
                anchorFrame: anchorFrame,
                responderFrame: responderFrame,
                currentTransformY: 0,
                screenMaxY: screenMaxY,
                emptySpace: emptySpace
        )
        XCTAssertEqual(result, -responderFrame.minY)
        XCTAssertEqual(result, -120)
    }

    // MARK: - Branch 2 (keyboardHasMoreSpaceAbove == false)

    func test_offset_lowerBranch_belowDialog_returnsNilNoAdjustment() {
        // Floating keyboard well above the anchor: difference = 150 - 200 + 48 = -2, fails
        // `difference > 0`, so the original guard bails.
        let screenMaxY: CGFloat = 800
        let keyboardFrame = CGRect(x: 0, y: 100, width: 300, height: 50) // minY 100, maxY 150
        let anchorFrame = CGRect(x: 0, y: 200, width: 300, height: 40) // minY 200

        let hasMoreSpaceAbove = avoider.keyboardHasMoreSpaceAbove(keyboardFrame: keyboardFrame, screenMaxY: screenMaxY)
        XCTAssertFalse(hasMoreSpaceAbove)

        let result = avoider.offset(
                keyboardHasMoreSpaceAbove: hasMoreSpaceAbove,
                keyboardFrame: keyboardFrame,
                anchorFrame: anchorFrame,
                responderFrame: nil,
                currentTransformY: 0,
                screenMaxY: screenMaxY,
                emptySpace: emptySpace
        )
        XCTAssertNil(result)
    }

    func test_offset_lowerBranch_overlapping_equalsOverlapPlusEmptySpace() {
        // Original formula: difference = keyboardFrame.maxY - anchorFrame.minY + emptySpace
        //                              = 150 - 130 + 48 = 68
        let screenMaxY: CGFloat = 800
        let keyboardFrame = CGRect(x: 0, y: 50, width: 300, height: 100) // minY 50, maxY 150
        let anchorFrame = CGRect(x: 0, y: 130, width: 300, height: 40) // minY 130

        let hasMoreSpaceAbove = avoider.keyboardHasMoreSpaceAbove(keyboardFrame: keyboardFrame, screenMaxY: screenMaxY)
        XCTAssertFalse(hasMoreSpaceAbove)

        let result = avoider.offset(
                keyboardHasMoreSpaceAbove: hasMoreSpaceAbove,
                keyboardFrame: keyboardFrame,
                anchorFrame: anchorFrame,
                responderFrame: nil,
                currentTransformY: 0,
                screenMaxY: screenMaxY,
                emptySpace: emptySpace
        )
        XCTAssertEqual(result, 68)
    }

    func test_offset_lowerBranch_coveringMoreThanDialog_clampsToResponderBottom() {
        // difference = 700 - 130 + 48 = 618; responderFrame.maxY 640 pushes the sum (1258) past
        // screenMaxY (800), so it clamps: `difference = screenMaxY - responderFrame.maxY`
        //                                             = 800 - 640 = 160
        let screenMaxY: CGFloat = 800
        let keyboardFrame = CGRect(x: 0, y: 50, width: 300, height: 650) // minY 50, maxY 700
        let anchorFrame = CGRect(x: 0, y: 130, width: 300, height: 40) // minY 130
        let responderFrame = CGRect(x: 0, y: 600, width: 300, height: 40) // maxY 640

        let hasMoreSpaceAbove = avoider.keyboardHasMoreSpaceAbove(keyboardFrame: keyboardFrame, screenMaxY: screenMaxY)
        XCTAssertFalse(hasMoreSpaceAbove)

        let result = avoider.offset(
                keyboardHasMoreSpaceAbove: hasMoreSpaceAbove,
                keyboardFrame: keyboardFrame,
                anchorFrame: anchorFrame,
                responderFrame: responderFrame,
                currentTransformY: 0,
                screenMaxY: screenMaxY,
                emptySpace: emptySpace
        )
        XCTAssertEqual(result, screenMaxY - responderFrame.maxY)
        XCTAssertEqual(result, 160)
    }
}
