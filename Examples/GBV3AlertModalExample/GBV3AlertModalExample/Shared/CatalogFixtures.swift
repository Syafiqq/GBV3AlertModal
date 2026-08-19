import Foundation

/// Framework-neutral content shared by the UIKit gallery and the SwiftUI-only catalog.
enum CatalogFixtures {
    static let title10Line =
        "This is an intentionally long title string engineered to stress test the wrapping behavior of " +
        "the alert modal across many lines without any manual line breaks so the layout engine must " +
        "handle natural word wrapping consistently across roughly ten lines of bold twenty four point " +
        "text inside a narrow content card which forces frequent word wraps and exercises the vertical " +
        "growth of the title label region within the alert content stack and its surrounding padding " +
        "and spacing constraints under sustained load"
    static let subtitle10Line =
        "This subtitle exists purely to stress test long form body copy wrapping inside the alert modal " +
        "without any manual line breaks whatsoever so that the rendering engine is forced to reflow " +
        "every single word naturally across roughly ten lines of regular sixteen point text set inside " +
        "a narrow two hundred fifty six point wide content card which in turn forces frequent word " +
        "wraps and thoroughly exercises the vertical growth behavior of the subtitle label region " +
        "within the alert content stack along with its surrounding padding insets interbutton spacing " +
        "and overall scroll container sizing logic under sustained stress conditions"
    static let title4Repeat = String(repeating: "Long title wraps across many lines ", count: 4)
        .trimmingCharacters(in: .whitespaces)
    static let subtitleOneLine = "This is the subtitle text for the alert modal."
    static let titleUnbreakable =
        "Pneumonoultramicroscopicsilicovolcanoconiosisantidisestablishmentarianism"
    static let subtitleUnbreakable =
        "Floccinaucinihilipilificationhippopotomonstrosesquippedaliophobiapseudopseudohypoparathyroidism"
        + "Thyroparathyroidectomizedradioimmunoelectrophoresisspectrophotofluorometrically"
    static let primaryFull = "Continue"
    static let secondaryFull = "Not Now"
    static let primaryWrapped =
        "This Extremely Long Primary Action Button Label Is Designed To Force Multi-Line Wrapping " +
        "Inside The Button Bounds"
    static let secondaryWrapped =
        "This Equally Long Secondary Action Button Label Also Forces The Button To Wrap Across " +
        "Several Lines"
    static let sweepCategory = "Stress · Axis Sweep"
    static let maxedCategory = "Stress · Everything Maxed"
    static let degenerateCategory = "Stress · Degenerate"
    static let nastyCategory = "Stress · Nasty Interactions"
    static let closeButtonCategory = "Stress · Close Button"
    static let extraCategory = "Stress · Extra"
    static let divergenceCategory = "Divergence"
    static let comparableSubtitle = "A banner the gate can actually measure."
}

extension Array {
    subscript(safeIndex index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }

    @inlinable func isSafe(index: Int) -> Bool {
        indices.contains(index)
    }
}
