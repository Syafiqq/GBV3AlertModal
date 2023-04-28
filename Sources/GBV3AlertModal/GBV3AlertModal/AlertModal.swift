import Foundation
import UIKit
import SnapKit

// MARK: - LIFECYCLE AND CALLBACK

public class AlertModal: UIView {
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

    private(set) var svSubtitleContainer: UIScrollView?
    private(set) var lbSubtitle: UILabel?
    private(set) weak var vwSubtitle: UIView?

    // Divider
    private(set) var vwBannerAndTitleDivider: UIView?
    private(set) var vwTitleAndSubtitleDivider: UIView?

    // MARK: Constraints
    private(set) var constraintVwContainerWidth: Constraint?

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

    public init(
            holder: DataHolder,
            properties: DialogProperties
    ) {
        super.init(frame: .zero)

        dataHolder = holder
        updateProperties(properties)

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
            make.edges
                    .equalTo(parent)
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
        tintColor = properties?.baseTint

        vwOverlay?.backgroundColor = properties?.overlayColor

        vwContainer?.backgroundColor = properties?.contentBackgroundColor
        vwContainer?.layer.cornerRadius = properties?.contentCornerRadius ?? 0
        vwContainer?.clipsToBounds = true

        unregisterDialogView()
        registerDialogView()

        svContentContainer?.alignment = properties?.contentMatchParent == true ? .fill : .center
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
        svSubtitleContainer?.removeFromSuperview()
        lbSubtitle?.removeFromSuperview()
        vwSubtitle?.removeFromSuperview()

        vwTitleAndSubtitleDivider?.removeFromSuperview()
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func registerDialogView() {
        // Setup banner
        if let banner = dataHolder?.banner {
            let vwBanner = generateGenericViewDesign()
            let ivBanner = generateImageViewForBannerDesign()
            ivBanner.image = banner

            vwBanner.addSubview(ivBanner)
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

        // Setup subtitle
        if dataHolder?.subtitle != nil ||
                   dataHolder?.subtitleAttributed != nil ||
                   dataHolder?.subtitleCustomView != nil {
            let svSubtitleContainer = generateScrollForCustomViewDesign()
            let vwSubtitle: UIView?
            if let subtitle = dataHolder?.subtitle,
               !subtitle.isEmpty {
                let lbSubtitle = generateLabelForSubtitleDesign()
                lbSubtitle.attributedText = NSAttributedString(
                        string: subtitle,
                        attributes: [
                            .font: properties?.subtitleFont,
                            .foregroundColor: properties?.subtitleColor
                        ].compactMapValues({ $0 })
                )

                vwSubtitle = lbSubtitle
                self.lbSubtitle = lbSubtitle
            } else if let subtitle = dataHolder?.subtitleAttributed,
                      subtitle.length <= 0 {
                let lbSubtitle = generateLabelForSubtitleDesign()
                lbSubtitle.attributedText = subtitle

                vwSubtitle = lbSubtitle
                self.lbSubtitle = lbSubtitle
            } else if let subtitle = dataHolder?.subtitleCustomView {
                vwSubtitle = subtitle
                self.vwSubtitle = subtitle
            } else {
                vwSubtitle = nil
            }

            if let vwSubtitle {
                svSubtitleContainer.addSubview(vwSubtitle)
                vwSubtitle.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                    make.edges
                            .equalTo(svSubtitleContainer.contentLayoutGuide)
                    make.width
                            .equalTo(svSubtitleContainer.frameLayoutGuide)
                    make.height
                            .equalTo(svSubtitleContainer.frameLayoutGuide).priority(.low)
                }

                self.svSubtitleContainer = svSubtitleContainer
            }
        } else {
            svSubtitleContainer = nil
            lbSubtitle = nil
            vwSubtitle = nil
        }

        // Setup Divider
        // Setup banner and title
        if vwBanner != nil,
           (lbTitle != nil || svSubtitleContainer != nil) {
            let vwBannerAndTitleDivider = generateGenericViewDesign()
            vwBannerAndTitleDivider.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.height
                        .equalTo(properties?.bannerToTitleSpace ?? 0)
            }

            self.vwBannerAndTitleDivider = vwBannerAndTitleDivider
        } else {
            vwBannerAndTitleDivider = nil
        }

        // Setup divider title and subtitle
        if lbTitle != nil,
           svSubtitleContainer != nil {
            let vwTitleAndSubtitleDivider = generateGenericViewDesign()
            vwTitleAndSubtitleDivider.snp.makeConstraints { (make: ConstraintMaker) -> Void in
                make.height
                        .equalTo(properties?.bannerToTitleSpace ?? 0)
            }

            self.vwTitleAndSubtitleDivider = vwTitleAndSubtitleDivider
        } else {
            vwTitleAndSubtitleDivider = nil
        }

        // Compile View

        [
            vwBanner,
            vwBannerAndTitleDivider,
            lbTitle,
            vwTitleAndSubtitleDivider,
            svSubtitleContainer
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

    private func updateProperties(_ properties: DialogProperties) {
        self.properties = DialogProperties(
                baseTint: properties.baseTint
                        ?? globalProperties.baseTint,
                overlayColor: properties.overlayColor
                        ?? globalProperties.overlayColor,
                contentBackgroundColor: properties.contentBackgroundColor
                        ?? globalProperties.contentBackgroundColor,
                contentCornerRadius: properties.contentCornerRadius
                        ?? globalProperties.contentCornerRadius,
                contentFixedSize: properties.contentFixedSize
                        ?? globalProperties.contentFixedSize,
                contentVerticalMargin: properties.contentVerticalMargin
                        ?? globalProperties.contentVerticalMargin,
                contentHorizontalMargin: properties.contentHorizontalMargin
                        ?? globalProperties.contentHorizontalMargin,
                contentTopPadding: properties.contentTopPadding
                        ?? globalProperties.contentTopPadding,
                contentBottomPadding: properties.contentBottomPadding
                        ?? globalProperties.contentBottomPadding,
                contentHorizontalPadding: properties.contentHorizontalPadding
                        ?? globalProperties.contentHorizontalPadding,
                contentMatchParent: properties.contentMatchParent
                        ?? globalProperties.contentMatchParent,
                bannerRatio: properties.bannerRatio
                        ?? globalProperties.bannerRatio,
                titleFont: properties.titleFont
                        ?? globalProperties.titleFont,
                titleColor: properties.titleColor
                        ?? globalProperties.titleColor,
                subtitleFont: properties.subtitleFont
                        ?? globalProperties.subtitleFont,
                subtitleColor: properties.subtitleColor
                        ?? globalProperties.subtitleColor,
                bannerToTitleSpace: properties.bannerToTitleSpace
                        ?? globalProperties.bannerToTitleSpace,
                titleToSubtitleSpace: properties.titleToSubtitleSpace
                        ?? globalProperties.titleToSubtitleSpace
        )
    }
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

        var constraintVwContainerWidth: Constraint?

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
                    .greaterThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(
                            properties?.contentVerticalMargin ?? 0
                    )
            make.leading
                    .greaterThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(
                            properties?.contentHorizontalMargin ?? 0
                    )
            make.bottom
                    .lessThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(
                            -(properties?.contentVerticalMargin ?? 0)
                    )
            make.trailing
                    .lessThanOrEqualTo(safeAreaLayoutGuide)
                    .offset(
                            -(properties?.contentHorizontalMargin ?? 0)
                    )

            make.center
                    .equalToSuperview()

            // Pin
            constraintVwContainerWidth = make.width
                    .equalTo(properties?.contentFixedSize ?? 0)
                    .priority(.low)
                    .constraint
        }

        svContentContainer.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            make.top
                    .greaterThanOrEqualToSuperview()
                    .offset(
                            properties?.contentTopPadding?.0 ?? 0
                    )
            make.top
                    .equalToSuperview()
                    .offset(
                            properties?.contentTopPadding?.1 ?? 0
                    )
                    .priority(.medium)

            make.leading
                    .greaterThanOrEqualToSuperview()
                    .offset(
                            properties?.contentHorizontalPadding?.0 ?? 0
                    )
            make.leading
                    .equalToSuperview()
                    .offset(
                            properties?.contentHorizontalPadding?.1 ?? 1
                    )
                    .priority(.medium)

            make.bottom
                    .lessThanOrEqualToSuperview()
                    .offset(
                            -(properties?.contentBottomPadding?.0 ?? 0)
                    )
            make.bottom
                    .equalToSuperview()
                    .offset(
                            -(properties?.contentBottomPadding?.1 ?? 0)
                    )
                    .priority(.medium)

            make.centerX
                    .equalToSuperview()
        }

        if properties?.contentFixedSize == nil {
            constraintVwContainerWidth?.deactivate()
        } else {
            constraintVwContainerWidth?.activate()
        }

        // MARK: View Assign
        self.vwOverlay = vwOverlay
        self.vwContainer = vwContainer
        self.svContentContainer = svContentContainer

        self.constraintVwContainerWidth = constraintVwContainerWidth
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

    func generateScrollForCustomViewDesign() -> UIScrollView {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = true
        return view
    }

    func generateImageViewForBannerDesign() -> UIImageView {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        return view
    }
}
