# Direction — SwiftUI is the product; UIKit is legacy

**Decided 2026-08-05 by the owner.** Recorded because every document in this module currently
assumes the opposite, and that assumption is load-bearing in test prose.

> **Keep UIKit. Mature SwiftUI. Delete UIKit.**

---

## 1. What this changes

Until now the stated goal was **parity**: mirror a frozen, shipping UIKit dialog and prove the
mirror faithful. The architecture serves that goal well — both backends run the *same*
`GBAlertModal.resolve` over the *same* `AlertHolder.make`, which is why resolution provably cannot
diverge and why several test docs say "by construction."

The destination is now **independence**: SwiftUI stands alone, UIKit is deleted. That makes the
shared pipeline **transitional scaffolding with an end date**, and it changes four things:

| | before | after |
|---|---|---|
| The differential gate | the permanent proof of correctness | a **migration tool**, retired with UIKit |
| "UIKit is frozen" | it is canonical; SwiftUI must match | it is legacy; it must not *change*, but it is not the target |
| A divergence | a defect in SwiftUI | **a question**: is UIKit right here, or merely first? |
| `Properties` | the configuration API | a UIKit-typed API the app must eventually migrate off |

## 2. The reframing that matters most

**Reproducing a UIKit bug is now anti-value.** Three findings on the current branch were filed as
SwiftUI gaps and are better read as UIKit defects SwiftUI correctly declines to inherit:

- **The landscape inset band (844×417…431).** UIKit's vertical compression there is
  *path-dependent* — the same modal at the same size yields an 18.67pt top inset over a 38.33pt
  subtitle laid out fresh, and 24.00 over 27.33 after passing through a smaller size. 16pt apart,
  because two constraints tie at `defaultLow` and Auto Layout's optimum is a tied face rather than a
  point. SwiftUI's layout is a pure function of (tree, proposed size) and *cannot* be path
  dependent. That is a feature.
- **`showsPrimary` resolved but not obeyed.** A real asymmetry — but the fix is to make the
  descriptor able to express "no primary button", not to teach SwiftUI UIKit's behaviour.
- **`bannerFixedHeight`.** Measured inert on both UIKit paths at every size tried. It is dead
  vocabulary that SwiftUI should never have carried.

Divergences still need to be *measured and explained*. What changes is the default conclusion.

## 3. The boundary

`Core/` — `AlertDialog`, `ModalStyle`, `ModalImage` — is **already UIKit-free** and enforced by
`CorePurityTests`. That is the shared foundation and it stays shared.

Everything else splits. For the SwiftUI half to contain no UIKit it needs its own:

| what | why it cannot be shared |
|---|---|
| configuration type | `Properties` is 18 `UIColor`, 6 `UIFont`, 3 `UIEdgeInsets`, 3 `NSLayoutConstraint` |
| resolver | `ResolvedModal.buttonAxis` is `NSLayoutConstraint.Axis` |
| text measurement | `titleUIFont`/`subtitleUIFont` are measurement twins; `Font` cannot report a line height. **CoreText can measure without UIKit** |
| axis | currently bridged at one call site |
| orientation source | `UIScreen.main` — also wrong on iPad multitasking, where it is the screen and not the window |
| four bespoke views | text input, date picker, badge, loading all delegate to `UIKitModalRenderer` because descriptors cannot carry a `UIView` |

## 3a. The SwiftUI config mirrors `Properties`' VOCABULARY, not its types

**Decided with §1.** The SwiftUI-native configuration keeps the same field names and the same
concepts as `GBAlertModal.Properties`, so a call site moving from UIKit to SwiftUI recognises every
line and only the types change. It is a **parallel type, not a translation layer** — nothing
converts at runtime, and neither side imports the other.

"More or less" is accepted: where the two worlds genuinely differ, the SwiftUI type is allowed to
differ, and where a UIKit field is dead it is **not** carried over.

Of the 29 public fields, roughly half need no change at all — `CGFloat` is CoreGraphics and `Bool`
is `Bool`. Only these actually move:

| `Properties` (UIKit) | SwiftUI mirror | note |
|---|---|---|
| `baseTint`, `overlayColor`, `titleColor`, `subtitleColor`, `closeButtonTint`, `backgroundColor` — `UIColor?` | `Color?` | direct |
| `titleFont`, `subtitleFont` — `UIFont?` | `Font?` | measurement moves inside, via CoreText — the caller never sees a `UIFont` |
| `margin` — `UIEdgeInsets?` | `EdgeInsets?` | direct |
| `padding` — `UIMinMaxEdgeInsets?` | own `MinMaxEdgeInsets` | SwiftUI has no min/max inset type; this one is genuinely ours either way |
| `buttonActionOrientation` — `NSLayoutConstraint.Axis?` | `Axis?` | already bridged at one call site today |
| `primaryActionStyle`, `secondaryActionStyle` — `ActionStyle?` | own `ActionStyle` | same four cases, `Color`-based themes |
| `contentProperty` — `ContentProperty?` | same shape, `Color` inside | nested, same field names |
| `bannerRatio`, `bannerMaxHeight`, `cornerRadius`, the four width fields, `space`, the `Bool`s | **unchanged** | `CGFloat`/`Bool`/own types |

**Deliberately NOT carried over:**

- **`bannerFixedHeight`.** Measured inert on both UIKit paths at every size tried — it loses to
  hugging (250) going up and to compression resistance (750) coming down. Dead vocabulary; the
  SwiftUI type should never have it. This is the model case for "more or less."

Any further omission needs the same standard: a measurement showing the field does nothing, not an
opinion that it looks redundant.

## 4. The descriptor gap is the keystone

Nine `notRenderable` gallery entries, the `showsPrimary` divergence, and the four bespoke
delegations are **one problem**: a `ModalDescriptor` is a `Sendable` value that cannot carry a view,
cannot express "no primary button" (`AlertDialog.primary` is a non-optional `String`), and has no
presentation-state channel.

Closing it collapses all three at once, and it is the highest-leverage single change available.

## 5. Staged path

Each pass leaves the suite green and the gate meaningful, so a regression is attributable.

**Pass 1 — leaves.** CoreText measurement replacing the `UIFont` twins; SwiftUI-native axis;
`UIScreen` → environment; `AttributedString`-only path. No architectural change; the SwiftUI half
stops importing UIKit for anything cosmetic.

**Pass 2 — the descriptor gap.** `AlertDialog.primary` becomes optional; descriptors gain a
presentation-state channel. Closes nine gallery gaps and one divergence.

**Pass 3 — the core.** A SwiftUI-native configuration type and resolver over `Core/` descriptors.
This is where "by construction" stops being true and the gate becomes the only thing holding the
two together — so it lands *after* the gate is at its strongest.

**Pass 4 — bespoke views.** Native SwiftUI text input, date picker, badge, loading.

**Pass 5 — be READY to retire UIKit.** Not "delete UIKit": this repo cannot do that on its own, and
the app is out of scope (§6a). The deliverable is a library where the SwiftUI path touches no UIKit
and the UIKit half is inert — deletable the day the app stops importing it, by someone else, on
someone else's schedule.

## 6. Consequences to accept

- **"By construction" becomes an empirical claim at Pass 3.** Every test doc using that phrase needs
  re-checking then, not now.
- **The differential gate has an end date.** It is the safety net for Passes 3–4 and is deleted at
  Pass 5. Its measurements — the geometry rules, the truth table, the divergence catalogue — outlive
  it as documentation of what the shipping dialog did.

## 6a. The app is READ-ONLY to this work

`geniebook-student-ios` is a **reference, never a target.** Read it to establish facts — what
`Properties` values the real presets use, what point sizes the real artwork is, which fields are
actually set. Never plan or make a change to it.

Two consequences:

- **`Properties` stays, working, indefinitely.** It is the app's live API. The SwiftUI-native config
  (§3a) lands *alongside* it, not instead of it. Nothing is removed from `Properties` on a schedule
  this repo controls — including `bannerFixedHeight`, which is dead but stays public because
  removing it is a source break for a consumer that is not ours to edit.
- **"Ready" is the finish line, not "deleted."** Success is: SwiftUI complete, independent, and
  proven; UIKit present but untouched by it. Whether and when UIKit is actually removed is a
  decision made elsewhere, with the app's migration.

This is also why the geometry measurements matter beyond this branch: they are the evidence an app
team needs to trust the swap, and they were taken against the real presets and the real artwork.

## 7. What is NOT in scope

- Changing UIKit. It stays frozen until it is deleted. Frozen now means *legacy*, not *canonical*.
- Reproducing UIKit defects in SwiftUI (§2).
- Re-litigating the measurements. The geometry rules and the divergence numbers are evidence and
  survive the reframing intact.
