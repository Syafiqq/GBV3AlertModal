import XCTest
import SwiftUI
import UIKit
@testable import GBV3AlertModal

/// Regression coverage for the subtitle-styling bug caught in review: `SwiftUIAlertModal` used to
/// render the UIKit holder's `ModalText.split`-stripped `String` for a `.plain` subtitle, silently
/// dropping SwiftUI-scoped styling a caller applied the natural way. Nothing in the existing 246
/// library / 52 example tests caught it — `ModalTextTests.testSwiftUIScopedColorStaysPlain` only
/// pins `ModalText.split`'s own classification, it never touches `SwiftUIAlertModal` or asserts
/// what gets handed to `Text`.
///
/// `SwiftUIAlertModal.subtitlePayload` is the extracted, pure decision+payload-selection function
/// (spec C-1 follow-up) — these tests call it directly, with no `View` construction, so a
/// regression back to holder-sourced plain text fails HERE.
@MainActor
final class SubtitlePayloadTests: XCTestCase {

    private func resolvedAndHolder(
        for dialog: AlertDialog
    ) -> (GBAlertModal.ResolvedModal, GBAlertModal.DataHolder) {
        let holder = UIKitModalRenderer.AlertHolder.make(for: dialog, resolve: { _ in })
        let resolved = GBAlertModal.resolve(properties: GBAlertModal.Properties(), holder: holder, isLandscape: false)
        return (resolved, holder)
    }

    /// One place to vary just the subtitle, so `subtitle: nil` / `subtitle: ""` calls aren't
    /// ambiguous between `AlertDialog`'s `String?` and `AttributedString?` initializers (a bare
    /// `nil`/`""` literal at the call site can't disambiguate; a typed parameter can).
    private func dialog(subtitle: String?) -> AlertDialog {
        AlertDialog(title: "T", subtitle: subtitle, primary: "OK")
    }

    // MARK: (a) THE REGRESSION GUARD

    /// A SwiftUI-scoped attribute on the descriptor's subtitle must survive in the returned
    /// `.plain` payload. Reasoning (per review step 3): if `subtitlePayload` regressed to sourcing
    /// `.plain` from the UIKIT HOLDER's stripped `String` (`ModalText.split`'s plain output —
    /// `String(text.characters)`, which carries NO attributes at all — see `ModalText.swift`)
    /// instead of from `config.subtitle`, then `text.swiftUI.foregroundColor` below would read
    /// back `nil`, not `.red`, and `XCTAssertEqual` would fail. This test DOES discriminate
    /// between the two payload sources; it is not just re-pinning `ModalText.split` again.
    func test_plainPayload_retainsSwiftUIScopedStyling() {
        var subtitle = AttributedString("Body")
        subtitle.swiftUI.foregroundColor = .red
        let dialog = AlertDialog(title: "T", subtitle: subtitle, primary: "OK")
        let (resolved, holder) = resolvedAndHolder(for: dialog)

        let payload = SwiftUIAlertModal.subtitlePayload(resolved: resolved, config: dialog, holder: holder)
        guard case let .plain(text) = payload else {
            XCTFail("expected .plain, got \(payload)")
            return
        }
        XCTAssertEqual(text.swiftUI.foregroundColor, .red,
                        "SwiftUI-scoped styling must survive in the .plain payload")
    }

    // MARK: (b) plain/unstyled — no behaviour change

    func test_plainPayload_unstyledSubtitle_carriesSameText() {
        let d = dialog(subtitle: "Body")
        let (resolved, holder) = resolvedAndHolder(for: d)

        let payload = SwiftUIAlertModal.subtitlePayload(resolved: resolved, config: d, holder: holder)
        guard case let .plain(text) = payload else {
            XCTFail("expected .plain, got \(payload)")
            return
        }
        XCTAssertEqual(String(text.characters), "Body")
    }

    // MARK: (c) UIKit-scoped styling -> .attributed, sourced from the holder

    /// UIKit-scoped styling is the one case that legitimately bridges to `NSAttributedString` —
    /// the resolver classifies it `.attributed`, and the payload must be `holder.subtitleAttributed`
    /// itself (the exact instance UIKit would draw), not re-derived from the descriptor.
    func test_attributedPayload_comesFromHolder() {
        var subtitle = AttributedString("Bold")
        subtitle.uiKit.foregroundColor = UIColor.red
        let dialog = AlertDialog(title: "T", subtitle: subtitle, primary: "OK")
        let (resolved, holder) = resolvedAndHolder(for: dialog)

        let payload = SwiftUIAlertModal.subtitlePayload(resolved: resolved, config: dialog, holder: holder)
        guard case let .attributed(attributed) = payload else {
            XCTFail("expected .attributed, got \(payload)")
            return
        }
        XCTAssertTrue(attributed === holder.subtitleAttributed,
                       "attributed payload must be holder.subtitleAttributed itself, not re-derived")
    }

    // MARK: (d) nil / empty subtitle -> .none

    func test_nonePayload_whenSubtitleNil() {
        let d = dialog(subtitle: nil)
        let (resolved, holder) = resolvedAndHolder(for: d)
        let payload = SwiftUIAlertModal.subtitlePayload(resolved: resolved, config: d, holder: holder)
        guard case .none = payload else {
            XCTFail("expected .none, got \(payload)")
            return
        }
    }

    func test_nonePayload_whenSubtitleEmpty() {
        let d = dialog(subtitle: "")
        let (resolved, holder) = resolvedAndHolder(for: d)
        let payload = SwiftUIAlertModal.subtitlePayload(resolved: resolved, config: d, holder: holder)
        guard case .none = payload else {
            XCTFail("expected .none, got \(payload)")
            return
        }
    }
}
