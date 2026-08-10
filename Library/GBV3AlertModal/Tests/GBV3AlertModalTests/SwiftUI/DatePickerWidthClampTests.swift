import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **The date-picker card's width, measured — across three attempts at the same report.**
///
/// 1. Clamp the picker's frame to `contentMaxWidth` (256, production's column). Clipped it on
///    real device: SwiftUI's `.wheel` `DatePicker` does not reflow its 3-column layout the way
///    UIKit's `UIPickerView`-backed `UIDatePicker` does. Reverted.
/// 2. Widen `contentMaxWidth` alone, no picker-side constraint. No visible change on real device —
///    the picker doesn't read that number in either direction, so a wider proposal has no more
///    leverage over it than a narrower one did.
/// 3. Cap the picker's own frame at 320 WITHOUT also widening `contentMaxWidth` (still 256). Also no
///    visible change: the picker (up to 320) was still wider than the 256pt ceiling its own row was
///    proposed, so it was still the row's oversized child — capping it wider than its container
///    doesn't stop it being wider than its container.
///
/// **Current (4th) attempt: both together, same number.** `contentMaxWidth` and the picker's
/// `.frame(maxWidth:)` are now BOTH 320 (`SwiftUIModalRenderer+InputViews.swift` /
/// `GeniePresets.datePickerInputModalProperties()`), so the row's own ceiling and what the picker is
/// capped to agree — the picker can't be the oversized child if its cap matches its container's.
/// This is still an UNVERIFIED guess pending on-device confirmation; attempts 1-3 all measured
/// "successfully" in this bare host too and did not survive real-device testing, so passing here is
/// evidence, not proof.
///
/// `cardMaxWidth` is now `320 + 40 + 40 = 400`, wider than the 350pt available on the 390pt host
/// this suite renders at (`390 − 2·20` margin) — so the card is expected to clamp to the available
/// 350pt, not reach its own 400pt cap (same relationship attempt 2 produced, for the same reason:
/// it's a function of `contentMaxWidth` alone, independent of what the picker's own frame does).
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

    /// With a 400pt cap and only 350pt of host available, the card is screen-constrained, not
    /// cap-constrained — it should sit at the AVAILABLE width. If this ever reports the full 400pt
    /// cap instead, the margin stopped being applied.
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
