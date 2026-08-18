import Foundation
import SwiftUI

/// SwiftUI-native configuration for the alert modal.
///
/// This type intentionally models SwiftUI capabilities instead of mirroring
/// `GBAlertModal.Properties`. In particular, banner artwork uses its `Image`'s intrinsic aspect
/// ratio and needs only an optional SwiftUI maximum-height cap.
///
/// ## What is deliberately different, and why
///
/// - UIKit banner ratio and fixed-height constraints are not carried over. They duplicate image
///   metadata or fight SwiftUI's proposal-based layout.
/// - **`padding` reuses `MinMaxEdgeInsets`.** SwiftUI has no min/max inset type, so this one is
///   genuinely platform-neutral: eight `let CGFloat`s, with the UIKit-era spelling retained as a
///   deprecated compatibility alias.
/// - **`shadowColor`, `borderColor`, `borderDisableColor` become `Color?`, not `CGColor?`.**
///   `CGColor` is CoreGraphics rather than UIKit so it could have been kept, but a SwiftUI caller
///   writing one colour as `Color` and the next as `CGColor` is exactly the seam this type exists
///   to remove.
///
/// ## What is deliberately the SAME, including the parts that used to draw nothing
///
/// All FOUR `ActionStyle` cases are carried, and `ModalButtonStyles` now implements all four shapes:
/// `.obliqueBottomLeft` (primary's fixed look) and `.plain` (secondary's fixed look) as before, plus
/// `.capsule`/`.capsuleOutlined` as real `CapsuleButtonStyle`/`CapsuleOutlinedButtonStyle` looks —
/// either slot, whichever one's `ActionStyle` says so (`ModalTokens.primaryCapsule`/
/// `.secondaryCapsule`/`.primaryCapsuleOutlined`/`.secondaryCapsuleOutlined`).
///
/// Dropping the two once-unread cases was considered and rejected when this type was written, for
/// exactly the reason that turned out to matter: `bannerFixedHeight` earned its omission with a
/// measurement showing it does nothing *on UIKit's own path*, but `.capsule` was inert only because
/// the SwiftUI RENDERER had not implemented it yet — carrying it anyway is what made implementing it
/// later (this) an additive change instead of a source break.
public struct ModalProperties: Sendable {
    public static var `default`: Self { Self() }

    public var baseTint: Color?
    public var overlayColor: Color?
    public var contentProperty: ContentProperty?

    public var margin: EdgeInsets?
    public var padding: MinMaxEdgeInsets?

    public var banner: ModalBannerConfiguration?
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
        padding: MinMaxEdgeInsets? = nil,
        banner: ModalBannerConfiguration? = nil,
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
        self.banner = banner
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

// MARK: - The resolver's inputs

/// The SwiftUI vocabulary's half of `ModalStructureInputs` — the same eight projections
/// `GBAlertModal.Properties` supplies, off the same field names. This is the whole of what makes
/// ONE resolver serve both configurations, and therefore the whole of why Pass 3 did not have to
/// give up the "by construction" guarantee the spec expected it to.
extension ModalProperties: ModalStructureInputs {
    public var hasPrimaryActionStyle: Bool { primaryActionStyle != nil }
    public var hasSecondaryActionStyle: Bool { secondaryActionStyle != nil }
    public var buttonsAreHorizontal: Bool { buttonActionOrientation == .horizontal }
    public var buttonsMatchParent: Bool { buttonActionShouldMatchParent == true }
    public var fixedWidthPortrait: CGFloat? { contentProperty?.fixedWidthPortrait }
    public var maxWidthPortrait: CGFloat? { contentProperty?.maxWidthPortrait }
    public var fixedWidthLandscape: CGFloat? { contentProperty?.fixedWidthLandscape }
    public var maxWidthLandscape: CGFloat? { contentProperty?.maxWidthLandscape }
}
