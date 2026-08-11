// swiftlint:disable all
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

        let abc = Presentation.UiKit.V3AlertModal(
                properties: Presentation.UiKit.V3AlertModal.popupProperties.copy(
                        bannerRatio: 320.0 / 229.0,
                        bannerMaxHeight: 216,
                        bannerFixedHeight: 184
                ),
                holder: Presentation.UiKit.V3AlertModal.holder.copy(
                        closeOnTapOverlay: false,
                        banner: UIImage(named: "img_illust_onboarding"),
                        title: "Help us make your experience better Help us make your experience better",
                        subtitle: "Take our quick survey and gain bubbles!",
                        primaryAction: "Proceed to feedback",
                        secondaryAction: "Not Now",
                        showCloseButton: false,
                        dismissOnAction: false
                ),
                completion: { [weak self] _, state in
                    guard self != nil else {
                        return
                    }

                    switch state {
                    case .primary:
                        break
                    case .secondary:
                        break
                    default:
                        break
                    }
                }
        )

        abc.show()
    }
}

enum Presentation {
    enum UiKit {
    }
}

enum DialogType: Equatable {
    case deferred
}

@MainActor
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
    class V3AlertModal: GBAlertModal, Dialogable {
        open var type: DialogType?
        open var isShowing: Bool = false
        open weak var targetPage: UIViewController?

        public init(
                properties: GBAlertModal.Properties? = nil,
                holder: GBAlertModal.DataHolder,
                completion: @escaping (V3AlertModal, GBAlertModal.ActionType) -> Void
        ) {
            super.init(properties: properties, holder: holder)

            let currentCompletion = holder.completion

            var holder = holder
            holder = holder.copy(
                completion: { [weak self] modal, type in
                    currentCompletion?(modal, type)
                    if let self {
                        completion(self, type)
                    }
                }
            )
            updateDialog(holder: holder, properties: properties)
        }

        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public func show() {
            guard let parent = AppCompatHelper.keyWindow else {
                return
            }
            show(parent: parent, completion: { })
        }

        public func removeSelf() {
            hide()
        }

        public func updateDialog(
                properties: GBAlertModal.Properties? = nil,
                holder: GBAlertModal.DataHolder,
                completion: @escaping (V3AlertModal, GBAlertModal.ActionType) -> Void
        ) {
            let currentCompletion = holder.completion

            var holder = holder
            holder = holder.copy(
                completion: { [weak self] modal, type in
                    currentCompletion?(modal, type)
                    if let self {
                        completion(self, type)
                    }
                }
            )
            updateDialog(holder: holder, properties: properties)
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
                    bannerMaxHeight: nil,
                    bannerFixedHeight: nil,
                    titleFont: FontHelper.DMSans.bold.font(24),
                    titleColor: UIColor.Custom.primary,
                    subtitleFont: FontHelper.DMSans.regular.font(16),
                    subtitleColor: UIColor.Custom.textPrimaryDark,
                    buttonActionShouldMatchParent: true,
                    buttonActionOrientation: .vertical,
                    primaryActionStyle: .obliqueBottomLeft(Presentation.UiKit.V3AlertModal.obliqueBottomLeftTheme),
                    secondaryActionStyle: .plain(Presentation.UiKit.V3AlertModal.plainTheme),
                    closeButtonTint: .black,
                    space: Self.space
            )
            _properties = properties
        }
        return properties
    }

    static var popupProperties: GBAlertModal.Properties {
        properties.copy(
                padding: UIMinMaxEdgeInsets(
                        top: (20, 32),
                        left: (20, 32),
                        bottom: (20, 32),
                        right: (20, 32)
                ),
                titleFont: FontHelper.OpenSans.bold.font(24),
                titleColor: UIColor.Custom.GBPNavy,
                subtitleFont: FontHelper.OpenSans.regular.font(16),
                subtitleColor: UIColor.Custom.labelSubtitle,
                space: GBAlertModal.Properties.ComponentSpace(
                        banner: 16,
                        title: 16,
                        subtitle: 24,
                        interButton: 8
                )
        )
    }

    // MARK: Content Property
    static var contentProperty: GBAlertModal.Properties.ContentProperty {
        GBAlertModal.Properties.ContentProperty(
                backgroundColor: .white,
                cornerRadius: 16,
                fixedWidthPortrait: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
                maxWidthPortrait: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
                fixedWidthLandscape: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
                maxWidthLandscape: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
                childShouldMatchParent: true
        )
    }

    // MARK: Default Padding
    static var padding: UIMinMaxEdgeInsets {
        UIMinMaxEdgeInsets(
                top: (16, 24),
                left: (16, 32),
                bottom: (16, 24),
                right: (16, 32)
        )
    }

    // MARK: Default Margin
    static var margin: UIEdgeInsets {
        UIEdgeInsets(vertical: 40, horizontal: 20)
    }

    // MARK: Default Space
    static var space: GBAlertModal.Properties.ComponentSpace {
        GBAlertModal.Properties.ComponentSpace(
                banner: 8,
                title: 8,
                subtitle: 16,
                interButton: 8
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
                backgroundDisableColor: UIColor(netHex: 0xB4B4B4),
                titleColor: UIColor.white,
                titleDisableColor: UIColor.white,
                titleFont: FontHelper.DMSans.medium.font(16.0)
        )
    }

    // MARK: Action Theme -> Capsule Outline
    static var capsuleOutlineTheme: GBAlertModal.ActionStyle.CapsuleOutlineTheme {
        GBAlertModal.ActionStyle.CapsuleOutlineTheme(
                backgroundColor: .clear,
                backgroundDisableColor: .clear,
                titleColor: UIColor.Custom.labelSubtitle,
                titleDisableColor: UIColor(netHex: 0xB4B4B4),
                borderWidth: 2,
                borderColor: UIColor.Custom.labelSubtitle.cgColor,
                borderDisableColor: UIColor(netHex: 0xB4B4B4).cgColor,
                titleFont: FontHelper.DMSans.medium.font(16.0)
        )
    }

    // MARK: Action Theme -> Plain
    static var plainTheme: GBAlertModal.ActionStyle.PlainTheme {
        GBAlertModal.ActionStyle.PlainTheme(
                titleColor: UIColor.Custom.accentSecondaryDark,
                titleDisableColor: UIColor(netHex: 0xB4B4B4),
                titleFont: FontHelper.DMSans.medium.font(16.0)
        )
    }

    // MARK: Action Theme -> Oblique
    static var obliqueBottomLeftTheme: GBAlertModal.ActionStyle.ObliqueBottomLeftTheme {
        GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
                unPressedColor: UIColor(netHex: 0xF7941E),
                pressedColor: UIColor(netHex: 0x038CD5),
                disabledColor: UIColor(netHex: 0xB4B4B4),
                shadowColor: UIColor(netHex: 0xE57B41).cgColor,
                titleColor: .white,
                titleDisableColor: .white,
                titleFont: FontHelper.DMSans.medium.font(16.0)
        )
    }
}
