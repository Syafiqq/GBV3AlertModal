import XCTest

/// **Enforces that every `Text` drawing a descriptor's `AttributedString` title/subtitle goes
/// through `AttributedTextBridge`.**
///
/// Two real bugs (commits `4464579`, `f0867e8`, and the bespoke/input-view sweep alongside this
/// test) were the SAME shape: `Text(title)`/`Text(subtitle)` handed the descriptor's raw
/// `AttributedString` straight to `Text`, which reads only SwiftUI's own attribute scope — a
/// caller's UIKit-scoped styling (`GenieShapeCatalog.styled(_:color:)`'s vocabulary; the real
/// `switch-device-recommendation` title and `badgeUnlockSubtitle`-shaped subtitles) reached the draw
/// call unconverted and was silently dropped or degraded. Fixing the known instances doesn't stop a
/// new one being written the natural way tomorrow.
///
/// Same pattern `SwiftUIPurityTests`/`CorePurityTests` already use for their own boundaries — a
/// textual scan rather than a description nothing re-checks. This one has no allow-list: zero
/// unwrapped call sites is the permanent state, not a list that can legitimately grow.
final class UnbridgedTextTests: XCTestCase {

    /// The exact unsafe shape, as literal source. Checked against CODE lines only (a `//`/`///`
    /// comment earlier on the line disqualifies the match) — this file's own sibling docs
    /// (`SwiftUIAlertModal.bridgedTitle`'s comment, `SwiftUIModalRenderer+InputViews.swift`'s)
    /// legitimately mention these strings in prose.
    private static let forbiddenPatterns = ["Text(title)", "Text(subtitle)"]

    /// **The one legitimate exception, named rather than silently tolerated.**
    /// `AlertModalScaffold.primaryButton`/`.secondaryButton` take `_ title: String` — a BUTTON
    /// LABEL (`AlertDialog.primary`/`.secondary`, always `String?`), not a descriptor's
    /// `AttributedString` title/subtitle. `Text(title)` there is the exact literal this scan looks
    /// for, but there is no `AttributedString` in play and nothing to bridge. Excluded by name so a
    /// GENUINE new offender elsewhere cannot hide behind a blanket exemption.
    private static let exemptFiles: Set<String> = ["AlertModalScaffold.swift"]

    /// Mirrors `SwiftUIPurityTests.swiftUISwiftFiles` exactly — same directory, same traversal.
    private var swiftUISwiftFiles: [URL] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // SwiftUI/
            .deletingLastPathComponent()  // GBV3AlertModalTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // GBV3AlertModal/
            .appendingPathComponent("Sources/GBV3AlertModal/SwiftUI")
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    func test_theSwiftUIRegionIsNotEmpty() {
        XCTAssertFalse(swiftUISwiftFiles.isEmpty, "SwiftUI/ region is missing or empty")
    }

    func test_noTextCallSite_bypassesTheAttributedTextBridge() throws {
        var offenders: [String] = []
        for file in swiftUISwiftFiles where !Self.exemptFiles.contains(file.lastPathComponent) {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
                let stripped = String(line)
                guard !stripped.contains("//") else { continue }
                for pattern in Self.forbiddenPatterns where stripped.contains(pattern) {
                    offenders.append("\(file.lastPathComponent): \(stripped.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertEqual(
            offenders, [],
            "Found Text(title)/Text(subtitle) unwrapped by AttributedTextBridge — a caller's "
                + "UIKit-scoped styling on this run would silently drop. Wrap it: "
                + "Text(AttributedTextBridge.swiftUIRenderable(title)), same as every other "
                + "descriptor title/subtitle Text() in this module:\n"
                + offenders.joined(separator: "\n")
        )
    }
}
