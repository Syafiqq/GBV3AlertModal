import Foundation
import UIKit
import SnapKit

// MARK: - DESIGN

extension GBAlertModal {
    // Widened from `private` to `internal`: called from `init` in
    // GBAlertModal.swift (different file, same module).
    func initDesign() {
        // MARK: View Initialization
        let vwOverlay = generateGenericViewDesign()
        let vwContainer = generateGenericViewDesign()
        let svContentContainer = generateStackViewForContentDesign()

        // MARK: View Graph
        addSubview(vwOverlay)
        addSubview(vwContainer)
        vwContainer.addSubview(svContentContainer)

        // MARK: View Constraints
        vwOverlay.snp.makeConstraints { (make: ConstraintMaker) in
            make.edges
                    .equalToSuperview()
        }

        adjustVwContainerConstraint(vwContainer)
        adjustSvContentContainerConstraint(svContentContainer)

        // MARK: View Assign
        self.vwOverlay = vwOverlay
        self.vwContainer = vwContainer
        self.svContentContainer = svContentContainer
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateGenericViewDesign() -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    // Only used within this file (by `initDesign`); stays file-scoped.
    private func generateStackViewForContentDesign() -> UIStackView {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.distribution = .fill
        view.alignment = .center
        view.spacing = 0
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateImageViewForBannerDesign() -> UIImageView {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateLabelForTitleDesign() -> UILabel {
        let view = UILabel(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.numberOfLines = 2
        view.minimumScaleFactor = 0.75
        view.adjustsFontSizeToFitWidth = true
        view.textAlignment = .center
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateScrollForCustomViewDesign() -> UIScrollView {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = true
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateLabelForSubtitleDesign() -> UILabel {
        let view = UILabel(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.numberOfLines = 0
        view.textAlignment = .center
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateStackViewForMainButtonDesign() -> UIStackView {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.distribution = .fillEqually
        view.alignment = .center
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateButtonForCloseDesign() -> UIButton {
        let view = UIButton(type: .system)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}
