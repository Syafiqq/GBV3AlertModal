import Foundation
import SwiftUI

/// **`GBAlertModal.Properties`' vocabulary, in SwiftUI's language — a parallel type, not a
/// translation layer.**
///
/// Same field names, same concepts, same nesting, so a call site moving off the UIKit backend
/// recognises every line and only the types change (spec §3a). Nothing converts at runtime and
/// neither side imports the other: `Properties` keeps taking `UIColor`/`UIFont`/`UIEdgeInsets`
/// because the UIKit renderer is frozen and the app depends on it (§6a), and this takes
/// `Color`/`ModalFont`/`EdgeInsets`. Both derive the SAME `ModalTokens`, which is where the two
/// paths meet — see `ModalTokens.init(from: ModalProperties)` and the equivalence test that pins
/// the two derivations against each other.
///
/// ## What is deliberately different, and why
///
/// - **`bannerFixedHeight` is NOT carried over.** Measured inert on BOTH UIKit paths at every size
///   tried (`BannerGeometryTruthTests.test_bannerFixedHeight_isInert_*`): it loses to hugging (250)
///   going up and to compression resistance (750) coming down, and nothing lays out with it. It is
///   dead vocabulary and this type should never have it. It stays on `Properties`, public and
///   working, because removing it there is a source break for a consumer this repo cannot edit.
/// - **`padding` reuses `UIMinMaxEdgeInsets`.** SwiftUI has no min/max inset type, so this one is
///   genuinely ours either way — it is `import Foundation`, eight `let CGFloat`s, already
///   `Sendable`. The `UI` prefix is a misnomer it has carried since before this work; renaming it
///   would be a source break on a public type for a cosmetic gain.
/// - **`shadowColor`, `borderColor`, `borderDisableColor` become `Color?`, not `CGColor?`.**
///   `CGColor` is CoreGraphics rather than UIKit so it could have been kept, but a SwiftUI caller
///   writing one colour as `Color` and the next as `CGColor` is exactly the seam this type exists
///   to remove.
///
/// ## What is deliberately the SAME, including the parts nothing draws
///
/// All FOUR `ActionStyle` cases are carried, though `ModalButtonStyles` implements only two shapes
/// and `ModalTokens` reads colours from `.obliqueBottomLeft` (primary) and `.plain` (secondary)
/// alone. A consumer shipping `.capsule` on this backend already gets the oblique look — a recorded
/// spec-D8 decision pinned by `test_accentColors_keepStandardLiterals_whenActionStyleIsNotOblique`.
///
/// Dropping the two unread cases was considered and rejected. `bannerFixedHeight` earned its
/// omission with a measurement showing it does nothing *on UIKit's own path*; `.capsule` is inert
/// only because the SwiftUI RENDERER has not implemented it. Carrying two cases would bake a
/// renderer gap into the vocabulary and silently narrow what a migrating call site can say, which
/// is the opposite of this type's job.
public struct ModalProperties: Sendable {
    public static var `default`: Self { Self() }

    public var baseTint: Color?
    public var overlayColor: Color?
    public var contentProperty: ContentProperty?

    public var margin: EdgeInsets?
    public var padding: UIMinMaxEdgeInsets?

    public var bannerRatio: CGFloat?
    public var bannerMaxHeight: CGFloat?
    public var titleFont: ModalFont?
    public var titleColor: Color?
    public var subtitleFont: ModalFont?
    public var subtitleColor: Color?
    public var buttonActionShouldMatchParent: Bool?
    /// `SwiftUI.Axis`, where `Properties` has `NSLayoutConstraint.Axis`. The resolver keeps speaking
    /// UIKit's — it must, `UIStackView.axis` takes exactly that type — and the translation happens
    /// at the one boundary that already bridges it (`ModalAxisBridge`).
    public var buttonActionOrientation: Axis?
    public var primaryActionStyle: ActionStyle?
    public var secondaryActionStyle: ActionStyle?

    public var closeButtonTint: Color?

    public var space: ComponentSpace?

    public init(
        baseTint: Color? = nil,
        overlayColor: Color? = nil,
        contentProperty: ContentProperty? = nil,
        margin: EdgeInsets? = nil,
        padding: UIMinMaxEdgeInsets? = nil,
        bannerRatio: CGFloat? = nil,
        bannerMaxHeight: CGFloat? = nil,
        titleFont: ModalFont? = nil,
        titleColor: Color? = nil,
        subtitleFont: ModalFont? = nil,
        subtitleColor: Color? = nil,
        buttonActionShouldMatchParent: Bool? = false,
        buttonActionOrientation: Axis? = nil,
        primaryActionStyle: ActionStyle? = nil,
        secondaryActionStyle: ActionStyle? = nil,
        closeButtonTint: Color? = nil,
        space: ComponentSpace? = nil
    ) {
        self.baseTint = baseTint
        self.overlayColor = overlayColor
        self.contentProperty = contentProperty
        self.margin = margin
        self.padding = padding
        self.bannerRatio = bannerRatio
        self.bannerMaxHeight = bannerMaxHeight
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.subtitleFont = subtitleFont
        self.subtitleColor = subtitleColor
        self.buttonActionShouldMatchParent = buttonActionShouldMatchParent
        self.buttonActionOrientation = buttonActionOrientation
        self.primaryActionStyle = primaryActionStyle
        self.secondaryActionStyle = secondaryActionStyle
        self.closeButtonTint = closeButtonTint
        self.space = space
    }
}

// MARK: - Nested vocabulary

public extension ModalProperties {
    /// `GBAlertModal.ContentProperty`, with `Color` for the background.
    ///
    /// Nested here rather than shared, even though only ONE of its seven fields is UIKit-typed: the
    /// UIKit one is nested inside `GBAlertModal` — a `UIView` subclass — so sharing it would make a
    /// SwiftUI caller spell `GBAlertModal.ContentProperty`. Same field names, so the two read
    /// identically at a call site.
    struct ContentProperty: Sendable, Equatable {
        public static var `default`: Self { Self() }

        public var backgroundColor: Color?
        public var cornerRadius: CGFloat
        public var fixedWidthPortrait: CGFloat?
        public var maxWidthPortrait: CGFloat?
        public var fixedWidthLandscape: CGFloat?
        public var maxWidthLandscape: CGFloat?
        public var childShouldMatchParent: Bool

        public init(
            backgroundColor: Color? = nil,
            cornerRadius: CGFloat = .zero,
            fixedWidthPortrait: CGFloat? = nil,
            maxWidthPortrait: CGFloat? = nil,
            fixedWidthLandscape: CGFloat? = nil,
            maxWidthLandscape: CGFloat? = nil,
            childShouldMatchParent: Bool = false
        ) {
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.fixedWidthPortrait = fixedWidthPortrait
            self.maxWidthPortrait = maxWidthPortrait
            self.fixedWidthLandscape = fixedWidthLandscape
            self.maxWidthLandscape = maxWidthLandscape
            self.childShouldMatchParent = childShouldMatchParent
        }
    }

    /// `GBAlertModal.ComponentSpace` — four `CGFloat`s, so nothing here needed retyping. Nested for
    /// the same spelling reason `ContentProperty` is.
    struct ComponentSpace: Sendable, Equatable {
        public static var zero: Self { Self() }

        public var banner: CGFloat
        public var title: CGFloat
        public var subtitle: CGFloat
        public var interButton: CGFloat

        public init(
            banner: CGFloat = .zero,
            title: CGFloat = .zero,
            subtitle: CGFloat = .zero,
            interButton: CGFloat = .zero
        ) {
            self.banner = banner
            self.title = title
            self.subtitle = subtitle
            self.interButton = interButton
        }
    }

    /// `GBAlertModal.ActionStyle`, all four cases. See the type's doc for why the two the SwiftUI
    /// renderer cannot draw are carried anyway.
    enum ActionStyle: Sendable, Equatable {
        case capsule(CapsuleTheme)
        case capsuleOutlined(CapsuleOutlineTheme)
        case plain(PlainTheme)
        case obliqueBottomLeft(ObliqueBottomLeftTheme)
    }
}

public extension ModalProperties.ActionStyle {
    struct CapsuleTheme: Sendable, Equatable {
        public var backgroundColor: Color?
        public var backgroundDisableColor: Color?
        public var titleColor: Color?
        public var titleDisableColor: Color?
        public var titleFont: ModalFont?

        public init(
            backgroundColor: Color? = nil,
            backgroundDisableColor: Color? = nil,
            titleColor: Color? = nil,
            titleDisableColor: Color? = nil,
            titleFont: ModalFont? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.backgroundDisableColor = backgroundDisableColor
            self.titleColor = titleColor
            self.titleDisableColor = titleDisableColor
            self.titleFont = titleFont
        }
    }

    struct CapsuleOutlineTheme: Sendable, Equatable {
        public var backgroundColor: Color?
        public var backgroundDisableColor: Color?
        public var titleColor: Color?
        public var titleDisableColor: Color?
        public var borderWidth: CGFloat?
        public var borderColor: Color?
        public var borderDisableColor: Color?
        public var titleFont: ModalFont?

        public init(
            backgroundColor: Color? = nil,
            backgroundDisableColor: Color? = nil,
            titleColor: Color? = nil,
            titleDisableColor: Color? = nil,
            borderWidth: CGFloat? = nil,
            borderColor: Color? = nil,
            borderDisableColor: Color? = nil,
            titleFont: ModalFont? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.backgroundDisableColor = backgroundDisableColor
            self.titleColor = titleColor
            self.titleDisableColor = titleDisableColor
            self.borderWidth = borderWidth
            self.borderColor = borderColor
            self.borderDisableColor = borderDisableColor
            self.titleFont = titleFont
        }
    }

    struct PlainTheme: Sendable, Equatable {
        public var titleColor: Color?
        public var titleDisableColor: Color?
        public var titleFont: ModalFont?

        public init(
            titleColor: Color? = nil,
            titleDisableColor: Color? = nil,
            titleFont: ModalFont? = nil
        ) {
            self.titleColor = titleColor
            self.titleDisableColor = titleDisableColor
            self.titleFont = titleFont
        }
    }

    struct ObliqueBottomLeftTheme: Sendable, Equatable {
        public var unPressedColor: Color?
        public var pressedColor: Color?
        public var disabledColor: Color?
        public var shadowColor: Color?
        public var titleColor: Color?
        public var titleDisableColor: Color?
        public var titleFont: ModalFont?

        public init(
            unPressedColor: Color? = nil,
            pressedColor: Color? = nil,
            disabledColor: Color? = nil,
            shadowColor: Color? = nil,
            titleColor: Color? = nil,
            titleDisableColor: Color? = nil,
            titleFont: ModalFont? = nil
        ) {
            self.unPressedColor = unPressedColor
            self.pressedColor = pressedColor
            self.disabledColor = disabledColor
            self.shadowColor = shadowColor
            self.titleColor = titleColor
            self.titleDisableColor = titleDisableColor
            self.titleFont = titleFont
        }
    }
}
