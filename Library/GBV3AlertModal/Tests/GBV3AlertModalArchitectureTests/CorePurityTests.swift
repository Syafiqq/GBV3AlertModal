import XCTest

/// The `Core/` region is the framework-neutral executor contract: descriptors, executor, token,
/// coordinator, renderer protocol. It must not depend on a UI framework — that is what makes a
/// future module split a manifest edit rather than a refactor. This test IS the enforcement;
/// there is no module boundary doing it for us (spec T5).
final class CorePurityTests: XCTestCase {

    /// `.../Library/GBV3AlertModal` — four levels up from this file.
    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // GBV3AlertModalArchitectureTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // GBV3AlertModal/
    }

    private var coreSwiftFiles: [URL] {
        let core = packageRoot.appendingPathComponent("Sources/GBV3AlertModalCore")
        guard let e = FileManager.default.enumerator(at: core, includingPropertiesForKeys: nil)
        else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    func testCoreRegionExistsAndIsNotEmpty() {
        XCTAssertFalse(coreSwiftFiles.isEmpty, "Core/ region is missing or empty")
    }

    func testCoreRegionImportsNoUIFramework() throws {
        var offenders: [String] = []
        for file in coreSwiftFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
                if let offence = Self.uiFrameworkImport(in: String(line)) {
                    offenders.append("\(file.lastPathComponent): \(offence)")
                }
            }
        }
        XCTAssertEqual(
            offenders, [],
            "Core/ must stay framework-neutral. Offending imports:\n" + offenders.joined(separator: "\n")
        )
    }

    func testResolvedModalDeclarationContainsNoUIFrameworkSymbols() throws {
        let file = packageRoot.appendingPathComponent(
            "Sources/GBV3AlertModalCore/ResolvedModal.swift"
        )
        let source = try String(contentsOf: file, encoding: .utf8)
            .split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let forbidden = ["UIKit", "SwiftUI", "NSLayoutConstraint", "UIView", "UIStackView"]

        for symbol in forbidden {
            XCTAssertFalse(source.contains(symbol), "ResolvedModal must not contain \(symbol)")
        }
    }

    /// **The import forms this recognises, and why matching whole lines was not enough.**
    ///
    /// This used to compare the trimmed line against exactly `"import UIKit"` / `"import SwiftUI"`,
    /// which let three real forms straight through:
    ///
    /// * `import UIKit // needed for CGFloat` — a trailing comment
    /// * `import struct SwiftUI.Color` — a submodule import, which is still a dependency
    /// * `@_exported import UIKit` — an attribute in front
    ///
    /// Each is a genuine framework dependency in `Core/`, and each would have passed a test whose
    /// whole purpose is to prevent exactly that. `test_theCorePurityCheck_catchesTheFormsItUsedToMiss`
    /// pins all three, so the matcher cannot quietly regress to equality again.
    ///
    /// Deliberately still TEXTUAL rather than a real parse: the check must fail closed and stay
    /// readable, and a false positive here is a comment somebody can reword.
    static func uiFrameworkImport(in line: String) -> String? {
        // Strip a trailing line comment, then normalise whitespace.
        let withoutComment = line.components(separatedBy: "//").first ?? line
        let trimmed = withoutComment.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }
        // Tokenise on whitespace and dots so `import struct SwiftUI.Color` and `@_exported import
        // UIKit` both reduce to a token list containing the framework name.
        let tokens = trimmed
            .components(separatedBy: CharacterSet(charactersIn: " \t."))
            .filter { !$0.isEmpty }
        guard tokens.contains("import") else {
            return nil
        }
        guard tokens.contains("UIKit") || tokens.contains("SwiftUI") else {
            return nil
        }
        return trimmed
    }
}

// MARK: - The check's own discrimination

/// A purity check that cannot see the forms it is supposed to catch is worse than none: it reports
/// green while the boundary it guards is already breached. These are the three forms the original
/// whole-line comparison let through.
final class CorePurityMatcherTests: XCTestCase {

    func test_theCorePurityCheck_catchesTheFormsItUsedToMiss() {
        let offending = [
            "import UIKit",
            "import SwiftUI",
            "import UIKit // needed for CGFloat",
            "import struct SwiftUI.Color",
            "@_exported import UIKit",
            "  import   SwiftUI  "
        ]
        for line in offending {
            XCTAssertNotNil(
                CorePurityTests.uiFrameworkImport(in: line),
                "'\(line)' is a UI-framework dependency in Core/ and was not caught"
            )
        }
    }

    func test_theCorePurityCheck_doesNotFireOnInnocentLines() {
        let innocent = [
            "import Foundation",
            "// import UIKit — deliberately not imported, see the note above",
            "/// Mirrors UIKit's `UIEdgeInsets` without importing it",
            "let description = \"import SwiftUI\"  // a string, not an import",
            ""
        ]
        for line in innocent {
            XCTAssertNil(
                CorePurityTests.uiFrameworkImport(in: line),
                "'\(line)' is not an import and must not be reported"
            )
        }
    }
}
