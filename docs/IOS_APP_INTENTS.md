# iOS Siri / App Intents

Implemented in `ios/Runner` (the Flutter app target), not the separate
`Amble/` SwiftUI scaffold. Available on iOS 16+. The ordinary app retains
its iOS 15 deployment target. No extension, App Group, SiriKit entitlement,
server, third-party native library, or Flutter package was added.
`AppIntents.framework` is weak-linked in Runner.

## Execution and storage

`AppDelegate` starts `AmbleFlutterHost`'s single, headless-capable engine.
It runs the real `main()` even when Siri launches the process without a
scene. `main()` initializes Hive, registers its generated adapters, opens
the existing boxes, seeds categories and creates the normal provider
container. The channel becomes ready only after that bootstrap. When a
scene connects, `SceneDelegate` attaches to the same engine; it never
creates a second Hive cache. The automatic Main storyboard launch was
removed, but the launch-screen storyboard stays.

This reuses Slack's **initialization discipline**, not Workmanager's
execution mechanism. Workmanager supplies its own background Flutter
context; App Intents does not. A separate intent extension would also
require shared-container storage and cross-process coordination. Neither
is needed for this app-target implementation. Existing Slack code is
unchanged. Unlike Slack's read-only subset, this engine runs the full
application bootstrap; cold-start latency must be measured on hardware.

The method channel serializes intent operations. All writes use the
existing repositories/notifiers. The UI sees the same objects and provider
refreshes. No repository, model, or NLP parser changes were made.

The iOS-only `IntentNotificationService` bootstrap adapter keeps the
existing scheduling implementation, but checks existing permission when
no foreground scene is active instead of attempting a permission prompt.
Foreground permission requests retain their existing behavior. The bridge
waits for tracked notification work before replying. Notification errors
do not undo saved data, matching the app's established contract.

Startup waits up to 15 seconds **before dispatch**. A request that times
out there is never dispatched later. Once dispatched, a 25-second reply
timeout reports an uncertain outcome and tells the person to check Amble;
it never retries a potentially committed write. OS termination can still
interrupt execution. This is not a new transactional storage layer.

## Actions and resolution

| Action | Behavior |
| --- | --- |
| Add Task | Passes free text and live categories to `parseQuickCapture`; calls `TaskList.createTask` with title, time, duration, category and recurrence. Non-confident input follows Quick Capture's unscheduled-note fallback. |
| Add Note | Constructs `Task.captured(title: ...)`, then uses the existing `TaskList.updateTask` save/upsert-and-refresh path. No parsing. |
| Add Zone | Uses `DateComponents` parameters with `kind: .time`. Requires valid hours/minutes and an end after the start. Midnight as the end means 24:00. Calls the form's `zonesOverlap` validator and existing `ZoneList.createZone`. |
| Read Day Summary | Fixed template: today's scheduled-task count and next task, or the first task if every start is past. Includes scheduled tasks of all statuses; excludes Inbox and external-calendar events. |
| Remove Task | Removes one selected occurrence through `TaskList.deleteTask`, preserving its existing recurrence-template promotion and notification cancellation. |

Remove searches today plus the next 13 **calendar** days. Exact
case-insensitive trimmed titles take priority. Without an exact match,
substring or all-token matching returns every candidate. Multiple exact
occurrences still require a choice. There is no edit-distance matching.

The native API is `ScheduledTaskEntity: AppEntity`,
`ScheduledTaskQuery: EntityStringQuery`, and
`@Parameter(... requestDisambiguationDialog: ..., query: ScheduledTaskQuery())`.
App Intents resolves the parameter and presents native disambiguation
before `perform()`. Each choice carries the stored UUID and displays its
date/time. No custom selection UI or first-match deletion is used. The
selected UUID/title/time is checked again immediately before deletion;
stale or out-of-window selections fail with a spoken error.

Zone semantics deliberately match the current form: a non-recurring zone
is dateless; overlap candidates are dateless zones plus today's dated
occurrences. The form does not currently validate a dateless new zone
against every other date's materialized occurrences. This existing
limitation is preserved, not silently fixed in the intent or repository.

## Device acceptance pass — still required

The current machine's Xcode 15.4 / iOS 17.5 SDK cannot compile the existing
`workmanager_apple 0.9.10` reference to `BGContinuedProcessingTask` (an iOS
26 API). Use an Xcode with the iOS 26 SDK to build the unchanged dependency.
The earlier history's suggestion that Xcode 16 alone suffices is too old.

After the toolchain is available, build/run **the real `lib/main.dart`**.
Use a release/profile build on a physical device for cold Siri launches;
a Flutter debug build's debugger/JIT lifecycle is not a cold-launch test.
Confirm the app opens normally and the five actions appear in Shortcuts.
Enable Siri and use these declared phrases (they have **not** yet been
tested via Siri):

1. “Add a task in Amble”; answer “Walk tomorrow at 9am for 30 minutes”.
2. “Add a note in Amble”; answer the same text and verify it stays a note.
3. “Add a zone in Amble”; supply a title and unambiguous start/end times.
   Try an adjacent window, an overlapping window, and an end before start.
4. “Read my day in Amble”; compare the spoken count/title/time with today.
5. “Remove a task in Amble”; say “walk” with “Walk the dog” and “Walk to
   store” scheduled in the window. Verify native choice, cancellation
   without deletion, and exactly one removal after choosing. Also test an
   exact title with a partial match present, and duplicate exact titles
   on different dates.

Repeat with the app foregrounded, backgrounded, and terminated. After a
cold Add Note, open the app and confirm the note appears without a second
engine or stale cache. Check notification-tap routing, denied notification
permission, scene reconnection and local time-zone/DST behavior. Actual
Siri recognition, metadata extraction and device runtime remain acceptance
gates; passing Dart tests and Swift type-checking do not establish them.

## API references checked for this implementation

- [Apple: app-target versus extension execution, scene-less background launch](https://developer.apple.com/videos/play/wwdc2022/10032/)
- [Apple: EntityStringQuery](https://developer.apple.com/documentation/appintents/entitystringquery)
- [Apple: AppEntity parameter query and disambiguation initializers](https://developer.apple.com/documentation/appintents/intentparameter-app-entity)
- [Apple: IntentParameterContext.requestDisambiguation](https://developer.apple.com/documentation/appintents/intentparametercontext/requestdisambiguation%28among%3Adialog%3A%29)
- [Flutter: long-lived engines can run Dart before showing UI](https://docs.flutter.dev/add-to-app/ios/add-flutter-screen)

The implementation targets the iOS 16 API surface and was type-checked
with Xcode 15.4's real App Intents headers. `openAppWhenRun = false` is the
backward-compatible spelling; current Apple documentation deprecates it
in favor of [`supportedModes`](https://developer.apple.com/documentation/appintents/appintent/supportedmodes).
That newer API is not present in the installed SDK. It is not necessary
to adopt the newer API to use native entity-parameter disambiguation.
