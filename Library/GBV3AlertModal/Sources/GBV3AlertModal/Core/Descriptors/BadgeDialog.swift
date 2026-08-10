import Foundation

/// The badge family: the unlock popups (`BadgesPopUpView`, one badge or many) and the tapped-badge
/// detail popup (`VBadgeListViewController` → `VBadgesItemView`).
///
/// Three real shapes, ONE descriptor, because they differ only in which slots they fill:
///
/// | catalog shape        | `banner` | `subtitle`            | `badges`                  |
/// |----------------------|----------|-----------------------|---------------------------|
/// | `badge-unlock-single`| artwork  | "you unlocked the X!" | the unlocked badge        |
/// | `badge-unlock-multi` | static   | "You unlocked badges."| the unlocked badges       |
/// | `badge-detail-popup` | none     | none                  | the tapped badge + detail |
///
/// **Why this is a descriptor and not an `AlertDialog`.** The badge grid is CONTENT that no
/// `AlertDialog` slot can carry: the real app builds a `VBadgesItemView` (artwork + name +
/// description) at runtime and hands it to `DataHolder.subtitleCustomView`. On the SwiftUI backend
/// that becomes `AlertModalScaffold`'s `@ViewBuilder` slot, filled by `BadgeModalView` — see
/// `SwiftUIModalRenderer+BespokeViews.swift`.
///
/// **D1 invariant.** This type stays a pure `Sendable` value type in `Core/`: it carries badge
/// NAMES and asset NAMES (`ModalImage`), never a `UIImage` and never a view. Every rendering
/// decision lives on the renderer.
public struct BadgeDialog: ModalDescriptor {

    /// One badge, as a value. `artwork` is an asset NAME (`badge.localImageName` in the real app,
    /// which is per-record and resolved at runtime) — the same reason `ModalImage` exists.
    public struct Badge: Sendable, Equatable, Identifiable {
        /// Stable identity for `ForEach`. The real app has a badge id; callers with none can pass
        /// the name.
        public let id: String
        public let name: String
        public let artwork: ModalImage?
        /// The description line shown on the DETAIL popup. `nil` on the unlock popups, which show
        /// artwork + name only.
        public let detail: String?

        public init(id: String, name: String, artwork: ModalImage? = nil, detail: String? = nil) {
            self.id = id
            self.name = name
            self.artwork = artwork
            self.detail = detail
        }
    }

    /// The two real outcomes: "View my badges" (navigates) or dismissed. `Got it` on the detail
    /// popup is the primary button and therefore also `.viewBadges` — the app treats it as an
    /// acknowledgement, and the caller decides what to do with it.
    public enum Result: Sendable, Equatable {
        case viewBadges
        case dismissed
    }
    public static var dismissedResult: Result { .dismissed }

    public var banner: ModalImage?
    public var title: AttributedString?
    public var subtitle: AttributedString?
    /// Empty = no grid (the unlock popups can be banner-only). Non-empty = the grid is drawn below
    /// the subtitle.
    public var badges: [Badge]
    public var primary: String
    public var secondary: String?
    public var closeOnTapOverlay: Bool
    public var showCloseButton: Bool
    /// Which registered preset draws it — `.badge`, the multi variant's taller banner, or the
    /// detail popup's own padding/spacing. Same token both renderers key their preset map by.
    public var style: ModalStyle

    /// ONE initializer, taking `AttributedString?` for both text slots. Deliberately not the
    /// two-overload `String`/`AttributedString` pair `AlertDialog` carries: that pair exists to keep
    /// ~114 legacy `String` call sites source-compatible, and this descriptor has no legacy call
    /// sites to protect. One init means no overload ambiguity to disambiguate.
    public init(
        banner: ModalImage? = nil,
        title: AttributedString? = nil,
        subtitle: AttributedString? = nil,
        badges: [Badge] = [],
        primary: String,
        secondary: String? = nil,
        closeOnTapOverlay: Bool = false,
        showCloseButton: Bool = false,
        style: ModalStyle = .standard
    ) {
        self.banner = banner
        self.title = title
        self.subtitle = subtitle
        self.badges = badges
        self.primary = primary
        self.secondary = secondary
        self.closeOnTapOverlay = closeOnTapOverlay
        self.showCloseButton = showCloseButton
        self.style = style
    }
}
