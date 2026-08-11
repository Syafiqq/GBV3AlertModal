//
//  DialogCatalog+WorkingSpace.swift
//  GBV3AlertModalExample
//
//  Shapes #21-#23 from the catalog: exit-worksheet confirmation and the two
//  worksheet timer banners (ready / timed-up). See
//  docs/superpowers/specs/2026-07-21-dialog-catalog.md sections 21-23.
//
//  #22/#23 use `subtitleAttributed` in the real app (rendered via a markdown
//  parser combining a template with remaining-time/nudge state); the demo
//  renders that as a plain attributed string using the catalog's font/color
//  (`subtitleFont`/`subtitleColor` from the shared `properties.copy`).
//

import UIKit
import GBV3AlertModal

extension DialogCatalog {
    static var workingSpaceEntries: [DialogEntry] {
        [
            exitWorksheetConfirmBanner,
            worksheetReadyTimerBanner,
            worksheetTimeupTimerBanner
        ]
    }

    /// #21 `exit-worksheet-confirm-banner` — leave-mid-worksheet nudge.
    /// Note the button/action mapping is inverted from what the localized
    /// keys suggest: `primaryAction` is the "stay" (keep going) button,
    /// `secondaryAction` is "leave" — kept verbatim from the catalog.
    /// `unAnsweredRemaining` is `[API]`.
    /// Source: `V1WorkingSpaceViewController.swift:2433`.
    private static var exitWorksheetConfirmBanner: DialogEntry {
        DialogEntry(name: "exit-worksheet-confirm-banner", category: "Worksheet/WorkingSpace") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    bannerRatio: 365.0 / 206.0,
                    bannerMaxHeight: 144,
                    bannerFixedHeight: 144
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: true,
                    banner: UIImage(named: "ic_exit_worksheet"),
                    title: "Hang in there!",
                    subtitle: "[API] Don't give up, you still have 3 questions remaining. You can do it!",
                    primaryAction: "Keep going!",
                    secondaryAction: "I'll be back!",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// Shared preset family for #22/#23 (`properties.copy` with matching
    /// padding/banner geometry/title+subtitle styling).
    private static var timerBannerProperties: GBAlertModal.Properties {
        GalleryPresets.properties.copy(
            padding: UIMinMaxEdgeInsets(
                top: (32, 32),
                left: (32, 32),
                bottom: (32, 32),
                right: (32, 32)
            ),
            bannerRatio: 193.0 / 170.0,
            bannerMaxHeight: 170,
            bannerFixedHeight: 170,
            titleFont: GallerySHSans.bold.font(24),
            titleColor: GalleryColor.gbpNavy,
            subtitleFont: GallerySHSans.regular.font(16),
            subtitleColor: GalleryColor.labelSubtitle
        )
    }

    /// #22 `worksheet-ready-timer-banner` — pre-start timer prompt.
    /// `worksheet.worksheetTypeEnum`/remaining-time/nudge eligibility are
    /// `[API]`. Source: `V1WorkingSpaceViewController.swift:2668`.
    private static var worksheetReadyTimerBanner: DialogEntry {
        DialogEntry(name: "worksheet-ready-timer-banner", category: "Worksheet/WorkingSpace") {
            let subtitle = NSAttributedString(
                string: "[API] You have 30 minutes remaining to complete this Practice Worksheet.",
                attributes: [
                    .font: GallerySHSans.regular.font(16),
                    .foregroundColor: GalleryColor.labelSubtitle
                ]
            )
            return SampleAlertModal(
                properties: timerBannerProperties,
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    banner: UIImage(named: "img_timer_alert"),
                    title: "Are you ready?",
                    subtitleAttributed: subtitle,
                    primaryAction: "Proceed",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #23 `worksheet-timeup-timer-banner` — timer-expired prompt. Subtitle
    /// is a literal English string in the source, not `.localized`.
    /// Source: `V1WorkingSpaceViewController.swift:2719`.
    private static var worksheetTimeupTimerBanner: DialogEntry {
        DialogEntry(name: "worksheet-timeup-timer-banner", category: "Worksheet/WorkingSpace") {
            let subtitle = NSAttributedString(
                string: "Tap \"Continue\" to keep working on the worksheet, or submit for marking.",
                attributes: [
                    .font: GallerySHSans.regular.font(16),
                    .foregroundColor: GalleryColor.labelSubtitle
                ]
            )
            return SampleAlertModal(
                properties: timerBannerProperties,
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    banner: UIImage(named: "img_timer_alert"),
                    title: "Time's up!",
                    subtitleAttributed: subtitle,
                    primaryAction: "Continue",
                    secondaryAction: "Submit for marking",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }
}
