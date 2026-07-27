import XCTest
import SnapshotTesting
@testable import GBV3AlertModal

/// Layer C: snapshot + behavioral characterization of the shipped Genie preset shapes.
///
/// This locks down the CURRENT rendered output of `GBAlertModal` for the exact
/// property/holder combinations Genie ships, so a later refactor (extracting a pure
/// layout/config resolver) can be proven behavior-preserving against these baselines.
// @MainActor: every test builds/renders the @MainActor `GBAlertModal` (via `renderForSnapshot`)
// and some inspect its live UIKit view properties directly, so this must run on the main actor
// under Swift 6.
@MainActor
final class LayerC_SnapshotTests: XCTestCase {
    let portrait = CGSize(width: 390, height: 844)
    let landscape = CGSize(width: 844, height: 390)

    // MARK: - Standard dialog, one button

    func test_standardDialog_oneButton_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.oneButton())
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
    }

    func test_standardDialog_oneButton_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.oneButton())
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
    }

    // MARK: - Standard dialog, two buttons

    func test_standardDialog_twoButton_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.twoButton())
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
    }

    func test_standardDialog_twoButton_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.twoButton())
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
    }

    // MARK: - Standard dialog, with banner

    func test_standardDialog_withBanner_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.withBanner())
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
    }

    func test_standardDialog_withBanner_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.withBanner())
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
    }

    // MARK: - Standard dialog, with close button

    func test_standardDialog_withCloseButton_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.withCloseButton())
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
    }

    func test_standardDialog_withCloseButton_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.withCloseButton())
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
    }

    // MARK: - Popup dialog (popupProperties, two buttons)

    func test_popupDialog_twoButton_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.popupProperties(),
                                  holder: GeniePresets.twoButton())
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
    }

    func test_popupDialog_twoButton_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.popupProperties(),
                                  holder: GeniePresets.twoButton())
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
    }

    // MARK: - Rename worksheet (custom subtitle view: UITextView)

    func test_renameWorksheet_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.renameWorksheet())
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
    }

    func test_renameWorksheet_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.renameWorksheet())
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
    }

    // MARK: - Date picker worksheet (custom subtitle view: UIDatePicker)

    func test_datePickerWorksheet_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.datePickerWorksheet())
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
    }

    func test_datePickerWorksheet_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.datePickerWorksheet())
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
    }

    // MARK: - Wrapping extremes: long title

    func test_longTitle_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.longTitle())
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
    }

    func test_longTitle_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.longTitle())
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
    }

    // MARK: - Wrapping extremes: long subtitle

    func test_longSubtitle_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.longSubtitle())
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
    }

    func test_longSubtitle_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.longSubtitle())
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
    }

    /// Behavioral assert (not a snapshot): a long subtitle must overflow the fixed-height
    /// content area so `svSubtitleContainer` actually needs to scroll.
    func test_longSubtitle_scrollEngages() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.longSubtitle())
        _ = renderForSnapshot(modal, size: portrait)

        guard let sv = modal.svSubtitleContainer else {
            XCTFail("expected svSubtitleContainer to be non-nil for a subtitle holder")
            return
        }
        XCTAssertGreaterThan(sv.contentSize.height, sv.bounds.height,
                              "long subtitle must overflow so the scroll view engages")
    }

    // MARK: - Wrapping extremes: long button label

    func test_longButtonLabel_portrait() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.longButtonLabel())
        assertSnapshot(of: renderForSnapshot(modal, size: portrait), as: .image)
    }

    func test_longButtonLabel_landscape() {
        let modal = GBAlertModal(properties: GeniePresets.standardProperties(),
                                  holder: GeniePresets.longButtonLabel())
        assertSnapshot(of: renderForSnapshot(modal, size: landscape), as: .image)
    }
}
