import SwiftUI

/// **The card's content region — banner, title and subtitle — made scrollable.**
///
/// The buttons and the close button are deliberately NOT inside this: an action must stay visible and
/// tappable however much copy the card carries, which is the top of the priority ladder
/// (`ModalLayout.Priority.buttonSlotHeight`) expressed structurally rather than numerically.
///
/// ## Why this exists
///
/// Under a card too short for its content, every non-scrolling arrangement loses something. Measured on
/// the landscape card (capped at 214pt: safe area 294 − 40/40 margins, leaving ~110pt for title +
/// subtitle): the subtitle slot settled at ~14pt of a 19.1pt line, so the body text was drawn with its
/// bottom half cut off — a half-row of glyphs, which reads as a rendering bug rather than as "there is
/// more text". A scroll removes the whole class of problem: the content keeps its natural height and it
/// is the VIEWPORT that shrinks.
///
/// ## SWIFTUI ONLY — and that is a deliberate divergence, not an oversight
///
/// UIKit's `GBAlertModal` keeps its subtitle-only `svSubtitleContainer`. This module is consumed by the
/// production app as an SPM dependency (`Tuist/Package.swift` pins it, `Project.swift` links it), so its
/// UIKit half IS the shipping dialog — restructuring its view tree, its public `svSubtitleContainer`
/// property and its keyboard-avoidance anchor is a change every consumer inherits on the next version
/// bump. The owner's call was to freeze UIKit and let the NEW renderer take the better structure.
///
/// The cost is stated rather than hidden: `DifferentialGeometry` asserts the two backends agree
/// element-for-element, and this is a structural difference between them. It is safe for that gate only
/// because of the hugging behaviour below — the harness measures unpressured portrait shapes, where this
/// wrapper is provably inert. A PRESSURED comparison would now legitimately differ, and would need a
/// recorded divergence in `DifferentialGeometrySupport` rather than a "fix".
///
/// ## Why it is inert when the content fits
///
/// A bare `ScrollView` is greedy: in a `VStack` it takes every point offered, so the card would stop
/// hugging its content and always render full-height. The fix is to cap it at the height its content
/// actually wants — measured from inside, where the scroll proposes an unbounded height and the content
/// therefore reports its IDEAL size.
///
/// `frame(maxHeight: idealHeight)` then resolves to `min(ideal, offered)`:
///
/// * offered >= ideal (every card with room) → the scroll is exactly its content's height, which is the
///   same frame the content had with no scroll at all. Nothing moves, and no snapshot changes.
/// * offered < ideal (the pressured card) → the scroll takes what it is offered and its content scrolls
///   inside it, at full size, un-sliced.
///
/// The `nil` before the first measurement is the one moment this is greedy; the preference lands in the
/// same layout cycle that produced it, so the settled layout is the capped one.
struct ScrollableContent<Content: View>: View {
    @ViewBuilder let content: () -> Content

    /// `nil` until the content has reported a height — see the note on greediness above.
    @State private var idealHeight: CGFloat?

    /// The height the scroll was actually GRANTED. Used only to decide whether the content overflows,
    /// and only to drive the fade below — never to size anything, so unlike the banner ceiling that
    /// was tried and reverted, this reading cannot feed back into the layout it is measured from.
    @State private var grantedHeight: CGFloat?

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            // `VStack(spacing: 0)` EXPLICITLY, and it is load-bearing. A `ScrollView` whose content
            // is a multi-view `ViewBuilder` wraps it in an IMPLICIT stack carrying SwiftUI's default
            // spacing (8pt) — where the scaffold's own stack is `spacing: 0` and every gap on this
            // card is stated by the preset (`tokens.gapBelowTitle` and friends). Measured, before
            // this line existed: the title agreed exactly and every row below it shifted down by
            // exactly 8.0 — subtitle 60.7 → 68.7, primary button 93.0 → 101.0, card 168 → 176 — i.e.
            // the differential gate caught an 8pt gap nobody asked for on all eight shapes.
            VStack(spacing: 0) {
                content()
            }
            // A background reader rather than a wrapping `GeometryReader`: a wrapping one would
            // impose ITS sizing on the content, which is the thing being measured.
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollableContentHeightKey.self, value: proxy.size.height
                    )
                }
            )
        }
        .frame(maxHeight: idealHeight)
        // **The fold, made to read as "there is more" rather than as a rendering fault.**
        //
        // A scroll viewport ends wherever the available height runs out, which is generally MID-LINE:
        // the bottom row of glyphs is sliced horizontally, and that is visually the same defect this
        // whole effort set out to remove from the subtitle slot.
        //
        // Snapping the viewport to whole lines is the obvious fix and is NOT expressible here: the
        // fold can land inside the 24pt title or the 16pt subtitle, and SwiftUI exposes no per-line
        // geometry to snap against. What it can do is fade the last few points, so a half-drawn line
        // reads as content continuing past the edge — the standard affordance — instead of as text
        // that has been cut off.
        //
        // Applied ONLY when the content actually overflows; a card whose content fits keeps a hard,
        // unfaded bottom edge and is pixel-identical to one with no scroll at all.
        .mask(foldFade)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ScrollGrantedHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ScrollGrantedHeightKey.self) { height in
            if height > 0, grantedHeight != height {
                grantedHeight = height
            }
        }
        .onPreferenceChange(ScrollableContentHeightKey.self) { height in
            // Guard the assignment: an unconditional write re-renders on every pass with the same
            // value, which is a layout loop rather than a settled layout.
            if height > 0, idealHeight != height {
                idealHeight = height
            }
        }
    }

    /// Opaque everywhere except the last few points, and only when there is something below the fold
    /// to hint at.
    @ViewBuilder
    private var foldFade: some View {
        if overflows {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 1 - fadeFraction),
                    .init(color: .black.opacity(0), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Color.black
        }
    }

    private var overflows: Bool {
        guard let idealHeight, let grantedHeight else {
            return false
        }
        // A point of slack: `maxHeight` resolves to the ideal when there is room, and the two
        // measurements can differ in the last fractional point without anything being cut.
        return idealHeight > grantedHeight + 1
    }

    /// Roughly one 16pt line's worth of softening — enough to read as a soft edge, small enough not
    /// to dim text that is fully visible.
    private var fadeFraction: CGFloat {
        guard let grantedHeight, grantedHeight > 0 else {
            return 0
        }
        return Swift.min(0.25, 12 / grantedHeight)
    }
}

/// The height the scroll was granted, for the overflow test behind the fold fade.
private struct ScrollGrantedHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = Swift.max(value, nextValue())
    }
}

/// The banner's ceiling inside a scrolling card, in points — `nil` outside one (every non-scrolling
/// card, where the priority ladder already keeps the banner below the text and this must not apply).
///
/// An environment value rather than a parameter because the banner row is supplied by the CALLER
/// through `AlertModalScaffold`'s `content` slot: the scaffold cannot reach into it, and threading a
/// height through every bespoke content view would put this constraint's existence in the hands of
/// each of them.
///
/// UNUSED at present: nothing currently reads `modalBannerMaxHeight` — the standard banner row
/// (`SwiftUIAlertModal.BannerSlot`) reads `\.modalBannerGeometry` instead, whose height already
/// accounts for the space the card was offered (`ModalTokens.bannerGeometry`). Left in place rather
/// than removed in Task 3, which did not touch the scrolling path; a future pass through
/// `ScrollableContent` should confirm whether this key is still needed or is dead.
///
/// **Derived from the CARD's available space, never from the scroll's own.** The first version of
/// this measured the scroll's viewport — which is sized from `idealHeight`, which is the content's
/// height, which includes the banner. Banner sizes content, content sizes viewport, viewport caps
/// banner: a cycle, and layout built on a cycle settles somewhere arbitrary. `AlertModalScaffold`
/// now feeds it from the space the card is offered (screen minus margins), which no content can
/// influence.
extension EnvironmentValues {
    var modalBannerMaxHeight: CGFloat? {
        get { self[ModalBannerMaxHeightKey.self] }
        set { self[ModalBannerMaxHeightKey.self] = newValue }
    }
}

private struct ModalBannerMaxHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

/// The height the CARD is offered — screen minus margins. Read by `AlertModalScaffold` from a
/// background reader on its own container, so it depends on the window and nothing else.
struct ModalAvailableHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = Swift.max(value, nextValue())
    }
}

/// The content's ideal height, published from inside the scroll.
///
/// `max` rather than last-wins: the content is a `ViewBuilder` slot that may contain several probed
/// subviews, and the region's height is the tallest reading, not whichever happened to report last.
private struct ScrollableContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = Swift.max(value, nextValue())
    }
}
