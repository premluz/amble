# Amble — Progress Log

Narrative record, in order. Different purpose from DECISIONS.md (what was chosen) and ERROR_LOG.md (what broke) — this is what actually happened, session by session, so the arc of the build is reconstructable later. Also doubles as raw material if Amble ends up as a portfolio case study.

One entry per session or milestone. Doesn't need to be long — a few lines is often enough.

Format:
```
## [YYYY-MM-DD] Session/milestone title
What happened, what shipped, what's still open, anything notable about how it went.
```

---

## [Pre-build] Planning phase
Scoped the product via a full teardown of Structured (needs/problems/retention/competitive map/recommendations). Decided to build a close-reference clone as a personal/portfolio tool: Flutter for one codebase across iOS + Android, local-only Hive persistence (no calendar sync, no auth, no cloud backend for MVP), export/import doubling as backup. Named the project **Amble**. Wrote the initial architecture (repository pattern, Riverpod, three-tier token system inherited from the Merlin/Astryx approach) and the constitution/scope/error-log/decisions doc set.

## [Dev environment] Setup complete
Flutter SDK, Xcode (15.4 — functional, upgrade to 16+ deferred as non-blocking), Android Studio + SDK, CocoaPods installed to unblock native iOS plugin linking (needed for `flutter_local_notifications`). Confirmed via `flutter doctor`, `flutter analyze`, and `flutter test` all clean, and a real build launching on physical iPhone.

## [Amble project] Initial scaffold
Created the Flutter project, installed core dependencies (Riverpod + generator, Hive, SVG/notifications/sharing/file-picker/path-provider, build_runner). Caught and corrected a scope mismatch early — an initial folder sketch referenced "Places/Saved/Notes" features that don't belong to Amble; SCOPE.md now explicitly names this to prevent recurrence.

## [Setup] CI + root config added
Added CLAUDE.md at repo root, docs/ set, and .github/workflows/flutter-ci.yml
(analyze + test + format check on push/PR). Caught a misnamed file
(pubspec.yaml sitting in .github/workflows/ instead of flutter-ci.yml)
before first commit — renamed, not a real duplicate.

## [Phase 0] Task model, Hive persistence, TaskRepository
Built `Task` (shared/models/) with all Constitution-mandated fields — client
UUID `id`, `status` enum (not bool), `completedAt` separate from
`scheduledAt`, `originalScheduledAt` preserved on reschedule, `schemaVersion`
— plus `TaskCategory`/`TaskStatus` as semantic enums (colors mapped via
tokens later, per DECISIONS.md). Added `TaskRepository` interface and
`HiveTaskRepository` in shared/repositories/; Hive wired into `main.dart`
(`initFlutter`, `registerAdapters`, opens the `tasks` box). No feature code
touches Hive directly. Resolved the hive_generator/riverpod_generator
`source_gen`/`analyzer` conflict by switching to `hive_ce`/`hive_ce_generator`
plus a one-version `analyzer` override — full detail in ERROR_LOG.md.
Repository layer covered by a small Hive-backed test suite. No UI, no
Riverpod providers, no Event model yet (flagged as a question rather than
guessed at) — all per this session's scope. This closes out the Phase 0
*code* work order, distinct from the earlier CI/docs "Setup" milestone.

## [Phase 1] Riverpod state layer over TaskRepository
Added `shared/providers/task_providers.dart` (new location, not yet named
in ARCHITECTURE.md's folder sketch — flagged as a deviation: it sits
alongside `shared/models/` and `shared/repositories/` since task CRUD state
isn't feature-specific yet). Three code-gen providers: `taskRepositoryProvider`
(wraps the already-open Hive box via `HiveTaskRepository`), `taskListProvider`
(a `Notifier<List<Task>>` exposing `createTask`/`updateTask`/`deleteTask`,
each writing through the repository then refreshing state), and
`taskByIdProvider(id)` (family, derived from `taskListProvider`). `createTask`
only ever calls `Task.create(...)` — never the base constructor — closing the
exact bypass risk named in the work order; audited the rest of the app for
stray `Task(...)` calls outside test fixtures and found none. Wired
`ProviderScope` into `main.dart`. Hit and fixed a real bug during testing:
both providers defaulted to `autoDispose`, so a notifier method awaiting a
Hive write could find its own `ref` disposed by the time the write resolved
(no listener was keeping the provider alive mid-test) — fixed with
`keepAlive: true` on both, which is also the correct semantics for
session-scoped app state. Full CRUD cycle (create→read, update→confirm
persisted, delete→confirm gone) and a reactive-propagation test (a listener
observes create/update/delete with no manual refresh call) both covered in
`test/shared/providers/task_providers_test.dart`. No screens, no widgets, no
Event model — per scope. Phase 1 exit criteria (CRUD through providers,
test-covered) met.

## [Phase 2] Design system foundation — tokens + AppButton/AppSheet
Built the three-tier token system in `core/tokens/`. Tier 1 primitives
(`color_primitives.dart`, `spacing_primitives.dart`, `radius_primitives.dart`,
`type_primitives.dart`, `motion_primitives.dart`) are plain Dart consts —
`dart:ui` only (`Color`, `FontWeight`), no `package:flutter` import. Motion
curves store raw bezier control-point tuples at Tier 1 rather than
`Curve`/`Cubic`, since those are Flutter framework types, not `dart:ui` — see
DECISIONS.md. Tier 2 is `AmbleTheme`, a `ThemeExtension` in
`semantic_theme.dart`, with `light`/`dark` instances covering
surface/text/border/accent/task-status colors, spacing, radii, a 5-step type
scale, and motion. Defined `TaskCategoryToken` (health/work/personal/admin)
as a fixed enum mapped through `AmbleTheme.categoryColors` — proposed starter
taxonomy, flagged for review, not derived from usage data; full color list in
DECISIONS.md. Tier 3 (`component_tokens.dart`) is scaffolded but
intentionally empty, per the work order. Built `AppButton` and `AppSheet` in
`core/widgets/` — both branch Cupertino/Material via `Theme.of(context).platform`
(not `dart:io.Platform`, which doesn't work on web and isn't mockable in
tests), both consume only `AmbleTheme`, zero hardcoded values. Added a
throwaway `test/core/widgets/design_system_scaffold_test.dart` — explicitly
marked as scaffolding in a header comment, not wired into `main.dart` or the
real app shell — proving tokens + both adaptive widgets compose end-to-end
under both Material and Cupertino platforms, including opening a sheet
through `AppSheet.show` rather than a raw platform call. Also fixed a stale
doc: ARCHITECTURE.md's "Known open item" still described the hive_generator
conflict as pending, though it was resolved and logged in ERROR_LOG.md two
sessions ago — corrected to point at that entry. No real screens, no capsule
timeline block, no new dependencies — all per scope.

## [Phase 3] Capsule timeline block — approved
Built the capsule-shaped task block (`features/timeline/task_capsule_block.dart`):
two columns — a narrow left rail (category icon badge + thin subtle-gray
connector sized by duration, badge/connector both fixed-radius, not
height-derived) and a right column on the surface background (secondary-color
time above bold primary-color title). Iterated through three visual-review
rounds on a real iOS Simulator debug build, since headless `flutter test`
goldens don't load real fonts and this is exactly the kind of layout bug that
stays invisible without a real render: (1) a 120-minute task ballooning the
whole block into a blob because radius was `height/2`, fixed to a flat Tier 2
radius token; (2) the reference-UI two-column restructure itself, replacing an
earlier full-width colored block; (3) badge sized up ~50% and the connector
thinned to a 2px neutral-gray hairline (new `borderWidthHairline` Tier 2
token, backed by the existing `SpacingPrimitives.space1`). Category OKLCH
values re-spaced for color-vision-deficiency-safe distinguishability (see
DECISIONS.md for the exact hues) — flagged for review, not derived from usage
data. Static seeded-data preview (`timeline_capsule_preview.dart` +
`timeline_capsule_preview_main.dart`) stays as a dev scaffold. Approved after
review; the existing `timeline_capsule_preview_test.dart` golden was
intentionally left un-regenerated through all three rounds (per instruction
to hold until final sign-off) and is now stale against the approved shape —
regenerating it is the first thing due next time that file is touched.

## [Phase 3] Timeline day view — hour markers, current time, day nav, live data
Built the full Timeline screen in `features/timeline/`: `TimelineScreen`
(hour markers + tasks positioned by `scheduledAt`/`durationMinutes` on a
shared pixels-per-minute scale, live current-time indicator, empty-day state,
horizontal swipe day navigation), backed by two new providers —
`selectedDateProvider` (screen-local day state, `goToPreviousDay`/
`goToNextDay`/`goToToday`) and `tasksForSelectedDayProvider` (derived from
Phase 1's `taskListProvider`, filtered/sorted for the selected day, fully
reactive). `TaskCapsuleBlock` reused unchanged per instruction — positioning
by time happens externally via `Positioned`, not inside the component.
`HourMarkers` uses `FractionalTranslation` to center each hour label exactly
on its row rather than an approximate padding offset. `CurrentTimeIndicator`
refreshes on a 1-minute `Timer.periodic` — simplest correct option for a
clock-driven element; flagging this as the refresh-strategy choice per the
work order. The day view auto-scrolls to roughly the current time on open
(`ScrollController.jumpTo` in a post-frame callback) rather than opening at
6am, since a "current-time indicator" that starts below the fold isn't
actually discoverable. `main.dart`'s Explore/Saved/Profile scaffold mismatch
(flagged repeatedly in earlier sessions) is still untouched and still not
wired to this screen — out of scope here; `TimelineScreen` exists as a
real, working widget with its own dev entry points
(`timeline_screen_main.dart` seeded, `timeline_screen_empty_main.dart` empty)
until nav wiring is explicitly requested. Caught and fixed one real bug via
simulator screenshot, not analyze/test: task blocks' badges weren't
vertically centered on their hour row (positioned by the badge's top edge,
not its center) — fixed by offsetting the `Positioned.top` by half the
badge height at the call site, confirmed against three screenshots
(populated day at various scroll positions, current-time indicator visible
mid-scroll, empty-day state). `dart format`/`flutter analyze` clean; the one
`flutter test` failure is the pre-existing stale capsule golden noted above,
unrelated to this session's changes — all other tests pass (14/14).

## [Phase 4] Task interactions — detail sheet, creation, completion, reschedule
Cleanup first: regenerated the stale `timeline_capsule_preview.png` golden
(deferred across 3 prior sessions), and replaced `main.dart`'s leftover
Explore/Saved/Profile scaffold with `Scaffold(body: TimelineScreen())` — the
app now launches directly into the real Timeline, no bottom nav yet (deferred
until Inbox/Settings exist, per DECISIONS.md). `widget_test.dart` updated to
wrap `AmbleApp` in a `ProviderScope` + isolated Hive box, since it now pumps
real provider-backed content instead of a static scaffold.

Then the four task interactions, all in `features/task_detail/` (new) and
`features/timeline/`: **detail sheet** (`TaskDetailForm` via `AppSheet`,
create/edit — title, scheduledAt via date+time pickers, durationMinutes
stepper, category chips, notes) opened by tapping a capsule block;
**creation** via a new `AppIconButton` (circular adaptive FAB-equivalent,
`core/widgets/` — no raw `FloatingActionButton`, per design principle 4)
bottom-right on the Timeline screen; **completion toggle** by tapping the
badge itself (separate gesture from opening the sheet), writing
`completedAt` + `status: completed` through a new `TaskList.toggleComplete`
provider method; **manual reschedule** via vertical drag on a task block,
snapping to 5-minute increments, writing through a new
`TaskList.rescheduleTask` method that sets `originalScheduledAt` only on
first reschedule (per the Constitution) and moves `status` to `rescheduled`.
All writes go through `taskListProvider` — no feature UI touches the
repository or Hive directly. Status visuals avoid shame-coding (design
principle 1): `completed` uses the previously-unused `colorTaskCompleted`
token (not the category color) plus a checkmark badge and dimmed/strikethrough
title; `skipped` uses `colorTaskSkipped` (a real token now, not an
alpha-blended category tint); `rescheduled` gets no color change at all, just
a small neutral "moved" icon — full reasoning in DECISIONS.md.

Caught and fixed one real bug while trying to screenshot the new detail
sheet: `AppSheet`'s Cupertino branch (`showCupertinoModalPopup`) had no
`Material` ancestor, so any Material-family sheet content (the detail form's
`TextField`s) crashed with "No Material widget found" — invisible until now
because `AppSheet`'s only existing test used a bare `Text`, Material platform
only. Fixed in `AppSheet` itself (wrapped Cupertino-branch content in
`Material(type: MaterialType.transparency)`), and closed the test gap that
let it through: `design_system_scaffold_test.dart`'s sheet-content probe is
now a real `TextField`, run on both Material and Cupertino.

No tap-injection tool is available in this environment for the iOS
Simulator (no `idb`/`cliclick`), so interactive gestures (tap-to-open,
drag-to-reschedule) couldn't be driven live for the required screenshots.
Worked around this with dedicated dev-scaffold entry points:
`timeline_screen_detail_sheet_main.dart` opens the sheet via code
(`showTaskDetailSheet` in a post-frame callback) against a real seeded task,
and `timeline_screen_main.dart` was extended with a sixth seed task in
`rescheduled` status (with `originalScheduledAt` set) to show the
post-reschedule visual state directly, since a live mid-drag frame wasn't
capturable. `dart format`/`flutter analyze` clean; `flutter test` — all
16/16 passing, golden regenerated and green. No Inbox, no notifications, no
cascade/auto-reflow — all per scope.

## [Phase 4, amendments] Task detail screen — full visual redesign
A same-day follow-up session, driven by direct reference-image feedback and
live on-device interaction, that replaced the Phase 4 form's look entirely
without touching its data flow (still one `TaskDetailForm` for create/edit,
still writes only through `taskListProvider`). Landed in many small,
independently-verified rounds — noted together here since they compound
into one coherent redesign, not several unrelated features.

**Presentation**: `showTaskDetailSheet` no longer uses `AppSheet`'s partial-
height bottom sheet — it now pushes a near-full-screen `PageRouteBuilder`
(slide-up transition). The colored, edge-to-edge header with an inline-
editable title doesn't fit `AppSheet`'s fixed-white-background contract, and
other simpler sheets should keep using `AppSheet` as-is. The whole card
(header + white content) sits inset from all four screen edges with a
matching `radiusSheet` corner radius throughout, including the header's own
bottom corners — `radiusSheet` itself was bumped to a new `RadiusPrimitives.
radius6` (32) token, one step past the previous max (`radius5`/24).

**Header**: the category icon badge was removed entirely (title now has the
full header width). The close (×) button moved from the top of the layout
flow (previously pushing the title down) to an absolutely-positioned overlay
in the top-right corner, so it never affects title layout — the title
`Column` reserves matching right-padding so the two never overlap.

**Category picker**: rebuilt from icon+label pill chips (Phase 4 original)
to a horizontally-scrollable row (`ListView.separated`) of circle-icon tags
— a subtle-alpha category-color circle with a stronger-color icon inside,
label beside it, no filled background — per a supplied reference image. The
category OKLCH palette itself was also muted one step (L 0.70→0.62, C
0.13→0.10, hues unchanged) since the original read too saturated once used
this prominently; the capsule-preview golden was regenerated to match.

**New adaptive components**: `AppSlider` (`core/widgets/`) — custom-painted
rather than wrapping `Slider`/`CupertinoSlider` directly, since the required
look (thick full-width track, thumb matching the active-track color, no
division tick marks) isn't achievable with either platform widget's
defaults (`CupertinoSlider`'s thumb color is fixed by the OS; both reserve
edge padding for the thumb). Replaced the duration stepper. `AppButton`
gained two new orthogonal variants — `AppButtonSize.large` and
`AppButtonShape.pill` — rather than hardcoding a one-off large/pill button
inline, since other screens may want either independently.

**Time picker**: replaced the two-tap `showTimePicker` with a custom
in-panel wheel scroller (`_TimeScroller`, `ListWheelScrollView`), 15-minute
steps, selected value shown as a large colored pill matching the reference.

**Continue button**: made sticky (floats via `Stack`/`Positioned`, content
scrolls underneath) and fully pill-shaped, with a drop shadow for visual
separation from content behind it. Getting a reliably-visible gap between
the button and the last form field (Notes) for short-content cases (where
the form doesn't need to scroll) took three iterations — measured height,
then two escalating static reserves — without fully closing the gap to
zero; the shadow was the pragmatic stopping point per direct instruction
rather than continuing to chase exact pixel spacing on a genuinely fiddly
edge case.

Every round in this session was verified with `dart format`/`flutter
analyze`/`flutter test` (clean throughout, 16/16) and a real on-device
screenshot before moving to the next change — no visual change was declared
done from source reading alone.

## [Phase 5] Inbox — capture and move-to-timeline
Built the Inbox: capture for unscheduled tasks/thoughts, and the flow to
move a captured item onto the Timeline. `Task.scheduledAt`/`durationMinutes`
were required and non-nullable, so there was no way to represent
"captured, not yet scheduled" — made both nullable, added a derived
`isScheduled` getter, and a new `Task.captured({title, notes})` factory
(title-only, per design principle 2). Confirmed the approach with the user
first (nullable fields vs. alternatives) rather than guessing, then
propagated the change through every call site that read those fields
(`TaskCapsuleBlock`, `TimelineScreen`'s positioning/drag math,
`tasksForSelectedDayProvider`'s day filter) — all null-safe now, full
project `flutter analyze`/`flutter test` clean throughout.

Built `features/inbox/`: `InboxScreen` (list of unscheduled tasks, reusing
the same capsule-adjacent visual language as the Timeline — category badge,
title, chevron — over `AppSheet`'s surface tokens), `inboxTasksProvider`
(derived from `taskListProvider`, filtered to `!isScheduled`), and
`showQuickCaptureSheet` — an `AppSheet`-based, title-only entry point
(auto-focused text field + Add button) that's meaningfully faster than the
full task detail screen, per design principle 2. Move-to-timeline needed no
new UI: `TaskDetailForm`'s existing edit path already assigns real values
to previously-null `scheduledAt`/`durationMinutes` and saves via the normal
`updateTask` call, so tapping an Inbox item just opens `showTaskDetailSheet`
as-is. Added `TaskList.scheduleTask(...)` to the provider as a named entry
point for future non-UI callers, though the sheet itself doesn't need it.

Wired bottom navigation (`AmbleHome` in `main.dart`) — Inbox and Timeline
tabs via a Material `NavigationBar` over an `IndexedStack`, defaulting to
Timeline on launch. Settings stays deferred (Phase 8, no content yet),
consistent with Phase 4's original reasoning for not building nav chrome
ahead of real screens.

Verified via `dart format`/`flutter analyze`/`flutter test` (clean, 16/16)
and real on-device screenshots for all three required flows: Inbox with
seeded items, quick-capture sheet mid-entry (focused, cursor visible), and
the move-to-timeline flow (a captured item opening pre-filled in the
existing detail screen). Also spot-checked the real `main.dart` app
(bottom nav rendering, Timeline tab selected by default) beyond the
required three, since it was a structural change to the app shell.

## [Phase 6] Exit-confirmation modal on the task detail form's close button
Added the "worth asking" guard to the × button: previously it discarded
unconditionally, now it prompts "Schedule this?" (primary action, same save
path as Continue/Add) vs. a destructive secondary action — "Delete draft"
on create, "Discard changes" on edit (confirmed the label/semantics split
with the user; edit-flow discard is a plain `Navigator.pop()`, never a
delete, since there's already a saved version to fall back to). Threshold:
non-empty title *and* at least one field (title included) changed from
where the form started — flagged and landed per the work order's request,
full reasoning in `docs/DECISIONS.md`. Added `AppAlertDialog`
(`core/widgets/`), the project's first two-choice confirmation dialog,
Cupertino/Material adaptive per design principle 4.

Caught a real bug via a new widget test (`test/features/task_detail/
exit_confirmation_test.dart`, 8 cases) before trusting a screenshot: an
earlier version of the "worth asking" check only diffed non-title fields,
so typing a title alone (the most common real case — Quick Capture → detail
form → close) never triggered the prompt. Fixed before calling the feature
done.

Writing that test also surfaced a genuine environment gotcha, not a
feature bug: `flutter test` hangs indefinitely when a tapped widget
triggers real Hive disk I/O, because `pumpAndSettle()` only waits on
frames, not the real event loop Hive's writes complete on. Root-caused via
isolated bisection (confirmed independent of two compounding false leads —
stray `kill -9`'d processes leaving stale Hive `.lock` files, and an
initial Navigator-depth issue in the test's own harness) down to needing
`WidgetTester.runAsync` plus an explicit zero-delay drain before the test
returns. Full writeup in `docs/ERROR_LOG.md` — this is the project's first
`testWidgets` test that also performs real Hive writes, so the gotcha was
previously latent. This is also what resolved an ambiguous on-device
screenshot of the "Discard changes" outcome (an empty Inbox that could have
meant either "discard worked" or "discard deleted the task") — the widget
test's explicit assertion proved the task was untouched, and the on-device
scaffolds were then updated to seed a second Inbox item so the screenshots
became unambiguous too.

Verified via `dart format`/`flutter analyze`/`flutter test` (clean, 24/24 —
16 pre-existing + 8 new) and real on-device screenshots for the modal
appearing, the "Schedule this" outcome, and the "Discard changes" outcome
(all three against the two-item Inbox seed for visual clarity).

## [Phase 7] Local notifications — task-start alerts, iOS + Android
Wired `flutter_local_notifications` end to end: a task created or scheduled
with a future `scheduledAt` now schedules a real OS-level notification at
that time; deleting, rescheduling, editing, or marking a task
complete/pending correctly cancels and (if still appropriate) re-schedules
it via one idempotent `NotificationService.syncForTask`, called from every
`TaskList` mutator right after the repository write — never from UI code,
per the work order. Two new dependencies added and confirmed with the user
first: `timezone` (required by `zonedSchedule`, the only scheduling API
that survives device timezone/DST changes) and `flutter_timezone`
(`timezone` alone can't detect the device's actual IANA timezone name;
this is `flutter_local_notifications`' own documented companion for that
gap). Full reasoning for both, plus every other judgment call this session
(permission timing, notification-id derivation, tap-to-open scope,
platform config), is in `docs/DECISIONS.md`.

Permission is requested lazily on the first task create/schedule, not at
app launch (`DarwinInitializationSettings` has all `request*Permission`
flags off) — denial degrades silently, every other write path proceeds
normally. Tap-to-open was in scope as "if reasonable this session" and
turned out to be: a new `notificationTapProvider`, populated from both
`onDidReceiveNotificationResponse` (foreground/background tap) and
`getNotificationAppLaunchDetails()` (cold start), consumed once by
`AmbleHome` to switch to the Timeline tab and jump to the tapped task's
day via the existing `selectedDateProvider`.

Platform config: Android manifest gained the two `flutter_local_notifications`
receivers (scheduled-alarm delivery + boot-persistence) plus
`RECEIVE_BOOT_COMPLETED`/`SCHEDULE_EXACT_ALARM`/`POST_NOTIFICATIONS`
permissions, all copied from the plugin's own README rather than guessed.
iOS `AppDelegate.swift` gained the documented
`setPluginRegistrantCallback` wiring. Notification icon reuses the
existing `@mipmap/ic_launcher` rather than adding a dedicated drawable —
flagged as a candidate to revisit, not a gap that blocks anything now.

Real on-device verification, iOS Simulator (a physical device wasn't
available this session — flagging per the work order's explicit ask):
built a dev-scaffold (`lib/shared/services/notification_verification_main.dart`)
that boots the real app and schedules a real task 90 seconds out via a
manual on-screen button, since no tap-injection tool exists in this
environment — the user tapped it live. First attempt looked like a
failure (backgrounded the app via `simctl terminate`, no banner visible in
two follow-up screenshots); turned out to be a false negative from killing
the process plus screenshot timing against a transient banner, not a real
bug — confirmed by directly inspecting the simulator's
`DeliveredNotifications.plist`, which showed the notification *had*
fired, with the correct title ("Notification test"), body ("23:58"), and
payload (the task's UUID). A second attempt, backgrounding via
`simctl launch` on a different app instead of terminating, delivered
visibly and reproducibly. Full writeup of both the delivery-timing gotcha
and the `flutter test` + real Hive I/O gotcha (unrelated, hit earlier
setting up test coverage for this same session) in `docs/ERROR_LOG.md`.

Test coverage: `test/shared/services/notification_service_test.dart` (2
cases — the pure-logic early-return guards: unscheduled task, past
scheduled time — reachable without a live platform channel) plus a
`FakeNotificationService` test double (`test/support/`) wired into the
existing `task_providers_test.dart`/`exit_confirmation_test.dart` overrides
so those suites don't touch the real plugin. Android on-device delivery
was not verified this session at all (iOS Simulator only) — flagging as
the one piece of the work order's "expect real platform-specific work" ask
not yet exercised live. A `flutter build apk --debug` static
build-correctness check was attempted but not completed: this machine had
never built for Android with these new native plugins before, so Gradle
started a large one-time Android NDK download (`android-ndk-r28c-darwin.zip`)
that was still in progress after ~8 minutes and was cancelled rather than
left blocking the session — not a build failure, just an uncompleted
first-time environment cost. Both the Android build-correctness check and
real on-device Android notification firing are open for a follow-up
session (the NDK download should be cached after the first successful
run).

Verified via `dart format`/`flutter analyze`/`flutter test` (clean, 26/26
— 24 previous + 2 new).

## [Phase 6 closure] Android notification delivery verified — the gap flagged above is resolved
Closes out the "Android on-device delivery was not verified this session"
item from the Phase 6 entry above. Let the NDK download run to completion
this time per direct instruction (no early cancellation) — it wasn't just
slow, it uncovered two real, previously-latent problems, both fixed:

1. **Real build bug, not a config gap**: `flutter build apk` failed outright
   with `flutter_local_notifications requires core library desugaring to be
   enabled for :app` — this project's `minSdk` (24) is below the API level
   (26) where `java.time` is natively available, and Android had never
   actually been built with the notifications plugin present until this
   session, so the failure was real but previously unexercised. Fixed in
   `android/app/build.gradle.kts` per the plugin's own documented recipe
   (`isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.4`).
2. **Corrupted NDK from the prior session's cancelled download**: the
   fixed build then failed a *second* time with a CMake "C compiler
   identification is unknown" error that read like an architecture
   mismatch but was actually a truncated `clang-19` binary — a broken
   symlink pointing at a file that had never fully downloaded/extracted
   when that download was cancelled last session. `rm -rf` on the NDK
   directory and a clean re-download (run explicitly, piped through `yes`,
   after discovering a backgrounded `flutter build`'s implicit auto-install
   can silently stall forever with no TTY attached) fixed it for good.
   Both are real environment gotchas, not code bugs — full write-ups in
   `docs/ERROR_LOG.md` (three new entries).

With the build actually succeeding, set up a local Android emulator (no
physical device available) — `Amble_Test_API34`, API 34/Android 14,
`google_apis/arm64-v8a` via `avdmanager`, specifically chosen to be past
API 33 where `POST_NOTIFICATIONS` became a runtime-requested permission.
Ran the same `notification_verification_main.dart` scaffold from the iOS
session; unlike iOS Simulator, `adb` gave direct scriptable control and
evidence — `adb shell input tap` to drive the UI (no live human tap needed
this time), a real `POST_NOTIFICATIONS` permission dialog appeared and was
granted, and two real notifications ("Notification test", 06:12 and 06:13)
were confirmed delivered via `adb shell dumpsys notification --noredact`
(correct `channel=task_alerts`, title, body, `mImportance=HIGH`) and
visually in the notification shade via screenshot. `adb shell dumpsys
alarm` additionally confirmed `SCHEDULE_EXACT_ALARM` is being honored
correctly — `com.example.amble`'s `ScheduledNotificationReceiver` shows as
a real `*walarm*` (wakeup alarm), not a coalesced/inexact one.

No code changes were needed beyond the Gradle desugaring fix above — the
Dart-side scheduling/permission/tap-to-open logic from Phase 6 worked
correctly on Android as soon as the build itself succeeded.

Verified via `dart format`/`flutter analyze`/`flutter test` (clean, 26/26,
unchanged from before this session — this was a verification/closure
session, no notification logic changed).

## [Phase 7] Export / import — JSON backup via share sheet + file picker
Full round-trip backup story: export serializes the whole `Task` dataset
(including completed/historical, not just current/future — per SCOPE.md's
"export doubles as backup") to a JSON file via `share_plus`'s native share
sheet; import picks a `.json` file via `file_picker`, validates it, and
merges it into local storage without ever overwriting existing data.

`Task` gained hand-written `toJson()`/`Task.fromJson()` (no
`json_serializable` — flagged and justified in `docs/DECISIONS.md`) plus a
`hasSameFieldsAs()` field-by-field comparison used for import dedup.
`Task.fromJson` validates every field explicitly — missing/wrong-typed
fields, unrecognized `TaskCategory`/`TaskStatus` enum values, and malformed
date strings all throw a `FormatException` rather than constructing a
partially-wrong task; caught a real bug here via the new
`test/shared/models/task_json_test.dart` suite — `EnumByName.byName` throws
`ArgumentError`, not `FormatException`, for an unrecognized name, so the
first version of the unrecognized-category/status tests failed until the
enum lookup was rewritten to validate explicitly first.

New `BackupService` (`shared/services/`) owns the file I/O and
share-sheet/file-picker calls; a new `TaskList.importTasks(List<Task>)`
(provider layer) does the actual merge, going through the same
`TaskRepository.saveTask` every other write uses — no special-cased bulk
path around normal validation. Three real design decisions this session
asked to be flagged rather than guessed, all confirmed with the user and
written up in `docs/DECISIONS.md`: **conflict handling** (same id,
different fields → skip and count as a conflict, never auto-overwrite —
`ImportResult` reports imported/alreadyPresent/conflicts counts so the
user knows something needs manual attention, without building a full
merge-resolution UI this session), **import notification behavior**
(deliberately notification-agnostic — a bulk restore shouldn't trigger a
wave of scheduled notifications or the permission prompt as a side
effect), and **entry point** (a temporary third bottom-nav "Backup" tab,
placed after Timeline so the existing notification-tap-to-open index
didn't need to change — folds into Settings once Phase 8 builds it).

Real on-device round-trip verification, iOS Simulator (per the same
reasoning as Phase 6/7's notification sessions — no tap-injection tool
available, so dev-scaffold entry points drive the real code paths
programmatically via `debugAutoTriggerExport`/`debugAutoTriggerImport`
flags on `BackupScreen`, same pattern as the earlier
`debugAutoTriggerClose`):

- **Export**: seeded 3 real tasks (scheduled + completed + unscheduled/Inbox),
  triggered the real `_export()` handler, and screenshotted the actual iOS
  share sheet showing a real "JSON • 1 KB" file with a working "Save to
  Files" option. Pulled the exported file directly from the simulator's
  app container filesystem and confirmed its JSON content byte-for-byte
  correct (full dataset, all fields, `completed` status included).
- **Round-trip**: a second scaffold wiped local storage (`box.clear()`,
  simulating a fresh install), imported the exported file via the real
  `BackupService.parseImportFile` + `TaskList.importTasks` path, and the
  resulting `BackupScreen` showed "3 task(s) stored locally" — exactly
  matching the pre-wipe count. No data loss.
- **Merge/dedup, live**: a third scaffold imported the same file twice in a
  row without wiping in between — first import: 3 imported, 0 already
  present; second import: 0 imported, 3 already present, 0 conflicts;
  final count still 3, no duplicates. Confirms the "skip if identical"
  conflict-handling decision works correctly outside the unit-test level
  too.

Real caught-live gotcha during this verification, not a code bug: a
screenshot taken right after relaunching a new scaffold app looked stale
(showed the *previous* scaffold's share sheet and task count) — turned out
iOS's native share sheet is a system-level UI that outlives the app
process that opened it, so a plain `flutter run` relaunch doesn't dismiss
it. Full write-up in `docs/ERROR_LOG.md`; the fix (`simctl terminate`
before trusting a screenshot after any native-chrome-presenting API) is
now the standing pattern for verifying `share_plus`/`file_picker` flows.

The work order's requested "import file picker" screenshot specifically
was not captured — the native document picker itself needs a real tap,
which this environment cannot provide (no tap-injection tool, same
limitation noted in every prior on-device verification session). The
scaffolds instead call `BackupService.parseImportFile` directly against a
known file path, exercising every part of the real import code path
(parsing, schema validation, merge logic, persistence) except the picker
UI itself. Flagging this explicitly rather than presenting a screenshot of
something else as if it satisfied that specific ask — the picker UI
itself is `file_picker`'s own well-established native component, not new
code this session wrote.

Android on-device verification of export/import was not done this session
(iOS Simulator only) — flagging per the same "no new dependencies without
platform config verified" caution as Phase 6/7's notification work, though
`share_plus`/`file_picker`/`path_provider` are lower-risk here since they
needed no manifest/Gradle changes on iOS, unlike `flutter_local_notifications`.

Verified via `dart format`/`flutter analyze`/`flutter test` (clean, 46/46
— 26 previous + 20 new: `task_json_test.dart` (8 cases), `backup_service_test.dart`
(8 cases), plus 4 new `importTasks` cases in `task_providers_test.dart`).

## [Phase 8] Settings screen, absorbing the temporary Backup tab

Built `features/settings/settings_screen.dart` as the permanent home for
export/import and notification preferences, replacing Phase 7's temporary
third "Backup" bottom-nav tab. `main.dart`'s nav shell now shows
Inbox/Timeline/Settings — confirmed against SCOPE.md's own documented nav
structure that Settings is meant to be a persistent third tab, not reached
another way, so no UX call was actually open here.

Export/import logic itself is unchanged — `BackupService`,
`TaskList.importTasks`, and the `debugAutoTriggerExport`/
`debugAutoTriggerImport` dev-scaffold pattern were carried over verbatim
from `BackupScreen` into `SettingsScreen`; `lib/features/backup/` was
deleted and its three `*_main.dart` scaffolds recreated under
`features/settings/` with updated imports.

Added two new capabilities to `NotificationService`: `hasPermission()`
(exposes the existing private permission check for display) and
`openNotificationSettings()`, which calls
`flutter_local_notifications`' own `openAppNotificationSettings()` —
already present on the plugin across iOS/Android/macOS, confirmed by
reading the plugin's source directly, so no new dependency was needed for
the "let the user go grant permission in OS settings" requirement.

Added `package_info_plus` (10.2.1) as a new direct dependency, confirmed
with the user first, for runtime app-version display in the new "About"
section — the only new dependency this session.

`SettingsScreen`'s `initState` now calls `notificationServiceProvider`
synchronously on mount, which broke `widget_test.dart` (real
`flutter_local_notifications` plugin has no test-channel handler, same
class of issue documented earlier for `NotificationService`). Fixed by
adding `hasPermission()`/`openNotificationSettings()` overrides to the
existing `FakeNotificationService` test double and wiring it into
`widget_test.dart`'s `ProviderScope` overrides — not a new gotcha, same
known pattern hitting a new call site.

On-device verification (iOS Simulator, via three throwaway
`settings_*_main.dart` scaffolds since there's still no tap-injection tool
available — same limitation as every prior session): (1) baseline
Settings screen renders all three sections correctly (Notifications with
live permission status + "Open notification settings" button, Backup with
task count + export/import buttons, About with real app version); (2)
export from the new location still produces the real iOS share sheet with
a valid JSON backup; (3) import from the new location, run against a
freshly wiped task box and a real exported backup file, correctly
restored all 3 tasks and the screen's own task-count text reflected it.

Verified via `dart format`/`flutter analyze`/`flutter test` — all clean,
46/46 tests passing (no tests added or removed this session; existing
`widget_test.dart` and `fake_notification_service.dart` were extended).

## [Phase 9] Real-device verification + store-prep basics

No physical iPhone or Android device was connected this session (`flutter devices`/USB check both confirmed) — every "real device" item below ran on iOS Simulator and/or the Phase 6 `Amble_Test_API34` Android emulator instead, flagged per item rather than presented as hardware-equivalent.

**Android on-device verification, closed out (Inbox/capture, export/import, Settings — none of these had ever been run on Android before this session):** all three confirmed working via the existing dev-scaffold pattern on the emulator — Inbox list + FAB, quick-capture sheet, Settings screen (all three sections), real Android share-sheet export, and a full wipe+import round-trip restoring the correct task count. One genuine cross-platform gap found and fixed along the way: the import scaffold's "read a known file path directly" shortcut (works fine on iOS Simulator) hit Android's scoped-storage restriction when the file lived in `/sdcard/Download/` — fixed by pushing the file into the app's own private storage instead and pointing the scaffold at that path for the run, then reverting; full write-up in `docs/ERROR_LOG.md`. Also independently confirmed Android's native share sheet has the same "outlives its launching app" behavior already documented for iOS — a second `docs/ERROR_LOG.md` entry, since it wasn't previously verified as a cross-platform rule.

**Import file picker's native UI — still not manually tapped through, flagged rather than worked around**, per direct instruction (`docs/DECISIONS.md`): no tap-injection tool exists for either platform's system-level file picker, and the user chose to leave this open for a later session rather than do a manual pass now.

**Live, non-scaffold walkthrough on the Android emulator**, beyond what the existing dev-scaffolds alone prove: discovered `adb shell input tap`/`input text` genuinely works for driving the *app's own* UI (not the system file picker) once a device is booted, so ran a real create-task → complete-toggle flow directly against the freshly installed **release APK** (not a debug scaffold) — new task appeared correctly positioned on the Timeline with the current-time indicator, and tapping its badge correctly toggled it to the `colorTaskCompleted` sage state with a checkmark overlay, matching Phase 4's design exactly. Test data cleared afterward (`pm clear`).

**Store-prep:**
- `pubspec.yaml` description fixed (was the default "A new Flutter project").
- App display name fixed on both platforms: Android's `android:label` moved off a hardcoded lowercase `"amble"` onto a new `strings.xml` resource ("Amble"); iOS `CFBundleName` capitalized to match the already-correct `CFBundleDisplayName`.
- App icon + splash screen replaced on both platforms with an explicit, clearly-flagged placeholder — a small Python/Pillow script generated a simple sage-brand mark at every required iOS/Android resolution (no new Flutter dependency; a plain generated-PNG approach was enough, so `flutter_launcher_icons`/`flutter_native_splash` weren't needed). Uses the app's real `sage500`/`sand50` values (ported the existing OKLCH conversion to Python for exact colors). iOS `LaunchScreen.storyboard` background color updated to match; Android got a new `colors.xml` + `launch_image.png` drawable wired into both `launch_background.xml` variants.
- Bundle ID/package name (`com.example.amble`, both platforms) deliberately left unchanged — confirmed with the user first; it's a real, consequential decision (re-signing, and on Android a post-publish change is effectively a new listing) better made at actual submission time, not guessed now.
- Version (`1.0.0+1`) left as-is — no reason surfaced this session to bump it.

**Release builds, both platforms, confirmed for the first time this project:** `flutter build ios --release --no-codesign` succeeded (`Runner.app`, 18.0MB — codesigning deliberately skipped since no distribution certificate is part of this session's scope). `flutter build apk --release` succeeded (`app-release.apk`, 53.3MB) — installed and smoke-tested on the Android emulator directly (not just "builds," actually launched and ran correctly, including the new icon/name/splash and a real create→complete task flow).

**Not done this session, explicitly out of non-goals or blocked by missing hardware:** no TestFlight/Play Console submission; no dark mode (still separately open, untouched); no new dependencies beyond the store-prep script (which needed none); full "real hardware" walkthroughs for items 3–4 of the work order (blocked by no physical device being available — emulator/simulator walkthroughs substituted and flagged throughout).

Verified via `dart format .`/`flutter analyze`/`flutter test` — all clean, 46/46 tests passing (no test changes this session — this was a verification/polish session, not a feature session).

### Coverage table

| Feature | iOS (Simulator) | Android (Emulator) | Real hardware |
|---|---|---|---|
| Task create/edit/complete/reschedule | ✅ (prior sessions) | ✅ (this session, live via `adb input` on release APK) | ❌ not available |
| Inbox capture + move-to-timeline | ✅ (prior sessions) | ✅ (this session) | ❌ not available |
| Local notifications — delivery | ✅ (Phase 6/7) | ✅ (Phase 6 closure) | ❌ not available |
| Export (share sheet) | ✅ (Phase 7/8) | ✅ (this session) | ❌ not available |
| Import — parse/merge logic | ✅ (Phase 7/8) | ✅ (this session) | ❌ not available |
| Import — native file-picker UI (manual tap) | ❌ never verified | ❌ never verified | ❌ not available |
| Settings screen (all sections) | ✅ (Phase 8) | ✅ (this session) | ❌ not available |
| App icon / splash | ✅ placeholder, both platforms — not device-specific | ✅ placeholder, both platforms | n/a |
| Release build succeeds | ✅ `flutter build ios --release` | ✅ `flutter build apk --release` | n/a |
| Release build actually runs | not attempted (no distribution cert/device) | ✅ installed + smoke-tested on emulator | ❌ not available |

## [Post-Phase 9] Capsule block redesign — badge now stretches to show duration

User feedback (with a reference screenshot from Structured): task blocks weren't visually communicating duration — the badge was a small fixed circle with only a thin connector line indicating how long the task ran. Replaced `TaskCapsuleBlock`'s circle-badge-plus-hairline-connector with a single tall rounded pill (`radiusTaskPill`, previously defined but unused) that stretches to the task's actual duration, icon positioned near the top. Confirmed via AskUserQuestion that the connector should be fully replaced, not just thickened, before touching the signature component's code.

`TimelineScreen`'s positioning math updated to match: the pill's top edge now represents the scheduled start time directly, so the previous `-badgeSize/2` centering offset (needed when the badge was a small circle independent of the duration line) was removed entirely rather than adjusted.

Golden test (`timeline_capsule_preview_test.dart`) regenerated — an intentional visual change, not a regression, per the project's standing rule that stale goldens get regenerated when content changes on purpose. Verified via `dart format`/`flutter analyze`/`flutter test` (clean, 46/46) and a real on-device screenshot on iOS Simulator (`timeline_screen_main.dart`'s existing seed data, which already included a 120-minute "Deep work" task, so the redesign's headline case — a long task's pill visibly stretching across multiple hour rows — was directly visible without new scaffolding).

Full reasoning in `docs/DECISIONS.md`.

## [Post-Phase 9] Bug fix — "tap Continue while editing, nothing happens"

User-reported bug, reproduced on iOS Simulator via a new dev-scaffold (`edit_save_repro_main.dart`) that opens the edit form pre-changed and calls the real `_save()` handler directly (`debugAutoTriggerSave`, mirroring `debugAutoTriggerClose`'s established pattern). First repro attempt hit a `LateInitializationError` from the `timezone` package — the scaffold hadn't called `NotificationService.initialize()` the way `main.dart` always does — which itself proved the underlying failure class: none of `TaskList`'s five notification-syncing mutators (`createTask`, `scheduleTask`, `updateTask`, `rescheduleTask`, `toggleComplete`) had any error handling around `syncForTask`, so any real exception from that native platform-channel call could silently abort a save before the UI ever reached `Navigator.pop()`.

Fixed by adding `TaskList._syncNotificationSafely`, wrapping every `syncForTask` call (and `deleteTask`'s `cancelForTask`) in try/catch — the task write always completes and the UI always closes; a scheduling failure is logged via `debugPrint`, not silently swallowed. Confirmed the fix approach with the user first (AskUserQuestion) rather than assuming.

Verified three ways: (1) the corrected scaffold (now properly calling `NotificationService.initialize()`) ran cleanly on iOS Simulator with a real screenshot showing the sheet closed and the duration change (60→90 min) correctly persisted and rendered as a stretched pill on the Timeline; (2) three new regression tests in `task_providers_test.dart` using a new `ThrowingNotificationService` test double that always throws — prove `createTask`/`updateTask`/`deleteTask` still complete and refresh state even when notification sync fails; (3) full suite clean.

Verified via `dart format .`/`flutter analyze`/`flutter test` — all clean, 49/49 tests passing (46 previous + 3 new).

## [Post-Phase 9] False bug report — "nav disappeared on simulator" was a leftover dev-scaffold

Investigated a report that the bottom nav had vanished on the iOS Simulator. It had — but not because of a bug: the installed app was `edit_save_repro_main.dart`, the dev-scaffold built during the previous "Continue does nothing" investigation, which renders `Scaffold(body: TimelineScreen())` with no `AmbleHome` nav shell by design. Confirmed by matching the installed bundle's mtime against when that scaffold was launched. Reinstalling the real app (`flutter run -t lib/main.dart`) restored the nav immediately; the real app was never broken.

Root-caused the *recurrence risk* rather than just the instance: every scaffold set `debugShowCheckedModeBanner: false`, so a scaffold and the real app looked identical on-device, and every scaffold installs over the same bundle ID. Removed that suppression from all 16 `*_main.dart` scaffolds (kept in `lib/main.dart`) so scaffold builds are now instantly identifiable by the DEBUG banner.

This is the second "app looks wrong, code is fine" report in two days (the first being a stale pre-Phase-5 build on the physical iPhone) — both now written up in `docs/ERROR_LOG.md` with the same standing lesson: verify *which build is installed* before investigating layout code.

Verified via `dart format .`/`flutter analyze`/`flutter test` — all clean, 49/49 passing (no functional code touched; scaffold-only change).

## [Post-Phase 9] Drag time labels + overlapping-task layout

Two changes from one request. **Drag now shows its target times**: dragging a task displays the would-be start time above the pill and the end time (start + duration) below it, so the drop slot is readable directly on the block instead of eyeballed against the hour markers. Label and commit share the same snapped-delta getters, so what's shown mid-drag is exactly what gets saved.

**Dropping onto an occupied slot** was asked for as "push the other task down," but that's cascade replanning, which SCOPE.md line 26 explicitly defers out of the MVP — so it was raised as a stop-and-confirm rather than built. Offered allow-and-show / block-the-drop / full-cascade-with-a-SCOPE-amendment; user chose **allow the overlap and show it visually**, which stays in scope and needed no SCOPE.md change. Overlapping tasks now render side by side in columns (standard calendar treatment) instead of stacking invisibly.

The layout logic lives in a new widget-free `layoutOverlappingTasks` (`features/timeline/task_overlap_layout.dart`) so it could be tested properly: 10 unit tests covering touching-but-not-overlapping boundaries, fully-contained tasks, column reuse (a chained group needs fewer columns than it has tasks), per-group sizing, and input-order independence.

Two things only the device caught. The first overlap implementation used `FractionallySizedBox` to narrow each task's width — which changed nothing visually, because the pill is a fixed-width element inside the block's `Row`, so narrowing the available width leaves it exactly in place; replaced with a real per-column horizontal offset. Then the pills separated correctly but titles ran underneath the neighbouring column's pill, fixed by capping text width for any task not in the last column so titles ellipsize.

Also worth recording: a `flutter test` run mid-session took **16 minutes and reported a spurious failure** in an unrelated test file, which passed cleanly in isolation seconds later. Cause was environmental exactly as ERROR_LOG warns — a leftover `flutter run` process from earlier was still holding the Dart frontend compiler. Killed it; the same suite then ran in 2 seconds, all green. No code was changed in response to that "failure," which is the point.

Verified via `dart format .`/`flutter analyze`/`flutter test` — all clean, 59/59 passing (49 previous + 10 new), plus on-device verification on iOS Simulator via a new `timeline_overlap_main.dart` scaffold seeding deliberate two-way and chained clashes.

## [Post-Phase 9] Current time labelled in bold on the timeline gutter

Added the requested bold current-time label to the left of the red now-line, sharing the hour-label gutter (width passed through from the timeline's own constant so it stays aligned with `HourMarkers`), with the existing dot and line following it. The indicator row is now taller than the line, so it's shifted up half its height to keep the line sitting exactly on the current minute rather than being pushed below it.

On-device screenshot caught a collision the request didn't anticipate: at 14:54 the bold label rendered on top of the muted "15:00" hour label. Fixed by giving `HourMarkers` an optional `hideLabelNear`, which drops the hour label nearest the current time — threshold derived from the caption style's real line height rather than a hardcoded gap, so it scales with the type scale. Verified at 14:58: "15:00" correctly suppressed, 14:00 and 16:00 still present.

**Flagged, not fixed:** `CurrentTimeIndicator` renders on every day, not just today — so the now-line and its new label also appear on past/future days, where they're meaningless. Pre-existing, outside this request's scope, and the correct behaviour is a real UX call; written up in `docs/DECISIONS.md` rather than silently changed.

Verified via `dart format .`/`flutter analyze`/`flutter test` — all clean, 59/59 passing.
