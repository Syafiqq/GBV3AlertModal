import Foundation
import SwiftUI
import UIKit
@testable import GBV3AlertModal

/// **SwiftUI measurement machinery — hosting, probing, and the shared shape fixtures.**
///
/// Split out of `DifferentialGeometrySupport.swift` (Pass 5, step 1 —
/// `2026-08-07-uikit-retirement.md` §3). This half has no expiry: it is how a `SwiftUIAlertModal`'s
/// laid-out frames get measured at all, and `BespokeBannerColumnTests` /
/// `TitleSubtitleTruncationTests` already depend on it independently of the differential gate. The
/// COMPARISON built on top of it — `DifferentialGeometryComparison.swift` — dies once the gate's
/// numbers are recorded as absolute pins (§3 step 4); this file is what step 2's pin recording and
/// every future measurement-only test keep using afterward.
///
/// **`uiKitFrames`/`makeUIKitModal` live here, not in the comparison file, despite the brief that
/// ordered this split naming them as dying in step 4.** Measured, not assumed:
/// `TitleSubtitleTruncationTests.test_swiftUITitle_wrapsToTheSameHeightUIKitDoes` calls
/// `DifferentialGeometry.uiKitFrames` directly, outside the gate, to pin a long title's wrap height
/// against live UIKit — deleting that function with the gate would have broken a permanent test.
// @MainActor: builds `GBAlertModal`, `UIWindow` and `UIHostingController`, all main-actor-isolated
// under Swift 6.
@MainActor
enum DifferentialGeometry {

    /// A phone-sized portrait host — the default both measurement functions use.
    ///
    /// It used to be the ONLY size, because `SwiftUIAlertModal` hardcoded `isLandscape: false` for
    /// the resolver: a landscape comparison would have measured that assumption rather than the
    /// layout. Both backends now read orientation from the container they are given
    /// (`GBAlertModal.makeResolvedModal` from `self.bounds`, `SwiftUIAlertModal` from a
    /// `GeometryReader`), so landscape is comparable and `landscapeHost` below is gated for real.
    static let host = CGSize(width: 390, height: 844)

    /// The same phone, rotated. Every landscape fix in this module was verified by snapshot and by
    /// eye until this existed; nothing compared SwiftUI's landscape geometry against UIKit's
    /// measured numbers.
    static let landscapeHost = CGSize(width: 844, height: 390)

    /// **An iPad-WIDTH host — named, because its two siblings above are.**
    ///
    /// It exists for one job: it is wider than `cardMaxWidth + 2·cardMarginH`, which is the regime
    /// where `AlertModalScaffold`'s host-derived column ceiling names more room than a card pinned at
    /// `cardMaxWidth` could hand over. Both phone hosts are narrower, so neither exercises that
    /// branch (`test_bannerWide_theSlotNeverOverflowsTheCard_atAnyHostWidth`).
    ///
    /// **iPad-WIDTH, not an iPad.** It is a `UIWindow` of these dimensions on whatever simulator is
    /// running, so the trait collection, the size classes, the display scale and
    /// `UIDevice.current.userInterfaceIdiom` all remain the host device's. Nothing here is evidence
    /// about iPad hardware; it is evidence about the width arithmetic.
    static let iPadWidthHost = CGSize(width: 1024, height: 1366)

    /// Sub-pixel only. Auto Layout resolves to fractional points and SwiftUI rounds to the display
    /// scale, so a shared edge can legitimately land half a point apart; anything larger is a
    /// design difference. Deliberately NOT tunable per shape.
    static let tolerance: CGFloat = 0.5

    // MARK: - Shapes

    /// One comparable shape: a descriptor plus the `Properties` preset it is drawn with.
    ///
    /// Both are the real catalog values. The example app's `SwiftUICatalog` / `DialogCatalog` cannot
    /// be reached from the library test target (different target, and the example test target uses
    /// explicit file membership), so these are library-side fixtures built from `GeniePresets`,
    /// which is itself transcribed from the app's presets.
    struct Shape {
        let name: String
        let dialog: AlertDialog
        let properties: GBAlertModal.Properties
    }

    /// **Fifteen shapes, chosen to vary the fields the two backends read differently.**
    ///
    /// Covered: the standard 1-button and 2-button shapes; a nil-title shape; a close-button shape;
    /// the oblique-RED shape (a different `ObliqueBottomLeftTheme`); the permission-alert preset and
    /// the streak preset (both with ASYMMETRIC vertical padding, which is the interesting case for
    /// `ModalTokens.contentPadding` — and the streak preset is additionally the one that engages
    /// UIKit's horizontal padding COMPRESSION, asking for 352pt of card in 350pt of room); the popup
    /// preset (32pt uniform padding, different
    /// `ComponentSpace`); and the error-banner preset (popup + banner ratio/cap/fixed height).
    ///
    /// Plus the three added for the banner and D-7 work: `banner-comparable` (an artwork NARROWER
    /// than the content column, so the column stays at `contentMaxWidth`), `banner-wide` (artwork
    /// wider than the column, the regime eight of the app's nine real banner assets are in), and
    /// `long-subtitle-unscrolled` (a 1222pt subtitle, long enough to engage the subtitle slot on
    /// BOTH backends at any size — the shape that made the subtitle row comparable).
    ///
    /// Plus the three Pass 2 added, once `StandardAlertContent.primary` became optional:
    /// `no-primary-secondary-only`, `no-buttons-title-subtitle` and `no-buttons-title-only`. See their
    /// own comments below — each pins a spacing rule that was vacuously true while every descriptor
    /// carried a primary button.
    ///
    /// NOT covered, and why: the three bespoke descriptors (`BadgeDialog`, `LoadingDialog`,
    /// `SatisfactionDialog`) and the two input descriptors (`TextInputDialog`,
    /// `DatePickerDialog`) — those render through `register(_:view:)` bodies that build their OWN
    /// scaffold and have no `GBAlertModal` counterpart view graph to measure against, so there is
    /// nothing differential to do. Landscape is gated for the five non-banner shapes, for
    /// `long-subtitle-unscrolled` and for `banner-comparable` in full, and for `banner-wide` on
    /// everything but width (`landscapeHost` below, and `DifferentialGeometryTests`' landscape
    /// section).
    static var shapes: [Shape] {
        [
            Shape(
                name: "standard-one-button",
                dialog: AlertDialog(
                    title: "Failed",
                    subtitle: "You don't have microphone.",
                    primary: "Okay",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties()
            ),
            Shape(
                name: "standard-two-button",
                dialog: AlertDialog(
                    title: "[API] Confirm action",
                    subtitle: "[API] Are you sure you want to proceed?",
                    primary: "Yes",
                    secondary: "No",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties()
            ),
            Shape(
                name: "title-nil-error",
                // `String?.none`, not a bare `nil`: `AlertDialog` has a String and an
                // AttributedString initializer, and this pins the String one.
                dialog: AlertDialog(
                    title: String?.none,
                    subtitle: "[API] The operation couldn't be completed. (NSURLErrorDomain error -1009.)",
                    primary: "Okay",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties()
            ),
            Shape(
                name: "close-button-dismiss",
                dialog: AlertDialog(
                    title: "Access Denied",
                    subtitle: "[API] You are not allowed to send messages in this class right now.",
                    primary: "Close",
                    closeOnTapOverlay: true,
                    showCloseButton: true
                ),
                properties: GeniePresets.standardProperties()
            ),
            Shape(
                name: "oblique-red-leave-confirm",
                dialog: AlertDialog(
                    title: "You're leaving?",
                    subtitle: "The live class has not ended yet. Are you sure you want to leave?",
                    primary: "Yes",
                    secondary: "No",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.obliqueRedProperties()
            ),
            Shape(
                name: "permission-denied-settings",
                dialog: AlertDialog(
                    title: "Allow Permission",
                    subtitle: "Allow Geniebook to access your camera in your device's settings.",
                    primary: "Settings",
                    secondary: "Not now",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.permissionAlertProperties()
            ),
            Shape(
                name: "onboarding-welcome-nobanner",
                dialog: AlertDialog(
                    title: "Hello there!",
                    subtitle: "Let's explore Geniebook!",
                    primary: "I'm ready"
                ),
                properties: GeniePresets.popupProperties()
            ),
            Shape(
                name: "streak-popup-banner",
                dialog: AlertDialog(
                    image: ModalImage("streak_lose"),
                    title: "You missed your streak!",
                    subtitle: "[API] You missed your 7 days streak and 15 extra bubbles. "
                        + "Save your streak by doing 5 questions!",
                    primary: "Continue"
                ),
                properties: GeniePresets.streakProperties()
            ),
            Shape(
                name: "database-error-banner",
                dialog: AlertDialog(
                    image: ModalImage("img_database_error"),
                    title: "Something went wrong :(",
                    subtitle: "We're fixing our servers as fast as we can.\nTake a break and try again later.",
                    primary: "Okay"
                ),
                properties: GeniePresets.errorBannerProperties()
            ),
            /// **The first shape whose BANNER is actually compared.**
            ///
            /// Every other banner shape here draws nothing on either side: both renderers resolve
            /// artwork from the main bundle, this target has none, and `bannerIsUnresolvableInThe
            /// LibraryBundle` therefore reports `absent (both)` — agreement about an absence, which
            /// is not a measurement. `ModalImage.bundleIdentifier` closes that: the asset lives in
            /// this target's own resource bundle, so both backends draw a real 16:9 image and the
            /// `.banner` row finally carries two frames.
            ///
            /// `TestBundleAssetTests` gates the premise — that the asset resolves at all — because a
            /// banner row over an unresolvable name would go back to `absent (both)` and PASS.
            Shape(
                name: "banner-comparable",
                dialog: AlertDialog(
                    image: ModalImage(
                        "gb_test_banner", bundleIdentifier: Bundle.module.bundleIdentifier
                    ),
                    title: "Heads up",
                    subtitle: "A banner the gate can actually measure.",
                    primary: "Okay"
                ),
                properties: GeniePresets.standardProperties()
            ),
            /// **The banner shape whose artwork is WIDER than the content column.**
            ///
            /// Eight of the app's nine real banner assets are (`img_gc2gs_prompt_*` at 320x190pt is
            /// this one, verbatim). UIKit lets the artwork push the column past `contentMaxWidth` —
            /// `ivBanner`'s compression resistance (750) outranks `width == fixedWidth` at
            /// `.medium` (500) — and before this shape existed nothing on the SwiftUI side could
            /// see that. Measured cost when it was missed: card 30pt narrow, banner 72pt tall.
            ///
            /// Expected on both sides: card 350, column 310, banner height 184.06.
            Shape(
                name: "banner-wide",
                dialog: AlertDialog(
                    image: ModalImage(
                        "gb_test_banner_wide", bundleIdentifier: Bundle.module.bundleIdentifier
                    ),
                    title: "Heads up",
                    subtitle: "A banner wider than the column it sits in.",
                    primary: "Okay"
                ),
                properties: GeniePresets.popupProperties()
                    .copy(bannerRatio: 320.0 / 190.0, bannerMaxHeight: 256)
            ),
            /// **The shape that ENGAGES the subtitle scroll — the half of D-7 the gate could not see,
            /// and now the one that CLOSES it.**
            ///
            /// Every shape above is short enough that UIKit's `svSubtitleContainer` is exactly its
            /// label's height, so the gate was comparing a scroll slot against a `Text` in the one
            /// case where the two happen to coincide. This subtitle is long enough to overflow even
            /// the portrait card, so UIKit's slot genuinely shrinks-and-scrolls and the comparison
            /// is finally against the mechanism rather than around it.
            ///
            /// The two backends are measurably the same layout: SwiftUI's `SubtitleSlot` lands on
            /// UIKit's VIEWPORT to the point — **645.33 against 645.33** in portrait and **161.33
            /// against 161.33** in landscape, on a subtitle whose content is 1222pt. So this shape
            /// goes through the full `assertAgrees` in BOTH orientations, subtitle row included.
            ///
            /// **It used to have a twin.** `long-subtitle-scrolling` was this exact dialog with
            /// `Properties.contentScrollable` ON, and it could not compare its `subtitle` row: the
            /// flag's outer `ScrollableContent` wrapped title AND subtitle, so inside it the height
            /// proposal was unbounded, the slot was never pressured, and it reported the full 1222.
            /// The flag is deleted and the twin with it — with the field gone the two shapes were
            /// character-for-character identical, so keeping both would have been the same
            /// measurement run twice under two names.
            Shape(
                name: "long-subtitle-unscrolled",
                dialog: AlertDialog(
                    title: "Heads up",
                    subtitle: String(
                        // FORTY, not twenty. At twenty the subtitle came to 611pt and the portrait
                        // card — whose ceiling the zeroed vertical margin raised — simply FIT it, so
                        // the slot equalled its content and the row was vacuous. The premise test
                        // `test_theUnscrolledShape_actuallyClipsItsSubtitle` is what catches that.
                        repeating: "This subtitle keeps going so the slot has to engage. ", count: 40
                    ).trimmingCharacters(in: .whitespaces),
                    primary: "Okay",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties()
            ),
            // MARK: The two shapes `primary: String?` made expressible (Pass 2)
            //
            // Both were UNREACHABLE from a descriptor before `StandardAlertContent.primary` became
            // optional — the UIKit stress gallery had to hand-build a `DataHolder` with
            // `primaryAction: nil` to show them at all, which is precisely why they were never
            // gated. They are here rather than only in the example gallery because the gap they
            // expose is arithmetic, not visual: with the button run absent or half-absent, the
            // SPACING rules stop being trivially satisfied.
            Shape(
                // A LONE SECONDARY. The vertical button run hand-rolls `UIStackView.spacing` as a
                // `.padding(.top, interButton)` on the secondary, and stack spacing applies only
                // BETWEEN arranged subviews — so an unconditional padding here would leave an 8pt
                // hole above the secondary that UIKit does not have.
                name: "no-primary-secondary-only",
                dialog: AlertDialog(
                    title: "Leave without saving?",
                    subtitle: "[API] Your changes will be lost.",
                    primary: nil,
                    secondary: "Cancel",
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties()
            ),
            Shape(
                // NO BUTTON RUN AT ALL, which makes the subtitle the last row in the card. UIKit
                // builds `vwSubtitleAndBelowDivider` only when `svMainActionContainer != nil`, so
                // the subtitle's trailing gap has to disappear with the buttons.
                name: "no-buttons-title-subtitle",
                dialog: AlertDialog(
                    title: "Syncing",
                    subtitle: "[API] This will close on its own when the upload finishes.",
                    primary: nil,
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties()
            ),
            Shape(
                // TITLE ALONE. `no-buttons-title-subtitle` above satisfies the title's
                // "is anything below me" test through its SUBTITLE, so it cannot tell a correct
                // `hasSubtitle || hasButtons` from an unconditional gap. This shape has neither,
                // and is the only one that fails when the title's trailing gap is left
                // unconditional. `vwTitleAndBelowDivider` is its UIKit counterpart.
                name: "no-buttons-title-only",
                dialog: AlertDialog(
                    title: "Saved",
                    subtitle: String?.none,
                    primary: nil,
                    closeOnTapOverlay: true
                ),
                properties: GeniePresets.standardProperties()
            )
        ]
    }

    static func shape(named name: String) -> Shape? {
        shapes.first { $0.name == name }
    }

    // MARK: - UIKit measurement (the source of truth)

    /// Reads the real `GBAlertModal`'s laid-out frames. Not a computation and not a recording —
    /// Auto Layout resolved these numbers, in this process, at this host size.
    static func uiKitFrames(_ shape: Shape, size: CGSize = host) -> [ModalGeometryElement: CGRect] {
        let modal = makeUIKitModal(shape)
        let window = makeWindow(size: size)
        defer { teardown(window) }
        modal.show(parent: window, completion: {})
        window.setNeedsLayout()
        window.layoutIfNeeded()

        guard let card = modal.vwContainer else { return [:] }
        let cardFrame = modal.convert(card.bounds, from: card)
        var frames: [ModalGeometryElement: CGRect] = [
            // Position excluded by design — see the type doc.
            .card: CGRect(origin: .zero, size: cardFrame.size)
        ]
        func record(_ element: ModalGeometryElement, _ view: UIView?) {
            guard let view else { return }
            frames[element] = modal.convert(view.bounds, from: view)
                .offsetBy(dx: -cardFrame.minX, dy: -cardFrame.minY)
        }
        record(.banner, modal.vwBanner)
        record(.title, modal.lbTitle)
        record(.subtitle, modal.svSubtitleContainer)
        // The VISIBLE oblique rectangle, not its slot: `configureButtonActionConstraint` insets
        // `btPrimaryAction` by (+3, -3) from `vwPrimaryAction`, and the visible rect is what a user
        // sees. Comparing the slot instead would hide that inset.
        record(.primaryButton, modal.btPrimaryAction)
        record(.secondaryButton, modal.btSecondaryAction)
        record(.closeButton, modal.btCloseAction)
        return frames
    }

    /// The modal both halves of the comparison are built from. The `DataHolder` comes from
    /// `UIKitModalRenderer.AlertHolder.make` — the SAME mapping `SwiftUIAlertModal` runs internally
    /// — so the two sides cannot differ because of their fixture.
    static func makeUIKitModal(_ shape: Shape) -> GBAlertModal {
        GBAlertModal(
            properties: shape.properties,
            holder: UIKitModalRenderer.AlertHolder.make(for: shape.dialog, resolve: { _ in })
        )
    }

    // MARK: - SwiftUI measurement (in-view, via GeometryReader + PreferenceKey)

    /// Hosts `SwiftUIAlertModal` and returns whatever the probes published.
    ///
    /// Returns `[:]` when the card was never measured — the callers treat that as a HARD failure
    /// rather than as "no differences found". A harness that silently reports an empty set is
    /// exactly how 26 vacuous green assertions got written on this plan once already.
    static func swiftUIFrames(
        _ shape: Shape,
        tokens: ModalTokens? = nil,
        size: CGSize = host
    ) -> [ModalGeometryElement: CGRect] {
        let sink = Sink()
        let root = ProbeHost(sink: sink) {
            SwiftUIAlertModal(
                config: shape.dialog,
                properties: shape.properties,
                tokens: tokens ?? ModalTokens(from: shape.properties),
                onAction: { _ in }
            )
        }
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .clear
        controller.view.frame = CGRect(origin: .zero, size: size)

        let window = makeWindow(size: size)
        defer { teardown(window) }
        window.rootViewController = controller
        pump(window) { sink.frames[.card] != nil }

        let frames = sink.frames
        guard let card = frames[.card] else { return [:] }
        var normalised: [ModalGeometryElement: CGRect] = [
            .card: CGRect(origin: .zero, size: card.size)
        ]
        for (element, rect) in frames where element != .card {
            normalised[element] = rect.offsetBy(dx: -card.minX, dy: -card.minY)
        }
        return normalised
    }

    /// Where the probes' `PreferenceKey` deliveries land.
    ///
    /// `@unchecked Sendable` for the same reason `SnapshotSupport`'s host window is
    /// `nonisolated(unsafe)`: it is only ever touched on the main thread (SwiftUI delivers
    /// preferences there, and the reads happen in a `@MainActor` test body), so there is no real
    /// race to guard. The unchecked conformance also makes this compile whether or not the SDK
    /// annotates `onPreferenceChange`'s action `@Sendable`.
    final class Sink: @unchecked Sendable {
        private var storage: [ModalGeometryElement: CGRect] = [:]
        var frames: [ModalGeometryElement: CGRect] { storage }
        func record(_ value: [ModalGeometryElement: CGRect]) { storage = value }
    }

    /// Wraps the view under measurement and drains its geometry preference into `sink`.
    ///
    /// Deliberately in the TEST target: the production instrumentation is only the probes. Nothing
    /// in the library ever collects them, so there is no library-side plumbing to keep alive.
    @MainActor
    struct ProbeHost<Content: View>: View {
        let sink: Sink
        let content: Content

        init(sink: Sink, @ViewBuilder content: () -> Content) {
            self.sink = sink
            self.content = content()
        }

        var body: some View {
            content.onPreferenceChange(ModalGeometryPreferenceKey.self) { [sink] value in
                sink.record(value)
            }
        }
    }

    // MARK: - Hosting

    /// A key window sized to `host`, created the way `SnapshotSupport.renderForSnapshot` documents.
    ///
    /// Every caller pairs this with `teardown(_:)` in a `defer` IN THE SAME CALL. That is not
    /// tidiness: `UIWindow(windowScene:)` registers the window in `scene.windows`, which retains it
    /// for the scene's lifetime, and a host left alive across a test boundary on this target once
    /// became a zombie that crashed the next synchronous render (see `SnapshotSupport`'s note). No
    /// window created here ever outlives the function that made it.
    static func makeWindow(size: CGSize = host) -> UIWindow {
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: .zero)
        }
        window.frame = CGRect(origin: .zero, size: size)
        window.backgroundColor = .white
        window.isHidden = false
        window.makeKeyAndVisible()
        return window
    }

    static func teardown(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
        window.subviews.forEach { $0.removeFromSuperview() }
        window.windowScene = nil
    }

    /// Lays out, commits the layer tree, and turns the run loop until `isReady()` — or until the
    /// budget runs out.
    ///
    /// SwiftUI delivers a preference change as part of its update cycle, which a single synchronous
    /// `layoutIfNeeded()` does not always complete; `CATransaction.flush()` commits what SwiftUI
    /// built (the same reason `GenieShapeCatalog.bodyEvidence` calls it before reading pixels), and
    /// the short run-loop turns give the update a chance to land. The budget is small and bounded;
    /// running out is reported by the caller as a failure, never as "no differences".
    static func pump(_ window: UIWindow, budget: Int = 40, until isReady: () -> Bool) {
        for _ in 0..<budget {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            CATransaction.flush()
            if isReady() { return }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.005))
        }
    }
}
