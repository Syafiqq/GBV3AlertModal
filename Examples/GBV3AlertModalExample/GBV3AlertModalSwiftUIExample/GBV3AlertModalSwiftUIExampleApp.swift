import SwiftUI

@main
struct GBV3AlertModalSwiftUIExampleApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                SwiftUICatalogScreen(
                    initialEntryName: ProcessInfo.processInfo.environment["GB_SWIFTUI_ENTRY"]
                )
            }
        }
    }
}
