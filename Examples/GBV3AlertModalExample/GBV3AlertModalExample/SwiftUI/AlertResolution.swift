import GBV3AlertModal

/// A discrete user interaction with the modal. Pure enum so routing is testable without a view.
enum AlertInteraction {
    case primaryTapped, secondaryTapped, closeTapped, overlayTapped
}

/// Which slots the modal renders, derived purely from the config.
/// Mirrors the library's `ResolvedModal` resolver (the "Layer A" pattern).
struct ResolvedAlert {
    let showsBanner: Bool
    let showsTitle: Bool
    let showsSubtitle: Bool
    let showsSecondary: Bool
    let showsClose: Bool
    let dismissOnOverlayTap: Bool

    init(_ config: AlertDialog) {
        func present(_ s: String?) -> Bool { !(s ?? "").isEmpty }
        showsBanner = config.image != nil
        showsTitle = present(config.title)
        showsSubtitle = present(config.subtitle)
        showsSecondary = present(config.secondary)
        showsClose = config.showCloseButton
        dismissOnOverlayTap = config.closeOnTapOverlay
    }
}

/// The outcome an interaction produces, or `nil` for a no-op (overlay tap when disabled).
func resolve(_ interaction: AlertInteraction, _ config: AlertDialog) -> AlertDialog.Result? {
    switch interaction {
    case .primaryTapped:   return .primary
    case .secondaryTapped: return .secondary
    case .closeTapped:     return .dismissed
    case .overlayTapped:   return config.closeOnTapOverlay ? .dismissed : nil
    }
}
