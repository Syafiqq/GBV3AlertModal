import Foundation

/// An input dialog with a date picker (e.g. the app's "date-picker worksheet"). Same pattern as
/// `TextInputDialog`: `Sendable` value config in, the renderer builds a `UIDatePicker` as the
/// modal's `subtitleCustomView`, and the result carries the picked date.
public struct DatePickerDialog: ModalDescriptor {
    public enum Result: Sendable, Equatable {
        case submitted(Date)
        case dismissed
    }
    public static var dismissedResult: Result { .dismissed }

    public var title: AttributedString?
    public var initialDate: Date
    public var primary: String
    public var secondary: String?

    public init(
        title: String? = nil,
        initialDate: Date,
        primary: String,
        secondary: String? = nil
    ) {
        self.title = title.map(AttributedString.init)
        self.initialDate = initialDate
        self.primary = primary
        self.secondary = secondary
    }
}
