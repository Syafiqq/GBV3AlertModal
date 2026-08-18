import Foundation
import XCTest

final class SwiftUIBackendPurityTests: XCTestCase {
    private var swiftUIFiles: [URL] {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let root = packageRoot.appendingPathComponent("Sources/GBV3AlertModal/SwiftUI")
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    func testSwiftUIBackendContainsNoUIKitImportsOrRuntimeSymbols() throws {
        let forbidden = [
            "GBAlertModal", "UIKitModalRenderer", "UIView", "UIImage", "UIColor", "UIFont",
            "UIDatePicker", "UIWindow", "UIApplication", "UIHostingController"
        ]
        var offenders: [String] = []

        for file in swiftUIFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            let code = source.split(separator: "\n").filter {
                !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
            }.joined(separator: "\n")
            if code.contains("import UIKit") {
                offenders.append("\(file.lastPathComponent): import UIKit")
            }
            for symbol in forbidden where code.range(of: "\\b\(symbol)\\b", options: .regularExpression) != nil {
                offenders.append("\(file.lastPathComponent): \(symbol)")
            }
        }

        XCTAssertEqual(offenders, [], offenders.joined(separator: "\n"))
    }
}
