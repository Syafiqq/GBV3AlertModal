import GBV3AlertModalCore

import Foundation
import SwiftUI

// The BESPOKE-CONTENT ports: the three real shapes whose content is not expressible in any
// `AlertDialog` slot, rendered through the SAME seam the input dialogs already use
// (`SwiftUIModalRenderer+InputViews.swift`).
//
//   descriptor (Core/, pure value)   SwiftUI body (here, on the renderer)
//   ------------------------------   ------------------------------------------------
//   BadgeDialog                      BadgeModalView         — badge grid
//   LoadingDialog                    LoadingModalView       — busy primary button
//   SatisfactionDialog               SatisfactionModalView  — pick-one row + validation gate
//
// Every one of them WRAPS `AlertModalScaffold` (scrim + card + primary/secondary + close) and fills
// only its `@ViewBuilder` slot. None of them rebuilds card, scrim or buttons — that is the whole
// point of the scaffold, and it is why these bodies stay short.
//
// The scaffold is INSIDE each view, not around it, for the same reason it is inside
// `TextInputModalView`: the primary button has to read `@State` (a selected index) or a descriptor
// field (`isLoading`) that `ModalHost` cannot see.

extension SwiftUIModalRenderer {
    /// SwiftUI content for `BadgeDialog`. Registration shape, identical to `TextInputContent`:
    /// ```swift
    /// renderer.register(BadgeDialog.self, view: { descriptor, resolve in
    ///     SwiftUIModalRenderer.BadgeContent.make(
    ///         for: descriptor, tokens: ModalTokens(from: badgeProperties), resolve: resolve
    ///     )
    /// })
    /// ```
    @MainActor public enum BadgeContent {
        public static func make(
            for descriptor: BadgeDialog,
            tokens: ModalTokens = .standard,
            resolve: @escaping (BadgeDialog.Result) -> Void
        ) -> AnyView {
            AnyView(BadgeModalView(descriptor: descriptor, tokens: tokens, resolve: resolve))
        }
    }

    /// SwiftUI content for `LoadingDialog`. See `BadgeContent` for the registration shape.
    @MainActor public enum LoadingContent {
        public static func make(
            for descriptor: LoadingDialog,
            tokens: ModalTokens = .standard,
            resolve: @escaping (LoadingDialog.Result) -> Void
        ) -> AnyView {
            AnyView(LoadingModalView(descriptor: descriptor, tokens: tokens, resolve: resolve))
        }
    }

    /// SwiftUI content for `SatisfactionDialog`. See `BadgeContent` for the registration shape.
    @MainActor public enum SatisfactionContent {
        public static func make(
            for descriptor: SatisfactionDialog,
            tokens: ModalTokens = .standard,
            resolve: @escaping (SatisfactionDialog.Result) -> Void
        ) -> AnyView {
            AnyView(SatisfactionModalView(descriptor: descriptor, tokens: tokens, resolve: resolve))
        }
    }
}

// MARK: - Badge grid

/// `BadgeDialog` in SwiftUI: optional banner, title, subtitle, then the badge grid — all inside the
/// shared `AlertModalScaffold`. Covers all three real badge shapes (see `BadgeDialog`); the slots a
/// given shape does not use simply render nothing.
@MainActor
public struct BadgeModalView: View {
    public let descriptor: BadgeDialog
    public let tokens: ModalTokens
    public let resolve: (BadgeDialog.Result) -> Void

    public init(
        descriptor: BadgeDialog,
        tokens: ModalTokens = .standard,
        resolve: @escaping (BadgeDialog.Result) -> Void
    ) {
        self.descriptor = descriptor
        self.tokens = tokens
        self.resolve = resolve
    }

    public var body: some View {
        AlertModalScaffold(
            tokens: tokens,
            layoutPreset: descriptor.badges.contains(where: { $0.detail != nil }) ? .customSubtitle : .default,
            primaryTitle: descriptor.primary,
            onPrimary: { resolve(Self.result(for: .primary)) },
            secondaryTitle: descriptor.secondary,
            onSecondary: { resolve(Self.result(for: .secondary)) },
            showClose: descriptor.showCloseButton,
            onClose: { resolve(Self.result(for: .close)) },
            // Same guard-inside-the-closure spelling `SwiftUIAlertModal` uses, so the scrim stays
            // interactive-but-inert rather than needing an optional closure at the call site.
            onOverlayTap: { if descriptor.closeOnTapOverlay { resolve(Self.result(for: .close)) } },
            // **The badge banner can widen its column now, as its UIKit counterpart always could.**
            //
            // This argument used to be omitted, and the omission was recorded in a comment rather
            // than fixed: without it `bannerGeometry` stayed `.zero`, so a badge banner could never
            // widen the content column or the card however wide its artwork was. UIKit's
            // counterpart DOES widen both — `BadgeDialog` has a real view graph
            // (`UIKitModalRenderer.BadgeHolder.make` builds a genuine `banner: UIImage` and
            // `GBAlertModal` renders it through the same `vwBanner`/`ivBanner` constraints as every
            // other shape), and there `ivBanner`'s compression resistance (750) outranks
            // `svContentContainer`'s `width == fixedWidth` at `.medium` (500).
            //
            // **Why this is safe on a path the differential gate cannot reach.** `bannerGeometry`'s
            // column is `min(max(demand, contentMaxWidth), ceiling)`, so it is `contentMaxWidth`
            // itself for any artwork narrower than the column — and both places the value lands
            // (`AlertModalScaffold`'s card cap and its content-container frame) take a `max` against
            // the number they already used. The change is therefore the IDENTITY for every shape
            // whose artwork fits, which is every badge shape that ships: the one real banner asset,
            // `img_badge_multi_achievement`, is 160x160pt inside a 256pt column, and
            // `badge-unlock-single` carries no banner at all. `.zero` in, `.zero` out, for the
            // no-banner shapes. What changes is only the case that was WRONG.
            hasBanner: descriptor.banner != nil
        ) {
            bannerView
            titleView
            subtitleView
            badgeGrid
        }
    }

    @ViewBuilder
    private var bannerView: some View {
        if let banner = descriptor.banner {
            // `bundle:` so the DRAWN image and the artwork size the scaffold was handed above
            // resolve through the same lookup — `ModalImage.pointSize` is bundle-aware, and a row
            // that measured a bundle-scoped asset while drawing from `Bundle.main` would size a
            // column for a picture it never renders. `Image(_:bundle:)` with a nil bundle IS
            // `Image(_:)`, so this is byte-identical for every asset that names no bundle, which is
            // every asset the app ships.
            Image(banner.assetName, bundle: banner.bundle)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: tokens.bannerMaxHeight)
                // `ModalBannerGeometry` (the `ViewModifier`) is gone — Task 3 dropped it, and
                // neutralised `bannerLayout.height` (measured inert in UIKit,
                // `BannerGeometryTruthTests`); the field itself has since been deleted. This
                // bespoke banner did NOT gain the slot/image split `SwiftUIAlertModal`'s standard
                // banner got: `BadgeDialog` DOES have a real UIKit view graph behind it
                // (`UIKitModalRenderer.BadgeHolder.make` builds a genuine `banner: UIImage` and
                // `GBAlertModal` renders it through the same `vwBanner`/`ivBanner` constraints as
                // every other shape) — it is simply UNTESTED, not ungraphed: `DifferentialGeometry`
                // excludes all three bespoke descriptors because they render through their OWN
                // `AlertModalScaffold` wrapper (`BadgeModalView`) rather than through
                // `SwiftUIAlertModal`, which is the one the gate measures. So this keeps the two live
                // fields inline, branching exactly as the deleted `ModalBannerGeometry` did — a nil
                // field adds NO modifier, rather than relying on `.aspectRatio(nil, ...)` /
                // `.frame(maxHeight: nil)` being no-ops, which was the assumption that type existed
                // to avoid making.
                //
                // This banner also lost its `.frame(height: bannerFixedHeight)` pin along with every
                // other banner in this module (Task 3): UIKit ignores that field on both paths
                // (`BannerGeometryTruthTests.test_bannerFixedHeight_isInert_*`), so dropping it here
                // is correct — but it is a real behavioural change to a path the differential gate
                // does not reach, for the reason above.
                //
                // The COLUMN, though, is no longer part of that gap: the scaffold above is handed
                // `descriptor.banner?.pointSize`, so wide artwork widens this card exactly as it
                // widens `SwiftUIAlertModal`'s. Covered by `BespokeBannerColumnTests`, which hosts
                // this view and measures the card probe rather than trusting the wiring.
                .padding(.bottom, tokens.gapBelowBanner)
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if let title = descriptor.title {
            // Descriptor text is rendered directly after any migration-boundary conversion.
            Text(title)
                .font(tokens.titleFont.font)
                .foregroundColor(tokens.palette.titleText)
                .multilineTextAlignment(.center)
                .padding(.bottom, tokens.gapBelowTitle)
        }
    }

    @ViewBuilder
    private var subtitleView: some View {
        if let subtitle = descriptor.subtitle {
            // Preserve the descriptor's Core `AttributedString` without a renderer-side bridge.
            Text(subtitle)
                .font(tokens.subtitleFont.font)
                .foregroundColor(tokens.palette.subtitleText)
                .multilineTextAlignment(.center)
                .padding(.bottom, tokens.gapBelowSubtitle)
        }
    }

    @ViewBuilder
    private var badgeGrid: some View {
        if descriptor.badges.count == 1, let badge = descriptor.badges.first {
            badgeCell(badge)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, tokens.gapBelowSubtitle)
        } else if !descriptor.badges.isEmpty {
            // `LazyVGrid` is iOS 14+, inside the iOS 15 floor. `.adaptive` lets several badges
            // wrap — the single-badge case above must bypass it because an adaptive grid
            // resolves this card width to two columns and places its only item in the leading one.
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: 12)],
                spacing: 12
            ) {
                ForEach(descriptor.badges) { badge in
                    badgeCell(badge)
                }
            }
            .padding(.bottom, tokens.gapBelowSubtitle)
        }
    }

    private func badgeCell(_ badge: BadgeDialog.Badge) -> some View {
        VStack(spacing: 6) {
            if let artwork = badge.artwork {
                Image(artwork.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
            } else if badge.detail != nil {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 1, green: 0.65, blue: 0.25))
                    .frame(width: 96, height: 96)
            }
            Text(badge.name)
                .font(badge.detail == nil ? tokens.subtitleFont.font : .system(size: 16, weight: .bold))
                .foregroundColor(tokens.palette.titleText)
                .multilineTextAlignment(.center)
            if let detail = badge.detail {
                Text(detail)
                    .font(tokens.subtitleFont.font)
                    .foregroundColor(tokens.palette.subtitleText)
                    .multilineTextAlignment(.center)
                    // Wrap rather than truncate on the 256/300pt card.
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// `ActionType` → the descriptor's result vocabulary. Kept out of the body (the same split
    /// `TextInputModalView.result` uses) so a test can call it without hosting a view.
    nonisolated static func result(for action: ModalAction) -> BadgeDialog.Result {
        switch action {
        case .primary: return .viewBadges
        case .secondary, .close: return .dismissed
        }
    }
}

// MARK: - Loading state

/// `LoadingDialog` in SwiftUI: an ordinary title/subtitle confirm whose primary button switches to a
/// spinner when `descriptor.isLoading`. The spinner and the disabling are `AlertModalScaffold`'s
/// (`isPrimaryLoading`) — this view only supplies the flag, which is the point: the loading state
/// was already built, it just had no descriptor able to ask for it.
@MainActor
public struct LoadingModalView: View {
    public let descriptor: LoadingDialog
    public let tokens: ModalTokens
    public let resolve: (LoadingDialog.Result) -> Void

    public init(
        descriptor: LoadingDialog,
        tokens: ModalTokens = .standard,
        resolve: @escaping (LoadingDialog.Result) -> Void
    ) {
        self.descriptor = descriptor
        self.tokens = tokens
        self.resolve = resolve
    }

    public var body: some View {
        AlertModalScaffold(
            tokens: tokens,
            primaryTitle: descriptor.primary,
            isPrimaryLoading: descriptor.isLoading,
            onPrimary: { resolve(Self.result(for: .primary)) },
            secondaryTitle: descriptor.secondary,
            onSecondary: { resolve(Self.result(for: .secondary)) },
            showClose: descriptor.showCloseButton,
            onClose: { resolve(Self.result(for: .close)) },
            onOverlayTap: { if descriptor.closeOnTapOverlay { resolve(Self.result(for: .close)) } }
        ) {
            if let title = descriptor.title {
                Text(title)
                    .font(tokens.titleFont.font)
                    .foregroundColor(tokens.palette.titleText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, tokens.gapBelowTitle)
            }
            if let subtitle = descriptor.subtitle {
                Text(subtitle)
                    .font(tokens.subtitleFont.font)
                    .foregroundColor(tokens.palette.subtitleText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, tokens.gapBelowSubtitle)
            }
        }
    }

    nonisolated static func result(for action: ModalAction) -> LoadingDialog.Result {
        switch action {
        case .primary: return .confirmed
        case .secondary: return .cancelled
        case .close: return .dismissed
        }
    }
}

// MARK: - Satisfaction row

/// `SatisfactionDialog` in SwiftUI: a pick-one row inside the shared scaffold, with the primary
/// button gated on a selection. The library port of the example app's `SatisfactionDemoView`.
///
/// This is the seam's exemplar: `selectedIndex` is `@State` the VIEW owns, and the primary button
/// resolves the gate with it at tap time. No pre-registered `(ActionType) -> Result` route can carry
/// that value — which is exactly why `register(_:view:)` hands the view the gate itself.
@MainActor
public struct SatisfactionModalView: View {
    public let descriptor: SatisfactionDialog
    public let tokens: ModalTokens
    public let resolve: (SatisfactionDialog.Result) -> Void

    @State private var selectedIndex: Int?

    public init(
        descriptor: SatisfactionDialog,
        tokens: ModalTokens = .standard,
        resolve: @escaping (SatisfactionDialog.Result) -> Void
    ) {
        self.descriptor = descriptor
        self.tokens = tokens
        self.resolve = resolve
    }

    public var body: some View {
        AlertModalScaffold(
            tokens: tokens,
            primaryTitle: descriptor.primary,
            // THE VALIDATION GATE: nothing selected → the primary button is disabled.
            primaryEnabled: selectedIndex != nil,
            onPrimary: { resolve(Self.result(for: .primary, selectedIndex: selectedIndex)) },
            onClose: { resolve(Self.result(for: .close, selectedIndex: selectedIndex)) },
            onOverlayTap: {
                if descriptor.closeOnTapOverlay {
                    resolve(Self.result(for: .close, selectedIndex: selectedIndex))
                }
            }
        ) {
            if let title = descriptor.title {
                Text(title)
                    .font(tokens.titleFont.font)
                    .foregroundColor(tokens.palette.titleText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, tokens.gapBelowTitle)
            }
            HStack(spacing: 12) {
                // Indexed rather than `enumerated()`: the result is an INDEX, and `ForEach` over a
                // tuple sequence cannot destructure its element in the content closure.
                ForEach(descriptor.options.indices, id: \.self) { index in
                    optionButton(index: index, option: descriptor.options[index])
                }
            }
            .padding(.bottom, tokens.gapBelowSubtitle)
        }
    }

    private func optionButton(index: Int, option: SatisfactionDialog.Option) -> some View {
        let isSelected = selectedIndex == index
        return Button {
            selectedIndex = index
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.symbolName)
                    .font(.title3)
                Text(option.label)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    // Wrap to two lines instead of truncating on the 256pt card.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? tokens.palette.accent.opacity(0.15)
                    : tokens.palette.disabled.opacity(0.15)
            )
            .foregroundColor(isSelected ? tokens.palette.accent : tokens.palette.titleText)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    /// The selection-aware result mapping, pulled out of the body so it is assertable without
    /// hosting a view — the same split `TextInputModalView.result` uses. A primary tap with NOTHING
    /// selected is unreachable through the UI (the button is disabled) and maps to `.dismissed`
    /// rather than fabricating an index.
    nonisolated static func result(
        for action: ModalAction, selectedIndex: Int?
    ) -> SatisfactionDialog.Result {
        switch action {
        case .primary:
            guard let selectedIndex else { return .dismissed }
            return .submitted(index: selectedIndex)
        case .secondary, .close:
            return .dismissed
        }
    }
}

// MARK: - The bespoke banner's own layout (BadgeDialog only)

/// **`BadgeModalView.bannerView`'s counterpart to the deleted `ModalBannerGeometry`.**
///
/// This is NOT the standard banner path — `SwiftUIAlertModal`'s `BannerSlot` reads
/// `ModalTokens.bannerGeometry` instead (Task 3's slot/image split, verified against measured UIKit
/// output). This one still applies `ModalTokens.bannerLayout` (`aspectRatio` / `maxHeight`) directly
/// to the `Image`, exactly as the deleted `ModalBannerGeometry` did, because `BadgeDialog` sits
/// outside the differential gate (see the call site's comment) and nothing was asked to change here.
///
/// Each field is applied ONLY when `BannerLayout` supplies it — a nil field adds NO modifier at all.
/// `ModalBannerGeometry`'s doc stated exactly why this branching exists rather than passing the
/// optionals straight to `.aspectRatio(_:contentMode:)` / `.frame(maxHeight:)`: "Relying on
/// `.frame(height: nil)` / `.frame(maxHeight: nil)` being a no-op would be an assumption about
/// SwiftUI's flexible-frame behaviour; branching states the intent instead." `BadgeModalView` has no
/// differential test to catch that assumption being wrong, so the branching is restored rather than
/// re-introduced as an implicit nil-pass-through.
