import Foundation

/// The shared content shape of the standard alert family (`AlertDialog`, `PopupDialog`, …): the same
/// fields, plus the `ModalStyle` token that says WHICH preset to draw them with.
///
/// Originally style was descriptor identity (spec D8) — `PopupDialog` exists purely as a
/// content-identical twin of `AlertDialog` registered with different `Properties`. That does not
/// scale: the app has five presets plus per-entry overrides, so type-per-style grows the type count
/// with the DESIGN SYSTEM. `style` below is the extensible replacement; both renderers key their
/// style→`Properties` map by it. `PopupDialog` is retained for source compatibility.
///
/// `style` lives HERE, on the protocol, rather than only on the concrete `AlertDialog`, because
/// `SwiftUIModalRenderer.registerStandard` is generic over `D: StandardAlertContent` and must read
/// the token where `D` is still abstract. Putting it on the protocol keeps that lookup STATIC —
/// neither renderer casts a descriptor at `present` time, and both read the token identically,
/// which is what makes the parity gate meaningful.
public protocol StandardAlertContent {
    var image: ModalImage? { get }
    var title: AttributedString? { get }
    var subtitle: AttributedString? { get }
    /// **Optional, so a descriptor can say "no primary button" — the shape the gallery could not
    /// reach.** It was a non-optional `String`, which made six stress twins and the
    /// `showsPrimary` divergence structurally unreachable through the descriptor path on EITHER
    /// backend: the UIKit gallery had to build a `DataHolder` with `primaryAction: nil` by hand.
    ///
    /// `DataHolder.primaryAction` was already `String?`, so nothing on the UIKit side changed to
    /// accept this — `nil` flows straight through to `resolve`, which reports `showsPrimary` false,
    /// which `buildActionComponents` has always obeyed.
    ///
    /// Spelling it `""` is NOT the same thing and never was: `showsPrimary` tests for `nil`, so an
    /// empty string draws an EMPTY BUTTON.
    var primary: String? { get }
    var secondary: String? { get }
    var closeOnTapOverlay: Bool { get }
    var showCloseButton: Bool { get }
    /// Optional per-call overrides. `nil` preserves the selected preset's configuration.
    var primaryButtonStyle: ModalButtonStyle? { get }
    var secondaryButtonStyle: ModalButtonStyle? { get }
    var buttonOrientation: ModalButtonOrientation? { get }
    /// The style preset this descriptor asks for. Renderers resolve it through their own
    /// style→`Properties` map and fall back to `.standard` when it is unregistered.
    var style: ModalStyle { get }
}

public extension StandardAlertContent {
    var primaryButtonStyle: ModalButtonStyle? { nil }
    var secondaryButtonStyle: ModalButtonStyle? { nil }
    var buttonOrientation: ModalButtonOrientation? { nil }
}
