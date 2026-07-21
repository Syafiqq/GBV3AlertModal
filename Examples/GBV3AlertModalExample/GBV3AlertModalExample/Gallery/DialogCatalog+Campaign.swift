//
//  DialogCatalog+Campaign.swift
//  GBV3AlertModalExample
//
//  Shapes #17, #18 from the catalog: onboarding welcome popup (no banner)
//  and the trial/subscription-ended banner. See
//  docs/superpowers/specs/2026-07-21-dialog-catalog.md sections 17, 18.
//

import UIKit
import GBV3AlertModal

extension DialogCatalog {
    static var campaignEntries: [DialogEntry] {
        [
            onboardingWelcomeNoBanner,
            onboardingTrialBanner
        ]
    }

    /// #17 `onboarding-welcome-nobanner` — first-run welcome popup, no
    /// banner. The `isEligibleForJcUiVariant` ternary that picks between the
    /// two subtitle strings isn't modeled; shown with the "announcer" variant.
    /// Source: `V1MainTabViewController+PopupCampaign.swift:262`.
    private static var onboardingWelcomeNoBanner: DialogEntry {
        DialogEntry(name: "onboarding-welcome-nobanner", category: "Campaign/Onboarding") {
            SampleAlertModal(
                properties: GalleryPresets.popupProperties,
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    title: "Hello there!",
                    subtitle: "Let's explore Geniebook!",
                    primaryAction: "I'm ready",
                    secondaryAction: nil,
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }

    /// #18 `onboarding-trial-banner` — free-trial-ended banner (variant A of
    /// two near-identical shapes; the subscription-ended variant only swaps
    /// title/subtitle/banner/button text).
    /// Source: `V1MainTabViewController+PopupCampaign.swift:327`.
    private static var onboardingTrialBanner: DialogEntry {
        DialogEntry(name: "onboarding-trial-banner", category: "Campaign/Onboarding") {
            SampleAlertModal(
                properties: GalleryPresets.popupProperties.copy(
                    bannerRatio: 320.0 / 229.0,
                    bannerMaxHeight: 216,
                    bannerFixedHeight: 184
                ),
                holder: GalleryPresets.holder.copy(
                    closeOnTapOverlay: false,
                    banner: UIImage(named: "img_illust_free_trial_ended"),
                    title: "Free trial has ended",
                    subtitle: "Subscribe to continue learning with Geniebook",
                    primaryAction: "View pricing plans",
                    secondaryAction: "Dismiss",
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }
}
