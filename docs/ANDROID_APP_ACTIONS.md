# Android assistant actions

Implemented with **App Actions**, not AppFunctions. Google documents
AppFunctions as Android 16+ with Gemini access still restricted to a
preview. The connected Moto g54 runs Android 15, so this pass uses the
App Actions route that opens Amble. This is not a background-only voice
integration and does not promise offline Google Assistant recognition.
All Amble parsing, matching, storage and summary generation stay on-device.

No Flutter package, native library, Gradle plugin or permission was added.
Five custom capabilities live in `res/xml/shortcuts.xml`, referenced by
MainActivity's `android.app.shortcuts` metadata. Query patterns live in
`res/values/assistant_queries.xml`. Custom intents require matching
**English (US)** device/Assistant language settings. Custom capabilities
preserve the complete free-text task input for the existing local parser;
there is no second date/time NLP parser.

## Execution and behavior

MainActivity uses one process-owned FlutterEngine. Normal launch and action
launch run the real main/bootstrap, including Hive initialization and
adapter/box setup. Recreated activities reuse the engine. The existing
serialized Dart channel is enabled on Android and calls the same
AppIntentService used by iOS. No repository, parser, Quick Capture or Slack
implementation was changed. This reuses the Hive bootstrap discipline, not
Workmanager's separate execution isolate. App Actions supplies an Activity;
no background service or extension is needed for this implementation.

The notification bootstrap adapter now covers both mobile platforms:
background work checks permission; foreground work retains normal requests.
Existing Android notification/exact-alarm permission screens can interrupt
a first save or launch notification refresh. Return to Amble after making
the permission choice. Permission denial does not undo persisted tasks.

Add Task and Add Note accept `text`; the former uses parseQuickCapture and
the existing confidence/fallback rules, while the latter captures the full
text without parsing. Add Zone accepts `title`, `start`, `end`, using
ISO local times (for example `09:00`, or `09:00:00`). Missing values open
native input fields. Ambiguous/malformed times fail explicitly; no guessed
AM/PM, seconds, or overnight ranges. End `00:00` means 24:00. The existing
zone overlap validator, day filter and create path are reused unchanged.
Read Day Summary displays the fixed template from real Tasks. Results also
request speech through an installed offline Android TTS voice, if available;
visual feedback remains when a matching offline voice is unavailable.

## Remove Task: Android-specific resolution

No documented App Actions equivalent of Siri's dynamic AppEntity parameter
picker was found. **This picker belongs to Amble**, not Google Assistant:
lookup returns exact-title matches first, then substring/all-token matches,
within today plus the next 13 calendar days. A native Android dialog shows
the title and date/time of each candidate. The user chooses a task to delete,
or cancels. Even a single match requires a tap because an exported Activity
alone does not establish authorization to delete. Nothing is deleted merely
by receiving a title. The shared handler rechecks UUID/title/time/window
before existing recurrence-safe TaskList deletion. No custom matching library.

Consumed Android intents are not replayed after activity recreation. Native
readiness and reply timeouts report failures rather than retrying uncertain
writes. A process kill may still interrupt work; this is not a transactional
retry system. OS destruction of the activity can hide a result after a save;
check the app before repeating a request whose outcome is unclear.

## Testing

Build: `flutter build apk --debug --no-pub`. The resulting APK is
`build/app/outputs/flutter-apk/app-debug.apk`.

For actual voice testing, use Google's Android Studio Assistant plugin to
create an App Actions preview under the testing Google account. The
registered app and account must meet Google's testing requirements; merely
sideloading an APK does not register its capabilities with Assistant.
Production discovery requires the Google Play App Actions process.
This repository still uses `com.example.amble`; production app identity
and Play setup remain separate release work.

Example phrases matching the declared patterns (**not voice-verified**):

- “Hey Google, use Amble to add a task walk tomorrow at 9am for 45 minutes.”
- “Hey Google, use Amble to add a note walk tomorrow at 9am.”
- “Hey Google, use Amble to add a zone reading from 9pm to 10pm.”
- “Hey Google, use Amble to read my day.”
- “Hey Google, use Amble to remove task walk.” Then choose in Amble.

Direct fulfillment tests bypass Assistant recognition and preview setup:

```sh
adb shell 'am start -W -n com.example.amble/.MainActivity -a com.example.amble.assistant.ADD_TASK --es text "Assistant probe walk tomorrow at 9am for 45 minutes"'
adb shell 'am start -W -n com.example.amble/.MainActivity -a com.example.amble.assistant.ADD_NOTE --es text "A note tomorrow at 9am"'
adb shell 'am start -W -n com.example.amble/.MainActivity -a com.example.amble.assistant.ADD_ZONE --es title "Reading" --es start "21:00" --es end "22:00"'
adb shell 'am start -W -n com.example.amble/.MainActivity -a com.example.amble.assistant.DAY_SUMMARY'
adb shell 'am start -W -n com.example.amble/.MainActivity -a com.example.amble.assistant.REMOVE_TASK --es text "Assistant probe walk"'
```

Add `-s <device-id>` after `adb` when more than one device is connected.
Test normal launch, a cold action launch, a warm action launch, missing
input, overlap, invalid time, multiple matches, cancellation, and persistence
after restarting. A cold launch requires stopping the existing process;
`am start -W` alone can simply deliver to a restored emulator activity.
Do not use `pm clear`, which would erase the app's data.

## Verification recorded 2026-09-09

- Android debug APK builds; installed successfully on Moto g54 (API 35)
  and the existing API 34 emulator. Physical-phone UI verification was
  blocked by its lock screen; no credentials or lock bypass were attempted.
- Emulator normal timeline renders. Direct action tests verified task
  creation, note capture preserving time-like text, valid zone creation,
  overlap rejection, reversed-time rejection and the real day summary.
- Two test tasks were offered for a fuzzy query. Cancellation retained both;
  choosing one removed only that task. The surviving choice remained after
  a cold process restart, proving persistence through the real Hive path.
  The captured note also remained visible, unscheduled, in Manage after restart.
- Native result dialogs were inspected. TTS code executes, but audible output
  and Google Assistant voice recognition/discovery were not verified.
- 26 shared intent tests pass, including two new Android channel/permission
  tests. Analyze reports only the two existing unused `modalTitle` warnings.
- Full suite reached 905 passes and 16 failures, then its known List-mode
  hang; stopped at 75 seconds. All 16 failing test names match the previously
  reproduced no-Siri-change baseline. No unrelated test failures were fixed.
- Clearly named `Assistant probe` fixtures remain only on the test emulator.

Follow-up: unlock the phone for a physical UI pass; configure Google's
Assistant preview and test the actual phrases. AppFunctions/Gemini remains
unimplemented and needs a separate choice when Android 16+/preview access
is available. No claim of Siri-equivalent hands-free disambiguation.

## Primary references checked

- [App Actions execution and preview testing](https://developer.android.com/develop/devices/assistant/overview)
- [Custom intents, supported types and en-US limit](https://developer.android.com/develop/devices/assistant/custom-intents)
- [shortcuts.xml capability schema](https://developer.android.com/develop/devices/assistant/action-schema)
- [AppFunctions requirements and restricted Gemini access](https://developer.android.com/ai/appfunctions)
