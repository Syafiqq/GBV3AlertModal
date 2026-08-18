import GBV3AlertModalCore
import GBV3AlertModalSwiftUI
import GBV3AlertModalUIKit

import CoreText
import Foundation
import SwiftUI
import UIKit

/// Converts legacy UIKit attribute scopes at the temporary cross-backend migration boundary.
enum LegacyAttributedTextAdapter {
    static func swiftUIRenderable(_ text: NSAttributedString) -> AttributedString {
        swiftUIRenderable(AttributedString(text))
    }

    static func swiftUIRenderable(_ text: AttributedString) -> AttributedString {
        var converted = text
        for run in text.runs {
            let range = run.range
            if converted[range].swiftUI.foregroundColor == nil,
               let color = converted[range].uiKit.foregroundColor {
                converted[range].swiftUI.foregroundColor = Color(uiColor: color)
            }
            if converted[range].swiftUI.font == nil,
               let font = converted[range].uiKit.font {
                converted[range].swiftUI.font = Font(font as CTFont)
            }
        }
        return converted
    }
}
