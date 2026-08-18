import SwiftUI
import UIKit
import XCTest
import GBV3AlertModalCore
import GBV3AlertModalSwiftUI
import GBV3AlertModalUIKit
import GBV3AlertModalMigration

/// Checked-in ownership decisions for declarations referenced across the Task 8 target boundaries.
/// A type entry covers its explicitly declared public initializers, members, nested types,
/// conformances, and generic constraints; the disposable split-package build is the compiler-level
/// witness that every such member has sufficient access.
private enum CrossModuleAPIInventory {
    struct Entry {
        let symbol: String
        let owner: String
        let consumers: String
        let access: String
        let rationale: String
    }

    static let entries: [Entry] = [
        // Core consumer surface.
        .publicCore("ModalDescriptor", "SwiftUI, UIKit, Migration", "Descriptor contract"),
        .publicCore("ButtonEnablement", "SwiftUI, UIKit", "Mutable button-state contract"),
        .publicCore("ModalImage", "SwiftUI, UIKit", "Semantic image reference"),
        .publicCore("ModalContentInputs", "SwiftUI, UIKit", "Resolver content contract"),
        .publicCore("ModalStructureInputs", "SwiftUI, UIKit", "Resolver structure contract"),
        .publicCore("ModalRenderer", "SwiftUI, UIKit, Migration", "Renderer abstraction"),
        .publicCore("ModalExecutor", "Core consumers", "Executor abstraction"),
        .publicCore("DefaultModalExecutor", "Core consumers", "Default executor"),
        .publicCore("MainTabModalCoordinator", "Core consumers", "Coordinator implementation"),
        .publicCore("ModalID", "SwiftUI, UIKit, Migration", "Presentation identity"),
        .publicCore("ModalToken", "Core consumers", "Presentation result handle"),
        .publicCore("ModalAction", "SwiftUI, UIKit, Migration", "Backend-neutral action"),
        .publicCore("ResolvedModal", "SwiftUI, UIKit, Migration", "Shared resolution result"),
        .publicCore("CoreResolvedModal", "UIKit", "Legacy nested-name bridge"),
        .publicCore("MinMaxEdgeInsets", "SwiftUI, UIKit, Migration", "Neutral layout value"),
        .publicCore("ModalText", "Migration", "Attributed-text degradation policy"),
        .publicCore("ModalStyle", "SwiftUI, UIKit, Migration", "Renderer style key"),
        .publicCore("StandardAlertContent", "SwiftUI, UIKit", "Standard content projection"),
        .publicCore("AlertDialog", "SwiftUI, UIKit, Migration", "Supported descriptor"),
        .publicCore("PopupDialog", "SwiftUI, UIKit, Migration", "Supported descriptor"),
        .publicCore("BadgeDialog", "SwiftUI, UIKit, Migration", "Supported descriptor"),
        .publicCore("LoadingDialog", "SwiftUI, UIKit, Migration", "Supported descriptor"),
        .publicCore("SatisfactionDialog", "SwiftUI, UIKit, Migration", "Supported descriptor"),
        .publicCore("TextInputDialog", "SwiftUI, UIKit, Migration", "Supported descriptor"),
        .publicCore("DatePickerDialog", "SwiftUI, UIKit, Migration", "Supported descriptor"),
        .packageCore("ModalDiagnostics", "SwiftUI, UIKit, Migration", "Shared debug logging"),
        .packageCore("ModalLayoutMetrics", "SwiftUI, UIKit", "Renderer parity constants"),

        // SwiftUI product surface consumed by Migration and the compatibility shim.
        .publicSwiftUI("ModalProperties"), .publicSwiftUI("ModalContent"),
        .publicSwiftUI("ModalTokens"), .publicSwiftUI("ModalFont"),
        .publicSwiftUI("ModalBannerConfiguration"), .publicSwiftUI("ModalLayoutPreset"),
        .publicSwiftUI("AlertModalScaffold"), .publicSwiftUI("SwiftUIAlertModal"),
        .publicSwiftUI("ModalHost"), .publicSwiftUI("SwiftUIModalRenderer"),
        .publicSwiftUI("TextInputModalView"), .publicSwiftUI("DatePickerModalView"),
        .publicSwiftUI("BadgeModalView"), .publicSwiftUI("LoadingModalView"),
        .publicSwiftUI("SatisfactionModalView"), .publicSwiftUI("ObliquePrimaryStyle"),
        .publicSwiftUI("PlainSecondaryStyle"), .publicSwiftUI("CapsuleButtonStyle"),
        .publicSwiftUI("CapsuleOutlinedButtonStyle"),

        // UIKit and integration surface.
        .init(symbol: "GBAlertModal", owner: "UIKit", consumers: "Migration, compatibility",
              access: "public", rationale: "Legacy supported API and adapter input"),
        .init(symbol: "UIKitModalRenderer", owner: "UIKit", consumers: "compatibility",
              access: "public", rationale: "Independently consumable UIKit backend"),
        .init(symbol: "UIMinMaxEdgeInsets", owner: "UIKit", consumers: "compatibility",
              access: "public", rationale: "Deprecated source-compatible alias"),
        .init(symbol: "WindowModalRenderer", owner: "Migration", consumers: "compatibility",
              access: "public", rationale: "Cross-backend UIWindow integration"),
        .init(symbol: "ModalProperties.init(adapting:)", owner: "Migration",
              consumers: "migration clients, compatibility", access: "public",
              rationale: "Explicit legacy-to-native configuration bridge"),
    ]
}

private extension CrossModuleAPIInventory.Entry {
    static func publicCore(_ symbol: String, _ consumers: String, _ rationale: String) -> Self {
        .init(symbol: symbol, owner: "Core", consumers: consumers, access: "public", rationale: rationale)
    }

    static func packageCore(_ symbol: String, _ consumers: String, _ rationale: String) -> Self {
        .init(symbol: symbol, owner: "Core", consumers: consumers, access: "package", rationale: rationale)
    }

    static func publicSwiftUI(_ symbol: String) -> Self {
        .init(symbol: symbol, owner: "SwiftUI", consumers: "Migration, compatibility",
              access: "public", rationale: "Supported native backend surface")
    }
}

final class CrossModuleAPITests: XCTestCase {
    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testInventoryHasUniqueSymbolsAndCompleteDecisions() {
        let entries = CrossModuleAPIInventory.entries
        XCTAssertEqual(Set(entries.map(\.symbol)).count, entries.count)
        for entry in entries {
            XCTAssertFalse(entry.owner.isEmpty)
            XCTAssertFalse(entry.consumers.isEmpty)
            XCTAssertTrue(["public", "package"].contains(entry.access))
            XCTAssertFalse(entry.rationale.isEmpty)
        }
    }

    func testEveryCrossOwnerDeclaredTypeHasAnInventoryClassification() throws {
        let roots: [(owner: String, path: String)] = [
            ("Core", "Sources/GBV3AlertModalCore"),
            ("SwiftUI", "Sources/GBV3AlertModalSwiftUI"),
            ("UIKit", "Sources/GBV3AlertModalUIKit/Components"),
            ("UIKit", "Sources/GBV3AlertModalUIKit/Executor"),
        ]
        let inventory = Set(CrossModuleAPIInventory.entries.map(\.symbol))
        var missing: [String] = []

        for root in roots {
            let files = swiftFiles(at: packageRoot.appendingPathComponent(root.path))
            for file in files {
                let source = try String(contentsOf: file, encoding: .utf8)
                for symbol in declaredBoundaryTypes(in: source) where inventory.contains(symbol) == false {
                    if isReferencedOutside(symbol: symbol, ownerRoot: root.path, roots: roots) {
                        missing.append("\(root.owner).\(symbol)")
                    }
                }
            }
        }

        XCTAssertEqual(missing.sorted(), [], "Unclassified cross-owner declarations: \(missing)")
    }

    /// Compile witnesses use a normal import, not `@testable`, so these calls prove supported
    /// consumer API rather than package internals.
    @MainActor
    func testRepresentativePublicSurfaceCompilesWithoutTestableImport() {
        let content = ModalContent(title: "Title", primaryAction: "OK")
        let properties = ModalProperties(padding: .init(top: (8, 16)))
        let descriptor = AlertDialog(title: "Title", primary: "OK")
        let swiftUIRenderer: any ModalRenderer = SwiftUIModalRenderer(alertProperties: properties)
        let uiKitRenderer: any ModalRenderer = UIKitModalRenderer(
            alertProperties: GBAlertModal.Properties()
        )

        XCTAssertEqual(content.title, "Title")
        XCTAssertEqual(properties.padding?.topMax, 16)
        XCTAssertEqual(descriptor.primary, "OK")
        _ = swiftUIRenderer
        _ = uiKitRenderer
    }

    private func swiftFiles(at root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    private func declaredBoundaryTypes(in source: String) -> [String] {
        source.split(separator: "\n").compactMap { line in
            guard line.first?.isWhitespace == false else { return nil }
            let words = line.split { $0 == " " || $0 == "\t" || $0 == ":" || $0 == "<" }
            guard let accessIndex = words.firstIndex(where: { $0 == "public" || $0 == "package" }),
                  words.indices.contains(accessIndex + 2),
                  ["struct", "class", "enum", "protocol", "typealias"].contains(words[accessIndex + 1])
            else { return nil }
            return String(words[accessIndex + 2])
        }
    }

    private func isReferencedOutside(
        symbol: String,
        ownerRoot: String,
        roots: [(owner: String, path: String)]
    ) -> Bool {
        roots.filter { $0.path != ownerRoot }.contains { root in
            swiftFiles(at: packageRoot.appendingPathComponent(root.path)).contains { file in
                (try? String(contentsOf: file, encoding: .utf8))?.contains(symbol) == true
            }
        }
    }
}
