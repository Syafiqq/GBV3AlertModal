import Foundation
import UIKit
import SnapKit

// MARK: - LIFECYCLE AND CALLBACK

public class AlertModal: UIView {
    // MARK: Outlets
    // Overlay
    public private(set) var vwOverlay: UIView?

    // Main Container
    public private(set) var vwContainer: UIView?

    // MARK: Attributes Gestures
    private var tapRecognizerOverlay: UIGestureRecognizer?

    // MARK: ViewModel

    // MARK: Private Properties

    private var closeOnTapOverlay: Bool = true
    private var dismissOnAction: Bool = true

    private var completion: ((AlertModal, ActionType) -> Void)?

    private var properties: DialogProperties?

    // Rx

    // MARK: Data

    // Credential

    // MARK: Public Properties

    // MARK: Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)

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
        guard closeOnTapOverlay else {
            return
        }

        switch sender.state {
        case .ended:
            dismissAndEmit(event: .close)
        default:
            break
        }
    }

    // MARK: Public Function

    /*
     We need to show specific alert long enough, so
     we don't overwrite the main class for now and add custom method here
     */
    public func show(parent: UIView, completion onShown: @escaping () -> Void) {
        weak var parent = parent
        guard let parent else {
            return
        }

        alpha = 1
        transform = .identity

        parent.addSubview(self)
        snp.makeConstraints { (make: ConstraintMaker) -> Void in
            make.edges.equalTo(parent)
        }

        onShown()
    }

    @objc
    public func hide() {
        UIView.animate(
                withDuration: 0.2,
                animations: { [weak self] in
                    self?.alpha = 0
                    self?.transform = .identity.scaledBy(x: 2, y: 2)
                },
                completion: { [weak self] _ in
                    self?.removeFromSuperview()
                }
        )
    }

    func dismiss() {
        if dismissOnAction {
            hide()
        }
    }

    func dismissAndEmit(event: ActionType) {
        if dismissOnAction {
            hide()
        }
        completion?(self, event)
    }

    // MARK: Deinitialization

    deinit {
    }
}

// MARK: - PRIVATE FUNCTIONS

private extension AlertModal {
    // MARK: Init Functions
    func initViews() {
        translatesAutoresizingMaskIntoConstraints = false

        vwOverlay?.backgroundColor = properties?.overlayColor ?? globalProperties.overlayColor

        vwContainer?.backgroundColor = properties?.contentBackgroundColor ?? globalProperties.contentBackgroundColor
        vwContainer?.layer.cornerRadius = properties?.contentCornerRadius ?? globalProperties.contentCornerRadius ?? 0
    }

    func initEvents() {
        unregisterEvents()
        registerEvents()
    }

    func initData() {
    }

    // MARK: Views

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
}

// MARK: - DELEGATIONS

// MARK: - EXTENSION

// MARK: - STATIC DETACHABLE

// MARK: - TRACKING

// MARK: - DESIGN

private extension AlertModal {
    func initDesign() {
        // MARK: View Initialization
        let vwOverlay = generateGenericView()
        let vwContainer = generateGenericView()

        // MARK: View Graph
        addSubview(vwOverlay)
        addSubview(vwContainer)

        // MARK: View Constraints
        vwOverlay.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            make.edges
                    .equalToSuperview()
        }

        vwContainer.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            // Align
            make.top
                    .greaterThanOrEqualToSuperview()
                    .offset(
                            properties?.contentVerticalMargin ?? globalProperties.contentVerticalMargin ?? 0
                    )
            make.leading
                    .greaterThanOrEqualToSuperview()
                    .offset(
                            properties?.contentHorizontalMargin ?? globalProperties.contentHorizontalMargin ?? 0
                    )

            make.center
                    .equalToSuperview()
        }

        // MARK: View Assign
        self.vwOverlay = vwOverlay
        self.vwContainer = vwContainer
    }

    func generateGenericView() -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}
