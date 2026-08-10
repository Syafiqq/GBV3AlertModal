import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **The date-picker card's width, measured — across an exhausted list of containment attempts.**
///
/// `date-picker-worksheet`'s buttons render flush to the card edge instead of padded, confirmed
/// (real device, controlled placeholder swap) to be caused by the `DatePicker` — its own width
/// propagates to the whole `AlertModalScaffold` row (title+picker+buttons, one `VStack`), which
/// `buttonsMatchParent` faithfully copies onto the buttons. See `DatePickerModalView`'s own doc for
/// the full account: THREE pure-SwiftUI containment techniques (`.frame(maxWidth:)`, an exact
/// `.frame(width:)`, an `.overlay()`-based base-view override) were each tried on real device and
/// none constrained it. The one technique that would reliably work — a hand-built UIKit-view
/// bridge — is blocked by this library's enforced `SwiftUIPurityTests` allow-list, a real
/// architectural decision, not a bug to route around here.
///
/// `contentProperty` is NOT overridden for this preset — widening it (to match a picker-side frame
/// cap) was tried and, like everything else, had no observable effect, so it stays at `standard`'s
/// real 256pt production column: `cardMaxWidth` is `256 + 40 + 40 = 336pt`. On the 390pt host
/// `DifferentialGeometry` renders at, there is `390 − 2·20(margin) = 350`pt available — 14pt of
/// slack over that cap, so (as measured before any of this episode started) the card reaching its
/// cap here was never in question. What these two tests guard is that CARD-LEVEL invariant only —
/// they say nothing about the button-padding defect, which lives one level lower than `.card` probes.
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

    /// The card should sit exactly at its cap on a host with 14pt of slack to spare.
    func test_card_reachesItsStatedCap_onAHostWithRoomToSpare() throws {
        let tokens = ModalTokens(from: properties)
        let width = try cardWidth()
        XCTAssertEqual(
            width, tokens.cardMaxWidth, accuracy: DifferentialGeometry.tolerance,
            "the date-picker card is \(width)pt where its cap is \(tokens.cardMaxWidth)pt, on a host "
                + "with 14pt to spare over that cap"
        )
    }

    /// **The other direction.** The card must never OVERSHOOT its cap either — a rigid child that
    /// reports a larger ideal than proposed can blow past a `.frame(maxWidth:)` ceiling from inside
    /// it, the same way `BannerSlot` could before it was made to yield (`AlertModalScaffold`'s doc).
    func test_card_neverExceedsItsStatedCap() throws {
        let tokens = ModalTokens(from: properties)
        let width = try cardWidth()
        XCTAssertLessThanOrEqual(
            width, tokens.cardMaxWidth + DifferentialGeometry.tolerance,
            "the date-picker card (\(width)pt) exceeded its stated cap (\(tokens.cardMaxWidth)pt)"
        )
    }
}
