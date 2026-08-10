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
    ///
    /// Uses a SwiftUI-scoped FONT rather than a colour, and that swap is load-bearing: `split` now
    /// converts SwiftUI COLOUR onto UIKit's scope, so a coloured subtitle classifies as `.attributed`
    /// and never reaches the `.plain` branch this test is about. Font has no `Font -> UIFont`
    /// direction to convert through, so it still routes to `.plain` — which keeps this discrimination
    /// (payload sourced from `config.subtitle`, not from the holder's stripped `String`) testable.
    func test_plainPayload_retainsSwiftUIScopedStyling() {
        var subtitle = AttributedString("Body")
        subtitle.swiftUI.font = .largeTitle
        let dialog = AlertDialog(title: "T", subtitle: subtitle, primary: "OK")
        let (resolved, _) = resolvedAndHolder(for: dialog)

        let payload = SwiftUIAlertModal.subtitlePayload(resolved: resolved, config: dialog)
        guard case let .plain(text) = payload else {
            XCTFail("expected .plain, got \(payload)")
            return
        }
        XCTAssertEqual(text.swiftUI.font, .largeTitle,
                        "SwiftUI-scoped styling must survive in the .plain payload")
    }

    // MARK: (b) plain/unstyled — no behaviour change

    func test_plainPayload_unstyledSubtitle_carriesSameText() {
        let d = dialog(subtitle: "Body")
        let (resolved, _) = resolvedAndHolder(for: d)

        let payload = SwiftUIAlertModal.subtitlePayload(resolved: resolved, config: d)
        guard case let .plain(text) = payload else {
            XCTFail("expected .plain, got \(payload)")
            return
        }
        XCTAssertEqual(String(text.characters), "Body")
    }

    // MARK: (c) UIKit-scoped styling -> .attributed, sourced from the holder

    /// UIKit-scoped styling is the one case that legitimately bridges to `NSAttributedString` —
    /// the resolver classifies it `.attributed`, and the payload must be VALUE-equal to
    /// `holder.subtitleAttributed` (the exact bridged string UIKit would draw).
    ///
    /// **Not `===` any more, and that is deliberate (Pass 5 step 6).** `subtitlePayload` used to
    /// read `holder.subtitleAttributed` directly; it now re-derives the SAME string via
    /// `ModalText.split(config.subtitle)` — a `ModalContent` carries no `NSAttributedString` to
    /// read (see `ModalContent`'s doc) — so the result is a distinct instance with identical
    /// content, not the same object.
    func test_attributedPayload_matchesTheUIKitBridgedString() {
        var subtitle = AttributedString("Bold")
        subtitle.uiKit.foregroundColor = UIColor.red
        let dialog = AlertDialog(title: "T", subtitle: subtitle, primary: "OK")
        let (resolved, holder) = resolvedAndHolder(for: dialog)

        let payload = SwiftUIAlertModal.subtitlePayload(resolved: resolved, config: dialog)
        guard case let .attributed(attributed) = payload else {
            XCTFail("expected .attributed, got \(payload)")
            return
        }
        XCTAssertEqual(attributed, holder.subtitleAttributed,
                        "attributed payload must match holder.subtitleAttributed's content")
    }

    // MARK: (d) nil / empty subtitle -> .none

    func test_nonePayload_whenSubtitleNil() {
        let d = dialog(subtitle: nil)
        let (resolved, _) = resolvedAndHolder(for: d)
        let payload = SwiftUIAlertModal.subtitlePayload(resolved: resolved, config: d)
        guard case .none = payload else {
            XCTFail("expected .none, got \(payload)")
            return
        }
    }

    func test_nonePayload_whenSubtitleEmpty() {
        let d = dialog(subtitle: "")
        let (resolved, _) = resolvedAndHolder(for: d)
        let payload = SwiftUIAlertModal.subtitlePayload(resolved: resolved, config: d)
        guard case .none = payload else {
            XCTFail("expected .none, got \(payload)")
            return
        }
    }
}

// MARK: - `attributedRuns` — UIKit-scoped styling must reach SwiftUI's scope

/// The declared catalog divergence said SwiftUI "draws them unstyled": an `NSAttributedString`
/// bridged with `AttributedString(_:)` keeps its runs on UIKit's scope, and `Text` reads its own, so
/// bold and colour were carried to the draw call and dropped there.
final class AttributedTextBridgeTests: XCTestCase {

    private func styled() -> NSAttributedString {
        NSAttributedString(
            string: "Bold and red",
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 19),
                .foregroundColor: UIColor.red
            ]
        )
    }

    func test_uiKitScopedColourAndFont_reachSwiftUIsScope() throws {
        let converted = AttributedTextBridge.swiftUIRenderable(styled())
        let run = try XCTUnwrap(converted.runs.first)

        XCTAssertNotNil(
            run.swiftUI.foregroundColor,
            "the colour never reached SwiftUI's scope — Text would draw this in the default colour"
        )
        XCTAssertNotNil(
            run.swiftUI.font,
            "the font never reached SwiftUI's scope — Text would draw this unbolded, which is the "
                + "emphasis the caller explicitly asked for"
        )
    }

    /// The UIKit attributes are left in place: the same value still bridges back for any UIKit
    /// consumer, so this is additive re-scoping rather than a move.
    func test_theUIKitScopeIsPreserved() throws {
        let converted = AttributedTextBridge.swiftUIRenderable(styled())
        let run = try XCTUnwrap(converted.runs.first)

        XCTAssertNotNil(run.uiKit.foregroundColor)
        XCTAssertNotNil(run.uiKit.font)
    }

    /// A caller who set SwiftUI's scope explicitly is not second-guessed.
    func test_anExplicitSwiftUIScope_isNotOverwritten() throws {
        var text = AttributedString("Mixed")
        text.uiKit.foregroundColor = .red
        text.swiftUI.foregroundColor = .green

        let converted = AttributedTextBridge.swiftUIRenderable(NSAttributedString(text))
        let run = try XCTUnwrap(converted.runs.first)
        XCTAssertEqual(run.swiftUI.foregroundColor, .green)
    }

    /// Unstyled text is unchanged — the bridge must not invent attributes.
    func test_unstyledText_gainsNothing() throws {
        let converted = AttributedTextBridge.swiftUIRenderable(NSAttributedString(string: "Plain"))
        let run = try XCTUnwrap(converted.runs.first)

        XCTAssertNil(run.swiftUI.foregroundColor)
        XCTAssertNil(run.swiftUI.font)
    }
}

