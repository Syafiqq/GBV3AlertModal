// SwiftUIDemoScreenSmokeTests.swift
import SwiftUI
import UIKit
import XCTest
import GBV3AlertModal
@testable import GBV3AlertModalExample

@MainActor
final class SwiftUIDemoScreenSmokeTests: XCTestCase {

    private func layoutPass(_ window: UIWindow) {
        window.setNeedsLayout()
        window.layoutIfNeeded()
    }

    /// Pure-SwiftUI content (e.g. `Text`) renders straight to `CALayer` sublayers on this SDK
    /// without necessarily creating a child `UIView` — only UIKit-interop content (e.g. a
    /// `ProgressView`'s backing `UIActivityIndicatorView`) shows up in `.subviews`. Checking
    /// either confirms the hosting controller actually built non-trivial content.
    private func hasBuiltViewGraph(_ view: UIView) -> Bool {
        !view.subviews.isEmpty || !(view.layer.sublayers ?? []).isEmpty
    }

    func test_demoScreen_builds() {
        let host = UIHostingController(rootView: SwiftUIDemoScreen())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        layoutPass(window)
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty)
        XCTAssertTrue(hasBuiltViewGraph(host.view))
    }

    func test_gallery_exposes_swiftui_entry_point() {
        let gallery = GalleryViewController()
        gallery.loadViewIfNeeded()           // triggers viewDidLoad
        XCTAssertNotNil(
            gallery.navigationItem.rightBarButtonItem,
            "gallery should expose a nav-bar button to reach the SwiftUI demo"
        )
    }

    /// Asserts the entry points BY TITLE rather than by count. The count form failed the moment a
    /// fourth entry point was added and said only "expected 3, got 4" — which is true of both an
    /// accidental extra button and a deliberate one, and names neither.
    func test_gallery_exposes_its_entry_points() {
        let gallery = GalleryViewController()
        gallery.loadViewIfNeeded()
        let titles = (gallery.navigationItem.rightBarButtonItems ?? []).compactMap(\.title)
        XCTAssertEqual(
            titles, [
                "SwiftUI", "Tier 0", "Tier 1", "Embedded", "Window", "SwiftUI Catalog",
                "Embedded Catalog", "Window Catalog"
            ],
            "the gallery's entry points changed. 'Tier 1' is the AdoptionScreen — VM → executor → "
                + "coordinator → SwiftUIModalRenderer, the whole chain assembled as a consumer would. "
                + "'Embedded' is EmbeddedAdoptionScreen — the same chain over the UIKit-free "
                + "EmbeddedModalRenderer (mainUIRenderer). 'Window' reuses Tier0DemoScreen over "
                + "WindowModalRenderer (rootRenderer) — both from iridescent-enchanting-pike.md's plan. "
                + "'Embedded Catalog'/'Window Catalog' are the 26-real-shape visual browsers for those "
                + "two renderers, reusing SwiftUICatalog.dialogEntries unchanged — the eyes-on-screen "
                + "half of what EmbeddedShapeCoverageTests/WindowShapeCoverageTests prove structurally."
        )
    }

    /// **The under-delivery gate for the SwiftUI gallery.** It must list the SAME
    /// shapes as the UIKit `DialogCatalog`, by name and in the same order, so the
    /// two galleries are comparable entry-for-entry — and every entry must either
    /// be presentable or carry a visible "not yet renderable" reason. A gallery
    /// that quietly lists 23 of 26 is worse than one that shows 26 with 3 marked
    /// broken, so both halves are asserted here.
    func test_swiftui_catalog_mirrors_the_dialog_catalog_entry_for_entry() {
        XCTAssertEqual(SwiftUICatalog.dialogEntries.count, 26, "the catalog defines exactly 26 dialog shapes")
        XCTAssertEqual(
            SwiftUICatalog.dialogEntries.map(\.name),
            DialogCatalog.entries.map(\.name),
            "the SwiftUI gallery must mirror the UIKit gallery name-for-name, in catalog order"
        )

        for entry in SwiftUICatalog.entries {
            XCTAssertEqual(
                entry.present == nil,
                entry.notRenderableReason != nil,
                "\(entry.name): an entry with no present closure MUST show a reason, and vice versa"
            )
        }

        XCTAssertEqual(
            SwiftUICatalog.dialogEntries.filter { $0.present != nil }.count, 26,
            "all 26 shapes present on the SwiftUI backend today — if that ever drops, the gallery must SHOW "
                + "the gap (notRenderableReason), never omit the row"
        )
    }

    /// **Exactly ONE `notRenderable` row remains, and it is a decision rather than a limit.**
    ///
    /// There were nine. Six were `StandardAlertContent.primary` being a non-optional `String`, two
    /// were a descriptor having nowhere to put button enable-state; Pass 2 closed both. The ninth,
    /// `variant-subtitle-customview`, is left deliberately: fixing it means a `ModalDescriptor` that
    /// carries a live `UIView`, which costs the `Sendable` conformance the whole descriptor design
    /// rests on, and `register(_:view:)` already serves the real use case.
    ///
    /// Asserted BY NAME, not by count. A count alone passes if this row is quietly fixed while some
    /// other row breaks — which is the exact substitution the gallery's honesty rule exists to stop.
    func test_theOnlyUnrenderableShape_isTheOneWeDecidedNotToBuild() {
        XCTAssertEqual(
            SwiftUICatalog.entries.filter { $0.notRenderableReason != nil }.map(\.name),
            ["variant-subtitle-customview"]
        )
    }

    /// Tier 0: the SwiftUI screen builds with a real executor injected (no SwiftUI modal of its own).
    func test_tier0_demo_screen_builds() {
        let executor = DefaultModalExecutor(renderer: UIKitModalRenderer(alertProperties: GBAlertModal.Properties()))
        let host = UIHostingController(rootView: Tier0DemoScreen(executor: executor))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        layoutPass(window)
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty)
        XCTAssertTrue(hasBuiltViewGraph(host.view))
    }

    /// Tier 0 end-to-end from the VM: `confirmDelete()` presents a UIKit modal through the executor,
    /// and resolving that modal (user taps primary) flows the result back into `lastResult`.
    func test_tier0_vm_presents_and_resolves_result() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let renderer = UIKitModalRenderer(
            alertProperties: GBAlertModal.Properties(primaryActionStyle: .capsule(.init(backgroundColor: .systemBlue))),
            windowProvider: { window }
        )
        let vm = Tier0DemoViewModel(executor: DefaultModalExecutor(renderer: renderer))

        let task = Task { await vm.confirmDelete() }
        var modal: GBAlertModal?
        for _ in 0..<200 {
            modal = firstDescendant(GBAlertModal.self, in: window)
            if modal != nil { break }
            await Task.yield()
        }
        XCTAssertNotNil(modal, "VM.confirmDelete() should present a UIKit modal through the executor")

        modal?.dismissAndEmit(event: .primary)   // user taps primary
        await task.value
        XCTAssertEqual(vm.lastResult, "primary")
    }

    private func firstDescendant<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        for sub in view.subviews {
            if let hit = sub as? T { return hit }
            if let deep = firstDescendant(type, in: sub) { return deep }
        }
        return nil
    }

    // MARK: new stateful demo cases

    /// The "loading button" (Gc2Gs) case: the demo screen's fixture, hosted through
    /// `SwiftUIAlertModal` with `isPrimaryLoading: true`, mirrors the mid-flight render.
    func test_loading_demo_fixture_builds_with_spinner_state() {
        let host = UIHostingController(
            rootView: SwiftUIAlertModal(config: SwiftUIDemoScreen.demoLoading, isPrimaryLoading: true) { _ in }
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        layoutPass(window)
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty)
        XCTAssertTrue(hasBuiltViewGraph(host.view))
    }

    /// The validation-gate (Satisfaction) case: a bespoke view, not a config render.
    func test_satisfaction_demo_view_builds() {
        let host = UIHostingController(rootView: SatisfactionDemoView { _ in })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        layoutPass(window)
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty)
        XCTAssertTrue(hasBuiltViewGraph(host.view))
    }
}
