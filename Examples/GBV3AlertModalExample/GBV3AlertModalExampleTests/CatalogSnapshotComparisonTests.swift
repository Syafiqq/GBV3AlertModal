import SnapshotTesting
import SwiftUI
import UIKit
import XCTest
import GBV3AlertModal
@testable import GBV3AlertModalExample

/// Full-page visual evidence for every example exposed by either catalog backend.
/// The HTML report joins these snapshots by the catalogs' stable entry names.
@MainActor
final class CatalogSnapshotComparisonTests: XCTestCase {
    private let canvas = CGRect(x: 0, y: 0, width: 390, height: 844)

    func testEveryUIKitExample() {
        for entry in GalleryViewController.allEntries {
            autoreleasepool {
                let rootView = UIView(frame: canvas)
                rootView.backgroundColor = .white
                let modal = entry.make()
                modal.show(parent: rootView, completion: {})
                rootView.setNeedsLayout()
                rootView.layoutIfNeeded()

                verifyCatalogSnapshot(
                    renderedImage(of: rootView),
                    entryName: entry.name,
                    testName: "testEveryUIKitExample"
                )
                modal.removeFromSuperview()
            }
        }
    }

    func testEverySwiftUIExample() {
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        host.view.frame = canvas
        host.view.backgroundColor = .clear
        let window = UIWindow(frame: canvas)
        window.rootViewController = host
        window.makeKeyAndVisible()

        for entry in SwiftUICatalog.entries {
            autoreleasepool {
                snapshotSwiftUI(entry, using: host, in: window)
            }
        }

        host.rootView = AnyView(EmptyView())
        advanceMainRunLoop()
        window.isHidden = true
        window.rootViewController = nil
        advanceMainRunLoop()
    }

    private func snapshotSwiftUI(
        _ entry: SwiftUICatalogEntry,
        using host: UIHostingController<AnyView>,
        in window: UIWindow
    ) {
        let model = SwiftUICatalogModel(initialEntryName: entry.name)
        guard let index = SwiftUICatalog.index(ofEntryNamed: entry.name) else {
            XCTFail("Missing SwiftUI catalog index for \(entry.name)")
            return
        }
        model.present(at: index)
        waitForPresentation(in: model.renderer, key: entry.name)

        let view = ModalHost(renderer: model.renderer) {
            Color.white
        }
        .environment(\.colorScheme, .light)
        .frame(width: canvas.width, height: canvas.height)
        .ignoresSafeArea()

        let image = renderedImage(of: view, using: host, in: window)
        verifyCatalogSnapshot(
            image,
            entryName: entry.name,
            testName: "testEverySwiftUIExample"
        )
        model.dismissCurrent()
        host.rootView = AnyView(EmptyView())
        host.view.layoutIfNeeded()
    }

    func testCatalogPairingContract() {
        let uikit = GalleryViewController.allEntries.map(\.name)
        let swiftUI = SwiftUICatalog.entries.map(\.name)
        XCTAssertEqual(Set(uikit), Set(swiftUI))
        XCTAssertEqual(uikit.count, Set(uikit).count, "UIKit catalog contains duplicate keys")
        XCTAssertEqual(swiftUI.count, Set(swiftUI).count, "SwiftUI catalog contains duplicate keys")
        XCTAssertEqual(SwiftUICatalog.entries.count, 70)
    }

    private func renderedImage(of view: UIView) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { context in
            view.layer.render(in: context.cgContext)
        }
    }

    private func renderedImage<Content: View>(
        of content: Content,
        using host: UIHostingController<AnyView>,
        in window: UIWindow
    ) -> UIImage {
        host.rootView = AnyView(content)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        // `SubtitleSlot` publishes its measured ideal size on the next main-run-loop turn. Await
        // that event explicitly instead of guessing how many milliseconds the simulator needs.
        advanceMainRunLoop()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        window.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func waitForPresentation(in renderer: SwiftUIModalRenderer, key: String) {
        for _ in 0..<100 where renderer.presentations.isEmpty {
            advanceMainRunLoop()
        }
        XCTAssertEqual(renderer.presentations.count, 1, "\(key) did not publish one presentation")
    }

    private func advanceMainRunLoop() {
        let advanced = expectation(description: "Advance the main run loop")
        DispatchQueue.main.async { advanced.fulfill() }
        wait(for: [advanced], timeout: 1)
    }

    private func verifyCatalogSnapshot(_ image: UIImage, entryName: String, testName: String) {
        if let failure = verifySnapshot(
            of: image,
            as: .image,
            named: entryName,
            testName: testName
        ) {
            XCTFail("Catalog entry '\(entryName)' failed snapshot verification:\n\(failure)")
        }
    }
}
