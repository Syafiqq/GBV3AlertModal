import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **The date-picker card's width, measured — across two different fixes for the same report.**
///
/// Attempt 1: `WheelDatePickerStyle` was suspected of being a RIGID child — the same class of
/// problem `BespokeBannerColumnTests` measures for `BadgeModalView`'s banner artwork — so it was
/// clamped to `contentMaxWidth` (256, the production column). Run against this bare host, the
/// theory did not reproduce: the card sat exactly at its 336pt cap BOTH with and without the clamp.
/// **Reverted anyway**: tested on a real device, the clamp CLIPPED the picker rather than reflowing
/// it — `UIDatePicker`'s wheel columns reflow to fit whatever width UIKit gives them, but SwiftUI's
/// native `.wheel` `DatePicker` does not compress below its 3-column intrinsic width, so
/// constraining its FRAME just cut off what did not fit.
///
/// Attempt 2 (current): widen the CONTENT column itself instead of constraining the picker —
/// `GeniePresets.datePickerInputModalProperties()` now states `contentMaxWidth: 320` (a starting
/// guess pending on-device confirmation, not yet a citation-backed production number). That pushes
/// `cardMaxWidth` to `320 + 40 + 40 = 400`, which EXCEEDS the 350pt available on the 390pt host this
/// suite renders at (`390 − 2·20(margin)`) — so the card is now expected to clamp to the available
/// 350pt, not reach its own stated 400pt cap. That is a different invariant than attempt 1 tested,
/// and the two tests below were rewritten to match it rather than left asserting the old numbers.
@MainActor
final class DatePickerWidthClampTests: XCTestCase {
    private var properties: ModalProperties { GeniePresets.datePickerInputModalProperties() }

    /// Hosts `DatePickerModalView` and returns the CARD frame its scaffold probed — same harness
    /// `BespokeBannerColumnTests.cardWidth(banner:)` uses for `BadgeModalView`.
    private func cardWidth() throws -> CGFloat {
        let sink = DifferentialGeometry.Sink()
        let root = DifferentialGeometry.ProbeHost(sink: sink) {
            DatePickerModalView(
                descriptor: DatePickerDialog(
                    title: "Pick a date",
                    initialDate: Date(timeIntervalSince1970: 1_700_000_000),
                    primary: "OK"
                ),
                tokens: ModalTokens(from: properties),
                resolve: { _ in }
            )
        }
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .clear
        controller.view.frame = CGRect(origin: .zero, size: DifferentialGeometry.host)

        let window = DifferentialGeometry.makeWindow(size: DifferentialGeometry.host)
        defer { DifferentialGeometry.teardown(window) }
        window.rootViewController = controller
        DifferentialGeometry.pump(window) { sink.frames[.card] != nil }

        return try XCTUnwrap(
            sink.frames[.card],
            "the date-picker scaffold published no card frame — nothing was measured"
        ).width
    }

    /// With a 400pt cap and only 350pt of host available (`390 − 2·20` margin), the card is
    /// screen-constrained now, not cap-constrained — it should sit at the AVAILABLE width, not the
    /// stated cap. If this ever reports the full 400pt cap instead, the margin stopped being applied.
    func test_card_clampsToTheAvailableHostWidth_notItsOwnCap() throws {
        let tokens = ModalTokens(from: properties)
        let available = DifferentialGeometry.host.width - tokens.cardMarginH * 2
        let width = try cardWidth()
        XCTAssertEqual(
            width, available, accuracy: DifferentialGeometry.tolerance,
            "the date-picker card is \(width)pt where the host only has \(available)pt available "
                + "(cap is \(tokens.cardMaxWidth)pt, wider than the host can give it) — expected the "
                + "margin to clamp it to the available width"
        )
    }

    /// **The other direction.** The card must never exceed its OWN stated cap regardless of how much
    /// host room there is — a rigid child that reports a larger ideal than proposed can blow past a
    /// `.frame(maxWidth:)` ceiling from inside it, the same way `BannerSlot` could before it was made
    /// to yield (`AlertModalScaffold`'s doc).
    func test_card_neverExceedsItsStatedCap() throws {
        let tokens = ModalTokens(from: properties)
        let width = try cardWidth()
        XCTAssertLessThanOrEqual(
            width, tokens.cardMaxWidth + DifferentialGeometry.tolerance,
            "the date-picker card (\(width)pt) exceeded its stated cap (\(tokens.cardMaxWidth)pt) — "
                + "the wheel picker is overflowing its proposed width without the card growing to match"
        )
    }
}
