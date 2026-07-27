# SwiftUI Alert Modal — UI-first prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pure-SwiftUI alert modal mirroring `GBAlertModal`'s content, driven by local `@State`, reachable from the UIKit gallery in the Example app — as a judgment prototype for the SwiftUI direction.

**Architecture:** A **dumb SwiftUI view** (`SwiftUIAlertModal`) renders a full-screen scrim + centered card via `ZStack` overlay. All branching logic lives in **pure, headless functions** (`ResolvedAlert`, `resolve`) so correctness is exhaustively unit-testable with no view-inspection dependency. A demo screen drives it with item-driven `@State`. Zero library changes.

**Tech Stack:** SwiftUI (iOS 15 floor), XCTest, `UIHostingController` for hosting-smoke tests. Reuses the library's public `AlertDialog` type as the content/config vocabulary. No new dependencies.

## Global Constraints

- **iOS 15 floor.** `@StateObject`, `.fullScreenCover(item:)`, `@Environment(\.dismiss)` available; `@Observable` (iOS 17) is NOT — use `@State`/plain values.
- **Example app only.** No changes under `Library/`. No new SPM/CocoaPods/ViewInspector/snapshot dependency in the example targets.
- **Presentation is an overlay `ZStack`** (full-screen scrim + centered card) — never `.sheet`/`.fullScreenCover`.
- **Config vocabulary = the library's public `AlertDialog`** (`image: ModalImage?`, `title/subtitle: String?`, `primary: String`, `secondary: String?`, `closeOnTapOverlay: Bool`, `showCloseButton: Bool`) and outcome = `AlertDialog.Result` (`.primary` / `.secondary` / `.dismissed`).
- **No new files need pbxproj edits:** the example targets use `PBXFileSystemSynchronizedRootGroup`; files placed in the app folder join the app target, files in the test folder join the test target, automatically.
- **The SwiftUI view holds no branching logic** — it only reads `ResolvedAlert` and pipes taps through `resolve(_:_:)`.
- **Fidelity: content-faithful, native idioms.** No pixel-clone of oblique buttons / banner ratios / DM Sans.
- **Test run:** `xcodebuild test -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17'`. Tighten with `-only-testing:GBV3AlertModalExampleTests/<Class>/<method>`.

---

### Task 1: Headless resolution logic (`AlertResolution`)

The entire correctness surface: which slots render + how each interaction resolves. Pure Swift, no SwiftUI/UIKit import. This is the "Layer A" of the repo's house test style.

**Files:**
- Create: `Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/AlertResolution.swift`
- Test: `Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/AlertResolutionTests.swift`

**Interfaces:**
- Consumes: `AlertDialog` and `AlertDialog.Result` from `import GBV3AlertModal`.
- Produces:
  - `enum AlertInteraction { case primaryTapped, secondaryTapped, closeTapped, overlayTapped }`
  - `struct ResolvedAlert { let showsBanner, showsTitle, showsSubtitle, showsSecondary, showsClose, dismissOnOverlayTap: Bool; init(_ config: AlertDialog) }`
  - `func resolve(_ interaction: AlertInteraction, _ config: AlertDialog) -> AlertDialog.Result?`

- [ ] **Step 1: Write the failing tests**

```swift
// AlertResolutionTests.swift
import XCTest
import GBV3AlertModal
@testable import GBV3AlertModalExample

final class AlertResolutionTests: XCTestCase {

    // MARK: ResolvedAlert — slot visibility

    func test_banner_shows_iff_image_present() {
        XCTAssertTrue(ResolvedAlert(cfg(image: ModalImage("x"))).showsBanner)
        XCTAssertFalse(ResolvedAlert(cfg(image: nil)).showsBanner)
    }

    func test_title_shows_iff_nonEmpty() {
        XCTAssertTrue(ResolvedAlert(cfg(title: "Hi")).showsTitle)
        XCTAssertFalse(ResolvedAlert(cfg(title: nil)).showsTitle)
        XCTAssertFalse(ResolvedAlert(cfg(title: "")).showsTitle)
    }

    func test_subtitle_shows_iff_nonEmpty() {
        XCTAssertTrue(ResolvedAlert(cfg(subtitle: "Body")).showsSubtitle)
        XCTAssertFalse(ResolvedAlert(cfg(subtitle: nil)).showsSubtitle)
        XCTAssertFalse(ResolvedAlert(cfg(subtitle: "")).showsSubtitle)
    }

    func test_secondary_shows_iff_nonEmpty() {
        XCTAssertTrue(ResolvedAlert(cfg(secondary: "Cancel")).showsSecondary)
        XCTAssertFalse(ResolvedAlert(cfg(secondary: nil)).showsSecondary)
        XCTAssertFalse(ResolvedAlert(cfg(secondary: "")).showsSecondary)
    }

    func test_close_shows_iff_flag_set() {
        XCTAssertTrue(ResolvedAlert(cfg(showCloseButton: true)).showsClose)
        XCTAssertFalse(ResolvedAlert(cfg(showCloseButton: false)).showsClose)
    }

    func test_dismissOnOverlayTap_mirrors_flag() {
        XCTAssertTrue(ResolvedAlert(cfg(closeOnTapOverlay: true)).dismissOnOverlayTap)
        XCTAssertFalse(ResolvedAlert(cfg(closeOnTapOverlay: false)).dismissOnOverlayTap)
    }

    // MARK: resolve — interaction routing

    func test_primary_tap_resolves_primary() {
        XCTAssertEqual(resolve(.primaryTapped, cfg()), .primary)
    }

    func test_secondary_tap_resolves_secondary() {
        XCTAssertEqual(resolve(.secondaryTapped, cfg(secondary: "Cancel")), .secondary)
    }

    func test_close_tap_resolves_dismissed() {
        XCTAssertEqual(resolve(.closeTapped, cfg(showCloseButton: true)), .dismissed)
    }

    func test_overlay_tap_resolves_dismissed_only_when_enabled() {
        XCTAssertEqual(resolve(.overlayTapped, cfg(closeOnTapOverlay: true)), .dismissed)
        XCTAssertNil(resolve(.overlayTapped, cfg(closeOnTapOverlay: false)))
    }

    // MARK: helper — one place to vary a single field

    private func cfg(
        image: ModalImage? = nil,
        title: String? = "Title",
        subtitle: String? = "Subtitle",
        primary: String = "OK",
        secondary: String? = nil,
        closeOnTapOverlay: Bool = false,
        showCloseButton: Bool = false
    ) -> AlertDialog {
        AlertDialog(
            image: image, title: title, subtitle: subtitle,
            primary: primary, secondary: secondary,
            closeOnTapOverlay: closeOnTapOverlay, showCloseButton: showCloseButton
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalExampleTests/AlertResolutionTests`
Expected: FAIL to compile — `ResolvedAlert` / `resolve` / `AlertInteraction` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// AlertResolution.swift
import GBV3AlertModal

/// A discrete user interaction with the modal. Pure enum so routing is testable without a view.
enum AlertInteraction {
    case primaryTapped, secondaryTapped, closeTapped, overlayTapped
}

/// Which slots the modal renders, derived purely from the config.
/// Mirrors the library's `ResolvedModal` resolver (the "Layer A" pattern).
struct ResolvedAlert {
    let showsBanner: Bool
    let showsTitle: Bool
    let showsSubtitle: Bool
    let showsSecondary: Bool
    let showsClose: Bool
    let dismissOnOverlayTap: Bool

    init(_ config: AlertDialog) {
        func present(_ s: String?) -> Bool { !(s ?? "").isEmpty }
        showsBanner = config.image != nil
        showsTitle = present(config.title)
        showsSubtitle = present(config.subtitle)
        showsSecondary = present(config.secondary)
        showsClose = config.showCloseButton
        dismissOnOverlayTap = config.closeOnTapOverlay
    }
}

/// The outcome an interaction produces, or `nil` for a no-op (overlay tap when disabled).
func resolve(_ interaction: AlertInteraction, _ config: AlertDialog) -> AlertDialog.Result? {
    switch interaction {
    case .primaryTapped:   return .primary
    case .secondaryTapped: return .secondary
    case .closeTapped:     return .dismissed
    case .overlayTapped:   return config.closeOnTapOverlay ? .dismissed : nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalExampleTests/AlertResolutionTests`
Expected: PASS (all AlertResolutionTests green).

- [ ] **Step 5: Commit**

```bash
git add Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/AlertResolution.swift \
        Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/AlertResolutionTests.swift
git commit -m "feat(swiftui): headless alert resolution logic + exhaustive tests"
```

---

### Task 2: `SwiftUIAlertModal` view + hosting smoke test

The dumb view: full-screen scrim + centered card, reading `ResolvedAlert`, piping taps through `resolve`. Content-faithful, native idioms.

**Files:**
- Create: `Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/SwiftUIAlertModal.swift`
- Test: `Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/SwiftUIAlertModalSmokeTests.swift`

**Interfaces:**
- Consumes: `AlertDialog`, `AlertDialog.Result` (library); `ResolvedAlert`, `AlertInteraction`, `resolve` (Task 1).
- Produces: `struct SwiftUIAlertModal: View { init(config: AlertDialog, scrim: Color = Color.black.opacity(0.6), onAction: @escaping (AlertDialog.Result) -> Void) }`

- [ ] **Step 1: Write the failing hosting-smoke test**

```swift
// SwiftUIAlertModalSmokeTests.swift
import SwiftUI
import UIKit
import XCTest
import GBV3AlertModal
@testable import GBV3AlertModalExample

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

    private func assertBuilds(_ config: AlertDialog, _ message: String) {
        let (window, host) = host(SwiftUIAlertModal(config: config) { _ in })
        defer { teardown(window) }
        XCTAssertFalse(host.view.bounds.isEmpty, "\(message): host view was not laid out")
        XCTAssertFalse(host.view.subviews.isEmpty, "\(message): view graph is empty")
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalExampleTests/SwiftUIAlertModalSmokeTests`
Expected: FAIL to compile — `SwiftUIAlertModal` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// SwiftUIAlertModal.swift
import SwiftUI
import GBV3AlertModal

/// Pure-SwiftUI mirror of `GBAlertModal`'s content: a full-screen scrim with a centered card.
/// Holds NO branching logic — reads `ResolvedAlert` and routes taps through `resolve(_:_:)`.
/// Never dismisses itself; the caller reacts to `onAction` (matches the executor teardown contract).
struct SwiftUIAlertModal: View {
    let config: AlertDialog
    var scrim: Color = Color.black.opacity(0.6)
    let onAction: (AlertDialog.Result) -> Void

    private var resolved: ResolvedAlert { ResolvedAlert(config) }

    var body: some View {
        ZStack {
            scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { route(.overlayTapped) }

            card
                .frame(maxWidth: 300)
                .padding(24)

            if resolved.showsClose {
                closeButton
            }
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            if resolved.showsBanner, let name = config.image?.assetName {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
            }
            if resolved.showsTitle, let title = config.title {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
            }
            if resolved.showsSubtitle, let subtitle = config.subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button { route(.primaryTapped) } label: {
                Text(config.primary)
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            if resolved.showsSecondary, let secondary = config.secondary {
                Button { route(.secondaryTapped) } label: {
                    Text(secondary)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { route(.closeTapped) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(32)
    }

    /// The one place interaction becomes outcome. `nil` = no-op (e.g. overlay tap when disabled).
    private func route(_ interaction: AlertInteraction) {
        resolve(interaction, config).map(onAction)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalExampleTests/SwiftUIAlertModalSmokeTests`
Expected: PASS (both configs build a non-empty, laid-out view graph).

- [ ] **Step 5: Commit**

```bash
git add Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/SwiftUIAlertModal.swift \
        Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/SwiftUIAlertModalSmokeTests.swift
git commit -m "feat(swiftui): SwiftUIAlertModal view (scrim + centered card) + hosting smoke tests"
```

---

### Task 3: Demo screen + gallery entry point

Item-driven `@State` host with two fixtures, reachable from the UIKit gallery via a nav-bar button pushing a `UIHostingController`.

**Files:**
- Create: `Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/SwiftUIDemoScreen.swift`
- Modify: `Examples/GBV3AlertModalExample/GBV3AlertModalExample/Gallery/GalleryViewController.swift` (add a right bar button in `viewDidLoad` + a push handler)
- Test: `Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/SwiftUIDemoScreenSmokeTests.swift`

**Interfaces:**
- Consumes: `SwiftUIAlertModal` (Task 2); `AlertDialog`, `ModalImage` (library); `UIHostingController` (UIKit).
- Produces:
  - `struct SwiftUIDemoScreen: View` with static fixtures `static let demoMinimal: AlertDialog`, `static let demoFull: AlertDialog`.
  - `GalleryViewController` gains a right bar button titled "SwiftUI" that pushes `UIHostingController(rootView: SwiftUIDemoScreen())`.

- [ ] **Step 1: Write the failing tests**

```swift
// SwiftUIDemoScreenSmokeTests.swift
import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModalExample

final class SwiftUIDemoScreenSmokeTests: XCTestCase {

    func test_demoScreen_builds() {
        let host = UIHostingController(rootView: SwiftUIDemoScreen())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil }

        XCTAssertFalse(host.view.bounds.isEmpty)
        XCTAssertFalse(host.view.subviews.isEmpty)
    }

    func test_gallery_exposes_swiftui_entry_point() {
        let gallery = GalleryViewController()
        gallery.loadViewIfNeeded()           // triggers viewDidLoad
        XCTAssertNotNil(
            gallery.navigationItem.rightBarButtonItem,
            "gallery should expose a nav-bar button to reach the SwiftUI demo"
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalExampleTests/SwiftUIDemoScreenSmokeTests`
Expected: FAIL — `SwiftUIDemoScreen` undefined; `rightBarButtonItem` is nil.

- [ ] **Step 3a: Write the demo screen**

```swift
// SwiftUIDemoScreen.swift
import SwiftUI
import GBV3AlertModal

/// A pure-SwiftUI host that drives `SwiftUIAlertModal` with item-driven local `@State`.
/// No executor, no coordinator — this is the "does SwiftUI feel good to author here" prototype.
struct SwiftUIDemoScreen: View {
    /// Item-driven presentation: non-nil == a modal is shown. Single source of truth.
    @State private var active: AlertDialog?
    /// Last outcome, shown so the judgment run can see taps resolve.
    @State private var lastResult: String = "—"

    static let demoMinimal = AlertDialog(
        title: "You're all set",
        subtitle: "Your changes have been saved.",
        primary: "Got it"
    )

    static let demoFull = AlertDialog(
        image: ModalImage("img_illust_onboarding"),
        title: "Help us make your experience better",
        subtitle: "Take our quick survey and gain bubbles!",
        primary: "Proceed to feedback",
        secondary: "Not now",
        closeOnTapOverlay: true,
        showCloseButton: true
    )

    var body: some View {
        VStack(spacing: 16) {
            Text("Last result: \(lastResult)")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button("Minimal alert") { active = Self.demoMinimal }
            Button("Full alert") { active = Self.demoFull }
        }
        .navigationTitle("SwiftUI Modal")
        .overlay {
            if let config = active {
                SwiftUIAlertModal(config: config) { result in
                    lastResult = "\(result)"
                    active = nil                 // caller owns dismissal; view never self-dismisses
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: active != nil)
    }
}
```

Note: `AlertDialog` is not `Equatable`, so the `.animation(_:value:)` observes the derived `Bool` `active != nil`, not `active` itself.

- [ ] **Step 3b: Wire the gallery entry point**

In `GalleryViewController.swift`, at the end of `viewDidLoad()` add:

```swift
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "SwiftUI",
            style: .plain,
            target: self,
            action: #selector(openSwiftUIDemo)
        )
```

And add the handler method to the class (needs `import SwiftUI` at the top of the file):

```swift
    @objc private func openSwiftUIDemo() {
        let host = UIHostingController(rootView: SwiftUIDemoScreen())
        navigationController?.pushViewController(host, animated: true)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GBV3AlertModalExampleTests/SwiftUIDemoScreenSmokeTests`
Expected: PASS (demo screen builds; gallery exposes the right bar button).

- [ ] **Step 5: Run the full example test suite**

Run: `xcodebuild test -scheme GBV3AlertModalExample -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: PASS — all example tests green (AlertResolution + both smoke suites + pre-existing DialogCatalogSmokeTests).

- [ ] **Step 6: Commit**

```bash
git add Examples/GBV3AlertModalExample/GBV3AlertModalExample/SwiftUI/SwiftUIDemoScreen.swift \
        Examples/GBV3AlertModalExample/GBV3AlertModalExample/Gallery/GalleryViewController.swift \
        Examples/GBV3AlertModalExample/GBV3AlertModalExampleTests/SwiftUIDemoScreenSmokeTests.swift
git commit -m "feat(swiftui): demo screen with item-driven state + gallery entry point"
```

---

## Manual verification (owner judgment step — the point of the prototype)

After Task 3, run the app (not just tests): launch `GBV3AlertModalExample` on a simulator, tap the **"SwiftUI"** nav-bar button, and exercise both alerts. Confirm: full-screen dimmed scrim, centered card, banner/title/subtitle/buttons/close render, overlay-tap dismisses only on the full alert, and the "Last result" line updates on each tap. This is the look/feel judgment that decides keep-local vs Tier 0 vs Tier 1.

## Self-Review

**Spec coverage:** Overlay ZStack scrim+card (Task 2 ✓), item-driven `@State` (Task 3 ✓), content-faithful native idioms (Task 2 view ✓), AlertDialog-only scope (all ✓), two variants minimal/full (Task 3 fixtures + Task 2 smoke ✓), example-app-only/zero-library-change (all paths under `Examples/` ✓), Layer-A headless exhaustive tests (Task 1 ✓), hosting-smoke tests (Tasks 2–3 ✓), snapshot deferred (not built, by design ✓), gallery reachability (Task 3 ✓), full-screen-scrim+centered-card invariant (Task 2 `ZStack { scrim.ignoresSafeArea(); card }` ✓).

**Placeholder scan:** No TBD/TODO; every code step is complete and runnable.

**Type consistency:** `AlertInteraction`, `ResolvedAlert(_:)`, `resolve(_:_:) -> AlertDialog.Result?` defined in Task 1 and consumed unchanged in Task 2. `SwiftUIAlertModal(config:scrim:onAction:)` defined in Task 2 and consumed unchanged in Task 3. `AlertDialog` initializer args match the library's public `AlertDialog.init` (image/title/subtitle/primary/secondary/closeOnTapOverlay/showCloseButton).
