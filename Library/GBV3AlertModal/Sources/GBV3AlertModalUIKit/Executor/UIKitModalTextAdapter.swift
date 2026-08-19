import GBV3AlertModalCore

import Foundation
import UIKit

/// Converts Core descriptor text into the legacy holder's plain/attributed representation.
/// Unknown non-UIKit scopes deliberately degrade to plain text.
enum UIKitModalTextAdapter {
    static func split(_ text: AttributedString?) -> (plain: String?, attributed: NSAttributedString?) {
        guard let text else { return (nil, nil) }
        let hasUIKitStyling = text.runs.contains { run in
            run[AttributeScopes.UIKitAttributes.ForegroundColorAttribute.self] != nil
                || run[AttributeScopes.UIKitAttributes.FontAttribute.self] != nil
                || run[AttributeScopes.FoundationAttributes.LinkAttribute.self] != nil
        }
        guard hasUIKitStyling else { return (String(text.characters), nil) }
        return (nil, NSAttributedString(text))
    }
}
