# Estimate: Modal Executor — VM-ready, SwiftUI-ready presentation seam

**Status:** post-decision estimate. No code. Follows the two pre-decision briefs
([executor](2026-07-21-modal-executor-brief.md), [stack/queue](2026-07-21-modal-stack-queue-brief.md)).
**Purpose:** size the task, fix complexity, and record every decision before implementation.

---

## 1. Scope of THIS task

**Deliver the executor CAPABILITY in this module only** — the library seam + renderer +
built-in descriptors + extension mechanism + stateful/input support, built, demonstrated
in the Example app, and tested here. **This task does NOT migrate the distribution app's
142 call sites** — that is a separate downstream effort in the app repo. The app inventory
(§4) is *input* that defines which descriptor **kinds** the capability must support; it is
not a migration checklist for this task.

A VM-facing presentation seam so a ViewModel triggers any dialog **without touching UIKit**:

```
ViewModel ──present/update/dismiss──▶ ModalExecutor ──render(descriptor)──▶ ModalRenderer (UIKit)
             (pure descriptors)                                              ⟵ overlap possible, ACCEPTED
```

- **Two seams:** `ModalExecutor` (front door) + `ModalRenderer` (UIKit now / SwiftUI later). No coordinator.
- **Overlap is an accepted non-goal** — parity with today's legacy `.show()`. Overlap-fixing is the coordinator's job (deferred).
- **In the library** (portable, SwiftUI-ready), authored in the library's current Swift 5 mode.

**Out of scope (separate future tasks):** coordinator/queue/priority/dedup/owner-scoping · SwiftUI renderer + port · library Swift 6 language-mode flip · hard sunset of legacy · lint fence.

---

## 2. Two tracks

| Track | Rule |
|---|---|
| **Legacy** `V3AlertModal(...).show()` | Unbounded lifetime, no sunset, migrate opportunistically. Stays unmanaged (may overlap). |
| **New** `executor.present(...)` | Every new dialog goes through the executor. VM-ready + SwiftUI-ready. |

"No new legacy" is enforced by **PR review only** (no lint — owner's call; risk: drift on a large team, lint-with-baseline remains a later fallback).

---

## 3. Locked decisions

**A — Result delivery**
- Primitive `present(_) -> ModalToken<Result>` (sync, `@MainActor`) + `token.result` (async, **replayable, idempotent**).
- Convenience `present(_) async -> Result` for simple show+wait.
- `update(token,to:)` / `dismiss(token)` on the executor.
- **Token ⟺ statefulness:** simple/input dialogs (`dismissOnAction` baked `true`, tap is terminal) are **await-only, no token**; stateful dialogs (`false`) hold the token to drive `update`/`dismiss`.
- **Exactly-once resolve gate** over every teardown path (→ `.dismissed`).
- **Executor is async-native; library is Rx-free.** New dialogs call `await present()` directly.
- **OPTIONAL** app-side Rx `Single` adapter over `token.result` — build only if an *existing* Rx call site (the app has 711 `import RxSwift` files) needs to consume the executor. Skip it if new work is async-not-Rx. No async twin, no closure primitive, never Rx in the library.

**A-concurrency**
- Seam is `@MainActor`; `protocol ModalDescriptor: Sendable { associatedtype Result: Sendable }`.
- Authored in the library's **Swift 5 mode** (annotations are valid there). Do **not** flip library or app to Swift 6 language mode — that would drag the whole legacy modal through strict concurrency.
- App keeps Swift 5 mode; Rx adapter uses `@preconcurrency import RxSwift`. Toolchain is Swift 6.3.3, so a v5-consumer/v6-clean-seam interop is safe when the flip eventually happens.

**B — Purity boundary (content vs style vs behavior)**

| Bucket | Lives where | New descriptor on change? |
|---|---|---|
| Content (image, title, subtitle, primary, secondary) | VM-editable value | No |
| Per-use behavior (`closeOnTapOverlay`, `showCloseButton`) | VM-editable value | **No** |
| Style bundle (fonts, colors, padding, banner ratio, button styles) | descriptor **identity** | **Yes** |
| `dismissOnAction`, `subtitleCustomView` | fixed by descriptor **kind** (simple/input/stateful/bespoke) | n/a |

> **VM sets the 5 content values + safe per-use behavior flags. Descriptor identity fixes the style bundle. Descriptor kind fixes lifecycle/custom-view. Style never enters the VM; behavior booleans never force a new descriptor.**

**B — Descriptor granularity:** style→descriptor. `AlertDialog` + `PopupDialog` + ~12–15 styled recipes (consolidated from 63 inline-style sites) + 4 input + 1 stateful + ~8 bespoke ≈ **~20–25 descriptors**. Includes a **style-consolidation audit** of the 63 sites.

**Ownership & lifecycle** (the load-bearing one)
- **Token = `id` + result state, NEVER a UIView.** VM safe to hold; leaks nothing after dismissal (a few bytes).
- **View lifetime = key window + renderer `[id: modal]` registry**, from `present()` to a terminal event. Dropping the token does **not** dismiss.
- **Cleanup choke point = the resolve-once gate:** `removeFromSuperview()` + `registry[id] = nil` (→ UIView deallocs) + `token.resolve(...)` once, guarded by `hasResolved`. No retain cycle (`registry → modal → completion → token`, `token → nothing`).
- **Stateful teardown = Option 1 (CONFIRMED):** VC routes `viewWillDisappear`/`deinit` to the VM as an Rx input; VM calls `executor.dismiss(token)`. Handles VM-outlives-VC. ~1 wiring on the ~1 stateful VM (Gc2Gs). VM-held `update` after dismissal is a no-op.
- **Await path:** `withTaskCancellationHandler` dismisses if the awaiting VM's task is cancelled — free teardown for awaited dialogs.
- **Full automatic owner-scoping = coordinator, deferred.** Unwired stateful orphan-on-VC-death = legacy parity (accepted).

**D — Window source:** renderer resolves the key window **internally** (parity with today's `AppCompatHelper.keyWindow`), with a construction-time `windowProvider: () -> UIWindow?` seam for tests/multi-scene. One source now; multiple renderers become meaningful only when stack/queue lands. **Never** in the VM-facing API.

**SwiftUI:** design is SwiftUI-ready as-is. A `SwiftUIRenderer` switches on the same descriptors and maps `present`/`update`/`dismiss` onto a `@Published current` state a presenter observes. VM code unchanged; `.task` cancellation makes owner-teardown cleaner than UIKit. No VM-facing change.

---

## 4. Dialog inventory (distribution app)

142 construction sites across 51 files.

| Category | Count | API surface | Descriptor |
|---|---|---|---|
| Fire-and-forget info/error/confirm | ~110 | `await present() -> Result` | `AlertDialog` / `PopupDialog` + styled variants |
| Input (rename `UITextView`, date `UIDatePicker`) | 4 inits | `await present() -> .renamed(String)` / `.picked(Date)` | 4 input descriptors (live view stays renderer-side) |
| Stateful (`GenerateGc2GsModal`) | 1 family, 7 drivers | `present() -> token` → `update(.loading)`/`.insufficient` | 1 state-enum descriptor |
| Selection-toggle (`SatisfactionLevelDialogView`) | 1 | await; validation renderer-side | 1 bespoke descriptor |
| Bespoke custom-content popups (NPS, Streak, Badges, GenieClass ×3, PopupCampaign) | ~8 | await / token | ~8 bespoke descriptors |
| Inline-style overrides feeding the above | 63 sites | — | consolidate → ~12–15 styled recipes |

Key facts: exactly **one** stateful subclass in the whole app; `StreakActionModalGenerator` is **already VM-driven** (reference pattern); banners are asset-catalog names (tokenizable).

---

## 5. Estimate

**Complexity: LOW intellectual risk.** The design is bounded and proven against the worst case (Gc2Gs); every complex dialog already exists and *moves* behind the renderer. **Cost is throughput, not difficulty.**

### THIS project — the capability (in this module)

| Phase | Work | Size |
|---|---|---|
| 1 | Seam: `ModalDescriptor`/`Result` protocols + `ModalToken` (resolve-once + async replay) + `ModalExecutor` + `ModalRenderer`, `@MainActor`/`Sendable` | **S–M** |
| 2 | `UIKitRenderer` (key-window + `windowProvider` + `[id:modal]` registry + resolve-once gate) + built-in `AlertDialog`/`PopupDialog` + `presentRaw{UIView}` escape hatch + `present async` convenience | **M** |
| 3 | Extension mechanism: type-erased descriptor→factory registry so consumers register their own descriptor kinds (input/stateful/bespoke) without editing the library | **S–M** |
| 4 | `update(token,to:)` stateful support + resolve-once semantics for `dismissOnAction:false` | **S** |
| 5 | Demonstrate + test in the Example app: one of each kind (fire-and-forget, await-value/input, stateful) in the gallery; Layer-A/B/C-style tests | **M** |

**Headline for this task: S–M.** Bounded, single-repo, low risk — no app call sites touched.

### Downstream — app migration (SEPARATE tasks, app repo, NOT this project)

`StyleCatalog` extraction · 63-site style-consolidation audit → ~12–15 styled descriptors ·
input descriptors (rename/date) · Gc2Gs state-enum + Option 1 wiring · ~8 bespoke popups ·
migrate ~114 simple sites → `await present()` · optional Rx `Single` adapter. **Throughput-bound M–L, owned by the app team.**

---

## 6. Sequencing (this task — capability only)

1. Seam: `ModalDescriptor`/`ModalToken`/`ModalExecutor`/`ModalRenderer` protocols + token resolve-once/replay.
2. `UIKitRenderer` + built-in `AlertDialog`/`PopupDialog` + `presentRaw` + `present async` convenience.
3. Descriptor→factory registry (consumer extension point).
4. `update(token,to:)` stateful support.
5. Example-app demonstration (one per kind) + Layer-A/B/C tests.

*(Downstream, separate/app repo: style extraction → audit → app descriptors → migrate 142 sites. Later still: coordinator/queue → overlap + `isShowing` + owner-scoping.)*
