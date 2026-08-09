import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **The date-picker card's width, measured.** `WheelDatePickerStyle` was suspected of being a
/// RIGID child — the same class of problem `BespokeBannerColumnTests` measures for `BadgeModalView`'s
/// banner artwork — and clamping it to `contentMaxWidth` was tried in
/// `SwiftUIModalRenderer+InputViews.swift` on that theory.
///
/// **Run against this bare host, the theory did not reproduce**: the card already sat exactly at its
/// 336pt cap (`contentMaxWidth` 256 + `leftMax`/`rightMax` 40 each) BOTH with and without the clamp —
/// identical numbers. On the 390pt host `DifferentialGeometry` renders at, there is
/// `390 − 2·20(margin) = 350`pt available, 14pt of slack over the cap, so the card had no reason to
/// fall short here either way. **The clamp was then reverted anyway**: tested on a real device, it
/// clipped the picker rather than reflowing it — `UIDatePicker`'s wheel columns reflow to fit
/// whatever width UIKit gives them, but SwiftUI's native `.wheel` `DatePicker` does not compress
/// below its 3-column intrinsic width, so constraining its FRAME just cut off what did not fit.
///
/// What these two tests guard, independent of that whole clamp episode: the card-width invariant
/// itself — reaches its cap when there is room, never exceeds it.
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

    /// The card should sit exactly at its cap on a host with 14pt of slack to spare — verified
    /// identical with and without the (reverted) width clamp, see the file doc.
    func test_card_reachesItsStatedCap_onAHostWithRoomToSpare() throws {
        let tokens = ModalTokens(from: properties)
        let width = try cardWidth()
        XCTAssertEqual(
            width, tokens.cardMaxWidth, accuracy: DifferentialGeometry.tolerance,
            "the date-picker card is \(width)pt where its cap is \(tokens.cardMaxWidth)pt, on a host "
                + "with 14pt to spare over that cap — padding is compressing toward its floor for no "
                + "reason the available space explains"
        )
    }

    /// **The other direction.** The card must never OVERSHOOT its cap either — a rigid child that
    /// reports a larger ideal than proposed can blow past a `.frame(maxWidth:)` ceiling from inside
    /// it, the same way `BannerSlot` could before it was made to yield (`AlertModalScaffold`'s doc).
    /// Also unaffected by the (reverted) clamp in this host — see the file doc.
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
