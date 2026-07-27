import SwiftUI
import GBV3AlertModal

/// A pure-SwiftUI host that drives `SwiftUIAlertModal` with item-driven local `@State`.
/// No executor, no coordinator — this is the "does SwiftUI feel good to author here" prototype.
struct SwiftUIDemoScreen: View {
    /// Item-driven presentation: non-nil == a modal is shown. Single source of truth.
    @State private var active: AlertDialog?
    /// Last outcome, shown so the judgment run can see taps resolve.
    @State private var lastResult: String = "—"

    static let demoMinimal = AlertDialog(
        title: "You're all set",
        subtitle: "Your changes have been saved.",
        primary: "Got it"
    )

    static let demoFull = AlertDialog(
        image: ModalImage("img_illust_onboarding"),
        title: "Help us make your experience better",
        subtitle: "Take our quick survey and gain bubbles!",
        primary: "Proceed to feedback",
        secondary: "Not now",
        closeOnTapOverlay: true,
        showCloseButton: true
    )

    var body: some View {
        VStack(spacing: 16) {
            Text("Last result: \(lastResult)")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button("Minimal alert") { active = Self.demoMinimal }
            Button("Full alert") { active = Self.demoFull }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("SwiftUI Modal")
        .overlay {
            if let config = active {
                SwiftUIAlertModal(config: config) { result in
                    lastResult = "\(result)"
                    active = nil                 // caller owns dismissal; view never self-dismisses
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: active != nil)
    }
}
