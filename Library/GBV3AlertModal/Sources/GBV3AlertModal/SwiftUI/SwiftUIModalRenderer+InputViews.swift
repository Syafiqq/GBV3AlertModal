import Foundation // `Date` / `AttributedString` — the descriptors' own vocabulary.
import SwiftUI
import UIKit // `WheelDatePicker` only — see its own doc for why this is a deliberate, owner-approved
             // exception to this file's usual UIKit-free rule, not a quiet regression.

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

/// A raw `UIDatePicker` (`.date` mode, `.wheels` style), pinned by the ordinary SwiftUI
/// `UIViewRepresentable` hosting contract — NOT the built-in `SwiftUI.DatePicker(.wheel)`.
///
/// **Why this exists — an owner-approved exception, not a quiet regression.** `SwiftUI.DatePicker`
/// styled `.wheel` wraps `UIPickerView`/`UIDatePicker` through Apple's own PRIVATE bridge, and that
/// bridge does not forward any SwiftUI-level frame constraint down to the real picker — confirmed
/// on real device, three separate ways: `.frame(maxWidth:)` (a proposal, expected to fail), an
/// EXACT `.frame(width:)` (a real override for ordinary SwiftUI content — still failed), and an
/// `.overlay()`-based base-view technique that should not have been able to fail by SwiftUI's own
/// documented `overlay(content:)` contract — still failed. A controlled placeholder swap confirmed
/// the picker (not `Properties`, not the scaffold, not anything else in this shape) is what
/// corrupts `AlertModalScaffold`'s row: `buttonsMatchParent` sizes the primary/secondary buttons to
/// whatever that row reports, and the built-in picker was reporting something the row never asked
/// for, flush to the card edge.
///
/// This works because a representable WE author goes through the ORDINARY `UIViewRepresentable`
/// hosting contract, which DOES apply SwiftUI's computed frame to the underlying `UIView` directly
/// — no opaque bridge in the way. `UIDatePicker`'s own `.wheels` layout then reflows its
/// month/day/year columns to fit whatever width it is actually given, the same way it already does
/// at the real production call site (`GeniePresets.datePickerWorksheet()` in this repo's own test
/// fixtures) and the same way UIKit's own gallery entry for this shape already renders.
///
/// Deliberately on `SwiftUIPurityTests`'s `permittedUIKitImporters` allow-list with this file's
/// name and this reason, rather than adding a silent import: the allow-list's whole point is that a
/// new UIKit dependency is a decision, made by editing that list, not a line added at the top of a
/// file (see that test's own doc).
struct WheelDatePicker: UIViewRepresentable {
    @Binding var date: Date
    let minimumDate: Date?
    let maximumDate: Date?

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.minimumDate = minimumDate
        picker.maximumDate = maximumDate
        picker.date = date
        picker.addTarget(
            context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged
        )
        return picker
    }

    /// `date` is written back only when it actually differs — `UIDatePicker.date` round-trips
    /// through calendar/timezone normalization, so writing it unconditionally on every SwiftUI
    /// update pass (which `updateUIView` gets called on for reasons unrelated to the date changing)
    /// can fight the user mid-scroll.
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        if uiView.date != date { uiView.date = date }
        uiView.minimumDate = minimumDate
        uiView.maximumDate = maximumDate
    }

    func makeCoordinator() -> Coordinator { Coordinator(date: $date) }

    final class Coordinator: NSObject {
        let date: Binding<Date>
        init(date: Binding<Date>) { self.date = date }
        @objc func dateChanged(_ sender: UIDatePicker) { date.wrappedValue = sender.date }
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
            // `WheelDatePicker`, not `SwiftUI.DatePicker` — see its own doc for why. Unlike the
            // four-branch dance the built-in type needed (no single initialiser takes two optional
            // bounds), `UIDatePicker.minimumDate`/`.maximumDate` are already optional, so the
            // descriptor's range passes straight through.
            WheelDatePicker(
                date: $date, minimumDate: descriptor.minimumDate, maximumDate: descriptor.maximumDate
            )
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
