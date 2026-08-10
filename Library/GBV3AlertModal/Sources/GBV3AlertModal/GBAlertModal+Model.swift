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

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal+ViewGraph.swift, `resolvedContentWidths` in GBAlertModal+Layout.swift,
    // and `adjustDialogViewStyle` in GBAlertModal+Style.swift (different files, same module).
    /// The current render decisions, computed by the pure `resolve(...)` mirror from the
    /// live view state. Orientation is read here from the modal's *own* bounds (`self` is
    /// pinned to its parent's edges, so `bounds` reflects the actual host/screen size) rather
    /// than the window scene's real orientation — this makes the landscape width branch
    /// follow the actual layout size and keeps it deterministic/testable. Before first layout
    /// `bounds == .zero`, so this defaults to portrait; `makeResolvedModal()` is re-invoked on
    /// every `layoutSubviews` (via `adjustSvContentContainerConstraintWidth`), so the final
    /// resolved state after layout is correct.
    func makeResolvedModal() -> ResolvedModal {
        Self.resolve(
                properties: properties,
                holder: dataHolder ?? .default,
                isLandscape: bounds.width > bounds.height
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
