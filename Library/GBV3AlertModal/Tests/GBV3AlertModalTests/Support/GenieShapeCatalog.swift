import SwiftUI
import UIKit
@testable import GBV3AlertModal

/// The style tokens the 26 real shapes ask for. The library ships only `.standard` and `.popup`;
/// everything else is a CONSUMER preset, which is precisely the claim `ModalStyle` makes — see its
/// doc comment ("Extend it from the app side, exactly like `ModalImage`"). This block is that
/// extension, written the way the app would write it.
///
/// Names are deliberately distinct from the tokens `ModalStyleTests`/`RendererParityTests` declare
/// privately (`badge`, `ghost`, `parity.badge`), so nothing here shadows or collides with them.
extension ModalStyle {
    static let permissionAlert = ModalStyle("genie.permissionAlert")
    static let obliqueRed = ModalStyle("genie.obliqueRed")
    static let errorBanner = ModalStyle("genie.errorBanner")
    static let forceUpdateBanner = ModalStyle("genie.forceUpdateBanner")
    static let capBanner = ModalStyle("genie.capBanner")
    static let quizBanner = ModalStyle("genie.quizBanner")
    static let trialBanner = ModalStyle("genie.trialBanner")
    static let aiNotesBanner = ModalStyle("genie.aiNotesBanner")
    static let creditDeduction = ModalStyle("genie.creditDeduction")
    static let streak = ModalStyle("genie.streak")
    static let timerBanner = ModalStyle("genie.timerBanner")
    static let exitWorksheetBanner = ModalStyle("genie.exitWorksheetBanner")
    static let renameInput = ModalStyle("genie.renameInput")
    static let datePickerInput = ModalStyle("genie.datePickerInput")
    static let badgeUnlock = ModalStyle("genie.badgeUnlock")
    static let badgeMulti = ModalStyle("genie.badgeMulti")
    static let badgeDetail = ModalStyle("genie.badgeDetail")
}

/// **The 26 real Geniebook dialog shapes, expressed against this library's SwiftUI backend.**
///
/// Source of truth: `Examples/GBV3AlertModalExample/.../Gallery/DialogCatalog+*.swift`, which is
/// itself mined from the production app (`docs/superpowers/specs/2026-07-21-dialog-catalog.md`).
/// Each entry here reproduces the CONTENT and the PRESET of the catalog entry with the same name.
///
/// ## What this file is evidence of, and what it is not
///
/// * It IS evidence that every shape is **expressible**: a descriptor + a registered preset (and,
///   for the bespoke ones, a registered SwiftUI body) exists for each, and presenting it through
///   `SwiftUIModalRenderer` yields the expected `ResolvedModal` slots and a body `ModalHost` draws.
/// * It is NOT evidence of **visual fidelity**. There is no snapshot baseline for the SwiftUI
///   backend, and this repo has a documented history of snapshot-green-but-visually-wrong. Fonts
///   and colours here are system approximations (see `GeniePresets`' catalog-preset note), and the
///   banner ARTWORK is substituted (see `substitutedBanner`).
@MainActor
enum GenieShapeCatalog {

    // MARK: - The manifest

    /// **The 26 catalog names, hard-coded.** `ShapeCoverageTests`' manifest test asserts this has
    /// exactly 26 entries and that every one of them has a `Shape` below. That is the gate that
    /// makes silent under-delivery impossible: drop a shape and the manifest goes red.
    ///
    /// Order follows `DialogCatalog.entries` (cross-cutting, worksheet, GenieClass, campaign,
    /// working-space, badges).
    static let names: [String] = [
        // Cross-cutting (DialogCatalog+CrossCutting.swift)
        "standard-one-button",
        "standard-two-button",
        "title-nil-error",
        "close-button-dismiss",
        "permission-denied-settings",
        "oblique-red-leave-confirm",
        "database-error-banner",
        "force-update-banner",
        // Worksheet (DialogCatalog+Worksheet.swift)
        "worksheet-generating-abused",
        "worksheet-abused-cap-banner",
        "rename-worksheet",
        "date-picker-worksheet",
        "streak-popup-banner",
        "switch-device-recommendation",
        // GenieClass (DialogCatalog+GenieClass.swift)
        "quiz-info-banner",
        "quiz-begin-banner",
        "credit-deduction-popup",
        "ai-notes-ready-banner",
        // Campaign (DialogCatalog+Campaign.swift)
        "onboarding-welcome-nobanner",
        "onboarding-trial-banner",
        // Working space (DialogCatalog+WorkingSpace.swift)
        "exit-worksheet-confirm-banner",
        "worksheet-ready-timer-banner",
        "worksheet-timeup-timer-banner",
        // Badges (DialogCatalog+Badges.swift)
        "badge-unlock-single",
        "badge-unlock-multi",
        "badge-detail-popup"
    ]

    /// One catalog shape, reduced to the only thing a coverage test needs: how to present it.
    struct Shape {
        let name: String
        /// Presents the shape on an already-registered renderer. `@MainActor` spelled explicitly
        /// (rather than relying on the enclosing enum's isolation) so the stored closure's isolation
        /// is unambiguous under Swift 6.
        let present: @MainActor (SwiftUIModalRenderer, ModalID) -> Void
    }

    static func shape(named name: String) -> Shape? {
        shapes.first { $0.name == name }
    }

    // MARK: - Presenting

    /// Thrown when a name in `names` has no `Shape`. Surfaces in BOTH the manifest test and the
    /// named per-shape test, so a dropped shape fails twice and cannot be missed.
    struct MissingShape: Error, CustomStringConvertible {
        let name: String
        var description: String {
            "no covered shape for catalog entry '\(name)' — it is listed in the manifest but not implemented"
        }
    }

    /// What one presented shape produced. Everything a coverage assertion reads.
    struct Presented {
        /// Held so the renderer (and therefore the presentation's gate) outlives the assertions.
        let renderer: SwiftUIModalRenderer
        let id: ModalID
        let presentation: SwiftUIModalRenderer.Presentation

        /// The renderer's STRUCTURE decision, from the shared `GBAlertModal.resolve`.
        var resolved: GBAlertModal.ResolvedModal { presentation.resolved }
        /// Whether `ModalHost` has anything to draw for this presentation.
        var hasBody: Bool { ModalPresentationBody.hasBody(presentation) }
        /// Whether the body is a `register(_:view:)` one (bespoke content) rather than the
        /// standard `AlertDialog` projection.
        var isBespoke: Bool { presentation.customContent != nil }
        var tokens: ModalTokens { presentation.tokens }
    }

    /// Presents the named shape on a fully-registered renderer.
    static func present(_ name: String) throws -> Presented {
        guard let shape = shape(named: name) else { throw MissingShape(name: name) }
        let renderer = makeRenderer()
        let id = ModalID()
        shape.present(renderer, id)
        guard let presentation = renderer.presentations.first(where: { $0.id == id }) else {
            throw MissingShape(name: name)
        }
        return Presented(renderer: renderer, id: id, presentation: presentation)
    }

    // MARK: - Measuring the body

    /// A body smaller than this in either dimension is not a modal — the shared scaffold alone is a
    /// 48pt primary button plus card padding. Used as the "non-empty body" threshold.
    static let minimumRenderedExtent: CGFloat = 44

    /// A phone-sized layout proposal. Nothing here is orientation-sensitive
    /// (`SwiftUIModalRenderer` pins `isLandscape: false`), so one proposal is enough.
    static let layoutProposal = CGSize(width: 390, height: 844)

    /// Measures the body `ModalHost` draws for `presentation`, by running SwiftUI's REAL layout over
    /// it in a `UIHostingController`.
    ///
    /// This is a LAYOUT measurement, deliberately not a snapshot: it proves the body exists, is
    /// constructible, and lays out to a real size. It proves nothing about appearance — there is no
    /// baseline image anywhere in this suite for the SwiftUI backend.
    ///
    /// `test_measure_discriminatesAnEmptyBody` is the control that keeps this honest: the same
    /// helper over an `EmptyView` must measure `.zero`, otherwise a green measurement here would be
    /// meaningless.
    static func measuredBodySize(of presentation: SwiftUIModalRenderer.Presentation) -> CGSize {
        measuredSize(of: ModalPresentationBody.view(for: presentation))
    }

    static func measuredSize(of view: some View) -> CGSize {
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(origin: .zero, size: layoutProposal)
        host.view.layoutIfNeeded()
        return host.sizeThatFits(in: layoutProposal)
    }

    // MARK: - Renderer setup

    /// A renderer carrying every preset, factory and body the 26 shapes need — the library-side
    /// equivalent of the app's modal setup.
    static func makeRenderer() -> SwiftUIModalRenderer {
        let renderer = SwiftUIModalRenderer(
            alertProperties: GeniePresets.standardProperties(),
            popupProperties: GeniePresets.popupProperties()
        )
        for (style, properties) in stylePresets {
            renderer.register(style: style, properties: properties)
        }
        registerStandardFamily(on: renderer)
        registerBespokeContent(on: renderer)
        return renderer
    }

    /// style → preset. `.standard`/`.popup` are already seeded by `init`.
    static var stylePresets: [(ModalStyle, GBAlertModal.Properties)] {
        [
            (.permissionAlert, GeniePresets.permissionAlertProperties()),
            (.obliqueRed, GeniePresets.obliqueRedProperties()),
            (.errorBanner, GeniePresets.errorBannerProperties()),
            (.forceUpdateBanner, GeniePresets.forceUpdateBannerProperties()),
            (.capBanner, GeniePresets.capBannerProperties()),
            (.quizBanner, GeniePresets.quizBannerProperties()),
            (.trialBanner, GeniePresets.quizBannerProperties()),
            (.aiNotesBanner, GeniePresets.aiNotesBannerProperties()),
            (.creditDeduction, GeniePresets.creditDeductionProperties()),
            (.streak, GeniePresets.streakProperties()),
            (.timerBanner, GeniePresets.timerBannerProperties()),
            (.exitWorksheetBanner, GeniePresets.exitWorksheetBannerProperties()),
            (.renameInput, GeniePresets.renameInputProperties()),
            (.datePickerInput, GeniePresets.datePickerInputProperties()),
            (.badgeUnlock, GeniePresets.badgeUnlockProperties()),
            (.badgeMulti, GeniePresets.badgeMultiProperties()),
            (.badgeDetail, GeniePresets.badgeDetailProperties())
        ]
    }

    /// **The one deliberate deviation from the production registration, stated plainly.**
    ///
    /// `UIKitModalRenderer.AlertHolder.make` resolves a descriptor's `ModalImage` with
    /// `UIImage(named:)`, which searches `Bundle.main`. The app's 12 banner assets live in the
    /// EXAMPLE app's asset catalog, not in this package, so in the library test bundle every one of
    /// them resolves to `nil` — and `GBAlertModal.resolve` treats a nil banner as "no banner slot".
    /// Every banner shape's coverage test would then be quietly asserting `showsBanner == false`,
    /// i.e. testing the absence of the thing it claims to cover.
    ///
    /// So this factory substitutes a generated image whenever — and ONLY when — the descriptor
    /// actually NAMES an asset. It changes nothing else: the same `AlertHolder.make` mapping, the
    /// same style lookup, the same route and content projection (`register(_:factory:)` preserves
    /// both).
    ///
    /// PROVES: the banner slot resolves and is laid out. DOES NOT PROVE: that the named asset
    /// exists, loads, or looks right. `ShapeCoverageTests.test_bannerSubstitution_isTheOnlyDeviationFromProduction`
    /// pins the blast radius to exactly `showsBanner`.
    static func registerStandardFamily(on renderer: SwiftUIModalRenderer) {
        renderer.register(AlertDialog.self) { [weak renderer] descriptor, resolve in
            (
                renderer?.properties(for: descriptor.style),
                UIKitModalRenderer.AlertHolder.make(for: descriptor, resolve: resolve)
                    .copy(banner: substitutedBanner(for: descriptor.image))
            )
        }
        renderer.register(PopupDialog.self) { [weak renderer] descriptor, resolve in
            (
                renderer?.properties(for: descriptor.style),
                UIKitModalRenderer.AlertHolder.make(for: descriptor, resolve: resolve)
                    .copy(banner: substitutedBanner(for: descriptor.image))
            )
        }
    }

    /// `nil` in, `nil` out — a shape with no banner keeps none.
    static func substitutedBanner(for image: ModalImage?) -> UIImage? {
        guard image != nil else { return nil }
        return .gbv3TestSolid(width: 320, height: 200)
    }

    /// The four custom-content descriptor kinds: the two input dialogs the library already shipped,
    /// plus the three bespoke ports (badge grid, loading state, satisfaction row).
    ///
    /// Each is registered exactly the way the library documents it: a factory (descriptor →
    /// `Properties` + `DataHolder`, so the presentation still resolves a real structure) AND a view
    /// (`register(_:view:)`, so `ModalHost` has a body to draw). The two registrations are
    /// independent and neither clears the other.
    static func registerBespokeContent(on renderer: SwiftUIModalRenderer) {
        let renameProperties = GeniePresets.renameInputProperties()
        renderer.register(TextInputDialog.self) { descriptor, resolve in
            (renameProperties, UIKitModalRenderer.TextInputHolder.make(for: descriptor, resolve: resolve))
        }
        renderer.register(TextInputDialog.self, view: { descriptor, resolve in
            SwiftUIModalRenderer.TextInputContent.make(
                for: descriptor, tokens: ModalTokens(from: renameProperties), resolve: resolve
            )
        })

        let datePickerProperties = GeniePresets.datePickerInputProperties()
        renderer.register(DatePickerDialog.self) { descriptor, resolve in
            (datePickerProperties, UIKitModalRenderer.DatePickerHolder.make(for: descriptor, resolve: resolve))
        }
        renderer.register(DatePickerDialog.self, view: { descriptor, resolve in
            SwiftUIModalRenderer.DatePickerContent.make(
                for: descriptor, tokens: ModalTokens(from: datePickerProperties), resolve: resolve
            )
        })

        renderer.register(BadgeDialog.self) { [weak renderer] descriptor, _ in
            (renderer?.properties(for: descriptor.style), badgeHolder(for: descriptor))
        }
        renderer.register(BadgeDialog.self, view: { [weak renderer] descriptor, resolve in
            SwiftUIModalRenderer.BadgeContent.make(
                for: descriptor,
                tokens: tokens(for: descriptor.style, on: renderer),
                resolve: resolve
            )
        })

        renderer.register(LoadingDialog.self) { [weak renderer] descriptor, _ in
            (renderer?.properties(for: descriptor.style), loadingHolder(for: descriptor))
        }
        renderer.register(LoadingDialog.self, view: { [weak renderer] descriptor, resolve in
            SwiftUIModalRenderer.LoadingContent.make(
                for: descriptor,
                tokens: tokens(for: descriptor.style, on: renderer),
                resolve: resolve
            )
        })

        renderer.register(SatisfactionDialog.self) { [weak renderer] descriptor, _ in
            (renderer?.properties(for: descriptor.style), satisfactionHolder(for: descriptor))
        }
        renderer.register(SatisfactionDialog.self, view: { [weak renderer] descriptor, resolve in
            SwiftUIModalRenderer.SatisfactionContent.make(
                for: descriptor,
                tokens: tokens(for: descriptor.style, on: renderer),
                resolve: resolve
            )
        })
    }

    private static func tokens(for style: ModalStyle, on renderer: SwiftUIModalRenderer?) -> ModalTokens {
        guard let properties = renderer?.properties(for: style) else { return .standard }
        return ModalTokens(from: properties)
    }

    // MARK: - Holders for the bespoke descriptors
    //
    // These are the CONSUMER's descriptor→`DataHolder` mappings. They exist so the presentation's
    // `resolved`/`tokens` are derived from the shape's REAL `Properties` rather than the neutral
    // fallback, which is what makes the structural assertions meaningful.
    //
    // STRUCTURAL NOTE, load-bearing for how these tests read: `ResolvedModal.SubtitleKind.custom`
    // means `holder.subtitleCustomView != nil` — a UIKit-only classification. On the SwiftUI
    // backend, bespoke content lives in `AlertModalScaffold`'s `@ViewBuilder` slot
    // (`Presentation.customContent`), NOT on the holder. These holders therefore do NOT fabricate a
    // `UIView` just to make the resolver say `.custom`; the SwiftUI structural equivalent is
    // `customContent != nil`, and that is what the coverage tests assert.

    static func badgeHolder(for descriptor: BadgeDialog) -> GBAlertModal.DataHolder {
        let (titlePlain, titleAttributed) = ModalText.split(descriptor.title)
        let (subtitlePlain, subtitleAttributed) = ModalText.split(descriptor.subtitle)
        return GBAlertModal.DataHolder(
            closeOnTapOverlay: descriptor.closeOnTapOverlay,
            banner: substitutedBanner(for: descriptor.banner),
            title: titlePlain,
            titleAttributed: titleAttributed,
            subtitle: subtitlePlain,
            subtitleAttributed: subtitleAttributed,
            primaryAction: descriptor.primary,
            secondaryAction: descriptor.secondary,
            showCloseButton: descriptor.showCloseButton,
            dismissOnAction: false  // the renderer's gate owns teardown
        )
    }

    static func loadingHolder(for descriptor: LoadingDialog) -> GBAlertModal.DataHolder {
        let (titlePlain, titleAttributed) = ModalText.split(descriptor.title)
        let (subtitlePlain, subtitleAttributed) = ModalText.split(descriptor.subtitle)
        return GBAlertModal.DataHolder(
            closeOnTapOverlay: descriptor.closeOnTapOverlay,
            title: titlePlain,
            titleAttributed: titleAttributed,
            subtitle: subtitlePlain,
            subtitleAttributed: subtitleAttributed,
            primaryAction: descriptor.primary,
            secondaryAction: descriptor.secondary,
            showCloseButton: descriptor.showCloseButton,
            dismissOnAction: false
        )
    }

    static func satisfactionHolder(for descriptor: SatisfactionDialog) -> GBAlertModal.DataHolder {
        let (titlePlain, titleAttributed) = ModalText.split(descriptor.title)
        return GBAlertModal.DataHolder(
            closeOnTapOverlay: descriptor.closeOnTapOverlay,
            title: titlePlain,
            titleAttributed: titleAttributed,
            primaryAction: descriptor.primary,
            dismissOnAction: false
        )
    }

    // MARK: - Text helpers

    /// An `AttributedString` carrying UIKIT-scoped styling — the only scope `ModalText.split`
    /// classifies as attributed (SwiftUI-scoped keys stay "plain" on purpose; see its doc comment).
    /// Shapes whose real content is an `NSAttributedString` are built with this, so their
    /// `SubtitleKind` really is `.attributed` and not accidentally `.plain`.
    static func styled(_ string: String, color: UIColor = .darkGray) -> AttributedString {
        var value = AttributedString(string)
        value.uiKit.foregroundColor = color
        return value
    }

    /// The `badge-unlock-single` subtitle: "you unlocked the **<name>** badge!" — a MIXED-RUN
    /// attributed string (bold badge name inside regular text), exactly as `BadgesPopUpView` builds it.
    static func badgeUnlockSubtitle(badgeName: String) -> AttributedString {
        var subtitle = AttributedString("you unlocked the ")
        subtitle.uiKit.font = .systemFont(ofSize: 16)
        var name = AttributedString(badgeName)
        name.uiKit.font = .boldSystemFont(ofSize: 16)
        var tail = AttributedString(" badge!")
        tail.uiKit.font = .systemFont(ofSize: 16)
        subtitle.append(name)
        subtitle.append(tail)
        return subtitle
    }
}

// MARK: - The 26 shapes

extension GenieShapeCatalog {
    /// One entry per catalog name, in manifest order. Content is transcribed from the catalog
    /// entry of the same name; `[API]` placeholders are kept verbatim so the shapes stay
    /// recognisably the app's.
    static var shapes: [Shape] {
        crossCuttingShapes + worksheetShapes + genieClassShapes
            + campaignShapes + workingSpaceShapes + badgeShapes
    }

    // MARK: Cross-cutting

    static var crossCuttingShapes: [Shape] {
        [
            Shape(name: "standard-one-button") { renderer, id in
                renderer.present(
                    AlertDialog(
                        title: "Failed",
                        subtitle: "You don't have microphone.",
                        primary: "Okay",
                        closeOnTapOverlay: true
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "standard-two-button") { renderer, id in
                renderer.present(
                    AlertDialog(
                        title: "[API] Confirm action",
                        subtitle: "[API] Are you sure you want to proceed?",
                        primary: "Yes",
                        secondary: "No",
                        closeOnTapOverlay: true
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "title-nil-error") { renderer, id in
                renderer.present(
                    // `String?.none`, not a bare `nil`: `AlertDialog` has a String and an
                    // AttributedString initializer, and this pins the String one.
                    AlertDialog(
                        title: String?.none,
                        subtitle: "[API] The operation couldn't be completed. (NSURLErrorDomain error -1009.)",
                        primary: "Okay",
                        closeOnTapOverlay: true
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "close-button-dismiss") { renderer, id in
                renderer.present(
                    AlertDialog(
                        title: "Access Denied",
                        subtitle: "[API] You are not allowed to send messages in this class right now.",
                        primary: "Close",
                        closeOnTapOverlay: true,
                        showCloseButton: true
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "permission-denied-settings") { renderer, id in
                renderer.present(
                    AlertDialog(
                        title: "Allow Permission",
                        subtitle: "Allow Geniebook to access your camera in your device's settings.",
                        primary: "Settings",
                        secondary: "Not now",
                        closeOnTapOverlay: true,
                        style: .permissionAlert
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "oblique-red-leave-confirm") { renderer, id in
                renderer.present(
                    AlertDialog(
                        title: "You're leaving?",
                        subtitle: "The live class has not ended yet. Are you sure you want to leave?",
                        primary: "Yes",
                        secondary: "No",
                        closeOnTapOverlay: true,
                        style: .obliqueRed
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "database-error-banner") { renderer, id in
                renderer.present(
                    AlertDialog(
                        image: ModalImage("img_database_error"),
                        title: "Something went wrong :(",
                        subtitle: "We're fixing our servers as fast as we can.\nTake a break and try again later.",
                        primary: "Okay",
                        style: .errorBanner
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "force-update-banner") { renderer, id in
                renderer.present(
                    AlertDialog(
                        image: ModalImage("img_illust_gc_finished_quiz"),
                        title: "A new update is ready!",
                        subtitle: "[API] Head over to the App Store to download the latest version.",
                        primary: "Go to App Store",
                        style: .forceUpdateBanner
                    ),
                    id: id, resolve: { _ in }
                )
            }
        ]
    }

    // MARK: Worksheet

    static var worksheetShapes: [Shape] {
        [
            // BESPOKE PORT: the loading state. Presented in its RESTING state, which is what the
            // catalog entry shows; `ShapeCoverageTests` drives the busy state separately.
            Shape(name: "worksheet-generating-abused") { renderer, id in
                renderer.present(
                    LoadingDialog(
                        title: AttributedString("Generating Worksheet"),
                        subtitle: AttributedString(
                            "[API] Something went wrong while generating your worksheet.\n\nContinue?"
                        ),
                        primary: "Continue",
                        secondary: "Cancel",
                        isLoading: false
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "worksheet-abused-cap-banner") { renderer, id in
                renderer.present(
                    AlertDialog(
                        image: ModalImage("img_illust_abused_worksheet"),
                        title: "Daily worksheet limit reached",
                        subtitle: "[API] You've reached your daily worksheet generation limit for today.",
                        primary: "Proceed",
                        secondary: "I'll practise something else",
                        style: .capBanner
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "rename-worksheet") { renderer, id in
                renderer.present(
                    TextInputDialog(
                        title: "Rename Worksheet",
                        placeholder: "Worksheet name",
                        initialText: "[API] Chapter 3 Practice Set",
                        primary: "Done",
                        secondary: "Cancel",
                        closeOnTapOverlay: true
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "date-picker-worksheet") { renderer, id in
                renderer.present(
                    DatePickerDialog(
                        title: "Select Date",
                        // Fixed, not `Date()`: a relative seed would make the shape's input drift
                        // day to day for no behavioural reason.
                        initialDate: Date(timeIntervalSince1970: 1_700_000_000),
                        primary: "Done",
                        secondary: "Cancel",
                        closeOnTapOverlay: true
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "streak-popup-banner") { renderer, id in
                renderer.present(
                    AlertDialog(
                        image: ModalImage("streak_lose"),
                        title: "You missed your streak!",
                        subtitle: "[API] You missed your 7 days streak and 15 extra bubbles. "
                            + "Save your streak by doing 5 questions!",
                        primary: "Continue",
                        style: .streak
                    ),
                    id: id, resolve: { _ in }
                )
            },
            // Attributed title AND subtitle in the real app (`QuestionHelper.swift`), so this uses
            // the rich initializer and really does resolve `.attributed`.
            Shape(name: "switch-device-recommendation") { renderer, id in
                renderer.present(
                    AlertDialog(
                        title: GenieShapeCatalog.styled("Device Switch Recommended", color: .systemBlue),
                        subtitle: GenieShapeCatalog.styled(
                            "For the best experience in reading and understanding long passages, "
                                + "you may wish to switch over to the laptop or tablet to complete this exercise"
                        ),
                        primary: "Okay",
                        closeOnTapOverlay: true
                    ),
                    id: id, resolve: { _ in }
                )
            }
        ]
    }

    // MARK: GenieClass

    static var genieClassShapes: [Shape] {
        [
            Shape(name: "quiz-info-banner") { renderer, id in
                renderer.present(
                    AlertDialog(
                        image: ModalImage("img_illust_gc_finished_quiz"),
                        title: "Great Effort",
                        subtitle: "[API] You've completed the quiz for Algebra Fundamentals.",
                        primary: "Got it",
                        style: .quizBanner
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "quiz-begin-banner") { renderer, id in
                renderer.present(
                    AlertDialog(
                        image: ModalImage("img_illust_gc_finished_quiz"),
                        title: "Quiz Time",
                        subtitle: "[API] The GenieClass Algebra Fundamentals Quiz contains 10 MCQ questions "
                            + "and should take about 15 minutes to complete. Are you ready?",
                        primary: "Let's go",
                        secondary: "Dismiss",
                        style: .quizBanner
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "credit-deduction-popup") { renderer, id in
                renderer.present(
                    AlertDialog(
                        title: "Confirm Credit Use",
                        subtitle: "[API] Joining this class will use 1 Mathematics lesson credit.\n\n"
                            + "Mathematics lesson credits left: 5",
                        primary: "Join class",
                        secondary: "Not now",
                        style: .creditDeduction
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "ai-notes-ready-banner") { renderer, id in
                renderer.present(
                    AlertDialog(
                        image: ModalImage("img_illust_ai_notes_banner"),
                        title: String?.none,
                        subtitle: "[API] Your Personalised Summary Notes for Algebra Fundamentals is ready!",
                        primary: "Bring me there!",
                        secondary: "Later",
                        style: .aiNotesBanner
                    ),
                    id: id, resolve: { _ in }
                )
            }
        ]
    }

    // MARK: Campaign

    static var campaignShapes: [Shape] {
        [
            // The one shape presented as `PopupDialog` rather than `AlertDialog(style: .popup)` —
            // the two spellings must resolve through the same style map, and this keeps the
            // retained-for-compatibility type exercised by real content.
            Shape(name: "onboarding-welcome-nobanner") { renderer, id in
                renderer.present(
                    PopupDialog(
                        title: "Hello there!",
                        subtitle: "Let's explore Geniebook!",
                        primary: "I'm ready"
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "onboarding-trial-banner") { renderer, id in
                renderer.present(
                    AlertDialog(
                        image: ModalImage("img_illust_free_trial_ended"),
                        title: "Free trial has ended",
                        subtitle: "Subscribe to continue learning with Geniebook",
                        primary: "View pricing plans",
                        secondary: "Dismiss",
                        style: .trialBanner
                    ),
                    id: id, resolve: { _ in }
                )
            }
        ]
    }

    // MARK: Working space

    static var workingSpaceShapes: [Shape] {
        [
            Shape(name: "exit-worksheet-confirm-banner") { renderer, id in
                renderer.present(
                    AlertDialog(
                        image: ModalImage("ic_exit_worksheet"),
                        title: "Hang in there!",
                        subtitle: "[API] Don't give up, you still have 3 questions remaining. You can do it!",
                        primary: "Keep going!",
                        secondary: "I'll be back!",
                        closeOnTapOverlay: true,
                        style: .exitWorksheetBanner
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "worksheet-ready-timer-banner") { renderer, id in
                renderer.present(
                    AlertDialog(
                        image: ModalImage("img_timer_alert"),
                        title: AttributedString("Are you ready?"),
                        subtitle: GenieShapeCatalog.styled(
                            "[API] You have 30 minutes remaining to complete this Practice Worksheet."
                        ),
                        primary: "Proceed",
                        style: .timerBanner
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "worksheet-timeup-timer-banner") { renderer, id in
                renderer.present(
                    AlertDialog(
                        image: ModalImage("img_timer_alert"),
                        title: AttributedString("Time's up!"),
                        subtitle: GenieShapeCatalog.styled(
                            "Tap \"Continue\" to keep working on the worksheet, or submit for marking."
                        ),
                        primary: "Continue",
                        secondary: "Submit for marking",
                        style: .timerBanner
                    ),
                    id: id, resolve: { _ in }
                )
            }
        ]
    }

    // MARK: Badges — all three are BESPOKE PORTS onto the content seam

    static var badgeShapes: [Shape] {
        [
            Shape(name: "badge-unlock-single") { renderer, id in
                renderer.present(
                    BadgeDialog(
                        // `badge.localImageName` in the real app — per-record, resolved at runtime,
                        // which is exactly what a `ModalImage` NAME is for.
                        banner: ModalImage("[API] badge_math_wizard"),
                        title: AttributedString("Congratulations!"),
                        subtitle: GenieShapeCatalog.badgeUnlockSubtitle(badgeName: "Math Wizard"),
                        badges: [
                            BadgeDialog.Badge(
                                id: "math-wizard",
                                name: "Math Wizard",
                                artwork: ModalImage("[API] badge_math_wizard")
                            )
                        ],
                        primary: "View my badges",
                        secondary: "Dismiss",
                        style: .badgeUnlock
                    ),
                    id: id, resolve: { _ in }
                )
            },
            Shape(name: "badge-unlock-multi") { renderer, id in
                renderer.present(
                    BadgeDialog(
                        banner: ModalImage("img_badge_multi_achievement"),
                        title: AttributedString("Congratulations!"),
                        subtitle: AttributedString("You unlocked new badges."),
                        badges: [
                            BadgeDialog.Badge(id: "math-wizard", name: "Math Wizard",
                                              artwork: ModalImage("[API] badge_math_wizard")),
                            BadgeDialog.Badge(id: "word-smith", name: "Word Smith",
                                              artwork: ModalImage("[API] badge_word_smith")),
                            BadgeDialog.Badge(id: "science-star", name: "Science Star",
                                              artwork: ModalImage("[API] badge_science_star"))
                        ],
                        primary: "View my badges",
                        secondary: "Dismiss",
                        style: .badgeMulti
                    ),
                    id: id, resolve: { _ in }
                )
            },
            // No banner and no subtitle: the WHOLE content is the badge item (artwork + name +
            // description), which the real app passes as a `subtitleCustomView`.
            Shape(name: "badge-detail-popup") { renderer, id in
                renderer.present(
                    BadgeDialog(
                        badges: [
                            BadgeDialog.Badge(
                                id: "math-wizard",
                                name: "[API] Math Wizard",
                                artwork: ModalImage("[API] badge_math_wizard"),
                                detail: "[API] Solved 50 algebra questions without a hint."
                            )
                        ],
                        primary: "Got it",
                        closeOnTapOverlay: true,
                        style: .badgeDetail
                    ),
                    id: id, resolve: { _ in }
                )
            }
        ]
    }

    /// NOT one of the 26. The satisfaction row is the seam's exemplar (the app's
    /// `SatisfactionLevelDialogView`), ported alongside the badge grid and the loading state and
    /// covered by its own test — but it is deliberately absent from `names`, because the catalog
    /// does not list it and this manifest must stay a faithful copy of the catalog.
    static var satisfactionExemplar: Shape {
        Shape(name: "satisfaction-row") { renderer, id in
            renderer.present(
                SatisfactionDialog(
                    title: AttributedString("How helpful was this?"),
                    options: [
                        SatisfactionDialog.Option(id: "not", symbolName: "hand.thumbsdown", label: "Not helpful"),
                        SatisfactionDialog.Option(id: "quite", symbolName: "hand.thumbsup", label: "Quite helpful"),
                        SatisfactionDialog.Option(id: "very", symbolName: "star.fill", label: "Very helpful")
                    ],
                    primary: "Submit"
                ),
                id: id, resolve: { _ in }
            )
        }
    }
}
