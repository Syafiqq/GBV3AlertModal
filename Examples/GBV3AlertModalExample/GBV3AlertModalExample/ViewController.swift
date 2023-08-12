// @swiftlint:disable all
//
//  ViewController.swift
//  GBV3AlertModalExample
//
//  Created by engineering on 29/11/22.
//

import UIKit
import GBV3AlertModal

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        let properties = Presentation.UiKit.V3AlertModal.properties
        GBV3AlertModal.globalProperties = properties
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        print(Presentation.UiKit.V3AlertModal.holder.copy(title: "Testing").closeOnTapOverlay)
        Presentation.UiKit.V3AlertModal(
                        properties: Presentation.UiKit.V3AlertModal.properties.copy(
                                bannerRatio: 200.0 / 168.0,
                                bannerMaxHeight: 168,
                                bannerFixedHeight: 168,
                                titleFont: FontHelper.DMSans.bold.font(24),
                                titleColor: Colors.geniebook_blue_navy,
                                subtitleFont: FontHelper.DMSans.regular.font(16),
                                buttonActionShouldMatchParent: true,
                                primaryActionStyle: .obliqueBottomLeft(
                                        Presentation.UiKit.V3AlertModal.obliqueBottomLeftTheme
                                ),
                                space: GBAlertModal.Properties.ComponentSpace(
                                        banner: 16,
                                        title: 12,
                                        subtitle: 20,
                                        interButton: 16
                                )
                        ),
                        holder: Presentation.UiKit.V3AlertModal.holder.copy(
                                banner: UIImage(named: "streak_win"),
                                title: "You did it!".localized,
                                subtitle: "AWESOME! You’ve completed an amazing 30-day learning streak. What’s even better, you’re building a wonderful learning habit.".localized,
                                primaryAction: "Continue".localized,
                                completion: { _, _ in }
                        )
                )
                .show(completion: {})
    }
}

enum Presentation {
    enum UiKit {
    }
}

enum DialogType: Equatable {
    case deferred
}

protocol Dialogable: AnyObject {
    var isShowing: Bool { get }
    var type: DialogType? { get set }
    func show()
    func removeSelf()
    var targetPage: UIViewController? { get set }
}

class DialogView: UIView, Dialogable {
    var type: DialogType?
    var isShowing: Bool = false
    weak var targetPage: UIViewController?

    func show() {
        isShowing = true
    }

    func removeSelf() {
        isShowing = false
    }
}

// @swiftlint:enable all

extension Presentation.UiKit {
    class V3AlertModal: DialogView {
        let dialog: GBAlertModal

        init(properties: GBAlertModal.Properties? = nil, holder: GBAlertModal.DataHolder) {
            dialog = GBAlertModal(properties: properties, holder: holder)
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func show(completion onShown: @escaping () -> Void) {
            guard let parent = AppCompatHelper.keyWindow else {
                return
            }
            dialog.show(parent: parent, completion: onShown)
        }

        override func removeSelf() {
            dialog.hide()
        }

        func dismiss() {
            dialog.dismiss()
        }

        func dismissAndEmit(event: GBAlertModal.ActionType) {
            dialog.dismissAndEmit(event: event)
        }

        func updateDialog(holder: GBAlertModal.DataHolder, properties: GBAlertModal.Properties? = nil) {
            dialog.updateDialog(holder: holder, properties: properties)
        }
    }
}

extension Presentation.UiKit.V3AlertModal {
    // MARK: - PROPERTIES
    private static var _properties: GBAlertModal.Properties?
    static var properties: GBAlertModal.Properties {
        let properties: GBAlertModal.Properties
        if let _properties = _properties {
            properties = _properties
        } else {
            properties = GBAlertModal.Properties(
                    baseTint: UIColor.Custom.accentSecondary,
                    overlayColor: Colors.text_primary.withAlphaComponent(0.6),
                    contentProperty: Self.contentProperty,
                    margin: Self.margin,
                    padding: Self.padding,
                    bannerRatio: 1,
                    titleFont: FontHelper.DMSans.bold.font(16),
                    titleColor: UIColor.Custom.primary,
                    subtitleFont: FontHelper.DMSans.regular.font(16),
                    subtitleColor: UIColor.Custom.textPrimaryDark,
                    primaryActionStyle: .capsule(capsuleTheme),
                    closeButtonTint: .black,
                    space: Self.space
            )
            _properties = properties
        }
        return properties
    }

    // MARK: Content Property
    static var contentProperty: GBAlertModal.Properties.ContentProperty {
        GBAlertModal.Properties.ContentProperty(
                backgroundColor: .white,
                cornerRadius: 8,
                fixedWidth: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
                maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
                childShouldMatchParent: true
        )
    }

    // MARK: Default Padding
    static var padding: UIMinMaxEdgeInsets {
        UIMinMaxEdgeInsets(top: (20, 40), left: (20, 48), bottom: (20, 32), right: (20, 48))
    }

    // MARK: Default Margin
    static var margin: UIEdgeInsets {
        UIEdgeInsets(vertical: 40, horizontal: 20)
    }

    // MARK: Default Space
    static var space: GBAlertModal.Properties.ComponentSpace {
        GBAlertModal.Properties.ComponentSpace(
                banner: 24,
                title: 24,
                subtitle: 24,
                interButton: 16
        )
    }

    // MARK: - DATA HOLDER
    private static var _holder: GBAlertModal.DataHolder?
    static var holder: GBAlertModal.DataHolder {
        let holder: GBAlertModal.DataHolder
        if let _holder = _holder {
            holder = _holder
        } else {
            holder = GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    banner: nil,
                    title: nil,
                    titleAttributed: nil,
                    subtitle: nil,
                    subtitleAttributed: nil,
                    subtitleCustomView: nil,
                    primaryAction: "action_okay".localized,
                    secondaryAction: nil,
                    showCloseButton: false,
                    closeImage: nil,
                    dismissOnAction: true,
                    completion: nil
            )
            _holder = holder
        }
        return holder
    }

    // MARK: Action Theme -> Capsule
    static var capsuleTheme: GBAlertModal.ActionStyle.CapsuleTheme {
        GBAlertModal.ActionStyle.CapsuleTheme(
                backgroundColor: UIColor.Custom.accentSecondary,
                titleColor: UIColor.white,
                titleFont: FontHelper.DMSans.medium.font(16.0)
        )
    }

    // MARK: Action Theme -> Capsule Outline
    static var capsuleOutlineTheme: GBAlertModal.ActionStyle.CapsuleOutlineTheme {
        GBAlertModal.ActionStyle.CapsuleOutlineTheme(
                backgroundColor: .clear,
                titleColor: UIColor.Custom.labelSubtitle,
                borderWidth: 2,
                borderColor: UIColor.Custom.labelSubtitle.cgColor,
                titleFont: FontHelper.DMSans.medium.font(16.0)
        )
    }

    // MARK: Action Theme -> Plain
    static var plainTheme: GBAlertModal.ActionStyle.PlainTheme {
        GBAlertModal.ActionStyle.PlainTheme(
                titleColor: UIColor.Custom.accentSecondaryDark,
                titleFont: FontHelper.DMSans.medium.font(16.0)
        )
    }

    // MARK: Action Theme -> Oblique
    static var obliqueBottomLeftTheme: GBAlertModal.ActionStyle.ObliqueBottomLeftTheme {
        GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
                unPressedColor: UIColor(netHex: 0xF7941E),
                pressedColor: UIColor(netHex: 0x038CD5),
                shadowColor: UIColor(netHex: 0xE57B41).cgColor,
                titleColor: .white,
                titleFont: FontHelper.DMSans.medium.font(16.0)
        )
    }
}
