import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **The type that answers §3b's open question: a font a SwiftUI caller states that the library can
/// also measure.**
///
/// What is worth testing here is narrow, and it is not "does `.system(size: 24)` produce a 24pt
/// font". It is the two places a font can be drawn as one thing and measured as another — which is
/// the exact defect Pass 1 found in the title floor, one level up.
@MainActor
final class ModalFontTests: XCTestCase {

    // MARK: - The system path

    func test_system_carriesSizeAndWeight() {
        let font = ModalFont.system(size: 24, weight: .bold).uiFont

        XCTAssertEqual(font.pointSize, 24)
        XCTAssertEqual(font, .systemFont(ofSize: 24, weight: .bold))
    }

    func test_everyWeight_mapsToItsUIKitCounterpart() {
        // `CaseIterable` so a tenth case added to `Weight` cannot be left out of the mapping without
        // someone having to write a line here.
        let expected: [ModalFont.Weight: UIFont.Weight] = [
            .ultraLight: .ultraLight, .thin: .thin, .light: .light, .regular: .regular,
            .medium: .medium, .semibold: .semibold, .bold: .bold, .heavy: .heavy, .black: .black
        ]
        XCTAssertEqual(
            Set(expected.keys), Set(ModalFont.Weight.allCases),
            "a Weight case is not covered by this test"
        )
        for (weight, uiWeight) in expected {
            XCTAssertEqual(
                ModalFont.system(size: 16, weight: weight).uiFont,
                .systemFont(ofSize: 16, weight: uiWeight),
                "\(weight) does not map to \(uiWeight)"
            )
        }
    }

    /// `regular`, matching `Font.system(size:)`'s own default — a caller who omits the weight on one
    /// side and not the other must not get two different faces.
    func test_system_defaultsToRegular() {
        XCTAssertEqual(ModalFont.system(size: 16), ModalFont.system(size: 16, weight: .regular))
    }

    // MARK: - The custom path, and its fallback

    func test_custom_resolvesAnInstalledFaceByName() throws {
        // A face guaranteed present on every simulator and device, so this test is about the
        // resolution path and not about which fonts a CI image happens to ship.
        let name = try XCTUnwrap(UIFont.familyNames.contains("Helvetica") ? "Helvetica-Bold" : nil)

        let font = ModalFont.custom(name, size: 24).uiFont

        XCTAssertEqual(font.fontName, name)
        XCTAssertEqual(font.pointSize, 24)
    }

    /// **The fallback is the whole reason this type stores a `UIFont` rather than deriving one.**
    ///
    /// `UIFont(name:size:)` returns nil for a face that is not installed; `Font.custom` silently
    /// falls back to the system font and DRAWS SOMETHING. If measurement refused, or measured the
    /// intended-but-absent face, the library would once again be measuring a font it is not drawing
    /// — which is precisely the bug class `ModalFont` exists to make unwritable.
    func test_custom_fallsBackToTheSystemFont_whichIsWhatSwiftUIDraws() {
        let font = ModalFont.custom("NoSuchFaceShipsWithThisOS", size: 24).uiFont

        XCTAssertEqual(font, .systemFont(ofSize: 24))
        XCTAssertEqual(font.pointSize, 24, "the requested SIZE survives the fallback")
    }

    // MARK: - The invariant the type exists for

    /// The drawn font and the measured font are ONE value with two projections, so no test can put
    /// them out of step — but the derivation must be the platform's own bridge and not a
    /// reconstruction, because a reconstruction is where a guess would re-enter.
    func test_theDrawnFont_isDerivedFromTheMeasuredOne_viaThePlatformBridge() {
        let uiFont = UIFont.systemFont(ofSize: 19, weight: .semibold)

        XCTAssertEqual(ModalFont(uiFont).font, Font(uiFont))
        XCTAssertEqual(ModalFont(uiFont).uiFont, uiFont)
    }

    /// The one that would have caught the old `ModalTokens.standard` hazard: a font stated one way
    /// and a font stated the other way must be the same value, not merely look alike.
    func test_aSystemFontStatedNatively_equalsTheSameFontArrivingFromProperties() {
        let viaProperties = ModalTokens(
            from: GBAlertModal.Properties(titleFont: .systemFont(ofSize: 24, weight: .bold))
        ).titleFont

        XCTAssertEqual(viaProperties, .system(size: 24, weight: .bold))
    }
}
