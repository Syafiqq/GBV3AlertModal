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

    /// **The selectable range, and why the descriptor has to carry it.**
    ///
    /// The app's `date-picker worksheet` pins `minimumDate = tomorrow` and `maximumDate = +2 years`
    /// on the `UIDatePicker` it builds AT THE CALL SITE. A descriptor that cannot express that is a
    /// descriptor neither renderer can honour: both drew an unbounded wheel, so a SwiftUI adoption
    /// would happily return yesterday for a dialog whose whole purpose is scheduling forward. It was
    /// recorded as the `datePickerRange` catalog divergence and is a BEHAVIOURAL gap, not a visual
    /// one — the kind that surfaces as a backend rejecting a date rather than as a wrong-looking card.
    ///
    /// Optional on both ends: `nil` means unbounded in that direction, which is `UIDatePicker`'s own
    /// default and keeps every existing caller's behaviour unchanged.
    public var minimumDate: Date?
    public var maximumDate: Date?
    public var primary: String
    public var secondary: String?
    /// Tapping the scrim dismisses — the app's `date-picker-worksheet` shape sets it. See
    /// `TextInputDialog.closeOnTapOverlay`; appended last and defaulted for source compatibility.
    public var closeOnTapOverlay: Bool

    public init(
        title: String? = nil,
        initialDate: Date,
        minimumDate: Date? = nil,
        maximumDate: Date? = nil,
        primary: String,
        secondary: String? = nil,
        closeOnTapOverlay: Bool = false
    ) {
        self.title = title.map(AttributedString.init)
        self.initialDate = initialDate
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.primary = primary
        self.secondary = secondary
        self.closeOnTapOverlay = closeOnTapOverlay
    }
}
