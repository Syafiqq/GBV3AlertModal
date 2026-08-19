import Foundation
import XCTest

final class PackageBoundaryTests: XCTestCase {
    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var repositoryRoot: URL {
        packageRoot.deletingLastPathComponent().deletingLastPathComponent()
    }

    func testManifestDeclaresFiveOwnedTestTargets() throws {
        let manifest = try packageManifest()
        for target in ["Core", "SwiftUI", "UIKit", "Migration", "Architecture"] {
            XCTAssertTrue(manifest.contains("name: \"GBV3AlertModal\(target)Tests\""))
        }
        XCTAssertFalse(manifest.contains("name: \"GBV3AlertModalTests\""))
    }

    func testProductionDependencyEdgesFollowOwnership() throws {
        let manifest = try packageManifest()
        let core = try targetDeclaration(named: "GBV3AlertModalCore", in: manifest)
        let swiftUI = try targetDeclaration(named: "GBV3AlertModalSwiftUI", in: manifest)
        let uiKit = try targetDeclaration(named: "GBV3AlertModalUIKit", in: manifest)
        XCTAssertFalse(core.contains("dependencies:"))
        XCTAssertFalse(swiftUI.contains("GBV3AlertModalUIKit"))
        XCTAssertFalse(swiftUI.contains("GBV3AlertModalMigration"))
        XCTAssertFalse(swiftUI.contains("SnapKit"))
        XCTAssertTrue(uiKit.contains("SnapKit"))
    }

    func testCoreAndSwiftUISourcesContainNoForbiddenImports() throws {
        try assertNoImports(["UIKit", "GBV3AlertModalUIKit", "GBV3AlertModalMigration", "SnapKit"],
                            below: "Sources/GBV3AlertModalCore")
        try assertNoImports(["UIKit", "GBV3AlertModalUIKit", "GBV3AlertModalMigration", "SnapKit"],
                            below: "Sources/GBV3AlertModalSwiftUI")
    }

    func testOnlyMigrationProductionSourcesImportBothBackends() throws {
        let roots = ["GBV3AlertModalCore", "GBV3AlertModalSwiftUI", "GBV3AlertModalUIKit",
                     "GBV3AlertModalMigration", "GBV3AlertModal"]
        for root in roots {
            let sources = try swiftSources(below: "Sources/\(root)").joined(separator: "\n")
            let importsBoth = sources.contains("import GBV3AlertModalSwiftUI")
                && sources.contains("import GBV3AlertModalUIKit")
            if root == "GBV3AlertModalMigration" || root == "GBV3AlertModal" {
                XCTAssertTrue(importsBoth, "\(root) must integrate/re-export both backends")
            } else {
                XCTAssertFalse(importsBoth, "\(root) unexpectedly knows both backends")
            }
        }
    }

    func testBackendResourcesAreOwnedByTheirTargets() throws {
        XCTAssertTrue(FileManager.default.fileExists(atPath:
            packageRoot.appendingPathComponent("Sources/GBV3AlertModalSwiftUI/Assets.xcassets").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath:
            packageRoot.appendingPathComponent("Sources/GBV3AlertModalUIKit/Assets.xcassets").path))
        let manifest = try packageManifest()
        XCTAssertEqual(manifest.components(separatedBy: "resources: [.process(\"Assets.xcassets\")]").count - 1, 2)
    }

    func testOwnedTestTargetsHaveNonoverlappingSourceTrees() {
        let testRoot = packageRoot.appendingPathComponent("Tests")
        let owned = ["Core", "SwiftUI", "UIKit", "Migration", "Architecture"].map {
            testRoot.appendingPathComponent("GBV3AlertModal\($0)Tests").path
        }
        XCTAssertEqual(Set(owned).count, 5)
        for path in owned { XCTAssertTrue(FileManager.default.fileExists(atPath: path)) }
    }

    func testCoreTestsImportNoUIFramework() throws {
        try assertNoImports(["UIKit", "SwiftUI"], below: "Tests/GBV3AlertModalCoreTests")
    }

    func testCrossBackendSnapshotsLiveOnlyInMigrationTests() throws {
        let tests = packageRoot.appendingPathComponent("Tests")
        let snapshots = FileManager.default.enumerator(at: tests, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "png" } ?? []
        XCTAssertFalse(snapshots.isEmpty)
        XCTAssertTrue(snapshots.allSatisfy { $0.path.contains("GBV3AlertModalMigrationTests") })
    }

    func testSwiftUIExampleImportsOnlyOwnedPackageModules() throws {
        let root = repositoryRoot.appendingPathComponent(
            "Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI"
        )
        let sources = try swiftFiles(at: root).map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
        XCTAssertTrue(sources.contains("import GBV3AlertModalCore"))
        XCTAssertTrue(sources.contains("import GBV3AlertModalSwiftUI"))
        for forbidden in ["import GBV3AlertModal\n", "GBV3AlertModalUIKit", "GBV3AlertModalMigration"] {
            XCTAssertFalse(sources.contains(forbidden))
        }
    }

    func testExampleKeepsExactlySeventyUniqueSwiftUIEntriesContract() throws {
        let test = try String(contentsOf: repositoryRoot.appendingPathComponent(
            "Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/CatalogContractTests.swift"
        ), encoding: .utf8)
        XCTAssertTrue(test.contains("#expect(SwiftUICatalog.entries.count == 70)"))
        XCTAssertTrue(test.contains("#expect(swiftUI.count == Set(swiftUI).count"))
    }

    func testDeletionProofFixtureAndEntryPointStayIndependent() throws {
        let fixture = try source("Tests/Architecture/SwiftUIOnlyPackage.swift.fixture")
        XCTAssertTrue(fixture.contains("GBV3AlertModalCore"))
        XCTAssertTrue(fixture.contains("GBV3AlertModalSwiftUI"))
        for forbidden in ["SnapKit", "GBV3AlertModalUIKit", "GBV3AlertModalMigration"] {
            XCTAssertFalse(fixture.contains(forbidden))
        }

        let script = try String(contentsOf: repositoryRoot.appendingPathComponent(
            "Script/test-swiftui-independence.sh"
        ), encoding: .utf8)
        XCTAssertTrue(script.contains("mktemp -d /tmp/gbv3-swiftui-independence"))
        XCTAssertTrue(script.contains("SwiftUIOnlyPackage.swift.fixture"))
        XCTAssertTrue(script.contains("GBV3AlertModalSwiftUIExample"))
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: packageRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private func packageManifest() throws -> String {
        try String(contentsOf: repositoryRoot.appendingPathComponent("Package.swift"), encoding: .utf8)
    }

    private func targetDeclaration(named name: String, in manifest: String) throws -> String {
        let marker = ".target(\n            name: \"\(name)\""
        let start = try XCTUnwrap(manifest.range(of: marker)?.lowerBound)
        let suffix = manifest[start...]
        let end = suffix.range(of: "\n        ),")?.upperBound ?? manifest.endIndex
        return String(manifest[start..<end])
    }

    private func assertNoImports(_ modules: [String], below path: String) throws {
        let imports = try swiftSources(below: path).flatMap { source in
            source.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("import ") || $0.hasPrefix("@_exported import ") }
        }
        for module in modules {
            XCTAssertFalse(imports.contains { $0.contains("import \(module)") }, "\(path) imports \(module)")
        }
    }

    private func swiftSources(below path: String) throws -> [String] {
        try swiftFiles(at: packageRoot.appendingPathComponent(path)).map {
            try String(contentsOf: $0, encoding: .utf8)
        }
    }

    private func swiftFiles(at root: URL) -> [URL] {
        FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
    }
}
