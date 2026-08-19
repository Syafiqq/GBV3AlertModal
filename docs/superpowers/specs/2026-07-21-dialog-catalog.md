# V3AlertModal Dialog Catalog

Source repo (read-only): `geniebook-student-ios-distribution`
Preset layer read first:
- `Common/Common/Custom/Components/AlertModal/V3AlertModal.swift`
- `Common/Common/Custom/Components/AlertModal/V3AlertModal+GBV3AlertModal.swift` (`properties`, `popupProperties`, default `holder`, action-style themes)
- `Common/Common/Custom/Components/AlertModal/V3AlertModal+Worksheet.swift` (`renameWorksheet:`, `selectedDateAt:`, `reopenWorksheet:`, `changeWorksheetDueDateAt:`)

Three more convenience-init extension files were discovered while tracing call sites (not in the two files named in the brief) and are included below:
- `Geniebook/PresentationLayer/UIKit/Component/Dialog/StreakPopUpView.swift` — `init(streakType:completion:)`
- `Geniebook/PresentationLayer/UIKit/Component/Dialog/BadgesPopUpView.swift` — `init(badges:completion:)`
- `Geniebook/Shared/Helpers/QuestionHelper.swift:110` — `init(switchDeviceRecommendation:)`

Call sites scanned: **132** occurrences of `V3AlertModal(` outside the library folder, across **52** files.
Distinct shapes cataloged below: **26**.

---

## Design tokens used

### Colors (`UIColor.Genie.*` / `Colors.*`, resolved from `Common/Common/Constants/Colors.swift` and `Common/Common/Custom/Extensions/UIColorExtension.swift`)

| Token | Hex | Where used |
|---|---|---|
| `UIColor.Genie.accentSecondary` | `#F7A440` | `properties.baseTint` |
| `UIColor.Genie.primary` (= `GBPNavy`) | `#262262` | `properties.titleColor` (default) |
| `UIColor.Genie.textPrimaryDark` | `#333333` | `properties.subtitleColor` (default) |
| `UIColor.Genie.GBPNavy` | `#262262` | `popupProperties`/`badgeProperties`/`streakModalProperties` titleColor |
| `UIColor.Genie.labelSubtitle` | `#515151` | `popupProperties`/`badgeProperties`/`streakModalProperties` subtitleColor; permission-alert subtitleColor override |
| `UIColor.Genie.accentSecondaryDark` | `#F7941E` | `plainTheme.titleColor`, `obliqueBottomLeftTheme.unPressedColor` (default secondary/primary button colors) |
| `UIColor(netHex: 0x038CD5)` | `#038CD5` | `obliqueBottomLeftTheme.pressedColor` (default) |
| `UIColor.Genie.borderLight` | `#B4B4B4` | `obliqueBottomLeftTheme.disabledColor`, disabled button states |
| `UIColor.Genie.orangeMandarin` | `#E57B41` | `obliqueBottomLeftTheme.shadowColor` (default) |
| `UIColor.Genie.pastelRed` | `#F56468` | "leave class" red oblique button — `unPressedColor`/`pressedColor` |
| `UIColor.Genie.englishVermillion` | `#C54A47` | "leave class" red oblique button — `shadowColor` |
| `Colors.geniebook_blue_sky` | `#63C1E9` | `switchDeviceRecommendation` titleAttributed color |
| `.white` | `#FFFFFF` | `contentProperty.backgroundColor`, button title colors |

### Fonts (`FontHelper.SHSans.*` / `.DMSans.*`, resolved from `Common/Common/Helpers/FontHelper.swift`)

`SHSans` and `DMSans` are semantic wrappers; on English locale they resolve to the **OpenSans** family (Vietnamese locale swaps to BeVietnamPro — out of scope for this catalog). Files live at `Others/Fonts/OpenSans-*.ttf`.

| Semantic case | Resolves to (EN) | File |
|---|---|---|
| `SHSans.regular` / `DMSans.regular` | OpenSans-Regular | `Others/Fonts/OpenSans-Regular.ttf` |
| `SHSans.medium` / `DMSans.medium` | OpenSans-Medium | `Others/Fonts/OpenSans-Medium.ttf` |
| `SHSans.semiBold` | OpenSans-SemiBold | `Others/Fonts/OpenSans-SemiBold.ttf` |
| `SHSans.bold` / `DMSans.bold` | OpenSans-Bold | `Others/Fonts/OpenSans-Bold.ttf` |
| `SHSans.heavy` | OpenSans-ExtraBold | `Others/Fonts/OpenSans-ExtraBold.ttf` |

Sizes used across dialogs: title 24 (bold/heavy), 16 (badge title bold); subtitle 15–16 (regular/medium); button titles 16 (heavy).

---

## Static assets to copy

| Asset | `.imageset` path | Used by |
|---|---|---|
| `img_database_error` | `Geniebook/Assets.xcassets/img_database_error.imageset` | database-error-banner (static) |
| `img_illust_gc_finished_quiz` | `Geniebook/Assets.xcassets/img_illust_gc_finished_quiz.imageset` | quiz-info-banner, quiz-begin-banner, force-update-banner (conditional) |
| `img_illust_abused_worksheet` | `Geniebook/Assets.xcassets/img_illust_abused_worksheet.imageset` | worksheet-abused-cap-banner (conditional) |
| `img_illust_ai_notes_banner` | `Geniebook/Assets.xcassets/img_illust_ai_notes_banner.imageset` | ai-notes-ready-banner (conditional) |
| `img_illust_onboarding` | `Geniebook/Assets.xcassets/img_illust_onboarding.imageset` | NPS survey popup (conditional) |
| `img_illust_free_trial_ended` | `Geniebook/Assets.xcassets/img_illust_free_trial_ended.imageset` | onboarding-trial-banner variant A (conditional) |
| `img_illust_end_trial` | `Geniebook/Assets.xcassets/img_illust_end_trial.imageset` | onboarding-trial-banner variant B (conditional) |
| `ic_exit_worksheet` | `Geniebook/Assets.xcassets/Worksheet/WorkingSpace/ic_exit_worksheet.imageset` | exit-worksheet-confirm-banner (conditional) |
| `img_timer_alert` | `Geniebook/Assets.xcassets/img_timer_alert.imageset` | worksheet-ready-timer-banner, worksheet-timeup-timer-banner (conditional) |
| `streak_lose` | `Geniebook/Assets.xcassets/Streak/streak_lose.imageset` | streak-popup-banner (salvage/notSalvage cases, conditional) |
| `streak_win` | `Geniebook/Assets.xcassets/Streak/streak_win.imageset` | streak-popup-banner (winStreak case, conditional) |
| `img_badge_multi_achievement` | `Geniebook/Assets.xcassets/Badges/img_badge_multi_achievement.imageset` | badge-unlock-multi |

Count: **12 static assets**. All twelve are shown/hidden by `isEligibleForJcUiVariant` in several shapes (nil banner when the flag is true) except `img_database_error` and `img_badge_multi_achievement`, which are unconditional.

Not copyable — dynamic/API-sourced banner: `badge.localImageName` (badge-unlock-single) is resolved per-badge at runtime; stub with `[API]` placeholder art in the demo.

---

## Localized strings to copy (`en` from `Geniebook/Supporting Files/en.lproj/Localizable.strings`)

Deduped, alphabetical by key. All confirmed present unless marked NOT FOUND.

```
account_deletion_accept = "Yes, request deletion"
account_deletion_confirmation = "Account deletion is irreversible. Are you sure you want to proceed?"
account_deletion_decline = "No, keep my account"
action_close = "Close"
action_continue = "Continue"
action_dismiss = "Dismiss"
action_done = "Done"
action_not_now = "Not now"
action_okay = "Okay"
action_open = "Open"
action_practice_something_else = "I'll practise something else"
action_proceed = "Proceed"
action_retry = "Retry"
action_settings = "Settings"
action_view_my_badges = "view my badges"
action_yes = "Yes"
action_yes_join_class = "Yes, join class"
alert_subtitle_feedback_submitted = "Thank you for your feedback! Your feedback helps us to improve your experience."
alert_title_feedback_submitted = "Feedback submitted"
answer_delete_image_dialog_title = "Delete Image Answer"
application_update = "A new update is ready!"
cant_salvage_caption = "You lost your %@ days streak, but everyone needs a break now and then. Be sure to come back tomorrow to try again!"
canvas_close_description = "Do you want to save the changes?"
canvas_close_title = "Leave Drawing"
change_language_desc = "Do you want to change language to %@?\nChanging the language will restart the app."
change_language_label = "Change Language?"
change_password = "Password"
check_version = "Check Version"
delete_image_answer = "Are you sure want to delete this image answer?"
dialog_message_unlock_new_badge = "you unlocked the %@ badge!"
dialog_message_unlocked_new_badges = "You unlocked new badges."
dialog_title_congratulations = "Congratulations!"
dialog_title_failed = "Failed"
dialog_title_session_expired = "Your session has expired"
dialog_title_session_expired_deletion = "You have been logged out"
enable_microphone_permission_iOS = "Please enable microphone permission to use this feature.\nEnable microphone permission by going to settings -> Geniebook -> Microphone."
error_change_profile_picture = "Failed to prepare data"
error_server_down = "Oops! The server is not responding at this time. Please try again later"
error_server_down_title = "Server is unavailable"
error_survey_connection = "Couldn't connect to survey server"
failed_to_save_photo = "Failed to save photo"
generating_worksheet = "Generating Worksheet"
genieask_failed_send_message_title = "Something went wrong"
genieask_label_access_denined = "Access Denied"   # NOTE: typo in key, kept verbatim
genieask_label_limit_exceeded = "Message not found"
genieask_label_limit_exceeded_detail = "Sorry, we are unable to retrieve messages that are sent earlier than your joining date"
genieclass_welcome_title = "Welcome!"
go_to_app_store = "Go to App Store"
image_picker_max_picture_warning = "You can select maximum %d images"
in_app_purchase = "In-App Purchase"
keep_watching = "Keep watching"
label_action_got_it = "Got it"
label_attachment_file_limit_2 = "(not exceeding 4MB/image)"
label_class_is_recorded = "This class is being recorded."
label_delete_account_title = "Delete account?"
label_exit_worksheet_dialog_body = "Don't give up, you still have %d questions remaining. You can do it!"
label_exit_worksheet_dialog_cancel = "Keep going!"
label_exit_worksheet_dialog_confirm = "I'll be back!"
label_exit_worksheet_dialog_title = "Hang in there!"
label_genieask = "Teacher Chat"
label_limit_exceeded = "Limit Exceeded"
label_limit_exceeded_detail = "Your total attached file size is more than 16MB. Please reduce the number of files or reduce file size and try again."
label_record_audio_reach_limit = "Maximum file size limit of 16MB reached"
label_record_audio_stopped = "Recording Stopped"
label_restricted = "Restricted"
label_restricted_word_genieask = "Your message could not be sent because it contains restricted words."
label_upload_in_progress = "Recording on its way!"
label_worksheet_generated = "Worksheet Generated"
lc_ai_notes_banner_cta_negative = "Later"
lc_ai_notes_banner_cta_positive = "Bring me there!"
lc_ai_notes_banner_title = "Your Personalised Summary Notes for %@ is ready!"
lc_ai_notes_note_generate_failed_description = "We're already working to fix it.\nA notification will be sent as soon as it's ready."
lc_ai_notes_note_generate_failed_title = "Oops! Summary Error"
lc_ai_notes_quiz_ai_note_pdf_error = "Failed to prepare PDF, try again later"
lc_allow_permission = "Allow Permission"
lc_are_you_ready = "Are you ready?"
lc_credit_use_title = "Confirm Credit Use"
lc_fetch_api_error_common_desc = "We're fixing our servers as fast as we can.\nTake a break and try again later."
lc_gclass_credit_use_cta = "Join class"
lc_gclass_credit_use_description = "Joining this class will use 1 %1$@ lesson credit.\n\n%1$@ lesson credits left: %2$d"
lc_gsmart_no_credit_use_description = "This worksheet costs 1 credit to create. You've used all your credits for this month."
lc_label_hello_there = "Hello there!"
lc_label_im_ready = "I'm ready"
lc_label_maybe_later = "Maybe later"
lc_label_submit_for_marking = "Submit for marking"
lc_label_uiux_announcer_description_variant = "Let's explore Geniebook!"
lc_no_credit_use_cta = "Contact us for more credits"
lc_no_credit_use_title = "You're out of credits"
lc_our_team_will_contact_you_soon = "Our team will be in contact with you soon."
lc_picker_max_file_warning = "You can select maximum %d files"
lc_request_camera_permission = "Allow Geniebook to access your camera in your device's settings."
lc_request_camera_photo_permission = "Allow Geniebook to access your camera and photos in your device's settings."
lc_request_photo_permission = "Allow Geniebook to access your photos in your device's settings."
lc_request_submitted = "Request submitted"
lc_resubscribe_to_continue = "Resubscribe to continue learning with Geniebook"
lc_your_subscription_has_ended_1 = "Subscription has ended"
label_welcome_description = "Get started with our AI-generated worksheets, personalised reports, classes, and more!"
message_survey_server_unavailable = "Survey server might be currently unavailable"
message_worksheet_generate_confirmation = "Do you want to generate worksheet"
microphone_permission_denied = "Microphone Permission Denied."
missed_streak = "You missed your streak!"
nps_survey_dialog_content = "Take our quick survey and gain bubbles!"
nps_survey_dialog_negative_button = "Not Now"
nps_survey_dialog_positive_button = "Proceed to feedback"
nps_survey_dialog_title = "Help us make your experience better"
password_change_success = "Change password success"
photo_saved = "Photo saved"
recorded_class_is_coming = "This recording is processing and will be available within 2 days after the class."
redirect_new_page = "Redirecting to New Page"
salvage_caption = "You missed your %1$@ days streak and %2$@ extra bubbles. Save your streak by doing 5 questions!"
select_date = "Select Date"
subject_english_secondary_switch_recommendation_desc = "For the best experience in reading and understanding long passages, you may wish to switch over to the laptop or tablet to complete this exercise"
subject_english_secondary_switch_recommendation_title = "Device Switch Recommended"
subscribe_to_continue = "Subscribe to continue learning with Geniebook"
title_trial_ended = "Free trial has ended"
unknown_error_occured = "Unknown error occured"
video_will_be_hidden = "Your video will be hidden, but you will still be able to listen to the lesson. Are you sure?"
view_pricing_plans = "View pricing plans"
we_missed_you = "We missed you!"
win_streak_caption = "Awesome! You completed an amazing 30-day learning streak. You're steadily building a wonderful learning habit."
worksheet_abused_cap1_title = "Daily worksheet limit reached"
worksheet_abused_cap2_title = "Topic worksheets limit reached"
worksheet_rename = "Rename Worksheet"
you_did_it = "You did it!"
you_do_not_have_microphone = "You don't have microphone."
zoom_ask_audio_label = "The host would like you to unmute"
zoom_leave_lesson = "Leave Class"
zoom_stay_muted_label = "Stay Muted"
zoom_unmute_label = "Unmute"
```

Also present, hardcoded English **literals in Swift** (not localized keys) that back several shapes below — copied verbatim, no lookup needed: `"You're leaving?"`, `"The live class has not ended yet. Are you sure you want to leave?"`, `"Yes"`, `"No"`, `"Setting"`, `"Please enable microphone acces"` (typo, kept as-is), `"Go to Settings"`, `"Cancel"`, `"Question Time!"`, `"Do you want to volunteer to speak?"`, `"You have been selected!"`, `"Select \"Unmute\" to speak."`, `"Unmute"`, `"Class Has Ended!"`, `"Thanks for joining GenieClass."`, `"Close"`, `"Uh-oh! Something\nwent a bit wonky"`, `"Our team is on it!  Refresh the page and try again."`, `"Refresh page"`, `"Back to schedule"`, `"Oops"`, `"Great Effort"`, `"You've completed the quiz for {name}."`, `"Quiz Time"`, `"The GenieClass {name} Quiz contains {n} MCQ questions and should take about 15 minutes to complete. Are you ready?"`, `"Let's go"`, `"Quiz Ended"`, `"Quiz expires 10 minutes before your live class starts."`, `"Access to Quiz will end at 4 PM (SGT) on the day after your lesson."`, `"Bubble limit!"`, `"Got it"`, `"Tap \"Continue\" to keep working on the worksheet, or submit for marking."` (paraphrased from source), `"The changes has been applied, the app will close to take effect"`, `"Thank you for your purchase"`.

---

## Shapes

### 1. `standard-one-button`
- **category**: cross-cutting (informational acknowledgement)
- **preset**: `properties` (no `.copy`)
- **holder**: title + subtitle set, `primaryAction` only (secondary nil), `showCloseButton=false`
- **text**: title `dialog_title_failed` = "Failed"; subtitle `you_do_not_have_microphone` = "You don't have microphone."; primary `action_okay` = "Okay"
- **banner/image**: none
- **dynamic**: none
- **source**: `GenieAsk/GenieAsk/Common/Helper/Audio/AudioRecordManager.swift:245`

### 2. `standard-two-button`
- **category**: cross-cutting (confirm/cancel — the most common shape; ~20 sites reduce to this)
- **preset**: `properties` (no `.copy`)
- **holder**: title + subtitle set, `primaryAction` + `secondaryAction`, `showCloseButton=false`
- **text**: title/subtitle param (`"showConfirmation(title:message:)"`), primary `action_yes` = "Yes", secondary `action_no` = "No"
- **banner/image**: none
- **dynamic**: `title`/`message` are caller-supplied strings
- **source**: `Geniebook/Custom/Extensions/UIViewControllerExtensions.swift:17`
- **also covers** (text-only variants, same structure): volunteer prompt ("Question Time!"), unmute prompt ("You have been selected!"), mic-access-request ("Setting"/"Please enable microphone acces"), room-token-failure ("Uh-oh! Something went a bit wonky"), help-redirect (`redirect_new_page`), welcome/consent (`genieclass_welcome_title`), multiple-connection warning ("Oops"), streak-generate confirmation, change-language confirmation (`change_language_label`, dynamic `language.value`), account-deletion confirm/accepted, delete-image-answer confirm, canvas-close confirm, bubble-limit warning, class-ended notice (1-button subset), NPS error alert, password-change success (1-button subset), size-limit exceeded alerts (4MB/16MB), etc.

### 3. `title-nil-error`
- **category**: cross-cutting (WKWebView load failures)
- **preset**: `properties` (no `.copy`)
- **holder**: `title: nil`, `subtitle: error.localizedDescription`, only default `primaryAction` ("action_okay")
- **text**: primary `action_okay` = "Okay"; subtitle is the raw system `error.localizedDescription` **[DYNAMIC/system]**
- **banner/image**: none
- **dynamic**: `error.localizedDescription` — always system/dynamic
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/V3GenieClass/Components/V3GenieClassPracticeQuizViewController.swift:485`
- **repeats**: identically at :505 (same file), `V3GenieClassAiNoteViewController.swift:530/550`, `WorkingSpacePendingCommentPreviewView.swift:494/509`, `WorkingSpaceChineseNarrationPreviewView.swift:547/562`, `V2WorkingSpaceCompletedViewController.swift:1122/1137` — 6 files, 12 call sites total, all `WKNavigationDelegate` failure handlers

### 4. `close-button-dismiss`
- **category**: GenieAsk-ChatPage
- **preset**: `properties` (no `.copy`)
- **holder**: `closeOnTapOverlay: true`, title + dynamic subtitle, `primaryAction: "action_close"`, `secondaryAction: nil`, `showCloseButton: true`, `dismissOnAction: true`
- **text**: title `genieask_label_access_denined` = "Access Denied" (typo in key, kept); primary `action_close` = "Close"
- **banner/image**: none
- **dynamic [API]**: `subtitle: type.lastMessage` — message text varies by `GABlockClassType` (block-class reason)
- **source**: `GenieAsk/GenieAsk/PresentationLayer/UIKit/Controller/ChatPage/GAChatPageViewController.swift:1067`
- **also covers**: `:1088` — same shape, `title: ""` (empty), `subtitle: error.message` **[API]**

### 5. `permission-denied-settings`
- **category**: GenieAsk (camera/mic permission)
- **preset**: `properties.copy(padding: custom(20/30 asym), titleFont: bold/heavy 24, subtitleColor: labelSubtitle, space: custom(title:12, subtitle:20, interButton:8))`
- **holder**: `closeOnTapOverlay: true`, title + subtitle, `primaryAction: "action_settings"`, `secondaryAction: "action_not_now"` (or `"action_cancel"`)
- **text**: title `lc_allow_permission` = "Allow Permission"; subtitle `lc_request_camera_permission` = "Allow Geniebook to access your camera in your device's settings."; primary `action_settings` = "Settings"; secondary `action_not_now` = "Not now"
- **banner/image**: none
- **dynamic**: in `GAChatPageViewController+ChatBox.swift:320` the subtitle is chosen at runtime from 3 localized keys (`lc_request_camera_photo_permission` / `lc_request_photo_permission` / `lc_request_camera_permission`) depending on which permission(s) are missing
- **source**: `GenieAsk/GenieAsk/PresentationLayer/UIKit/Component/Gallery/CollectionCell/GACameraCell.swift:178`
- **repeats**: `AudioRecordManager.swift:200` (mic, secondary=`action_cancel`), `GAChatPageViewController+ChatBox.swift:320`

### 6. `oblique-red-leave-confirm`
- **category**: GenieClass-OnlineLesson
- **preset**: `properties.copy(primaryActionStyle: .obliqueBottomLeft(custom red theme: unPressed/pressed = pastelRed #F56468, shadow = englishVermillion #C54A47, titleColor = white))`
- **holder**: title + subtitle literal, `primaryAction: "Yes"`, `secondaryAction: "No"`
- **text**: title "You're leaving?"; subtitle "The live class has not ended yet. Are you sure you want to leave?"; primary "Yes"; secondary "No" — all hardcoded literals, not `.localized`
- **banner/image**: none
- **dynamic**: none
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/GenieClass/OnlineLesson/V1OnlineLessonViewController.swift:1813`
- **repeats**: `V2LiveKitSmallClassViewController.swift:1464`, `V2LiveKitOnlineLessonViewController.swift:2152`

### 7. `database-error-banner`
- **category**: Common/ErrorHandling
- **preset**: `popupProperties.copy(bannerRatio: 295/256, bannerMaxHeight: 320, bannerFixedHeight: 256)`
- **holder**: `closeOnTapOverlay: false`, banner set, title + subtitle, `primaryAction: "action_okay"`, `secondaryAction: nil`
- **text**: title = `genieask_failed_send_message_title` + " :(" = "Something went wrong :("; subtitle `lc_fetch_api_error_common_desc` = "We're fixing our servers as fast as we can.\nTake a break and try again later."; primary "Okay"
- **banner/image**: `img_database_error` (static, unconditional)
- **dynamic**: none
- **source**: `Common/Common/Helper/UiKitErrorHandlerHelper+Common.swift:72`
- **also**: same shape reused inside `Common/Common/Custom/Components/V2AlertModal/V2AlertModel+Error.swift:12-34` (`presentError` connection-error branch, invoked from `BaseError.swift:18/34`)

### 8. `force-update-banner`
- **category**: App-level (version gate)
- **preset**: `popupProperties.copy(bannerRatio: 320/320, bannerMaxHeight: 320, bannerFixedHeight: 256)`
- **holder**: `closeOnTapOverlay: false`, banner conditional, title + subtitle, `primaryAction` only, `dismissOnAction: true`
- **text**: title `application_update` = "A new update is ready!"; subtitle `wrong_version_arlet` = "Head over to the App Store..."; primary `go_to_app_store`.capitalizingFirstLetter() = "Go to App Store"
- **banner/image**: `isEligibleForJcUiVariant ? nil : UIImage(named: "img_illust_gc_finished_quiz")` **[conditional on feature flag]**
- **dynamic**: `isEligibleForJcUiVariant` (from `ProvideObjectResolver`)
- **source**: `Geniebook/Shared/Services/APIClient.swift:77`

### 9. `worksheet-generating-abused`
- **category**: Worksheet (generation abuse — base tier)
- **preset**: `properties` (no `.copy`)
- **holder**: `closeOnTapOverlay: false`, title + dynamic subtitle, `primaryAction: "action_continue"`, `secondaryAction: "action_cancel"`, `showCloseButton: false`
- **text**: title `generating_worksheet` = "Generating Worksheet"; primary "Continue"; secondary "Cancel"
- **banner/image**: none
- **dynamic [API]**: `subtitle = "\(error.message)\n\n\("action_continue".localized)?"`
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/Worksheet/V1WorksheetViewController.swift:984`
- **repeats** (10 sites, all byte-identical structure): `V1WorksheetViewController.swift:1217/1370/1523`, `V2CustomisedWorksheetGeneratorViewController.swift:935`, `V2StarterWorksheetGeneratorViewController.swift:792`, `V2RevisionWorksheetGeneratorSampleViewController.swift:594`, `V1OnlineLessonViewController.swift:862`, `V2LiveKitOnlineLessonViewController.swift:807`, `V2RecordedPreviewViewController.swift:1538`, `V1ProgressViewController.swift:1402`, `NotificationViewController.swift:575`, `V3GenieClassRecordedViewController.swift:1291`, `V3GenieClassDashboardViewController.swift:1112`

### 10. `worksheet-abused-cap-banner`
- **category**: Worksheet (generation abuse — cap tier 1/2)
- **preset**: `popupProperties.copy(bannerRatio: 320/197, bannerMaxHeight: 216, bannerFixedHeight: 184)`
- **holder**: `closeOnTapOverlay: false`, banner conditional, title + dynamic subtitle, `primaryAction: "action_proceed"`, `secondaryAction: "action_practice_something_else"`, `showCloseButton: false`
- **text**: title `worksheet_abused_cap1_title` = "Daily worksheet limit reached" (cap2 variant: `worksheet_abused_cap2_title` = "Topic worksheets limit reached"); primary "Proceed"; secondary "I'll practise something else"
- **banner/image**: `isEligibleForJcUiVariant ? nil : UIImage(named: "img_illust_abused_worksheet")` **[conditional]**
- **dynamic [API]**: `subtitle = error.message`
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/Worksheet/Generator/Customised/V2CustomisedWorksheetGeneratorViewController.swift:965` (cap1) / `:1003` (cap2)
- **repeats** (12 sites across cap1+cap2, same structure, only title-key differs): `V2StarterWorksheetGeneratorViewController.swift:822/860`, `V2RevisionWorksheetGeneratorSampleViewController.swift:624/662`, `V1WorksheetViewController.swift:1020/1060`, `V1OnlineLessonViewController.swift:898/938`, `V2LiveKitOnlineLessonViewController.swift:843/883`, `V2RecordedPreviewViewController.swift:1574/1614`, `V1ProgressViewController.swift:1433/1472`, `NotificationViewController.swift:611/651`, `V3GenieClassRecordedViewController.swift:1327/1367`, `V3GenieClassDashboardViewController.swift:1148/1188`

### 11. `rename-worksheet`
- **category**: Worksheet
- **preset**: convenience init `renameWorksheet:` → `properties.copy(padding: custom, titleFont: heavy 24, space: custom(title:16, subtitle:32, interButton:8))`
- **holder**: `closeOnTapOverlay: true`, `title: "worksheet_rename"`, `subtitleCustomView`: bordered `UITextView` pre-filled with the worksheet's current name, `primaryAction: "action_done"`, `secondaryAction: "action_cancel"`
- **text**: title `worksheet_rename` = "Rename Worksheet"; primary `action_done` = "Done"; secondary `action_cancel` = "Cancel"
- **banner/image**: none
- **dynamic [API]**: initial textview content = `worksheet.worksheetName ?? ""`
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/Worksheet/V1WorksheetViewController.swift:385`

### 12. `date-picker-worksheet`
- **category**: Worksheet
- **preset**: convenience inits `selectedDateAt:` / `reopenWorksheet:` / `changeWorksheetDueDateAt:` → `properties.copy(padding: custom, titleFont: heavy 24, space: custom(title:0, subtitle:8, interButton:8))`
- **holder**: `closeOnTapOverlay: true`, `title: "select_date"`, `subtitleCustomView`: `UIDatePicker` (wheels style, min = tomorrow, max = +2y), `primaryAction: "action_done"`, `secondaryAction: "action_cancel"`
- **text**: title `select_date` = "Select Date"; primary "Done"; secondary "Cancel"
- **banner/image**: none
- **dynamic [API]**: initial date = `worksheet.dueDate` (change-due-date) or computed today+14/today+1 (reopen/default)
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/Worksheet/V1WorksheetViewController.swift:410` (`changeWorksheetDueDateAt:`)
- **repeats**: `:433` (`reopenWorksheet:`)

### 13. `streak-popup-banner`
- **category**: Worksheet/Streak
- **preset**: private `streakModalProperties = properties.copy(padding: custom, bannerRatio: 200/168 base (overridden per-case), bannerMaxHeight/FixedHeight: 168, titleFont: DMSans.bold 24, titleColor: GBPNavy, subtitleFont: DMSans.regular 16, subtitleColor: labelSubtitle, space: custom(banner:16, title:12, subtitle:24, interButton:8))`
- **holder**: `closeOnTapOverlay: false`, banner conditional, title + dynamic-format subtitle, `primaryAction` only, `secondaryAction: nil`
- **text**: (salvage case) title `missed_streak` = "You missed your streak!"; subtitle `salvage_caption` format = "You missed your %1$@ days streak and %2$@ extra bubbles. Save your streak by doing 5 questions!"; primary `action_continue` = "Continue"
- **banner/image**: `isEligibleForJcUiVariant ? nil : UIImage(named: "streak_lose")` (salvage/notSalvage) or `"streak_win"` (winStreak) **[conditional]**
- **dynamic [API]**: `day`, `bubble` (streak popup detail counts), `isEligibleForJcUiVariant`
- **source**: `Geniebook/PresentationLayer/UIKit/Component/Dialog/StreakPopUpView.swift:42` (init), invoked at `Geniebook/PresentationLayer/UIKit/Controller/Worksheet/V1WorksheetActiveViewController.swift:627`

### 14. `switch-device-recommendation`
- **category**: Worksheet/Content (subject-specific device nudge)
- **preset**: `properties`/`holder` defaults (no properties override); uses `titleAttributed`/`subtitleAttributed` instead of plain strings
- **holder**: `titleAttributed`: DMSans.bold 16, color `geniebook_blue_sky` (#63C1E9); `subtitleAttributed`: DMSans.medium 16, color `textPrimaryDark`; all else default (`primaryAction: "action_okay"`, `closeOnTapOverlay: true`)
- **text**: title `subject_english_secondary_switch_recommendation_title` = "Device Switch Recommended"; subtitle `subject_english_secondary_switch_recommendation_desc` = "For the best experience..."
- **banner/image**: none
- **dynamic**: none
- **source**: `Geniebook/Shared/Helpers/QuestionHelper.swift:111`, invoked at `V1PrePostQuizWorkingSpaceViewController.swift:1119` and `V1WorkingSpaceViewController.swift:2355`

### 15. `quiz-info-banner`
- **category**: GenieClass (quiz completed/ended, single acknowledgement)
- **preset**: `popupProperties.copy(bannerRatio: 320/229, bannerMaxHeight: 216, bannerFixedHeight: 184)`
- **holder**: `closeOnTapOverlay: false`, banner conditional, title + dynamic/literal subtitle, `primaryAction` only ("Got it")
- **text**: title "Great Effort" (literal); subtitle "You've completed the quiz for {quizName}." **[dynamic]**; primary "Got it" (literal). "Quiz Ended" variant uses literal subtitle "Quiz expires 10 minutes before your live class starts." or `Access to Quiz will end at 4 PM (SGT)...`
- **banner/image**: `isEligibleForJcUiVariant ? nil : UIImage(named: "img_illust_gc_finished_quiz")` **[conditional]**
- **dynamic [API]**: `quizName`, `isEligibleForJcUiVariant`
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/V2GenieClass/RecordedClassPreviewer/V2RecordedPreviewViewController.swift:725`
- **repeats**: `V3GenieClassDashboardUiHelper.swift:95` (completed), `:206` (ended), `V1PrePostQuizWorkingSpaceViewController.swift:1134` (ended), `V3GenieClassDashboardViewController.swift:1805` (ended)

### 16. `quiz-begin-banner`
- **category**: GenieClass (quiz begin prompt)
- **preset**: `popupProperties.copy(bannerRatio: 320/229, bannerMaxHeight: 216, bannerFixedHeight: 184)`
- **holder**: `closeOnTapOverlay: false`, banner conditional, title + dynamic subtitle, `primaryAction` + `secondaryAction`
- **text**: title "Quiz Time" (literal); subtitle "The GenieClass {className} Quiz contains {questionCount} MCQ questions and should take about 15 minutes to complete. Are you ready?" **[dynamic]**; primary "Let's go" (literal); secondary `action_dismiss`.capitalizingFirstLetter() = "Dismiss"
- **banner/image**: `isEligibleForJcUiVariant ? nil : UIImage(named: "img_illust_gc_finished_quiz")` **[conditional]**
- **dynamic [API]**: `className`/`topic`, `questionCount`, `isEligibleForJcUiVariant`
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/V2GenieClass/RecordedClassPreviewer/V2RecordedPreviewViewController.swift:774`
- **repeats**: `V3GenieClassDashboardUiHelper.swift:130` (shared pre/post-quiz begin helper)

### 17. `onboarding-welcome-nobanner`
- **category**: Campaign/Onboarding
- **preset**: `popupProperties` (no `.copy`)
- **holder**: `closeOnTapOverlay: false`, no banner, title + dynamic subtitle, `primaryAction` only, `secondaryAction: nil`, `dismissOnAction: true`
- **text**: title `lc_label_hello_there` = "Hello there!"; subtitle (ternary) `lc_label_uiux_announcer_description_variant` = "Let's explore Geniebook!" **or** `label_welcome_description` = "Get started with our AI-generated worksheets..."; primary `lc_label_im_ready`.capitalizingFirstLetter() = "I'm ready"
- **banner/image**: none
- **dynamic**: `isEligibleForJcUiVariant` selects which subtitle string is shown
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/MainTab/V1MainTabViewController+PopupCampaign.swift:262`
- **repeats**: `:477` (same shape, gated by 30-Nov-2023 date cutoff, "UI/UX announcer" variant)

### 18. `onboarding-trial-banner`
- **category**: Campaign/Onboarding (trial/subscription ended)
- **preset**: `popupProperties.copy(padding: custom, bannerRatio: 320/229 or 320/230, bannerMaxHeight: 216, bannerFixedHeight: 184)`
- **holder**: `closeOnTapOverlay: false`, banner conditional, title + subtitle (static), `primaryAction` + `secondaryAction`, `dismissOnAction: true`
- **text**: title `title_trial_ended` = "Free trial has ended"; subtitle `subscribe_to_continue` = "Subscribe to continue learning with Geniebook"; primary `view_pricing_plans`.capitalizingFirstLetter() = "View pricing plans"; secondary `action_dismiss`.capitalizingFirstLetter() = "Dismiss"
- **banner/image**: `isEligibleForJcUiVariant ? nil : UIImage(named: "img_illust_free_trial_ended")` **[conditional]**
- **dynamic**: `isEligibleForJcUiVariant`
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/MainTab/V1MainTabViewController+PopupCampaign.swift:327`
- **repeats**: `:401` — subscription-ended variant, title `lc_your_subscription_has_ended_1` = "Subscription has ended", subtitle `lc_resubscribe_to_continue`, primary `label_action_got_it` = "Got it", secondary `view_pricing_plans`, banner `img_illust_end_trial`

### 19. `credit-deduction-popup`
- **category**: GenieClass (live-class credit confirmation)
- **preset**: `popupProperties.copy(titleFont: OpenSans.extraBold 24)` — no banner override
- **holder**: `closeOnTapOverlay: false`, no banner, title + dynamic-format subtitle, `primaryAction` + `secondaryAction`
- **text**: title `lc_credit_use_title` = "Confirm Credit Use"; subtitle `lc_gclass_credit_use_description` format = "Joining this class will use 1 %1$@ lesson credit.\n\n%1$@ lesson credits left: %2$d"; primary `lc_gclass_credit_use_cta` = "Join class"; secondary `action_not_now` = "Not now"
- **banner/image**: none
- **dynamic [API]**: `upcomingViewModel.subjectName` (nil → "This subject"), `credit` (Int)
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/V3GenieClass/V3GenieClassDashboardViewController.swift:2076`

### 20. `ai-notes-ready-banner`
- **category**: GenieClass/AiNotes
- **preset**: `popupProperties.copy(bannerRatio: 960/681, bannerMaxHeight: 320, bannerFixedHeight: 256)`
- **holder**: `closeOnTapOverlay: false`, banner conditional, `title: nil`, dynamic-format subtitle, `primaryAction` + `secondaryAction`, `dismissOnAction: true`
- **text**: subtitle `lc_ai_notes_banner_title` format = "Your Personalised Summary Notes for %@ is ready!"; primary `lc_ai_notes_banner_cta_positive`.capitalizingFirstLetter() = "Bring me there!"; secondary `lc_ai_notes_banner_cta_negative`.capitalizingFirstLetter() = "Later"
- **banner/image**: `isEligibleForJcUiVariant ? nil : UIImage(named: "img_illust_ai_notes_banner")` **[conditional]**
- **dynamic [API]**: `topicName`, `isEligibleForJcUiVariant`
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/V3GenieClass/V3GenieClassDashboardViewController+AiNotes.swift:245`

### 21. `exit-worksheet-confirm-banner`
- **category**: Worksheet/WorkingSpace
- **preset**: `properties.copy(padding: custom, bannerRatio: 365/206, bannerMaxHeight: 144, bannerFixedHeight: 144, space: custom)`
- **holder**: `closeOnTapOverlay: true`, banner conditional, title + dynamic-format subtitle, `primaryAction: "label_exit_worksheet_dialog_cancel"` (stay), `secondaryAction: "label_exit_worksheet_dialog_confirm"` (leave — note the button-label/action mapping is inverted from what the names suggest)
- **text**: title `label_exit_worksheet_dialog_title` = "Hang in there!"; subtitle `label_exit_worksheet_dialog_body` format = "Don't give up, you still have %d questions remaining. You can do it!"; primary `label_exit_worksheet_dialog_cancel` = "Keep going!"; secondary `label_exit_worksheet_dialog_confirm` = "I'll be back!"
- **banner/image**: `isEligibleForJcUiVariant ? nil : UIImage(named: "ic_exit_worksheet")` **[conditional]**
- **dynamic [API]**: `unAnsweredRemaining` (count), `isEligibleForJcUiVariant`
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/WorkingSpace/V1WorkingSpaceViewController.swift:2433`

### 22. `worksheet-ready-timer-banner`
- **category**: Worksheet/WorkingSpace (pre-start timer)
- **preset**: `properties.copy(padding: custom all-32, bannerRatio: 193/170, bannerMaxHeight/FixedHeight: 170, titleFont: OpenSans.bold 24, titleColor: GBPNavy, subtitleFont: OpenSans.regular 16, subtitleColor: labelSubtitle, space: custom)`
- **holder**: `closeOnTapOverlay: false`, banner conditional, title + `subtitleAttributed` (rendered via `noteParser`), `primaryAction` only
- **text**: title `lc_are_you_ready` = "Are you ready?"; subtitle is a rendered/markdown string combining a template (branches on exam vs default worksheet type) with remaining time, plus an optional nudge; primary `action_proceed` = "Proceed"
- **banner/image**: `isEligibleForJcUiVariant ? nil : UIImage(named: "img_timer_alert")` **[conditional]**
- **dynamic [API]**: `worksheet.worksheetTypeEnum`, `calculateRemainingTime(interval)`, `viewModel.isEligibleToShowTimedWorksheetNudge`, `isEligibleForJcUiVariant`
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/WorkingSpace/V1WorkingSpaceViewController.swift:2668`

### 23. `worksheet-timeup-timer-banner`
- **category**: Worksheet/WorkingSpace (timer expired)
- **preset**: same family as #22 — `properties.copy(padding: custom all-32, bannerRatio: 193/170, ..., titleFont/titleColor/subtitleFont/subtitleColor matching)`
- **holder**: `closeOnTapOverlay: false`, banner conditional, title + `subtitleAttributed`, `primaryAction` + `secondaryAction`
- **text**: title `lc_time_up` = "Time's up!"; subtitle (rendered, literal English, not `.localized`) "Tap \"Continue\"... or submit for marking..."; primary `action_continue` = "Continue"; secondary `lc_label_submit_for_marking` = "Submit for marking"
- **banner/image**: `isEligibleForJcUiVariant ? nil : UIImage(named: "img_timer_alert")` **[conditional]**
- **dynamic**: `isEligibleForJcUiVariant`
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/WorkingSpace/V1WorkingSpaceViewController.swift:2719`

### 24. `badge-unlock-single`
- **category**: Campaign/Badges
- **preset**: convenience init `badges:` (1-badge branch) → private `badgeProperties = properties.copy(padding: custom, bannerRatio: 1, bannerMaxHeight/FixedHeight: 144, titleFont: DMSans.bold 24, titleColor: GBPNavy, subtitleFont: DMSans.regular 16, subtitleColor: labelSubtitle, space: custom(banner:16, title:12, subtitle:24, interButton:8))`
- **holder**: `closeOnTapOverlay: false`, banner set, title + `subtitleAttributed` (badge name rendered bold inline), `primaryAction` + `secondaryAction`
- **text**: title `dialog_title_congratulations`.capitalizingFirstLetter() = "Congratulations!"; subtitle template `dialog_message_unlock_new_badge` = "you unlocked the %@ badge!" (badge name substituted, bold); primary `action_view_my_badges`.capitalizingFirstLetter() = "View my badges"; secondary `action_dismiss` = "Dismiss"
- **banner/image**: `UIImage(named: badge.localImageName)` **[DYNAMIC/API — per-badge asset, not copyable; stub with `[API]` placeholder art]**
- **dynamic [API]**: `badge.name`, `badge.localImageName`
- **source**: `Geniebook/PresentationLayer/UIKit/Component/Dialog/BadgesPopUpView.swift:37`, invoked at `V1MainTabViewController+PopupCampaign.swift:696`

### 25. `badge-unlock-multi`
- **category**: Campaign/Badges
- **preset**: same convenience init, multi-badge branch → `badgeProperties.copy(bannerMaxHeight: 216, bannerFixedHeight: 216)`
- **holder**: `closeOnTapOverlay: false`, banner set (static), title + static subtitle, `primaryAction` + `secondaryAction`
- **text**: title same as #24 "Congratulations!"; subtitle `dialog_message_unlocked_new_badges` = "You unlocked new badges."; primary/secondary same as #24
- **banner/image**: `img_badge_multi_achievement` (static, unconditional)
- **dynamic**: none (badge count only gates which branch runs)
- **source**: `Geniebook/PresentationLayer/UIKit/Component/Dialog/BadgesPopUpView.swift:79-91`, invoked at `V1MainTabViewController+PopupCampaign.swift:696`

### 26. `badge-detail-popup`
- **category**: Progress/Badges
- **preset**: `properties.copy(padding: custom(20/36,20/48,20/36,20/48), space: custom(banner:0, title:0, subtitle:24, interButton:0))`
- **holder**: `subtitleCustomView`: a `VBadgesItemView` built at runtime from the tapped badge, `primaryAction` only ("Got it")
- **text**: primary `label_action_got_it` = "Got it"
- **banner/image**: none (uses `subtitleCustomView` instead of `banner`)
- **dynamic [API]**: entire `subtitleCustomView` is built from the selected `Domain.VBadgesEntity` (badge artwork + text) — stub with `[API]` placeholder view in the demo
- **source**: `Geniebook/PresentationLayer/UIKit/Controller/Badges/VBadgeListViewController.swift:457`

---

## Cross-cutting notes / unknowns

- `isEligibleForJcUiVariant` (from `(UIApplication.shared.delegate as? ProvideObjectResolver)?.objectResolver?.isEligibleForJcUiVariant`) is the single most common conditional gate — it hides the banner (shows `nil`) on 10 of the 13 banner-bearing shapes when the flag is true. Any demo of a "banner" shape should include a toggle for this.
- Several `V1*` / `V2LiveKit*` GenieClass controllers are parallel, largely copy-pasted implementations of the same flows (worksheet-abuse, help-redirect, welcome/consent, leave-confirm, mic-permission, volunteer, unmute, room-token-failure) — all fold into shapes #2, #6, #9, #10 above; no unique shape lost by the fold.
- A non-trivial number of literal (non-localized) English strings exist directly in Swift call sites (shapes #6, #15, #16, #22/#23, #7 DevSettings, #2's "Uh-oh" and "Oops" variants) — copied verbatim above since there is no localization key to resolve.
- All keys queried against `Geniebook/Supporting Files/en.lproj/Localizable.strings` resolved successfully — **no NOT FOUND keys**.
- All 12 static banner asset names resolved to an `.imageset` in `Geniebook/Assets.xcassets` — **no missing assets**.
- Two banner sources are **not static assets** and cannot be copied: `badge.localImageName` (per-badge, shape #24) and the entire `subtitleCustomView` in shape #26 — both should be stubbed with `[API]` placeholders in the demo gallery.
- `BaseError.swift:18`/`:34` construct the alert with blank placeholder holder fields (`title: ""`, `subtitle: ""`, etc.) and immediately reconfigure it via `dialog.presentError(...)` (`V2AlertModel+Error.swift`) — this resolves to shape #7 (connection error) or shape #2/#9-style plain two-button/one-button shapes depending on the error branch; not a unique shape on its own.
