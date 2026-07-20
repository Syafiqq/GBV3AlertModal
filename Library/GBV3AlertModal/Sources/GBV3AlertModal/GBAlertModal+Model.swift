import Foundation
import UIKit

// MARK: - MODEL

extension GBAlertModal {
    // MARK: Init Functions

    // Widened from `private` to `internal`: called from `init` in
    // GBAlertModal.swift (different file, same module).
    func initViews() {
        translatesAutoresizingMaskIntoConstraints = false

        vwContainer?.clipsToBounds = true

        unregisterDialogView()
        adjustBaseDialogConstraint()
        registerDialogView()
        adjustDialogViewStyle()
    }

    // Widened from `private` to `internal`: called from `init` in
    // GBAlertModal.swift (different file, same module).
    func initEvents() {
        unregisterEvents()
        registerEvents()
        removeKeyboardEvents()
        listenKeyboardEvents()
    }

    // Widened from `private` to `internal`: called from `init` in
    // GBAlertModal.swift (different file, same module).
    func initData() {
    }

    /// The current render decisions, computed by the pure `resolve(...)` mirror from the
    /// live view state. Orientation is read here (via `UIWindow.isLandscape`) and passed in
    /// so the resolver itself stays deterministic.
    // Widened from `private` to `internal`: called from `registerDialogView` and
    // `resolvedContentWidths` in GBAlertModal.swift, and from `adjustDialogViewStyle` in
    // GBAlertModal+Style.swift (different files, same module).
    func makeResolvedModal() -> ResolvedModal {
        Self.resolve(
                properties: properties,
                holder: dataHolder ?? .default,
                isLandscape: UIWindow.isLandscape,
                isPad: UIDevice.current.userInterfaceIdiom == .pad
        )
    }

    // MARK: Model

    // Widened from `private` to `internal` in Task 1: called from `updateDialog` in
    // GBAlertModal+Lifecycle.swift and, as of Task 2, from `init` in GBAlertModal.swift
    // (different files, same module).
    func updateProperties(_ properties: Properties) {
        self.properties = Properties(
                baseTint: properties.baseTint
                        ?? globalProperties.baseTint,
                overlayColor: properties.overlayColor
                        ?? globalProperties.overlayColor,
                contentProperty: properties.contentProperty
                        ?? globalProperties.contentProperty,
                margin: properties.margin
                        ?? globalProperties.margin,
                padding: properties.padding
                        ?? globalProperties.padding,
                bannerRatio: properties.bannerRatio
                        ?? globalProperties.bannerRatio,
                bannerMaxHeight: properties.bannerMaxHeight
                        ?? globalProperties.bannerMaxHeight,
                bannerFixedHeight: properties.bannerFixedHeight
                        ?? globalProperties.bannerFixedHeight,
                titleFont: properties.titleFont
                        ?? globalProperties.titleFont,
                titleColor: properties.titleColor
                        ?? globalProperties.titleColor,
                subtitleFont: properties.subtitleFont
                        ?? globalProperties.subtitleFont,
                subtitleColor: properties.subtitleColor
                        ?? globalProperties.subtitleColor,
                buttonActionShouldMatchParent: properties.buttonActionShouldMatchParent
                        ?? globalProperties.buttonActionShouldMatchParent,
                buttonActionOrientation: properties.buttonActionOrientation
                        ?? globalProperties.buttonActionOrientation,
                primaryActionStyle: properties.primaryActionStyle
                        ?? globalProperties.primaryActionStyle,
                secondaryActionStyle: properties.secondaryActionStyle
                        ?? globalProperties.secondaryActionStyle,
                closeButtonTint: properties.closeButtonTint
                        ?? globalProperties.closeButtonTint,
                space: properties.space
                        ?? globalProperties.space
        )
    }
}
