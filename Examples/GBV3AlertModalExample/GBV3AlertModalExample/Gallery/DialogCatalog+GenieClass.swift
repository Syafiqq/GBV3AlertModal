//
//  DialogCatalog+GenieClass.swift
//  GBV3AlertModalExample
//
//  Shapes #15, #16, #19, #20 from the catalog: GenieClass quiz banners,
//  live-class credit confirmation, and AI notes ready banner. See
//  docs/superpowers/specs/2026-07-21-dialog-catalog.md sections 15, 16, 19, 20.
//

import UIKit
import GBV3AlertModal

extension DialogCatalog {
    static var genieClassEntries: [DialogEntry] {
        [
            quizInfoBanner,
            quizBeginBanner,
            creditDeductionPopup,
            aiNotesReadyBanner
        ]
    }

    /// #15 `quiz-info-banner` — quiz completed/ended acknowledgement.
    /// `quizName` is `[API]`. Source: `V2RecordedPreviewViewController.swift:725`.
    private static var quizInfoBanner: DialogEntry {
        DialogEntry(name: "quiz-info-banner", category: "GenieClass") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    bannerRatio: 320.0 / 229.0,
                    bannerMaxHeight: 216,
                    bannerFixedHeight: 184
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    banner: UIImage(named: "img_illust_gc_finished_quiz"),
                    title: "Great Effort",
                    subtitle: "[API] You've completed the quiz for Algebra Fundamentals.",
                    primaryAction: "Got it",
                    secondaryAction: nil,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #16 `quiz-begin-banner` — quiz begin prompt. `className`/`questionCount`
    /// are `[API]`. Source: `V2RecordedPreviewViewController.swift:774`.
    private static var quizBeginBanner: DialogEntry {
        DialogEntry(name: "quiz-begin-banner", category: "GenieClass") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    bannerRatio: 320.0 / 229.0,
                    bannerMaxHeight: 216,
                    bannerFixedHeight: 184
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    banner: UIImage(named: "img_illust_gc_finished_quiz"),
                    title: "Quiz Time",
                    subtitle: "[API] The GenieClass Algebra Fundamentals Quiz contains 10 MCQ questions "
                        + "and should take about 15 minutes to complete. Are you ready?",
                    primaryAction: "Let's go",
                    secondaryAction: "Dismiss",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #19 `credit-deduction-popup` — live-class credit confirmation.
    /// `subjectName`/`credit` are `[API]`.
    /// Source: `V3GenieClassDashboardViewController.swift:2076`.
    private static var creditDeductionPopup: DialogEntry {
        DialogEntry(name: "credit-deduction-popup", category: "GenieClass") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    titleFont: GallerySHSans.heavy.font(24)
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    title: "Confirm Credit Use",
                    subtitle: "[API] Joining this class will use 1 Mathematics lesson credit.\n\n"
                        + "Mathematics lesson credits left: 5",
                    primaryAction: "Join class",
                    secondaryAction: "Not now",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #20 `ai-notes-ready-banner` — AI summary notes ready. `title: nil`;
    /// `topicName` is `[API]`.
    /// Source: `V3GenieClassDashboardViewController+AiNotes.swift:245`.
    private static var aiNotesReadyBanner: DialogEntry {
        DialogEntry(name: "ai-notes-ready-banner", category: "GenieClass/AiNotes") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    bannerRatio: 960.0 / 681.0,
                    bannerMaxHeight: 320,
                    bannerFixedHeight: 256
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    banner: UIImage(named: "img_illust_ai_notes_banner"),
                    title: nil,
                    subtitle: "[API] Your Personalised Summary Notes for Algebra Fundamentals is ready!",
                    primaryAction: "Bring me there!",
                    secondaryAction: "Later",
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }
}
