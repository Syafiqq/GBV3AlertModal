//
//  DialogCatalog+Badges.swift
//  GBV3AlertModalExample
//
//  Shapes #24-#26 from the catalog: single/multi badge-unlock popups and the
//  badge detail popup. See
//  docs/superpowers/specs/2026-07-21-dialog-catalog.md sections 24-26.
//
//  #24's banner (`badge.localImageName`) and #26's `subtitleCustomView`
//  (built at runtime from a `Domain.VBadgesEntity`) are both catalog-flagged
//  `[API]` — neither is one of the 12 static assets copied in Task 1, so both
//  are stubbed: a generated solid-color placeholder image for #24, and a
//  minimal placeholder view (artwork swatch + label) standing in for the
//  real `VBadgesItemView` for #26.
//

import UIKit
import GBV3AlertModal

extension DialogCatalog {
    static var badgeEntries: [DialogEntry] {
        [
            badgeUnlockSingle,
            badgeUnlockMulti,
            badgeDetailPopup
        ]
    }

    /// #24 `badge-unlock-single` — one badge unlocked. `badge.name`/
    /// `badge.localImageName` are `[API]`.
    /// Source: `BadgesPopUpView.swift:37`.
    private static var badgeUnlockSingle: DialogEntry {
        DialogEntry(name: "badge-unlock-single", category: "Campaign/Badges") {
            let badgeName = "Math Wizard"
            let subtitle = NSMutableAttributedString(
                string: "you unlocked the ",
                attributes: [
                    .font: GallerySHSans.regular.font(16),
                    .foregroundColor: GalleryColor.labelSubtitle
                ]
            )
            subtitle.append(NSAttributedString(
                string: badgeName,
                attributes: [
                    .font: GallerySHSans.bold.font(16),
                    .foregroundColor: GalleryColor.labelSubtitle
                ]
            ))
            subtitle.append(NSAttributedString(
                string: " badge!",
                attributes: [
                    .font: GallerySHSans.regular.font(16),
                    .foregroundColor: GalleryColor.labelSubtitle
                ]
            ))

            return SampleAlertModal(
                properties: GalleryPresets.badgeProperties,
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    // [API]: `UIImage(named: badge.localImageName)` in the real app —
                    // per-badge, not one of the 12 copyable static assets.
                    banner: DialogCatalog.placeholderImage(
                        color: GalleryColor.accentSecondary,
                        size: CGSize(width: 144, height: 144)
                    ),
                    title: "Congratulations!",
                    subtitleAttributed: subtitle,
                    primaryAction: "View my badges",
                    secondaryAction: "Dismiss",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #25 `badge-unlock-multi` — multiple badges unlocked, static banner.
    /// Source: `BadgesPopUpView.swift:79-91`.
    private static var badgeUnlockMulti: DialogEntry {
        DialogEntry(name: "badge-unlock-multi", category: "Campaign/Badges") {
            SampleAlertModal(
                properties: GalleryPresets.badgeProperties.copy(
                    bannerMaxHeight: 216,
                    bannerFixedHeight: 216
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    banner: UIImage(named: "img_badge_multi_achievement"),
                    title: "Congratulations!",
                    subtitle: "You unlocked new badges.",
                    primaryAction: "View my badges",
                    secondaryAction: "Dismiss",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #26 `badge-detail-popup` — tapped-badge detail, no banner; uses
    /// `subtitleCustomView` in place of `banner`/`subtitle`.
    /// Source: `VBadgeListViewController.swift:457`.
    private static var badgeDetailPopup: DialogEntry {
        DialogEntry(name: "badge-detail-popup", category: "Progress/Badges") {
            SampleAlertModal(
                properties: GalleryPresets.properties.copy(
                    padding: UIMinMaxEdgeInsets(
                        top: (20, 36),
                        left: (20, 48),
                        bottom: (20, 36),
                        right: (20, 48)
                    ),
                    space: GBAlertModal.Properties.ComponentSpace(
                        banner: 0,
                        title: 0,
                        subtitle: 24,
                        interButton: 0
                    )
                ),
                holder: GalleryPresets.holder.copy(
                    // [API]: the real `VBadgesItemView`, built at runtime from the
                    // tapped `Domain.VBadgesEntity` (artwork + name + description).
                    subtitleCustomView: makeBadgeDetailPlaceholderView(
                        badgeName: "[API] Math Wizard",
                        badgeDescription: "[API] Solved 50 algebra questions without a hint."
                    ),
                    primaryAction: "Got it",
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// Minimal stand-in for `VBadgesItemView`: an artwork swatch above a
    /// name/description label pair.
    private static func makeBadgeDetailPlaceholderView(badgeName: String, badgeDescription: String) -> UIView {
        let container = UIView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false

        let artwork = UIImageView(image: DialogCatalog.placeholderImage(
            color: GalleryColor.accentSecondary,
            size: CGSize(width: 96, height: 96)
        ))
        artwork.translatesAutoresizingMaskIntoConstraints = false
        artwork.contentMode = .scaleAspectFit
        artwork.layer.cornerRadius = 12
        artwork.clipsToBounds = true

        let nameLabel = UILabel(frame: .zero)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = badgeName
        nameLabel.font = GallerySHSans.bold.font(16)
        nameLabel.textColor = GalleryColor.gbpNavy
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1

        let descriptionLabel = UILabel(frame: .zero)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = badgeDescription
        descriptionLabel.font = GallerySHSans.regular.font(14)
        descriptionLabel.textColor = GalleryColor.labelSubtitle
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [artwork, nameLabel, descriptionLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            artwork.widthAnchor.constraint(equalToConstant: 96),
            artwork.heightAnchor.constraint(equalToConstant: 96),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }
}
