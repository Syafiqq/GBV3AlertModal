import GBV3AlertModalCore

import SwiftUI

/// The NAMED semantic elements the two renderers are compared on (spec C-3a).
///
/// This enum is the WHOLE vocabulary of the differential-geometry gate: an element exists here only
/// because both backends draw a counterpart for it and a test compares the two. It is deliberately
/// not "every view in the tree" — a probe on an unnamed element would be measurement without a
/// comparison, which is the kind of instrumentation that grows without ever failing.
///
/// | case | UIKit counterpart (`GBAlertModal`) | SwiftUI counterpart |
/// | --- | --- | --- |
/// | `card` | `vwContainer` (the rounded, filled container) | `AlertModalScaffold.card` |
/// | `banner` | `vwBanner` (the banner SLOT, not `ivBanner`) | `BannerSlot`'s `Color.clear` slot, not the `Image` inside it |
/// | `title` | `lbTitle` | the title `Text` |
/// | `subtitle` | `svSubtitleContainer` (the scroll SLOT) | the subtitle `Text` |
/// | `primaryButton` | `btPrimaryAction` — the VISIBLE oblique rect, which UIKit insets ±3 from its slot | the primary `Button` |
/// | `secondaryButton` | `btSecondaryAction` | the secondary `Button` |
/// | `closeButton` | `btCloseAction` | the close `Button` in the card's `topTrailing` overlay |
///
/// Compiled in RELEASE as well as DEBUG, because it appears in the signature of
/// `View.modalGeometryProbe(_:)` below — but it is a bare tag type: no measurement code, no
/// `GeometryReader`, nothing that runs. The instrumentation itself is `#if DEBUG` only.
enum ModalGeometryElement: String, CaseIterable, Hashable, Sendable {
    case card
    case banner
    case title
    case subtitle
    case primaryButton
    case secondaryButton
    case closeButton
}

#if DEBUG
/// Collects one measured frame per `ModalGeometryElement` on its way up the view tree.
///
/// A `PreferenceKey` and not `onGeometryChange(for:of:action:)`: that modifier is iOS 16+ and this
/// library's floor is iOS 15. A preference also aggregates the whole card in ONE delivery, so a test
/// reads a consistent set of frames rather than seven independent callbacks that may land in
/// different layout passes.
struct ModalGeometryPreferenceKey: PreferenceKey {
    static let defaultValue: [ModalGeometryElement: CGRect] = [:]

    /// Later wins. Each element is probed exactly once per render, so this only ever merges
    /// disjoint single-entry dictionaries coming up from sibling subtrees.
    static func reduce(
        value: inout [ModalGeometryElement: CGRect],
        nextValue: () -> [ModalGeometryElement: CGRect]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Publishes `element`'s measured frame without changing layout.
///
/// The reader sits in a `.background` (never an `.overlay` and never a wrapping `GeometryReader`):
/// a background is proposed the size its parent already resolved, so it observes the frame instead
/// of participating in deciding it. A wrapping `GeometryReader` would accept the full proposal and
/// change the very geometry it is supposed to report.
///
/// Frames are taken in `.global`. The absolute origin is never compared — every test normalises
/// each element against the CARD's origin (see `DifferentialGeometrySupport`), so all that is
/// required of the space is that it be the SAME for all seven probes, which `.global` is. Using a
/// named space instead would mean adding a `coordinateSpace(name:)` to the production scaffold for
/// no gain.
struct ModalGeometryProbe: ViewModifier {
    let element: ModalGeometryElement

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ModalGeometryPreferenceKey.self,
                    value: [element: proxy.frame(in: .global)]
                )
            }
        }
    }
}
#endif

extension View {
    /// Tags this view as `element` for the differential-geometry gate.
    ///
    /// In RELEASE this returns `self` — the `#if` selects the branch before type-checking, so the
    /// opaque result type is `Self` and a release binary carries no `GeometryReader`, no preference
    /// and no closure. In DEBUG it attaches `ModalGeometryProbe`.
    ///
    /// Applied ONLY to the seven elements listed on `ModalGeometryElement`, and always INSIDE the
    /// element's own modifiers but OUTSIDE nothing — i.e. it measures the element as its parent
    /// stack sees it, before any inter-element spacing (`padding(.bottom, gapBelow…)`) is added, so
    /// the measured rect is the counterpart of the UIKit view rather than of UIKit's spacer view.
    func modalGeometryProbe(_ element: ModalGeometryElement) -> some View {
        #if DEBUG
        return modifier(ModalGeometryProbe(element: element))
        #else
        return self
        #endif
    }
}
