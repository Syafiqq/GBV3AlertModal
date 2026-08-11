# Dynamic / API-sourced content in the Dialog Gallery

The gallery (`Gallery/DialogCatalog.swift` + `Gallery/DialogCatalog+*.swift`)
reproduces 26 dialog shapes from the distribution app, sourced verbatim
(strings/config/assets) from
`docs/superpowers/specs/2026-07-21-dialog-catalog.md`. Several shapes carry
fields that, in the real app, are filled in at runtime from an API response,
a caller-supplied parameter, a system error, or per-user/per-record state —
not from a fixed localized string. This file lists every catalog shape that
has such a field, what drives it in the real app, and what the demo shows
instead so a reader can tell real content from a stub at a glance.

Fields whose demo value starts with the literal `"[API] "` prefix are
stand-ins for genuinely dynamic runtime data (error text, counts, names
resolved from a model/response). A few shapes are flagged `dynamic` in the
spec but only select between a small set of *fixed* localized strings (e.g.
which permission was denied) or gate a banner behind a feature flag
(`isEligibleForJcUiVariant`); those are called out separately below since
the demo renders one fixed branch rather than an `[API]`-stubbed value.

## Shapes with `[API]`-stubbed values

| # | Shape | Real-app field(s) | Demo stub |
|---|---|---|---|
| 4 | `close-button-dismiss` | `subtitle`: `type.lastMessage` (block-class reason) / `error.message` | `subtitle: "[API] You are not allowed to send messages in this class right now."` |
| 9 | `worksheet-generating-abused` | `subtitle`: `"\(error.message)\n\n...?"` | `subtitle: "[API] Something went wrong while generating your worksheet.\n\nContinue?"` |
| 10 | `worksheet-abused-cap-banner` | `subtitle`: `error.message` | `subtitle: "[API] You've reached your daily worksheet generation limit for today."` |
| 11 | `rename-worksheet` | `subtitleCustomView` seed text: `worksheet.worksheetName` | `UITextView` pre-filled with `"[API] Chapter 3 Practice Set"` |
| 12 | `date-picker-worksheet` | `subtitleCustomView` seed date: `worksheet.dueDate` (or computed today+14/today+1) | `UIDatePicker` seeded to `Date() + 14 days` (computed, not string-tagged, but stands in for the same runtime value) |
| 13 | `streak-popup-banner` | `subtitle` format args: `day`, `bubble` (per-user streak counts) | `subtitle: "[API] You missed your 7 days streak and 15 extra bubbles. Save your streak by doing 5 questions!"` |
| 15 | `quiz-info-banner` | `subtitle` format arg: `quizName` | `subtitle: "[API] You've completed the quiz for Algebra Fundamentals."` |
| 16 | `quiz-begin-banner` | `subtitle` format args: `className`/`topic`, `questionCount` | `subtitle: "[API] The GenieClass Algebra Fundamentals Quiz contains 10 MCQ questions and should take about 15 minutes to complete. Are you ready?"` |
| 19 | `credit-deduction-popup` | `subtitle` format args: `upcomingViewModel.subjectName`, `credit` | `subtitle: "[API] Joining this class will use 1 Mathematics lesson credit.\n\nMathematics lesson credits left: 5"` |
| 20 | `ai-notes-ready-banner` | `subtitle` format arg: `topicName` | `subtitle: "[API] Your Personalised Summary Notes for Algebra Fundamentals is ready!"` |
| 21 | `exit-worksheet-confirm-banner` | `subtitle` format arg: `unAnsweredRemaining` (count) | `subtitle: "[API] Don't give up, you still have 3 questions remaining. You can do it!"` |
| 22 | `worksheet-ready-timer-banner` | `subtitleAttributed`: rendered from `worksheet.worksheetTypeEnum`, `calculateRemainingTime(interval)`, `viewModel.isEligibleToShowTimedWorksheetNudge` | `subtitleAttributed: "[API] You have 30 minutes remaining to complete this Practice Worksheet."` |
| 24 | `badge-unlock-single` | `banner`: `UIImage(named: badge.localImageName)` (per-badge asset, not one of the 12 copyable static assets); `subtitleAttributed` badge-name insert: `badge.name` | `banner`: generated solid-color placeholder image (`DialogCatalog.placeholderImage`); badge name shown as the literal `"Math Wizard"` (not `[API]`-prefixed, but stands in for the per-badge value) |
| 26 | `badge-detail-popup` | `subtitleCustomView`: entire view built at runtime from the tapped `Domain.VBadgesEntity` (artwork + name + description) | Minimal placeholder view (artwork swatch + labels) with `"[API] Math Wizard"` / `"[API] Solved 50 algebra questions without a hint."` |

## Shapes with dynamic behavior *not* stubbed with `[API]`

These are flagged `dynamic` in the catalog spec, but the "dynamic" part is a
branch between a small number of fixed, already-localized strings, or a
feature-flag gate on a banner — not per-record API data. The demo renders
one fixed branch and does not model the flag/branch selection itself.

| # | Shape | Real-app behavior | Demo behavior |
|---|---|---|---|
| 2 | `standard-two-button` | `title`/`subtitle` are caller-supplied strings at ~20 call sites (`showConfirmation(title:message:)`) | Shown with a representative stub: `title: "[API] Confirm action"`, `subtitle: "[API] Are you sure you want to proceed?"` (this one *is* `[API]`-prefixed, since every real call site supplies different text) |
| 3 | `title-nil-error` | `subtitle`: raw system `error.localizedDescription` (`WKNavigationDelegate` failure handlers) | `subtitle: "[API] The operation couldn't be completed. (NSURLErrorDomain error -1009.)"` (also `[API]`-prefixed — always system/dynamic per the spec) |
| 5 | `permission-denied-settings` | `subtitle` selected at runtime from 3 fixed localized keys depending on which permission (camera/photo/mic) is missing | Shown with one fixed variant: `"Allow Geniebook to access your camera in your device's settings."` |
| 8 | `force-update-banner` | banner hidden (`nil`) when `isEligibleForJcUiVariant` is true | Banner (`img_illust_gc_finished_quiz`) shown unconditionally; the flag isn't modeled |
| 17 | `onboarding-welcome-nobanner` | `subtitle` ternary on `isEligibleForJcUiVariant` (`lc_label_uiux_announcer_description_variant` vs `label_welcome_description`) | Shown with the "announcer" variant subtitle only |
| 18 | `onboarding-trial-banner` | banner hidden when `isEligibleForJcUiVariant` is true | Banner (`img_illust_free_trial_ended`) shown unconditionally |
| 23 | `worksheet-timeup-timer-banner` | banner hidden when `isEligibleForJcUiVariant` is true | Banner (`img_timer_alert`) shown unconditionally |

## Shapes with no dynamic content

The remaining 12 shapes (`standard-one-button`, `oblique-red-leave-confirm`,
`database-error-banner`, `switch-device-recommendation`,
`badge-unlock-multi`, and others not listed above) use only static,
already-localized strings and static assets per the catalog spec — nothing
to stub.

## Cross-cutting note

`isEligibleForJcUiVariant` (from
`(UIApplication.shared.delegate as? ProvideObjectResolver)?.objectResolver?.isEligibleForJcUiVariant`)
is the single most common conditional gate in the source app — it hides the
banner on 10 of the 13 banner-bearing shapes when true. This demo does not
implement the flag; every banner-bearing entry always shows its banner.
