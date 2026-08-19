//
//  DialogCatalog+Worksheet.swift
//  GBV3AlertModalExample
//
//  Shapes #9-#14 from the catalog: worksheet generation/abuse, the two
//  worksheet shapes, streak popup, and the device-switch recommendation. See
//  docs/superpowers/specs/2026-07-21-dialog-catalog.md sections 9-14.
//
//  The rename/date-picker `subtitleCustomView`s mirror the view construction
//  in `V3AlertModal+Worksheet.swift` (distribution repo) using plain
//  `NSLayoutConstraint`s in place of that file's SnapKit + Rx usage, which
//  aren't available to this example target.
//

import UIKit
import GBV3AlertModal

extension DialogCatalog {
    static var worksheetEntries: [DialogEntry] {
        [
            worksheetGeneratingAbused,
            worksheetAbusedCapBanner,
            renameWorksheet,
            datePickerWorksheet,
            streakPopupBanner,
            switchDeviceRecommendation
        ]
    }

    /// #9 `worksheet-generating-abused` — 10 near-identical call sites fold
    /// into this. Subtitle is `"\(error.message)\n\n\("action_continue".localized)?"`.
    /// Source: `V1WorksheetViewController.swift:984`.
    private static var worksheetGeneratingAbused: DialogEntry {
        DialogEntry(name: "worksheet-generating-abused", category: "Worksheet") {
            SampleAlertModal(
                properties: GalleryPresets.properties,
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    title: "Generating Worksheet",
                    subtitle: "[API] Something went wrong while generating your worksheet.\n\nContinue?",
                    primaryAction: "Continue",
                    secondaryAction: "Cancel",
                    showCloseButton: false,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #10 `worksheet-abused-cap-banner` — daily/topic generation cap
    /// (cap1/cap2 title variants; shown here as cap1). 12 call sites fold
    /// into this. Source: `V2CustomisedWorksheetGeneratorViewController.swift:965`.
    private static var worksheetAbusedCapBanner: DialogEntry {
        DialogEntry(name: "worksheet-abused-cap-banner", category: "Worksheet") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    bannerRatio: 320.0 / 197.0,
                    bannerMaxHeight: 216,
                    bannerFixedHeight: 184
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    banner: UIImage(named: "img_illust_abused_worksheet"),
                    title: "Daily worksheet limit reached",
                    subtitle: "[API] You've reached your daily worksheet generation limit for today.",
                    primaryAction: "Proceed",
                    secondaryAction: "I'll practise something else",
                    showCloseButton: false,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #11 `rename-worksheet` — bordered `UITextView` seeded with the
    /// worksheet's current name (`[API]`, per-worksheet). Preset mirrors the
    /// `renameWorksheet:` convenience init: heavy 24 title, tighter top/bottom
    /// padding, wider title/subtitle/interButton spacing.
    /// Source: `V1WorksheetViewController.swift:385`.
    private static var renameWorksheet: DialogEntry {
        DialogEntry(name: "rename-worksheet", category: "Worksheet") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    padding: GalleryPresets.padding.copy(
                        top: (20, 32),
                        bottom: (16, 16)
                    ),
                    titleFont: GallerySHSans.heavy.font(24),
                    space: GalleryPresets.space.copy(
                        title: 16,
                        subtitle: 32,
                        interButton: 8
                    )
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: true,
                    title: "Rename Worksheet",
                    subtitleCustomView: makeRenameWorksheetView(seededText: "[API] Chapter 3 Practice Set"),
                    primaryAction: "Done",
                    secondaryAction: "Cancel",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #12 `date-picker-worksheet` — wheel-style `UIDatePicker` (min =
    /// tomorrow, max = +2y). Shown here as the `changeWorksheetDueDateAt:`
    /// variant, seeded to +14 days (`reopenWorksheet:`'s default).
    /// Source: `V1WorksheetViewController.swift:410`.
    private static var datePickerWorksheet: DialogEntry {
        DialogEntry(name: "date-picker-worksheet", category: "Worksheet") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    padding: GalleryPresets.padding.copy(
                        top: (20, 32),
                        left: (12, 40),
                        bottom: (16, 16),
                        right: (12, 40)
                    ),
                    titleFont: GallerySHSans.heavy.font(24),
                    space: GalleryPresets.space.copy(
                        title: 0,
                        subtitle: 8,
                        interButton: 8
                    )
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: true,
                    title: "Select Date",
                    subtitleCustomView: makeDatePickerWorksheetView(
                        seededDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
                    ),
                    primaryAction: "Done",
                    secondaryAction: "Cancel",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #13 `streak-popup-banner` — salvage case (missed-streak nudge).
    /// `day`/`bubble` counts are `[API]` (per-user streak state).
    /// Source: `StreakPopUpView.swift:42`.
    private static var streakPopupBanner: DialogEntry {
        DialogEntry(name: "streak-popup-banner", category: "Worksheet/Streak") {
            SampleAlertModal(
                properties: GalleryPresets.streakModalProperties,
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    banner: UIImage(named: "streak_lose"),
                    title: "You missed your streak!",
                    subtitle: "[API] You missed your 7 days streak and 15 extra bubbles. Save your streak by doing 5 questions!",
                    primaryAction: "Continue",
                    secondaryAction: nil,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #14 `switch-device-recommendation` — subject-specific device nudge,
    /// uses `titleAttributed`/`subtitleAttributed` instead of plain strings
    /// (no `properties`/`holder` overrides beyond that).
    /// Source: `QuestionHelper.swift:111`.
    private static var switchDeviceRecommendation: DialogEntry {
        DialogEntry(name: "switch-device-recommendation", category: "Worksheet/Content") {
            let title = NSAttributedString(
                string: "Device Switch Recommended",
                attributes: [
                    .font: GallerySHSans.bold.font(16),
                    .foregroundColor: GalleryColor.blueSky
                ]
            )
            let subtitle = NSAttributedString(
                string: "For the best experience in reading and understanding long passages, "
                    + "you may wish to switch over to the laptop or tablet to complete this exercise",
                attributes: [
                    .font: GallerySHSans.medium.font(16),
                    .foregroundColor: GalleryColor.textPrimaryDark
                ]
            )
            return SampleAlertModal(
                properties: GalleryPresets.properties,
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: true,
                    titleAttributed: title,
                    subtitleAttributed: subtitle,
                    primaryAction: "Okay",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    // MARK: - Worksheet custom views
    // Mirrors `V3AlertModal+Worksheet.swift`'s
    // `generateViewForRenameWorksheetDesign()` / `generateViewForDatePickerWorksheetDesign()`,
    // using `NSLayoutConstraint` anchors since SnapKit isn't linked into this
    // example target.

    private static func makeRenameWorksheetView(seededText: String) -> UIView {
        let container = UIView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 16
        container.layer.borderWidth = 1
        container.layer.borderColor = GalleryColor.borderLight.cgColor

        let textView = UITextView(frame: .zero)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = seededText
        textView.contentInsetAdjustmentBehavior = .never
        textView.textColor = GalleryColor.primary
        textView.font = GallerySHSans.regular.font(16)
        textView.keyboardType = .alphabet
        textView.isEditable = true
        textView.textContainer.lineFragmentPadding = .zero
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 4, bottom: 12, right: 4)
        textView.backgroundColor = .clear

        container.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            textView.heightAnchor.constraint(equalToConstant: 48)
        ])

        return container
    }

    private static func makeDatePickerWorksheetView(seededDate: Date?) -> UIView {
        let container = UIView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false

        let datePicker = UIDatePicker(frame: .zero)
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }
        datePicker.datePickerMode = .date

        let minimumDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        let maximumDate = Calendar.current.date(byAdding: .year, value: 2, to: Date())
        datePicker.minimumDate = minimumDate
        datePicker.maximumDate = maximumDate

        if var seededDate {
            if let minimumDate, seededDate < minimumDate {
                seededDate = minimumDate
            }
            if let maximumDate, seededDate > maximumDate {
                seededDate = maximumDate
            }
            datePicker.date = seededDate
        }

        container.addSubview(datePicker)
        NSLayoutConstraint.activate([
            datePicker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            datePicker.topAnchor.constraint(equalTo: container.topAnchor),
            datePicker.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }
}
