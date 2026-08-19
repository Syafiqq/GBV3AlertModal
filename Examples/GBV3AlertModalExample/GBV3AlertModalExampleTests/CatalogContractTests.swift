import Testing
@testable import GBV3AlertModalExample

struct CatalogContractTests {
    @MainActor
    @Test func backendsExposeTheSameSeventyUniqueEntries() {
        let uiKit = GalleryViewController.allEntries.map(\.name)
        let swiftUI = SwiftUICatalog.entries.map(\.name)

        #expect(Set(uiKit) == Set(swiftUI))
        #expect(uiKit.count == Set(uiKit).count, "UIKit catalog contains duplicate keys")
        #expect(swiftUI.count == Set(swiftUI).count, "SwiftUI catalog contains duplicate keys")
        #expect(SwiftUICatalog.entries.count == 70)
    }
}
