import Foundation
import UIKit
import SnapKit

// MARK: - LAYOUT

extension GBAlertModal {
    // Moved verbatim from GBAlertModal.swift (Task 6). Implicitly `internal` (the extension's
    // default, same as the original's explicit `internal` inside a `private extension`): called
    // from `updateDialog` in GBAlertModal+Lifecycle.swift and from `initViews` in
    // GBAlertModal+Model.swift (different files, same module).
    func adjustBaseDialogConstraint() {
        if let vwContainer = vwContainer {
            adjustVwContainerConstraint(vwContainer)
        }
        if let svContentContainer = svContentContainer {
            adjustSvContentContainerConstraint(svContentContainer)
        }
    }

    // Moved verbatim from GBAlertModal.swift (Task 6). Implicitly `internal`: called from
    // `initDesign` in GBAlertModal+ViewFactory.swift (different file, same module), plus
    // `adjustBaseDialogConstraint` above. The four inset offsets are now resolved by
    // `ModalLayout.resolveContainerOffsets(margin:)` (pure, unit-tested); the SnapKit application
    // stays here.
    func adjustVwContainerConstraint(_ vwContainer: UIView) {
        let offsets = ModalLayout.resolveContainerOffsets(margin: properties?.margin)
        vwContainer.snp.remakeConstraints { (make: ConstraintMaker) in
            // Align
            make.top
                    .greaterThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(offsets.top)
            make.leading
                    .greaterThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(offsets.leading)
            make.bottom
                    .lessThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(offsets.bottom)
            make.trailing
                    .lessThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(offsets.trailing)

            make.center
                    .equalToSuperview()
                    .priority(.low)
        }
    }

    // Moved verbatim from GBAlertModal.swift (Task 6). Implicitly `internal`: called from
    // `initDesign` in GBAlertModal+ViewFactory.swift (different file, same module), plus
    // `adjustBaseDialogConstraint` above. The eight inset offsets are now resolved by
    // `ModalLayout.resolveContentPadding(padding:)` (pure, unit-tested); the SnapKit application
    // stays here.
    // swiftlint:disable:next function_body_length
    func adjustSvContentContainerConstraint(_ svContentContainer: UIView) {
        let padding = ModalLayout.resolveContentPadding(padding: properties?.padding)
        svContentContainer.snp.remakeConstraints { (make: ConstraintMaker) in
            make.top
                    .greaterThanOrEqualToSuperview()
                    .offset(padding.topMin)
            make.top
                    .equalToSuperview()
                    .offset(padding.topMax)
                    .priority(.low)

            make.leading
                    .greaterThanOrEqualToSuperview()
                    .offset(padding.leadingMin)
            make.leading
                    .equalToSuperview()
                    .offset(padding.leadingMax)
                    .priority(.low)

            make.bottom
                    .lessThanOrEqualToSuperview()
                    .offset(padding.bottomMin)
            make.bottom
                    .equalToSuperview()
                    .offset(padding.bottomMax)
                    .priority(.low)

            make.trailing
                    .lessThanOrEqualToSuperview()
                    .offset(padding.trailingMin)
            make.trailing
                    .equalToSuperview()
                    .offset(padding.trailingMax)
                    .priority(.low)

            make.center
                    .equalToSuperview()
                    .priority(.low)

            // Pin
            let (fixedWidth, maxWidth) = resolvedContentWidths()
            if let fixedWidth {
                make.width
                        .equalTo(fixedWidth)
                        .priority(.medium)
            }
            if let maxWidth {
                make.width
                        .lessThanOrEqualTo(maxWidth)
                        .priority(.high)
            }
        }
    }

    // Moved verbatim from GBAlertModal.swift (Task 6). Implicitly `internal`: called from
    // `layoutSubviews` in GBAlertModal+Lifecycle.swift (different file, same module).
    func adjustSvContentContainerConstraintWidth(_ svContentContainer: UIView) {
        svContentContainer.snp.updateConstraints { (make: ConstraintMaker) in
            // Pin
            let (fixedWidth, maxWidth) = resolvedContentWidths()
            if let fixedWidth {
                make.width
                        .equalTo(fixedWidth)
                        .priority(.medium)
            }
            if let maxWidth {
                make.width
                        .lessThanOrEqualTo(maxWidth)
                        .priority(.high)
            }
        }
    }

    /// The fixed / max content-width constraints to apply. Moved verbatim from
    /// GBAlertModal.swift (Task 6), except the switch over `WidthResolution` itself is now
    /// `ModalLayout.resolveContentWidths(_:)` (pure, unit-tested) — this wrapper just supplies the
    /// live `makeResolvedModal().contentWidth` input. Stays `private`: only used by the two
    /// adjust* methods above, in this same file.
    private func resolvedContentWidths() -> (fixed: CGFloat?, max: CGFloat?) {
        ModalLayout.resolveContentWidths(makeResolvedModal().contentWidth)
    }
}
