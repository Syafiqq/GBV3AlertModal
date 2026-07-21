import Foundation
import UIKit
import SnapKit

// MARK: - LIFECYCLE AND CALLBACK

extension GBAlertModal {
    // MARK: Lifecycle

    // MARK: Override Function

    override public func layoutSubviews() {
        super.layoutSubviews()

        if let svContentContainer {
            adjustSvContentContainerConstraintWidth(svContentContainer)
        }
    }

    // MARK: Public Function

    public func show(parent: UIView, completion onShown: @escaping () -> Void) {
        alpha = 1
        transform = .identity

        parent.addSubview(self)
        snp.makeConstraints { (make: ConstraintMaker) in
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
                },
                completion: { [weak self] _ in
                    self?.removeFromSuperview()
                }
        )
    }

    public func dismiss() {
        if makeResolvedModal().dismissOnAction == true {
            hide()
        }
    }

    public func dismissAndEmit(event: ActionType) {
        if makeResolvedModal().dismissOnAction == true {
            hide()
        }
        dataHolder?.completion?(self, event)
    }

    public func updateDialog(holder: DataHolder, properties: Properties?) {
        dataHolder = holder
        updateProperties(properties ?? self.properties ?? globalProperties)

        unregisterDialogView()
        unregisterEvents()
        adjustBaseDialogConstraint()
        registerDialogView()
        adjustDialogViewStyle()
        registerEvents()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }

    public func changePrimaryActionEnableState(isEnable: Bool) {
        guard let btPrimaryAction else {
            return
        }
        btPrimaryAction.isEnabled = isEnable
        if let style = properties?.primaryActionStyle {
            configureButtonActionStyle(btPrimaryAction, style: style)
        }
    }

    public func changeSecondaryActionEnableState(isEnable: Bool) {
        guard let btSecondaryAction else {
            return
        }
        btSecondaryAction.isEnabled = isEnable
        if let style = properties?.secondaryActionStyle {
            configureButtonActionStyle(btSecondaryAction, style: style)
        }
    }
}
