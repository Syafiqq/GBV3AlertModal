import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **The badge card's banner column — the one bespoke geometry the differential gate cannot see.**
///
/// `BadgeModalView` builds its own `AlertModalScaffold`, so `DifferentialGeometry` excludes it: the
/// gate measures `SwiftUIAlertModal` against `GBAlertModal`, and this view is neither. That
/// exclusion is why the missing `bannerArtworkSize:` argument survived as a COMMENT for as long as
/// it did — nothing measured the consequence.
///
/// This is not a second differential harness and does not pretend to be one. It hosts the SwiftUI
/// view alone and asserts the one fact the omission removed: **artwork wider than the content column
/// widens the card.** Its UIKit counterpart does that (`ivBanner`'s 750 compression resistance
/// outranks `svContentContainer`'s `width == fixedWidth` at `.medium`, 500 — the mechanism
/// `BannerGeometryTruthTests` pins against measured Auto Layout output, on the standard path that
/// shares the same `vwBanner`/`ivBanner` constraints).
///
/// **Both directions are asserted, and the second one is the load-bearing half.** A test that only
/// checked "wide artwork widens the card" would also pass if the card had simply grown for everyone,
/// which would be a regression on every badge shape that ships. So the narrow-artwork case is pinned
/// at exactly the unwidened cap in the same run.
///
/// Uses the test target's own `gb_test_banner_wide` (320x190pt) — the same asset the differential
/// `banner-wide` shape uses, and the same regime eight of the app's nine real banner assets are in.
/// `TestBundleAssetTests` gates that it resolves at all; the premise below re-checks it here, because
/// an unresolvable asset makes `pointSize` `.zero` and turns every assertion in this file vacuous.
// @MainActor: hosts a `UIHostingController` in a real `UIWindow`.
@MainActor
final class BespokeBannerColumnTests: XCTestCase {

    /// The `banner-wide` regime: a 256pt content column, 20/32 min/max padding, ratio 320:190,
    /// cap 256 — so the artwork's 320pt demand survives the cap and reaches the column.
    private var properties: GBAlertModal.Properties {
        GeniePresets.popupProperties().copy(bannerRatio: 320.0 / 190.0, bannerMaxHeight: 256)
    }

    private func badge(banner: ModalImage?) -> BadgeDialog {
        BadgeDialog(
            banner: banner,
            title: AttributedString("Congratulations!"),
            subtitle: AttributedString("You unlocked new badges."),
            primary: "View my badges"
        )
    }

    /// Hosts `BadgeModalView` and returns the CARD frame its scaffold probed.
    ///
    /// Reuses `DifferentialGeometry`'s hosting machinery rather than growing a second copy: the
    /// window/teardown pairing there exists because a host left alive across a test boundary once
    /// became a zombie that crashed the next render, and `pump` is what gives SwiftUI's preference
    /// delivery a chance to land.
    private func cardWidth(banner: ModalImage?) throws -> CGFloat {
        let sink = DifferentialGeometry.Sink()
        let root = DifferentialGeometry.ProbeHost(sink: sink) {
            BadgeModalView(
                descriptor: badge(banner: banner),
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
            "the badge scaffold published no card frame — nothing was measured, so no verdict here "
                + "means anything"
        ).width
    }

    /// The premise: the wide asset resolves, and it really is wider than the column. Without both,
    /// `pointSize` is `.zero` (or the artwork simply fits) and the comparison below is between two
    /// identical cards for a reason that has nothing to do with the fix.
    func test_premise_theWideAssetResolvesAndExceedsTheColumn() throws {
        let artwork = ModalImage("gb_test_banner_wide", bundleIdentifier: Bundle.module.bundleIdentifier)
        let size = artwork.pointSize
        XCTAssertGreaterThan(
            size.width, 0,
            "'gb_test_banner_wide' does not resolve from the test bundle, so every assertion in "
                + "this file compares two banner-less cards"
        )
        XCTAssertGreaterThan(
            size.width, ModalTokens(from: properties).contentMaxWidth,
            "the artwork (\(size.width)pt) no longer exceeds the content column "
                + "(\(ModalTokens(from: properties).contentMaxWidth)pt), so it cannot widen anything "
                + "and this file has stopped testing column growth"
        )
    }

    /// **The fix, measured.** Wide artwork must push the badge card past `cardMaxWidth`.
    ///
    /// Expected numbers, for the record: `contentMaxWidth` 256 + 32 + 32 = a 320pt `cardMaxWidth`;
    /// the 320pt artwork drives the column to the 310pt ceiling (350pt of available card minus the
    /// 20pt rigid minima), so the card asks for 310 + 32 + 32 = 374 and the 390pt host clamps it to
    /// 350. Asserted as an inequality against `cardMaxWidth` rather than against 350, because the
    /// literal is a consequence of the host width and the point is the RELATION.
    func test_wideArtwork_widensTheBadgeCard() throws {
        let tokens = ModalTokens(from: properties)
        let wide = try cardWidth(
            banner: ModalImage("gb_test_banner_wide", bundleIdentifier: Bundle.module.bundleIdentifier)
        )
        XCTAssertGreaterThan(
            wide, tokens.cardMaxWidth + DifferentialGeometry.tolerance,
            "the badge card (\(wide)pt) did not grow past its unbannered cap "
                + "(\(tokens.cardMaxWidth)pt) for artwork wider than the column. `BadgeModalView` is "
                + "not passing `bannerArtworkSize:` to its scaffold, so `bannerGeometry` is `.zero` "
                + "and the column can never grow — while the UIKit badge view graph widens both."
        )
    }

    /// **The other direction, and it is what stops the assertion above from being satisfied by a
    /// card that simply got wider for everyone.** No banner at all must leave the card exactly at
    /// `cardMaxWidth`.
    func test_noBanner_leavesTheBadgeCardAtItsUnbanneredCap() throws {
        let tokens = ModalTokens(from: properties)
        let plain = try cardWidth(banner: nil)
        XCTAssertEqual(
            plain, tokens.cardMaxWidth, accuracy: DifferentialGeometry.tolerance,
            "a badge card with NO banner is \(plain)pt where its cap is \(tokens.cardMaxWidth)pt. "
                + "`.zero` artwork must collapse `bannerGeometry` to `.zero` and leave the card "
                + "untouched — every badge shape that ships depends on that being the identity."
        )
    }

    /// And the case the app is actually in: artwork NARROWER than the column changes nothing either.
    /// The one real badge banner asset, `img_badge_multi_achievement`, is 160x160pt inside a 256pt
    /// column, which is this case — so this is the assertion that says the shipped shapes did not
    /// move.
    func test_narrowArtwork_leavesTheBadgeCardAtItsUnbanneredCap() throws {
        let tokens = ModalTokens(from: properties)
        let narrow = try cardWidth(
            banner: ModalImage("gb_test_banner", bundleIdentifier: Bundle.module.bundleIdentifier)
        )
        XCTAssertEqual(
            narrow, tokens.cardMaxWidth, accuracy: DifferentialGeometry.tolerance,
            "a badge banner NARROWER than the column (\(narrow)pt card against a "
                + "\(tokens.cardMaxWidth)pt cap) moved the card. `bannerGeometry.column` is "
                + "`max(demand, contentMaxWidth)`, so it must be the identity here — if it is not, "
                + "every shipped badge shape has changed width."
        )
    }
}
