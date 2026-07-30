import Foundation
import UIKit
import SnapKit

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
    /// **The title NEVER truncates and NEVER shrinks — owner directive.**
    ///
    /// This used to be `numberOfLines = 2` + `adjustsFontSizeToFitWidth = true` +
    /// `minimumScaleFactor = 0.75`, which is a three-rung ladder ending in TRUNCATION: shrink the
    /// glyphs to 75%, then wrap onto a second line, then ellipsize whatever is left over. The owner
    /// directive is "title and subtitle should no truncated, title with more content compression
    /// (title will still live while subtitle begin to wrap)", so all three rungs go:
    ///
    /// * `numberOfLines = 0` — as many lines as the string needs. This alone removes the ellipsis in
    ///   the common case, because `UILabel` only truncates when the text cannot fit the lines it is
    ///   allowed.
    /// * `lineBreakMode = .byWordWrapping`, stated rather than inherited. `UILabel`'s default is
    ///   `.byTruncatingTail`, which is harmless while the label gets its intrinsic height but
    ///   ellipsizes the moment it is given less — and being given less is exactly what a
    ///   height-pressured card does. Word wrapping cannot produce an ellipsis at all.
    /// * `adjustsFontSizeToFitWidth` is REMOVED, not merely left at `false`. It was the shrink half
    ///   of the ladder, and with `numberOfLines = 0` it has nothing left to do: wrapping always
    ///   satisfies the width, so there is no width to shrink onto. (UIKit also documents it as
    ///   applying to labels with a bounded line count; keeping it here would be inert at best and an
    ///   undefined interaction at worst, on the one property whose whole purpose was to shrink text
    ///   toward the truncation this directive forbids.)
    ///
    /// The second half of the directive is the ORDERING: the title's vertical compression resistance
    /// is raised from UIKit's 750 default to `ModalLayout.Priority.titleCompressionResistance` (900),
    /// which puts it above every other content rung — most importantly above the subtitle slot's
    /// frame/content height tie (250, or 749 on the natural-aspect banner path), which is the
    /// existing SUBTITLE-YIELDS mechanism. So under vertical pressure the subtitle shrink-and-scrolls
    /// inside `svSubtitleContainer` while the title keeps its size and all of its lines. The whole
    /// ladder, and why 900 rather than `.required`, is documented on `ModalLayout.Priority`.
    func generateLabelForTitleDesign() -> UILabel {
        let view = UILabel(frame: .zero)
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
    ///   height tie (250, or 749 on the natural-aspect banner path). That gap is what makes the
    ///   subtitle SCROLL rather than shrink: the tie is what breaks under pressure, so the scroll's
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
