//
//  DialogCatalog+CrossCutting.swift
//  GBV3AlertModalExample
//
//  Shapes #1-#8 from the catalog: the generic acknowledgement/confirm shapes
//  reused across almost every feature area, plus the four "own preset"
//  shapes (permission alert, red leave-confirm, database error banner,
//  force-update banner). See
//  docs/superpowers/specs/2026-07-21-dialog-catalog.md sections 1-8.
//

import UIKit
import GBV3AlertModal

extension DialogCatalog {
    static var crossCuttingEntries: [DialogEntry] {
        [
            standardOneButton,
            standardTwoButton,
            titleNilError,
            closeButtonDismiss,
            permissionDeniedSettings,
            obliqueRedLeaveConfirm,
            databaseErrorBanner,
            forceUpdateBanner
        ]
    }

    /// #1 `standard-one-button` — cross-cutting informational acknowledgement.
    /// Source: `AudioRecordManager.swift:245`.
    private static var standardOneButton: DialogEntry {
        DialogEntry(name: "standard-one-button", category: "Cross-cutting") {
            SampleAlertModal(
                properties: GalleryPresets.properties,
                holder: GalleryPresets.holder.copy(
                    title: "Failed",
                    subtitle: "You don't have microphone.",
                    primaryAction: "Okay",
                    showCloseButton: false,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #2 `standard-two-button` — the most common shape (~20 call sites fold
    /// into this). `title`/`subtitle` are caller-supplied at every real call
    /// site; the demo stands in a representative confirm prompt.
    /// Source: `UIViewControllerExtensions.swift:17`.
    private static var standardTwoButton: DialogEntry {
        DialogEntry(name: "standard-two-button", category: "Cross-cutting") {
            SampleAlertModal(
                properties: GalleryPresets.properties,
                holder: GalleryPresets.holder.copy(
                    title: "[API] Confirm action",
                    subtitle: "[API] Are you sure you want to proceed?",
                    primaryAction: "Yes",
                    secondaryAction: "No",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #3 `title-nil-error` — WKWebView load-failure handlers (6 files, 12
    /// call sites). `title: nil`; subtitle is always the raw system
    /// `error.localizedDescription`.
    /// Source: `V3GenieClassPracticeQuizViewController.swift:485`.
    private static var titleNilError: DialogEntry {
        DialogEntry(name: "title-nil-error", category: "Cross-cutting") {
            SampleAlertModal(
                properties: GalleryPresets.properties,
                holder: GalleryPresets.holder.copy(
                    title: nil,
                    subtitle: "[API] The operation couldn't be completed. (NSURLErrorDomain error -1009.)",
                    primaryAction: "Okay",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #4 `close-button-dismiss` — GenieAsk chat-page block/error dismissal.
    /// Source: `GAChatPageViewController.swift:1067` (and `:1088`).
    private static var closeButtonDismiss: DialogEntry {
        DialogEntry(name: "close-button-dismiss", category: "GenieAsk-ChatPage") {
            SampleAlertModal(
                properties: GalleryPresets.properties,
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: true,
                    title: "Access Denied",
                    subtitle: "[API] You are not allowed to send messages in this class right now.",
                    primaryAction: "Close",
                    secondaryAction: nil,
                    showCloseButton: true,
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #5 `permission-denied-settings` — camera/mic permission nudge.
    /// Uses `permissionAlertProperties` (the inline override built at every
    /// call site: asymmetric 20/30 padding, bold/heavy 24 title, tighter
    /// space). Source: `GACameraCell.swift:178`.
    private static var permissionDeniedSettings: DialogEntry {
        DialogEntry(name: "permission-denied-settings", category: "GenieAsk") {
            SampleAlertModal(
                properties: GalleryPresets.permissionAlertProperties,
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: true,
                    title: "Allow Permission",
                    subtitle: "Allow Geniebook to access your camera in your device's settings.",
                    primaryAction: "Settings",
                    secondaryAction: "Not now",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #6 `oblique-red-leave-confirm` — leave-class confirmation, styled with
    /// the red oblique primary theme (`obliqueBottomLeftRedTheme`). All
    /// strings are hardcoded literals at the call site (not `.localized`).
    /// Source: `V1OnlineLessonViewController.swift:1813`.
    private static var obliqueRedLeaveConfirm: DialogEntry {
        DialogEntry(name: "oblique-red-leave-confirm", category: "GenieClass-OnlineLesson") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    primaryActionStyle: .obliqueBottomLeft(GalleryPresets.obliqueBottomLeftRedTheme)
                ),
                holder: GalleryPresets.holder.copy(
                    title: "You're leaving?",
                    subtitle: "The live class has not ended yet. Are you sure you want to leave?",
                    primaryAction: "Yes",
                    secondaryAction: "No",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #7 `database-error-banner` — generic connection-error banner, reused
    /// by `V2AlertModel+Error.swift`'s `presentError`.
    /// Source: `UiKitErrorHandlerHelper+Common.swift:72`.
    private static var databaseErrorBanner: DialogEntry {
        DialogEntry(name: "database-error-banner", category: "Common/ErrorHandling") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    bannerRatio: 295.0 / 256.0,
                    bannerMaxHeight: 320,
                    bannerFixedHeight: 256
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    banner: UIImage(named: "img_database_error"),
                    title: "Something went wrong :(",
                    subtitle: "We're fixing our servers as fast as we can.\nTake a break and try again later.",
                    primaryAction: "Okay",
                    secondaryAction: nil,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #8 `force-update-banner` — app version gate. `wrong_version_arlet`'s
    /// full localized text isn't in the catalog's deduped strings dump (only
    /// its key is referenced); the subtitle below approximates its meaning
    /// per the spec's shape description rather than reproducing an unverified
    /// string. Banner shown unconditionally (the `isEligibleForJcUiVariant`
    /// gate that would hide it isn't modeled in this demo).
    /// Source: `APIClient.swift:77`.
    private static var forceUpdateBanner: DialogEntry {
        DialogEntry(name: "force-update-banner", category: "App-level") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    bannerRatio: 320.0 / 320.0,
                    bannerMaxHeight: 320,
                    bannerFixedHeight: 256
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    banner: UIImage(named: "img_illust_gc_finished_quiz"),
                    title: "A new update is ready!",
                    subtitle: "[API] Head over to the App Store to download the latest version.",
                    primaryAction: "Go to App Store",
                    secondaryAction: nil,
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }
}
