import XCTest

/// **How much UIKit the SwiftUI half still imports, file by file, with a REASON for every one that
/// does — enforced rather than described.**
///
/// The direction spec's §3 listed "four bespoke views — text input, date picker, badge, loading —
/// all delegate to `UIKitModalRenderer` because descriptors cannot carry a `UIView`" as work
/// remaining for Pass 4. That was measured false: `SwiftUIModalRenderer+InputViews.swift` and
/// `+BespokeViews.swift` were 673 lines of native SwiftUI between them, importing no UIKit,
/// containing no `UIViewRepresentable`, and were the RICHER half — `BadgeDialog`'s grid has no
/// UIKit content view in this library at all, and `LoadingDialog.isLoading` has no UIKit expression
/// (`UIKitModalRenderer.registerBuiltInDescriptors` says so itself).
///
/// `+InputViews.swift` has since gained ONE owner-approved exception: `WheelDatePicker` (a raw
/// `UIDatePicker` behind `UIViewRepresentable`), because `SwiftUI.DatePicker(.wheel)` was measured
/// — three separate ways, on real device — not to let any SwiftUI-level frame constrain what it
/// reports to its parent, corrupting `AlertModalScaffold`'s button row on every shape that uses it.
/// See `WheelDatePicker`'s own doc for the full account. `+BespokeViews.swift` remains fully pure.
///
/// A claim like that rots the moment someone adds an import for a quick fix, which is precisely how
/// §3's row came to be wrong. `CorePurityTests` solves the same problem for `Core/` by making the
/// boundary a test; this is that pattern applied to the boundary Pass 5 actually has to move.
///
/// **The allow-list IS the remaining work.** Every entry is a file that legitimately imports UIKit
/// today, with the reason and — where there is one — the pass that removes it. When Pass 5 asks
/// "what is left", this list is the answer, and it cannot silently grow.
final class SwiftUIPurityTests: XCTestCase {

    /// The files permitted to import UIKit, and why.
    ///
    /// - `ModalFont` / `ModalTokens`: **permanent.** Measurement stays on `UIFont` by measurement
    ///   rather than by choice (spec §3b) — CoreText was tried and rejected because multi-line
    ///   wrapping differs by up to 2.16pt against a 0.5pt tolerance, under-measuring at floor scale.
    ///   `ModalTokens` additionally derives from `GBAlertModal.Properties`, which is the app's live
    ///   API and stays indefinitely (§6a).
    /// - `AttributedTextBridge`: **permanent while `Properties` is.** It re-scopes attributes
    ///   between SwiftUI's and UIKit's attribute scopes; naming both is its entire job.
    /// - `SwiftUIModalRenderer`: **PUBLIC API, permanent while it is.** Pass 5 step 6 generalized the
    ///   INTERNAL registry past `DataHolder` (`Registration.factory` now returns
    ///   `any ModalContentInputs`), but the PUBLIC `Factory` typealias and
    ///   `register(_:factory:)`/`register(_:route:factory:)` stay `(GBAlertModal.Properties?,
    ///   DataHolder)` on purpose — an owner decision to keep them non-breaking for existing callers
    ///   (the example app, `register(_:factory:)`'s documented extension point) rather than replace
    ///   them. The import stays for as long as that public surface does.
    /// - `DataHolder+ModalContentInputs.swift`: **permanent while `DataHolder` is.** Bridges
    ///   `GBAlertModal.DataHolder` (a UIKit-region type) to `ModalContentInputs` — reads
    ///   `UIImage.size` to decide `hasBanner`. The conformance's whole job is naming the UIKit type.
    /// - `SwiftUIModalRenderer+InputViews.swift`: **owner-approved, scoped to `WheelDatePicker`.**
    ///   `SwiftUI.DatePicker(.wheel)` wraps `UIPickerView`/`UIDatePicker` through Apple's own
    ///   PRIVATE bridge, and that bridge does not forward any SwiftUI-level frame constraint down
    ///   to the real picker — confirmed on real device, three separate ways (`.frame(maxWidth:)`,
    ///   an EXACT `.frame(width:)`, and an `.overlay()`-based technique that should not have been
    ///   able to fail by SwiftUI's own documented contract), each of which left
    ///   `AlertModalScaffold`'s primary/secondary buttons rendering flush to the card edge instead
    ///   of padded — `buttonsMatchParent` faithfully copies whatever the row reports, and the
    ///   built-in picker was reporting something the row never asked for. `WheelDatePicker` is a
    ///   raw `UIDatePicker` behind the ORDINARY `UIViewRepresentable` hosting contract instead,
    ///   which DOES apply SwiftUI's computed frame to the real view, the same way the production
    ///   UIKit gallery entry for this shape already constrains its own `UIDatePicker`. See
    ///   `WheelDatePicker`'s own doc for the full account of what was tried first.
    ///
    /// `AlertModalScaffold.swift` was on this list and is NOT any more: it imported UIKit and used
    /// zero UIKit symbols. A dead import is how an allow-list becomes a fiction.
    private static let permittedUIKitImporters: Set<String> = [
        "ModalFont.swift",
        "ModalTokens.swift",
        "AttributedTextBridge.swift",
        "SwiftUIModalRenderer.swift",
        "DataHolder+ModalContentInputs.swift",
        "SwiftUIModalRenderer+InputViews.swift"
    ]

    private var swiftUISwiftFiles: [URL] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Architecture/
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

    /// **The allow-list must not GROW silently.** A new UIKit import in the SwiftUI half is a
    /// decision, and it should be made by editing this list with a reason rather than by adding a
    /// line at the top of a file.
    func test_onlyTheListedFiles_importUIKit() throws {
        var offenders: [String] = []
        for file in swiftUISwiftFiles where !Self.permittedUIKitImporters.contains(file.lastPathComponent) {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n", omittingEmptySubsequences: false)
            where Self.importsUIKit(String(line)) {
                offenders.append(file.lastPathComponent)
            }
        }
        XCTAssertEqual(
            Set(offenders), [],
            "New UIKit imports in SwiftUI/. Add the file to `permittedUIKitImporters` WITH A REASON "
                + "if it is genuinely needed, or remove the import:\n"
                + Set(offenders).sorted().joined(separator: "\n")
        )
    }

    /// **The allow-list must not go STALE either**, which is the failure this whole file exists
    /// because of: `AlertModalScaffold.swift` carried an `import UIKit` it did not use, and §3
    /// carried a description of Pass 4 that was no longer true. Both are the same defect — a
    /// statement about the boundary that nothing re-checked.
    func test_everyListedFile_actuallyStillImportsUIKit() throws {
        var stale: [String] = []
        for name in Self.permittedUIKitImporters {
            guard let file = swiftUISwiftFiles.first(where: { $0.lastPathComponent == name }) else {
                stale.append("\(name) (no such file)")
                continue
            }
            let source = try String(contentsOf: file, encoding: .utf8)
            let imports = source
                .split(separator: "\n", omittingEmptySubsequences: false)
                .contains { Self.importsUIKit(String($0)) }
            if !imports {
                stale.append("\(name) (no longer imports UIKit — remove it from the list)")
            }
        }
        XCTAssertEqual(stale.sorted(), [], "The allow-list has entries that no longer apply")
    }

    /// **The bespoke views are native, and this is the assertion that says so.**
    ///
    /// Named explicitly rather than left to the general check above, because these were what §3
    /// claimed still delegated to UIKit. Naming it means the correction is pinned to the specific
    /// claim it corrects, and a future reader diffing the spec against the code lands here.
    ///
    /// `+InputViews.swift` dropped OFF this list deliberately (`WheelDatePicker`, see
    /// `permittedUIKitImporters`'s own doc) — it is on the allow-list above instead, which is the
    /// honest place for a file with one, named, owner-approved exception rather than none.
    func test_theBespokeViews_arePureSwiftUI() throws {
        for name in ["SwiftUIModalRenderer+BespokeViews.swift"] {
            let file = try XCTUnwrap(swiftUISwiftFiles.first { $0.lastPathComponent == name })
            let source = try String(contentsOf: file, encoding: .utf8)

            XCTAssertFalse(
                source.split(separator: "\n", omittingEmptySubsequences: false)
                    .contains { Self.importsUIKit(String($0)) },
                "\(name) imports UIKit"
            )
            // A representable would be a UIKit view wearing a SwiftUI type, which is exactly the
            // delegation §3 described and the one thing an import check alone would not catch if
            // the type were re-exported.
            XCTAssertFalse(
                source.contains("UIViewRepresentable") || source.contains("UIViewControllerRepresentable"),
                "\(name) wraps a UIKit view"
            )
        }
    }

    /// **`WheelDatePicker` is the ONLY UIKit-facing surface `+InputViews.swift` is allowed to have.**
    /// The general checks above prove the file imports UIKit and wraps a representable — this
    /// proves it does not do so anywhere else, so the exception stays exactly as scoped as its
    /// reason claims.
    func test_inputViews_onlyWheelDatePicker_touchesUIKit() throws {
        let file = try XCTUnwrap(
            swiftUISwiftFiles.first { $0.lastPathComponent == "SwiftUIModalRenderer+InputViews.swift" }
        )
        let source = try String(contentsOf: file, encoding: .utf8)
        // `": UIViewRepresentable"` (the conformance syntax), not a bare substring match — the file's
        // own doc comments legitimately say "UIViewRepresentable" in prose more than once explaining
        // WHY `WheelDatePicker` exists, and a raw substring count would false-positive on those.
        let conformanceCount = source.components(separatedBy: ": UIViewRepresentable").count - 1
        XCTAssertEqual(
            conformanceCount, 1,
            "expected exactly one `: UIViewRepresentable` conformance (WheelDatePicker) — found "
                + "\(conformanceCount). If this is a second exception it needs its own reason in "
                + "permittedUIKitImporters, not a silent addition alongside the first."
        )
        XCTAssertFalse(
            source.contains("UIViewControllerRepresentable"), "\(file.lastPathComponent) wraps a view controller"
        )
    }

    /// Same textual matcher `CorePurityTests` uses, narrowed to UIKit — SwiftUI files may of course
    /// import SwiftUI. Its discrimination (trailing comments, submodule imports, `@_exported`) is
    /// already pinned by `CorePurityMatcherTests`.
    private static func importsUIKit(_ line: String) -> Bool {
        guard let offence = CorePurityTests.uiFrameworkImport(in: line) else { return false }
        return offence
            .components(separatedBy: CharacterSet(charactersIn: " \t."))
            .contains("UIKit")
    }
}
