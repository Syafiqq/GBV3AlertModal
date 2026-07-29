import XCTest

/// The `Core/` region is the framework-neutral executor contract: descriptors, executor, token,
/// coordinator, renderer protocol. It must not depend on a UI framework — that is what makes a
/// future module split a manifest edit rather than a refactor. This test IS the enforcement;
/// there is no module boundary doing it for us (spec T5).
final class CorePurityTests: XCTestCase {

    /// `.../Library/GBV3AlertModal` — four levels up from this file.
    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Architecture/
            .deletingLastPathComponent()  // GBV3AlertModalTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // GBV3AlertModal/
    }

    private var coreSwiftFiles: [URL] {
        let core = packageRoot.appendingPathComponent("Sources/GBV3AlertModal/Core")
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
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed == "import UIKit" || trimmed == "import SwiftUI" {
                    offenders.append("\(file.lastPathComponent): \(trimmed)")
                }
            }
        }
        XCTAssertEqual(
            offenders, [],
            "Core/ must stay framework-neutral. Offending imports:\n" + offenders.joined(separator: "\n")
        )
    }
}
