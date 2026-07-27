// swiftlint:disable all
//  AppDelegate.swift
//  GBV3AlertModalExample
//
//  Created by engineering on 29/11/22.
//

import Foundation
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // MARK: - AppDelegate Lifecycle

    func application(
            _ application: UIApplication,
            willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
            // swiftlint:disable:previous discouraged_optional_collection
    ) -> Bool {
        true
    }

    func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
            // swiftlint:disable:previous discouraged_optional_collection
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let gallery = GalleryViewController()
        window.rootViewController = UINavigationController(rootViewController: gallery)
        window.makeKeyAndVisible()
        self.window = window

        let floatingControl = FloatingTraversalControl()
        window.addSubview(floatingControl)
        NSLayoutConstraint.activate([
            floatingControl.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            floatingControl.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            floatingControl.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 16),
            floatingControl.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -16)
        ])

        gallery.floatingControl = floatingControl
        floatingControl.onPrev = { [weak gallery] in gallery?.step(by: -1) }
        floatingControl.onNext = { [weak gallery] in gallery?.step(by: 1) }
        gallery.syncFloatingControl()

        // Debug-only hook: `SIMCTL_CHILD_GB_STRESS_ENTRY=<entry-name> xcrun simctl launch ...`
        // presents that entry immediately on launch, so a specific gallery entry (e.g. a
        // Stress shape) can be screenshotted from a script without UI automation.
        if let entryName = ProcessInfo.processInfo.environment["GB_STRESS_ENTRY"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak gallery] in
                gallery?.presentEntry(named: entryName)
            }
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }
}



// MARK: - FONTS
class FontHelper {
    static func create(name font: String?, withSize size: CGFloat) -> UIFont {
        if let fontName = font,
           let font: UIFont = UIFont(name: fontName, size: size) {
            return font
        } else {
            return UIFont.systemFont(ofSize: size)
        }
    }

    enum DMSans {
        case regular
        case medium
        case italic
        case mediumItalic
        case bold
        case boldItalic
    }

    enum OpenSans {
        case regular
        case medium
        case italic
        case mediumItalic
        case bold
        case boldItalic
        case semiBold
        case semiBoldItalic
        case extraBold
        case extraBoldItalic
        case light
        case lightItalic
    }

    enum MuseoSans {
        case extraBold
    }

    enum Campton {
        case bold
        case light
        case lightItalic
        case medium
        case regular
        case regularItalic
    }

    struct DMSansName {
        static let regular = "DMSans-Regular"
        static let medium = "DMSans-Medium"
        static let italic = "DMSans-Italic"
        static let mediumItalic = "DMSans-MediumItalic"
        static let bold = "DMSans-Bold"
        static let boldItalic = "DMSans-BoldItalic"
    }

    struct OpenSansName {
        static let regular = "OpenSans-Regular"
        static let medium = "OpenSans-Medium"
        static let italic = "OpenSans-Italic"
        static let mediumItalic = "OpenSans-MediumItalic"
        static let bold = "OpenSans-Bold"
        static let boldItalic = "OpenSans-BoldItalic"
        static let semiBold = "OpenSans-SemiBold"
        static let semiBoldItalic = "OpenSans-SemiBoldItalic"
        static let extraBold = "OpenSans-ExtraBold"
        static let extraBoldItalic = "OpenSans-ExtraBoldItalic"
        static let light = "OpenSans-Light"
        static let lightItalic = "OpenSans-LightItalic"
    }
}

extension FontHelper.DMSans {
    func font(_ size: CGFloat) -> UIFont {
        switch (self) {
        case .regular: return FontHelper.create(name: "DMSans-Regular", withSize: size)
        case .medium: return FontHelper.create(name: "DMSans-Medium", withSize: size)
        case .italic: return FontHelper.create(name: "DMSans-Italic", withSize: size)
        case .mediumItalic: return FontHelper.create(name: "DMSans-MediumItalic", withSize: size)
        case .bold: return FontHelper.create(name: "DMSans-Bold", withSize: size)
        case .boldItalic: return FontHelper.create(name: "DMSans-BoldItalic", withSize: size)
        }
    }

    func font(_ f: UIFont) -> UIFont {
        font(f.pointSize)
    }
}

extension FontHelper.OpenSans {
    func font(_ size: CGFloat) -> UIFont {
        switch (self) {
        case .regular: return FontHelper.create(name: "OpenSans-Regular", withSize: size)
        case .medium: return FontHelper.create(name: "OpenSans-Medium", withSize: size)
        case .italic: return FontHelper.create(name: "OpenSans-Italic", withSize: size)
        case .mediumItalic: return FontHelper.create(name: "OpenSans-MediumItalic", withSize: size)
        case .bold: return FontHelper.create(name: "OpenSans-Bold", withSize: size)
        case .boldItalic: return FontHelper.create(name: "OpenSans-BoldItalic", withSize: size)
        case .semiBold: return FontHelper.create(name: "OpenSans-SemiBold", withSize: size)
        case .semiBoldItalic: return FontHelper.create(name: "OpenSans-SemiBoldItalic", withSize: size)
        case .extraBold: return FontHelper.create(name: "OpenSans-ExtraBold", withSize: size)
        case .extraBoldItalic: return FontHelper.create(name: "OpenSans-ExtraBoldItalic", withSize: size)
        case .light: return FontHelper.create(name: "OpenSans-Light", withSize: size)
        case .lightItalic: return FontHelper.create(name: "OpenSans-LightItalic", withSize: size)
        }
    }

    func font(_ f: UIFont) -> UIFont {
        font(f.pointSize)
    }
}

extension FontHelper.MuseoSans {
    func ofSize(_ size: CGFloat) -> UIFont {
        var fontName: String
        switch self {
        case .extraBold:
            fontName = "MuseoSansW01-900"
        }

        return FontHelper.create(name: fontName, withSize: size)
    }
}

extension FontHelper.Campton {
    func ofSize(_ size: CGFloat) -> UIFont {
        var fontName: String
        switch self {
        case .bold:
            fontName = "Campton-Bold"
        case .light:
            fontName = "Campton-Light"
        case .lightItalic:
            fontName = "Campton-LightItalic"
        case .medium:
            fontName = "Campton-Medium"
        case .regular:
            fontName = "Campton-Book"
        case .regularItalic:
            fontName = "Campton-BookItalic"
        }

        return FontHelper.create(name: fontName, withSize: size)
    }

    @available(*, message: "Please use `ofSize` instead")
    func font(_ size: CGFloat) -> UIFont {
        self.ofSize(size)
    }
}


extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        self.init(alpha: 255, red: red, green: green, blue: blue)
    }

    convenience init(alpha: Int, red: Int, green: Int, blue: Int) {
        assert(alpha >= 0 && alpha <= 255, "Invalid alpha component")
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: CGFloat(alpha) / 255.0)
    }

    convenience init(netHex: Int) {
        self.init(red: (netHex >> 16) & 0xff, green: (netHex >> 8) & 0xff, blue: netHex & 0xff)
    }

    convenience init(argbHex hex: Int) {
        self.init(alpha: (hex >> 24) & 0xff, red: (hex >> 16) & 0xff, green: (hex >> 8) & 0xff, blue: hex & 0xff)
    }

    struct Custom {
        static let primary = UIColor(named: "primary") ?? UIColor(netHex: 0x28ABE1)
        static let accentSecondary = UIColor(named: "accent-secondary") ?? UIColor(netHex: 0xF7A440)
        static let accentSecondaryDark = UIColor(named: "bright-orange-new") ?? UIColor(netHex: 0xF7941E)
        static let accentSecondaryLight = UIColor(named: "accent-secondary-light") ?? UIColor(netHex: 0xFCC412)
        static let accentTernary = UIColor(named: "accent-ternary") ?? UIColor(netHex: 0x5148D1)
        static let invertAccentTernary = UIColor(netHex: 0xD8D8D8)
        static let textPrimary = UIColor(named: "text-primary") ?? UIColor(netHex: 0x156E94)
        static let textPrimaryDark = UIColor(named: "text-primary-dark") ?? UIColor(netHex: 0x333333)
        static let textPrimaryDarkMedium = UIColor(netHex: 0x888888)
        static let backgroundDark = UIColor(named: "background-dark") ?? UIColor(netHex: 0x333333)
        static let backgroundDark1 = UIColor(netHex: 0x222222)
        static let backgroundLight = UIColor(named: "background-light") ?? UIColor(netHex: 0xFCFDFF)
        static let backgroundPrimary = UIColor(named: "primary-light") ?? UIColor(netHex: 0xF4FAFD)
        static let backgroundFieldDisabled = UIColor(netHex: 0xF8F8F8)
        static let backgroundButtonDisabled = UIColor(netHex: 0xC2C2C2)
        static let borderLight = UIColor(named: "border-color") ?? UIColor(netHex: 0xB4B4B4)
        static let borderDark = UIColor(netHex: 0x707070)
        static let borderAccentTernary = UIColor(netHex: 0x817CE1)
        static let borderAccentTernaryDisabled = UIColor(netHex: 0xC2BFEF)
        static let titleTextTitlePrimary = UIColor(named: "text-title-primary") ?? UIColor(netHex: 0xF1F2F2)
        static let buttonDisableLight = UIColor(named: "button-disable-light") ?? UIColor(netHex: 0xF5F5F5)
        static let labelSubtitle = UIColor(named: "label-subtitle") ?? UIColor(netHex: 0x515151)
        static let labelSubtitleVariant1 = UIColor(netHex: 0x707070)
        static let labelSubtitleVariant2 = UIColor(netHex: 0x8D8E92)
        static let dropShadow = UIColor(argbHex: 0x29000000)
        static let dropShadowLight = UIColor(argbHex: 0x124B8E29)
        static let backgroundGrey = UIColor(named: "grey_light") ?? UIColor(netHex: 0xEDF1F8)
        static let dangerVariant1 = UIColor(netHex: 0xDD6E6E)
        static let backgroundDisabled = UIColor(named: "disabledBackground") ?? UIColor(netHex: 0xEFEFEF)
        static let titleTextTitlePrimary1 = UIColor(netHex: 0xF1F2F3)
        static let chatBoxBackground = UIColor(netHex: 0xF7F7F7)
        static let chatBoxBorder = UIColor(netHex: 0xF0F0F0)
        static let networkErrorBackground = UIColor(netHex: 0xFEE79C)
        static let worksheetPrimary = UIColor(argbHex: 0xFF262262)
        static let worksheetQuestionListText = UIColor(netHex: 0x110E3E)
        static let worksheetQuestionListCorrect = UIColor(netHex: 0x76C48E)
        static let worksheetQuestionListSubmitted = UIColor(netHex: 0xD6D3FF)
        static let worksheetQuestionListPullDownBar = UIColor(netHex: 0xBCD6E1)
        static let worksheetMCQRadioBackground = UIColor(netHex: 0x166F94)
        static let genieAskFailedMessageIcon = UIColor(netHex: 0xED4444)
        static let canvasBlack = UIColor(netHex: 0x000000)
        static let canvasWhite = UIColor(netHex: 0xFFFFFF)
        static let canvasOrange = UIColor(netHex: 0xFF9C16)
        static let canvasGreen = UIColor(netHex: 0x54B87E)
        static let canvasBlue = UIColor(netHex: 0x3B92F8)
        static let canvasMagenta = UIColor(netHex: 0xB42775)
        static let transparentBackground = UIColor(alpha: 24, red: 0, green: 0, blue: 0)
        static let settingsGreyBackground = UIColor(netHex: 0xEEEFF1)
        static let settingsGreyDividerLine = UIColor(netHex: 0xCDCDCF)
        static let settingsSwitchActive = UIColor(netHex: 0x34C759)
        static let settingsSwitchInactive = UIColor(argbHex: 0x78788029)
        static let warningNotification = UIColor(netHex: 0xDD6E6E)
        static let midnightBlue = UIColor(netHex: 0x110E3E) // Name comes from https://colors.dopely.top/color-pedia/110E3E
        static let streakMissedLabel = UIColor(netHex: 0xFED00B)
        static let streakInactiveLabel = UIColor(netHex: 0x39578F)
        static let streakDoneColor = UIColor(netHex: 0x54B87E)
        static let buttonDisabled = UIColor(netHex: 0xC2C2C2)
        static let submitExamResultReward = UIColor(netHex: 0x27AAE1)
        static let submitExamResultRewardContainer = UIColor(netHex: 0xE9F7FC)
        static let examResultPendingStateContainer = UIColor(netHex: 0xFEF4E9)
        static let examResultApprovedState = UIColor(netHex: 0x439365)
        static let examResultApprovedStateContainer = UIColor(netHex: 0xEEF8F2)
        static let genieClassLeaveClassRed = UIColor(netHex: 0xF55C42)
        static let genieClassLiveRed = UIColor(netHex: 0xF55C42)
        static let genieClassSmallClassBlue = UIColor(netHex: 0x335693)
        static let classReportImproved = UIColor(netHex: 0x335693)
        static let worksheetCompletionPageBubbleReward = UIColor(netHex: 0x555555)
        static let worksheetCompletionPageBubbleRewardNote = UIColor.init(white: 1, alpha: 0.8)
        static let worksheetCompletionBackgroundNotes = UIColor(netHex: 0xFFF7EB)
        static let genieClassPopExitBackground = UIColor(netHex: 0x4B496E)
        static let genieClassAlertBackground = UIColor(netHex: 0xFDE5E5)
        static let geniePostQuizPeek = UIColor(netHex: 0x79A25C)
        static let onlineClassAlertPeek = UIColor(netHex: 0xD86D6D)
        static let genieclassFreeTrialBlocker = UIColor(netHex: 0xEEEEF0)
        static let tooltipBackground = UIColor(argbHex: 0xFF323233)
        static let scrollThumbColor = UIColor(argbHex: 0xFF6C63FF)
        static let GBPNavy = UIColor(netHex: 0x262262)
        static let overlay80 = UIColor(argbHex: 0x80000000)
        static let onlineLessonResult = UIColor(netHex: 0xC8EBFA)
        static let onlineLessonQuizSelected = UIColor(netHex: 0x43BDF2)
        static let formFieldError = UIColor(netHex: 0xC54A47)
        static let formFieldBorderNormal = UIColor(netHex: 0xCFD7E5)

        /**
         Color Name  Reference V0: https://www.color-name.com/hex/e57b42#color-palettes
         */
        static let orangeMandarin = UIColor(netHex: 0xE57B41)
        static let darkSlateBlue = UIColor(netHex: 0x414188)
        static let blueYonder = UIColor(netHex: 0x496DAE)
        static let azureishWhite = UIColor(netHex: 0xDCE4F3)
        static let peachOrange = UIColor(netHex: 0xFCC898)
        static let lightGray = UIColor(netHex: 0xD5D5D5)
        static let blueCrayola = UIColor(netHex: 0x1E82F7)
        static let ghostWhite = UIColor(netHex: 0xFAFBFD)
        static let darkCornflowerBlue = UIColor(netHex: 0x333F8B)
        static let coralReef = UIColor(netHex: 0xF77767)
        static let americanBlue = UIColor(netHex: 0x3E3A6E)
    }
}

extension UIStackView {
    // MARK: Manipulate Subview
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach {
            removeArrangedSubViewProperly($0)
        }
    }

    @discardableResult
    func removeArrangedSubViewProperly(_ view: UIView) -> UIView {
        removeArrangedSubview(view)
        NSLayoutConstraint.deactivate(view.constraints)
        view.removeFromSuperview()
        return view
    }

    func removeAllArrangedSubviewsSafe() {
        arrangedSubviews.forEach {
            removeArrangedSubViewProperlySafe($0)
        }
    }

    @discardableResult
    func removeArrangedSubViewProperlySafe(_ view: UIView) -> UIView {
        removeArrangedSubview(view)
        view.removeFromSuperview()
        return view
    }

    func addArrangedSubview(_ view: UIView?) {
        guard let view = view else {
            return
        }

        addArrangedSubview(view)
    }
}

extension UIImage {
    @MainActor
    func tinted(color: UIColor) -> UIImage? {
        let image = withRenderingMode(.alwaysTemplate)
        let imageView = UIImageView(image: image)
        imageView.tintColor = color

        UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0)
        if let context = UIGraphicsGetCurrentContext() {
            imageView.layer.render(in: context)
            let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return tintedImage
        } else {
            return self
        }
    }
}

struct V1WidgetFactory {
    static func createIconText(icon attachment: NSTextAttachment?, text: String, attributes attrs: [NSAttributedString.Key: Any]? = nil, space: String = "  ", isLeftPosition: Bool = true) -> NSAttributedString {
        let attributes = ([
            NSAttributedString.Key.foregroundColor: UIColor.Custom.accentSecondary,
            NSAttributedString.Key.font: FontHelper.DMSans.bold.font(16),
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
        ]).merging(attrs ?? [:]) {
            (_, new) in
            new
        }
        return createIconTextRaw(icon: attachment, text: text, attributes: attributes, space: space, isLeftPosition: isLeftPosition)
    }

    static func createIconTextRaw(icon attachment: NSTextAttachment?, text: String, attributes attrs: [NSAttributedString.Key: Any]? = nil, space: String = "  ", isLeftPosition: Bool = true) -> NSAttributedString {
        let imageText: NSAttributedString? = attachment?.image == nil ? nil : NSMutableAttributedString(attachment: attachment!)
        let urlText = NSMutableAttributedString(
                string: "\(text)",
                attributes: attrs
        )

        let fullText = NSMutableAttributedString()
        if isLeftPosition {
            if let imageText = imageText {
                fullText.append(imageText)
                fullText.append(NSAttributedString(string: space))
            }
        }
        fullText.append(urlText)
        if !isLeftPosition {
            if let imageText = imageText {
                fullText.append(NSAttributedString(string: space))
                fullText.append(imageText)
            }
        }
        return fullText
    }
}

extension UIButton {
    func makeBottomRightShadow(of color: UIColor) {
        layer.shadowColor = color.cgColor
        layer.shadowRadius = 1
        layer.shadowOffset = CGSize(width: 1, height: 1)
        layer.shadowOpacity = 0.4
        layer.masksToBounds = false
    }
}


extension UIColor {
    static var random: UIColor {
        .init(hue: .random(in: 0...1), saturation: 1, brightness: 1, alpha: 1)
    }
}

extension Array {
    subscript(safeIndex index: Int) -> Element? {
        if isSafe(index: index) {
            return self[index]
        } else {
            return nil
        }
    }

    @inlinable func isSafe(index: Int) -> Bool {
        index >= 0 && index < endIndex
    }
}

extension UICollectionViewCell {
    static var reuseIdentifier: String {
        String(describing: Self.self)
    }
}

extension String {
    var localized: String {
        self
    }
}

extension UIEdgeInsets {
    init(vertical: CGFloat, horizontal: CGFloat) {
        self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    init(all: CGFloat) {
        self.init(top: all, left: all, bottom: all, right: all)
    }
}

@MainActor
enum AppCompatHelper {
    static weak var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })
    }
}

struct Colors {
    //MARK: - NEW
    static let text_primary_new: UIColor = #colorLiteral(red: 0.1607843137, green: 0.1607843137, blue: 0.1607843137, alpha: 1) //#FF292929

    //MARK: - FROM ANDROID
    //static let geniebook_blue: UIColor = #colorLiteral(red: 0.1607843137, green: 0.768627451, blue: 0.9215686275, alpha: 1) //#FF29C4EB
    static let geniebook_blue_sky: UIColor = #colorLiteral(red: 0.3882352941, green: 0.7568627451, blue: 0.9137254902, alpha: 1) //#FF63C1E9
    static let geniebook_blue_pressed: UIColor = #colorLiteral(red: 0.0313725490196078, green: 0.549019607843137, blue: 0.654901960784314, alpha: 1.0) //#FF088CA7
    static let geniebook_blue_opac_90: UIColor = #colorLiteral(red: 0.0431372549019608, green: 0.686274509803922, blue: 0.819607843137255, alpha: 0.898039215686275) //#E50BAFD1
    static let geniebook_blue_opac_90_pressed: UIColor = #colorLiteral(red: 0.0313725490196078, green: 0.549019607843137, blue: 0.654901960784314, alpha: 0.898039215686275) //#E5088CA7
    static let geniebook_pink: UIColor = #colorLiteral(red: 0.7058823529, green: 0.1529411765, blue: 0.4588235294, alpha: 1) //#FFB42775

    //static let geniebook_blue_dark: UIColor = #colorLiteral(red: 0.270588235294118, green: 0.435294117647059, blue: 0.670588235294118, alpha: 1.0) //#FF456FAB
    static let geniebook_blue_navy: UIColor = #colorLiteral(red: 0.1490196078, green: 0.1333333333, blue: 0.3843137255, alpha: 1) //#FF262262
    static let white: UIColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1) //#FFFFFFFF
    static let black: UIColor = #colorLiteral(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0) //#FF000000
    //static let primary_light: UIColor = #colorLiteral(red: 0.494117647058824, green: 0.847058823529412, blue: 0.972549019607843, alpha: 1.0) //#FF7ED8F8
    //static let primary: UIColor = #colorLiteral(red: 0.16078431372549, green: 0.768627450980392, blue: 0.92156862745098, alpha: 1.0) //#FF29C4EB
    //static let primary_dark: UIColor = #colorLiteral(red: 0.0313725490196078, green: 0.549019607843137, blue: 0.654901960784314, alpha: 1.0) //#FF088CA7
    //static let accent: UIColor = #colorLiteral(red: 0.16078431372549, green: 0.768627450980392, blue: 0.92156862745098, alpha: 1.0) //#FF29C4EB
    //static let accent_secondary: UIColor = #colorLiteral(red: 0.270588235294118, green: 0.435294117647059, blue: 0.670588235294118, alpha: 1.0) //#FF456FAB

    static let text_primary: UIColor = #colorLiteral(red: 0.3843137255, green: 0.3843137255, blue: 0.3843137255, alpha: 1) //#FF626262
}

// @swiftlint:enable all
