import SwiftUI
import Testing
import UIKit
@testable import GBV3AlertModal

struct LegacyAttributedTextAdapterTests {
    @Test
    func convertsLegacyForegroundColorAndFont() {
        var legacy = AttributedString("Styled")
        legacy.uiKit.foregroundColor = .red
        legacy.uiKit.font = .boldSystemFont(ofSize: 18)

        let adapted = LegacyAttributedTextAdapter.swiftUIRenderable(legacy)

        #expect(adapted.swiftUI.foregroundColor == Color(uiColor: .red))
        #expect(adapted.swiftUI.font != nil)
    }

    @Test
    func convertsMixedRunsIndependently() {
        var first = AttributedString("Red")
        first.uiKit.foregroundColor = .red
        var second = AttributedString("Blue")
        second.uiKit.foregroundColor = .blue
        first.append(second)

        let adapted = LegacyAttributedTextAdapter.swiftUIRenderable(first)
        let runs = Array(adapted.runs)

        #expect(runs.count == 2)
        #expect(runs[0].swiftUI.foregroundColor == Color(uiColor: .red))
        #expect(runs[1].swiftUI.foregroundColor == Color(uiColor: .blue))
    }

    @Test
    func absentLegacyAttributesRemainAbsent() {
        let adapted = LegacyAttributedTextAdapter.swiftUIRenderable(AttributedString("Plain"))

        #expect(adapted.swiftUI.foregroundColor == nil)
        #expect(adapted.swiftUI.font == nil)
    }

    @Test
    func explicitSwiftUIAttributesWinOverLegacyAttributes() {
        var text = AttributedString("Styled")
        text.uiKit.foregroundColor = .red
        text.uiKit.font = .boldSystemFont(ofSize: 18)
        text.swiftUI.foregroundColor = .green
        text.swiftUI.font = .caption

        let adapted = LegacyAttributedTextAdapter.swiftUIRenderable(text)

        #expect(adapted.swiftUI.foregroundColor == .green)
        #expect(adapted.swiftUI.font == .caption)
    }

    @Test
    func acceptsLegacyNSAttributedString() {
        let legacy = NSAttributedString(
            string: "Styled",
            attributes: [.foregroundColor: UIColor.orange, .font: UIFont.systemFont(ofSize: 20)]
        )

        let adapted = LegacyAttributedTextAdapter.swiftUIRenderable(legacy)

        #expect(String(adapted.characters) == "Styled")
        #expect(adapted.swiftUI.foregroundColor == Color(uiColor: .orange))
        #expect(adapted.swiftUI.font != nil)
    }
}
