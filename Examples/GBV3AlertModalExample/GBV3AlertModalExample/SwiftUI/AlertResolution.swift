import Foundation
import GBV3AlertModalCore

/// A discrete user interaction with the modal. Pure enum so routing is testable without a view.
enum AlertInteraction {
    case primaryTapped, secondaryTapped, closeTapped, overlayTapped
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

/// Guards the double-tap / stale-async race: an in-flight async result (e.g. a "generating…"
/// task fired from a primary tap) should only be applied if its captured generation still
/// matches the current one. A later tap, or a dismissal, bumps the generation and supersedes it.
func shouldApply(resultGeneration: Int, currentGeneration: Int) -> Bool {
    resultGeneration == currentGeneration
}

/// No-blink A→B swap (spec D4): given the currently-shown descriptor, the next one to show
/// IN PLACE. The return is non-optional on purpose — the presentation slot must stay non-nil
/// across the swap. Assigning this to the `@State` item WITHOUT nil-ing first (and with a stable
/// view identity — no per-descriptor `.id`) keeps the card mounted so only its content diffs.
/// Nil-then-set would be a real dismiss+present, i.e. a blink.
func noBlinkSwap(current: AlertDialog, between a: AlertDialog, and b: AlertDialog) -> AlertDialog {
    current.primary == a.primary ? b : a
}
