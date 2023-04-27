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

    // Main Content
    public private(set) var svContentContainer: UIStackView?

    // Content
    public private(set) var lbTitle: UILabel?

    // MARK: Attributes Gestures
    private var tapRecognizerOverlay: UIGestureRecognizer?

    // MARK: ViewModel

    // MARK: Private Properties

    private var properties: DialogProperties?
    private var dataHolder: DataHolder?

    // Rx

    // MARK: Data

    // Credential

    // MARK: Public Properties

    // MARK: Initialization

    public init(holder: DataHolder) {
        super.init(frame: .zero)

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
        if dataHolder?.dismissOnAction == true {
            hide()
        }
    }

    func dismissAndEmit(event: ActionType) {
        if dataHolder?.dismissOnAction == true {
            hide()
        }
        dataHolder?.completion?(self, event)
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

        // Define base color
        backgroundColor = .clear
        tintColor = properties?.baseTint ?? globalProperties.baseTint

        vwOverlay?.backgroundColor = properties?.overlayColor ?? globalProperties.overlayColor

        vwContainer?.backgroundColor = properties?.contentBackgroundColor ?? globalProperties.contentBackgroundColor
        vwContainer?.layer.cornerRadius = properties?.contentCornerRadius ?? globalProperties.contentCornerRadius ?? 0

        unregisterDialogView()
        registerDialogView()
    }

    func initEvents() {
        unregisterEvents()
        registerEvents()
    }

    func initData() {
    }

    // MARK: Views

    func unregisterDialogView() {
        svContentContainer?.removeAllArrangedSubviews()

        lbTitle?.removeFromSuperview()
    }

    func registerDialogView() {
        // Setup title
        if let title = dataHolder?.title {
            let lbTitle = generateLabelForTitleDesign()
            lbTitle.attributedText = NSAttributedString(
                    string: title,
                    attributes: [
                        .font: properties?.titleFont ?? globalProperties.titleFont,
                        .foregroundColor: properties?.titleColor ?? globalProperties.titleColor
                    ].compactMapValues({ $0 })
            )
            self.lbTitle = lbTitle
        } else if let title = dataHolder?.attributedTitle {
            let lbTitle = generateLabelForTitleDesign()
            lbTitle.attributedText = title
            self.lbTitle = lbTitle
        } else {
            lbTitle = nil
        }

        // Setup Divider

        // Compile View

        [
            lbTitle
        ]
                .forEach {
                    guard let view = $0 else {
                        return
                    }
                    svContentContainer?.addArrangedSubview(view)
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
}

// MARK: - DELEGATIONS

// MARK: - EXTENSION

// MARK: - STATIC DETACHABLE

// MARK: - TRACKING

// MARK: - DESIGN

private extension AlertModal {
    // swiftlint:disable:next function_body_length
    func initDesign() {
        // MARK: View Initialization
        let vwOverlay = generateGenericViewDesign()
        let vwContainer = generateGenericViewDesign()
        let svContentContainer = generateStackViewDesign()

        // MARK: View Graph
        addSubview(vwOverlay)
        addSubview(vwContainer)
        vwContainer.addSubview(svContentContainer)

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

        svContentContainer.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            make.top
                    .greaterThanOrEqualToSuperview()
                    .offset(
                            properties?.contentTopPadding?.0 ?? globalProperties.contentTopPadding?.0 ?? 0
                    )
            make.top
                    .equalToSuperview()
                    .offset(
                            properties?.contentTopPadding?.1 ?? globalProperties.contentTopPadding?.1 ?? 0
                    )
                    .priority(.medium)

            make.leading
                    .greaterThanOrEqualToSuperview()
                    .offset(
                            properties?.contentHorizontalPadding?.0 ?? globalProperties.contentHorizontalPadding?.0 ?? 0
                    )
            make.leading
                    .equalToSuperview()
                    .offset(
                            properties?.contentHorizontalPadding?.1 ?? globalProperties.contentHorizontalPadding?.1 ?? 1
                    )
                    .priority(.medium)

            make.bottom
                    .lessThanOrEqualToSuperview()
                    .offset(
                            -(properties?.contentBottomPadding?.0 ?? globalProperties.contentBottomPadding?.0 ?? 0)
                    )
            make.bottom
                    .equalToSuperview()
                    .offset(
                            -(properties?.contentBottomPadding?.1 ?? globalProperties.contentBottomPadding?.1 ?? 0)
                    )
                    .priority(.medium)

            make.centerX
                    .equalToSuperview()
        }

        // MARK: View Assign
        self.vwOverlay = vwOverlay
        self.vwContainer = vwContainer
        self.svContentContainer = svContentContainer
    }

    func generateGenericViewDesign() -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func generateStackViewDesign() -> UIStackView {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.distribution = .fill
        view.alignment = .center
        view.spacing = 0
        return view
    }

    func generateLabelForTitleDesign() -> UILabel {
        let view = UILabel(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.numberOfLines = 2
        view.minimumScaleFactor = 0.75
        view.adjustsFontSizeToFitWidth = true
        view.textAlignment = .center
        return view
    }

    func generateLabelForSubtitleDesign() -> UILabel {
        let view = UILabel(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.numberOfLines = 0
        view.textAlignment = .center
        return view
    }
}
