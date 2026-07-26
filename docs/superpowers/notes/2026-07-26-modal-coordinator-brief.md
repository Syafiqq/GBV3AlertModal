# Brief: Modal Coordinator — PR-1/PR-2 (pick up in a fresh session)

> **PR-1 FINAL (2026-07-26, 3rd council pass — Torvalds/Rams/Taleb/Feynman, ponytail lens).**
> This section SUPERSEDES the two-coordinator/protocol design in §2 below for PR-1. Nothing here is
> silently dropped — each cut is a fresh-lens reversal of the earlier lock, reasoned below.
>
> 1. **Cut `BaseModalCoordinator`.** The executor→renderer direct path in `DefaultModalExecutor`
>    ALREADY is today's unbounded/overlap behavior. A passthrough class only existed to dodge a
>    nil-check. Executor holds ONE optional concrete `RootScreenModalCoordinator?`; `nil` = the shipped
>    direct path, untouched.
> 2. **No `ModalCoordinator` protocol** in PR-1 (one impl). Lifecycle methods (`hide/show/pause/resume`)
>    MUST stay on the concrete type — a protocol/Base would silently no-op them (the "silent trap").
>    Add the protocol at rule-of-three.
> 3. **Name: `RootScreenModalCoordinator`** — app-agnostic. It owns visibility lifecycle: hide-on-push,
>    show-on-pop, driven by the app's root/tab screen. (Considered `MainTab…`; kept neutral so the lib
>    vocabulary stays decoupled from app navigation.)
> 4. Behavior: **serial (1-at-a-time, dimmed-fullscreen geometry), unbounded queue, dedup-by-key
>    (nil=none, duplicate=drop-new).**
> 5. **Lifecycle on the concrete type:** `hide()/show()` (+ `pause()/resume()` — port app
>    `DialogQueue` pause/restart). Hide/show is NOT a terminal exit — it must NOT resolve the token.
>    Needs one new renderer method `setHidden(_ id:, _:)` (toggle visibility without teardown).
> 6. **Resolve-on-every-exit invariant** + conservation test over paths that EXIST in PR-1:
>    normal-resolve, dedup-drop, screen-teardown-drain. (Do NOT test supersede/owner-deinit — those
>    features don't ship yet; a green test over an unreachable path is false robustness.)
> 7. **Teardown drain (load-bearing here, not speculative):** when the owning root screen
>    pops-and-deallocs, the coordinator drains + resolves its queue `.superseded` (== dismissedValue
>    for now) on deinit/uninstall. A settable property/deinit, NOT `setCoordinator`-returns-previous.
> 8. Front door: **`present(descriptor, dedupKey:)`**. No `priority:` (dishonest no-op) and no
>    public `scope:` param yet.
> 9. **Deferred (add on real reproducer):** per-request scope/owner cancel (orphan token deallocs
>    clean, parks no continuation, CANNOT hang — harm is a lingering, self-correcting modal =
>    Mediocristan; the coordinator is already screen-scoped); `priority:`+interrupt (PR-2);
>    `ModalOutcome` enum; coordinator protocol/stack; queue cap/TTL; SwiftUI renderer.
> 10. **Flag (note in code, don't build):** dedup-drop resolving with `dismissedValue` is
>     indistinguishable from a user dismiss — `ModalOutcome` closes that later.
>
> **PR-1 SHIPPED (2026-07-26, TDD, full suite 197/197 green, was 182).** Files added:
> `Executor/RootScreenModalCoordinator.swift` (serial, dedup-by-key drop-new, `drain()`,
> `hide()/show()` with `isHidden` pause gate; owns queued tokens strongly — a fire-and-forget queued
> `present()` must still show, which is why drain is load-bearing). `ModalRenderer` gained
> `setHidden(_:_:)` (UIKit: `modal.isHidden`, no teardown). `DefaultModalExecutor` gained
> `var coordinator: RootScreenModalCoordinator?` (`didSet { oldValue?.drain() }` = handoff-drain) and
> front door `present(_:dedupKey:)` (protocol requirement + defaulted convenience; `presentAndWait`
> unchanged). Tests: `RootScreenModalCoordinatorTests` (11) + `ModalExecutorCoordinatorTests` (4),
> with `SpyRenderer` fake; async assertions bounded via `XCTestExpectation` (brief §9).
> **KNOWN GAP (deferred, ponytail-noted in ModalExecutor.swift):** `presentAndWait` routed THROUGH a
> coordinator, if its await is cancelled, resolves the token (no hang — invariant holds) but leaves
> the modal visible + `current` stuck, because the coordinator doesn't wire `token.onDrop`. Stuck
> modal = Mediocristan, same class as deferred per-request scope. Close when scope/cancel lands.
> Branch `feat/modal-executor-capability`, UNMERGED, not committed by the building session.

---

**Status:** design locked (via two /council passes), token slice shipped, coordinator NOT built.
**Branch:** `feat/modal-executor-capability` (off `refactor/decompose-modal`, unmerged).
**Supersedes:** `2026-07-21-modal-stack-queue-brief.md` (pre-decision; do not act on its recommendations).
**Related:** `2026-07-22-modal-executor-estimate.md`, plan `../plans/2026-07-22-modal-executor-capability.md`.

---

## 1. Where things stand

**DONE — token migration (2026-07-26, TDD, 182/182 green):** `ModalToken` is enqueue-ready.
- `init(dismissedValue:)` seeded from `D.dismissedResult` (public — a custom executor/renderer must mint tokens).
- `result` uses `withTaskCancellationHandler` + dict-keyed waiters (per-waiter detach).
- Exactly-once `resolve` clears `onDrop`.
- Two cancellation modes via `dismissOnAwaitCancel` (internal):
  - `true` (`presentAndWait`, await owns the modal) → cancel fires `onDrop` → dismiss → teardown, resolves dismissed.
  - `false` (`present() -> token`, VM owns) → cancel detaches just that waiter; modal lives on.
- `onDrop` (internal) is weak both ways (token + self) — no retain cycle to defeat scope auto-cancel.
- Non-throwing throughout (cancel resolves `dismissedValue`).
- Files: `Library/GBV3AlertModal/Sources/GBV3AlertModal/Executor/{ModalToken,ModalExecutor}.swift`;
  tests `.../Tests/GBV3AlertModalTests/Executor/{ModalTokenTests,ModalExecutorTests}.swift`.

**NEXT:** PR-1 (coordinator core) → PR-2 (priority + interrupt). Split per council.

---

## 2. Locked architecture (condensed)

One `ModalRenderer` (UIKit) owns the single window slot — the only presenter, kills overlap. A
`ModalCoordinator` sits optionally between executor and renderer as the **policy layer**:

- **`BaseModalCoordinator`** — unbounded passthrough = today's behavior; the DEFAULT (so there is no
  `nil` branch). Thin; exists for symmetry + set-wide lifecycle.
- **`MainModalCoordinator`** — serial, one-at-a-time, unbounded queue, dedup; installed on screens
  that need ordering.
- One coordinator owns the slot at a time; base↔main is **handoff, never concurrent**.
- Concurrency is fixed, not a dial (Main=1 by geometry — dimmed fullscreen overlay; Base=∞).
- Front door stays one: `present(descriptor, priority:, dedupKey:, scope:) -> token`, everything but
  `descriptor` defaulted. `await token.result`.
- Priority MECHANISM lives in the lib (a `Comparable` on the request); the app's 21-case
  `DialogType.priority` VALUES stay app-side. Do NOT drag `DialogType` into the library.
- Prior art to PORT (not reinvent): the app's `DialogQueue.swift`
  (`geniebook-student-ios-distribution/Common/Common/Custom/Components/Dialog/DialogQueue.swift`) —
  serial, `rearrangeDialog` (pin shown, sort rest), dedup by type, pause/restart. 4 years of tuning;
  respect it.
- SwiftUI later = swap the injected `ModalRenderer`. Coordinator stays UIKit-free.

## 3. THE invariant (council dealbreaker, unanimous)

**Every request that enters `present()` gets exactly one terminal resolution.** Queued-then-dropped
(dedup), superseded (priority), displaced at handoff, and owner-deinit-while-queued must ALL resolve
the token — else `await token.result` hangs forever on the main actor. This is the whole reason the
token was migrated first (it now has `onDrop`/`dismissedValue` hooks). Ship with a **conservation
test**: `count(resolutions) == count(requests entered)` across every exit path.

## 4. Resolved design calls (2nd council pass)

**Q1 — owner/scope = optional weak `AnyObject`, `.app` default, checked LAZILY.**
- Add optional `scope`/`owner: AnyObject?`, default `.app` (90% of call sites pass nothing).
- Owner-cancel is a **lazy weak-check on the MainActor at the next coordinator touch — NOT a
  `deinit` hook.** Same pattern already shipped at `ModalExecutor.swift` (`[weak self, weak token]`,
  checked lazily on main). This avoids the deinit-thread race and makes a retain cycle impossible.
- REJECTED: `ModalScope` handle (ceremony; unanimous, incl. its proposer). REJECTED: deferring scope
  entirely — a real, non-lint-closable leak exists (see §6, leak #1).

**Q2 — handoff = explicit `executor.setCoordinator(_:)`, returns previous.**
- The safety property is an INVARIANT, not a data structure: *the coordinator losing the slot must
  drain its queue, resolving every pending token `.superseded` before yielding.*
- `setCoordinator` returns the previous coordinator (caller can restore / build a stack later, no API
  break). REJECTED for now: coordinator stack, lifecycle-observation (magic; the app's Rx
  `TopScreenDetector` is exactly what this module walks away from).

## 5. PR-1 — concrete tasks (TDD, tests first)

Recommended structure: executor holds a `ModalCoordinator` (default `BaseModalCoordinator`); the
coordinator holds the `ModalRenderer` and drives it. First implementation decision: exact
`ModalCoordinator` protocol shape (present/update/dismiss + resolve-baton contract; likely richer
than `ModalRenderer` because it carries `dedupKey`/`scope`).

Build:
1. `ModalCoordinator` protocol + `BaseModalCoordinator` (thin wrap of current behavior).
2. `MainModalCoordinator` — serial one-at-a-time, unbounded queue, **dedup by caller key** (nil = no
   dedup, duplicate = drop-new).
3. Resolve-on-every-exit wiring via `token.onDrop`/`dismissedValue`.
4. `scope`/owner optional weak `AnyObject` (`.app` default) + lazy weak-check + purge pending.
5. `executor.setCoordinator(_:)` (returns previous) + drain-and-resolve-`.superseded` on handoff.
6. Executor front door gains defaulted `dedupKey:`/`scope:`.

**Mandatory tests to write FIRST (both are real leaks the council surfaced):**
- **Conservation:** resolutions == requests entered, across dedup-drop / supersede / handoff / owner-deinit-while-queued.
- **Leak #1 (stored-token orphan):** `present()` (@discardableResult, no await), store token, "VM"
  deinits without awaiting `.result` or calling `dismiss()` → owner-scope must still resolve+purge.
- **Drain-on-handoff:** `setCoordinator` with a non-empty queue resolves every pending token `.superseded`.

## 6. Known leaks (context for the tests above)

1. **Stored-token orphan (real, not lint-closable):** `present()` returns a `@discardableResult`
   token with `dismissOnAwaitCancel=false` and no awaiting Task. A VM that stores it for a later
   `update()` and deinits without awaiting/ dismissing → nothing fires. This is why scope ships in
   PR-1 (lazy weak-owner cancel closes it). Cross-scope runtime lifetime — a lint can't see it.
2. **Deinit-thread race / retain cycle (AVOIDED by design):** only a hazard of push-based `deinit`
   hooks or strong owner capture. The lazy-weak-check-on-MainActor pattern avoids both.

## 7. PR-2 — priority + interrupt

- Priority keep-current: port `rearrangeDialog` (pin shown, sort rest); `Comparable` on the request;
  values app-side.
- Kill-switch INTERRUPT as explicit per-request opt-in (NOT a general mode) — mirrors the app's
  separate `DialogSessionEndQueue`. Default never preempts the shown modal.
- Watch starvation once priority lands (aging deferred — see §8).

## 8. Deferred / dropped (council-blessed)

Queue cap + TTL, starvation aging, `ModalOutcome` enum (distinguish superseded/deduped/cancelled),
dedup-share-winner, SwiftUI renderer, pause-on-background wiring, coordinator stack, ModalScope,
lifecycle-observed handoff. Add only when a real reproducer appears. (Student app = bounded
interaction rate; unbounded queue is not a v1 liveness risk once resolve-on-exit self-drains it.)

## 9. Gotchas

- **Async cancellation tests:** use `XCTestExpectation` + `wait(for:timeout:)`. Do NOT wrap a
  possibly-never-resuming task in a `withTaskGroup` race — the group drains all children before
  returning and deadlocks on the hung task. (Cost us a real hang this session.)
- **Test run:** `xcodebuild test -scheme GBV3AlertModal -destination 'platform=iOS Simulator,name=iPhone 17'`
  (iOS 13 target; `swift test` won't compile — iOS-only package). First build is slow and competes
  with any full Geniebook app build; run in background and stream to a logfile. Use
  `-only-testing:GBV3AlertModalTests/<Class>` for tight loops.
- **`ModalToken` API note:** `init()` → `init(dismissedValue:)` is the only public break; inert
  because only the executor mints tokens. See memory `gb-v3-alert-modal-executor-decisions`.

## 10. Council record

Two passes this session (panel: Torvalds/Rams/Taleb/Feynman). Pass 1 → the 14-point list + the
resolve-on-every-exit dealbreaker + PR-1/PR-2 split. Pass 2 → Q1 (scope = optional weak AnyObject,
lazy) and Q2 (handoff = explicit setCoordinator + drain invariant); ModalScope and defer both
rejected on a code-verified leak.
