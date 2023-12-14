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
        true
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
public class FontHelper {
    static func create(name font: String?, withSize size: CGFloat) -> UIFont {
        if let fontName = font,
           let font: UIFont = UIFont(name: fontName, size: size) {
            return font
        } else {
            return UIFont.systemFont(ofSize: size)
        }
    }

    public enum DMSans {
        case regular
        case medium
        case italic
        case mediumItalic
        case bold
        case boldItalic
    }

    public enum OpenSans {
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

    public enum SHSans: Int {
        case extraLight = 100
        case light = 200
        case normal = 300
        case regular = 400
        case medium = 500
        case bold = 700
        case heavy = 900
    }

    public enum BeVietnam: Int {
        // @formatter:off
        case thin             = 100
        case thinItalic       = 101
        case extraLight       = 200
        case extraLightItalic = 201
        case light            = 300
        case lightItalic      = 301
        case regular          = 400
        case italic           = 401
        case medium           = 500
        case mediumItalic     = 501
        case semiBold         = 600
        case semiBoldItalic   = 601
        case bold             = 700
        case boldItalic       = 701
        case extraBold        = 800
        case extraBoldItalic  = 801
        case black            = 900
        case blackItalic      = 901
        // @formatter:off
    }
}

public extension FontHelper.DMSans {
    func font(_ size: CGFloat, allowAppOverrides: Bool = true) -> UIFont {
        switch (self) {
        case .regular:         return FontHelper.OpenSans.regular.font(size, allowAppOverrides: allowAppOverrides)
        case .medium:          return FontHelper.OpenSans.medium.font(size, allowAppOverrides: allowAppOverrides)
        case .italic:          return FontHelper.OpenSans.italic.font(size, allowAppOverrides: allowAppOverrides)
        case .mediumItalic:    return FontHelper.OpenSans.mediumItalic.font(size, allowAppOverrides: allowAppOverrides)
        case .bold:            return FontHelper.OpenSans.bold.font(size, allowAppOverrides: allowAppOverrides)
        case .boldItalic:      return FontHelper.OpenSans.boldItalic.font(size, allowAppOverrides: allowAppOverrides)
        default:               return FontHelper.create(name: "null", withSize: size)
        }
    }
}

public extension FontHelper.OpenSans {
    func font(_ size: CGFloat, allowAppOverrides: Bool = true) -> UIFont {
        if allowAppOverrides {
            if false {
                // @formatter:off
                switch (self) {
                case .regular               : return FontHelper.BeVietnam.regular.font(size, allowAppOverrides: false)
                case .medium                : return FontHelper.BeVietnam.medium.font(size, allowAppOverrides: false)
                case .italic                : return FontHelper.BeVietnam.italic.font(size, allowAppOverrides: false)
                case .mediumItalic          : return FontHelper.BeVietnam.mediumItalic.font(size, allowAppOverrides: false)
                case .bold                  : return FontHelper.BeVietnam.bold.font(size, allowAppOverrides: false)
                case .boldItalic            : return FontHelper.BeVietnam.boldItalic.font(size, allowAppOverrides: false)
                case .semiBold              : return FontHelper.BeVietnam.semiBold.font(size, allowAppOverrides: false)
                case .semiBoldItalic        : return FontHelper.BeVietnam.semiBoldItalic.font(size, allowAppOverrides: false)
                case .extraBold             : return FontHelper.BeVietnam.extraBold.font(size, allowAppOverrides: false)
                case .extraBoldItalic       : return FontHelper.BeVietnam.extraBoldItalic.font(size, allowAppOverrides: false)
                case .light                 : return FontHelper.BeVietnam.light.font(size, allowAppOverrides: false)
                case .lightItalic           : return FontHelper.BeVietnam.lightItalic.font(size, allowAppOverrides: false)
                default                     : return FontHelper.create(name: "null", withSize: size)
                // @formatter:on
                }
            } else {
                return font(size, allowAppOverrides: false)
            }
        } else {
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
            default: return FontHelper.create(name: "null", withSize: size)
            }
        }
    }
}

public extension FontHelper.SHSans {
    func font(_ size: CGFloat, allowAppOverrides: Bool = true) -> UIFont {
        switch (self) {
        case .extraLight:   return FontHelper.OpenSans.light.font(size, allowAppOverrides: allowAppOverrides)
        case .light:        return FontHelper.OpenSans.light.font(size, allowAppOverrides: allowAppOverrides)
        case .normal:       return FontHelper.OpenSans.regular.font(size, allowAppOverrides: allowAppOverrides)
        case .regular:      return FontHelper.OpenSans.regular.font(size, allowAppOverrides: allowAppOverrides)
        case .medium:       return FontHelper.OpenSans.medium.font(size, allowAppOverrides: allowAppOverrides)
        case .bold:         return FontHelper.OpenSans.bold.font(size, allowAppOverrides: allowAppOverrides)
        case .heavy:        return FontHelper.OpenSans.extraBold.font(size, allowAppOverrides: allowAppOverrides)
        default:            return FontHelper.create(name: "null", withSize: size)
        }
    }
}

public extension FontHelper.BeVietnam {
    func font(_ size: CGFloat, allowAppOverrides: Bool = true) -> UIFont {
        // @formatter:off
        switch (self) {
        case .thin             : return FontHelper.create(name: "BeVietnamPro-Thin", withSize: size)
        case .thinItalic       : return FontHelper.create(name: "BeVietnamPro-ThinItalic", withSize: size)
        case .extraLight       : return FontHelper.create(name: "BeVietnamPro-ExtraLight", withSize: size)
        case .extraLightItalic : return FontHelper.create(name: "BeVietnamPro-ExtraLightItalic", withSize: size)
        case .light            : return FontHelper.create(name: "BeVietnamPro-Light", withSize: size)
        case .lightItalic      : return FontHelper.create(name: "BeVietnamPro-LightItalic", withSize: size)
        case .regular          : return FontHelper.create(name: "BeVietnamPro-Regular", withSize: size)
        case .italic           : return FontHelper.create(name: "BeVietnamPro-Italic", withSize: size)
        case .medium           : return FontHelper.create(name: "BeVietnamPro-Medium", withSize: size)
        case .mediumItalic     : return FontHelper.create(name: "BeVietnamPro-MediumItalic", withSize: size)
        case .semiBold         : return FontHelper.create(name: "BeVietnamPro-SemiBold", withSize: size)
        case .semiBoldItalic   : return FontHelper.create(name: "BeVietnamPro-SemiBoldItalic", withSize: size)
        case .bold             : return FontHelper.create(name: "BeVietnamPro-Bold", withSize: size)
        case .boldItalic       : return FontHelper.create(name: "BeVietnamPro-BoldItalic", withSize: size)
        case .extraBold        : return FontHelper.create(name: "BeVietnamPro-ExtraBold", withSize: size)
        case .extraBoldItalic  : return FontHelper.create(name: "BeVietnamPro-ExtraBoldItalic", withSize: size)
        case .black            : return FontHelper.create(name: "BeVietnamPro-Black", withSize: size)
        case .blackItalic      : return FontHelper.create(name: "BeVietnamPro-BlackItalic", withSize: size)
        default                : return FontHelper.create(name: "null", withSize: size)
        // @formatter:on
        }
    }
}

public extension UIColor {
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

    convenience init(netHex:Int) {
        self.init(red:(netHex >> 16) & 0xff, green:(netHex >> 8) & 0xff, blue:netHex & 0xff)
    }

    convenience init(argbHex hex :Int) {
        self.init(alpha: (hex >> 24) & 0xff, red:(hex >> 16) & 0xff, green:(hex >> 8) & 0xff, blue:hex & 0xff)
    }
    
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }

    struct Genie {
        public static let primary = GBPNavy
        public static let accentSecondary = UIColor(netHex: 0xF7A440)
        public static let accentSecondaryDark = UIColor(netHex: 0xF7941E)
        public static let accentSecondaryLight = UIColor(netHex: 0xFCC412)
        public static let accentTernary = UIColor(netHex: 0x5148D1)
        public static let invertAccentTernary = UIColor(netHex: 0xD8D8D8)
        public static let textPrimary = UIColor(netHex: 0x156E94)
        public static let textPrimaryDark = UIColor(netHex: 0x333333)
        public static let textPrimaryDarkMedium = UIColor(netHex: 0x888888)
        public static let backgroundDark = textPrimaryDark
        public static let backgroundDark1 = UIColor(netHex: 0x222222)
        public static let backgroundLight = UIColor(netHex: 0xFCFDFF)
        public static let backgroundPrimary = UIColor(netHex: 0xF4FAFD)
        public static let backgroundPrimary1 = UIColor(netHex: 0xF4F7FC)
        public static let backgroundFieldDisabled = UIColor(netHex: 0xF8F8F8)
        public static let backgroundButtonDisabled = UIColor(netHex: 0xC2C2C2)
        public static let borderLight = UIColor(netHex: 0xB4B4B4)
        public static let borderDark = UIColor(netHex: 0x707070)
        public static let borderAccentTernary = UIColor(netHex: 0x817CE1)
        public static let borderAccentTernaryDisabled = UIColor(netHex: 0xC2BFEF)
        public static let titleTextTitlePrimary = UIColor(netHex: 0xF1F2F2)
        public static let buttonDisableLight = UIColor(netHex: 0xF5F5F5)
        public static let labelSubtitle = UIColor(netHex: 0x515151)
        public static let labelSubtitleVariant1 = borderDark
        public static let labelSubtitleVariant2 = UIColor(netHex: 0x8D8E92)
        public static let dropShadow = UIColor(argbHex: 0x29000000)
        public static let dropShadowLight = UIColor(argbHex: 0x124B8E29)
        public static let backgroundGrey = UIColor(netHex: 0xEDF1F8)
        public static let dangerVariant1 = UIColor(netHex: 0xDD6E6E)
        public static let backgroundDisabled = UIColor(netHex: 0xEFEFEF)
        public static let titleTextTitlePrimary1 = UIColor(netHex: 0xF1F2F3)
        public static let chatBoxBackground = UIColor(netHex: 0xF7F7F7)
        public static let chatBoxBorder = UIColor(netHex: 0xF0F0F0)
        public static let networkErrorBackground = UIColor(netHex: 0xFEE79C)
        public static let worksheetPrimary = GBPNavy
        public static let worksheetQuestionListText = UIColor(netHex: 0x110E3E)
        public static let worksheetQuestionListCorrect = UIColor(netHex: 0x76C48E)
        public static let worksheetQuestionListSubmitted = UIColor(netHex: 0xD6D3FF)
        public static let worksheetQuestionListPullDownBar = UIColor(netHex: 0xBCD6E1)
        public static let worksheetMCQRadioBackground = UIColor(netHex: 0x166F94)
        public static let genieAskFailedMessageIcon = UIColor(netHex: 0xED4444)
        public static let canvasBlack = UIColor(netHex: 0x000000)
        public static let canvasWhite = UIColor(netHex: 0xFFFFFF)
        public static let canvasOrange = UIColor(netHex: 0xFF9C16)
        public static let canvasGreen = UIColor(netHex: 0x54B87E)
        public static let canvasBlue = UIColor(netHex: 0x3B92F8)
        public static let canvasMagenta = UIColor(netHex: 0xB42775)
        public static let transparentBackground = UIColor(alpha: 24, red: 0, green: 0, blue: 0)
        public static let settingsGreyBackground = UIColor(netHex: 0xEEEFF1)
        public static let settingsGreyDividerLine = UIColor(netHex: 0xCDCDCF)
        public static let settingsSwitchActive = UIColor(netHex: 0x34C759)
        public static let settingsSwitchInactive = UIColor(argbHex: 0x78788029)
        public static let warningNotification = dangerVariant1
        public static let backgroundWarningNotification = UIColor(alpha: 20, red: 221, green: 110, blue: 110)
        public static let midnightBlue = worksheetQuestionListText
        public static let streakMissedLabel = UIColor(netHex: 0xFED00B)
        public static let streakInactiveLabel = UIColor(netHex: 0x39578F)
        public static let streakDoneColor = canvasGreen
        public static let buttonDisabled = backgroundButtonDisabled
        public static let submitExamResultReward = UIColor(netHex: 0x27AAE1)
        public static let onlineStatusColor = UIColor(netHex: 0x58B17C)
        public static let onlineLessonResult = UIColor(netHex: 0xC8EBFA)
        public static let submitExamResultRewardContainer = UIColor(netHex: 0xE9F7FC)
        public static let examResultPendingStateContainer = UIColor(netHex: 0xFEF4E9)
        public static let examResultApprovedState = UIColor(netHex: 0x439365)
        public static let examResultApprovedStateContainer = UIColor(netHex: 0xEEF8F2)
        public static let genieClassLeaveClassRed = UIColor(netHex: 0xF55C42)
        public static let genieClassLiveRed = genieClassLeaveClassRed
        public static let genieClassSmallClassBlue = UIColor(netHex: 0x335693)
        public static let classReportImproved = genieClassSmallClassBlue
        public static let worksheetCompletionPageBubbleReward = UIColor(netHex: 0x555555)
        public static let worksheetCompletionPageBubbleRewardNote = UIColor.init(white: 1, alpha: 0.8)
        public static let worksheetCompletionBackgroundNotes = UIColor(netHex: 0xFFF7EB)
        public static let genieClassPopExitBackground = UIColor(netHex: 0x4B496E)
        public static let genieClassAlertBackground = UIColor(netHex: 0xFDE5E5)
        public static let geniePostQuizPeek = UIColor(netHex: 0x79A25C)
        public static let onlineClassAlertPeek = UIColor(netHex: 0xD86D6D)
        public static let genieclassFreeTrialBlocker = UIColor(netHex: 0xEEEEF0)
        public static let tooltipBackground = UIColor(argbHex: 0xFF323233)
        public static let scrollThumbColor = UIColor(argbHex: 0xFF6C63FF)
        public static let GBPNavy = UIColor(netHex: 0x262262)
        public static let GBDeepNavy = UIColor(netHex: 0x16133E)
        public static let checkInactiveTint = UIColor(netHex: 0xDCE3EF)
        public static let overlay80 = UIColor(argbHex: 0x80000000)
        public static let onlineLessonQuizSelected = UIColor(netHex: 0x43BDF2)
        public static let formFieldError = UIColor(netHex: 0xC54A47)
        public static let formFieldBorderNormal = UIColor(netHex: 0xCFD7E5)

        /**
         Color Name  Reference V0: https://www.color-name.com/hex/e57b42#color-palettes
         */
        public static let orangeMandarin = UIColor(netHex: 0xE57B41)
        public static let darkSlateBlue = UIColor(netHex: 0x414188)
        public static let blueYonder = UIColor(netHex: 0x496DAE)
        public static let azureishWhite = UIColor(netHex: 0xDCE4F3)
        public static let peachOrange = UIColor(netHex: 0xFCC898)
        public static let lightGray = UIColor(netHex: 0xD5D5D5)
        public static let blueCrayola = UIColor(netHex: 0x1E82F7)
        public static let ghostWhite = UIColor(netHex: 0xFAFBFD)
        public static let darkCornflowerBlue = UIColor(netHex: 0x333F8B)
        public static let coralReef = UIColor(netHex: 0xF77767)
        public static let americanBlue = UIColor(netHex: 0x3E3A6E)
        public static let backgroundBrown = UIColor(netHex: 0x827E7E)
        
        
        public static let yankeesBlue = GBDeepNavy
        public static let mandarin = orangeMandarin
        public static let beer = accentSecondaryDark
        public static let carrotOrange = UIColor(netHex: 0xF79420) // Name comes from https://colors.dopely.top/color-pedia/F79420
        public static let columbiaBlue = formFieldBorderNormal
        public static let batteryChargedBlue = submitExamResultReward
        public static let darkLiver = labelSubtitle
        public static let darkLavender = UIColor(netHex: 0x714E90)
        public static let purpleMountainMajesty = UIColor(netHex: 0x926FB0)
        public static let philippineSilver = borderLight
        public static let venetianRed = formFieldError
        public static let quickSilver = UIColor(netHex: 0xA0A0A0)
        public static let htmlGray = backgroundBrown
        public static let soap = UIColor(netHex: 0xCECDF2)
        public static let aliceBlue = backgroundPrimary1
        public static let veryPaleOrange = UIColor(netHex: 0xFFE2BF)
        public static let water = onlineLessonResult
        public static let brightGray = UIColor(netHex: 0xE5F3F7)
        public static let indigo = GBPNavy
        public static let mediumSeaGreen = UIColor(netHex: 0x48A175)
    }
}

extension UIStackView {
    // MARK: Manipulate Subview
    @discardableResult
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach { removeArrangedSubViewProperly($0) }
    }

    func removeArrangedSubViewProperly(_ view: UIView) -> UIView {
        removeArrangedSubview(view)
        NSLayoutConstraint.deactivate(view.constraints)
        view.removeFromSuperview()
        return view
    }

    @discardableResult
    func removeAllArrangedSubviewsSafe() {
        arrangedSubviews.forEach { removeArrangedSubViewProperlySafe($0) }
    }

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

public extension UIImage {

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

public enum V1WidgetFactory {
    public static func createIconText(icon attachment: NSTextAttachment?, text: String, attributes attrs: [NSAttributedString.Key : Any]? = nil, space: String = "  ", isLeftPosition: Bool = true) -> NSAttributedString {
        let attributes = ([
            NSAttributedString.Key.foregroundColor: UIColor.Genie.accentSecondary,
            NSAttributedString.Key.font: FontHelper.DMSans.bold.font(16),
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
        ]).merging(attrs ?? [:]) {
            (_, new) in new
        }
        return createIconTextRaw(icon: attachment, text: text, attributes: attributes, space: space, isLeftPosition: isLeftPosition)
    }

    public static func createIconTextRaw(icon attachment: NSTextAttachment?, text: String, attributes attrs: [NSAttributedString.Key : Any]? = nil, space: String = "  ", isLeftPosition: Bool = true) -> NSAttributedString {
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

public enum AppCompatHelper {
    public static weak var keyWindow: UIWindow? {
        #if swift(>=5.1)
        if #available(iOS 13, *) {
            return UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow })
        } else {
            return UIApplication.shared.keyWindow
        }
        #else
        return UIApplication.shared.keyWindow
        #endif
    }
}

public struct Colors {
    //MARK: - FROM ANDROID
    public static let geniebook_blue_sky: UIColor = #colorLiteral(red: 0.3882352941, green: 0.7568627451, blue: 0.9137254902, alpha: 1) //#FF63C1E9

    public static let text_primary: UIColor = #colorLiteral(red: 0.3843137255, green: 0.3843137255, blue: 0.3843137255, alpha: 1) //#FF626262
    public static let text_secondary: UIColor = #colorLiteral(red: 0.5529411765, green: 0.5607843137, blue: 0.5764705882, alpha: 1) //#FF8D8F93
    public static let text_label: UIColor = #colorLiteral(red: 0.756862745098039, green: 0.764705882352941, blue: 0.772549019607843, alpha: 1.0) //#FFC1C3C5
    public static let answer_correct: UIColor = #colorLiteral(red: 0.145098039215686, green: 0.686274509803922, blue: 0.282352941176471, alpha: 1.0) //#FF25AF48
    public static let answer_wrong: UIColor = #colorLiteral(red: 0.8745098039, green: 0.2823529412, blue: 0.168627451, alpha: 1) //#FFDF482B
    public static let grey_light: UIColor = #colorLiteral(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.00) //#FFE6E6E6
    public static let grey_dark_extra: UIColor = #colorLiteral(red: 0.129411764705882, green: 0.129411764705882, blue: 0.129411764705882, alpha: 1.0) //#FF212121
    public static let orange: UIColor = #colorLiteral(red: 1.0, green: 0.596078431372549, blue: 0.0, alpha: 1.0) //#FFFF9800
}

// swiftlint:enable all
