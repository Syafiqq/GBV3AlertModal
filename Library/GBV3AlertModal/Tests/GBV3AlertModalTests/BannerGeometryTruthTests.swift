import XCTest
@testable import GBV3AlertModal

/// **The UIKit banner rules, pinned against measured Auto Layout output.**
///
/// UIKit's banner geometry is emergent — `vwBanner` often carries NO height constraint at all, and
/// the slot's size falls out of `ivBanner`'s intrinsic content size meeting its default compression
/// resistance (750) through the `width == height * ratio` tie. Two closed-form rules reproduce it in
/// portrait; this suite is what fails if a priority in `ModalLayout.Priority` is retuned, which has
/// already happened once with only stale comments to show for it.
///
/// PORTRAIT ONLY, and deliberately so: in a height-constrained card UIKit distributes the remainder
/// across four sub-required tiers and the banner takes the residual (measured 102.3 for every real
/// preset regardless of ratio or cap). No closed form reaches that, and none is claimed here.
///
/// ## What the table covers, and the two places it does NOT
///
/// Aspect: landscape (160x90, 320x190, 320x229, 1168x760), square (160x160, 64x64), nearly-square
/// (295x256), and — added later — narrow/TALL portrait (120x400, 200x2000). Column: 256 (the app's
/// iPhone width) and 300 (its iPad width). Host: 390x844, and 1024x1366 for the 300pt rows.
///
/// Two rows here are DIVERGENCES, pinned rather than fixed, and both say so in full at their own
/// definitions:
///
/// * `test_tallUncappedArtwork_UIKitYieldsTheResidual_whereTheRuleDoesNot` — uncapped artwork taller
///   than the card can hold. UIKit yields to the residual (525.0 at this host); the rule returns the
///   artwork's full 2000. No shipping asset is in the regime, and `BannerSlot`'s `.frame(maxHeight:)`
///   absorbs it on the SwiftUI side.
/// * `test_ratioThatDisagreesWithItsArtwork_divergesFromTheRule` — a `bannerRatio` that is not the
///   artwork's own aspect. UIKit measures 305.67 where the rule computes 318/320. Every preset in the
///   app spells its ratio from the asset it ships with, so nothing reaches it.
@MainActor
final class BannerGeometryTruthTests: XCTestCase {
    private let host = CGSize(width: 390, height: 844)

    /// The rules under test. Mirrors `ModalTokens.bannerGeometry` (Task 2) but is written out
    /// independently ON PURPOSE: a truth table that imports the implementation it is checking
    /// proves only that the code equals itself.
    private func predicted(
        imageSize: CGSize,
        ratio: CGFloat?,
        cap: CGFloat?,
        contentMaxWidth: CGFloat,
        leftMin: CGFloat,
        rightMin: CGFloat,
        availableCardWidth: CGFloat
    ) -> (column: CGFloat, height: CGFloat) {
        guard imageSize.width > 0, imageSize.height > 0 else { return (0, 0) }
        let r = ratio ?? (imageSize.width / imageSize.height)
        let capped = cap ?? .greatestFiniteMagnitude
        let ceiling = availableCardWidth - leftMin - rightMin
        let demand = min(imageSize.width, capped * r)
        let column = min(max(demand, contentMaxWidth), ceiling)
        let height = min(capped, column / r, max(imageSize.height, imageSize.width / r))
        return (column, height)
    }

    private func measure(
        _ properties: GBAlertModal.Properties,
        imageSize: CGSize,
        hostSize: CGSize? = nil
    ) -> (column: CGFloat, height: CGFloat, card: CGFloat) {
        let hostSize = hostSize ?? host
        let modal = GBAlertModal(
            properties: properties,
            holder: GeniePresets.withBanner(width: imageSize.width, height: imageSize.height)
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: hostSize))
        window.isHidden = false
        modal.show(parent: window, completion: {})
        window.setNeedsLayout()
        window.layoutIfNeeded()
        let slot = modal.vwBanner?.frame ?? .zero
        let card = modal.vwContainer?.frame ?? .zero
        window.isHidden = true
        return (slot.width, slot.height, card.width)
    }

    private func assertRules(
        _ label: String,
        properties: GBAlertModal.Properties,
        imageSize: CGSize,
        hostSize: CGSize? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let hostSize = hostSize ?? host
        let measured = measure(properties, imageSize: imageSize, hostSize: hostSize)
        let padding = properties.padding ?? UIMinMaxEdgeInsets()
        let expected = predicted(
            imageSize: imageSize,
            ratio: properties.bannerRatio,
            cap: properties.bannerMaxHeight,
            contentMaxWidth: properties.contentProperty?.maxWidthPortrait ?? .infinity,
            leftMin: padding.leftMin,
            rightMin: padding.rightMin,
            availableCardWidth: hostSize.width - (properties.margin?.left ?? 0) - (properties.margin?.right ?? 0)
        )
        XCTAssertEqual(
            measured.column, expected.column, accuracy: 0.5,
            "\(label): column rule broke — measured \(measured.column), rule says \(expected.column)",
            file: file, line: line
        )
        XCTAssertEqual(
            measured.height, expected.height, accuracy: 0.5,
            "\(label): height rule broke — measured \(measured.height), rule says \(expected.height)",
            file: file, line: line
        )
    }

    // MARK: - Artwork that fits inside the column

    func test_ratio1_artworkNarrowerThanColumn() {
        assertRules("160x90 r1 no cap",
                    properties: GeniePresets.standardProperties(),
                    imageSize: CGSize(width: 160, height: 90))
    }

    func test_ratio1_squareArtworkNarrowerThanColumn() {
        assertRules("160x160 r1 cap216",
                    properties: GeniePresets.popupProperties().copy(bannerRatio: 1, bannerMaxHeight: 216),
                    imageSize: CGSize(width: 160, height: 160))
    }

    func test_naturalAspect_artworkNarrowerThanColumn() {
        assertRules("160x90 rNil no cap",
                    properties: GeniePresets.standardPropertiesNilBannerRatio(),
                    imageSize: CGSize(width: 160, height: 90))
    }

    // MARK: - Artwork wider than the column (every real app asset but one)

    func test_gc2gsShape_artworkWiderThanColumn() {
        assertRules("320x190 r320:190 cap256",
                    properties: GeniePresets.popupProperties()
                        .copy(bannerRatio: 320.0 / 190.0, bannerMaxHeight: 256),
                    imageSize: CGSize(width: 320, height: 190))
    }

    func test_quizShape_capBindsBeforeTheColumn() {
        assertRules("320x229 r320:229 cap216",
                    properties: GeniePresets.popupProperties()
                        .copy(bannerRatio: 320.0 / 229.0, bannerMaxHeight: 216),
                    imageSize: CGSize(width: 320, height: 229))
    }

    /// **The artwork SETS the column: wider than `contentMaxWidth`, and clear of the ceiling.**
    ///
    /// Renamed from `test_errorBannerShape_artworkJustUnderTheCeiling`, which named the wrong bound.
    /// `errorBannerProperties` is the popup preset, so `contentMaxWidth` is 256 and the ceiling is
    /// 310 (350 of card minus the 20pt rigid minima). The artwork is 295 wide and the cap allows
    /// `320 * 1.152 = 368.75`, so the demand is the artwork's own 295 — above the 256pt column and
    /// 15pt clear of the ceiling. The CEILING IS INERT in this row; it is the `max(demand,
    /// contentMaxWidth)` term that decides, and the resulting column is exactly the artwork width.
    ///
    /// That distinction matters because the ceiling branch is pinned by its own rows
    /// (`test_gc2gsShape_artworkWiderThanColumn` at 310, `test_fasttrackShape_hugeArtworkClampsTo
    /// TheCeiling` at 310). Naming this one after the ceiling implied a third clamped row where there
    /// is none, and left the unclamped-demand case looking uncovered.
    func test_errorBannerShape_artworkSetsTheColumn() {
        assertRules("295x256 r295:256 cap320",
                    properties: GeniePresets.errorBannerProperties(),
                    imageSize: CGSize(width: 295, height: 256))
    }

    func test_fasttrackShape_hugeArtworkClampsToTheCeiling() {
        assertRules("1168x760 r292:190 cap256",
                    properties: GeniePresets.popupProperties()
                        .copy(bannerRatio: 292.0 / 190.0, bannerMaxHeight: 256),
                    imageSize: CGSize(width: 1168, height: 760))
    }

    // MARK: - The cap

    func test_capBelowEverything_wins() {
        assertRules("160x90 r1 cap40",
                    properties: GeniePresets.standardProperties().copy(bannerMaxHeight: 40),
                    imageSize: CGSize(width: 160, height: 90))
    }

    // MARK: - The inert field, pinned so its removal from SwiftUI stays justified

    /// `bannerFixedHeight` sits at 243: below the card's hugging (250) going up, below the image's
    /// compression resistance (750) coming down. Measured zero effect at every size tried. SwiftUI
    /// drops it in Task 3 on the strength of this test.
    func test_bannerFixedHeight_isInert_onTheRatioPath() {
        let withFixed = measure(
            GeniePresets.standardProperties().copy(bannerFixedHeight: 200),
            imageSize: CGSize(width: 64, height: 64)
        )
        let without = measure(
            GeniePresets.standardProperties(),
            imageSize: CGSize(width: 64, height: 64)
        )
        XCTAssertEqual(withFixed.height, without.height, accuracy: 0.5,
                       "bannerFixedHeight changed the slot height — it is no longer inert, and "
                           + "ModalTokens.bannerLayout must start applying it again")
        XCTAssertEqual(withFixed.height, 64, accuracy: 0.5)
    }

    func test_bannerFixedHeight_isInert_onTheNaturalAspectPath() {
        let withFixed = measure(
            GeniePresets.standardPropertiesNilBannerRatio().copy(bannerFixedHeight: 200),
            imageSize: CGSize(width: 64, height: 64)
        )
        // The WITHOUT measurement, exactly as the ratio-path sibling above takes it. This test used
        // to compare against a bare literal `64`, which asserts something weaker and different: that
        // the slot is 64pt tall. "Inert" means "the field changed NOTHING", and only a paired
        // measurement can say that — a literal would still pass if a future change moved both
        // readings to some other shared number, which is the case the ratio-path test would catch
        // and this one would not.
        let without = measure(
            GeniePresets.standardPropertiesNilBannerRatio(),
            imageSize: CGSize(width: 64, height: 64)
        )
        XCTAssertEqual(withFixed.height, without.height, accuracy: 0.5,
                       "bannerFixedHeight changed the slot height on the natural-aspect path "
                           + "(\(withFixed.height) with it, \(without.height) without) — it is no "
                           + "longer inert, and ModalTokens.bannerLayout must start applying it again")
        // And the literal too, so the pair above is known to be pinned at the artwork's own size
        // rather than merely agreeing with each other somewhere else.
        XCTAssertEqual(withFixed.height, 64, accuracy: 0.5,
                       "bannerFixedHeight is no longer inert on the natural-aspect path")
    }

    // MARK: - Narrow/TALL PORTRAIT artwork — the aspect regime this table had none of
    //
    // Every fixture above is landscape or square: 160x90, 160x160, 320x190, 320x229, 295x256,
    // 1168x760, 64x64. The RULE side is pinned for a tall artwork
    // (`ModalBannerGeometryRuleTests.test_tallUncappedArtwork_producesAnUnyieldingSlot_whereUIKit
    // WouldYield`, 200x2000 -> 2000) but the MEASURED side never was, so that test's central claim —
    // "where UIKit would yield" — was prose. These three rows measure it.

    /// A tall artwork that still FITS the card: the rules hold, unchanged.
    ///
    /// 120x400 at natural aspect (r = 0.3). demand 120, so the column stays at `contentMaxWidth`
    /// 256; the height is the artwork's own 400, which an 844pt host has room for. This is the
    /// ordinary row — it is here so the divergence below is known to be about the CARD RUNNING OUT
    /// OF ROOM and not about tall artwork as such.
    func test_tallPortraitArtwork_thatFitsTheCard_followsTheRules() {
        assertRules("120x400 rNil no cap",
                    properties: GeniePresets.standardPropertiesNilBannerRatio(),
                    imageSize: CGSize(width: 120, height: 400))
    }

    /// The same tall artwork under a cap: the rules hold there too, because the cap removes the
    /// only term the rule is missing.
    func test_tallPortraitArtwork_underACap_followsTheRules() {
        assertRules("200x2000 rNil cap160",
                    properties: GeniePresets.standardPropertiesNilBannerRatio(bannerMaxHeight: 160),
                    imageSize: CGSize(width: 200, height: 2000))
    }

    /// **FINDING — `ModalTokens.bannerGeometry` OVERSHOOTS when the artwork is taller than the card
    /// can hold, and this is the first measurement of it.**
    ///
    /// 200x2000 at natural aspect with NO cap is the regime UIKit has explicit machinery for: the
    /// natural-aspect driver sits at `ModalLayout.Priority.bannerNaturalAspect` (245) and the image's
    /// own intrinsic resistance is dropped to `bannerImageIntrinsic` (241), both below the card's
    /// `.low` (250) hugging and far below the title's compression resistance (900). So UIKit shrinks
    /// the banner rather than starving the text — and it shrinks it to **the residual**, exactly as
    /// it does in landscape.
    ///
    /// Measured, portrait, in this suite's 390x844 host: **525.0pt**, where the rule returns
    /// **2000.0pt**. The residual is a property of the HOST, not of the artwork:
    ///
    /// | artwork | host | UIKit measured | rule says |
    /// |---|---|---|---|
    /// | 200x2000 rNil capNil | 390x844 | **525.0** | 2000.0 |
    /// | 200x800 rNil capNil | 390x844 | **525.0** | 800.0 |
    /// | 200x600 rNil capNil | 390x844 | **525.0** | 600.0 |
    /// | 200x2000 rNil capNil | 1024x1366 | **1047.0** | 2000.0 |
    /// | 200x2000 r200:2000 capNil | 390x844 | **618.33** | 2000.0 |
    /// | 120x400 rNil capNil | 390x844 | 400.0 | 400.0 (agree — it fits) |
    /// | 200x2000 rNil **cap160** | 390x844 | 160.0 | 160.0 (agree — the cap binds first) |
    ///
    /// **The rule is NOT adjusted to fit.** `ModalTokens.bannerGeometry` deliberately has no yield
    /// term — the column depends on the resolved height, the height on the residual, the residual on
    /// the text, and the text's wrapping on the column, which is the measurement cycle the design
    /// forbids. What absorbs the overshoot in the SwiftUI backend is `BannerSlot`'s
    /// `.frame(maxHeight:)` over a greedy `Color.clear`: the SLOT resolves to
    /// `min(thisDesire, whateverIsLeft)`, produced by the layout engine rather than by arithmetic.
    /// So this divergence is in the RULE and is expected to be; what is asserted here is its SHAPE,
    /// so that a future yield rule changes this test deliberately instead of discovering it.
    ///
    /// **No shipping asset is in this regime.** All the real banner assets are landscape or square,
    /// and every real preset sets a `bannerMaxHeight` — either alone is enough, as the two rows above
    /// show.
    ///
    /// The exact 525.0 is NOT asserted: it is the residual left by this fixture's title, subtitle and
    /// button at this host, so it would move for a text change that is not a defect. What is asserted
    /// is that UIKit yielded, that it yielded to something the host can actually hold, and that it is
    /// the HEIGHT alone — the column still agrees to the point.
    func test_tallUncappedArtwork_UIKitYieldsTheResidual_whereTheRuleDoesNot() {
        let imageSize = CGSize(width: 200, height: 2000)
        let properties = GeniePresets.standardPropertiesNilBannerRatio()
        let measured = measure(properties, imageSize: imageSize)
        let padding = properties.padding ?? UIMinMaxEdgeInsets()
        let rule = predicted(
            imageSize: imageSize,
            ratio: properties.bannerRatio,
            cap: properties.bannerMaxHeight,
            contentMaxWidth: properties.contentProperty?.maxWidthPortrait ?? .infinity,
            leftMin: padding.leftMin,
            rightMin: padding.rightMin,
            availableCardWidth: host.width - (properties.margin?.left ?? 0) - (properties.margin?.right ?? 0)
        )

        // Premise: the rule really does ask for the artwork's full height. Without this the
        // inequality below could be satisfied by a rule that had quietly started clamping, and the
        // divergence would read as closed when it is not.
        XCTAssertEqual(
            rule.height, 2000, accuracy: 0.5,
            "the rule no longer returns the artwork's full 2000pt for uncapped tall artwork. If a "
                + "yield term was added, this whole test is the thing to rewrite — do not delete it."
        )

        // The COLUMN is not part of the divergence: both say 256.
        XCTAssertEqual(
            measured.column, rule.column, accuracy: 0.5,
            "the column diverged too (measured \(measured.column), rule \(rule.column)). This "
                + "finding is about the HEIGHT only; a column divergence here is a separate defect."
        )

        // The divergence itself, as an inequality rather than a frozen 525.
        XCTAssertLessThan(
            measured.height, rule.height - 0.5,
            "UIKit no longer yields for uncapped tall artwork: it measured \(measured.height)pt "
                + "against the rule's \(rule.height)pt. If UIKit has stopped shrinking the banner "
                + "below the text, `ModalLayout.Priority`'s banner tier has been retuned and "
                + "`ModalBannerGeometryRuleTests.test_tallUncappedArtwork_producesAnUnyielding"
                + "Slot_whereUIKitWouldYield` is describing a UIKit that no longer exists."
        )

        // …and it yielded to something the host can hold, which is what "the residual" means.
        XCTAssertLessThanOrEqual(
            measured.height, host.height,
            "UIKit's banner (\(measured.height)pt) is taller than the whole \(host.height)pt host, "
                + "so it did not yield to a residual — it overflowed"
        )
        XCTAssertGreaterThan(
            measured.height, 0,
            "the banner collapsed entirely rather than taking the residual"
        )
    }

    // MARK: - The 300pt content column (the iPad width)

    /// **The app uses 256pt on iPhone and 300pt on iPad** (`V3AlertModal+GBV3AlertModal.swift`), and
    /// every row above exercises 256. `GeniePresets.badgeProperties()` already carries the 300, so
    /// these run the SAME measured-against-transcribed comparison at that column.
    ///
    /// **What these prove and what they do NOT.** They prove the column arithmetic — the
    /// `max(demand, contentMaxWidth)` / ceiling interaction — holds at 300 as it does at 256, on a
    /// phone-width host AND on an iPad-width one. They prove NOTHING about real iPad hardware: this
    /// is an iPhone simulator with a 1024x1366 `UIWindow` forced on it, so the trait collection, the
    /// size classes, the display scale and `UIDevice.current.userInterfaceIdiom` are all still the
    /// phone's. What the app does with the idiom — pick 300 over 256 — is the app's decision and is
    /// not under test here; what happens once 300 has been picked is.
    private var iPadWidthHost: CGSize { CGSize(width: 1024, height: 1366) }

    func test_column300_artworkNarrowerThanTheColumn() {
        for (label, size) in [("phone host", host), ("iPad-width host", iPadWidthHost)] {
            assertRules("160x160 rNil no cap, 300col, \(label)",
                        properties: GeniePresets.badgeProperties().copy(bannerRatio: nil),
                        imageSize: CGSize(width: 160, height: 160),
                        hostSize: size)
        }
    }

    /// Artwork wider than the 300pt column, at a ratio that matches it — the real-preset shape.
    /// The two hosts take different branches: the phone clamps the column to its 318pt ceiling
    /// (350 available − 16 − 16 of rigid minimum padding), the iPad-width host does not and the
    /// column reaches the artwork's full 400.
    func test_column300_artworkWiderThanTheColumn() {
        for (label, size) in [("phone host", host), ("iPad-width host", iPadWidthHost)] {
            assertRules("400x250 r400:250 cap256, 300col, \(label)",
                        properties: GeniePresets.badgeProperties()
                            .copy(bannerRatio: 400.0 / 250.0, bannerMaxHeight: 256),
                        imageSize: CGSize(width: 400, height: 250),
                        hostSize: size)
        }
    }

    /// The cap binding before the 300pt column: `cap 320 * ratio 1.152 = 368.75`, above the
    /// artwork's own 295, so the artwork sets the demand — and 295 is below 300, so the column
    /// stays at `contentMaxWidth`.
    func test_column300_capBindsBeforeTheColumn() {
        for (label, size) in [("phone host", host), ("iPad-width host", iPadWidthHost)] {
            assertRules("295x256 r295:256 cap320, 300col, \(label)",
                        properties: GeniePresets.badgeProperties()
                            .copy(bannerRatio: 295.0 / 256.0, bannerMaxHeight: 320),
                        imageSize: CGSize(width: 295, height: 256),
                        hostSize: size)
        }
    }

    // MARK: - A ratio that DISAGREES with its artwork

    /// **FINDING — every fixture in this file (and every real preset) sets `bannerRatio` to the
    /// artwork's OWN aspect, and the rule is only correct there.**
    ///
    /// Give a 320x190 artwork a forced ratio of 1 and UIKit measures a **305.67pt** column where the
    /// rule computes 318 (phone, ceiling-clamped) / 320 (iPad-width host). Measured on both hosts and
    /// at both columns — 256 and 300 — so it is a property of the MISMATCH, not of the column or the
    /// ceiling:
    ///
    /// | artwork | ratio | column | host | UIKit | rule |
    /// |---|---|---|---|---|---|
    /// | 320x190 | 1 | 256 | 390x844 | **305.67** | 318 |
    /// | 320x190 | 1 | 256 | 1024x1366 | **305.67** | 320 |
    /// | 320x190 | 1 | 300 | 1024x1366 | **305.67** | 320 |
    /// | 320x**320** | 1 | 300 | 1024x1366 | 320.0 | 320.0 (agree — the ratio MATCHES) |
    /// | 320x**320** | 1 | 300 | 390x844 | 318.0 | 318.0 (agree) |
    ///
    /// The cause is that `demand = min(imageWidth, cap * ratio)` reads the artwork's WIDTH, which is
    /// the width UIKit's `ivBanner` asks for only when the picture fills a slot of that ratio. Under
    /// `scaleAspectFit` in a slot whose aspect it does not share, the picture is letterboxed and its
    /// effective demand is something else — and the rule cannot see it.
    ///
    /// **Not fixed, deliberately.** No preset in the app is in this regime: every one spells its
    /// ratio from the asset it ships with (`errorBannerProperties` 295:256 for a 295x256 asset,
    /// `aiNotesBannerProperties` 960:681 for the same asset's pixel ratio, `badgeUnlockProperties`
    /// ratio 1 for a square badge). Changing `bannerGeometry` for a case nothing reaches would be a
    /// change with no shape behind it. This test exists so the divergence is a pinned number rather
    /// than a rumour, and so that a preset which ever DOES mismatch finds this written down.
    func test_ratioThatDisagreesWithItsArtwork_divergesFromTheRule() {
        let imageSize = CGSize(width: 320, height: 190)   // 1.684 wide, forced into a square slot
        let properties = GeniePresets.badgeProperties()    // bannerRatio 1, no cap, 300pt column
        let measured = measure(properties, imageSize: imageSize, hostSize: iPadWidthHost)
        let padding = properties.padding ?? UIMinMaxEdgeInsets()
        let rule = predicted(
            imageSize: imageSize,
            ratio: properties.bannerRatio,
            cap: properties.bannerMaxHeight,
            contentMaxWidth: properties.contentProperty?.maxWidthPortrait ?? .infinity,
            leftMin: padding.leftMin,
            rightMin: padding.rightMin,
            availableCardWidth: iPadWidthHost.width
                - (properties.margin?.left ?? 0) - (properties.margin?.right ?? 0)
        )

        XCTAssertEqual(
            rule.column, 320, accuracy: 0.5,
            "premise: the rule takes the artwork's own 320pt width as the demand. If it no longer "
                + "does, this finding has changed shape and the table above is stale."
        )
        XCTAssertLessThan(
            measured.column, rule.column - 0.5,
            "UIKit's column for a ratio that disagrees with its artwork (\(measured.column)pt) is no "
                + "longer NARROWER than the rule's \(rule.column)pt. If they now agree, the rule has "
                + "become correct in a regime it was never written for — delete this test and move "
                + "the row into the table above."
        )
        // And the MATCHING case still agrees, which is what makes the divergence attributable to the
        // mismatch rather than to something about this preset or this host.
        assertRules("320x320 r1 no cap, 300col, iPad-width host — the MATCHING control",
                    properties: properties,
                    imageSize: CGSize(width: 320, height: 320),
                    hostSize: iPadWidthHost)
    }

    // MARK: - Degenerate

    func test_zeroSizeArtwork_collapsesTheSlot() {
        let measured = measure(GeniePresets.standardProperties(), imageSize: .zero)
        // Guard against a vacuous pass: if the modal never laid out at all, `vwBanner` would be
        // nil and both assertions below would read 0 from `?? .zero` regardless of whether the
        // slot actually collapsed. Proving the card built confirms the zeros mean something.
        XCTAssertGreaterThan(
            measured.card, 0,
            "the modal did not lay out at all, so the zero-size slot below proves nothing"
        )
        XCTAssertEqual(measured.column, 0, accuracy: 0.5)
        XCTAssertEqual(measured.height, 0, accuracy: 0.5)
    }
}
