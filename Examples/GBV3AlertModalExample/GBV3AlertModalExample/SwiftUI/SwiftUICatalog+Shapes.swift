//
//  SwiftUICatalog+Shapes.swift
//  GBV3AlertModalExample
//
//  The 26 shapes, as executor descriptors, in `DialogCatalog.entries` order.
//
//  Every `name`/`category` and every string is transcribed from the
//  `DialogCatalog+<Category>.swift` entry of the same name — including the
//  `[API]` placeholders, so the shapes stay recognisably the app's. Styling is
//  asked for by `ModalStyle` token (see `SwiftUICatalog+Presets.swift`).
//
//  Read the `divergences:` argument on each entry as the honest part: it is what
//  this SwiftUI render is KNOWN to get differently from its UIKit twin, and it
//  is shown on the row in the gallery.
//

import Foundation
import UIKit
import GBV3AlertModal

// MARK: - Cross-cutting (#1–#8)

extension SwiftUICatalog {
    static var crossCuttingEntries: [SwiftUICatalogEntry] {
        [
            // #1 — cross-cutting informational acknowledgement.
            SwiftUICatalogEntry.renderable("standard-one-button", category: "Cross-cutting") {
                AlertDialog(
                    title: "Failed",
                    subtitle: "You don't have microphone.",
                    primary: "Okay",
                    closeOnTapOverlay: true
                )
            },
            // #2 — the most common shape (~20 call sites fold into this).
            SwiftUICatalogEntry.renderable("standard-two-button", category: "Cross-cutting") {
                AlertDialog(
                    title: "[API] Confirm action",
                    subtitle: "[API] Are you sure you want to proceed?",
                    primary: "Yes",
                    secondary: "No",
                    closeOnTapOverlay: true
                )
            },
            // #3 — WKWebView load failures: `title: nil`, subtitle is the raw system error.
            // `String?.none` (not a bare `nil`) pins the String initializer.
            SwiftUICatalogEntry.renderable("title-nil-error", category: "Cross-cutting") {
                AlertDialog(
                    title: String?.none,
                    subtitle: "[API] The operation couldn't be completed. (NSURLErrorDomain error -1009.)",
                    primary: "Okay",
                    closeOnTapOverlay: true
                )
            },
            // #4 — GenieAsk chat-page block/error dismissal (close button).
            SwiftUICatalogEntry.renderable("close-button-dismiss", category: "GenieAsk-ChatPage") {
                AlertDialog(
                    title: "Access Denied",
                    subtitle: "[API] You are not allowed to send messages in this class right now.",
                    primary: "Close",
                    closeOnTapOverlay: true,
                    showCloseButton: true
                )
            },
            // #5 — camera/mic permission nudge, own preset.
            SwiftUICatalogEntry.renderable("permission-denied-settings", category: "GenieAsk") {
                AlertDialog(
                    title: "Allow Permission",
                    subtitle: "Allow Geniebook to access your camera in your device's settings.",
                    primary: "Settings",
                    secondary: "Not now",
                    closeOnTapOverlay: true,
                    style: .geniePermissionAlert
                )
            },
            // #6 — leave-class confirmation with the red oblique primary theme.
            SwiftUICatalogEntry.renderable("oblique-red-leave-confirm", category: "GenieClass-OnlineLesson") {
                AlertDialog(
                    title: "You're leaving?",
                    subtitle: "The live class has not ended yet. Are you sure you want to leave?",
                    primary: "Yes",
                    secondary: "No",
                    closeOnTapOverlay: true,
                    style: .genieObliqueRed
                )
            },
            // #7 — generic connection-error banner.
            SwiftUICatalogEntry.renderable(
                "database-error-banner",
                category: "Common/ErrorHandling",
                divergences: [.bannerArtworkNote]
            ) {
                AlertDialog(
                    image: ModalImage("img_database_error"),
                    title: "Something went wrong :(",
                    subtitle: "We're fixing our servers as fast as we can.\nTake a break and try again later.",
                    primary: "Okay",
                    style: .genieErrorBanner
                )
            },
            // #8 — app version gate.
            SwiftUICatalogEntry.renderable(
                "force-update-banner",
                category: "App-level",
                divergences: [.bannerArtworkNote]
            ) {
                AlertDialog(
                    image: ModalImage("img_illust_gc_finished_quiz"),
                    title: "A new update is ready!",
                    subtitle: "[API] Head over to the App Store to download the latest version.",
                    primary: "Go to App Store",
                    style: .genieForceUpdateBanner
                )
            }
        ]
    }
}

// MARK: - Worksheet (#9–#14)

extension SwiftUICatalog {
    static var worksheetEntries: [SwiftUICatalogEntry] {
        [
            // #9 — BESPOKE PORT: the confirm whose primary can go busy. Shown in
            // its resting state, which is the state the catalog entry describes.
            SwiftUICatalogEntry.renderable(
                "worksheet-generating-abused",
                category: "Worksheet",
                divergences: [.loadingPort, .bespokePort]
            ) {
                LoadingDialog(
                    title: AttributedString("Generating Worksheet"),
                    subtitle: AttributedString(
                        "[API] Something went wrong while generating your worksheet.\n\nContinue?"
                    ),
                    primary: "Continue",
                    secondary: "Cancel",
                    isLoading: false
                )
            },
            // #10 — daily/topic generation cap (cap1 variant).
            SwiftUICatalogEntry.renderable(
                "worksheet-abused-cap-banner",
                category: "Worksheet",
                divergences: [.bannerArtworkNote]
            ) {
                AlertDialog(
                    image: ModalImage("img_illust_abused_worksheet"),
                    title: "Daily worksheet limit reached",
                    subtitle: "[API] You've reached your daily worksheet generation limit for today.",
                    primary: "Proceed",
                    secondary: "I'll practise something else",
                    style: .genieCapBanner
                )
            },
            // #11 — text input. `placeholder` is empty on purpose: the UIKit entry
            // has no placeholder, only the seeded worksheet name.
            SwiftUICatalogEntry.renderable(
                "rename-worksheet",
                category: "Worksheet",
                divergences: [.bespokePort, .inputChrome]
            ) {
                TextInputDialog(
                    title: "Rename Worksheet",
                    placeholder: "",
                    initialText: "[API] Chapter 3 Practice Set",
                    primary: "Done",
                    secondary: "Cancel",
                    closeOnTapOverlay: true
                )
            },
            // #12 — wheel date picker, seeded to +14 days like the UIKit entry.
            SwiftUICatalogEntry.renderable(
                "date-picker-worksheet",
                category: "Worksheet",
                divergences: [.bespokePort, .inputChrome, .datePickerRange]
            ) {
                DatePickerDialog(
                    title: "Select Date",
                    initialDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date(),
                    primary: "Done",
                    secondary: "Cancel",
                    closeOnTapOverlay: true
                )
            },
            // #13 — missed-streak nudge (salvage case).
            SwiftUICatalogEntry.renderable(
                "streak-popup-banner",
                category: "Worksheet/Streak",
                divergences: [.bannerArtworkNote]
            ) {
                AlertDialog(
                    image: ModalImage("streak_lose"),
                    title: "You missed your streak!",
                    subtitle: "[API] You missed your 7 days streak and 15 extra bubbles. "
                        + "Save your streak by doing 5 questions!",
                    primary: "Continue",
                    style: .genieStreak
                )
            },
            // #14 — the one shape with BOTH title and subtitle attributed.
            SwiftUICatalogEntry.renderable(
                "switch-device-recommendation",
                category: "Worksheet/Content",
                divergences: [.attributedRuns]
            ) {
                AlertDialog(
                    title: SwiftUICatalog.styled(
                        "Device Switch Recommended",
                        font: GallerySHSans.bold.font(16),
                        color: GalleryColor.blueSky
                    ),
                    subtitle: SwiftUICatalog.styled(
                        "For the best experience in reading and understanding long passages, "
                            + "you may wish to switch over to the laptop or tablet to complete this exercise",
                        font: GallerySHSans.medium.font(16),
                        color: GalleryColor.textPrimaryDark
                    ),
                    primary: "Okay",
                    closeOnTapOverlay: true
                )
            }
        ]
    }
}

// MARK: - GenieClass (#15, #16, #19, #20)

extension SwiftUICatalog {
    static var genieClassEntries: [SwiftUICatalogEntry] {
        [
            // #15 — quiz completed acknowledgement.
            SwiftUICatalogEntry.renderable(
                "quiz-info-banner",
                category: "GenieClass",
                divergences: [.bannerArtworkNote]
            ) {
                AlertDialog(
                    image: ModalImage("img_illust_gc_finished_quiz"),
                    title: "Great Effort",
                    subtitle: "[API] You've completed the quiz for Algebra Fundamentals.",
                    primary: "Got it",
                    style: .genieQuizBanner
                )
            },
            // #16 — quiz begin prompt.
            SwiftUICatalogEntry.renderable(
                "quiz-begin-banner",
                category: "GenieClass",
                divergences: [.bannerArtworkNote]
            ) {
                AlertDialog(
                    image: ModalImage("img_illust_gc_finished_quiz"),
                    title: "Quiz Time",
                    subtitle: "[API] The GenieClass Algebra Fundamentals Quiz contains 10 MCQ questions "
                        + "and should take about 15 minutes to complete. Are you ready?",
                    primary: "Let's go",
                    secondary: "Dismiss",
                    style: .genieQuizBanner
                )
            },
            // #19 — live-class credit confirmation.
            SwiftUICatalogEntry.renderable("credit-deduction-popup", category: "GenieClass") {
                AlertDialog(
                    title: "Confirm Credit Use",
                    subtitle: "[API] Joining this class will use 1 Mathematics lesson credit.\n\n"
                        + "Mathematics lesson credits left: 5",
                    primary: "Join class",
                    secondary: "Not now",
                    style: .genieCreditDeduction
                )
            },
            // #20 — AI summary notes ready. `title: nil` WITH a banner.
            SwiftUICatalogEntry.renderable(
                "ai-notes-ready-banner",
                category: "GenieClass/AiNotes",
                divergences: [.bannerArtworkNote]
            ) {
                AlertDialog(
                    image: ModalImage("img_illust_ai_notes_banner"),
                    title: String?.none,
                    subtitle: "[API] Your Personalised Summary Notes for Algebra Fundamentals is ready!",
                    primary: "Bring me there!",
                    secondary: "Later",
                    style: .genieAiNotesBanner
                )
            }
        ]
    }
}

// MARK: - Campaign (#17, #18)

extension SwiftUICatalog {
    static var campaignEntries: [SwiftUICatalogEntry] {
        [
            // #17 — first-run welcome popup, no banner. Presented as `PopupDialog`
            // rather than `AlertDialog(style: .popup)`, so the retained-for-
            // compatibility type stays exercised by real content; both spellings
            // resolve through the same style map.
            SwiftUICatalogEntry.renderable("onboarding-welcome-nobanner", category: "Campaign/Onboarding") {
                PopupDialog(
                    title: "Hello there!",
                    subtitle: "Let's explore Geniebook!",
                    primary: "I'm ready"
                )
            },
            // #18 — free-trial-ended banner.
            SwiftUICatalogEntry.renderable(
                "onboarding-trial-banner",
                category: "Campaign/Onboarding",
                divergences: [.bannerArtworkNote]
            ) {
                AlertDialog(
                    image: ModalImage("img_illust_free_trial_ended"),
                    title: "Free trial has ended",
                    subtitle: "Subscribe to continue learning with Geniebook",
                    primary: "View pricing plans",
                    secondary: "Dismiss",
                    style: .genieTrialBanner
                )
            }
        ]
    }
}

// MARK: - Working space (#21–#23)

extension SwiftUICatalog {
    static var workingSpaceEntries: [SwiftUICatalogEntry] {
        [
            // #21 — leave-mid-worksheet nudge. Primary is "stay", secondary is
            // "leave": inverted from what the copy suggests, verbatim from the catalog.
            SwiftUICatalogEntry.renderable(
                "exit-worksheet-confirm-banner",
                category: "Worksheet/WorkingSpace",
                divergences: [.bannerArtworkNote]
            ) {
                AlertDialog(
                    image: ModalImage("ic_exit_worksheet"),
                    title: "Hang in there!",
                    subtitle: "[API] Don't give up, you still have 3 questions remaining. You can do it!",
                    primary: "Keep going!",
                    secondary: "I'll be back!",
                    closeOnTapOverlay: true,
                    style: .genieExitWorksheetBanner
                )
            },
            // #22 — pre-start timer prompt (attributed subtitle).
            SwiftUICatalogEntry.renderable(
                "worksheet-ready-timer-banner",
                category: "Worksheet/WorkingSpace",
                divergences: [.bannerArtworkNote, .attributedRuns]
            ) {
                AlertDialog(
                    image: ModalImage("img_timer_alert"),
                    title: AttributedString("Are you ready?"),
                    subtitle: SwiftUICatalog.styled(
                        "[API] You have 30 minutes remaining to complete this Practice Worksheet.",
                        font: GallerySHSans.regular.font(16),
                        color: GalleryColor.labelSubtitle
                    ),
                    primary: "Proceed",
                    style: .genieTimerBanner
                )
            },
            // #23 — timer-expired prompt (attributed subtitle).
            SwiftUICatalogEntry.renderable(
                "worksheet-timeup-timer-banner",
                category: "Worksheet/WorkingSpace",
                divergences: [.bannerArtworkNote, .attributedRuns]
            ) {
                AlertDialog(
                    image: ModalImage("img_timer_alert"),
                    title: AttributedString("Time's up!"),
                    subtitle: SwiftUICatalog.styled(
                        "Tap \"Continue\" to keep working on the worksheet, or submit for marking.",
                        font: GallerySHSans.regular.font(16),
                        color: GalleryColor.labelSubtitle
                    ),
                    primary: "Continue",
                    secondary: "Submit for marking",
                    style: .genieTimerBanner
                )
            }
        ]
    }
}

// MARK: - Badges (#24–#26) — all three are bespoke ports onto the content seam

extension SwiftUICatalog {
    static var badgeEntries: [SwiftUICatalogEntry] {
        [
            // #24 — one badge unlocked. The UIKit entry's banner is a GENERATED
            // placeholder image (the real `badge.localImageName` is per-record);
            // `ModalImage` can only carry a NAME, so this entry carries no banner
            // at all rather than naming an asset that does not exist.
            SwiftUICatalogEntry.renderable(
                "badge-unlock-single",
                category: "Campaign/Badges",
                divergences: [.bespokePort, .badgeBannerMissing, .attributedRuns]
            ) {
                BadgeDialog(
                    title: AttributedString("Congratulations!"),
                    subtitle: SwiftUICatalog.badgeUnlockSubtitle(badgeName: "Math Wizard"),
                    // Empty: the UIKit entry shows banner + title + subtitle only,
                    // no badge grid. Adding cells here would be invented content.
                    badges: [],
                    primary: "View my badges",
                    secondary: "Dismiss",
                    style: .genieBadgeUnlock
                )
            },
            // #25 — multiple badges unlocked, static banner (no grid, as in UIKit).
            SwiftUICatalogEntry.renderable(
                "badge-unlock-multi",
                category: "Campaign/Badges",
                divergences: [.bespokePort, .bannerArtworkNote]
            ) {
                BadgeDialog(
                    banner: ModalImage("img_badge_multi_achievement"),
                    title: AttributedString("Congratulations!"),
                    subtitle: AttributedString("You unlocked new badges."),
                    badges: [],
                    primary: "View my badges",
                    secondary: "Dismiss",
                    style: .genieBadgeMulti
                )
            },
            // #26 — tapped-badge detail: no banner, no subtitle. The WHOLE content
            // is the badge item (artwork + name + description), which the UIKit
            // entry passes as a `subtitleCustomView`.
            SwiftUICatalogEntry.renderable(
                "badge-detail-popup",
                category: "Progress/Badges",
                divergences: [.bespokePort, .badgeArtworkMissing, .subtitleSlotNone]
            ) {
                BadgeDialog(
                    badges: [
                        BadgeDialog.Badge(
                            id: "math-wizard",
                            name: "[API] Math Wizard",
                            detail: "[API] Solved 50 algebra questions without a hint."
                        )
                    ],
                    primary: "Got it",
                    closeOnTapOverlay: true,
                    style: .genieBadgeDetail
                )
            }
        ]
    }

    /// The `badge-unlock-single` subtitle: "you unlocked the **<name>** badge!" —
    /// a MIXED-RUN attributed string, exactly as `BadgesPopUpView` builds it.
    static func badgeUnlockSubtitle(badgeName: String) -> AttributedString {
        var subtitle = styled(
            "you unlocked the ",
            font: GallerySHSans.regular.font(16),
            color: GalleryColor.labelSubtitle
        )
        subtitle.append(styled(
            badgeName,
            font: GallerySHSans.bold.font(16),
            color: GalleryColor.labelSubtitle
        ))
        subtitle.append(styled(
            " badge!",
            font: GallerySHSans.regular.font(16),
            color: GalleryColor.labelSubtitle
        ))
        return subtitle
    }
}
