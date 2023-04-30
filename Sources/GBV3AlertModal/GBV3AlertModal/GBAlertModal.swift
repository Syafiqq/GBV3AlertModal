import Foundation
import UIKit
import SnapKit

// MARK: - LIFECYCLE AND CALLBACK

public class GBAlertModal: UIView {
    // MARK: Outlets
    // Overlay
    private(set) var vwOverlay: UIView?

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
    }

    func adjustBaseDialogConstraint() {
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
                        ?? globalProperties.overlayColor
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

        // MARK: View Graph
        addSubview(vwOverlay)

        // MARK: View Constraints
        vwOverlay.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            make.edges
                    .equalToSuperview()
        }

        // MARK: View Assign
        self.vwOverlay = vwOverlay
    }

    func generateGenericViewDesign() -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}
