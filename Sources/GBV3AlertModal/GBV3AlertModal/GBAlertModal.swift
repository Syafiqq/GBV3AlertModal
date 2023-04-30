import Foundation
import UIKit
import SnapKit

// MARK: - LIFECYCLE AND CALLBACK

public class GBAlertModal: UIView {
    // MARK: Outlets
    // Overlay
    private(set) var vwOverlay: UIView?

    // Main Container
    private(set) var vwContainer: UIView?

    // MARK: Constraints

    // MARK: Attributes Gestures
    private var tapRecognizerOverlay: UIGestureRecognizer?

    // MARK: ViewModel

    // MARK: Private Properties

    private var properties: Properties?
    private var dataHolder: DataHolder?

    // MARK: Data

    // MARK: Public Properties

    // MARK: Initialization
    public init(properties: Properties? = nil, holder: DataHolder) {
        super.init(frame: .zero)

        updateProperties(properties ?? globalProperties)
        dataHolder = holder

        initDesign()
        initViews()
        initEvents()
        initData()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Lifecycle

    // MARK: Override Function

    // MARK: Callback

    @objc
    private func onOverlayTapped(_ sender: UITapGestureRecognizer) {
        guard dataHolder?.closeOnTapOverlay == true else {
            return
        }
    }

    // MARK: Public Function

    // MARK: Deinitialization

    deinit {
    }
}

// MARK: - PRIVATE FUNCTIONS

private extension GBAlertModal {
    // MARK: Init Functions
    func initViews() {
        translatesAutoresizingMaskIntoConstraints = false

        vwContainer?.clipsToBounds = true

        unregisterDialogView()
        adjustBaseDialogConstraint()
        registerDialogView()
        adjustDialogViewStyle()
    }

    func initEvents() {
        unregisterEvents()
        registerEvents()
    }

    func initData() {
    }

    // MARK: Views

    func unregisterDialogView() {
    }

    func registerDialogView() {
    }

    func adjustDialogViewStyle() {
        // Base View
        tintColor = properties?.baseTint

        // Overlay
        vwOverlay?.backgroundColor = properties?.overlayColor

        // Content Container
        vwContainer?.backgroundColor = properties?.contentProperty?.backgroundColor
        vwContainer?.layer.cornerRadius = properties?.contentProperty?.cornerRadius ?? .zero
    }

    func adjustBaseDialogConstraint() {
        if let vwContainer = vwContainer {
            adjustVwContainerConstraint(vwContainer)
        }
    }

    private func adjustVwContainerConstraint(_ vwContainer: UIView) {
        vwContainer.snp.remakeConstraints { (make: ConstraintMaker) -> Void in
            // Align
            make.top
                    .greaterThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(
                            properties?.margin?.top ?? .zero
                    )
            make.leading
                    .greaterThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(
                            properties?.margin?.left ?? .zero
                    )
            make.bottom
                    .lessThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(
                            -(properties?.margin?.bottom ?? .zero)
                    )
            make.trailing
                    .lessThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(
                            -(properties?.margin?.right ?? .zero)
                    )

            make.center
                    .equalToSuperview()
                    .priority(.low)

            // Pin
            if let fixedWidth = properties?.contentProperty?.fixedWidth {
                make.width
                        .equalTo(fixedWidth)
                        .priority(.low)
            }

            if let maxWidth = properties?.contentProperty?.maxWidth {
                make.width
                        .lessThanOrEqualTo(maxWidth)
                        .priority(.high)
            }
        }
    }

    // MARK: ViewModel
    func registerEvents() {
        // Gestures
        let tapRecognizerOverlay = UITapGestureRecognizer(target: self, action: #selector(onOverlayTapped))
        vwOverlay?.addGestureRecognizer(tapRecognizerOverlay)
        vwOverlay?.isUserInteractionEnabled = true
        self.tapRecognizerOverlay = tapRecognizerOverlay

    }

    func unregisterEvents() {
        // Gestures
        if let tapRecognizerOverlay = tapRecognizerOverlay {
            vwOverlay?.removeGestureRecognizer(tapRecognizerOverlay)
        }
        tapRecognizerOverlay = nil
    }

    // MARK: Model

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
                        ?? globalProperties.padding
        )
    }
}

// MARK: - DELEGATIONS

// MARK: - EXTENSION

// MARK: - STATIC DETACHABLE

// MARK: - TRACKING

// MARK: - DESIGN

private extension GBAlertModal {
    func initDesign() {
        // MARK: View Initialization
        let vwOverlay = generateGenericViewDesign()
        let vwContainer = generateGenericViewDesign()

        // MARK: View Graph
        addSubview(vwOverlay)
        addSubview(vwContainer)

        // MARK: View Constraints
        vwOverlay.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            make.edges
                    .equalToSuperview()
        }

        adjustVwContainerConstraint(vwContainer)

        // MARK: View Assign
        self.vwOverlay = vwOverlay
        self.vwContainer = vwContainer
    }

    func generateGenericViewDesign() -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}
