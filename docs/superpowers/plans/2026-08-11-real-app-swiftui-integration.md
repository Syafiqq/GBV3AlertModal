# Plan — wiring GBV3AlertModal's SwiftUI-native stack into the real app

**Scope of this pass, per the owner's own framing:** executor, queue/coordinator, root-level
wiring, main-tab-level wiring, and ONE shared baseline config (`.standard`/`.popup` only).
**Explicitly deferred:** the other ~15 per-shape presets (badge, streak, permission-alert, banner
variants, input dialogs, …) — those get registered incrementally, shape by shape, in later
sessions, the same way `UIKitFreeCatalogPresets.swift` grew in this repo's own example app.

Everything below is additive to `geniebook-student-ios-distribution` and changes nothing that
exists today — no existing call site moves in this pass. That repo is read-only to this repo's own
work; this plan describes what a *later* session should do *there*, quoting real paths so it's
directly actionable, without this repo touching it.

---

## 0. Two blockers to resolve FIRST — before any code

**0a. `Tuist/Package.swift` points at a dead path.**
```swift
.package(path: "/Users/engineering/Documents/c/msyafiqq/GBV3AlertModal"),
```
That directory does not exist on this machine at all (`ls` confirms nothing is there — not a
symlink, not a stale checkout). Meanwhile `Tuist/Package.resolved` has already resolved the
dependency from a DIFFERENT source:
```
"location" : "git@github-ssffqq:Syafiqq/GBV3AlertModal.git"
```
`Package.swift`'s declared source and `Package.resolved`'s actual resolved source disagree. This
will surface the moment anyone runs a clean `tuist generate` / package resolve on a machine where
that local path genuinely doesn't exist (which is: everywhere except whatever machine originally
authored that line). **Decide one of:**
- Point `Package.swift` at THIS repo's real location (`path:` to wherever `gb-v3-alert-modal` is
  checked out on the machine doing the integration work), for fast local iteration during this
  integration project, or
- Switch to the git dependency `Package.resolved` already expects (`git@github-ssffqq:Syafiqq/GBV3AlertModal.git`),
  pinned to a tag/branch, once this branch's work is merged and pushed.

Either is fine; leaving the mismatch in place is not — flagging it here so it isn't discovered
mid-integration as a mysterious build failure.

**0b. Confirm which renderer, before writing any config.** The app is **100% UIKit in production**
today (grep-verified: only 2 `import SwiftUI` files exist, both `#if DEBUG` dev-settings tooling —
`DevSettingConfigurationViewController.swift`/`DevSettingView.swift`). That single fact decides
§2 below: `WindowModalRenderer`, not `EmbeddedModalRenderer`. See §2 for why.

---

## 1. What's already there, exactly (so the plan below is additive, not guessed)

| Today | File |
|---|---|
| `GBV3AlertModal.globalProperties` assignment | `Geniebook/AppDelegate.swift:145-147`, inside `didFinishLaunchingWithOptions`, before window creation |
| `Presentation.UiKit.V3AlertModal.properties`/`.popupProperties`/`.holder` | `Common/Common/Custom/Components/AlertModal/V3AlertModal+GBV3AlertModal.swift` (memoized statics) |
| Root window | `Geniebook/AppDelegate.swift` — single `UIWindow`, no `SceneDelegate` subclass (iOS still creates a default `UIWindowScene` under the hood) |
| "Current window" resolution | `AppCompatHelper.keyWindow` (`Common/Common/Helpers/AppCompatHelper.swift:9`) — walks `connectedScenes` for `isKeyWindow` |
| Tab-bar root | `V1MainTabViewController` (`UITabBarController` subclass, split across `+PopupCampaign.swift`/`+Service.swift`/`+Coordinator.swift`) |
| "Coordinator" today | `V1MainTabViewController+Coordinator.swift`'s `CoordinatorManager` — narrow, handles exactly 2 subscription-page navigations, not a reusable abstraction. **No generic Coordinator/Router pattern exists anywhere in this app.** |
| Modal queueing today | Two independent, uncoordinated mechanisms: `DialogQueue.shared` (priority queue keyed by a 20-case `DialogType` enum, pauses when the tab bar isn't visible) and `DialogSessionEndQueue.shared` (single-slot, for session/network errors) — **45 call sites use one of these two; the other ~79 of the 124 total `V3AlertModal(...)` construction sites call `.show()` directly with zero coordination.** |

---

## 2. Executor + renderer — one instance, app-wide, `WindowModalRenderer`

**Why `WindowModalRenderer`, not `EmbeddedModalRenderer`:** `EmbeddedModalRenderer` needs a SwiftUI
host (`EmbeddedModalHost`) embedded inside *some screen's own SwiftUI view tree* — this app has no
SwiftUI screens to embed into. `WindowModalRenderer` installs a fresh `UIHostingController`
directly into a `UIWindow` per presentation (`WindowModalRenderer.swift:409-414`) — no SwiftUI
tree required anywhere in the host app. Its default `windowProvider: nil` fallback
(`Self.keyWindow`, `WindowModalRenderer.swift:427-432`) is **byte-for-byte the same lookup**
`AppCompatHelper.keyWindow` already does — so it's a like-for-like replacement for
`V3AlertModal.show()`'s attach-to-key-window behavior, not a new one. No custom `windowProvider`
closure is needed for a faithful first port.

**Construction — one object, one place, same lifecycle point `globalProperties` uses today.**
Introduce a small owner (name it `GBModalCenter`, or whatever fits this app's naming convention)
holding the renderer + executor + coordinator (§3) as `let`s, constructed once:

```swift
@MainActor
final class GBModalCenter {
    let renderer: WindowModalRenderer
    let executor: DefaultModalExecutor

    init(alertProperties: ModalProperties, popupProperties: ModalProperties) {
        let renderer = WindowModalRenderer(
            alertProperties: alertProperties,
            popupProperties: popupProperties
        )
        self.renderer = renderer
        self.executor = DefaultModalExecutor(renderer: renderer)
    }
}
```

Construct it in `AppDelegate.didFinishLaunchingWithOptions`, right beside the existing
`GBV3AlertModal.globalProperties = properties` line (`AppDelegate.swift:145-147`) — same trigger
point, same lifecycle guarantee (exists before any screen can present anything).

**How the app reaches it:** this app already uses Cleanse for DI (confirmed — call sites build
`Factory<...>`-injected view controllers). The idiomatic answer is a Cleanse module exposing
`GBModalCenter`/`ModalExecutor` as a singleton binding, so call sites request it through the
existing injection graph rather than reaching a bare global. A plain `static let shared` is an
acceptable interim step for the first pilot migration (§6) if standing up a full Cleanse module is
more than this pass wants to take on — either way, exactly ONE instance for the whole app process,
matching what `globalProperties` already is (a single process-wide config).

---

## 3. Coordinator — ONE `MainTabModalCoordinator`, owned by the main-tab screen — NOT the app's true root

**Correction from the owner:** `DialogQueue` belongs to the main-tab coordinator's scope, not the
app's literal root. Worth being precise about, because this app's "root" isn't one thing — there's
whatever runs before the tab bar exists at all (splash, auth) and then the tab-bar experience
itself, and `DialogQueue`'s own pause/resume signal
(`TopScreenDetector.mainTabBarDetector.screenVisibility`) only ever means the SECOND one. So: this
coordinator is scoped to, and owned by, the main-tab screen — the same object §4 already names
(`V1MainTabViewController` or whatever plays that role) — not a singleton constructed at
`AppDelegate` alongside the executor in §2.

`MainTabModalCoordinator`'s own doc calls this "installed by the main-tab screen that also drives
its visibility lifecycle" — that's exactly this: ONE instance, installed by the main-tab screen,
not one per individual tab within it. That matches `DialogQueue.shared`'s current shape (one
global singleton, paused as a whole when the tab bar isn't visible) — a per-tab coordinator is a
real future refinement once individual tabs need independent modal queues, not a requirement here.

**Left open, not assumed:** whatever runs BEFORE the tab bar (splash/auth) has no coordinator in
this plan at all — `GBModalCenter`'s executor (§2) still works there uncoordinated (the direct
path `DefaultModalExecutor` already falls back to with no `coordinator` installed), it just won't
get serial/priority/dedup behavior until/unless that flow gets its own coordinator too. Flagging
this rather than quietly assuming the main-tab coordinator covers the whole app.

**Construction site follows from the correction above:** NOT alongside the executor at
`AppDelegate` (§2) — inside `V1MainTabViewController`'s own init/`viewDidLoad`, reaching the
app-wide `GBModalCenter.executor` (already constructed by the time any screen loads) to install
the coordinator onto it:

```swift
// inside V1MainTabViewController, not AppDelegate
let coordinator = MainTabModalCoordinator(renderer: modalCenter.renderer)
modalCenter.executor.coordinator = coordinator
```

**Visibility wiring — reuse the signal `DialogQueue` already reads**, don't invent a new one:
wherever `TopScreenDetector.mainTabBarDetector.screenVisibility` is observed today to drive
`DialogQueue`'s pause/resume, add the same two calls:

```swift
// tab bar covered  → coordinator.hide()
// tab bar returned → coordinator.show()
```

**Unifying the app's two existing queues onto one coordinator's three knobs:**

| Today | `MainTabModalCoordinator` equivalent |
|---|---|
| `DialogType.priority` (hand-assigned `Int` per case) | `priority:` param on `executor.present(descriptor, priority:)` — same ordering semantics (`enqueue` inserts higher-priority first, stable FIFO within a tie) |
| `DialogQueue.pop(type:)` removing a specific queued/shown entry | `executor.dismiss(token)` |
| `DialogSessionEndQueue`'s single-slot "always show this now" | `interrupt: true` — jumps the queue and tears down whatever's currently shown, same effect, no second queue object needed |
| A dialog that must never double-show while one's already up (rare manual checks scattered per call site today) | `dedupKey:` — the coordinator drops a second `present` with a key already active, resolving it `.dismissed` immediately, no per-call-site bookkeeping needed |

That's a real simplification worth calling out to whoever does the eventual migration: **the two
separate queue types collapse into one coordinator's built-in vocabulary.** Not required to prove
that in this pass — just recorded here so nobody re-invents `DialogSessionEndQueue` as a second
coordinator later.

---

## 4. "MainTabCoordinator" — there isn't one to hook into; the tab controller owns this directly

Given §1's finding (no generic coordinator abstraction exists anywhere in the app), don't invent
one as a side effect of this integration — that's scope creep this plan doesn't need. The concrete,
minimal answer: **`V1MainTabViewController` owns `GBModalCenter`'s coordinator's visibility calls
directly**, the same way it (or whatever currently observes `TopScreenDetector`) already drives
`DialogQueue.shared`'s pause/resume today. No new coordinator TYPE is needed — the "coordinator"
role for this system is filled by wiring two calls into whatever hook already exists for
`DialogQueue`.

If a real per-tab coordinator abstraction gets built later for OTHER reasons (navigation, not
modals), revisit whether per-tab `MainTabModalCoordinator` instances become worth it then —
don't build it speculatively now.

---

## 5. Common config — the `.standard`/`.popup` baseline only

`WindowModalRenderer.init` takes `ModalProperties` (the SwiftUI-native type), not
`GBAlertModal.Properties` — so this is a genuinely NEW file, not a re-import of the existing UIKit
`properties`/`popupProperties`. It's a **direct, mechanical port** of the exact values already
confirmed in `V3AlertModal+GBV3AlertModal.swift` — same relationship
`GalleryPresets.standardModalProperties` already has to `GalleryPresets.properties` in this
repo's own example app (`Examples/GBV3AlertModalExample/GBV3AlertModalExample/Gallery/GalleryPresets.swift`),
just pointed at the real app's actual design tokens instead of the catalog's citation-mirrors of
them.

Real values, confirmed from `V3AlertModal+GBV3AlertModal.swift` (quoted verbatim in this
session's exploration — do not re-guess these):

```swift
// New file, e.g. Common/Common/Custom/Components/AlertModal/V3AlertModal+SwiftUINative.swift
extension Presentation.UiKit.V3AlertModal {

    static var modalProperties: ModalProperties {
        ModalProperties(
            baseTint: Color(uiColor: .Genie.legacyAccentSecondary),
            overlayColor: Color(uiColor: .Genie.legacyTextPrimaryNeutral).opacity(0.6),
            contentProperty: ModalProperties.ContentProperty(
                backgroundColor: .white,
                cornerRadius: 16,
                fixedWidthPortrait: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
                maxWidthPortrait: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
                fixedWidthLandscape: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
                maxWidthLandscape: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
                childShouldMatchParent: true
            ),
            margin: EdgeInsets(top: 40, leading: 20, bottom: 40, trailing: 20),
            padding: UIMinMaxEdgeInsets(top: (16, 24), left: (16, 32), bottom: (16, 24), right: (16, 32)),
            bannerRatio: 1,
            titleFont: .system(size: 24, weight: .bold),           // OpenSansBV.bold(24) — family gap, see note below
            titleColor: Color(uiColor: .Genie.primaryNavyBlueMain),
            subtitleFont: .system(size: 16),                        // OpenSansBV.regular(16)
            subtitleColor: Color(uiColor: .Genie.neutralMarker),
            buttonActionShouldMatchParent: true,
            buttonActionOrientation: .vertical,
            primaryActionStyle: .obliqueBottomLeft(
                ModalProperties.ActionStyle.ObliqueBottomLeftTheme(
                    unPressedColor: Color(uiColor: .Genie.primaryApricotMain),
                    pressedColor: Color(uiColor: .Genie.legacyAzureBright),
                    disabledColor: Color(uiColor: .Genie.neutralEraser),
                    shadowColor: Color(cgColor: UIColor.Genie.primaryApricotDark.cgColor),
                    titleColor: .white,
                    titleDisableColor: .white,
                    titleFont: .system(size: 16, weight: .heavy)    // extraBold(16) — nearest system weight
                )
            ),
            secondaryActionStyle: .plain(
                ModalProperties.ActionStyle.PlainTheme(
                    titleColor: Color(uiColor: .Genie.primaryApricotMain),
                    titleDisableColor: Color(uiColor: .Genie.neutralEraser),
                    titleFont: .system(size: 16, weight: .heavy)
                )
            ),
            closeButtonTint: .black,
            space: ModalProperties.ComponentSpace(banner: 8, title: 8, subtitle: 16, interButton: 8)
        )
    }

    static var popupModalProperties: ModalProperties {
        var properties = modalProperties
        properties.padding = UIMinMaxEdgeInsets(top: (20, 32), left: (20, 32), bottom: (20, 32), right: (20, 32))
        properties.titleFont = .system(size: 24, weight: .heavy)   // extraBold(24)
        return properties
    }
}
```

**One real gap, not glossed over:** `titleFont`/`subtitleFont`/button fonts above use `.system(...)`
placeholders, not the app's real `OpenSansBV` family — `ModalFont`/`Font` has no direct path from a
`UIFont` custom-name lookup the way `GallerySHSans` does in the example app. Resolving this
properly (a real `Font.custom("...", size:)` wired to whatever the app's actual registered
PostScript names for `OpenSansBV` are) is the ONE piece of `.standard`/`.popup` parity this plan
does not close — flagged here rather than shipped silently wrong, same discipline this whole
project already holds itself to. Small, scoped follow-up, not a blocker to wiring the rest.

---

## 6. Pilot migration — prove it end to end on 1-2 real call sites, don't touch the rest

Once §2-§5 are wired and NOTHING existing has moved, migrate one or two of the simplest, most
isolated call sites as a live proof, leaving the other ~120+ untouched:

- **`ChangePasswordsViewController.swift:156-170`** — direct `.show()`, no queue involvement, no
  custom `Properties` override, single primary action. Lowest-risk pilot: becomes
  `executor.presentAndWait(AlertDialog(...))` or `executor.present(...)`.
- **`AccountDeletionViewController.swift:192-224`** — direct `.show()` but WITH a custom
  `Properties.copy(...)` override (padding/fonts/space) — good second pilot because it proves the
  per-call-site override path, which is exactly what's deferred from §5 (per-shape presets) but
  needs to work even for the two presets already defined.

**Coexistence is safe, not just tolerable:** the old `V3AlertModal.show()` path and the new
executor path can run side by side for as long as the migration takes — they're independent
presentation mechanisms, and the only failure mode (two modals visually overlapping if both fire
concurrently) is a risk that **already exists today** between `DialogQueue` and the ~79 unqueued
direct `.show()` call sites. This migration doesn't introduce a new risk class, it just gives the
app a single mechanism to eventually collapse onto.

---

## 7. What this plan deliberately does NOT do

- Does not migrate any of the 124 existing `V3AlertModal(...)` call sites beyond the 1-2 §6 pilots.
- Does not define the ~15 remaining per-shape presets (badge, streak, permission-alert, banner
  variants, rename/date-picker inputs, oblique-red, credit-deduction, …) — each gets its own
  `ModalStyle` + `ModalProperties` registration later, the same incremental way
  `UIKitFreeCatalogPresets.swift` grew shape by shape in this repo's own example app.
- Does not retire `DialogQueue`/`DialogSessionEndQueue` — they keep serving their current call
  sites until those are individually migrated; §3's table exists so that migration has a
  ready-made mapping when it happens, not so it happens in this pass.
- Does not build a general Coordinator/Router abstraction — §4 explicitly declines that scope.
- Does not touch `geniebook-student-ios-distribution` itself — this document is the plan; a later
  session executes it there.

---

## 8. Open questions for the owner, before implementation starts

1. **Package dependency (§0a):** local `path:` for fast iteration, or cut over to the git remote
   `Package.resolved` already expects?
2. **DI shape (§2):** stand up a real Cleanse module for `GBModalCenter`, or is a `static let
   shared` acceptable for the pilot phase?
3. **Font family (§5):** what are `OpenSansBV`'s actual registered PostScript names, so
   `titleFont`/etc. can become real `Font.custom(...)` instead of `.system(...)` placeholders?
4. **Pilot call sites (§6):** confirm `ChangePasswordsViewController`/`AccountDeletionViewController`
   are acceptable, or name different ones to start with.
