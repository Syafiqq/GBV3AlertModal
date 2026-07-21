//
//  VariantsCatalog.swift
//  GBV3AlertModalExample
//
//  A "Variants" group demonstrating every title/subtitle representation
//  (`title`, `titleAttributed`, `subtitle`, `subtitleAttributed`,
//  `subtitleCustomView`) and every `GBAlertModal.ActionStyle` case
//  (`.capsule`, `.capsuleOutlined`, `.plain`, `.obliqueBottomLeft`) the
//  library supports, plus the primary/secondary enabled-disabled button
//  state toggle (`changePrimaryActionEnableState` /
//  `changeSecondaryActionEnableState`). Every `category` starts with
//  `"Variant · "` so it forms its own section(s) in `GalleryViewController`,
//  appended after `DialogCatalog.entries + StressCatalog.entries`.
//

import UIKit
import GBV3AlertModal

enum VariantsCatalog {
    static let entries: [DialogEntry] =
        titleEntries
            + subtitleEntries
            + buttonStyleEntries
            + buttonStateEntries
}

// MARK: - Shared content

private extension VariantsCatalog {
    /// Builds a multi-color / bold-span attributed string so it's visibly
    /// distinct from a plain string when rendered.
    static func attributed(_ segments: [(String, UIColor, UIFont)]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (text, color, font) in segments {
            result.append(
                NSAttributedString(
                    string: text,
                    attributes: [.foregroundColor: color, .font: font]
                )
            )
        }
        return result
    }

    /// A simple bordered custom view (label inside a rounded, bordered
    /// container) standing in for `subtitleCustomView`, so it's clearly a
    /// custom view rather than a subtitle string when rendered.
    static func customSubtitleView() -> UIView {
        let container = UIView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = GalleryColor.accentSecondary.withAlphaComponent(0.08)
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 2
        container.layer.borderColor = GalleryColor.accentSecondary.cgColor

        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.text = "I'm a custom UIView (subtitleCustomView) — a bordered container with a label inside, not a subtitle string."
        label.font = GallerySHSans.semiBold.font(14)
        label.textColor = GalleryColor.accentSecondaryDark
        label.textAlignment = .center

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
        ])

        return container
    }

    static func entry(
        _ name: String,
        category: String,
        properties: GBAlertModal.Properties = GalleryPresets.properties,
        holder: GBAlertModal.DataHolder,
        configure: ((SampleAlertModal) -> Void)? = nil
    ) -> DialogEntry {
        DialogEntry(name: name, category: category) {
            let modal = SampleAlertModal(properties: properties, holder: holder)
            configure?(modal)
            return modal
        }
    }
}

// MARK: - Title representations

private extension VariantsCatalog {
    static let titleCategory = "Variant · Title"

    static var titleEntries: [DialogEntry] {
        [
            entry(
                "variant-title-plain", category: titleCategory,
                holder: GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    title: "Plain String Title",
                    subtitle: "This dialog's title is a plain `String` — set via `DataHolder.title`.",
                    primaryAction: "Okay",
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            ),
            entry(
                "variant-title-attributed", category: titleCategory,
                holder: GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    titleAttributed: attributed([
                        ("Attributed ", GalleryColor.primary, GallerySHSans.bold.font(24)),
                        ("Multi", GalleryColor.accentSecondary, GallerySHSans.heavy.font(24)),
                        ("-Color ", GalleryColor.accentSecondaryDark, GallerySHSans.bold.font(24)),
                        ("Title", GalleryColor.pressedBlue, GallerySHSans.heavy.font(24))
                    ]),
                    subtitle: "This dialog's title is an `NSAttributedString` — set via `DataHolder.titleAttributed` — with mixed colors and weights across spans.",
                    primaryAction: "Okay",
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            )
        ]
    }
}

// MARK: - Subtitle representations

private extension VariantsCatalog {
    static let subtitleCategory = "Variant · Subtitle"

    static var subtitleEntries: [DialogEntry] {
        [
            entry(
                "variant-subtitle-plain", category: subtitleCategory,
                holder: GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    title: "Subtitle · Plain String",
                    subtitle: "This subtitle is a plain `String` — set via `DataHolder.subtitle` and rendered with `properties.subtitleFont` / `subtitleColor`.",
                    primaryAction: "Okay",
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            ),
            entry(
                "variant-subtitle-attributed", category: subtitleCategory,
                holder: GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    title: "Subtitle · Attributed",
                    subtitleAttributed: attributed([
                        ("This subtitle mixes ", GalleryColor.textPrimaryDark, GallerySHSans.regular.font(16)),
                        ("bold orange", GalleryColor.accentSecondaryDark, GallerySHSans.bold.font(16)),
                        (", ", GalleryColor.textPrimaryDark, GallerySHSans.regular.font(16)),
                        ("navy heavy", GalleryColor.primary, GallerySHSans.heavy.font(16)),
                        (", and regular spans set via `DataHolder.subtitleAttributed`.", GalleryColor.textPrimaryDark, GallerySHSans.regular.font(16))
                    ]),
                    primaryAction: "Okay",
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            ),
            entry(
                "variant-subtitle-customview", category: subtitleCategory,
                holder: GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    title: "Subtitle · Custom View",
                    subtitleCustomView: customSubtitleView(),
                    primaryAction: "Okay",
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            )
        ]
    }
}

// MARK: - Button styles

private extension VariantsCatalog {
    static let buttonStyleCategory = "Variant · Button Style"

    static var buttonStyleEntries: [DialogEntry] {
        [
            entry(
                "variant-button-capsule", category: buttonStyleCategory,
                properties: GalleryPresets.properties.copy(primaryActionStyle: .capsule(GalleryPresets.capsuleTheme)),
                holder: GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    title: "Button Style · Capsule",
                    subtitle: "primaryActionStyle: .capsule(GalleryPresets.capsuleTheme)",
                    primaryAction: "Capsule Button",
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            ),
            entry(
                "variant-button-capsuleOutlined", category: buttonStyleCategory,
                properties: GalleryPresets.properties.copy(primaryActionStyle: .capsuleOutlined(GalleryPresets.capsuleOutlinedTheme)),
                holder: GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    title: "Button Style · Capsule Outlined",
                    subtitle: "primaryActionStyle: .capsuleOutlined(GalleryPresets.capsuleOutlinedTheme)",
                    primaryAction: "Capsule Outlined",
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            ),
            entry(
                "variant-button-plain", category: buttonStyleCategory,
                properties: GalleryPresets.properties.copy(primaryActionStyle: .plain(GalleryPresets.plainTheme)),
                holder: GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    title: "Button Style · Plain",
                    subtitle: "primaryActionStyle: .plain(GalleryPresets.plainTheme)",
                    primaryAction: "Plain Button",
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            ),
            entry(
                "variant-button-oblique", category: buttonStyleCategory,
                properties: GalleryPresets.properties.copy(primaryActionStyle: .obliqueBottomLeft(GalleryPresets.obliqueBottomLeftTheme)),
                holder: GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    title: "Button Style · Oblique Bottom Left",
                    subtitle: "primaryActionStyle: .obliqueBottomLeft(GalleryPresets.obliqueBottomLeftTheme)",
                    primaryAction: "Oblique Button",
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            )
        ]
    }
}

// MARK: - Button states

private extension VariantsCatalog {
    static let buttonStateCategory = "Variant · Button State"

    static var buttonStateEntries: [DialogEntry] {
        [
            DialogEntry(name: "variant-button-states", category: buttonStateCategory) {
                let modal = SampleAlertModal(
                    properties: GalleryPresets.properties,
                    holder: GBAlertModal.DataHolder(
                        closeOnTapOverlay: true,
                        title: "Button State · Disabled Secondary",
                        subtitle: "The primary action below is enabled; the secondary action is disabled via `changeSecondaryActionEnableState(isEnable: false)`, called right after init once the buttons exist.",
                        primaryAction: "Enabled Primary",
                        secondaryAction: "Disabled Secondary",
                        dismissOnAction: true,
                        completion: DialogCatalog.noopCompletion
                    )
                )
                // The buttons only exist once `SampleAlertModal.init(properties:holder:)` has
                // finished building the view graph — so this must run after construction, not
                // be expressible purely via `DataHolder`/`Properties`.
                modal.changeSecondaryActionEnableState(isEnable: false)
                return modal
            },
            DialogEntry(name: "variant-button-primary-disabled", category: buttonStateCategory) {
                let modal = SampleAlertModal(
                    properties: GalleryPresets.properties,
                    holder: GBAlertModal.DataHolder(
                        closeOnTapOverlay: true,
                        title: "Button State · Disabled Primary",
                        subtitle: "The primary action below is disabled via `changePrimaryActionEnableState(isEnable: false)`; the secondary action stays enabled.",
                        primaryAction: "Disabled Primary",
                        secondaryAction: "Enabled Secondary",
                        dismissOnAction: true,
                        completion: DialogCatalog.noopCompletion
                    )
                )
                modal.changePrimaryActionEnableState(isEnable: false)
                return modal
            }
        ]
    }
}
