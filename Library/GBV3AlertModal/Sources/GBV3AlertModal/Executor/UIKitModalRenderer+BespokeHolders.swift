import UIKit

// The UIKit half of the three BESPOKE descriptors, so `registerBuiltInDescriptors()` can wire them
// on this backend too — the mirror of `SwiftUIModalRenderer+BespokeViews.swift`:
//
//   descriptor           UIKit holder (here)      SwiftUI body (the other backend)
//   ------------------   ----------------------   -------------------------------
//   BadgeDialog          BadgeHolder              BadgeModalView
//   LoadingDialog        LoadingHolder            LoadingModalView
//   SatisfactionDialog   SatisfactionHolder       SatisfactionModalView
//
// INTERNAL, unlike `AlertHolder`/`TextInputHolder`/`DatePickerHolder`: the library's own
// `registerBuiltInDescriptors()` is the only caller, and a consumer who wants a different mapping
// writes their own factory rather than reaching for these.
//
// Each `result(for:)` switch is duplicated from the matching SwiftUI view's `result(for:)` (the same
// duplication `AlertHolder` and `registerStandard`'s route already carry) and MUST stay identical —
// pulling it out would drag SwiftUI types into this UIKit-only region.

extension UIKitModalRenderer {

    /// `DataHolder` for `BadgeDialog`: banner + title + subtitle + buttons.
    ///
    /// The badge GRID is not rendered: `BadgeDialog.Badge` carries artwork asset NAMES and a detail
    /// line that the SwiftUI `BadgeModalView` lays out in a `LazyVGrid`, and there is no UIKit
    /// counterpart view in this library. The RESULT is unaffected — it is decided purely by which
    /// button was pressed — so this mapping is faithful about outcome and partial about content.
    @MainActor enum BadgeHolder {
        static func make(
            for descriptor: BadgeDialog,
            resolve: @escaping (BadgeDialog.Result) -> Void
        ) -> GBAlertModal.DataHolder {
            let (titlePlain, titleAttr) = ModalText.split(descriptor.title)
            let (subPlain, subAttr) = ModalText.split(descriptor.subtitle)
            return GBAlertModal.DataHolder(
                closeOnTapOverlay: descriptor.closeOnTapOverlay,
                banner: descriptor.banner.flatMap { UIImage(named: $0.assetName) },
                title: titlePlain,
                titleAttributed: titleAttr,
                subtitle: subPlain,
                subtitleAttributed: subAttr,
                primaryAction: descriptor.primary,
                secondaryAction: descriptor.secondary,
                showCloseButton: descriptor.showCloseButton,
                dismissOnAction: false, // the renderer's gate owns teardown
                completion: { _, action in resolve(result(for: action)) }
            )
        }

        /// Identical to `BadgeModalView.result(for:)`.
        static func result(for action: GBAlertModal.ActionType) -> BadgeDialog.Result {
            switch action {
            case .primary: return .viewBadges
            case .secondary, .close: return .dismissed
            }
        }
    }

    /// `DataHolder` for `LoadingDialog`: title + subtitle + buttons.
    ///
    /// `descriptor.isLoading` is DROPPED here — `GBAlertModal` has no busy-primary state to switch
    /// into (that state is `AlertModalScaffold.isPrimaryLoading`, i.e. SwiftUI-only). A caller who
    /// flips `isLoading` via `update(_:to:)` on this backend gets an unchanged card rather than a
    /// spinner. The three-way result mapping is fully expressible, so outcomes are faithful.
    @MainActor enum LoadingHolder {
        static func make(
            for descriptor: LoadingDialog,
            resolve: @escaping (LoadingDialog.Result) -> Void
        ) -> GBAlertModal.DataHolder {
            let (titlePlain, titleAttr) = ModalText.split(descriptor.title)
            let (subPlain, subAttr) = ModalText.split(descriptor.subtitle)
            return GBAlertModal.DataHolder(
                closeOnTapOverlay: descriptor.closeOnTapOverlay,
                title: titlePlain,
                titleAttributed: titleAttr,
                subtitle: subPlain,
                subtitleAttributed: subAttr,
                primaryAction: descriptor.primary,
                secondaryAction: descriptor.secondary,
                showCloseButton: descriptor.showCloseButton,
                dismissOnAction: false,
                completion: { _, action in resolve(result(for: action)) }
            )
        }

        /// Identical to `LoadingModalView.result(for:)`.
        static func result(for action: GBAlertModal.ActionType) -> LoadingDialog.Result {
            switch action {
            case .primary: return .confirmed
            case .secondary: return .cancelled
            case .close: return .dismissed
            }
        }
    }

    /// `DataHolder` for `SatisfactionDialog`: the pick-one row as a `UISegmentedControl` in the
    /// custom-content slot; a primary tap reads its selection and resolves `.submitted(index:)`.
    ///
    /// `UISegmentedControl` rather than a hand-built row of buttons because it IS the platform's
    /// pick-one control and the descriptor carries only labels; the SF Symbols are the one thing lost.
    /// The VALIDATION GATE (`primaryEnabled` on the SwiftUI side) has no UIKit expression, so a
    /// primary tap with nothing selected resolves `.dismissed` — exactly the value
    /// `SatisfactionModalView.result(for: .primary, selectedIndex: nil)` produces, rather than
    /// fabricating an index.
    @MainActor enum SatisfactionHolder {
        static func make(
            for descriptor: SatisfactionDialog,
            resolve: @escaping (SatisfactionDialog.Result) -> Void
        ) -> GBAlertModal.DataHolder {
            let control = UISegmentedControl(items: descriptor.options.map(\.label))
            control.overrideUserInterfaceStyle = .light // legible on the standard light card
            control.translatesAutoresizingMaskIntoConstraints = false
            control.heightAnchor.constraint(equalToConstant: 44).isActive = true

            let (titlePlain, titleAttr) = ModalText.split(descriptor.title)
            // Captured as a value: the completion must not read `descriptor` again, and bounds are
            // checked because `selectedSegmentIndex` is negative while nothing is selected.
            let optionCount = descriptor.options.count
            return GBAlertModal.DataHolder(
                closeOnTapOverlay: descriptor.closeOnTapOverlay,
                title: titlePlain,
                titleAttributed: titleAttr,
                subtitleCustomView: control,
                primaryAction: descriptor.primary,
                dismissOnAction: false,
                completion: { _, action in
                    switch action {
                    case .primary:
                        let index = control.selectedSegmentIndex
                        let selected = (index >= 0 && index < optionCount) ? index : nil
                        resolve(result(for: .primary, selectedIndex: selected))
                    case .secondary, .close:
                        resolve(result(for: action, selectedIndex: nil))
                    }
                }
            )
        }

        /// Identical to `SatisfactionModalView.result(for:selectedIndex:)`.
        static func result(
            for action: GBAlertModal.ActionType, selectedIndex: Int?
        ) -> SatisfactionDialog.Result {
            switch action {
            case .primary:
                guard let selectedIndex else { return .dismissed }
                return .submitted(index: selectedIndex)
            case .secondary, .close:
                return .dismissed
            }
        }
    }
}
