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

    // Main Content
    private(set) var svContentContainer: UIStackView?

    // Content
    private(set) var vwBanner: UIView?
    private(set) var ivBanner: UIImageView?

    private(set) var lbTitle: UILabel?

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
        svContentContainer?.removeAllArrangedSubviews()

        vwBanner?.removeFromSuperview()
        ivBanner?.removeFromSuperview()
        lbTitle?.removeFromSuperview()
    }

    func registerDialogView() {
        // MARK: View Initialization
        // Setup banner
        if let banner = dataHolder?.banner {
            let vwBanner = generateGenericViewDesign()
            let ivBanner = generateImageViewForBannerDesign()
            ivBanner.image = banner

            vwBanner.addSubview(ivBanner)

            self.vwBanner = vwBanner
            self.ivBanner = ivBanner
        } else {
            vwBanner = nil
            ivBanner = nil
        }

        // Setup title
        if let title = dataHolder?.title,
           !title.isEmpty {
            let lbTitle = generateLabelForTitleDesign()
            lbTitle.attributedText = NSAttributedString(
                    string: title,
                    attributes: [
                        .font: properties?.titleFont,
                        .foregroundColor: properties?.titleColor
                    ].compactMapValues({ $0 })
            )
            self.lbTitle = lbTitle
        } else if let title = dataHolder?.titleAttributed,
                  title.length <= 0 {
            let lbTitle = generateLabelForTitleDesign()
            lbTitle.attributedText = title
            self.lbTitle = lbTitle
        } else {
            lbTitle = nil
        }

        // MARK: View Graph
        // Compile View

        [
            vwBanner,
            lbTitle
        ]
                .forEach {
                    guard let view = $0 else {
                        return
                    }
                    svContentContainer?.addArrangedSubview(view)
                }

        // MARK: View Constraints
        // Banner
        if let ivBanner {
            ivBanner.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                // Align
                make.leading.top
                        .greaterThanOrEqualToSuperview()
                make.leading.top
                        .equalToSuperview()
                        .priority(.low)
                make.center
                        .equalToSuperview()

                // Pin
                if let ratio = properties?.bannerRatio {
                    make.width
                            .equalTo(ivBanner.snp.height)
                            .multipliedBy(ratio)
                }
            }
        }
    }

    func adjustDialogViewStyle() {
        // Base View
        tintColor = properties?.baseTint

        // Overlay
        vwOverlay?.backgroundColor = properties?.overlayColor

        // Content Container
        vwContainer?.backgroundColor = properties?.contentProperty?.backgroundColor
        vwContainer?.layer.cornerRadius = properties?.contentProperty?.cornerRadius ?? .zero

        // Content Container Stack
        svContentContainer?.alignment = properties?.contentProperty?.childShouldMatchParent == true ? .fill : .center
    }

    func adjustBaseDialogConstraint() {
        if let vwContainer = vwContainer {
            adjustVwContainerConstraint(vwContainer)
        }
        if let svContentContainer = svContentContainer {
            adjustSvContentContainerConstraint(svContentContainer)
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

    private func adjustSvContentContainerConstraint(_ svContentContainer: UIView) {
        svContentContainer.snp.remakeConstraints { (make: ConstraintMaker) -> Void in
            make.top
                    .greaterThanOrEqualToSuperview()
                    .offset(
                            properties?.padding?.topMin ?? .zero
                    )
            make.top
                    .equalToSuperview()
                    .offset(
                            properties?.padding?.topMax ?? .zero
                    )
                    .priority(.low)

            make.leading
                    .greaterThanOrEqualToSuperview()
                    .offset(
                            properties?.padding?.leftMin ?? .zero
                    )
            make.leading
                    .equalToSuperview()
                    .offset(
                            properties?.padding?.leftMax ?? .zero
                    )
                    .priority(.low)

            make.bottom
                    .lessThanOrEqualToSuperview()
                    .offset(
                            -(properties?.padding?.bottomMin ?? .zero)
                    )
            make.bottom
                    .equalToSuperview()
                    .offset(
                            -(properties?.padding?.bottomMax ?? .zero)
                    )
                    .priority(.low)

            make.trailing
                    .lessThanOrEqualToSuperview()
                    .offset(
                            -(properties?.padding?.rightMin ?? .zero)
                    )
            make.trailing
                    .equalToSuperview()
                    .offset(
                            -(properties?.padding?.rightMax ?? .zero)
                    )
                    .priority(.low)

            make.center
                    .equalToSuperview()
                    .priority(.low)
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
                        ?? globalProperties.padding,
                bannerRatio: properties.bannerRatio
                        ?? globalProperties.bannerRatio,
                titleFont: properties.titleFont
                        ?? globalProperties.titleFont,
                titleColor: properties.titleColor
                        ?? globalProperties.titleColor
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
        let svContentContainer = generateStackViewForContentDesign()

        // MARK: View Graph
        addSubview(vwOverlay)
        addSubview(vwContainer)
        vwContainer.addSubview(svContentContainer)

        // MARK: View Constraints
        vwOverlay.snp.makeConstraints { (make: ConstraintMaker) -> Void in
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

    func generateGenericViewDesign() -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func generateStackViewForContentDesign() -> UIStackView {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.distribution = .fill
        view.alignment = .center
        view.spacing = 0
        return view
    }

    func generateImageViewForBannerDesign() -> UIImageView {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
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
}
