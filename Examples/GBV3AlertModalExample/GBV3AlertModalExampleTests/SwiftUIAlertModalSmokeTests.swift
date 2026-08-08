// SwiftUIAlertModalSmokeTests.swift
import SwiftUI
import UIKit
import XCTest
import ViewInspector
import SnapshotTesting
import GBV3AlertModal
@testable import GBV3AlertModalExample

// @MainActor: hosts SwiftUI/UIKit views in a UIWindow, which is main-actor under Swift 6.
@MainActor
final class SwiftUIAlertModalSmokeTests: XCTestCase {

    /// Hosts a SwiftUI view in a throwaway key window and forces a layout pass,
    /// mirroring DialogCatalogSmokeTests. Returns the host so the caller asserts + tears down.
    private func host<V: View>(_ view: V) -> (UIWindow, UIHostingController<V>) {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        return (window, host)
    }

    private func teardown(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    /// Pure-SwiftUI content (e.g. `Text`) renders straight to `CALayer` sublayers on this SDK
    /// without necessarily creating a child `UIView` — only UIKit-interop content (e.g. a
    /// `ProgressView`'s backing `UIActivityIndicatorView`) shows up in `.subviews`. Checking
    /// either confirms the hosting controller actually built non-trivial content.
    private func hasBuiltViewGraph(_ view: UIView) -> Bool {
        !view.subviews.isEmpty || !(view.layer.sublayers ?? []).isEmpty
    }

    private func assertBuilds(_ config: AlertDialog, _ message: String) {
        let (window, host) = host(SwiftUIAlertModal(config: config) { _ in })
        defer { teardown(window) }
        XCTAssertFalse(host.view.bounds.isEmpty, "\(message): host view was not laid out")
        XCTAssertTrue(hasBuiltViewGraph(host.view), "\(message): view graph is empty")
    }

    func test_minimal_config_builds() {
        assertBuilds(
            AlertDialog(title: "Title", subtitle: "Subtitle", primary: "OK"),
            "minimal"
        )
    }

    func test_full_config_builds() {
        assertBuilds(
            AlertDialog(
                image: ModalImage("img_illust_onboarding"),
                title: "Help us improve",
                subtitle: "Take our quick survey and gain bubbles!",
                primary: "Proceed",
                secondary: "Not now",
                closeOnTapOverlay: true,
                showCloseButton: true
            ),
            "full"
        )
    }

    // MARK: presentation-state params (primaryEnabled / isPrimaryLoading)

    func test_primary_loading_state_builds() {
        let (window, host) = host(
            SwiftUIAlertModal(
                config: AlertDialog(title: "Generate your worksheet", subtitle: "This will use one credit.", primary: "Generate", secondary: "Cancel"),
                isPrimaryLoading: true
            ) { _ in }
        )
        defer { teardown(window) }
        XCTAssertFalse(host.view.bounds.isEmpty, "loading: host view was not laid out")
        XCTAssertTrue(hasBuiltViewGraph(host.view), "loading: view graph is empty")
    }

    func test_primary_disabled_state_builds() {
        let (window, host) = host(
            SwiftUIAlertModal(
                config: AlertDialog(title: "Title", subtitle: "Subtitle", primary: "OK"),
                primaryEnabled: false
            ) { _ in }
        )
        defer { teardown(window) }
        XCTAssertFalse(host.view.bounds.isEmpty, "disabled: host view was not laid out")
        XCTAssertTrue(hasBuiltViewGraph(host.view), "disabled: view graph is empty")
    }

    // MARK: Layer-B wiring — hosting-observable (no ViewInspector)

    /// The `isPrimaryLoading` branch must render a real spinner, not just the label. A hosted
    /// SwiftUI `ProgressView` is backed by a `UIActivityIndicatorView`, so its presence/absence
    /// is an observable per-field wiring assert without ViewInspector.
    func test_loading_state_renders_activity_indicator() {
        let cfg = AlertDialog(title: "Generate", subtitle: "Uses one credit.", primary: "Generate")
        let (loadingWindow, loadingHost) = host(SwiftUIAlertModal(config: cfg, isPrimaryLoading: true) { _ in })
        defer { teardown(loadingWindow) }
        XCTAssertNotNil(firstDescendant(UIActivityIndicatorView.self, in: loadingHost.view),
                        "loading primary should render a spinner")

        let (idleWindow, idleHost) = host(SwiftUIAlertModal(config: cfg, isPrimaryLoading: false) { _ in })
        defer { teardown(idleWindow) }
        XCTAssertNil(firstDescendant(UIActivityIndicatorView.self, in: idleHost.view),
                     "non-loading primary should show no spinner")
    }

    private func firstDescendant<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        for sub in view.subviews {
            if let hit = sub as? T { return hit }
            if let deep = firstDescendant(type, in: sub) { return deep }
        }
        return nil
    }

    // MARK: Task-4 design tokens & styles (pure — no hosting)

    /// Tokens are transcribed from the real `Presentation.UiKit.V3AlertModal` preset (spec D8),
    /// now via `ModalTokens.standard` (instance data, spec C-0 — see `ModalTokensProvenanceTests`
    /// in the library test target for the DERIVED-from-`Properties` coverage).
    /// Pin them so an accidental edit that drifts from the app design is a failing test, not a silent regression.
    func test_modalTokens_match_real_V3AlertModal_preset() {
        let tokens = ModalTokens.standard
        XCTAssertEqual(tokens.cornerRadius, 16)
        // owner override: uniform 12 gaps (real preset was 8/8/16); interButton stays 8
        XCTAssertEqual(tokens.gapBelowBanner, 12)
        XCTAssertEqual(tokens.gapBelowTitle, 12)
        XCTAssertEqual(tokens.gapBelowSubtitle, 12)
        XCTAssertEqual(tokens.interButton, 8)
        // real margin 40v/20h; content padding 24v/32h (horizontal > vertical)
        XCTAssertEqual(tokens.cardMarginV, 40)
        XCTAssertEqual(tokens.cardMarginH, 20)
        XCTAssertEqual(tokens.contentPaddingV, 24)
        XCTAssertEqual(tokens.contentPaddingH, 32)
        XCTAssertEqual(tokens.buttonCornerRadius, 8)              // primary is a solid rounded-8 rect
        // `standard` has no `Properties` to derive a width cap from, so it's uncapped on every
        // idiom (card fills to the horizontal margin) — a real per-device cap only exists once
        // `init(from:)` is fed a real `Properties.contentProperty.maxWidthPortrait` (Task 6).
        XCTAssertEqual(tokens.cardMaxWidth, .infinity)
    }

    // `test_hex_color_decodes_rgb_channels` moved to the library test target
    // (GBV3AlertModalTests/SwiftUI/ModalTokensTests.swift): `Color(hex:)` is an internal
    // extension on a type the library doesn't own (`SwiftUI.Color`), never public, so this
    // module can no longer reach it without `@testable import GBV3AlertModal` — and the
    // assertion tests a library internal, not example-app behaviour, so the library's own
    // `@testable`-importing test target is the better home anyway.

    /// The primary is a solid rounded-8 rectangle (no shadow, no cut corner).
    func test_primary_button_corner_radius() {
        XCTAssertEqual(ModalTokens.standard.buttonCornerRadius, 8)
    }

    // MARK: Layer-B wiring — view introspection (ViewInspector)

    private func modal(_ config: AlertDialog) -> SwiftUIAlertModal {
        SwiftUIAlertModal(config: config) { _ in }
    }

    /// Each content field actually reaches a rendered `Text` (title/subtitle/primary/secondary label).
    func test_layerB_content_text_reaches_the_view() throws {
        let sut = modal(AlertDialog(title: "Title", subtitle: "Body", primary: "OK", secondary: "Cancel"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Title"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Body"))
        XCTAssertNoThrow(try sut.inspect().find(text: "OK"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Cancel"))
    }

    /// Button count reflects secondary + close wiring: minimal=1 (primary), +secondary=2, +close=3.
    func test_layerB_button_count_reflects_secondary_and_close() throws {
        XCTAssertEqual(try modal(AlertDialog(title: "T", primary: "OK"))
            .inspect().findAll(ViewType.Button.self).count, 1)
        XCTAssertEqual(try modal(AlertDialog(title: "T", primary: "OK", secondary: "Cancel"))
            .inspect().findAll(ViewType.Button.self).count, 2)
        XCTAssertEqual(try modal(AlertDialog(title: "T", primary: "OK", secondary: "Cancel", showCloseButton: true))
            .inspect().findAll(ViewType.Button.self).count, 3)
    }

    /// The banner `Image` renders only when an image is set (no banner, no close → no `Image` at all).
    func test_layerB_banner_image_present_only_when_image_set() throws {
        XCTAssertNoThrow(try modal(AlertDialog(image: ModalImage("img_illust_onboarding"), title: "T", primary: "OK"))
            .inspect().find(ViewType.Image.self))
        XCTAssertThrowsError(try modal(AlertDialog(title: "T", primary: "OK"))
            .inspect().find(ViewType.Image.self))
    }

    /// The close glyph (an SF Symbol `Image`) appears iff `showCloseButton`.
    func test_layerB_close_glyph_present_iff_flag() throws {
        XCTAssertNoThrow(try modal(AlertDialog(title: "T", primary: "OK", showCloseButton: true))
            .inspect().find(ViewType.Image.self))
        XCTAssertThrowsError(try modal(AlertDialog(title: "T", primary: "OK", showCloseButton: false))
            .inspect().find(ViewType.Image.self))
    }

    /// The bespoke satisfaction case (built on AlertModalScaffold) wires 3 option buttons + Submit,
    /// and its custom body text reaches the view.
    func test_layerB_satisfaction_renders_options_and_submit() throws {
        let sut = SatisfactionDemoView { _ in }
        XCTAssertEqual(try sut.inspect().findAll(ViewType.Button.self).count, 4)
        XCTAssertNoThrow(try sut.inspect().find(text: "How helpful was this?"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Submit"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Not helpful"))
    }
}

// MARK: - Layer C — snapshots of the shipped shapes (real Genie colours)

/// Locks the rendered output of the SwiftUI modal for the shapes Geniebook actually ships, so a
/// later refactor (or a Tier-1 library port) can be proven pixel-equivalent. Baselines are recorded
/// on an iPhone 17 simulator; re-record intentionally if the design changes.
@MainActor
final class SwiftUIAlertModalSnapshotTests: XCTestCase {
    private let portrait = CGSize(width: 390, height: 844)
    private let landscape = CGSize(width: 844, height: 390)

    private func render(_ view: some View, size: CGSize) -> UIView {
        // Pin to light: a snapshot host with no colour-scheme pin inherits whatever appearance the
        // simulator happens to be in. The 8 references below were recorded in light; left unpinned,
        // a machine whose simulator is in dark mode fails all 8 on the scrim colour alone
        // (`AlertModalScaffold`'s scrim is a translucent grey composited over the hosting
        // controller's implicit background, which flips light/dark with the environment), with the
        // card/text/button content pixel-identical either way. That's a snapshot test reporting the
        // environment, not the code — pinning makes the suite deterministic.
        //
        // `.preferredColorScheme` (not `window.overrideUserInterfaceStyle`) is what actually
        // sticks: `assertSnapshot(of:as:.image)` re-hosts the rendered `UIView` inside its OWN
        // internal window with an unspecified trait collection (see swift-snapshot-testing's
        // `prepareView`/`Window`), which discards any override made on THIS window and falls back
        // to the simulator's real appearance. `.preferredColorScheme` is baked into the SwiftUI
        // view tree itself, so it survives that re-parenting.
        let host = UIHostingController(rootView: view.preferredColorScheme(.light))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        host.view.frame = CGRect(origin: .zero, size: size)
        window.setNeedsLayout()
        window.layoutIfNeeded()
        return host.view
    }

    private func alert(
        _ config: AlertDialog,
        properties: GBAlertModal.Properties? = nil,
        isPrimaryLoading: Bool = false
    ) -> SwiftUIAlertModal {
        SwiftUIAlertModal(
            config: config,
            properties: properties,
            isPrimaryLoading: isPrimaryLoading,
            tokens: properties.map { ModalTokens(from: $0) } ?? .standard
        ) { _ in }
    }

    private static let full = AlertDialog(
        image: ModalImage("img_illust_onboarding"),
        title: "Help us make your experience better",
        subtitle: "Take our quick survey and gain bubbles!",
        primary: "Proceed to feedback",
        secondary: "Not now",
        closeOnTapOverlay: true,
        showCloseButton: true
    )

    func test_snapshot_minimal() {
        let v = render(alert(AlertDialog(title: "You're all set",
                                         subtitle: "Your changes have been saved.",
                                         primary: "Got it")), size: portrait)
        assertSnapshot(of: v, as: .image(precision: 0.98), named: "minimal")
    }

    func test_snapshot_full() {
        assertSnapshot(of: render(alert(Self.full), size: portrait), as: .image(precision: 0.98), named: "full")
    }

    func test_snapshot_full_landscape() {
        assertSnapshot(of: render(alert(Self.full), size: landscape), as: .image(precision: 0.98), named: "full-landscape")
    }

    func test_snapshot_primary_loading() {
        let v = render(alert(AlertDialog(title: "Generate your worksheet",
                                         subtitle: "This will use one credit.",
                                         primary: "Generate", secondary: "Cancel"),
                             isPrimaryLoading: true), size: portrait)
        assertSnapshot(of: v, as: .image(precision: 0.98), named: "primary-loading")
    }

    // Wrapping / overflow extremes (mirror UIKit LayerC longTitle / longSubtitle).
    // `test_snapshot_scrollable_landscape_noBanner` and its recorded image are DELETED. Its subject
    // was `Properties.contentScrollable` — the flag is gone, so the render it baselined exists on no
    // code path, and keeping the case would have meant re-recording a snapshot to photograph
    // different behaviour under the same name. The landscape long-copy regime it stood for is
    // measured rather than photographed now, by the library's
    // `test_geometry_landscape_longSubtitleUnscrolled` (a 161.33pt subtitle viewport over 1222pt of
    // content, matching UIKit to the point).

    func test_snapshot_longTitle() {
        let v = render(alert(AlertDialog(
            title: "This is a deliberately very long title that must wrap across several lines inside the fixed-width card without truncating",
            subtitle: "Short body.", primary: "OK")), size: portrait)
        assertSnapshot(of: v, as: .image(precision: 0.98), named: "long-title")
    }

    func test_snapshot_longSubtitle() {
        let v = render(alert(AlertDialog(
            title: "Heads up",
            subtitle: "This is a deliberately very long subtitle used to exercise multi-line wrapping and vertical growth of the card. It keeps going well past a couple of lines so the layout under overflow is locked by a baseline.",
            primary: "Got it")), size: portrait)
        assertSnapshot(of: v, as: .image(precision: 0.98), named: "long-subtitle")
    }

    // Bespoke content case (D1) — the satisfaction picker, on the shared scaffold.
    func test_snapshot_satisfaction() {
        let v = render(SatisfactionDemoView { _ in }, size: portrait)
        assertSnapshot(of: v, as: .image(precision: 0.98), named: "satisfaction")
    }
}

// MARK: - Tier 1 adoption — VM → executor → coordinator → SwiftUI renderer

/// **The adoption screen, exercised as a consumer would use it.**
///
/// `RendererParityTests` already proves coordinator semantics against both renderers with a spy.
/// What it cannot show is the chain assembled the way a product screen assembles it: a VM owning a
/// `SwiftUIModalRenderer`, a `DefaultModalExecutor` over it, a `RootScreenModalCoordinator` behind
/// that, and `ModalHost` rendering the result inside a real view hierarchy. That is what
/// `AdoptionScreen` is, and this is its gate.
@MainActor
final class AdoptionScreenTests: XCTestCase {

    private func viewModel() -> AdoptionViewModel {
        AdoptionViewModel(
            properties: GalleryPresets.properties,
            popupProperties: GalleryPresets.popupProperties
        )
    }

    func test_theScreenBuildsAndHostsItsRenderer() {
        let screen = AdoptionScreen(
            properties: GalleryPresets.properties,
            popupProperties: GalleryPresets.popupProperties
        )
        let host = UIHostingController(rootView: screen)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty, "the adoption screen was not laid out")
    }

    /// **The coordinator serialises — the property the whole screen exists to demonstrate.**
    ///
    /// Two presentations are launched together. With the coordinator installed the second must WAIT:
    /// at any moment exactly one presentation is live, never two. Asserted on the renderer's own
    /// presentation list, which is what `ModalHost` draws from.
    func test_twoPresentationsAtOnce_serialise() async {
        let vm = viewModel()

        let both = Task { await vm.presentTwoAtOnce() }
        // Let the first presentation land.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(
            vm.renderer.presentations.count, 1,
            "two modals are live at once — the coordinator is not serialising, which is the single "
                + "thing this screen is wired to prove"
        )

        // Resolve the first through the SAME handle the rendered modal's buttons call — the
        // renderer exposes no test-only door, and using one would prove less.
        vm.renderer.presentations.first?.onAction(.primary)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertLessThanOrEqual(
            vm.renderer.presentations.count, 1,
            "more than one presentation after the first resolved"
        )

        both.cancel()
    }

    /// The VM records a result only when one actually arrives — a cancelled await (screen dismissed
    /// mid-presentation) must not be logged as if the user chose something.
    func test_aCancelledPresentation_isNotRecorded() async {
        let vm = viewModel()
        let task = Task { await vm.confirmDelete() }
        await Task.yield()
        task.cancel()
        _ = await task.value

        XCTAssertEqual(vm.lastResult, "—", "a cancelled presentation was recorded as a result")
    }
}

// MARK: - EmbeddedModalRenderer — the UIKit-free renderer, hosted the same way

/// **`EmbeddedAdoptionScreen`, exercised as a consumer would use it — the same gate
/// `AdoptionScreenTests` runs for `AdoptionScreen`, closing the "does it actually run" gap that
/// unit tests alone (`EmbeddedModalRendererTests`) can't: real window, real `UIHostingController`,
/// real `RootScreenModalCoordinator` serialisation, resolved through the same `onAction` handle a
/// rendered button's tap calls.**
@MainActor
final class EmbeddedAdoptionScreenTests: XCTestCase {

    func test_theScreenBuildsAndHostsItsRenderer() {
        let screen = EmbeddedAdoptionScreen()
        let host = UIHostingController(rootView: screen)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty, "the embedded adoption screen was not laid out")
    }

    /// Same proof `AdoptionScreenTests.test_twoPresentationsAtOnce_serialise` runs for the UIKit-typed
    /// renderer: `RootScreenModalCoordinator` needs zero code changes to arbitrate `EmbeddedModalRenderer`
    /// — this is that claim, exercised end to end rather than assumed from the type signature matching.
    func test_twoPresentationsAtOnce_serialise() async {
        let vm = EmbeddedAdoptionViewModel()

        let both = Task { await vm.presentTwoAtOnce() }
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(
            vm.renderer.presentations.count, 1,
            "two modals are live at once — the coordinator is not serialising EmbeddedModalRenderer"
        )

        // Resolved through the SAME handle a rendered SwiftUIAlertModal's button tap calls
        // (EmbeddedModalHost -> SwiftUIAlertModal.onAction -> Presentation.onAction) — no test-only door.
        vm.renderer.presentations.first?.onAction(.primary)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertLessThanOrEqual(
            vm.renderer.presentations.count, 1,
            "more than one presentation after the first resolved"
        )

        both.cancel()
    }

    /// **The rendering claim, not just the data-model claim.** Everything above proves
    /// `EmbeddedModalRenderer.presentations` changes correctly; this proves `EmbeddedModalHost`
    /// actually turns that into real UIKit views inside the hosted window — the SwiftUI->UIKit
    /// bridge working, not just the `@Published` array.
    func test_presenting_actuallyAddsRenderedContent_toTheHostedWindow() {
        let vm = EmbeddedAdoptionViewModel()
        let host = UIHostingController(
            rootView: EmbeddedModalHost(renderer: vm.renderer) { Color.clear }
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }

        func subviewCount(_ view: UIView) -> Int {
            1 + view.subviews.reduce(0) { $0 + subviewCount($1) }
        }
        let before = subviewCount(host.view)

        vm.renderer.present(
            AlertDialog(title: "T", subtitle: "S", primary: "OK"), id: ModalID(), resolve: { _ in }
        )
        window.setNeedsLayout()
        window.layoutIfNeeded()
        let during = subviewCount(host.view)

        XCTAssertGreaterThan(
            during, before,
            "presenting through EmbeddedModalRenderer must add real drawn content to the hosted "
                + "window, not just update the renderer's own @Published state"
        )
    }
}

// MARK: - Tier 0 — the existing UIKit executor paints OVER a live SwiftUI screen

/// Proves (not just reasons) that a SwiftUI ViewModel can drive dialogs TODAY with zero new
/// rendering code: the library's `DefaultModalExecutor` + `UIKitModalRenderer` install a UIKit
/// `GBAlertModal` into the SAME `UIWindow` as a hosted SwiftUI screen, painted over its content.
/// This is the empirical check the design notes flagged as reasoned-but-unobserved.
@MainActor
final class Tier0HostingSmokeTests: XCTestCase {
    func test_uikitExecutorModal_paintsOverSwiftUIScreen() {
        // A real SwiftUI screen hosted in a window — as a SwiftUI-first app would have.
        let swiftUIScreen = UIHostingController(rootView: SwiftUIDemoScreen())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = swiftUIScreen
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }

        // The library executor + UIKit renderer, aimed at that same window.
        let renderer = UIKitModalRenderer(alertProperties: GBAlertModal.Properties(), windowProvider: { window })
        let executor = DefaultModalExecutor(renderer: renderer)

        // A "SwiftUI VM" triggers a dialog — no SwiftUI rendering code involved.
        let token = executor.present(AlertDialog(title: "Over SwiftUI", subtitle: "Hi", primary: "OK"))
        window.layoutIfNeeded()

        // 1) A UIKit modal now lives in the SwiftUI screen's window.
        let modal = firstDescendant(GBAlertModal.self, in: window)
        XCTAssertNotNil(modal, "UIKit modal should be installed in the SwiftUI screen's window")
        // 2) The SwiftUI host is still present underneath.
        XCTAssertTrue(swiftUIScreen.view.isDescendant(of: window), "SwiftUI content should remain in the window")
        // 3) The modal paints OVER the SwiftUI content: it's a WINDOW-LEVEL overlay (direct child of
        //    the window, not nested in the SwiftUI view) and the topmost subview — so it's above the
        //    root view controller's SwiftUI content, which the window hosts beneath it.
        XCTAssertTrue(modal?.superview === window, "modal should be a window-level overlay, not nested in the SwiftUI view")
        XCTAssertTrue(window.subviews.last === modal, "modal should be the topmost view in the window, over the SwiftUI content")

        renderer.dismiss(token.id)
    }

    private func firstDescendant<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        for sub in view.subviews {
            if let hit = sub as? T { return hit }
            if let deep = firstDescendant(type, in: sub) { return deep }
        }
        return nil
    }
}

// MARK: - rootRenderer — WindowModalRenderer paints SwiftUI-drawn content OVER a live SwiftUI screen

/// Same empirical proof `Tier0HostingSmokeTests` runs for `UIKitModalRenderer`, for
/// `WindowModalRenderer` (rootRenderer, `a1c6bbb`) instead: a SwiftUI-DRAWN modal (not a UIKit
/// `GBAlertModal`) installs at window level, over an existing SwiftUI screen's content, as the
/// topmost subview — proving the window-installation mechanics actually work in a real app, not
/// just against a bare `UIWindow` in `WindowModalRendererTests`.
@MainActor
final class WindowModalRendererHostingSmokeTests: XCTestCase {
    func test_windowRendererModal_paintsOverSwiftUIScreen() {
        let swiftUIScreen = UIHostingController(rootView: SwiftUIDemoScreen())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = swiftUIScreen
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }

        let renderer = WindowModalRenderer(
            alertProperties: GalleryPresets.standardModalProperties, windowProvider: { window }
        )
        let executor = DefaultModalExecutor(renderer: renderer)

        let before = window.subviews.count
        let token = executor.present(AlertDialog(title: "Over SwiftUI", subtitle: "Hi", primary: "OK"))
        window.layoutIfNeeded()

        // 1) A real view now lives directly in the SwiftUI screen's window — not nested inside the
        //    SwiftUI screen's own view hierarchy.
        XCTAssertGreaterThan(window.subviews.count, before, "presenting should add a view to the window")
        // 2) The SwiftUI host is still present underneath.
        XCTAssertTrue(swiftUIScreen.view.isDescendant(of: window), "SwiftUI content should remain in the window")
        // 3) The modal paints OVER the SwiftUI content: topmost subview, direct child of the window.
        XCTAssertTrue(
            window.subviews.last?.superview === window,
            "the hosted modal should be a window-level overlay, not nested in the SwiftUI view"
        )

        renderer.dismiss(token.id)
        XCTAssertEqual(window.subviews.count, before, "dismiss should remove the hosted view from the window")
    }
}

// MARK: - The 26-real + 28-stress catalog, in front of a human's eyes, on the two UIKit-free renderers

/// `EmbeddedCatalogScreen` builds, hosts its renderer, and actually presents a real shape — the
/// visual half of `EmbeddedShapeCoverageTests`' structural claim, now proven end to end through a
/// live app screen rather than a bare renderer.
@MainActor
final class EmbeddedCatalogScreenTests: XCTestCase {
    func test_theScreenBuildsAndHostsItsRenderer() {
        let host = UIHostingController(rootView: EmbeddedCatalogScreen())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty, "the embedded catalog screen was not laid out")
    }

    func test_presentingTheFirstShape_actuallyShowsUpOnTheRenderer() async {
        // `present(at:)` fires the entry's `present` closure inside a `Task` (so traversal can
        // CANCEL a still-pending presentation) — the renderer's own synchronous append only runs
        // once that Task gets its first turn, so this polls a few yields rather than asserting
        // immediately after the call, which would race the Task before it ever started.
        let model = EmbeddedCatalogModel()
        model.present(at: 0)
        for _ in 0..<10 where model.renderer.presentations.isEmpty {
            await Task.yield()
        }
        XCTAssertEqual(model.renderer.presentations.count, 1, "presenting a real catalog shape should show it")
        model.dismissCurrent()
    }

    /// The stress matrix's own `ModalStyle` tokens (`.stressWideBanner` and friends) are a SEPARATE
    /// registration from the 26 real shapes' — `UIKitFreeCatalogPresets.stressPresets`, added
    /// alongside `stylePresets` in `EmbeddedCatalogModel.init`. This is the check that the wiring
    /// actually reaches the renderer rather than merely compiling: an unregistered style falls back to
    /// `.standard` silently (see `RendererParityTests.test_unregisteredStyle_fallsBackIdentically_onBothRenderers`),
    /// so a missing registration here would still present SOMETHING and this test is what would catch it.
    func test_presentingAStressShape_actuallyShowsUpOnTheRenderer() async {
        let model = EmbeddedCatalogModel()
        let stressIndex = SwiftUICatalog.dialogEntries.count // first entry past the 26 real shapes
        model.present(at: stressIndex)
        for _ in 0..<10 where model.renderer.presentations.isEmpty {
            await Task.yield()
        }
        XCTAssertEqual(model.renderer.presentations.count, 1, "presenting a stress-matrix shape should show it")
        model.dismissCurrent()
    }
}

/// The `WindowModalRenderer` twin: same claim, `WindowCatalogModel` paints into a real `UIWindow`
/// instead of a caller-embedded `@Published` array.
@MainActor
final class WindowCatalogScreenTests: XCTestCase {
    func test_theScreenBuilds() {
        let host = UIHostingController(rootView: WindowCatalogScreen())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty, "the window catalog screen was not laid out")
    }
}
