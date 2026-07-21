# Brief: Modal Executor / Trigger — can it be called from a View or a ViewModel?

**Status:** pre-decision brief. Not scheduled. Read before building a "clean trigger".
**Related:** [modal stack/queue brief](2026-07-21-modal-stack-queue-brief.md) — the executor is the front door; the queue/stack is the policy behind it.

## The question
Today a modal is triggered by constructing a `GBAlertModal` (a `UIView`) and calling `.show()` — which adds it to the key window. That call lives in the **View layer** (UIViewControllers). Can the trigger instead be invoked from a **ViewModel**, without a ViewModel touching UIKit?

## Why it's not trivial
`GBAlertModal` **is a `UIView`**. Building and showing it needs `UIKit` + a window/parent. In MVVM a ViewModel is supposed to be UI-framework-agnostic (no `UIView`, testable without a screen). So a ViewModel calling `modal.show()` directly **couples the VM to UIKit** — the thing MVVM exists to avoid. It also blocks the planned SwiftUI port (a SwiftUI VM can't hold a UIKit view).

The good news: the library already separates *decisions* from *rendering*. `ResolvedModal` + the `Properties`/`DataHolder` value types are pure data. A trigger only needs to pass **data** (what to show), not a view.

## Options

| Option | VM can trigger? | UIKit in VM? | Notes |
|---|---|---|---|
| **A. View-only (status quo)** | No — VM emits an intent, View shows | No | Cleanest separation, but the "trigger" is View code; every screen re-implements it. |
| **B. Reactive output** | Indirectly | No | VM exposes an output (RxSwift `Observable` / Combine publisher / a closure) carrying a *spec*; the View subscribes and presents. Common MVVM. VM stays pure. |
| **C. Executor protocol (recommended)** | **Yes, directly** | No | VM holds an injected `ModalExecutor` (a protocol). VM calls `executor.present(spec)` with a **pure spec** (no UIView). The concrete executor lives in the View/coordinator layer and does the UIKit `show()`. |

## Recommended shape: an `ModalExecutor` seam
```swift
// Pure — lives in a layer both View and ViewModel can import (no UIKit view types).
struct ModalRequest {            // what to show (pure data)
    var properties: GBAlertModal.Properties?
    var holder: GBAlertModal.DataHolder
}
protocol ModalExecutor {         // the seam a ViewModel can call
    @discardableResult
    func present(_ request: ModalRequest) -> ModalHandle   // handle for dismiss/await result
}
```
- **ViewModel side:** inject a `ModalExecutor`; call `executor.present(...)`. No UIKit. Fully unit-testable with a mock executor (assert "VM asked to present X").
- **View side:** the concrete `UIKitModalExecutor` builds a `GBAlertModal`/`SampleAlertModal` and shows it on the key window (or a passed parent). This is the ONLY place UIKit lives.
- **SwiftUI later:** a `SwiftUIModalExecutor` drives a `@Published` current-request that a presenter view renders via overlay/`.sheet`. Same VM code, different executor. The executor is the exact seam that makes the VM portable.

So: **"Can it be called on View or ViewModel?" → Yes, from both — via the executor.** The VM triggers through the pure `ModalExecutor` interface; the actual presentation stays View-side. `DataHolder.completion` (or an `async` return on `ModalHandle`) delivers the tap result back.

## Notes / open questions
- `DataHolder.completion` is a UIKit-flavored callback (`(GBAlertModal, ActionType) -> Void`). For a VM-friendly API, wrap it so the executor returns a plain `ActionType` (or `async`/publisher) and never hands the VM a `GBAlertModal`.
- Where does the concrete executor get the window/parent? Inject it, or resolve the key window inside the UIKit executor (as `V3AlertModal.show()` does today).
- The executor should route through the coordinator (queue/stack) — see the companion brief — so `present(...)` never overlaps an existing modal.
- Scope decision to make later: does the executor live in **this library** (ships a default UIKit executor + the protocol) or in the **consumer app**? Library-side keeps it reusable and SwiftUI-ready; app-side is faster but non-portable.
