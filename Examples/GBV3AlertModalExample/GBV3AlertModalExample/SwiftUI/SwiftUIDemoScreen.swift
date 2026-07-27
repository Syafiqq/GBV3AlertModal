import SwiftUI
import GBV3AlertModal

/// A pure-SwiftUI host that drives `SwiftUIAlertModal` with item-driven local `@State`.
/// No executor, no coordinator — this is the "does SwiftUI feel good to author here" prototype.
struct SwiftUIDemoScreen: View {
    /// Item-driven presentation: non-nil == a modal is shown. Single source of truth.
    @State private var active: AlertDialog?
    /// Last outcome, shown so the judgment run can see taps resolve.
    @State private var lastResult: String = "—"

    /// True while `active` is the loading-button (Gc2Gs) case — distinguishes it from the
    /// plain minimal/full cases, which share the same `active` overlay slot.
    @State private var isLoadingCase = false
    /// Presentation state for the primary spinner, owned entirely by this caller.
    @State private var isLoading = false
    /// Bumped on every primary tap (and every dismissal) so an in-flight async result can
    /// tell, via `shouldApply`, whether it's still the one that matters.
    @State private var generation = 0

    /// Validation-gate (Satisfaction) case: its own presentation flag, its own overlay slot —
    /// it's a bespoke view, not an `AlertDialog` config.
    @State private var showSatisfaction = false

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

    static let demoLoading = AlertDialog(
        title: "Generate your worksheet",
        subtitle: "This will use one credit.",
        primary: "Generate",
        secondary: "Cancel"
    )

    var body: some View {
        VStack(spacing: 16) {
            Text("Last result: \(lastResult)")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button("Minimal alert") { active = Self.demoMinimal }
            Button("Full alert") { active = Self.demoFull }
            Button("Loading button") { presentLoadingCase() }
            Button("Validation gate") { showSatisfaction = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("SwiftUI Modal")
        .overlay {
            if let config = active {
                SwiftUIAlertModal(config: config, isPrimaryLoading: isLoading) { result in
                    handle(result)
                }
                .transition(.opacity)
            }
            if showSatisfaction {
                SatisfactionDemoView { result in
                    switch result {
                    case .submitted(let index): lastResult = "satisfaction: \(index)"
                    case .dismissed:             lastResult = "satisfaction: dismissed"
                    }
                    showSatisfaction = false
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: active != nil)
        .animation(.easeInOut(duration: 0.2), value: showSatisfaction)
    }

    /// Opens the loading-button case, resetting any leftover loading state from a prior run
    /// (reset-on-reopen, per spec) and bumping `generation` to invalidate any stale in-flight task.
    private func presentLoadingCase() {
        isLoading = false
        generation += 1
        isLoadingCase = true
        active = Self.demoLoading
    }

    /// Routes a `SwiftUIAlertModal` outcome. For the loading case, a primary tap starts the
    /// async "generate" flow instead of dismissing immediately; every other outcome (and every
    /// other case) dismisses right away.
    private func handle(_ result: AlertDialog.Result) {
        guard isLoadingCase else {
            lastResult = "\(result)"
            active = nil
            return
        }
        guard result == .primary else {
            // secondary/close/overlay during the loading case: cancel any in-flight generation
            generation += 1
            isLoading = false
            isLoadingCase = false
            lastResult = "\(result)"
            active = nil
            return
        }
        startGenerating()
    }

    private func startGenerating() {
        generation += 1
        let captured = generation
        isLoading = true
        lastResult = "generating…"
        // @MainActor: this method is nonisolated, so pin the post-sleep @State mutations to the main actor.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard shouldApply(resultGeneration: captured, currentGeneration: generation) else { return }
            isLoading = false
            isLoadingCase = false
            active = nil
            lastResult = "primary (generated)"
        }
    }
}
