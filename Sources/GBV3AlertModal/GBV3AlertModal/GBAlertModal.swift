import Foundation
import UIKit

// MARK: - LIFECYCLE AND CALLBACK

public class GBAlertModal: UIView {
    // MARK: Outlets

    // MARK: Constraints

    // MARK: Attributes Gestures

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
    }

    func adjustBaseDialogConstraint() {
    }

    // MARK: ViewModel
    func registerEvents() {
    }

    func unregisterEvents() {
    }

    // MARK: Model

    func updateProperties(_ properties: Properties) {
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

        // MARK: View Graph

        // MARK: View Constraints

        // MARK: View Assign
    }
}
