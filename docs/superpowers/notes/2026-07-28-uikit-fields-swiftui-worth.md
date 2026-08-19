# UIKit `GBAlertModal` fields → worth in SwiftUI

Brief, field-by-field: what each UIKit config field does, and whether it's worth carrying into a SwiftUI
version. Discussion doc for the SwiftUI direction — verdicts are a starting point, not decided.

**Verdict legend**
- 🟢 **NATIVE** — SwiftUI does this with a modifier or layout. It's *how you write the view*, not an API field — the field simply disappears.
- 🔵 **CONTENT** — genuine per-call content. Keep it (it's the `AlertDialog` descriptor shape).
- 🟡 **BEHAVIOR** — a behavioral contract callers depend on. Needs an explicit SwiftUI decision, not a silent drop.
- 🟠 **RETHINK** — an escape hatch. SwiftUI composes this differently (e.g. a `@ViewBuilder` slot); don't port the UIKit shape.
- 🔴 **DROP** — design-system identity or cruft, not a per-call knob.

---

## `DataHolder` — 13 content fields

| # | Field | Type | What it does | SwiftUI worth |
|---|-------|------|--------------|---------------|
| 1 | `closeOnTapOverlay` | `Bool` | Tap the dimmed backdrop to dismiss | 🔵 **CONTENT** — per-use flag; already in `AlertDialog`. Maps to `.onTapGesture` on the scrim, gated by this bool. |
| 2 | `banner` | `UIImage?` | Top illustration image | 🔵 **CONTENT** — but as an **asset/`Image` reference**, not `UIImage` (`AlertDialog` already uses `ModalImage(assetName:)`, keeps it `Sendable`). |
| 3 | `title` | `String?` | Title text | 🔵 **CONTENT** — `Text`. |
| 4 | `titleAttributed` | `NSAttributedString?` | Rich/styled title | 🟠 **RETHINK** — `NSAttributedString` is a UIKit escape hatch. SwiftUI uses `AttributedString` / composed `Text`. Few real uses; don't port the UIKit type. |
| 5 | `subtitle` | `String?` | Body text | 🔵 **CONTENT** — `Text`. |
| 6 | `subtitleAttributed` | `NSAttributedString?` | Rich/styled body | 🟠 **RETHINK** — same as #4. |
| 7 | `subtitleCustomView` | `UIView?` | Arbitrary custom content in the subtitle slot (e.g. the Gc2Gs / satisfaction option rows) | 🟠 **RETHINK → the one that becomes a STRENGTH.** Becomes a native **`@ViewBuilder` content slot** — SwiftUI's whole point. Don't carry a `UIView` field; let callers compose. |
| 8 | `primaryAction` | `String?` | Primary button label | 🔵 **CONTENT**. |
| 9 | `secondaryAction` | `String?` | Secondary button label (optional) | 🔵 **CONTENT**. |
| 10 | `showCloseButton` | `Bool` | Show the top-corner ✕ | 🔵 **CONTENT** — per-use flag; already in `AlertDialog`. |
| 11 | `closeImage` | `UIImage?` | Custom ✕ icon | 🔴 **DROP** — the close glyph is *design-system identity*, not per-call content. Fixed SF Symbol / asset in the view (add a style token only if it's genuinely variable — the app uses one). |
| 12 | `dismissOnAction` | `Bool` | Whether a button tap auto-dismisses | 🟡 **BEHAVIOR** — a real contract. In the executor model teardown is *caller-owned* (`onAction` → caller clears state), so this becomes **caller/descriptor policy**, not a content field. `AlertDialog` omits it on purpose. Decide explicitly. |
| 13 | `completion` | `(GBAlertModal, ActionType) -> Void)?` | Result callback (passes the modal instance) | 🟡 **BEHAVIOR → REPLACE** — becomes `onAction(result)` / `await token.result`. The `GBAlertModal` instance param is **dropped** (value-only result). Already the executor design. |

**DataHolder summary:** 6 genuine content (banner/title/subtitle/primary/secondary + the two behavior bools) = the `AlertDialog` shape you already have. 1 (`subtitleCustomView`) → a `@ViewBuilder` slot (a win, not a port). 2 attributed-string escape hatches → drop/rethink. 1 (`closeImage`) → design token. 2 behavior contracts (`dismissOnAction`, `completion`) → caller-owned dismissal + async result.

---

## `Properties` — 29 style fields (main 18 + `ContentProperty` 7 + `ComponentSpace` 4)

### `Properties` (18)
| # | Field | Type | What it does | SwiftUI worth |
|---|-------|------|--------------|---------------|
| 1 | `baseTint` | `UIColor?` | Global tint | 🟢 **NATIVE** — `.tint()` / design token. |
| 2 | `overlayColor` | `UIColor?` | Scrim colour | 🟢 **NATIVE** — the scrim `Color` (one value; dimmed default). |
| 3 | `contentProperty` | `ContentProperty?` | Card style bundle | 🟢 **NATIVE** — card modifiers (see sub-table). |
| 4 | `margin` | `UIEdgeInsets?` | Card-to-screen-edge margin | 🟢 **NATIVE** — `.padding()` on the card. |
| 5 | `padding` | `UIMinMaxEdgeInsets?` | Inner content padding (min/max responsive) | 🟢 **NATIVE** — `.padding()`; the min/max is a UIKit constraint trick SwiftUI handles with adaptive layout. Drop the min/max complexity. |
| 6 | `bannerRatio` | `CGFloat?` | Banner aspect ratio | 🟢 **NATIVE** — `.aspectRatio(_:contentMode:)`. |
| 7 | `bannerMaxHeight` | `CGFloat?` | Banner max height | 🟢 **NATIVE** — `.frame(maxHeight:)`. |
| 8 | `bannerFixedHeight` | `CGFloat?` | Banner fixed height | 🟢 **NATIVE** — `.frame(height:)`. |
| 9 | `titleFont` | `UIFont?` | Title font | 🟢 **NATIVE** — `.font()` / design token. |
| 10 | `titleColor` | `UIColor?` | Title colour | 🟢 **NATIVE** — `.foregroundStyle()`. |
| 11 | `subtitleFont` | `UIFont?` | Body font | 🟢 **NATIVE** — `.font()`. |
| 12 | `subtitleColor` | `UIColor?` | Body colour | 🟢 **NATIVE** — `.foregroundStyle()`. |
| 13 | `buttonActionShouldMatchParent` | `Bool?` | Buttons stretch to full width | 🟢 **NATIVE** — `.frame(maxWidth: .infinity)` (app always true). |
| 14 | `buttonActionOrientation` | `NSLayoutConstraint.Axis?` | Vertical vs horizontal button stack | 🟢 **NATIVE** — `VStack`/`HStack` (app always vertical). |
| 15 | `primaryActionStyle` | `ActionStyle?` | Primary button theme (oblique/capsule/plain) | 🔴 **STYLE-IDENTITY** — becomes a SwiftUI `ButtonStyle` / view design, fixed by the design system, not a per-call field (app uses oblique primary). |
| 16 | `secondaryActionStyle` | `ActionStyle?` | Secondary button theme | 🔴 **STYLE-IDENTITY** — `ButtonStyle` (app uses plain secondary). |
| 17 | `closeButtonTint` | `UIColor?` | ✕ colour | 🟢 **NATIVE** — `.foregroundStyle()` on the close glyph. |
| 18 | `space` | `ComponentSpace?` | Inter-component spacing | 🟢 **NATIVE** — `VStack(spacing:)` / per-gap padding (see sub-table). |

### `ContentProperty` (7) — the card
| # | Field | Type | What it does | SwiftUI worth |
|---|-------|------|--------------|---------------|
| 19 | `backgroundColor` | `UIColor?` | Card background | 🟢 **NATIVE** — `.background()`. |
| 20 | `cornerRadius` | `CGFloat` | Card corner radius | 🟢 **NATIVE** — `.clipShape(RoundedRectangle(cornerRadius:))`. |
| 21 | `fixedWidthPortrait` | `CGFloat?` | Card width, portrait | 🟢 **NATIVE** — `.frame(width:)` (app: 256 phone / 300 pad). |
| 22 | `maxWidthPortrait` | `CGFloat?` | Card max width, portrait | 🟢 **NATIVE** — `.frame(maxWidth:)` (app: == fixed). |
| 23 | `fixedWidthLandscape` | `CGFloat?` | Card width, landscape | 🟢 **NATIVE** — size-class / `.frame` (app: == portrait). |
| 24 | `maxWidthLandscape` | `CGFloat?` | Card max width, landscape | 🟢 **NATIVE** — `.frame(maxWidth:)` (app: == portrait). |
| 25 | `childShouldMatchParent` | `Bool` | Content stretches to card width | 🟢 **NATIVE** — `.frame(maxWidth: .infinity)`. |

### `ComponentSpace` (4) — vertical gaps
| # | Field | Type | What it does | SwiftUI worth |
|---|-------|------|--------------|---------------|
| 26 | `banner` | `CGFloat` | Gap below banner | 🟢 **NATIVE** — `VStack` spacing / `.padding(.bottom:)`. |
| 27 | `title` | `CGFloat` | Gap below title | 🟢 **NATIVE** — same. |
| 28 | `subtitle` | `CGFloat` | Gap below subtitle | 🟢 **NATIVE** — same. |
| 29 | `interButton` | `CGFloat` | Gap between buttons | 🟢 **NATIVE** — `VStack(spacing:)`. |

**Properties summary:** ~25 of 29 are 🟢 **NATIVE** — fonts, colours, spacing, padding, widths, ratios, corner radius, orientation, match-parent all become view modifiers or layout you simply *write*, not an API you *configure*. The remaining ~2 (`primaryActionStyle` / `secondaryActionStyle`) are 🔴 **design-system identity** → `ButtonStyle`, fixed in the view, not per-call. `overlayColor` and the fonts/colours collapse into a small design-token set.

---

## The headline for discussion

- **`Properties` (style) essentially DISSOLVES in SwiftUI.** It's not an API you port — ~25/29 fields are how you write the view (modifiers + stacks), and the rest are design-system identity (button styles, tokens). The whole "pass a `Properties` bag per call" model is a UIKit necessity SwiftUI removes.
- **`DataHolder` (content) collapses to the ~7-field `AlertDialog` you already built**, plus **one `@ViewBuilder` slot** (the real upgrade over `subtitleCustomView`), with **2 behavior contracts to decide** (`dismissOnAction`, `completion` → caller-owned dismissal + `onAction`/async result) and **2 escape hatches to drop** (attributed strings; `closeImage` → token).
- **Net:** the SwiftUI version's *public surface* is dramatically smaller than the UIKit one — because most of the UIKit surface exists to reconfigure layout/appearance that SwiftUI expresses directly. What's left to *decide* is small and specific: the `@ViewBuilder` slot, the two behavior contracts, whether attributed strings are ever really needed, and where the button/design styling lives (`ButtonStyle` + tokens).
