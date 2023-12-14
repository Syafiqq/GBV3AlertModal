// swiftlint:disable all
//
//  ViewController.swift
//  GBV3AlertModalExample
//
//  Created by engineering on 29/11/22.
//

import UIKit
import GBV3AlertModal
import Lottie
import SnapKit

class ViewController: UIViewController {
    private var vwSubmitAnimation: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        let properties = Presentation.UiKit.V3AlertModal.properties
        GBV3AlertModal.globalProperties = properties
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let vwSubmitAnimation = generateViewForSubmitAnimation()

        print(Presentation.UiKit.V3AlertModal.holder.copy(title: "Testing").closeOnTapOverlay)
        let abc = Presentation.UiKit.V3AlertModal(
                        properties: Presentation.UiKit.V3AlertModal.properties.copy(
                                bannerRatio: 200.0 / 168.0,
                                bannerMaxHeight: 168,
                                bannerFixedHeight: 168,
                                titleFont: FontHelper.DMSans.bold.font(24),
                                titleColor: UIColor.Genie.submitExamResultReward,
                                subtitleFont: FontHelper.DMSans.regular.font(16),
                                buttonActionShouldMatchParent: true,
                                primaryActionStyle: .obliqueBottomLeft(Presentation.UiKit.V3AlertModal.obliqueBottomLeftTheme),
                                secondaryActionStyle: .plain(Presentation.UiKit.V3AlertModal.plainTheme),
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
                                primaryAction: "Continue".localized
                        ),
                        completion: { _, _ in }
                )

        abc.show()
        abc.isUserInteractionEnabled = false
        abc.dialog?.isUserInteractionEnabled = false
        abc.updateDialog(
            holder: Presentation.UiKit.V3AlertModal.holder.copy(
                banner: UIImage(named: "streak_win"),
                title: "You did it!".localized,
                subtitle: "AWESOME! You’ve completed an amazing 30-day learning streak. What’s even better, you’re building a wonderful learning habit.".localized,
                primaryAction: "",
                secondaryAction: "Yeah"
            )
        )
        abc.dialog?.changeSecondaryActionEnableState(isEnable: false)
        abc.dialog?.btPrimaryAction?.addSubview(vwSubmitAnimation)
        vwSubmitAnimation.snp.makeConstraints { (make: ConstraintMaker) -> Void in
            make.center
                    .equalToSuperview()
            make.height
                    .equalTo(32)
            make.width
                    .equalTo(vwSubmitAnimation.snp.height)
                    .multipliedBy(96.0 / 60.0)
        }
//        abc.dialog?.changePrimaryActionEnableState(isEnable: false)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            abc.dialog?.changePrimaryActionEnableState(isEnable: true)
//        }
    }

    func generateViewForSubmitAnimation() -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.Genie.accentSecondaryDark
        view.isUserInteractionEnabled = false

        let ivIcon = AnimationView(frame: .zero)
        ivIcon.translatesAutoresizingMaskIntoConstraints = false
        ivIcon.loopMode = .loop
        ivIcon.animation = Animation.named("lottie_four_dots_loading", bundle: Bundle.main)
        ivIcon.play()

        view.addSubview(ivIcon)

        ivIcon.snp.makeConstraints { make in
            make.edges
                    .equalToSuperview()
        }

        return view
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
    public class V3AlertModal: DialogView {
        public private(set) var dialog: GBAlertModal?
        public private(set) var completionLegacy: ((V3AlertModal, GBAlertModal.ActionType) -> Void)?
        public private(set) var completion: ((GBAlertModal, GBAlertModal.ActionType) -> Void)?

        public init(
                properties: GBAlertModal.Properties? = nil,
                holder: GBAlertModal.DataHolder,
                completion: @escaping (V3AlertModal, GBAlertModal.ActionType) -> Void
        ) {
            super.init(frame: .zero)

            var holder = holder
            self.completion = holder.completion
            completionLegacy = completion

            holder = holder.copy(completion: hookCompletion)
            dialog = GBAlertModal(properties: properties, holder: holder)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override public func show() {
            guard let parent = AppCompatHelper.keyWindow else {
                return
            }
            dialog?.show(parent: parent, completion: { })
        }

        override public func removeSelf() {
            dialog?.hide()
        }

        public func dismiss() {
            dialog?.dismiss()
        }

        public func dismissAndEmit(event: GBAlertModal.ActionType) {
            dialog?.dismissAndEmit(event: event)
        }

        public func updateDialog(holder: GBAlertModal.DataHolder, properties: GBAlertModal.Properties? = nil) {
            dialog?.updateDialog(holder: holder, properties: properties)
        }

        public func updateDialog(
                properties: GBAlertModal.Properties? = nil,
                holder: GBAlertModal.DataHolder,
                completion: @escaping (V3AlertModal, GBAlertModal.ActionType) -> Void
        ) {
            var holder = holder
            self.completion = holder.completion
            completionLegacy = completion

            holder = holder.copy(completion: hookCompletion)
            dialog?.updateDialog(holder: holder, properties: properties)
        }

        public func hookCompletion(_ modal: GBAlertModal, _ type: GBAlertModal.ActionType) {
            completionLegacy?(self, type)
            completion?(modal, type)
        }
    }
}

public extension Presentation.UiKit.V3AlertModal {
    // MARK: - PROPERTIES
    private static var _properties: GBAlertModal.Properties?
    static var properties: GBAlertModal.Properties {
        let properties: GBAlertModal.Properties
        if let _properties = _properties {
            properties = _properties
        } else {
            properties = GBAlertModal.Properties(
                    baseTint: UIColor.Genie.accentSecondary,
                    overlayColor: Colors.text_primary.withAlphaComponent(0.6),
                    contentProperty: Self.contentProperty,
                    margin: Self.margin,
                    padding: Self.padding,
                    bannerRatio: 1,
                    bannerMaxHeight: nil,
                    bannerFixedHeight: nil,
                    titleFont: FontHelper.SHSans.bold.font(24),
                    titleColor: UIColor.Genie.primary,
                    subtitleFont: FontHelper.SHSans.regular.font(16),
                    subtitleColor: UIColor.Genie.textPrimaryDark,
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
                titleFont: FontHelper.SHSans.heavy.font(24),
                titleColor: UIColor.Genie.GBPNavy,
                subtitleFont: FontHelper.SHSans.regular.font(16),
                subtitleColor: UIColor.Genie.labelSubtitle,
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
                fixedWidth: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
                maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
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
                backgroundColor: UIColor.Genie.accentSecondary,
                backgroundDisableColor: UIColor.Genie.borderLight,
                titleColor: UIColor.white,
                titleDisableColor: UIColor.white,
                titleFont: FontHelper.SHSans.heavy.font(16.0)
        )
    }

    // MARK: Action Theme -> Capsule Outline
    static var capsuleOutlineTheme: GBAlertModal.ActionStyle.CapsuleOutlineTheme {
        GBAlertModal.ActionStyle.CapsuleOutlineTheme(
                backgroundColor: .clear,
                backgroundDisableColor: .clear,
                titleColor: UIColor.Genie.labelSubtitle,
                titleDisableColor: UIColor.Genie.borderLight,
                borderWidth: 2,
                borderColor: UIColor.Genie.labelSubtitle.cgColor,
                borderDisableColor: UIColor.Genie.borderLight.cgColor,
                titleFont: FontHelper.SHSans.heavy.font(16.0)
        )
    }

    // MARK: Action Theme -> Plain
    static var plainTheme: GBAlertModal.ActionStyle.PlainTheme {
        GBAlertModal.ActionStyle.PlainTheme(
                titleColor: UIColor.Genie.accentSecondaryDark,
                titleDisableColor: UIColor.Genie.borderLight,
                titleFont: FontHelper.SHSans.heavy.font(16.0)
        )
    }

    // MARK: Action Theme -> Oblique
    static var obliqueBottomLeftTheme: GBAlertModal.ActionStyle.ObliqueBottomLeftTheme {
        GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
                unPressedColor: UIColor.Genie.accentSecondaryDark,
                pressedColor: UIColor(netHex: 0x038CD5),
                disabledColor: UIColor.Genie.borderLight,
                shadowColor: UIColor.Genie.orangeMandarin.cgColor,
                titleColor: .white,
                titleDisableColor: .white,
                titleFont: FontHelper.SHSans.heavy.font(16.0)
        )
    }
}
