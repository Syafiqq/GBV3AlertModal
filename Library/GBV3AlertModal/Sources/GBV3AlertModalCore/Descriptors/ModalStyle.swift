import Foundation

/// A named STYLE PRESET a descriptor asks to be rendered with. The token is framework-neutral and
/// carries no styling itself — each renderer maps it to a `GBAlertModal.Properties` (see
/// `UIKitModalRenderer.register(style:properties:)` and its `SwiftUIModalRenderer` twin).
///
/// **Why a String wrapper and not an enum.** The presets are defined by the CONSUMING APP, not by
/// this library: the real Geniebook app ships five (`properties`, `popupProperties`,
/// `badgeProperties`, `streakModalProperties`, `permissionAlertProperties`) plus per-call-site
/// overrides (an oblique-red "leave class" theme, a custom `ComponentSpace` on badge-detail, custom
/// padding on the input dialogs). A closed enum would force a library change for every new app
/// preset, and the alternative — one descriptor TYPE per style, which is what `PopupDialog` is —
/// grows the type count with the DESIGN SYSTEM rather than with the content shape. Modelled on
/// `ModalImage` (`Core/ModalDescriptor.swift`), which wraps an asset name for the same reason:
/// `Core/` may not reference UIKit or SwiftUI, so it can only ever carry a NAME.
///
/// `Hashable` because both renderers key their style→`Properties` map by it.
///
/// Extend it from the app side, exactly like `ModalImage`:
/// ```swift
/// extension ModalStyle {
///     static let badge = ModalStyle("badge")
///     static let streak = ModalStyle("streak")
///     static let permissionAlert = ModalStyle("permissionAlert")
/// }
/// ```
public struct ModalStyle: Sendable, Hashable {
    /// The registration key. Two `ModalStyle`s are the same style iff their names match, so a
    /// consumer's `ModalStyle("badge")` and the renderer's `register(style: .badge, …)` line up
    /// without either side importing the other's declaration.
    public let name: String

    public init(_ name: String) {
        self.name = name
    }

    /// The default preset — what every `AlertDialog` carries unless told otherwise, and the entry
    /// both renderers FALL BACK to when a descriptor names a style nobody registered.
    /// Seeded from `init(alertProperties:…)`, so it is always present.
    public static let standard = ModalStyle("standard")

    /// The banner-popup preset. Seeded from `init(…popupProperties:)` when that argument is
    /// non-nil, and the style `PopupDialog` carries.
    public static let popup = ModalStyle("popup")
}
