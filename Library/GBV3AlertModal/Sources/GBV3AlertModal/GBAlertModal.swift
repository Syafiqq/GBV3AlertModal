import Foundation
import UIKit
import SnapKit

private var kEmptySpaceForKeyboardExtension: CGFloat = 48

// MARK: - LIFECYCLE AND CALLBACK

open class GBAlertModal: UIView {
    // MARK: Outlets
    // Overlay
    public private(set) var vwOverlay: UIView?

    // Main Container
    public private(set) var vwContainer: UIView?

    // Main Content
    public private(set) var svContentContainer: UIStackView?

    // Content
    public private(set) var vwBanner: UIView?
    public private(set) var ivBanner: UIImageView?

    public private(set) var lbTitle: UILabel?

    public private(set) var svSubtitleContainer: UIScrollView?
    public private(set) var lbSubtitle: UILabel?
    public private(set) weak var vwSubtitle: UIView?

    // Main action container
    public private(set) var svMainActionContainer: UIStackView?

    // Action
    public private(set) var vwPrimaryAction: UIView?
    public private(set) var btPrimaryAction: UIButton?
    public private(set) var vwSecondaryAction: UIView?
    public private(set) var btSecondaryAction: UIButton?

    public private(set) var btCloseAction: UIButton?

    // Divider
    public private(set) var vwBannerAndBelowDivider: UIView?
    public private(set) var vwTitleAndBelowDivider: UIView?
    public private(set) var vwSubtitleAndBelowDivider: UIView?

    // MARK: Constraints

    // MARK: Attributes Gestures
    var tapRecognizerOverlay: UIGestureRecognizer?

    // MARK: ViewModel

    // MARK: Private Properties

    var properties: Properties?
    var dataHolder: DataHolder?

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

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Deinitialization

    deinit {
        removeKeyboardEvents()
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
        removeKeyboardEvents()
        listenKeyboardEvents()
    }

    func initData() {
    }

    /// The current render decisions, computed by the pure `resolve(...)` mirror from the
    /// live view state. Orientation is read here (via `UIWindow.isLandscape`) and passed in
    /// so the resolver itself stays deterministic.
    func makeResolvedModal() -> ResolvedModal {
        Self.resolve(
                properties: properties,
                holder: dataHolder ?? .default,
                isLandscape: UIWindow.isLandscape,
                isPad: UIDevice.current.userInterfaceIdiom == .pad
        )
    }

    // MARK: Views

    // Widened from `private` to `internal`: called from `updateDialog` in
    // GBAlertModal+Lifecycle.swift (different file, same module).
    internal func unregisterDialogView() {
        svContentContainer?.removeAllArrangedSubviews()

        vwBanner?.removeFromSuperview()
        ivBanner?.removeFromSuperview()
        lbTitle?.removeFromSuperview()
        svSubtitleContainer?.removeFromSuperview()
        lbSubtitle?.removeFromSuperview()
        vwSubtitle?.removeFromSuperview()

        vwBannerAndBelowDivider?.removeFromSuperview()
        vwTitleAndBelowDivider?.removeFromSuperview()
        vwSubtitleAndBelowDivider?.removeFromSuperview()

        svMainActionContainer?.removeAllArrangedSubviews()
        svMainActionContainer?.removeFromSuperview()

        vwPrimaryAction?.removeFromSuperview()
        btPrimaryAction?.removeFromSuperview()
        vwSecondaryAction?.removeFromSuperview()
        btSecondaryAction?.removeFromSuperview()

        btCloseAction?.removeFromSuperview()
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    // Widened from `private` to `internal`: called from `updateDialog` in
    // GBAlertModal+Lifecycle.swift (different file, same module).
    internal func registerDialogView() {
        let resolved = makeResolvedModal()

        // MARK: View Initialization
        // Setup banner
        if resolved.showsBanner, let banner = dataHolder?.banner {
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
        if resolved.showsTitle {
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
                      title.length > 0 {
                let lbTitle = generateLabelForTitleDesign()
                lbTitle.attributedText = title
                self.lbTitle = lbTitle
            }
        } else {
            lbTitle = nil
        }

        // Setup subtitle
        if dataHolder?.subtitle != nil ||
                   dataHolder?.subtitleAttributed != nil ||
                   dataHolder?.subtitleCustomView != nil {
            let svSubtitleContainer = generateScrollForCustomViewDesign()
            let vwSubtitle: UIView?
            switch resolved.subtitle {
            case .plain(let subtitle):
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
            case .attributed:
                let lbSubtitle = generateLabelForSubtitleDesign()
                lbSubtitle.attributedText = dataHolder?.subtitleAttributed

                vwSubtitle = lbSubtitle
                self.lbSubtitle = lbSubtitle
            case .custom:
                vwSubtitle = dataHolder?.subtitleCustomView
                self.vwSubtitle = dataHolder?.subtitleCustomView
            case .none:
                vwSubtitle = nil
            }

            if let vwSubtitle {
                svSubtitleContainer.addSubview(vwSubtitle)

                self.svSubtitleContainer = svSubtitleContainer
            }
        } else {
            svSubtitleContainer = nil
            lbSubtitle = nil
            vwSubtitle = nil
        }

        // Setup primaryAction
        if resolved.showsPrimary,
           let primaryAction = dataHolder?.primaryAction,
           let primaryActionStyle = properties?.primaryActionStyle {
            let vwPrimaryAction = generateGenericViewDesign()

            let btPrimaryAction = generateButtonForActionDesign(style: primaryActionStyle)
            configureButtonActionStyle(btPrimaryAction, title: primaryAction, style: primaryActionStyle)

            vwPrimaryAction.addSubview(btPrimaryAction)

            self.vwPrimaryAction = vwPrimaryAction
            self.btPrimaryAction = btPrimaryAction
        } else {
            vwPrimaryAction = nil
            btPrimaryAction = nil
        }

        // Setup secondaryAction
        if resolved.showsSecondary,
           let secondaryAction = dataHolder?.secondaryAction,
           let secondaryActionStyle = properties?.secondaryActionStyle {
            let vwSecondaryAction = generateGenericViewDesign()

            let btSecondaryAction = generateButtonForActionDesign(style: secondaryActionStyle)
            configureButtonActionStyle(btSecondaryAction, title: secondaryAction, style: secondaryActionStyle)

            vwSecondaryAction.addSubview(btSecondaryAction)

            self.vwSecondaryAction = vwSecondaryAction
            self.btSecondaryAction = btSecondaryAction
        } else {
            vwSecondaryAction = nil
            btSecondaryAction = nil
        }

        // Setup main action container
        if resolved.showsPrimary || resolved.showsSecondary {
            let svMainActionContainer = generateStackViewForMainButtonDesign()
            svMainActionContainer.spacing = properties?.space?.interButton ?? .zero

            self.svMainActionContainer = svMainActionContainer
        } else {
            svMainActionContainer = nil
        }

        // Setup close action
        if resolved.showsCloseButton,
           let vwContainer = vwContainer {
            let btCloseAction = generateButtonForCloseDesign()
            vwContainer.addSubview(btCloseAction)

            self.btCloseAction = btCloseAction
        } else {
            btCloseAction = nil
        }

        // Setup Divider
        // Setup banner and its below
        if vwBanner != nil,
           lbTitle != nil || svSubtitleContainer != nil || svMainActionContainer != nil {
            let vwBannerAndBelowDivider = generateGenericViewDesign()

            self.vwBannerAndBelowDivider = vwBannerAndBelowDivider
        } else {
            vwBannerAndBelowDivider = nil
        }

        // Setup title and its below
        if lbTitle != nil,
           svSubtitleContainer != nil || svMainActionContainer != nil {
            let vwTitleAndBelowDivider = generateGenericViewDesign()

            self.vwTitleAndBelowDivider = vwTitleAndBelowDivider
        } else {
            vwTitleAndBelowDivider = nil
        }

        // Setup subtitle and its below
        if svSubtitleContainer != nil,
           svMainActionContainer != nil {
            let vwSubtitleAndBelowDivider = generateGenericViewDesign()

            self.vwSubtitleAndBelowDivider = vwSubtitleAndBelowDivider
        } else {
            vwSubtitleAndBelowDivider = nil
        }

        // MARK: View Graph
        // Compile View

        [
            vwPrimaryAction,
            vwSecondaryAction
        ]
                .forEach {
                    guard let view = $0 else {
                        return
                    }
                    svMainActionContainer?.addArrangedSubview(view)
                }

        [
            vwBanner,
            vwBannerAndBelowDivider,
            lbTitle,
            vwTitleAndBelowDivider,
            svSubtitleContainer,
            vwSubtitleAndBelowDivider,
            svMainActionContainer
        ]
                .forEach {
                    guard let view = $0 else {
                        return
                    }
                    svContentContainer?.addArrangedSubview(view)
                }

        // MARK: View Constraints
        // Banner
        if let vwBanner {
            vwBanner.snp.makeConstraints { (make: ConstraintMaker) in
                // Pin
                if let bannerMaxHeight = properties?.bannerMaxHeight {
                    make.height
                            .lessThanOrEqualTo(bannerMaxHeight)
                            .priority(UILayoutPriority(751))
                }
                if let bannerFixedHeight = properties?.bannerFixedHeight {
                    make.height
                            .equalTo(bannerFixedHeight)
                            .priority(UILayoutPriority(251))
                }
            }
        }
        if let ivBanner {
            ivBanner.snp.makeConstraints { (make: ConstraintMaker) in
                // Align
                make.top
                        .equalToSuperview()
                make.leading
                        .greaterThanOrEqualToSuperview()
                make.leading
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

        // Banner divider
        if let vwBannerAndBelowDivider {
            vwBannerAndBelowDivider.snp.makeConstraints { (make: ConstraintMaker) in
                make.height
                        .equalTo(properties?.space?.banner ?? .zero)
            }
        }

        // Subtitle
        if let svSubtitleContainer,
           let vwSubtitle = vwSubtitle ?? lbSubtitle {
            vwSubtitle.snp.makeConstraints { (make: ConstraintMaker) in
                make.edges
                        .equalTo(svSubtitleContainer.contentLayoutGuide)
                make.width
                        .equalTo(svSubtitleContainer.frameLayoutGuide)
                make.height
                        .equalTo(svSubtitleContainer.frameLayoutGuide)
                        .priority(.low)
            }
        }

        // Title Divider
        if let vwTitleAndBelowDivider {
            vwTitleAndBelowDivider.snp.makeConstraints { (make: ConstraintMaker) in
                make.height
                        .equalTo(properties?.space?.title ?? .zero)
            }
        }

        // Subtitle Divider
        if let vwSubtitleAndBelowDivider {
            vwSubtitleAndBelowDivider.snp.makeConstraints { (make: ConstraintMaker) in
                make.height
                        .equalTo(properties?.space?.subtitle ?? .zero)
            }
        }

        // Primary Action
        if let vwPrimaryAction,
           let btPrimaryAction,
           let primaryActionStyle = properties?.primaryActionStyle {
            configureButtonActionConstraint(btPrimaryAction, parent: vwPrimaryAction, style: primaryActionStyle)
        }

        // Secondary Action
        if let vwSecondaryAction,
           let btSecondaryAction,
           let secondaryActionStyle = properties?.secondaryActionStyle {
            configureButtonActionConstraint(btSecondaryAction, parent: vwSecondaryAction, style: secondaryActionStyle)
        }

        // Close Action
        if let btCloseAction {
            btCloseAction.snp.makeConstraints { (make: ConstraintMaker) in
                make.top.trailing
                        .equalToSuperview()
                make.size
                        .equalTo(48)
                make.leading
                        .greaterThanOrEqualToSuperview()
                make.bottom
                        .lessThanOrEqualToSuperview()
            }
        }
    }

    // Widened from `private` to `internal`: called from `updateDialog` in
    // GBAlertModal+Lifecycle.swift (different file, same module).
    internal func adjustDialogViewStyle() {
        let resolved = makeResolvedModal()

        // Base View
        tintColor = properties?.baseTint

        // Overlay
        vwOverlay?.backgroundColor = properties?.overlayColor

        // Content Container
        vwContainer?.backgroundColor = properties?.contentProperty?.backgroundColor
        vwContainer?.layer.cornerRadius = properties?.contentProperty?.cornerRadius ?? .zero

        // Content Container Stack
        svContentContainer?.alignment = properties?.contentProperty?.childShouldMatchParent == true ? .fill : .center

        // Button Action Stack
        svMainActionContainer?.alignment = resolved.buttonsMatchParent ? .fill : .center

        // Button Action Orientation
        svMainActionContainer?.axis = resolved.buttonAxis

        // Close Button
        btCloseAction?.tintColor = properties?.closeButtonTint
        btCloseAction?.setImage(
                dataHolder?.closeImage ?? UIImage(
                        named: "ic_fa_xmark_24",
                        in: Bundle.module,
                        compatibleWith: nil
                ),
                for: .normal
        )
    }

    // Widened from `private` to `internal`: called from `updateDialog` in
    // GBAlertModal+Lifecycle.swift (different file, same module).
    internal func adjustBaseDialogConstraint() {
        if let vwContainer = vwContainer {
            adjustVwContainerConstraint(vwContainer)
        }
        if let svContentContainer = svContentContainer {
            adjustSvContentContainerConstraint(svContentContainer)
        }
    }

    private func adjustVwContainerConstraint(_ vwContainer: UIView) {
        vwContainer.snp.remakeConstraints { (make: ConstraintMaker) in
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
        }
    }

    // swiftlint:disable:next function_body_length
    private func adjustSvContentContainerConstraint(_ svContentContainer: UIView) {
        svContentContainer.snp.remakeConstraints { (make: ConstraintMaker) in
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

    // Widened from `private` to `internal`: called from `layoutSubviews` in
    // GBAlertModal+Lifecycle.swift (different file, same module).
    internal func adjustSvContentContainerConstraintWidth(_ svContentContainer: UIView) {
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

    /// The fixed / max content-width constraints to apply, unpacked from the pure resolver's
    /// `WidthResolution`. Both may be present at once, mirroring the two independent `if let`s
    /// this replaced.
    private func resolvedContentWidths() -> (fixed: CGFloat?, max: CGFloat?) {
        switch makeResolvedModal().contentWidth {
        case .flexible:
            return (nil, nil)
        case .fixed(let fixed):
            return (fixed, nil)
        case .max(let max):
            return (nil, max)
        case .fixedAndMax(let fixed, let max):
            return (fixed, max)
        }
    }

    // MARK: Model

    // Widened from `private` to `internal`: called from `updateDialog` in
    // GBAlertModal+Lifecycle.swift (different file, same module).
    internal func updateProperties(_ properties: Properties) {
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
                bannerMaxHeight: properties.bannerMaxHeight
                        ?? globalProperties.bannerMaxHeight,
                bannerFixedHeight: properties.bannerFixedHeight
                        ?? globalProperties.bannerFixedHeight,
                titleFont: properties.titleFont
                        ?? globalProperties.titleFont,
                titleColor: properties.titleColor
                        ?? globalProperties.titleColor,
                subtitleFont: properties.subtitleFont
                        ?? globalProperties.subtitleFont,
                subtitleColor: properties.subtitleColor
                        ?? globalProperties.subtitleColor,
                buttonActionShouldMatchParent: properties.buttonActionShouldMatchParent
                        ?? globalProperties.buttonActionShouldMatchParent,
                buttonActionOrientation: properties.buttonActionOrientation
                        ?? globalProperties.buttonActionOrientation,
                primaryActionStyle: properties.primaryActionStyle
                        ?? globalProperties.primaryActionStyle,
                secondaryActionStyle: properties.secondaryActionStyle
                        ?? globalProperties.secondaryActionStyle,
                closeButtonTint: properties.closeButtonTint
                        ?? globalProperties.closeButtonTint,
                space: properties.space
                        ?? globalProperties.space
        )
    }
}

// MARK: - KEYBOARD

private extension GBAlertModal {
    func listenKeyboardEvents() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
                self,
                selector: #selector(onKeyboardWillShowNotification),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
        )
        notificationCenter.addObserver(
                self,
                selector: #selector(onKeyboardWillHideNotification),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
        )
        notificationCenter.addObserver(
                self,
                selector: #selector(onKeyboardChangeFrameNotification),
                name: UIResponder.keyboardWillChangeFrameNotification,
                object: nil
        )
        notificationCenter.addObserver(
                self,
                selector: #selector(onKeyboardChangeFrameNotification),
                name: UIResponder.keyboardDidChangeFrameNotification,
                object: nil
        )
    }

    func removeKeyboardEvents() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
    }

    @objc
    private func onKeyboardWillHideNotification(_ notification: Notification) {
        restoreDialogPosition()
    }

    @objc
    private func onKeyboardWillShowNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let valueKeyboard = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }

        let keyboardFrame = valueKeyboard.cgRectValue
        adjustDialogPosition(keyboardFrame)
    }

    @objc
    private func onKeyboardChangeFrameNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let valueKeyboard = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }

        let keyboardFrame = valueKeyboard.cgRectValue
        let deviceFrame = UIScreen.main.bounds

        // It is just assumption
        let isDocked = abs(deviceFrame.maxY - keyboardFrame.maxY) < 2 // Threshold
                && abs(deviceFrame.maxX - keyboardFrame.maxX) < 2 // Threshold
        let isMinimised = (deviceFrame.maxY - keyboardFrame.maxY) < 0
                || (deviceFrame.maxX - keyboardFrame.maxX) < 0

        if isDocked {
            adjustDialogPosition(keyboardFrame)
        } else {
            if isMinimised {
                restoreDialogPosition()
            } else if keyboardFrame == .zero {
                restoreDialogPosition()
            } else {
                adjustDialogPosition(keyboardFrame)
            }
        }
    }

    func restoreDialogPosition() {
        vwContainer?.transform = .identity
    }

    // swiftlint:disable:next function_body_length
    func adjustDialogPosition(_ keyboardFrame: CGRect) {
        guard let vwContainer else {
            return
        }
        // check if upper keyboard has more space than btm
        if keyboardFrame.minY > (UIScreen.main.bounds.maxY - keyboardFrame.maxY) {
            guard let bottomView = svMainActionContainer ?? svSubtitleContainer ?? lbTitle,
                  let bottomViewSuperview = bottomView.superview else {
                return
            }
            let bottomViewRelativeFrame = bottomViewSuperview.convert(
                    bottomView.frame,
                    to: nil
            )
            var difference = keyboardFrame.minY
                    - bottomViewRelativeFrame.maxY
                    - kEmptySpaceForKeyboardExtension

            if let responder = firstResponder,
               let responderSuperview = responder.superview {
                let responderRelativeFrame = responderSuperview.convert(responder.frame, to: nil)
                if difference + responderRelativeFrame.minY < 0 {
                    difference = -responderRelativeFrame.minY
                }
            }

            difference += vwContainer.transform.ty

            guard difference < 0 else {
                return
            }
            vwContainer.transform = .identity.translatedBy(x: 0, y: difference)
        } else {
            guard let bottomView = lbTitle ?? svSubtitleContainer ?? svMainActionContainer,
                  let bottomViewSuperview = bottomView.superview else {
                return
            }
            let bottomViewRelativeFrame = bottomViewSuperview.convert(
                    bottomView.frame,
                    to: nil
            )
            var difference = keyboardFrame.maxY
                    - bottomViewRelativeFrame.minY
                    + kEmptySpaceForKeyboardExtension

            if let responder = firstResponder,
               let responderSuperview = responder.superview {
                let responderRelativeFrame = responderSuperview.convert(responder.frame, to: nil)
                if difference + responderRelativeFrame.maxY > UIScreen.main.bounds.maxY {
                    difference = UIScreen.main.bounds.maxY - responderRelativeFrame.maxY
                }
            }

            difference += vwContainer.transform.ty

            guard difference > 0 else {
                return
            }
            vwContainer.transform = .identity.translatedBy(x: 0, y: difference)
        }
    }
}

// MARK: - DELEGATIONS

// MARK: - EXTENSION

private extension UIView {
    var firstResponder: UIView? {
        guard !isFirstResponder else {
            return self
        }

        for subview in subviews {
            if let firstResponder = subview.firstResponder {
                return firstResponder
            }
        }

        return nil
    }
}

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

    func generateScrollForCustomViewDesign() -> UIScrollView {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = true
        return view
    }

    func generateLabelForSubtitleDesign() -> UILabel {
        let view = UILabel(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.numberOfLines = 0
        view.textAlignment = .center
        return view
    }

    func generateStackViewForMainButtonDesign() -> UIStackView {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.distribution = .fillEqually
        view.alignment = .center
        return view
    }

    func generateButtonForCloseDesign() -> UIButton {
        let view = UIButton(type: .system)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}
