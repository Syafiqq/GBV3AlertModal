import Foundation // `Date` / `AttributedString` — the descriptors' own vocabulary.
import SwiftUI

// The SwiftUI mirror of `UIKitModalRenderer+InputHolders.swift`, one-for-one:
//
//   UIKit                                   SwiftUI
//   ----------------------------------      ------------------------------------------
//   TextInputHolder.make(for:resolve:)      TextInputContent.make(for:tokens:resolve:)
//   DatePickerHolder.make(for:resolve:)     DatePickerContent.make(for:tokens:resolve:)
//   UITextField in subtitleCustomView       TextField in AlertModalScaffold's body slot
//   UIDatePicker in subtitleCustomView      DatePicker in AlertModalScaffold's body slot
//   read `field.text` in holder.completion  read `@State text` in the scaffold's onPrimary
//
// Both sides read the live value AT TAP TIME and hand it to the renderer's resolve gate, which is
// the only way `.submitted(<value>)` can be produced at all. The descriptors themselves are
// untouched, pure `Sendable` value types in `Core/` (decision D1) — every view lives out here.

extension SwiftUIModalRenderer {
    /// SwiftUI content for `TextInputDialog` — the counterpart of
    /// `UIKitModalRenderer.TextInputHolder`, shaped for `register(_:view:)`:
    ///
    /// ```swift
    /// renderer.register(TextInputDialog.self, view: { descriptor, resolve in
    ///     SwiftUIModalRenderer.TextInputContent.make(
    ///         for: descriptor, tokens: ModalTokens(from: properties), resolve: resolve
    ///     )
    /// })
    /// ```
    ///
    /// `tokens` is passed in (rather than read off the presentation) for the same reason the UIKit
    /// registration closure captures its `Properties`: the builder signature carries the descriptor
    /// and the gate, nothing else. Callers with real `Properties` should pass
    /// `ModalTokens(from: properties)` so the card matches every other modal.
    @MainActor public enum TextInputContent {
        public static func make(
            for descriptor: TextInputDialog,
            tokens: ModalTokens = .standard,
            resolve: @escaping (TextInputDialog.Result) -> Void
        ) -> AnyView {
            AnyView(TextInputModalView(descriptor: descriptor, tokens: tokens, resolve: resolve))
        }
    }

    /// SwiftUI content for `DatePickerDialog` — the counterpart of
    /// `UIKitModalRenderer.DatePickerHolder`. See `TextInputContent` for the registration shape.
    @MainActor public enum DatePickerContent {
        public static func make(
            for descriptor: DatePickerDialog,
            tokens: ModalTokens = .standard,
            resolve: @escaping (DatePickerDialog.Result) -> Void
        ) -> AnyView {
            AnyView(DatePickerModalView(descriptor: descriptor, tokens: tokens, resolve: resolve))
        }
    }
}

/// `TextInputDialog` rendered in SwiftUI: a `TextField` inside the SHARED modal chrome
/// (`AlertModalScaffold` — scrim, card, primary/secondary buttons, close), never a rebuilt card.
///
/// The scaffold is inside this view, not around it, precisely because the primary button has to
/// read `text`. That is the whole shape of the seam: `ModalHost` hands over the entire modal, and
/// this view resolves the gate with a value only it can see.
@MainActor
public struct TextInputModalView: View {
    public let descriptor: TextInputDialog
    public let tokens: ModalTokens
    /// The renderer's resolve gate. Calling it resolves the modal's token exactly once and tears
    /// the presentation down (the gate is resolve-once; later calls are inert).
    public let resolve: (TextInputDialog.Result) -> Void

    /// The live field value. Seeded ONCE from `descriptor.initialText` — `State(initialValue:)` is
    /// applied on first appearance only, so a later `update(_:to:)` rebuild will not stomp text the
    /// user has already typed (see `ModalHost` for why the view identity survives those rebuilds).
    @State private var text: String

    public init(
        descriptor: TextInputDialog,
        tokens: ModalTokens = .standard,
        resolve: @escaping (TextInputDialog.Result) -> Void
    ) {
        self.descriptor = descriptor
        self.tokens = tokens
        self.resolve = resolve
        _text = State(initialValue: descriptor.initialText)
    }

    public var body: some View {
        AlertModalScaffold(
            tokens: tokens,
            primaryTitle: descriptor.primary,
            onPrimary: { resolve(Self.result(for: .primary, text: text)) },
            secondaryTitle: descriptor.secondary,
            onSecondary: { resolve(Self.result(for: .secondary, text: text)) },
            onClose: { resolve(Self.result(for: .close, text: text)) },
            // Same guard-inside-the-closure spelling `SwiftUIAlertModal` uses. The UIKit path gets
            // this from `holder.closeOnTapOverlay` (`TextInputHolder`); both now read the same
            // descriptor field, so a scrim tap means the same thing on both backends.
            onOverlayTap: {
                if descriptor.closeOnTapOverlay { resolve(Self.result(for: .close, text: text)) }
            }
        ) {
            titleView
            // `RoundedBorderTextFieldStyle()` spelled out rather than `.roundedBorder`: the concrete
            // style type is iOS 13+, which is unambiguously inside the iOS 15 floor.
            TextField(descriptor.placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(height: 44)               // same 44pt the UIKit holder constrains the field to
                .padding(.bottom, tokens.gapBelowSubtitle)
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if let title = descriptor.title {
            // `AttributedTextBridge`, not the raw descriptor value — see
            // `SwiftUIAlertModal.bridgedTitle`'s doc for why an unwrapped `Text(title)` silently
            // drops a caller's UIKit-scoped styling.
            Text(AttributedTextBridge.swiftUIRenderable(title))
                .font(tokens.titleFont.font)
                .foregroundColor(tokens.palette.titleText)
                .multilineTextAlignment(.center)
                .padding(.bottom, tokens.gapBelowTitle)
        }
    }

    /// `ActionType` + the live field value → the descriptor's own result. Byte-for-byte the switch
    /// `UIKitModalRenderer.TextInputHolder` performs inside `holder.completion`; kept out of the
    /// view body (the same split `SwiftUIAlertModal.subtitlePayload` uses) so it is a plain function
    /// a test can call without hosting a view hierarchy. The two must stay identical.
    ///
    /// `nonisolated`: it is pure, so it has no business borrowing the view's main-actor isolation.
    nonisolated static func result(
        for action: GBAlertModal.ActionType, text: String
    ) -> TextInputDialog.Result {
        switch action {
        case .primary: return .submitted(text)
        case .secondary, .close: return .dismissed
        }
    }
}

/// `DatePickerDialog` rendered in SwiftUI: a `DatePicker` inside the shared `AlertModalScaffold`
/// chrome. Same shape as `TextInputModalView` — see it for why the scaffold lives in here.
@MainActor
public struct DatePickerModalView: View {
    public let descriptor: DatePickerDialog
    public let tokens: ModalTokens
    public let resolve: (DatePickerDialog.Result) -> Void

    /// The live picker value; seeded once from `descriptor.initialDate`.
    @State private var date: Date

    public init(
        descriptor: DatePickerDialog,
        tokens: ModalTokens = .standard,
        resolve: @escaping (DatePickerDialog.Result) -> Void
    ) {
        self.descriptor = descriptor
        self.tokens = tokens
        self.resolve = resolve
        _date = State(initialValue: descriptor.initialDate)
    }

    public var body: some View {
        AlertModalScaffold(
            tokens: tokens,
            primaryTitle: descriptor.primary,
            onPrimary: { resolve(Self.result(for: .primary, date: date)) },
            secondaryTitle: descriptor.secondary,
            onSecondary: { resolve(Self.result(for: .secondary, date: date)) },
            onClose: { resolve(Self.result(for: .close, date: date)) },
            onOverlayTap: {
                if descriptor.closeOnTapOverlay { resolve(Self.result(for: .close, date: date)) }
            }
        ) {
            titleView
            // `.date` only + wheels — the same two choices `DatePickerHolder` makes
            // (`datePickerMode = .date`, `preferredDatePickerStyle = .wheels`).
            // `WheelDatePickerStyle` is iOS 13+, safely inside the iOS 15 floor.
            // The descriptor's range, honoured the way `DatePickerHolder` honours it. SwiftUI has
            // no single initialiser taking two optional bounds, so the four cases are spelled out —
            // `PartialRangeFrom`/`PartialRangeThrough` are what express "one end only".
            datePicker
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                // An EXACT fixed frame, not `.frame(maxWidth:)`. `maxWidth` is a PROPOSAL — it caps
                // what's offered down to the child, but a rigid/UIKit-bridged child (`WheelDatePickerStyle`
                // wraps a real `UIPickerView`) can still report a bigger size back UP to its parent
                // regardless, and SwiftUI lets that propagate. `.clipped()` only trims what's DRAWN;
                // it does nothing to the SIZE used for layout. Confirmed on-device with a border
                // diagnostic (`AlertModalScaffold.card()`'s row-level border split into two
                // disconnected rectangles exactly where the picker sat — its native size was
                // corrupting the row's own reported width, and `buttonsMatchParent` faithfully copied
                // that onto the buttons, which is why they read as unpadded). An EXACT `width:` is a
                // real override — the view reports precisely that number to its parent no matter what
                // its child wants — which `maxWidth` never was. 320 is still an unverified guess for
                // the NUMBER (does it avoid clipping the picker's own content); the MECHANISM (exact
                // vs max) is now confirmed.
                .frame(width: 320)
                .clipped()
                // GUARANTEED gap on top of the cap — the cap alone bounds the OVERFLOW, it does not
                // by itself leave any breathing room, so this is still needed. `contentPadding
                // .leftMin` (12pt) is this shape's own stated floor, not a new number.
                .padding(.horizontal, tokens.contentPadding.leftMin)
                .padding(.bottom, tokens.gapBelowSubtitle)
        }
    }

    /// `DatePicker` has a distinct initialiser per bound combination, so the descriptor's optional
    /// range becomes four branches rather than one expression. Unbounded is the default and matches
    /// `UIDatePicker`'s, so an existing caller that sets neither is unaffected.
    @ViewBuilder
    private var datePicker: some View {
        switch (descriptor.minimumDate, descriptor.maximumDate) {
        case let (minimum?, maximum?):
            DatePicker("", selection: $date, in: minimum...maximum, displayedComponents: [.date])
        case let (minimum?, nil):
            DatePicker("", selection: $date, in: minimum..., displayedComponents: [.date])
        case let (nil, maximum?):
            DatePicker("", selection: $date, in: ...maximum, displayedComponents: [.date])
        case (nil, nil):
            DatePicker("", selection: $date, displayedComponents: [.date])
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if let title = descriptor.title {
            // `AttributedTextBridge`, not the raw descriptor value — see
            // `SwiftUIAlertModal.bridgedTitle`'s doc for why an unwrapped `Text(title)` silently
            // drops a caller's UIKit-scoped styling.
            Text(AttributedTextBridge.swiftUIRenderable(title))
                .font(tokens.titleFont.font)
                .foregroundColor(tokens.palette.titleText)
                .multilineTextAlignment(.center)
                .padding(.bottom, tokens.gapBelowTitle)
        }
    }

    /// `ActionType` + the live picker value → the descriptor's own result. The switch
    /// `UIKitModalRenderer.DatePickerHolder` performs, verbatim. See `TextInputModalView.result`.
    nonisolated static func result(
        for action: GBAlertModal.ActionType, date: Date
    ) -> DatePickerDialog.Result {
        switch action {
        case .primary: return .submitted(date)
        case .secondary, .close: return .dismissed
        }
    }
}
