import Foundation

/// The shared content shape of the standard alert family (`AlertDialog`, `PopupDialog`, …): the same
/// fields, differing only in STYLE (spec D8 — style is descriptor identity, not per-call content).
/// One `DataHolder` mapping (`UIKitModalRenderer.AlertHolder.make`) serves every conformer; each
/// descriptor type is registered with its own `Properties`, which is what makes it a "popup" vs an
/// "alert".
public protocol StandardAlertContent {
    var image: ModalImage? { get }
    var title: AttributedString? { get }
    var subtitle: AttributedString? { get }
    var primary: String { get }
    var secondary: String? { get }
    var closeOnTapOverlay: Bool { get }
    var showCloseButton: Bool { get }
}
