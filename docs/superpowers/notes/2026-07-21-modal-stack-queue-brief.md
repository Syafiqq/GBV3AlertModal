> **SUPERSEDED (2026-07-26)** by `2026-07-26-modal-coordinator-brief.md`. Design is now locked (two
> /council passes) — do not act on the pre-decision recommendations below; kept for history only.

# Brief: Modal Stack / Queue — coordinating multiple modals

**Status:** pre-decision brief. Not scheduled. Read before building modal coordination.
**Related:** [modal executor brief](2026-07-21-modal-executor-brief.md) — the executor is the front door; this is the policy behind it.

## The problem
Today there is **no coordination**. Each modal independently `addSubview`s itself to the key window. If two are triggered close together (an async error + a campaign popup, a retry dialog while another is up), they **overlap**. The app works around this by checking a `Dialogable.isShowing` flag **scattered across dozens of call sites** — every caller manually guards against double-presenting. That scatter is the real pain; a coordinator absorbs it into one place.

## The core decision: what happens when a modal is triggered while one is already showing?

| Policy | Behavior | Good for | Downside |
|---|---|---|---|
| **Queue (FIFO)** | New modal waits; shows after the current dismisses. One at a time. | Sequences: notifications, onboarding steps, "show these in order". Kills the overlap/`isShowing` scatter. | A modal can be delayed behind others. |
| **Stack (LIFO)** | New modal shows on top of the current; dismiss reveals the one beneath. | Nested confirmations ("Are you sure?" over a form dialog). | Visual clutter; z-order/dimming management; rarely needed. |
| **Replace** | New modal dismisses the current. | "Latest wins" (a fresh error supersedes a stale one). | Loses the earlier modal silently. |
| **Priority** | Each request has a priority; higher preempts (replace/stack), lower queues. | Mixed urgency (a blocking error should beat a marketing popup). | More policy to reason about. |

## Recommendation: a `ModalCoordinator` defaulting to **Queue**, with optional priority
The app's actual pain is "two modals overlap / callers hand-roll `isShowing`." That is precisely what a **serial queue** solves: one modal at a time, the rest wait. Start there; add a `priority` field so a blocking error can jump ahead of a queued marketing popup, and a `.replaceCurrent` option for "latest wins" cases. Stacking is a rare need — leave it out until a real nested-confirm flow demands it.

```swift
enum ModalPresentationPolicy { case enqueue, replaceCurrent }   // stacking deferred
struct ModalRequest { /* pure spec; see executor brief */ var priority: Int; var policy: ModalPresentationPolicy }

final class ModalCoordinator {              // holds pure state, not views
    func submit(_ request: ModalRequest) -> ModalHandle   // enqueues; presents when free
    // internally: a queue + a "current"; on dismiss, present the next (highest priority first)
}
```
- The coordinator is **framework-agnostic** — it owns the queue/current-request *state*, not the UIKit views. The **executor** (companion brief) renders whatever the coordinator says is current, and reports dismissal back so the coordinator advances.
- This centralizes the scattered `isShowing` checks into one authority; call sites just `submit(...)` and stop caring whether something is already up.
- **SwiftUI later:** the coordinator's "current request" becomes `@Published`; a single presenter view renders it. Same coordinator, no rewrite — which is why the state must stay UIKit-free.

## Prior art already in the repo
The gallery's floating traversal + **auto-next** (in `Examples/.../Gallery/FloatingTraversalControl.swift`) is effectively a manual, single-slot queue driver (present one, dismiss, present the next on a timer). It's a useful reference for the "dismiss current → present next" mechanic the coordinator needs.

## Notes / open questions
- **Dedup:** should submitting an identical request while it's already showing be a no-op? (Common desire — replaces a lot of `isShowing` guards.)
- **Lifecycle:** what happens to the queue on screen/navigation change (VC popped, backgrounded)? Probably: cancel requests tied to a dismissed owner. Needs an owner/scope on `ModalRequest`.
- **closeOnTapOverlay / dismiss** must notify the coordinator so it advances — the executor wires `DataHolder.completion`/dismissal into `coordinator.didDismiss(handle)`.
- **Scope decision (later):** coordinator in **this library** (reusable, SwiftUI-ready) vs the **consumer app**. Library-side is the portable choice and it retires the app's `isShowing` scatter for every consumer.
