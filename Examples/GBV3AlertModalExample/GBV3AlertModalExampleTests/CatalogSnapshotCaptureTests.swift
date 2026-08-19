import Foundation
import SwiftUI
import Testing
import UIKit
import GBV3AlertModal
@testable import GBV3AlertModalExample

/// Generates review artifacts only. No image is compared with a baseline.
struct CatalogSnapshotCaptureTests {
    private let canvas = CGRect(x: 0, y: 0, width: 390, height: 844)

    @MainActor
    @Test func captureEveryCatalogEntry() async throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let output = repositoryRoot.appendingPathComponent(
            ".build/reports/catalog-snapshots",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try captureUIKitEntries(to: output)
        try await captureSwiftUIEntries(to: output)
    }

    @MainActor
    private func captureUIKitEntries(to output: URL) throws {
        for entry in GalleryViewController.allEntries {
            try autoreleasepool {
                let rootView = UIView(frame: canvas)
                rootView.backgroundColor = .white
                let modal = entry.make()
                modal.show(parent: rootView, completion: {})
                rootView.layoutIfNeeded()
                try write(renderedImage(of: rootView), side: "uikit", key: entry.name, to: output)
                modal.removeFromSuperview()
            }
        }
    }

    @MainActor
    private func captureSwiftUIEntries(to output: URL) async throws {
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        host.view.frame = canvas
        host.view.backgroundColor = .clear
        let window = UIWindow(frame: canvas)
        window.rootViewController = host
        window.makeKeyAndVisible()

        for entry in SwiftUICatalog.entries {
            let model = SwiftUICatalogModel(initialEntryName: entry.name)
            guard let index = SwiftUICatalog.index(ofEntryNamed: entry.name) else {
                throw CaptureError.missingCatalogEntry(entry.name)
            }
            model.present(at: index)
            for _ in 0..<100 where model.renderer.presentations.isEmpty {
                await advanceMainRunLoop()
            }
            guard model.renderer.presentations.count == 1 else {
                throw CaptureError.presentationCount(entry.name, model.renderer.presentations.count)
            }

            host.rootView = AnyView(
                ModalHost(renderer: model.renderer) { Color.white }
                    .environment(\.colorScheme, .light)
                    .frame(width: canvas.width, height: canvas.height)
                    .ignoresSafeArea()
            )
            host.view.layoutIfNeeded()
            await advanceMainRunLoop()
            host.view.layoutIfNeeded()
            window.layoutIfNeeded()
            try write(renderedImage(of: window), side: "swiftui", key: entry.name, to: output)

            model.dismissCurrent()
            host.rootView = AnyView(EmptyView())
            host.view.layoutIfNeeded()
        }

        window.isHidden = true
        window.rootViewController = nil
    }

    @MainActor
    private func advanceMainRunLoop() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    @MainActor
    private func renderedImage(of view: UIView) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { context in
            view.layer.render(in: context.cgContext)
        }
    }

    @MainActor
    private func renderedImage(of window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func write(_ image: UIImage, side: String, key: String, to output: URL) throws {
        guard key.range(of: #"^[a-zA-Z0-9._-]+$"#, options: .regularExpression) != nil else {
            throw CaptureError.invalidEntryName(key)
        }
        guard let data = image.pngData() else { throw CaptureError.pngEncoding(key) }
        try data.write(to: output.appendingPathComponent("\(side).\(key).png"), options: .atomic)
    }
}

private enum CaptureError: Error {
    case invalidEntryName(String)
    case missingCatalogEntry(String)
    case pngEncoding(String)
    case presentationCount(String, Int)
}
