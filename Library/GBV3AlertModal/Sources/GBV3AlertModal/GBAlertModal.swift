import Foundation
import UIKit

private var kEmptySpaceForKeyboardExtension: CGFloat = 48

// MARK: - LIFECYCLE AND CALLBACK

open class GBAlertModal: UIView {
    // MARK: Outlets
    // Overlay
    // Setter widened from `private(set)` to `internal(set)`: assigned from `initDesign` in
    // GBAlertModal+ViewFactory.swift (different file, same module).
    public internal(set) var vwOverlay: UIView?

    // Main Container
    // Setter widened from `private(set)` to `internal(set)`: assigned from `initDesign` in
    // GBAlertModal+ViewFactory.swift (different file, same module).
    public internal(set) var vwContainer: UIView?

    // Main Content
    // Setter widened from `private(set)` to `internal(set)`: assigned from `initDesign` in
    // GBAlertModal+ViewFactory.swift (different file, same module).
    public internal(set) var svContentContainer: UIStackView?

    // Content
    // Setters widened from `private(set)` to `internal(set)`: assigned from `registerDialogView`
    // in GBAlertModal+ViewGraph.swift (different file, same module).
    public internal(set) var vwBanner: UIView?
    public internal(set) var ivBanner: UIImageView?

    public internal(set) var lbTitle: UILabel?

    public internal(set) var svSubtitleContainer: UIScrollView?
    public internal(set) var lbSubtitle: UILabel?
    public internal(set) weak var vwSubtitle: UIView?

    // Main action container
    public internal(set) var svMainActionContainer: UIStackView?

    // Action
    public internal(set) var vwPrimaryAction: UIView?
    public internal(set) var btPrimaryAction: UIButton?
    public internal(set) var vwSecondaryAction: UIView?
    public internal(set) var btSecondaryAction: UIButton?

    public internal(set) var btCloseAction: UIButton?

    // Divider
    public internal(set) var vwBannerAndBelowDivider: UIView?
    public internal(set) var vwTitleAndBelowDivider: UIView?
    public internal(set) var vwSubtitleAndBelowDivider: UIView?

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
//
// The `adjust*` constraint methods and `resolvedContentWidths()` that used to live here moved to
// `GBAlertModal+Layout.swift` in Task 6 (their pure geometry now lives in `Support/ModalLayout.swift`).

// MARK: - KEYBOARD

private extension GBAlertModal {
    // Widened from `private` to `internal`: called from `initEvents` in
    // GBAlertModal+Model.swift (different file, same module).
    internal func listenKeyboardEvents() {
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

    // Widened from `private` to `internal`: called from `initEvents` in
    // GBAlertModal+Model.swift (different file, same module); also used by `deinit`
    // in this file.
    internal func removeKeyboardEvents() {
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

    // Geometry now lives in `ModalKeyboardAvoider.offset(...)` (Sources/Support); this function
    // keeps only notification-era view state: which anchor view to read, coordinate conversion,
    // and applying the resulting transform.
    func adjustDialogPosition(_ keyboardFrame: CGRect) {
        guard let vwContainer else {
            return
        }

        let avoider = ModalKeyboardAvoider()
        let screenMaxY = UIScreen.main.bounds.maxY
        let keyboardHasMoreSpaceAbove = avoider.keyboardHasMoreSpaceAbove(
                keyboardFrame: keyboardFrame,
                screenMaxY: screenMaxY
        )

        let bottomView = keyboardHasMoreSpaceAbove
                ? (svMainActionContainer ?? svSubtitleContainer ?? lbTitle)
                : (lbTitle ?? svSubtitleContainer ?? svMainActionContainer)
        guard let bottomView, let bottomViewSuperview = bottomView.superview else {
            return
        }
        let anchorFrame = bottomViewSuperview.convert(bottomView.frame, to: nil)

        var responderFrame: CGRect?
        if let responder = firstResponder, let responderSuperview = responder.superview {
            responderFrame = responderSuperview.convert(responder.frame, to: nil)
        }

        guard let difference = avoider.offset(
                keyboardHasMoreSpaceAbove: keyboardHasMoreSpaceAbove,
                keyboardFrame: keyboardFrame,
                anchorFrame: anchorFrame,
                responderFrame: responderFrame,
                currentTransformY: vwContainer.transform.ty,
                screenMaxY: screenMaxY,
                emptySpace: kEmptySpaceForKeyboardExtension
        ) else {
            return
        }
        vwContainer.transform = .identity.translatedBy(x: 0, y: difference)
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
