import Foundation
import UIKit
import SnapKit

// MARK: - TITLE LABEL

/// **A `UILabel` that reports when its own frame for THIS layout pass has been assigned.**
///
/// Rung 2 of the no-truncation ladder (`GBAlertModal.adjustTitleFontScale`) is a decision about the
/// height Auto Layout actually granted the title, so it can only be made somewhere that height is
/// current. `GBAlertModal.layoutSubviews()` is NOT such a place: UIKit lays a tree out top-down, and
/// `lbTitle` is three levels down (`vwContainer` → `svContentContainer` → here), so when the modal's
/// own `layoutSubviews` runs, the title still carries the PREVIOUS pass's bounds — or `.zero` on the
/// first one, where the fit would silently be skipped and a compressed title would render truncated.
///
/// A label's own `layoutSubviews` is the correct place, and not an unusual one: it is exactly where
/// `UILabel` itself recomputes `preferredMaxLayoutWidth` from its bounds. By then the parent stack has
/// assigned the frames of ALL its arranged subviews, so the subtitle slot's height — the other half of
/// rung 2's budget — is current too.
///
/// A closure rather than a delegate or a back-reference: this type knows nothing about modals, and the
/// closure captures its owner weakly (see `buildTitleComponent`), so the label cannot keep the modal
/// alive. `lbTitle` stays typed as `UILabel` in the public API — this is a `UILabel`.
internal final class ModalTitleLabel: UILabel {
    /// Run after `super.layoutSubviews()`, i.e. once `bounds` is this pass's real value.
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

// MARK: - DESIGN

extension GBAlertModal {
    // Widened from `private` to `internal`: called from `init` in
    // GBAlertModal.swift (different file, same module).
    func initDesign() {
        // MARK: View Initialization
        let vwOverlay = generateGenericViewDesign()
        let vwContainer = generateGenericViewDesign()
        let svContentContainer = generateStackViewForContentDesign()

        // MARK: View Graph
        addSubview(vwOverlay)
        addSubview(vwContainer)
        vwContainer.addSubview(svContentContainer)

        // MARK: View Constraints
        vwOverlay.snp.makeConstraints { (make: ConstraintMaker) in
            make.edges
                    .equalToSuperview()
        }

        adjustVwContainerConstraint(vwContainer)
        adjustSvContentContainerConstraint(svContentContainer)

        // MARK: View Assign
        self.vwOverlay = vwOverlay
        self.vwContainer = vwContainer
        self.svContentContainer = svContentContainer
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateGenericViewDesign() -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    // Only used within this file (by `initDesign`); stays file-scoped.
    private func generateStackViewForContentDesign() -> UIStackView {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.distribution = .fill
        view.alignment = .center
        view.spacing = 0
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateImageViewForBannerDesign() -> UIImageView {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    //
    /// **The title NEVER truncates. It wraps; then, only as a last resort, it shrinks.**
    ///
    /// This used to be `numberOfLines = 2` + `adjustsFontSizeToFitWidth = true` +
    /// `minimumScaleFactor = 0.75` — a ladder ending in TRUNCATION: shrink the glyphs to 75% FIRST,
    /// then allow a second line, then ellipsize whatever is left over. The owner directive is "title
    /// and subtitle should no truncated, title with more content compression (title will still live
    /// while subtitle begin to wrap)", which reverses that order rather than merely deleting it:
    ///
    /// 1. the SUBTITLE yields first (the priority ladder below);
    /// 2. then the title SHRINKS, down to `ModalLayout.titleMinimumScaleFactor` — the same 0.75, still
    ///    with `numberOfLines = 0`, so the text re-wraps at the smaller size instead of being clipped
    ///    to a line count. That rung is `adjustTitleFontScale`, driven from `layoutSubviews`, because
    ///    it is a fit against the available HEIGHT and UIKit offers no property for that;
    /// 3. there is no third rung: the title keeps every glyph.
    ///
    /// So the three properties below go, and the shrink comes back one rung LOWER:
    ///
    /// * `numberOfLines = 0` — as many lines as the string needs. This alone removes the ellipsis in
    ///   the common case, because `UILabel` only truncates when the text cannot fit the lines it is
    ///   allowed.
    /// * `lineBreakMode = .byWordWrapping`, stated rather than inherited. `UILabel`'s default is
    ///   `.byTruncatingTail`, which is harmless while the label gets its intrinsic height but
    ///   ellipsizes the moment it is given less — and being given less is exactly what a
    ///   height-pressured card does. Word wrapping cannot produce an ellipsis at all.
    /// * `adjustsFontSizeToFitWidth` is REMOVED, not merely left at `false`, and it is NOT what rung 2
    ///   uses. With `numberOfLines = 0` a label never overflows its WIDTH — it wraps — so the property
    ///   has nothing to trigger it, and UIKit documents it against a bounded line count. Rung 2 needs
    ///   a fit against the available HEIGHT, which is `adjustTitleFontScale`'s computed search.
    ///
    /// Rung 1 is the ORDERING: the title's vertical compression resistance is raised from UIKit's 750
    /// default to `ModalLayout.Priority.titleCompressionResistance` (900), which puts it above every
    /// other content rung — most importantly above the subtitle slot's frame/content height tie
    /// (`ModalLayout.Priority.subtitleSlotHeight`, `.defaultLow`/250, unconditionally on every
    /// path), the existing SUBTITLE-YIELDS mechanism. So under vertical pressure the subtitle
    /// shrink-and-scrolls inside `svSubtitleContainer` first, at full
    /// size, and only what is left over reaches the title. The whole ladder, and why 900 rather than
    /// `.required`, is documented on `ModalLayout.Priority`.
    ///
    /// One property this factory does NOT set is `preferredMaxLayoutWidth`; `adjustTitleWrapWidth`
    /// owns it, because it is the resolved CONTENT width and not a constant. Leaving it at 0 is what
    /// made a wrapping title silently drop lines — see that method for the measured evidence.
    func generateLabelForTitleDesign() -> ModalTitleLabel {
        let view = ModalTitleLabel(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.numberOfLines = 0
        view.lineBreakMode = .byWordWrapping
        view.textAlignment = .center
        view.setContentCompressionResistancePriority(
                ModalLayout.Priority.titleCompressionResistance,
                for: .vertical
        )
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateScrollForCustomViewDesign() -> UIScrollView {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = true
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    //
    /// **The subtitle never truncates either — it YIELDS by scrolling.**
    ///
    /// `numberOfLines = 0` was already correct and is unchanged. Two things are now stated instead of
    /// inherited from a UIKit default, because the owner directive's ordering rests on both:
    ///
    /// * `lineBreakMode = .byWordWrapping`, for the same reason as the title: the default
    ///   `.byTruncatingTail` ellipsizes as soon as the label is given less height than it asked for.
    /// * the vertical compression resistance, pinned to
    ///   `ModalLayout.Priority.subtitleCompressionResistance` (750 — UIKit's own default, so this
    ///   changes no behaviour). It is BELOW the title's 900, which is the directive's "title with
    ///   more content compression", and it is deliberately ABOVE the subtitle slot's frame/content
    ///   height tie (`ModalLayout.Priority.subtitleSlotHeight`, `.defaultLow`/250, unconditionally).
    ///   That gap is what makes the subtitle SCROLL rather than shrink: the tie is what breaks
    ///   under pressure, so the scroll's
    ///   visible height falls below its content height while the label itself keeps every line at
    ///   full size. Lowering this label below the tie would invert that and produce a squeezed,
    ///   clipped subtitle — the exact outcome the directive forbids.
    func generateLabelForSubtitleDesign() -> UILabel {
        let view = UILabel(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.numberOfLines = 0
        view.lineBreakMode = .byWordWrapping
        view.textAlignment = .center
        view.setContentCompressionResistancePriority(
                ModalLayout.Priority.subtitleCompressionResistance,
                for: .vertical
        )
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateStackViewForMainButtonDesign() -> UIStackView {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.distribution = .fillEqually
        view.alignment = .center
        return view
    }

    // Widened from `private` to `internal`: called from `registerDialogView` in
    // GBAlertModal.swift (different file, same module).
    func generateButtonForCloseDesign() -> UIButton {
        let view = UIButton(type: .system)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}
