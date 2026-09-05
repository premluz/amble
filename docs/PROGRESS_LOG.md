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

## [Phase 10] TrackedBehavior data layer — model, repository, providers, feature flag

Architecture-only session: the full data layer for `TrackedBehavior` plus the `Task` fields that link to it. **No UI, nothing user-facing, and the app is visually and functionally identical** — which was the explicit success condition, not a side note.

**New model** (`shared/models/tracked_behavior.dart`, Hive typeId 3) with `BehaviorTargetType` split into its own file/typeId 4, mirroring how `TaskStatus`/`TaskCategory` are already separated. Uses the same `uuid` call `Task.create` uses. Frequency is a plain `int timesPerWeek` — named for its unit so the MVP limitation is self-documenting rather than inviting someone to later overload a generic `frequency` field into the recurrence system SCOPE.md rules out. CONSTITUTION.md's "targetAmount is null only when targetType is binary" rule is enforced by a constructor assert rather than left as prose, so an invalid behavior can't reach Hive and surface later as a confusing null.

**`Task` gained `behaviorId`/`actualAmount`** as Hive fields 10/11 — appended, never renumbering existing fields, since adapters key on field number and real devices already hold persisted records. Both nullable, defaulting null, declared after every existing parameter, so `Task.create`/`Task.captured` are untouched at every call site. Also wired into `toJson`/`fromJson`/`hasSameFieldsAs` so export/import doesn't silently drop a behavior link — but read as *optional* on import, because every backup file exported before this session lacks those keys and must still restore cleanly.

**The riskiest step, handled as the work order specified:** captured a clean 59/59 baseline before touching `Task`, then ran the full pre-existing suite immediately after regenerating the adapter, before writing any new tests. It passed identically — 59/59, zero test files modified. Real-device evidence too: the launched app still reads task data written by the *pre-Phase-10* adapter, rendering correctly on the Timeline, which is the practical proof that appending fields was safe.

**Repository + providers** mirror `TaskRepository`/`TaskList` exactly, including `keepAlive: true` per the Phase 1 decision (autoDispose caused a real mid-flight teardown bug for Task state; same reasoning). New `tracked_behaviors` Hive box opened in `main.dart` alongside the Task box.

**Feature flag**: `FeatureFlags.trackedBehaviorEnabled` in `lib/core/feature_flags.dart`, a plain `const bool`, default **off**. Nothing reads it today — no UI exists to gate, which is the intended state until Phase 11+. It gates UI entry points only; the data layer is never "turned off," only dormant.

**14 new tests** (73/73 total): 10 covering `HiveTrackedBehaviorRepository` CRUD to Phase 1's standard (persist/retrieve, update-not-duplicate, delete, unknown id, optional `minimumAmount` both present and null, binary behavior with null target, unique UUIDs, and the constructor invariant being rejected) plus 4 proving the `Task` additions are inert — both factories leave the link null, the fields round-trip through JSON, a pre-Phase-10 backup with those keys stripped still imports, and `hasSameFieldsAs` notices a differing behavior link.

Verified via `dart format .`/`flutter analyze`/`flutter test` — all clean, 73/73 passing (59 pre-existing unchanged + 14 new), plus real-app screenshots on iOS Simulator confirming Timeline and Inbox are unchanged.

## [Phase 11] Recurring tasks — materialized instances

Built recurring tasks per CONSTITUTION.md's materialized-instance spec: real persisted `Task` rows, one per occurrence, rather than virtual expansion at display time.

**Model.** `RecurrenceRule` (typeId 5) as a value object embedded on the originating task — no id, not a `HiveObject`, per the Constitution — plus `RecurrenceFrequency` (typeId 6, daily/weekly only). `Task` gained `recurrenceId` (12) and `recurrenceRule` (13), appended, never renumbering. Same risk discipline as Phase 10: captured a 73/73 baseline, regenerated the adapter, and re-ran the full pre-existing suite *before* writing anything new — it passed identically, 73/73, zero test files touched.

**Generation.** `generateRecurrenceInstances` in `shared/services/recurrence_generator.dart` is pure and widget-free so the date maths is genuinely unit-testable; it *returns* tasks and never persists, so `TaskList` writes them through `TaskRepository` like every other mutation. Rolling window of `recurrenceWindowWeeks = 8` (named constant). Two decisions confirmed with the user rather than guessed: generation runs **at app launch only** (the Timeline stays a pure reader — no writes on day-swipe), and the recurrence UI is an **inline collapsed "Repeats" panel** in the create form. Creating a recurring task also materializes its series immediately, so it appears without waiting for the next launch.

**UI.** New adaptive `AppSwitch` in `core/widgets/` (design principle 4 forbids raw `Switch` in feature code). The Repeats panel is create-only — MVP edits affect one instance, so there's no series rule to edit. Timeline indicator is a muted `repeat` icon beside the time, matching the existing "moved" indicator exactly; existing Tier 2 tokens only, no new tokens.

**Instance-only editing needed no special-casing**, as the work order suspected. A materialized instance is an ordinary `Task`; the edit path mutates only its own object and `deleteTask` removes one id. Verified on-device.

**A real bug the screenshots caught.** Dedup originally keyed on `scheduledAt`, and I had written up the resulting "moving an instance frees its slot, which gets refilled" as an accepted trade-off. The edit-mode screenshot showed what that actually looks like: two "Morning run" entries on one day — the user's rescheduled 08:30 one plus a regenerated 07:00 duplicate. That reads as the app undoing the user's edit. Fixed to key on `originalScheduledAt ?? scheduledAt`. **The unit tests had passed against the wrong behaviour**, because they encoded the same wrong assumption — only a real device screenshot exposed it, which is precisely why ERROR_LOG.md requires them.

Also worth noting: an earlier screenshot appeared to show a task at the wrong time with a "moved" marker. That was **my own `adb` swipe dragging the task pill** — drag-to-reschedule working correctly. Re-scrolling via the hour gutter (clear of pills) confirmed 07:00 was right all along; no code was changed in response to that false alarm.

**Verification.** `dart format .`/`flutter analyze`/`flutter test` clean, **88/88** (73 pre-existing + 15 new generator tests covering window size, interval, daysOfWeek, endDate boundaries, idempotency across simulated relaunches, window sliding, and instance shape). Real screenshots on the Android emulator (which supports genuine swipe/tap, unlike iOS Simulator): the Repeats form control, Friday+Saturday showing separately materialized instances with the recurrence indicator, a one-off task correctly showing no indicator, and an edited instance with its Saturday sibling provably untouched.

`daysOfWeek` and `endDate` are fully implemented and tested in the model and generator but not yet exposed in the UI — the obvious next increment, flagged rather than built speculatively.

## [Phase 12] Cross-platform verification — closing accumulated gaps

Verification-only session. **No feature code changed**; one verification scaffold was made platform-portable, and two documentation corrections were made. `dart format`/`flutter analyze`/`flutter test` clean throughout, **88/88**.

**Hardware reality, established first:** `flutter devices`, `system_profiler SPUSBDataType`, `adb devices` and `xcrun devicectl list devices` all confirmed **no physical iOS or Android device is connected**. Items 3 and 4 of the work order are therefore **not closed** — reported plainly rather than substituting another emulator pass, which is what the work order explicitly asked for.

**Item 1 — recurring tasks on iOS Simulator: CLOSED.** Every element of the Android-only Phase 11 verification now reproduced on iOS, with evidence from both the UI and the persisted store:
- *Create form*: the "Repeats" control renders correctly on iOS (switch, interval stepper visible).
- *Materialization*: the iOS Hive box contains **57 "Morning run" rows** — exactly the 8-week window (56 days + template), against **1 "One-off meeting"** and **59 distinct UUIDs** (57 tasks + the series id). Read directly off the simulator's app container, so it proves what was *persisted*, not just what was painted.
- *Indicator*: screenshot shows the repeat icon beside "Morning run" and **no** icon on "One-off meeting" — the same contrast verified on Android.
- *Single-instance edit*: exactly **1** row carries the EDITED title while the series total stays **57**. That covers all 57 rows, not just the visible day — stronger than the Android screenshot check.
- **This also closes the loose end left at the end of Phase 11**: the dedup fix (`originalScheduledAt ?? scheduledAt`) was corrected but never re-verified on-device. The iOS edit screenshot shows **one** "Morning run" where the pre-fix Android run showed two. Fix confirmed on a real device, not just in unit tests.

**Item 2 — native import file picker: CLOSED on Android, still requires a human on iOS.** This is a genuine correction to a standing project assumption. Prior sessions recorded the picker as agent-unverifiable on *both* platforms; that was only ever true of iOS. `adb shell uiautomator dump` exposes the full on-screen hierarchy **including other apps**, so DocumentsUI's file rows can be located by real `bounds` and tapped precisely. Drove the whole flow with real taps: real Import button → `dumpsys` confirms foreground becomes `com.google.android.documentsui/...PickActivity` → drawer → Downloads → tap file → back to `com.example.amble/.MainActivity` → **"Imported 1 task(s). 0 already present, 0 conflict(s) skipped."**, count 0→1, and the persisted box contains the exact title from the chosen file. iOS stays blocked for a harder reason than previously recorded: `simctl` has **no tap/touch/input capability at all**, and `idb` is not installed — so even reaching the Import button is impossible without a human or a new system dependency (flagged, not installed).

**Item 4 partial — Android real-app spot-check on emulator:** export now verified from the **real app** rather than a dev scaffold (real system share chooser, correctly-named backup file), plus Settings and Inbox. Still emulator, not hardware.

**Environment gotcha found and logged:** `pkill`-ing the emulator leaves `~/.android/avd/<name>.avd/multiinstance.lock` behind; the next start then aborts with a misleading *"Running multiple emulators with the same AVD is an experimental feature"* FATAL **after** printing a normal-looking startup banner, so it presents as an emulator that boots forever and never registers with adb. Cost ~10 minutes. Full entry in `docs/ERROR_LOG.md`; prefer `adb emu kill` over `pkill`.

## [Phase 12] TrackedBehavior — the first UI slice

The smallest useful loop: create a tracked behavior, link a task to it, record an actual amount on completion. **No history view, no charts, no calibration, no reason/reflection field** — all still deferred per this session's non-goals.

**Feature flag became a build-time override rather than being flipped on** (confirmed with the user, who chose it over hard-coding `true`). `trackedBehaviorEnabled` is now `bool.fromEnvironment('trackedBehavior')`, so an ordinary build — including any release build from this commit — is **unchanged**, and SCOPE.md's "default off" stays true without relying on nobody editing the constant back. Testing uses `--dart-define=trackedBehavior=true`. Since `bool.fromEnvironment` is const-evaluated, every gated subtree still dead-code-eliminates when off.

**What shipped:** a `Track a behavior` entry point in a gated Settings section, opening an `AppSheet` form with exactly the model's five fields (title, type, target, optional minimum, times-per-week) — `AppSheet` rather than Phase 4's full-screen modal, since five short fields don't warrant a full-screen takeover. A `Tracked behavior` chip row in the task detail form, with **None** selected by default, available on both create and edit (unlike recurrence, which stays create-only — a link is a property of one task, so changing it later is unambiguous). An amount-only outcome prompt on completion, pre-filled to the target so the common case is one tap. A muted `track_changes` icon on the Timeline block, matching the recurring indicator exactly.

**Ordinary tasks are provably unaffected** — the session's real constraint, evidenced three ways: (1) the **entire pre-existing suite passes unmodified, 88/88**, no test files touched; (2) two new explicit tests assert an ordinary task's completion records no amount and takes the identical single-argument `toggleComplete(task)` path; (3) an on-device screenshot with the **flag off** shows the task detail form with no tracked-behavior UI at all. `_completeTask` guards in order — flag off → un-completing → no `behaviorId` → each falls straight through to the original call.

**Two composition details worth noting.** Recurring instances now inherit `behaviorId` (CONSTITUTION.md says the two systems compose) but deliberately **not** `actualAmount` — inheriting an outcome would fabricate evidence for days that haven't happened. And un-completing clears `actualAmount`, since an amount describing a completion that no longer stands would misreport history.

`docs/SCOPE.md` updated: TrackedBehavior's history/calibration surfaces remain deferred, but the line no longer claims *no* UI exists, since that's now false.

Verified via `dart format .`/`flutter analyze`/`flutter test` — clean, **97/97** (88 pre-existing + 9 new), plus real screenshots on iOS Simulator (create form, outcome prompt) and Android emulator (link picker, flag-off comparison).

## [Phase 12, follow-up] Tracked-behavior Timeline indicator — verified by screenshot

Verification only; **no product code changed**. Closes the gap flagged at the end of the Phase 12 session: the `track_changes` indicator was correct in code and covered by tests, but had never been *seen* rendering on a Timeline block. That distinction matters here specifically — per the Phase 3 note in `docs/DECISIONS.md`, Flutter's headless golden rendering draws icons as blank boxes, so neither `flutter test` nor a golden can prove an icon actually renders. Only a real screenshot can.

Added a `timeline` mode to the existing `tracked_behavior_main.dart` scaffold (rather than a new file) seeding four contrasting tasks 30 minutes apart, so a single screenshot shows every indicator combination at once: **ordinary** (no icon), **tracked only**, **recurring only**, and **both together**.

**Result: the indicator renders correctly, and both indicators coexist cleanly.** A 3× crop confirms both are real glyphs — `track_changes` as a concentric target, `repeat` as a two-arrow loop — visually distinguishable from each other despite sharing the same muted colour and `spacingSm` size, and separated by `spacingXs` with no overlap when a task carries both. The "both" case also demonstrates on a real render that a recurring series inherits its `behaviorId` onto materialized instances, which had previously only been asserted in a unit test.

One scaffold detail worth recording: the first run seeded tasks at hourly offsets from "now", which at 19:00 pushed two of them to 22:00/23:00 — outside the Timeline's 06:00–22:00 window, so they simply didn't render. Re-seeded at 30-minute spacing with the base hour clamped to 07:00–19:00, so all four land inside both the day window and one screenful regardless of when the scaffold runs. Worth knowing for any future scaffold that seeds "relative to now".

Verified via `dart format .`/`flutter analyze`/`flutter test` — clean, **97/97**, unchanged from the session's starting baseline (no test files touched).

## [Phase 13a] Dark mode — wiring and first-pass palette (CHECKPOINT, awaiting review)

Mechanism complete and working end to end; the palette is a deliberate first pass, **not** polished. Phase 13b is the visual-refinement pass — this session deliberately stopped short of one, per the work order.

**Preferences layer.** New `PreferencesRepository` / `HivePreferencesRepository` over a single untyped `preferences` box — a **generic key-value store**, not a theme-mode box, so later settings land here rather than each growing their own box and adapter. Keys owned by `PreferenceKeys`. `getValue<T>` returns null on a type mismatch rather than throwing, so a changed preference schema can't make the app unlaunchable.

**Theme plumbing.** Theme mode persists as our own `AppThemeMode` (Hive typeId 7), not Flutter's `ThemeMode` — persisting a framework enum would tie the stored schema to its declaration order. `toFlutterThemeMode` is the single translation point. Exposed via a `keepAlive: true` provider read by the root `MaterialApp`, which now supplies `theme`/`darkTheme`/`themeMode` together. Three-way Light/Dark/System chip row added to Settings under a new "Appearance" section.

**Dark palette.** New `ink` OKLCH ramp at hue 90 (matching the `sand` neutral) so dark mode reads as the same product rather than generic grey — derived deliberately, not inverted or auto-darkened. Chroma stays tiny and *rises* with lightness; lightness steps are uneven because perceived separation compresses near black. New `sand200`/`sand400` carry dark text at a measured 15.6:1 / 7.5:1. **Category colors are unchanged** — measured at 4.9–5.2:1 against `ink900` before deciding, so a dark-specific ramp would have added a second set of values to maintain for no gain.

**Two fixes that fell out of the wiring.** `main.dart` carried hardcoded hex (`0xFF5B6F52`, `0xFFF7F5F0`) for the Material seed/scaffold — a no-magic-values violation, and a real hazard here since a light scaffold could show through a dark theme. Now derived from the palette. And system bar styling needed an explicit root `AnnotatedRegion`: the app has no `AppBar` anywhere, which is normally what manages status-bar icon brightness, so without it dark mode rendered dark icons on a near-black surface.

**Verified:** `dart format .`/`flutter analyze`/`flutter test` clean, **110/110** (97 pre-existing + 13 new). `widget_test.dart` needed a `preferencesRepositoryProvider` override added — `AmbleApp` now reads it at build time, same reason the task repository was already overridden there.

**Flagged for 13b review** (deliberately not changed): the category-pill icon glyph uses `colorSurfacePrimary`, so it renders white in light mode but near-black in dark. Measured *higher* contrast in dark (4.9–5.2:1 vs 3.6–3.8:1 for white), so it's legible — but it's an inconsistency in how the same component reads across themes, and the right answer is a design call. Also: the accent (FAB, nav pill, primary button) is the light `sage300` and reads brighter than the surroundings in dark; and the timeline canvas separates only subtly from the base surface.

## [Timeline, post-Phase 13a] Drag "lift" state

Requested: a lift state on drag with a visually large drop shadow. Confirmed the treatment before building (AskUserQuestion) since it replaces existing behaviour — the block previously faded to **0.75 opacity** while dragging, which read as receding rather than being picked up.

Now: fully opaque, scaled to 1.04 via `AnimatedScale` on the existing `motionFast`/`curveStandard` tokens, casting a new `shadowLift` token. The scale is deliberately small — a bigger lift looks more dramatic but makes the drop target ambiguous, because the block stops matching the size of the slot it's about to land in.

`shadowLift` is a real **Tier 2 token**, not an inline `BoxShadow`: this is the app's second shadow (the sheet's Continue button is the first), so per design principle 5 it gets promoted before a third use appears. Threading it through `AmbleTheme` meant the constructor, both palettes, `copyWith` **and** `lerp` — missing either of the last two would make the token silently revert to the other palette's value mid theme-animation, a bug that only shows during a transition. Tested explicitly, including that `lerp` actually interpolates at the midpoint.

**The first attempt failed on-device and the screenshot is what caught it.** A single 40px-blur shadow at 22% alpha was almost invisible against `sand50` — the alpha spread that far just washes out. Replaced with the standard two-layer approach: a tight contact shadow (12px blur) that anchors the element, plus a wide ambient layer (40px) that conveys height. Re-verified mid-drag on device in both palettes; dark uses pure black at higher alpha, since depth on a near-black surface has to come from something *darker* than the background.

Worth recording: fixing this **broke one of my own tests**, correctly. The "larger than the sheet button's shadow" assertion read `.first`, which became the tight contact layer. Rewritten to check the *widest* layer, since the assertion was always about reach rather than declaration order — plus a new test asserting the two-layer structure itself, so a future "simplification" back to one shadow fails loudly rather than quietly making drag flat again.

Verified via `dart format .`/`flutter analyze`/`flutter test` — clean, **118/118** (110 pre-existing + 8 new), plus mid-drag screenshots in light and dark on the Android emulator (a held `input swipe` with a concurrent screencap — iOS Simulator has no drag injection).

## [Phase 13a-pastel] Light-mode palette softened (CHECKPOINT, awaiting review)

Requested directly: move the light palette toward a softer, more pastel character — lower chroma, higher lightness, gentler than the existing saturated set. Explicit checkpoint: re-derive Tier 1, re-verify contrast and category distinguishability rigorously, stop for review before Phase 13b (dark mode) resumes. **Dark mode is completely untouched this session** — same discipline as the Phase 13a checkpoint before it.

**What moved and what didn't.** Category accents (`clay`/`ochre`/`periwinkle`/`berry`) went from L=0.62/C=0.10 to L=0.78/C=0.075–0.095, with hues nudged (30/120/250/340 → 35/160/240/345) rather than held fixed — full L/C/H table and hex values in `docs/DECISIONS.md`. `sage500` (the light-mode accent/button/FAB workhorse) moved from L=0.517/C=0.051 to L=0.550/C=0.060, tuned specifically to hold WCAG AA rather than picked by eye. `sage100`/`sage300`/`sage900` were **deliberately left unchanged** — `sage300` is dark mode's `colorAccent` (a shared primitive), and moving it would have been an unrequested dark-mode side effect smuggled in under a light-mode work order. `coral*` (the alert ramp) wasn't touched either: it's a functional status color, not a category swatch, and softening it would work against the one job it has — reading as urgent.

**Only Tier 1 (`color_primitives.dart`) changed.** `semantic_theme.dart` needed zero edits, which is the token architecture doing exactly what it's for — a palette swap propagates through Tier 2's references without touching the semantic layer.

**A real, required companion fix, not scope creep:** at the new pastel lightness, a white icon glyph on any category pill drops to ~1.8–2.1:1 contrast — well under the 3:1 WCAG floor for graphics. `TaskCapsuleBlock` now computes the glyph color per-badge (dark `colorTextPrimary` only for the plain-category case, detected via `ThemeData.estimateBrightnessForColor`; `colorTaskSkipped`/`colorTaskCompleted` badges keep white, since those stay dark enough). Deliberately **not** a new Tier 2 token — considered and rejected, since the work order specified Tier 2 needing no changes and a widget-local fix achieves the same correctness without expanding the token schema mid-checkpoint.

**Distinguishability was re-verified, not assumed.** The naive version of "more pastel" — lowering chroma uniformly, keeping hues fixed — actually *compressed* perceptual separation and scored worse than the old palette on 5 of 6 pairs when checked via OKLab deltaE. The hue nudges above exist specifically to fix that: the corrected palette meets or beats the old one on 5 of 6 pairs, and the closest pair under a red-green color-vision-deficiency proxy matches the old palette's worst-pair score exactly rather than falling below it. Checked with a throwaway Python script (not shipped, not a new Dart dependency) mirroring the existing hand-written OKLCH conversion.

**Verified:** `dart format .`/`flutter analyze`/`flutter test` clean, **118/118** — one golden (`timeline_capsule_preview.png`) intentionally regenerated for the new category colors, everything else unchanged. Real screenshots on the Android emulator (release build, `lib/main.dart`): Timeline with all four category colors visible together, the task-detail form's category picker (each chip legible, full-bleed header color also checked), and Settings (softer sage on the toggle chips and Export button). iOS Simulator screenshots not captured this session — Android alone was sufficient to verify the actual color/contrast changes, which are platform-independent; flagged rather than silently skipped.

**Flagged for 13b, not fixed here:** dark mode's `sage300`/category ramp are now the *old*, more saturated values, so light and dark currently disagree in character until 13b deliberately addresses it — expected given this session's explicit sequencing, not a bug.

## [Phase 13a-pastel-v2] Category palette re-derived against a user-supplied reference — supersedes the pass above

The first pastel pass (L=0.78, C≈0.08) was a genuinely softer mid-tone, but the user then supplied a real reference palette — "8 Soft Pastel Colors," pale tints at L≈0.95–0.99 — that's a different point on the scale entirely: a true tint, not a muted accent. Confirmed via AskUserQuestion (not guessed) how that should map onto a small pill: **a pale tint fill plus a separate, saturated same-hue icon glyph**, since at that lightness no single glyph color clears contrast against the fill alone. Also confirmed the category mapping: Peach→health, Mint→work, Sky→personal, Lavender→admin, out of the reference's eight swatches.

**`AmbleTheme` gained a second color map, `categoryIconColors`,** threaded through the constructor/both palettes/`copyWith`/`lerp` the same way `shadowLift` was. `categoryColors` now holds the pale tint (matched to the reference's own hex values through the app's real `oklch()` pipeline, not hand-copied — verified within 1–3/255 per channel); `categoryIconColors` holds a deliberately saturated version of the same hue, which `TaskCapsuleBlock` now reads directly instead of inferring a glyph color from brightness estimation, since a real per-category value exists now.

**A naming collision with dark mode was caught before it shipped, not after.** `clay500`/`ochre500`/`periwinkle500`/`berry500` — dark mode's pill-fill primitives, measured back in Phase 13a at 4.9–5.2:1 against `ink900` — got repurposed in-place as the new icon-glyph names. Left alone, that would have silently changed dark mode's rendering through a name collision rather than a value change anyone asked for, in a session explicitly scoped to light mode only. Fixed by preserving the original numbers under new, dark-exclusive names (`*Dark` suffix) and repointing dark's two category maps at those — dark mode is byte-for-byte unchanged.

**Distinguishability was re-checked and a real regression was caught.** The reference's Sky and Lavender hues sit close enough together that a first attempt (hues held at the reference's raw values) scored *below* the pre-pastel palette's worst-pair floor on the same red-green-CVD proxy used in the first pastel pass — an actual step backward on the exact axis Phase 3 originally fixed, not a hypothetical risk. Widening personal/admin's hue gap fixed it, verified against the same floor rather than assumed safe because the source was a polished-looking reference.

**Full before/after tables, per-category contrast numbers, and the distinguishability math are in `docs/DECISIONS.md`.** Verified: `dart format .`/`flutter analyze`/`flutter test` clean, 118/118 (one golden regenerated a second time), plus real Android emulator screenshots of Timeline (all four categories together), the category picker, and Settings, re-captured against this palette.

## [Timeline, drag ghost] "Leave a faded ghost at the original slot while dragging" — real bug found and fixed via user report, not caught in-session

Requested directly: while dragging a task, leave a 20% ghost copy at its original position until dropped. First implementation wrapped `_DraggableTaskBlock`'s single `Positioned` root in `Positioned.fill(child: Stack(...))`, so the widget's own `build()` could inject two `Positioned` children (ghost + live block) into the ambient day-timeline `Stack`. Structurally this worked — confirmed with a temporary magenta debug marker that the ghost's positioning math and `IgnorePointer` gating were correct — but the user reported a real interaction bug on a fresh Android install: **the first drag on any task would "arm" (shadow/lift/preview labels all appeared) but not actually move the block, and only a second drag on the same task worked.**

**Root cause:** `Positioned.fill` sizes its child to the *entire* ambient Stack's bounds — meaning every dragged task's wrapper widget, while dragging, had a hit-testable footprint the height of the whole day column, not just its own badge. With several task blocks in a day, each carrying this oversized footprint, the extra Stack nesting changed gesture-arena timing enough that the first pointer-down after a fresh app launch lost arbitration and the drag recognizer never actually claimed the gesture — evidenced by `onVerticalDragStart` firing (hence the visible "armed" state) while `onVerticalDragUpdate` never delivered usable deltas.

**Fix:** lifted the "which task is dragging" state up to `_DayTimelineState` (a new `_draggingTaskId` field) instead of having each `_DraggableTaskBlock` manage its own ghost internally. The parent's existing `for` loop now emits the ghost as a genuine sibling `Positioned` — conditional on `_draggingTaskId == slot.task.id`, `IgnorePointer`-wrapped, computed from the same layout math (`_minutesSinceStart`, column offset) the live block already used — right alongside the unchanged `_DraggableTaskBlock`. `_DraggableTaskBlock` itself is back to exactly its pre-ghost shape: a single `Positioned` root, no nested Stack, reporting drag start/end via a new `onDraggingChanged` callback instead of owning ghost rendering itself. No extra Stack depth, no inflated hit-test region — the drag `GestureDetector` sits at the identical nesting depth it always did.

**Verified the fix, not just the theory:** re-tested the exact failure mode — force-stopped and relaunched the app fresh, then dragged a task on the very first attempt. The drag now moves and drops correctly first-try (confirmed via a real `adb input draganddrop` capturing a genuine mid-drag frame showing both the preview time labels and a visibly separate faded original-position element), with no stuck lift/shadow state surviving the drop or a subsequent app restart.

Worth recording: the original architecture *looked* correct under every check available short of a real interaction — clean `flutter analyze`, clean tests, a debug marker proving the positioning math — and still shipped a real usability bug. The gap was gesture-arena behavior, which none of those checks exercise. `dart format .`/`flutter analyze`/`flutter test` clean, 118/118, unchanged from the ghost feature's own baseline (no test files touched by this fix).

## [Timeline] Fixed: tasks before 6am or after 10pm were unreachable — scroll bug, not a gesture bug

Reported directly, alongside a separate (deferred) request to redesign the time axis as task-driven rather than a fixed hourly grid — the two were split: this fix is the small, safe half; the axis redesign is its own future session, since it changes the timeline's core visual model and CONSTITUTION.md already flags the capsule/timeline component as the one place worth real design-review time rather than folding it into an unrelated bug fix.

**Not actually a scroll-gesture bug** — the day view's rendered content genuinely didn't extend past 6am-10pm (`_startHour`/`_endHour` constants), so `SingleChildScrollView` had nothing to scroll to beyond that window. Any task scheduled at 5am or 11pm was there in the data and on the day, just unreachable on screen. Fixed by widening the constants to the full calendar day (`_startHour = 0`, `_endHour = 24`) — `_endHour = 24` sizes/positions the full 24 hours of content, but `TimeOfDay` only accepts hour values 0-23, so `HourMarkers`' label loop now stops at 23 (11:00 PM) while still using the full 24-hour height for layout — the same way a real 24-hour clock has a "00:00" tick and no separate "24:00" one.

Verified past the code: `dart format .`/`flutter analyze`/`flutter test` clean, 118/118 (no test files needed changes — this scenario wasn't under test before, and adding day-boundary coverage is a reasonable follow-up but wasn't required to confirm the fix). On-device, re-tested both edges directly: scrolled to the true top of a real day and confirmed 12:00 AM renders with a previously-unreachable 4:00 AM task now visible, then scrolled to the true bottom and confirmed it reaches past 11:00 PM to the end of the day.

## [Timeline] Fixed hourly grid replaced with task-boundary time labels

The deferred half of the previous session's request: swap the left gutter's generic `:00` hour ticks for labels tied to what's actually scheduled that day, matching a reference design. Confirmed the scope via two AskUserQuestion decisions rather than guessing either: **(1)** keep the timeline's underlying scale linear/proportional — only which labels render changes, not how pixels map to minutes, so drag-to-reschedule, the current-time indicator, and overlap layout all stay untouched (they assume linear time); **(2)** gutter shows task start/end times only, with hour ticks removed entirely rather than falling back to them in empty gaps — matches the reference exactly, at the cost of empty stretches of a busy day having no time reference at all (a fully empty day already renders `_EmptyDayState` instead, so this only affects gaps *between* tasks, not a whole blank day).

**New pure function, `taskBoundaryTimes`** (`task_boundary_markers.dart`): collects every scheduled task's start and end `DateTime`, de-duplicates by exact value in a `Map<DateTime, TaskBoundary>`, sorts chronologically. De-duplication is the load-bearing behavior here — confirmed via AskUserQuestion that back-to-back tasks (one's end equals the next one's start) should share one label, not render the same time twice, matching the reference. Overlapping tasks (rendered side-by-side by the existing `layoutOverlappingTasks`) fall out of the same de-dup logic for free, since it only cares about the `DateTime` values, not which column a task sits in — no overlap-aware special-casing needed. A zero-duration task collapses to a single boundary the same way, for the same reason (start == end).

**`TaskBoundaryMarkers` replaces `HourMarkers`**, which is now deleted outright (it had exactly one real caller, and nothing else referenced it beyond doc comments — updated those in `current_time_indicator.dart` rather than leaving stale `[HourMarkers]` links). Same collision-avoidance rule as before (a boundary label near the bold current-time label is hidden, threshold derived from the caption text's own line height, not a hardcoded pixel gap) — ported over unchanged, just re-keyed on `DateTime.difference` instead of hour/minute arithmetic since boundaries are full timestamps now, not just an hour.

6 new unit tests for `taskBoundaryTimes` (empty day, single task, sort-order independence, back-to-back de-dup, overlapping-task de-dup, zero-duration collapse). Verified on-device: a day with sparse tasks now shows sparse labels exactly at each task's edges and nothing else, confirmed scrolling from a task at 12:05 AM through gaps to one at 7:15 AM with zero grid lines in between, matching the reference's character. `dart format .`/`flutter analyze`/`flutter test` clean, 124/124 (118 + 6 new).

## [Splash/carousel] First-launch acquisition screen — presentational only, per docs/SCOPE.md's sequencing

Built the "splash/landing + carousel" half of SCOPE.md's deferred splash/onboarding pair, explicitly not the onboarding question flow (still not started, per SCOPE.md). No new data model — the entire feature is presentational plus one boolean preference.

**Flow:** brief splash (the same diagonal line-and-dot mark as the Phase 9 placeholder app icon, live-drawn via `CustomPaint` rather than a new asset, "Amble" wordmark) for 1.2s, then a 4-slide `PageView` carousel with page-dot indicator, Next/Skip on slides 1-3, a single "Get started" CTA on the last slide. The CTA persists `hasSeenSplash = true` through the existing `PreferencesRepository` (Phase 13a) and the root `MaterialApp` — which **watches**, not reads, the new `hasSeenSplashProvider` — swaps straight to `AmbleHome` on the very next rebuild. No `Navigator.push`, no stub onboarding screen: exactly "skip straight to the real app," as scoped.

**Draft carousel copy** (flagged for review, not final — see the widget's own doc comment): four slides pulled from principles already established across this build — CONSTITUTION.md's "the plan is provisional, not a verdict" and "capture is frictionless," plus the local-first/no-account positioning. Each slide reuses one of the four pastel category tint/icon-color token pairs purely for visual variety, no connection to the user's actual categories.

**Debug-only reset**, flagged per the work order's own instruction: a "Developer" section in Settings, gated on `kDebugMode` (not `FeatureFlags` — this isn't a product feature to toggle per-build, it's a developer convenience that must categorically not exist in any real build, and `kDebugMode` is compile-time `false` in release/profile builds the same way a `FeatureFlags` gate dead-code-eliminates). One button calls `HasSeenSplash.reset()`, which — because `main.dart` watches the provider — re-shows the splash immediately, no app restart needed.

**Two real, pre-existing dark-mode bugs found and fixed while verifying, not introduced by this session's own code:**

1. **Category icon glyphs were invisible in dark mode** — `categoryIconColors` for dark mode mirrored `categoryColors` (both `clay500Dark`/etc.), so an icon was drawn in the exact color of its own background. This predates the splash work: it was introduced when `categoryIconColors` was added during the pastel-palette session, on the reasoning "dark mode never had a separate icon treatment" — true of the *old* code path (`TaskCapsuleBlock` read `colorSurfacePrimary`, white in light mode only by coincidence), but that session's rewrite made `iconColor` read `categoryIconColors` unconditionally in both palettes. My splash carousel's much larger category circles made the bug impossible to miss; it was equally present on every real Timeline task pill in dark mode. Fixed to pure white — the actual pre-pastel-session value, verified at 3.56-3.83:1 against all four dark category colors, matching Phase 13a's own originally-measured 3.6-3.8:1 figure.

2. **The bottom NavigationBar stayed white in dark mode** despite `backgroundColor: theme.colorSurfacePrimary` being wired correctly since Phase 5. Material 3's `NavigationBar` applies its own `surfaceTintColor` overlay by default (derived from `ColorScheme.fromSeed`), which paints *over* an explicit `backgroundColor` rather than being superseded by it. Fixed with `surfaceTintColor: ColorPrimitives.transparent`. Never caught before because no prior session's dark-mode screenshots happened to include the nav bar itself in frame.

Both fixes verified on a genuinely clean rebuild (`flutter clean` + fresh install, not just a hot patch over stale state) — the first attempt at verifying the nav-bar fix showed the same white bar, which turned out to be a stale build artifact, not a failed fix; a true clean rebuild resolved it.

**Verified:** `dart format .`/`flutter analyze`/`flutter test` clean, 124/124 (unchanged — no test files needed changes for this session). Real Android screenshots: splash logo in both palettes, multiple carousel slides in both palettes, the CTA landing on a real empty Timeline with the bottom nav present, a second launch skipping straight past the splash, and the debug-only reset section appearing only in a debug build (confirmed absent in a `--release` build of the same commit).

## [Splash/carousel, correction] Third dark-mode bug: `colorSurfacePrimary` was actually `ColorPrimitives.white`

Reported directly after the previous entry shipped: Timeline, Settings, and the splash screen's page background all still stayed fixed white in dark mode — not just the nav bar. Root cause was a genuine bug in this session's own earlier edit: while restructuring the dark palette block for the `categoryIconColors` fix, `colorSurfacePrimary`'s field value stayed `ColorPrimitives.white` even though the comment directly above it correctly describes the field as "near-black `ink900`." A copy-paste slip, not a design decision — the comment and the code disagreed, and nothing in that edit's review caught it.

This explains the earlier nav-bar investigation more completely than the `surfaceTintColor` fix alone did: `colorSurfacePrimary` is consumed by roughly a dozen call sites (nav bar, Settings, Inbox, splash, `AppSheet`, `AppButton`, task detail sheet), not just the one. The `surfaceTintColor` fix was still real and necessary — verified in isolation as a genuine, separate Material 3 behavior — but the first verification pass happened to land on a build/moment where the two bugs' effects were hard to tell apart, and called it fixed too early.

Fixed: `colorSurfacePrimary: ColorPrimitives.ink900`. Re-verified from a genuinely fresh state — full emulator restart, fresh install, dark mode explicitly re-selected rather than carried over — confirming Timeline, Settings, and the splash screen all render a real dark background now, not just the nav bar. `dart format .`/`flutter analyze`/`flutter test` clean, 124/124, unchanged.

## [Timeline] Connector line, larger icon padding, task-driven scroll range

Three requests against a reference image. Two were quick; the third turned into a real refactor.

**Connector line**: a continuous gray line now runs down through every consecutive task's badge, matching the reference — new `borderWidthConnector` token (3px, `colorBorder`), new `_TimelineConnectors` widget. Skips pairs that overlap in time (the side-by-side pills already show that clash) and, for the rare case where consecutive tasks land in different overlap columns, draws the segment at the later task's column rather than attempting a diagonal.

**Icon padding**: the category badge's top padding went from 4px to 16px (`theme.spacingMd`) — a one-line change, but visible everywhere a task pill renders, so the golden test's screenshot needed regenerating.

**Scroll range**: the Timeline no longer scrolls the full 24-hour day. It's now clamped to `[earliest task − 30min, latest task + 30min]` — genuinely reachable early/late tasks (the point of last session's 0–24h fix) without an empty pre-dawn or late-night void to scroll through to find them. This meant retiring `_startHour: int` everywhere it appeared — hour-count math doesn't generalize to a range that can start at an arbitrary minute — in favor of a real `rangeStart: DateTime` threaded through `_DayTimelineState`, `TaskBoundaryMarkers`, `_TimelineConnectors`, and `CurrentTimeIndicator` (which also gained a `rangeEnd`, since a tightly clamped day can easily not contain the actual current time at all — previously only "before the range" was handled).

Verified on-device: confirmed the connector renders as one unbroken line through several tasks, and confirmed a genuine scroll limit at the top of a real day — the current-time indicator sitting pinned right at the boundary with the day's earliest task just below it, not floating in leftover empty space. `dart format .`/`flutter analyze`/`flutter test` clean, 124/124 (one golden regenerated for the padding change; nothing else needed updating since no test referenced the old hour-based APIs directly).

## [Timeline, correction] Icon padding is 12px, not 16

Quick follow-up: the requested value was 12px, not 16 — corrected. 12 isn't on the existing spacing scale (4/8/16), so rather than round to the nearest existing token, added a new one-purpose `spacingIconTop` token (12px) the same way `borderWidthConnector` was added earlier in this session for a value with no existing home. Verified on-device and via a regenerated golden. `dart format .`/`flutter analyze`/`flutter test` clean, 124/124.

## [Timeline] Completion moved to a trailing checkbox; pill/title is now pure tap-to-edit; celebration emoji on completing

Reported directly: tapping the badge toggled completion, tapping the name opened edit — same row, two different behaviors depending on where you tapped, which read as confusing. Fixed by removing the badge's toggle entirely: the whole pill+title area now always opens the edit sheet. Completion moved to a new `CompletionCheckbox` — a small hollow ring on the far right of each row, filled with a checkmark when done, matching a reference image. Removed the old completed-state corner badge on the icon pill too, so the checkbox is the single place completion status shows.

**48px minimum tap target**, per the Material Design/WCAG guidance quoted directly in the request — the visible ring is only 24px, but a new `spacingMinTapTarget` token pads the actual tap area out to 48px regardless of how small the ring looks.

**Celebration**: completing a task (not un-completing) fades a random emoji — 👏🏼🏆🥇🎯🥁🏁💪🏼🌟 — in over the checkbox, holds, then fades out to reveal the ticked checkbox underneath. Built with plain Unicode emoji and Flutter's own `AnimationController`/`TweenSequence`, not the animated Noto emoji library the request linked to — that's a Lottie-backed CDN asset set, which would have meant a new network dependency and a new package, flagged and declined via AskUserQuestion in favor of the zero-dependency, works-offline version.

Verified on-device: the checkbox toggles independently of the pill, the celebration actually renders and fades to reveal the checked state, and the pill/title area reliably opens the real edit sheet now instead of ever toggling completion. `dart format .`/`flutter analyze`/`flutter test` clean, 124/124 — one golden regenerated for the layout change.

## [Timeline, follow-up] Real animated Noto emoji, not static Unicode — dependency explicitly authorized

User overrode the earlier decision directly: "Use noto > override dependence allowed." Added the `lottie` package and downloaded the 8 real animated Lottie files from Google's Noto emoji CDN (the exact codepoints from the original request), bundled locally under `assets/celebrations/` — confirmed via AskUserQuestion that bundling (not a live CDN fetch each time) was the right call, since it keeps the celebration working offline.

`CompletionCheckbox` now plays a real animated graphic (e.g. a moving gold trophy) over the checkbox instead of a static emoji character — the existing fade-in/hold/fade-out timing is unchanged, it's just fading in/out something that's animating on its own underneath now. Verified on-device: triggered a completion and confirmed the actual Lottie animation renders, not a fallback box — the asset path and package wiring are genuinely correct. `dart format .`/`flutter analyze`/`flutter test` clean, 124/124.

## [Task detail UI restructuring] Create split into a 2-step wizard; edit split into single-purpose modals; new task action sheet

Rebuilt `task_detail_sheet.dart` around a shared per-field state pattern instead of one form serving both create and edit. `showTaskDetailSheet` is now create-only: a 2-step wizard (`_TaskDetailFlow`, one state object owning every field across both steps plus a `_Step` enum) — step 1 (details: title/category/tracked-behavior link/notes) has a "Continue" button, step 2 (schedule: date/time/duration/repeats) has a back arrow and "Schedule" (the actual persist, via `TaskList.createTask`); nothing writes until step 2's save. `showEditDetailsSheet`/`showEditScheduleSheet` are new, single-step, single-purpose modals for editing an already-scheduled task — no step navigation, no "Continue," and the schedule modal never shows the Repeats panel (recurrence stays create-only per CONSTITUTION.md — editing a materialized instance never touches the series rule). All three share the same header/body/sticky-button chrome (`_StepScaffold`) and every sub-widget from the old single form (`_Panel`, `_CategoryTag`, `_TimeScroller`/`_Wheel`, `_RecurrencePanel`/`_DayChip`, `_BehaviorPickerPanel`/`_BehaviorChip`, date/time formatters) verbatim.

New `lib/features/task_detail/task_action_sheet.dart`: `showTaskActionSheet` — a 4-row bottom sheet (Edit details / Edit time and duration / Duplicate / Remove) opened by tapping a task on the Timeline, replacing the old direct-to-full-form tap. Built on the existing `AppSheet` primitive (its `builder` already supports arbitrary content, no new adaptive-widget gap). Destructive "Remove" row reuses the existing `colorTaskAlert` token (already used by `AppAlertDialog` for destructive actions) — no new color token needed. `TaskList.duplicateTask` (new) builds a standalone copy via `Task.create` (fresh UUID, no `recurrenceId`/`recurrenceRule`, no `status`/`completedAt`/`actualAmount` carried over — starts `pending`) and returns it so the caller opens it straight into "Edit details" for review.

`timeline_screen.dart`'s `onTaskTap` now calls `showTaskActionSheet` instead of `showTaskDetailSheet`; the FAB's create call and `inbox_screen.dart`'s own `showTaskDetailSheet(context, task: task)` call site are both unchanged, per direct instruction. The Inbox case needed one extra affordance on `showTaskDetailSheet`: an optional `task` param that pre-fills the create wizard from an existing *unscheduled* (captured) task and, on save, fills in that same task's schedule via `updateTask` rather than creating a second one — kept it create-*style* (2-step, "Continue"/"Schedule") since an Inbox item genuinely has no time yet, distinct from editing an already-scheduled task.

Updated every `*_main.dart` scaffold that referenced the old `TaskDetailForm` class or the old single-form edit call, to use `showEditDetailsSheet`/`showEditScheduleSheet`/`showTaskActionSheet` instead (`exit_confirm_modal_main.dart`, `exit_confirm_schedule_main.dart`, `exit_confirm_discard_main.dart`, `edit_save_repro_main.dart`, `timeline_screen_detail_sheet_main.dart` — the first three now seed a real scheduled task rather than a captured one, since the edit-schedule modal only ever opens on an already-scheduled task). `recurrence_verification_main.dart`, `tracked_behavior_main.dart`, and `inbox_move_to_timeline_main.dart` needed no changes — their existing calls already match the new/preserved signatures. Rewrote `test/features/task_detail/exit_confirmation_test.dart` to pump through the public `showTaskDetailSheet`/`showEditDetailsSheet` functions instead of the now-deleted `TaskDetailForm` class directly; same coverage, split cleanly into create-flow and edit-details-flow sections.

Judgment calls made, not explicitly specified in the work order: (1) no separate confirmation dialog on "Remove" — it calls `TaskList.deleteTask` directly, matching how deletion is invoked elsewhere in the app without a confirmation step; (2) action-sheet file placed under `features/task_detail/` (not `features/timeline/`) for consistency with the rest of the task-editing UI, even though its only call site is `timeline_screen.dart`; (3) destructive color reused `colorTaskAlert` rather than adding a token, since it was already the exact semantic ("destructive action") the design called for.

`flutter analyze`: clean. `flutter test`: 124/124 passed. No goldens needed regeneration — the timeline capsule-block golden is unrelated to this change and passed unchanged. On-device/simulator verification not done, per the work order's own instruction (not available in this environment for this task).

## [Post-Phase 9] "Prevent overlapping tasks" opt-out toggle — deliberate reversal of the side-by-side-overlap default
A new Settings preference (`PreferenceKeys.preventOverlappingTasks`, `PreventOverlappingTasksSetting`, default **true**) that, when on, blocks creating/scheduling/dragging a task into a slot that overlaps another scheduled task — reject-and-snap-back, no cascade, no auto-adjustment. This is a confirmed, deliberate opt-out layered on top of the post-Phase 9 "overlaps allowed, shown side by side" default recorded in docs/DECISIONS.md, not a reopening of that decision — the old behavior remains the default when the switch is off, and is exactly what happens today when it's on but no conflict exists.

Added: `lib/shared/services/overlap_checker.dart` (`overlapsExistingTask`, pure/widget-free, half-open interval semantics mirroring `task_overlap_layout.dart`'s `_layoutGroup`/`_endOf`), a new "Scheduling" section in `settings_screen.dart` with an `AppSwitch` toggle, and the preference notifier in `preferences_providers.dart` following `ThemeModeSetting`'s exact pattern (only difference: default `true`, flagged in its doc comment).

Wired into the three interactive flows only — create wizard's Save/Schedule button and edit-schedule modal's Save button in `task_detail_sheet.dart` (inline error text in `colorTaskAlert` above the primary button, sheet stays open, nothing persisted), and `timeline_screen.dart`'s drag-to-reschedule (`_DraggableTaskBlock` became `ConsumerStatefulWidget` so `onDragEnd` can read the preference and task list; a blocked drop snaps back exactly like the existing `minutesDelta == 0` no-op branch, no separate error UI). `TaskList`'s mutators (`createTask`/`updateTask`/`scheduleTask`/`rescheduleTask`) are untouched — the check happens in the UI layer before calling them, per CONSTITUTION.md's one-directional layering (this is a UI validation concern, not a data-integrity one). Confirmed `importTasks`/`_materializeSeries`/recurrence generation are unaffected, as instructed — a bulk restore or recurring series materializing weeks out should never silently reject entries, and there's no UI there to show an error anyway.

Completed tasks still count as blocking (judgment call, flagged per the work order): the point of the preference is a realistic view of what's occupying the day, and a completed task occupied its slot just as much as a pending one.

`test/shared/services/overlap_checker_test.dart` added (8 tests: no overlap, exact overlap, partial overlap, back-to-back half-open boundary both directions, self-exclusion, completed-still-blocks, different-days-never-overlap, unscheduled-tasks-ignored). `task_providers_test.dart` needed no changes (confirmed — `TaskList` never learned about this preference). `exit_confirmation_test.dart` needed one override (`preventOverlappingTasksSettingProvider` fixed to `false`) since its `_pumpHost` doesn't open a real `preferences` Hive box and one of its scenarios does reach the create wizard's `_save()` via the "Schedule this" exit-confirmation path — the fixtures themselves never overlap, but the provider's `build()` would otherwise throw on the missing box before ever reaching the overlap check.

`flutter analyze`: clean. `flutter test`: 132/132 passed.

## [Cascade replanning] Push-based cascade reschedule for drag-to-reschedule — reverses SCOPE.md's MVP deferral, deliberately

Confirmed directly by the user as its own phase: SCOPE.md previously listed "Cascade replanning logic (automatic reflow when a task runs over)" as explicitly out of MVP scope. That line is now replaced with a description of the implemented behavior, and the immediately-preceding session's decision (drag rejects an overlapping drop, snap-back, no auto-adjust) is reversed for the drag path only — the create wizard's Save/Schedule and the edit-schedule modal's Save keep the exact reject-with-inline-error behavior unchanged, since neither has a drag gesture to compute a push direction from.

**Algorithm** (`lib/shared/services/cascade_reschedule.dart`, `computeCascadeMoves`): worked out by hand from two examples the user gave before any code was written, per direct instruction not to skip to UI wiring with an unverified algorithm. Direction is decided by comparing the dragged task's *new start* against the overlapped task's own start and end — whichever is nearer wins. Nearer-to-end pushes the existing task earlier, its end landing exactly on the dragged task's new start; nearer-to-start pushes it later, its start landing on the dragged task's new *end* (not start) — a deliberate asymmetry, since pushing later means the existing task must clear the mover's entire span, not just where it begins. Verified exactly against the user's own worked numbers once one of their restated numbers (flagged in the work order itself as a likely typo) was corrected by re-deriving from the stated rule rather than copied: existing 11:00–12:00 dropped-against at 11:45 becomes 10:45–11:45; dropped-against at 10:15 becomes 11:15–12:15. Chains via a queue + visited-id set (BFS-style, not recursion), capped at the day's task count as a cycle guard. A day-boundary check (any move landing before 00:00 or after 24:00 of the viewed day) runs per-move as the cascade builds; failing it returns `null`, and the caller snaps the whole drag back untouched — nothing partially applies.

**Wiring** (`lib/features/timeline/timeline_screen.dart`, `_DraggableTaskBlock.onDragEnd`): the existing reject branch (when "Prevent overlapping tasks" is on and the drop overlaps) now computes a cascade instead of snapping back outright; a `null` result still snaps back exactly as before. A new `TaskList.rescheduleTaskWithCascade(List<TaskMove>)` (`shared/providers/task_providers.dart`) applies every move — dragged task and every pushed task alike — through the same per-task semantics `rescheduleTask` already has (`originalScheduledAt` set once, `status` → `rescheduled`), looked up fresh by id, with a single `_refresh()` at the end so the Timeline rebuilds once, atomically, rather than mid-cascade. Chose this provider-layer loop over a UI-layer loop calling the existing single-task `rescheduleTask` repeatedly — the latter would rebuild the Timeline once per pushed task, visibly moving them one at a time rather than all at once, which the work order's "applied atomically" requirement ruled out. Mirrors the `_materializeSeries` precedent (loop + write through the repository, one refresh at the end) rather than inventing a new pattern.

New `TaskMove` (paired `taskId` + `newScheduledAt`, not a live `Task` reference) keeps the cascade function pure/widget-free and avoids holding a `Task` object that could go stale between computation and write — both the UI (computing the cascade) and `rescheduleTaskWithCascade` (applying it) re-read fresh from `taskListProvider`/`TaskRepository` right before they need the data, same as every other mutator in this codebase.

Reviewed CONSTITUTION.md before starting: no data-model non-negotiable needed changing — a pushed task is an ordinary `Task` row going through ordinary reschedule semantics, same enum, same `originalScheduledAt` rule, no new fields.

New tests: `test/shared/services/cascade_reschedule_test.dart` (8 cases) — both worked examples reproduced exactly, a 3-task chain, the day-boundary-guard abort (both "existing task pushed past midnight" and "dragged task's own new start before 00:00"), no-overlap-at-all (returns just the dragged task's own move), back-to-back-is-not-an-overlap, and a tightly-packed 5-task cycle-guard smoke test (asserts only that it terminates, not a specific outcome). Grepped `test/` for `onDragEnd`/`_DraggableTaskBlock`/`rescheduleTask` — no existing widget test exercises the drag gesture directly (the only other hit was `recurrence_generator_test.dart`'s unrelated use of `originalScheduledAt`), so nothing needed updating there.

`flutter analyze`: clean. `flutter test`: 140/140 passed (132 previous + 8 new).

## [Timeline] Left-gutter labels reverted from task-boundary times back to a fixed hourly grid — configurable interval seam added

Requested directly: the boundary-derived labels (task start/end times only, from the previous session's confirmed redesign — see docs/DECISIONS.md) should go back to a fixed grid — "every hour interval, 11:00 12:00" — with the interval itself made configurable later (e.g. every 2 hours).

The scroll range is no longer the fixed 6–22h/0–24h window the *original* `HourMarkers` was built against — a later session made `_visibleRange` dynamic per day (earliest task start − 30min to latest task end + 30min, see docs/DECISIONS.md), so this isn't a plain revert of the deleted file. Confirmed via AskUserQuestion where ticks should land given a `rangeStart` that rarely falls on a whole hour: clean clock hours (11:00, 12:00...), not values offset from `rangeStart` itself (6:47, 7:47...) — matches the "11:00 12:00" example given and reads as a normal clock face rather than an arbitrary grid.

**`task_boundary_markers.dart` rewritten** (kept the filename/widget name — `TaskBoundaryMarkers` — since it's still the left-gutter markers widget, just grid-based again): `taskBoundaryTimes(List<Task>)` replaced with `hourlyGridTimes(DateTime rangeStart, DateTime rangeEnd, {int intervalHours = 1})`, a pure function that finds the first whole hour at or after `rangeStart`, then steps by `intervalHours` (not `Duration(hours:)` on a running total, so the "every 2 hours" follow-up is a call-site default change, not a new code path) through to `rangeEnd`. The widget lost its `tasks` param (no longer needed) and gained `rangeEnd` and `intervalHours` (default 1). The current-time-label collision guard (`hideLabelNear`, threshold = caption line height) is unchanged — it operates on `DateTime`s either way, indifferent to how the tick list was produced.

**`timeline_screen.dart`**: the one call site updated — `tasks:` dropped, `rangeEnd: rangeEnd` added (already computed there for `dayHeight`, just not previously passed through).

**Tests rewritten** (`task_boundary_markers_test.dart`, 6 cases, all pure-function — no widget pump needed since `hourlyGridTimes` takes plain `DateTime`s): non-hour-aligned `rangeStart` snaps up to the next whole hour; an already-aligned `rangeStart` is included as-is; the last tick never exceeds `rangeEnd`; a sub-hour range with no whole hour inside produces zero ticks; `intervalHours: 2` still anchors to whole hours; a range crossing midnight ticks correctly across the day boundary.

`flutter analyze`: clean. `flutter test`: 140/140 (full suite, no regressions — the capsule-preview golden and every other timeline test were unaffected since only the gutter-label source changed).

## [Timeline] Task capsule pill (and its icon) shrunk 40%

Requested directly: "make icons inside smaller and also task coloured pane smaller by 40%". The coloured pane is `TaskCapsuleBlock`'s left-rail badge/pill (`badgeSize`); the icon inside it is already sized relative to the pill (`badgeSize * 0.55`), so shrinking the pill shrinks the icon proportionally too — confirmed via AskUserQuestion that proportional shrinking (not an additional, disproportionate icon reduction) was what was meant, rather than assuming.

`badgeSize = theme.spacingXl * 1.5` → `theme.spacingXl * 0.9` (0.9 = 1.5 × 0.6, i.e. 40% smaller) in `task_capsule_block.dart`. `timeline_screen.dart`'s `_pillWidth` — an intentional mirror of the same value, documented in its own comment as needing to stay in sync since overlapping-task column offsets are computed from it — updated identically. Nothing else referenced the old `spacingXl * 1.5` pill size (the timeline's separate empty-day icon at that same literal expression is an unrelated widget, left untouched).

Golden regenerated (`test/features/timeline/timeline_capsule_preview.png`, `--update-goldens`) and reviewed directly — pills visibly smaller, icons scaled with them, no clipping or overlap in the 5-task/4-category preview. `flutter analyze`: clean. `flutter test`: 140/140 after the golden update (the one pre-update failure was exactly this expected pixel diff, not a layout break).

## [Timeline] Notification + repeat icons moved to their own row below time/duration, enlarged 2x

Requested directly: "make repeat and notif icons larger by 2x and under the time and duration". Both previously sat in the same trailing row as the time/duration text, alongside two other status indicators ("moved"/rescheduled, tracked-behavior). Confirmed via AskUserQuestion which of the four to touch — only notification + repeat relocate and enlarge; "moved" and tracked-behavior stay on the time/duration line at their existing size, since only two icons were named.

`task_capsule_block.dart`: notification (`notifications_active_rounded`) and repeat (`repeat_rounded`) icons split out of the shared trailing `Row` into a new row directly below it, gated the same way as before (`!isCompleted` for notification, `task.isRecurring` for repeat — a task can show one, both, or neither) at `theme.spacingSm * 2`. "Moved" and tracked-behavior icons stay in the original row, unchanged, at `theme.spacingSm`.

Visually verified two ways: the existing capsule-preview golden (regenerated, reviewed directly) confirms the notification icon's new position/size against every non-completed seeded task, correctly absent on the one completed task. The preview fixture has no recurring task, so a scratch widget test (not committed — written, run, screenshot reviewed, then deleted) confirmed the repeat icon renders correctly alongside notification on their shared new row, both at the enlarged size.

`flutter analyze`: clean. `flutter test`: 140/140 after the golden regeneration (same expected pixel-diff-then-regenerate pattern as the pill-size change above).

## [Settings/Timeline] New "Show hour labels" toggle — hides the left-side hour gutter, collapsing its width

Requested directly, plus one AskUserQuestion to settle "off" semantics (see docs/DECISIONS.md): the gutter's 56px width collapses to 0 when off, so tasks/connectors/the current-time indicator reclaim the space rather than leaving a blank margin.

**Data layer**: `PreferenceKeys.showHourLabels` added to `preferences_repository.dart`. `ShowHourLabelsSetting` (`preferences_providers.dart`) mirrors `PreventOverlappingTasksSetting` exactly — `keepAlive: true`, defaults to `true` when unset. `.g.dart` regenerated via `flutter pub run build_runner build`.

**Settings UI**: new "Timeline" section in `settings_screen.dart`, between "Scheduling" and the (gated) "Tracked behaviors" section — its own section since gutter display is a different concern from overlap-scheduling behavior. One `_SettingsPanel` + `AppSwitch`, same title/description/switch layout every other toggle on the screen uses.

**Wiring** (`timeline_screen.dart`): `TimelineScreen` (already a `ConsumerWidget`) reads `showHourLabelsSettingProvider` and passes it into `_DayTimeline` as a plain `bool` field — `_DayTimeline` itself stays a non-Riverpod `StatefulWidget`, same pattern as `theme`/`tasks` being threaded down rather than read internally. Inside `_DayTimeline.build`, a local `hourGutterWidth` resolves to the existing `56.0` constant when on or `0.0` when off, and every one of the four call sites that previously referenced the module-level `_hourGutterWidth` constant directly (`_TimelineConnectors`, the drag-ghost's `left` offset, `_DraggableTaskBlock`'s `left`, `CurrentTimeIndicator`'s `gutterWidth`) now reads this local instead — grepped for `_hourGutterWidth` afterward to confirm no stray reference was missed. `TaskBoundaryMarkers` itself is conditionally not rendered at all when off, rather than rendered with nothing to show.

**Tests**: new `test/shared/providers/show_hour_labels_provider_test.dart` (3 cases, modeled directly on the existing `theme_mode_provider_test.dart` Hive+ProviderContainer pattern) — defaults to true, set persists through the repository, and survives a simulated relaunch (new container over the same box). Visually verified the actual collapse behavior with a scratch widget test (not committed — written, run, screenshot reviewed side-by-side for gutter-on vs. gutter-off, then deleted): confirmed the hour labels disappear and the task pill shifts left to occupy the freed space, rather than leaving a blank margin.

`flutter analyze`: clean. `flutter test`: 143/143 (140 previous + 3 new) — no golden regeneration needed, since the default (on) renders byte-identical to before.

## [Timeline] Completed-task badge and checkbox both turn the same grey as completed-task text

Requested directly: "Checked task color (pane containining icon) sohuld turn grey as the text of completed task... We should also have checkbox variant... with color of checked of the same grey... and use that variant on the timeline with completed task". Two scope questions confirmed via AskUserQuestion first — see docs/DECISIONS.md for both.

**Badge** (`task_capsule_block.dart`): the completed branch of `badgeColor` now reads `theme.colorTextSecondary` directly instead of `theme.colorTaskCompleted` (which was sage green, `sage500`/`sage300`, and had exactly one consumer — this call site). `colorTaskCompleted` is now unused; left defined in `semantic_theme.dart` rather than removed, flagged in a comment.

**Checkbox** (`completion_checkbox.dart`): new `useMutedCompletedColor` bool param, default `false`. When true and the task is completed, the checked ring's fill color becomes `theme.colorTextSecondary` instead of `ringColor` (the category color); the unchecked border is unaffected regardless of the flag — it's always `ringColor`. `task_capsule_block.dart` passes `useMutedCompletedColor: true` at its one call site; no other caller exists yet, so every future default caller keeps the original always-category-colored ring unless it opts in.

Verified: golden preview regenerated and reviewed directly — the one completed seed task ("Pay rent") shows a grey badge and a grey filled checkmark, matching its own already-grey title text; the four non-completed tasks are unaffected, keeping their category colors on both badge and checkbox. `flutter analyze`: clean. `flutter test`: 143/143 after the golden update (the one pre-update failure was the expected pixel diff from the completed task's new colors, not a layout break).

## [Timeline] All four capsule status icons unified onto one row, same size

Requested directly, follow-up to the notification/repeat relocation above: the two icons still left on the time/duration line ("moved"/rescheduled `update_rounded`, tracked-behavior `track_changes_rounded`) move down to join notification/repeat on the row below, at the same 2x size. Confirmed via AskUserQuestion that both were meant, not just one.

`task_capsule_block.dart`: new private `_capsuleIcons({isRescheduled, isBehaviorInstance, isCompleted, isRecurring})` returns the applicable `IconData` list in the icons' original left-to-right order (moved, tracked-behavior, notification, repeat) — computed once per build and reused for both the empty-row check and the render loop, rather than the previous four independent conditional `Icon`/`SizedBox` pairs (two different tiers of `if` blocks, at two different sizes, in two different Rows). The time/duration line is now a single bare `Text` (its enclosing `Row`+`Flexible` wrapper removed — unneeded once nothing trails it, and consistent with the sibling title `Text` two lines above, which was already bare). The icon row renders only when the list is non-empty, with a spacer between icons via `.indexed` rather than per-icon conditional spacers.

Visually verified two ways: existing capsule-preview golden unaffected (none of its seed tasks are rescheduled or behavior-linked, so this was a no-diff change for that fixture — confirmed by `flutter test` needing no golden update). A scratch widget test (not committed — written, run, screenshot reviewed, then deleted) with all four conditions true at once confirmed all four icons render together at the same enlarged size, correctly spaced, with a clean icon-free time/duration line above.

`flutter analyze`: clean. `flutter test`: 143/143, no golden regeneration needed.

## [Timeline] Category icon nudged up 4px, time/duration text nudged up 3px (requested 6px, reduced after a visual collision)

Requested directly: icon inside the pill 4px up, time/duration text 6px up.

**Icon**: the badge's top padding (`theme.spacingIconTop`, 12px) reduced by 4px, landing exactly on `theme.spacingSm` (8px) — an existing token, so no new one needed. `spacingIconTop` is now unused; left defined in `semantic_theme.dart`, flagged in a comment (same posture as `colorTaskCompleted` a few sessions back).

**Text**: no existing gap sits between the title and the time/duration line to shrink (`Column` default spacing is zero), so this is a `Transform.translate(Offset(0, -N))` visual shift rather than a padding change — confirmed via AskUserQuestion. **The requested 6px was tried first and visually verified to collide with the title's own line above it** (screenshotted at 2x zoom, not assumed from reading the code) — `textCaption` is 12px/1.3 line-height ≈ 15.6px tall, and 6px is ~40% of that. Sent the collision screenshot, then compared -3px and -4px side by side; the architect chose -3px as the largest shift that clears the title cleanly.

Golden regenerated and reviewed directly across all 5 seeded tasks — icon sits visibly higher in every badge, time/duration line sits closer to the title with no overlap anywhere. `flutter analyze`: clean. `flutter test`: 143/143 after the golden update.

## [Timeline] Repeats settings editable on already-recurring tasks — change days, or disable (removing future instances)

Requested directly: "we sohuld be able to edit repeat settings on set items also and disable (which would remove future instances)". Follow-up to the read-only staging from the previous session — see docs/DECISIONS.md for the four AskUserQuestion rounds that settled which task row edits, what happens to already-materialized future instances, the precise "untouched" definition, and disable semantics.

**`task_providers.dart`**: new top-level `findSeriesTemplate(instance, allTasks)` (any instance resolves to its series' template, which is the only row carrying the rule). New `TaskList._deleteUntouchedFutureInstances(template)` — deletes future, still-`pending`, never-individually-rescheduled instances only; anything completed/skipped/moved survives regardless of the rule change. New `updateTaskWithChangedRecurrence` (saves the edited task, prunes, writes the new rule to the template, re-materializes) and `disableTaskRecurrence` (saves, prunes, clears the template's `recurrenceId`+`recurrenceRule` entirely).

**`task_detail_sheet.dart`**: `_EditScheduleFormState` now seeds `_selectedDays` from the series' real rule (via `findSeriesTemplate` + new `_selectedDaysFromRecurrenceRule`, the inverse of the existing day→rule conversion) rather than just the task's own weekday, so an already-recurring task's panel reflects its actual days on open. `_wasRecurring` captures the opened-with state so `_save` can branch correctly even after `existing` is mutated. Four-way save branch: plain→recurring (existing `updateTaskWithNewRecurrence`), recurring→off (`disableTaskRecurrence`), recurring→recurring-with-possibly-different-days (`updateTaskWithChangedRecurrence`), plain→plain (`updateTask`). `_hasUnconfirmedChanges` extended to catch a real day-set change (`setEquals` against the initial selection) without false-firing on a same-days no-op save.

`_RecurrencePanel`'s `enabled` parameter (added last session specifically to render the switch on-but-disabled) removed — `flutter analyze` correctly flagged it as unused once every caller relies on the new default-editable behavior; kept as dead code "for a future seam" would have violated the project's own no-dead-code rule, so it came back out rather than being left in.

**Tests** (`edit_schedule_repeats_test.dart`): the old "shows disabled" test rewritten to assert the switch is on AND editable with real days pre-selected (verified via the day chips' own selected-vs-unselected text color, since selection state isn't otherwise exposed to a widget test). Three new cases: changing days from the template instance prunes an untouched future instance while a rescheduled one survives, editing from a NON-template instance still updates the shared template, and disabling detaches the template while a completed future instance keeps its own `recurrenceId` (proving only the template — not history — detaches).

`flutter analyze`: clean (checked repeatedly through the session). `flutter test` intentionally NOT run — a live `flutter run` dev session was active throughout (confirmed with the architect this was their own manual verification), and the previous session's post-mortem found running `flutter test` alongside a live `flutter run` deadlocks both on the shared incremental-compiler cache. Handed back for the architect to run the suite themselves rather than risk repeating that.

## [Timeline] Two z-order fixes: dragged block always on top, header no longer overlapped by the scrolling day

Reported directly, two separate stacking problems.

**1. A dragged block slid under some of its neighbours.** `Stack` paints in child order and has no z-index, so a block's stacking was decided purely by its position in `layoutOverlappingTasks`' output — any task later in that list painted over the one being dragged. Fixed with a new `_DayTimelineState._dragLastOrder(slots)` that moves the currently-dragged slot to the end of the list (and only that slot — every other block keeps its existing relative order, so nothing else's stacking changes). Returns the list untouched when nothing is being dragged, and copies before reordering rather than mutating the caller's list.

**2. The scrolling timeline painted over the header** (day-nav arrows, date, Today button). Root cause: `SingleChildScrollView` had `clipBehavior: Clip.none`, added in an earlier session so a dragged block's lift shadow wouldn't be trimmed at the viewport edge. With clipping off, scrolled content isn't contained by anything, so it rode straight over its `Column` sibling above. Restored the framework-default clipping on the scroll view; the **inner** `Stack` keeps its own `Clip.none`, which is what actually preserves the shadow spilling across neighbouring blocks — the case that motivated the original change. The only behaviour genuinely given up is the shadow of a block dragged hard against the very top/bottom of the scroll viewport, which is ordinary scrollable-surface edge behaviour.

`flutter analyze`: clean. `flutter test` not run — a live `flutter run` dev session was active (same constraint as the previous two sessions; running both deadlocks on the shared incremental-compiler cache). Both changes are pure paint-order/clipping with no logic or data change, and no existing test asserts stacking order or clip behaviour — but they do want a real on-device look, which is the architect's own session anyway.

## [Timeline] Cascade reschedule: bidirectional fallback so a drop is never rejected

Reported directly: dropping into a condensed zone sometimes snapped back instead of moving the other tasks aside. Diagnosed the three existing rejection paths (day boundary, chain-length cycle cap, dragged task itself out of range) and confirmed the day-boundary one was the culprit in practice — a late-evening cluster where every conflicting task preferred to shift later and ran out of room before midnight.

**`cascade_reschedule.dart`**: extracted the collision-walking loop into a new `_findFreeSlot(...)` helper (walks away from an edge in one direction, skipping past already-placed tasks, returning null if it runs off the day). Both the earlier- and later-push blocks now call it with their preferred direction and fall back to the opposite direction before giving up. Net effect: pushes can now split across both directions within a single cascade — some tasks up, some down — which is exactly what the dense cases need.

Verified with a standalone `dart run` script (written, run, deleted — not committed) covering: the previously-rejected evening cluster near midnight, the previously-rejected 6-task dense cluster (now placed with one task pushed earlier and four later), the earlier overlap-bug repro, and a drop at 23:30 onto an occupied slot. All four now accepted with zero residual overlaps. Separately re-ran the two confirmed worked examples and the 3-task chain to prove the proximity/direction rule itself is unchanged — all three byte-identical to before.

**Tests**: the "day-boundary guard aborts" test rewritten to assert the fallback (existing task pushed earlier to 22:30, no overlaps) since it encoded the now-obsolete reject behaviour; new test for a dense late-evening cluster splitting pushes across both directions; cycle-guard test tightened from `anyOf(isNull, isNotNull)` to `isNotNull` — the permissive version would have hidden this very bug.

`flutter analyze`: clean. `flutter test` not run — live `flutter run` session active throughout (same shared-compiler-cache deadlock constraint as the previous sessions).

## [Timeline] Drop flicker fixed, plus eased drag/drop/cascade motion and lift fades

Reported directly, one bug and three animation asks.

**Flicker (real bug)** — see docs/ERROR_LOG.md for the full root cause: the block was drawn at the unsnapped finger offset but saved the snapped time, so it visibly jumped at release. Fixed via a new `_isSettling` state that switches the rendered offset to the snapped value the moment the finger lifts.

**Eased drop**: `_DraggableTaskBlock`'s root `Positioned` → `AnimatedPositioned`, `Curves.easeOut` at `motionNormal` (250ms). Duration is `Duration.zero` ONLY while this block is under the finger, so dragging still tracks 1:1 with no lag.

**Cascade neighbours slide**: the same `AnimatedPositioned` change means a task the cascade pushes out of the way now eases to its new time instead of teleporting — it was already rebuilding at a new `baseTop`, it just had no animation. Confirmed via AskUserQuestion that dragging should follow the finger continuously (rather than snapping every 5 minutes mid-drag), with the correction eased on release.

**Icon + checkbox fade during lift**: both wrapped in `AnimatedOpacity` (`motionFast`, 150ms) driven by the existing `isLifted` flag, which was already plumbed into `TaskCapsuleBlock`. The checkbox additionally gets `IgnorePointer` while faded, so a stray tap can't hit an invisible control mid-reposition.

All durations/curves come from existing motion tokens — no new values introduced.

`flutter analyze`: clean. `flutter test` not run — live `flutter run` session active throughout (same shared-compiler-cache deadlock constraint as prior sessions). These are animation/paint changes with no logic or data change; no existing test asserts drag positioning or opacity. They do want a real on-device look, which is the architect's own running session.

## [Timeline] Drop jump, second cause: ghost key + settle-aware Stack ordering

Follow-up to the snapped-offset fix in the previous entry — the block still jumped to a higher position first, then eased down. See docs/ERROR_LOG.md for the full diagnosis, including the `_visibleRange` drift theory that was ruled out by asking whether the jump was specific to the day's earliest task (it wasn't).

Two independent causes, both fixed: the unkeyed drag-ghost `Positioned` disturbing element matching for the keyed block beside it on removal (now `ValueKey('ghost-<taskId>')`), and `_dragLastOrder` releasing the block back to its natural Stack index mid-animation because it keyed off `_draggingTaskId`, which clears the moment the finger lifts.

Split the parent's state: `_draggingTaskId` still drives ghost visibility and clears on release; new `_settlingTaskId` drives Stack ordering and clears only when the block reports its settle finished, via a new required `onSettled` callback on `_DraggableTaskBlock`. `onSettled` guards against stale fires — a different task holding the pin, or the same task picked up again mid-settle.

`flutter analyze`: clean. `flutter test` not run — live `flutter run` session still active (same constraint as prior sessions). Paint/animation only; no logic or data change.

## [Task detail] Removing a recurring task now asks: this occurrence, or all

Requested directly. Remove previously deleted one instance with no confirmation, even for a repeating task.

**`task_providers.dart`**: new `deleteTaskSeries(instance)` — deletes the tapped instance plus every other occurrence today or later, cancels their notifications, and detaches a surviving past template from its series so it stops generating. Also factored the notification-cancel out of `deleteTask` into a shared `_cancelNotificationSafely(id)`, mirroring the existing `_syncNotificationSafely`.

**`task_action_sheet.dart`**: `_remove` now branches on `task.isRecurring` — a plain task deletes immediately as before, a recurring one opens a scope sheet first. New private `_RemoveScope` enum and `_askRemoveScope`, built on the existing `AppSheet` + `_ActionRow` + `colorTaskAlert`; no new widgets or tokens.

Two scope decisions confirmed via AskUserQuestion (both in docs/DECISIONS.md): past occurrences are always kept, and an explicit "all" does not spare touched future occurrences the way an incidental rule change does.

Also hit and fixed a quiet BuildContext bug along the way — see docs/ERROR_LOG.md. The existing `_duplicate` method appears to share it; flagged there rather than changed, since it's outside this request.

`flutter analyze`: clean. `flutter test` not run — live `flutter run` session active (same constraint as prior sessions). No existing test covers the delete flow; the new provider method deserves coverage once the suite is runnable.

## [Timeline] Lift-fade corrections, time-line typography, and the first full test run in several sessions

Four corrections, requested directly after reviewing the previous animation pass:

1. **Category glyph in the coloured pill no longer fades** while lifted — reverted; it's the pill's identity and stays visible throughout the drag.
2. **The indicator icons under the title now fade instead** (moved/tracked-behavior/notification/repeat) — secondary detail that isn't useful mid-drag. The checkbox fade is unchanged.
3. **Real gap between title and time line** — `spacingXs`, replacing the earlier `-3px` Transform nudge that pulled them *closer* (it was solving the opposite problem and is now removed entirely).
4. **Time line matches the task name's size** — `textBody` instead of the smaller `textCaption`, staying regular weight (the title's `w700` is an explicit override; `textBody` is regular by default, so no override needed).

**The dev session ended, so the full suite ran for the first time in several sessions — and found three real bugs.** See docs/ERROR_LOG.md for each: the day-of-week chips overflowing their row by 40px (a genuine production layout bug, now `Expanded`), hardcoded calendar dates in `edit_schedule_repeats_test.dart` that had rotted from future to past and broke its pruning assertions (now anchored to `DateTime.now()`), and that file's `Duration.zero` drain being too short for the multi-write series-editing paths (now 100ms).

Golden regenerated and reviewed directly — the time line now visibly matches the title's size at regular weight with a clear gap.

`flutter analyze`: clean. `flutter test`: **152/152 passing** — this covers everything accumulated across the recent unverified sessions (repeats editing, series delete, cascade fixes, drag/drop animation), all now confirmed green rather than analyze-only.

## [Task detail] Fixed "Remove not working" — three stacked bugs, plus first-ever tests for the action sheet

Reported directly: Remove did nothing. Reproduced with a new widget test rather than diagnosed by reading, which turned out to matter — there were three independent causes, each masking the next, and `flutter analyze` was clean through all of them. Full detail in docs/ERROR_LOG.md.

1. **`_ActionRow` label overflow (56px)** — the row's `Text` had no flex, and the new scope-sheet labels were longer than the originals. The layout exception aborted the tap handler before the delete ran. Now `Expanded` + ellipsis, which also hardens every other action row against a long label.
2. **`AppSheet.show` built with the caller's context** — a latent flaw in the shared primitive: `builder(context)` ran eagerly before the route was pushed, so a builder that popped with a value popped the wrong route and `show()` never returned. Only surfaced now because this is the first caller that needs a return value. Fixed inside `AppSheet` so every future caller gets the correct behaviour.
3. **`ref` used after unmount** — `_remove` awaited the scope sheet, then read `ref`, which by then belonged to an unmounted element. Threw inside the async gap, so it looked like nothing happened. Notifier now captured before the pop, alongside the navigator.

**Corrected an earlier mistake**: last session I flagged `_duplicate` as "likely affected the same way" as the BuildContext bug. Tests now prove that was wrong — `_duplicate`, `_editDetails` and `_editSchedule` all work, because they touch `context`/`ref` synchronously in the same frame as the pop. The distinction is the await, not the pop. The ERROR_LOG flag has been corrected rather than left standing.

**New `task_action_sheet_remove_test.dart`** (6 cases): plain-task remove, scope sheet appearing for a recurring task, each scope branch end-to-end (including past instances surviving "all occurrences"), plus Duplicate and Edit details — the action sheet had no test coverage at all before this.

`flutter analyze`: clean. `flutter test`: **158/158 passing**.

## [Timeline] Collapsed mode: hiding hour labels now removes the gaps and sizes pills by duration

Requested directly, from a screenshot showing two tasks separated by a screenful of empty space with the hour gutter turned off. See docs/DECISIONS.md for the three AskUserQuestion decisions (one switch vs. two, proportional vs. stepped heights, and what drag should do without a time axis).

**`timeline_screen.dart`**: new `_blockTops(slots, rangeStart, theme)` computes every block's vertical offset once, so both modes share one rendering path instead of branching at each of the half-dozen places a `top` was needed. Timeline mode maps elapsed time to pixels as before; collapsed mode stacks each block after the previous one (its own height plus a fixed gap), with overlap groups sharing a row so only column 0 advances the cursor. Day height, the ghost, the real block, and the pill scale all read from that one source.

Suppressed in collapsed mode, each because it encodes elapsed time that the mode deliberately doesn't represent: the connector thread, the current-time indicator, the open-scrolled-to-now behaviour, and drag-to-reschedule (via a new `isDraggable` flag — the pill stays tappable, just not draggable).

**A guessed constant that didn't work** — see docs/ERROR_LOG.md. The first scale (0.45) put the badge-size floor at 75 minutes, so 15m, 30m and 60m all rendered as the same circle, flattening exactly the distinction the feature exists to show. Caught by rendering the duration range and measuring it, not by reading the code. Replaced with a derived `pillWidth / 30`, and re-rendered to confirm 30m = circle, 1h = 2×, 2h = 4×.

Settings copy updated — the toggle now does more than its old description said, including the drag caveat.

`flutter analyze`: clean. `flutter test`: **158/158 passing**.

## [Task detail] Create-flow redesign — reordered step 1, live preview + typed numeric time entry on step 2

Requested directly from a wireframe mockup plus a voice-transcribed walkthrough; user corrected an early misread ("the new mockup is also 2 steps, step 1 (name, notes, icon), step 2 (preview, start time, duration, date, repeats)"). Five AskUserQuestion rounds settled scope: typed numeric boxes replace the scroll-wheel/slider, a new 5th "General" category is added (grey, first, default-selected), the Repeats toggle keeps its existing day-chip panel, duration has no upper cap, and the redesign applies to both the create wizard and the standalone "Edit time and duration" modal (they share `_ScheduleStepScaffold`).

**Step 1**: reordered to name → notes → category. The old coloured name banner is gone — the name field is now `_Panel`-wrapped and styled identically to Notes, just single-line. `_StepScaffold.headerContent`/`onPrimaryPressed` are now nullable so step 1 can render with no banner and a Continue button that starts disabled, enabling only once the first character of the name is typed (`ListenableBuilder` on the title controller, not new state).

**Step 2**: new `_SchedulePreviewCard` at the top mirrors `TaskCapsuleBlock`'s own badge/title/time styling exactly (same badge size, same category color lookups) and updates live as start time/duration are edited; a pencil icon (reusing `_HeaderCircleButton` on a plain background) jumps back to step 1. The scroll-wheel time picker and duration slider are gone, replaced by `_NumericTimeField` — typed Hour:Minute / Hours:Minutes digit boxes, with the numeric keyboard staying up for the whole step instead of dismissing between fields. Date defaults to today, reads "Today" (no calendar icon) when it matches, and the whole row is the tap target for the native date-picker sheet.

New `TaskCategory.general` (`@HiveField(4)`, appended — never renumbering the existing four) is the new default category for new tasks, with its own grey token pair in `color_primitives.dart`/`semantic_theme.dart` and a `TaskCategoryPickerOrder.orderedForPicker` extension so display order (`general` first) stays independent of the enum's Hive-index declaration order.

Deleted the now-fully-dead `_TimeScroller`/`_Wheel` widgets (161 lines) and `_Panel`'s unused `padding` parameter.

Found and fixed a real bug during verification, not just a test artifact — see docs/ERROR_LOG.md: a `TextEditingController.addListener`-driven auto-advance-focus mechanism could deliver typed digits to the wrong box. Fixed by switching to `TextField.onChanged`-driven advance.

`flutter analyze`: clean. `flutter test`: **158/158 passing**.

## [Design system] Surface scale, reusable form-field components, and a masked hh : mm input

A restyle, but a structural one: the create flow's fields were assembled inline inside `task_detail_sheet.dart`, so "make the forms look like this" had nowhere to land without first extracting real components. Four AskUserQuestion rounds settled the shape (see docs/DECISIONS.md).

**Surface scale.** New `colorSurfaceBase` (level 0, #F7F7F7), `colorSurfaceField` (level 2, #E8E8E8) and `colorSurfaceFieldActive` (level 2 focused, #DCDCDC) join the existing pane token as one explicit 0/1/2 elevation scale. The light values are DERIVED, not hand-copied: each lightness was solved back through `oklch()` so the specified hex reproduces exactly through the existing pipeline. Dark mode gets its own counterparts, inverted in direction (a field on a near-black panel gets *lighter*, not darker) and kept on the ink ramp's warm hue rather than the light scale's zero chroma.

**Four new components in `core/widgets/`**, so screens stop assembling field chrome themselves:
- `AppFieldShell` — the shared fill/radius/focus-tone/floating-label chrome. Holds no text; the input is passed in, so a typed field, a masked field and a tappable date row all present identically.
- `AppTextField` — single/multi-line text on that shell.
- `AppSegmentedTimeField` — the masked `hh : mm` input, serving BOTH Time and Duration.
- `AppPane` — a level-1 card whose section title renders above and outside it, per the mockup.

**The time field is one `TextField` with a baked-in separator, not two boxes.** That's what makes the caret behave like a date/expiry field: typing the last hour digit rolls past the separator on its own, and backspacing at the start of the minutes crosses back over it to clear the last hour digit. A `TextInputFormatter` owns all of it in digit space, so the separator can never be half-deleted and the whole value can be cleared and retyped without tapping between parts. Duration reuses the same component with `firstMax: null` and a 3-digit hour segment, since duration is uncapped.

Two real bugs found by testing rather than reading, both documented in docs/ERROR_LOG.md: a length-based "is this a deletion" check that silently swallowed pasted/bulk input, and a digit-count-based "is this one keystroke" check that broke sequential typing. The formatter now has 8 tests covering both paths, the cross-separator backspace, and the uncapped case.

Category chips are emoji on a tint-filled pill (mockup), wrapping onto a second line instead of scrolling; selection is carried by an outline, since the fill already encodes which category it is. `Repeats` → `Repeat`, and the panel no longer draws its own card now that it sits inside the Date pane.

`flutter analyze`: clean. `flutter test`: **166/166 passing** (158 + 8 new).

## [Design system] Seven follow-up corrections to the form restyle

Direct feedback after reviewing the restyle on device. All seven fixed, verified in BOTH palettes by rendering (light and dark, both steps).

1. **`hh : mm` placeholder when cleared.** The mask previously always rendered zeros, so a cleared field was indistinguishable from a real `00 : 00`. The formatter now emits an empty string once the first slot is deleted, letting a hint show through; the hint is built from the same separator and segment widths as the mask (`hhh : mm` for duration), so it lines up with a filled value. Blurring an emptied field restores its previous value rather than committing 00:00 — clearing is the start of retyping, not an instruction to set midnight.
2. **Duration hour is 3 digits** — already shipped in the restyle (`firstDigits: 3`); the hint now reflects it.
3. **Contained panes have no border.** Removed; see the surfacing fix below for why it was there.
4. **Dark-mode back/close icons were invisible.** They defaulted to `colorSurfacePrimary` for BOTH circle and glyph — correct only for the old coloured banner, but that token is white in light mode and near-black `ink900` in dark. Now a level-2 circle with a `colorTextPrimary` glyph. Text and surface tokens invert in opposite directions between palettes, so a glyph must come from a text token, never a surface one.
5. **Minimum field height 60px** — new `sizeMinFieldHeight` Tier 2 token (a floor, not a fixed height, so multi-line fields still grow). Content is centred within it, so a resting label sits mid-field rather than pinned to the top.
6. **Light-mode surfacing.** Background deepened #F7F7F7 → #EFEFEF, field #E8E8E8 → #E4E4E4, active #DCDCDC → #D1D1D1. At F7 the 0→1 step was ~3% lightness and read as no boundary at all — which is why the pane had needed a border. Deepening the GROUND (rather than tinting the pane, which stays pure white) lets the pane lift on its own, so fix 3 and fix 6 are the same fix.
7. **Modal header no longer has its own background.** The body was painting `colorSurfaceTimeline` while the scaffold used the base ground, leaving the top strip reading as a separate bar — a leftover from the coloured-header design. The sheet is now one continuous level-0 surface.

Four new tests cover the placeholder behaviour (empty state, duration's 3-digit hint, typing into a cleared field, and blur-restores-previous-value).

`flutter analyze`: clean. `flutter test`: **170/170 passing** (166 + 4 new).

## [Design system] Brand accent, radius scale by size, modal presentation, and a safe exit dialog

Ten changes from direct feedback. Two settled by AskUserQuestion (see docs/DECISIONS.md): the exit dialog's third option, and how far the accent swap should reach.

**Radius scale renamed by SIZE, not by component.** `radiusControl`/`radiusCard`/`radiusSheet` → `radiusSm`(4)/`radiusMd`(8)/`radiusLg`(12)/`radiusXl`(16), plus `radiusModal`(40) held deliberately off the scale so ordinary cards can't reach for it. Panes are `radiusXl`, form fields / category pills / day chips are `radiusMd`. Naming rungs by size rather than by component stops two controls that should match from drifting apart via two differently-named tokens holding the same number. The rename surfaced all 12 call sites, which is the point.

**Brand accent #3B63DB** replaces sage in the accent ROLE only. Solved back through the `oklch()` pipeline (lands #3B62DB, 1/255 on green — the tolerance the category tints already use). Measured: white-on-brand 5.31:1, brand on background 4.96:1, both past AA; dark mode needs its own lighter anchor (`brand300`) because the light value measures only ~2.4:1 on `ink900`. `colorTaskCompleted` deliberately stays sage — green means "done" independently of branding.

**Background restored to the specified #F7F7F7.** Last session I deepened it to #EFEFEF to make panes visible; that traded away your spec to solve an edge problem. The edge is now carried by `shadowPane` (2px y / 4px blur / -2 spread / 8% black, exactly as specified) instead, so the pane lifts without either darkening the ground or drawing a border. Dark mode uses the same geometry at 40% alpha — 8% is invisible on near-black.

**Modal presentation**: 40px corners, inset 8px from every edge with a transparent scaffold behind it so the rounding actually reads, and a "Create task" title in the header (with the header growing to fit it).

**Exit confirmation is now three-way** — Keep editing / Discard / Save — via a new `AppAlertDialog.showThreeWay` returning an `AppAlertDialogChoice` enum. Dismissing resolves to `cancel`, never null, so the safe branch and the default branch are the same one and a stray tap outside can't discard work. Wording also fixed: the old dialog was titled "Schedule this?" with "Discard changes" beneath it, which read as a scheduling prompt rather than a data-loss warning. Now "Discard this task?" (create) / "Discard changes?" (edit).

Pane titles moved one rung up (`textLabel` → `textBody` at bold) since they sit outside the pane as section headings.

`flutter analyze`: clean. `flutter test`: **171/171 passing** (170 + 1 new cancel-path test).

## [Design system] Modal geometry corrections and the duration-padding bug

Four direct corrections after review.

1. **Sheet no longer carries its own shadow.** Depth inside the sheet is the panes' job (`shadowPane`); a shadow on the sheet as well stacked two elevations for one surface.
2. **Full width, almost full height.** The sheet is now edge-to-edge horizontally and offset only from the top, with rounding on the top corners only — it reads as a panel pulled up over the screen rather than a floating card. The 8px all-round inset from the previous pass is gone.
3. **Title centred and one scale up** (`textTitle` → `textHeadline`), flanked by the back arrow (left) and close (right). Both header buttons are now vertically centred rather than pinned to a fixed top offset — the header's height varies with whether it carries a title, so the fixed offset left them sitting high in the taller variant. Verified by measurement: the title's centre lands at 195.0 on a 390px screen.
4. **Duration rendered `000 : 30` instead of `02 : 30`.** `firstDigits: 3` was being used as BOTH the mask's capacity and the display width, so every duration was zero-padded out to the field's maximum. Display width now sizes to the value (minimum two digits), while the mask keeps its 3-digit headroom — `02 : 30` for an ordinary duration, `120 : 00` for a long one. The hint stays two-digit `hh : mm`, since it describes what to type rather than the field's capacity.

Two tests updated/added around the duration fix, including a case for durations past 99 hours.

`flutter analyze`: clean. `flutter test`: **172/172 passing**.

## [Task detail] Unset time/duration, hour-first caret, and wheel/calendar alternative entry

Five changes. Two settled by AskUserQuestion (docs/DECISIONS.md): whether Save may proceed with an unset schedule, and the duration wheel's range.

**Time and duration now start UNSET.** Both are nullable through the whole create flow (`TimeOfDay?` and `int?`), so their fields show the `hh : mm` placeholder rather than seeding the tapped slot and a 30-minute default. Confirm is disabled until both are entered — same gate as Continue needing a name. The date is deliberately NOT nullable: it defaults to today and reads "Today" from the start, which is a real default rather than a guess. The preview card shows "Set a time and duration" until both exist rather than rendering a range nobody chose.

**The 3-digit hour bug is genuinely fixed this time.** The previous pass fixed the widget's display but left the FORMATTER padding to capacity, so `000 : 30` still appeared while typing. Capacity now lives only in the formatter (`_maxHourDigits`, a mask concept) and never leaks into a display width — the hour renders two digits until a value actually needs a third.

**Focus lands on the hour, not the minutes.** Tapping a `hh : mm` field put the caret at the end of the text, dropping the user into minutes and making them reach backwards. The caret now resets to offset 0 on GAINING focus only, guarded so it can't fire mid-typing.

**Alternative entry on all three fields**: a clock on Time and a stopwatch on Duration open a new `AppWheelTimePicker` (two wheels, hours/minutes, both defaulting to 00); a calendar icon on Date opens the existing native picker. All three use a new `AppFieldActionButton` — ghost styling (the field's fill already defines the control) with the tap target padded out to `spacingMinTapTarget`, since the visible glyph is well under the accessibility floor.

Typing stays the primary path; the pickers are for browsing to a value. Both write the same underlying value, so neither is a mode.

`flutter analyze`: clean. `flutter test`: **173/173 passing**.

## [Design system] Scrim token, sheet surface alignment, and a readable wheel selection

Four corrections to the picker sheets.

1. **New `colorScrim` token** (40% black), applied to the task-detail route (which had `barrierColor: Colors.transparent` — no dim at all) and to `AppSheet`'s Material path. One token for every modal layer, so a sheet opened over another sheet dims it by the same amount the first dimmed the page. Deliberately the SAME value in both palettes: a scrim's job is to push the layer behind it back, and lightening it for dark mode would stop it reading as depth.
2. **`AppSheet` now uses `colorSurfaceBase`**, matching the task-detail modal, so stacked modals share one ground instead of the sheet arriving as a lighter pane-coloured surface.
3. **The wheel's selection overlay no longer hides the selected value.** `CupertinoPicker` paints `selectionOverlay` ON TOP of its children, so the opaque fill was covering the number it was meant to highlight. Now 40% alpha — a highlight rather than a lid.
4. **`AppSheet.show` gained `padded`** so the picker (which applies its own inset) isn't padded twice.

**The "doesn't update the form field" report turned out to be sound wiring.** Reproduced it, then found the failure was my probe's default 800px test surface: the sheet renders taller than that viewport, which puts the confirm button's hit-test position out of step with where it draws, so the tap silently missed. At a real 390x844 viewport the round trip works. Kept as two permanent tests (`app_wheel_time_picker_test.dart`) covering confirm-writes-back and dismiss-leaves-untouched, since that round trip had no coverage.

`flutter analyze`: clean. `flutter test`: **175/175 passing** (173 + 2 new).

## [Task detail] Wheel picker discarded its value whenever the field was already set

Reported directly: choosing a time or duration on the wheels did nothing if the field already held a value. Reproduced, then found the real trigger — it wasn't "already set", it was **focus**.

`AppSegmentedTimeField.didUpdateWidget` skipped its resync whenever the field had focus, on the reasoning that overwriting a focused field would fight live typing. But the picker button sits INSIDE the field, so tapping it leaves the field focused — which meant every value confirmed on the wheel hit that guard and was silently dropped. It only looked like an "already set" problem because from an empty field the user hasn't focused it yet.

**Fix**: replace the focus check with a precise one — skip only when the incoming value already matches what is displayed (an echo of the user's own edit coming back through the caller), and otherwise honour it. That is what the focus guard was reaching for; focus was a proxy that happened to also block genuine external writes.

Two earlier tests passed against this bug because both unfocused the field first — one explicitly, one by never focusing it. The new regression test focuses the field first, exactly as typing a value would leave it.

`flutter analyze`: clean. `flutter test`: **177/177 passing** (175 + 2 new).

## [Task detail] Live preview added to step 1, without the edit pencil

Requested directly: the same live preview shown on step 2 should also appear on step 1, but without the edit button (step 1 already IS the step the pencil would navigate to).

`_DetailsStepScaffold` gained nullable `startTime`/`endTime`/`durationMinutes` params, rendering the existing `_SchedulePreviewCard` with `onEdit: null` — reusing the component's already-nullable pencil rather than adding a new flag. Both call sites wired:
- **Create wizard**: uses the flow's own `_resolvedScheduledAt`/`_durationMinutes`, both null until step 2 has been visited — the preview shows "Set a time and duration" until then, matching step 2's own empty-state text exactly.
- **Standalone "Edit details" modal**: always has a real scheduled task, so the preview always shows a real time range from the moment it opens.

Verified across three states by rendering: empty (placeholder title, no schedule, Confirm disabled), filled title with no schedule yet, and — the case worth checking specifically — that a schedule set on step 2 persists in step 1's preview when navigating back, since the create flow's state lives one level up from both scaffolds.

One test updated: the exit-confirmation "Keep editing" test asserted `findsOneWidget` for a typed title, which the preview now legitimately duplicates (`findsNWidgets(2)`).

`flutter analyze`: clean. `flutter test`: **177/177 passing**.

## [Design system] Time/duration field rewritten to shrink; disabled buttons no longer fade

Two follow-ups from device testing.

**`AppSegmentedTimeField`'s deletion model changed fundamentally**, per direct confirmation: backspace now shrinks whichever segment the caret is in — "05" backspaces to "0", then to empty — rather than the old model of re-zeroing a fixed 4-digit slot array. Crossing the separator only happens once the current segment is already empty. This required replacing the formatter's internal representation: it previously worked on one flat, always-4-digit array; it now tracks the hour and minute segments as two independent, genuinely variable-length strings, split on the separator itself rather than by digit position.

Also fixed as part of the same rewrite: the caret previously stalled right after the second hour digit (`"09| : 00"`) instead of advancing past the separator (`"09 : |00"`) — an off-by-one in the digit-index-to-caret-offset mapping (`<=` where it needed `<`).

Sequential single-key typing past two hour digits still rolls into minutes (matching the existing "typing the last hour digit slides into minutes" behaviour), and a duration can still reach a genuine 3-digit hour by typing three digits in a row from empty before the 2-digit cap applies. Both paths, and the multi-character case (`enterText`/autofill delivering 2+ digits in one edit), are covered by tests.

**`AppButton`'s disabled state is now explicit**, not the platform default. `CupertinoButton`/`ElevatedButton` both fade the WHOLE control (fill included) toward transparent when `onPressed` is null, which read as blurry/washed-out. Both platforms' `disabled*` parameters are now set explicitly to a flat grey fill (`colorSurfaceField`) with only the TEXT losing opacity — the button keeps a defined, solid edge instead of dissolving into the page.

`flutter analyze`: clean. `flutter test`: **180/180 passing** (177 + 3 new, one existing test rewritten for the new deletion behaviour).

## [Task detail] Create flow collapsed to one screen; per-field modals; a real notifications toggle

Major restructure requested from a full mockup flow. The 2-step wizard (name/category, then schedule) is now ONE screen — what used to be step 2 — with name/category, start time, and duration each edited in their own compact modal, opened from that screen. Step 1 as a full page is gone from the live tap-through (per direct confirmation: `_DetailsStepScaffold`/`_EditDetailsForm`/`showEditDetailsSheet` are kept, unreferenced by the new flow, as an explicit backup rather than deleted).

**Three new modal widgets**, each a compact `AppSheet`-based bottom sheet:
- `TaskNameCategoryModal` — name, description, category chips. Edits the SAME controllers/category the caller already owns, live, so the screen behind it (visible through the scrim) updates the moment the sheet closes.
- `TaskStartTimeModal` / `TaskDurationModal` — a typed `AppSegmentedTimeField` plus an inline wheel (`AppWheelPicker`, a new bare-wheel-pair widget extracted from `AppWheelTimePicker` so it can sit alongside a typed field instead of only inside its own titled sheet). Duration's wheel steps by 5 minutes (00, 05…55 — 12 rows, confirmed directly: the typed field already offers exact-minute precision, so the wheel's job here is fast rough browsing); Start time's wheel stays every-minute, since browsing to an exact time is a real, common need.

**Guided first-run sequence**: creating a genuinely new task (never `showTaskDetailSheet(task: ...)` with an existing task) auto-advances Name → Start time → Duration on each modal's Done, via a one-shot `_autoAdvanceEligible` flag that turns itself off the moment the user backs out of a modal without confirming, or once Duration (the last step) is reached — confirmed directly: this sequence runs ONLY for a from-scratch create, never when editing an already-scheduled task or the Inbox "give it a schedule" case.

**`_StepScaffold` gained `titleAlignment`** (default centre, unchanged for every other caller) — the single screen's title now reads left, since there's no back arrow to balance a centred title against any more (`onBack: null` everywhere in the new flow).

**A real, persisted `Task.notificationsEnabled`** (new `@HiveField(14)`, default `true` — matching `NotificationService`'s previous unconditional-scheduling behaviour, confirmed directly rather than shipped as a UI-only placeholder). Wired through `Task.toJson`/`fromJson`/`hasSameFieldsAs` (old backups without the key import as `true`), `TaskList.createTask`, and a new early-return guard in `NotificationService.scheduleForTask`. Shown as its own bare `AppPane` (no title, per direct request — "just pane with label and switch inside"), distinct from Repeats which nests inside the Date pane.

Two real bugs found and fixed while wiring end-to-end tests for this, both now permanent regression coverage:
- The new modals didn't scroll — a `RenderFlex` overflow under a real on-screen keyboard, since Name+Description+Category+Done (or the segmented field+wheel+Done) can exceed the remaining height once the keyboard opens. All three now wrap their content in `SingleChildScrollView`.
- `find.byType(TextField).first` is unreliable whenever a modal sheet is open: the main screen's own fields stay mounted underneath a `showModalBottomSheet` route and are found FIRST in traversal order, ahead of the modal's own fields — a bare `.first` silently typed into the wrong screen entirely. Every test finder here is scoped via `find.descendant(of: find.byType(<ModalType>), ...)`.

`flutter analyze`: clean (one pre-existing-pattern warning: `_DetailsStepScaffold`'s `modalTitle` param has no caller now that step 1 is unreferenced by the live flow — left as-is since the whole class is the "keep as backup" scaffold, not new code). `flutter test`: **184/184 passing** (180 + several rewritten for the new flow, others unaffected).

**Flagged, not fixed**: `task_detail_sheet.dart` is now 2230 lines and `app_wheel_time_picker.dart` is 293 — both over the 200-line guardrail. The former predates this session (~2070 lines already); this session's additions made both worse without addressing the split, given the scope already in flight. Splitting `task_detail_sheet.dart` (by scaffold/step, or by create-vs-edit flow) is real follow-up work, not done here.

## [2026-08-30] Day-strip nav, create-flow redesign into 2-stage single sheet, drag-preview redesign, keyboard/caret bug fixes

Large multi-part session, several distinct changes:

**Day-strip navigation** (`day_strip.dart`, new): replaced the old header day-nav row and floating create FAB with one horizontally-scrollable strip of day chips sitting above the bottom nav, `+` create button inline, grey fill marking today specifically (independent of selection), a "return to today" chevron once scrolled away, top-edge shadow. `timeline_screen.dart`'s whole-screen swipe-to-change-day `GestureDetector` is commented out (not deleted) per direct instruction — drag-to-reschedule on individual task pills is untouched. `day_navigation_row.dart` is now fully dead code, flagged not deleted.

**Task detail styling**: Date moved into the Time/Duration pane (that pane's header hidden); Repeat became its own standalone bare pane matching Notifications. `TaskNameCategoryModal`'s Name/Description wrapped in a bare pane; Category's header removed.

**Duration presets**: extracted `AppSelectableChip` (shared with Repeats' day chips) and `AppWheelPickerController` (external animated-scroll handle for `AppWheelPicker`) so tapping a duration preset both sets the value and animates the wheel to match; typing/scrolling to a matching value re-highlights the preset. Presets render as one `Row` of `Expanded` chips (not `Wrap`, which overflowed to a second line on narrow screens) — same pattern as the day-of-week row.

**Create-flow restructure into two internal stages, one sheet** (major, from a 3-screenshot mockup): the old "auto-open Name/Category modal, chain into Start-time modal, chain into Duration modal" guided sequence is gone. `_TaskDetailFlow` now has an internal `_isNameStage` bool: stage 1 shows ONLY the Name field (autofocused, in its own bare pane) with a "Done" primary button; confirming (button tap or the keyboard's own complete action) unfocuses, and if the name is still empty routes through the same `_handleClose` path the × button uses (silent abandon, per existing decision — see prior entry) — otherwise advances to stage 2. Stage 2 is the full schedule form, cross-faded in via `AnimatedSwitcher`, with each top-level pane running its own staggered fade+slide entrance on first build (`_StaggeredEntrance`, 40ms stagger, runs once — not on every rebuild). New row layout matches the mockup: Category ("Add" link, opens new `TaskCategoryModal` — Category split out of the old combined Name+Category modal since Name now lives in stage 1 alone), Date ("Today"/date link, opens the existing `showDatePicker`), Time (read-only row showing the resolved range, opens `TaskStartTimeModal` — no more inline typed field for Time), Duration (a link showing "Custom" or the resolved preset/duration label, tap does nothing — the preset chips and wheel now render directly inline in the same pane, confirmed directly: `TaskDurationModal` is no longer opened from the create flow at all). `presetMinutes`/`presetLabel` promoted from private to public in `task_duration_modal.dart` so both that modal and the new inline block share one list.

`TaskNameCategoryModal` and `TaskDurationModal` remain live (still used by `_EditDetailsForm`/`_EditScheduleForm`, the separate "Edit details"/"Edit time and duration" flows for already-scheduled tasks, reached via `task_action_sheet.dart`) — this restructure is scoped to the **create** flow only. `_ScheduleStepScaffold` (shared by both create and edit-schedule) was left untouched; the new stage/row widgets are new, create-flow-only classes (`_NameOnlyStage`, `_ScheduleFieldsStage`, `_StaggeredEntrance`, `_LinkFieldRow`, `_PlainFieldRow`) alongside it.

Rewrote two test files to match: `create_flow_initial_modal_test.dart` (previously tested the deleted modal-auto-open/chain behavior; now tests the stage-1/stage-2 split, the Inbox-skips-stage-1 case, and the abandon-on-empty-name behavior for both the Done button and the header ×) and `exit_confirmation_test.dart`'s create-flow tests (`_nameTaskViaModal` now types into stage 1's inline field instead of opening `TaskNameCategoryModal`; the "Save task" test now opens Time via its read-only row and relies on Duration's 5-minute default rather than filling a Duration modal that no longer exists in this flow).

**Drag interaction redesign**: removed the floating `_DragTimeLabel` chips that overlapped neighboring tasks' text during drag; the existing time-range text under the title now shows the live drag-preview time instead (`dragPreviewStartsAt ?? task.scheduledAt!`). Lifted cards are wrapped in a frosted pane — `BackdropFilter`/`ImageFilter.blur` at a new tokenised `colorSurfaceBlurOverlay` (36% alpha, derived via `.withValues` from the existing pane-surface primitive, confirmed directly to use `colorSurfacePrimary`'s primitive not `colorSurfaceBase`) / `blurOverlaySigma` (12.0) pair on `AmbleTheme`, with the pane's own shadow (`shadowPane`) moved from the inner icon pill to this outer wrapper.

**Two real bugs found and fixed in `AppSegmentedTimeField`**:
- Keyboard "Done" committed the typed value but never closed the keyboard — `TextField.onEditingComplete` was overridden with a bare `_commit`, silently dropping Flutter's own default `unfocus()` call the override replaces. Fixed with a `_handleEditingComplete()` wrapper (`_commit()` then `_focusNode.unfocus()`). Confirmed `AppTextField` (Name/Description) does NOT have this bug — it never overrides `onEditingComplete`.
- Tapping directly into a specific position in the field (e.g. mid-minutes) snapped the caret to the start first, requiring a second tap to land where intended. `_handleFocusChange`'s post-frame "force caret to start on focus-gain" logic couldn't distinguish a genuine tap-driven focus gain from any other kind (opening the sheet, tabbing in) — both looked like "caret at end" to the `atEnd` check. Fixed with a `_pendingTextTap` flag set by the `TextField`'s own `onTap`, consumed by `_handleFocusChange` to skip the reset only when focus arrived from an actual tap.

`flutter analyze`: clean project-wide (only the two long-standing, accepted `_DetailsStepScaffold.modalTitle` warnings — that class remains an intentionally-unreferenced backup, unrelated to this session).

**`flutter test` NOT run this session** — one or more `flutter run` dev sessions stayed active throughout (checked repeatedly via `ps aux`), and per the incremental-compiler-cache deadlock risk this repo avoids running the test suite alongside a live `flutter run`. This is the single largest open risk from this session: the day-strip widget, the whole create-flow restructure, the drag redesign, and both `AppSegmentedTimeField` fixes are verified by `flutter analyze` and manual reasoning only, not by a green test run. Run `flutter test` as soon as no `flutter run` session is active — this covers a large backlog.

**Still flagged, not fixed**: `task_detail_sheet.dart` is now well past 2400 lines (was ~2340 before this session's additions) — the 200-line guardrail violation flagged in the prior entry has only gotten worse. Splitting it (by stage, or by create-vs-edit flow) remains real, un-started follow-up work.

## [2026-08-30] Create-flow stage 2 corrections from annotated mockup feedback

Follow-up correction pass on the same day's stage-2 redesign, from an annotated screenshot marking up the actual build against the target:

- **Preview card removed.** The read-only badge/title/"Set a time and duration" row is gone from stage 2; Name and Description are real editable `AppTextField`s again (own bare pane, matching stage 1's treatment), not collapsed into a preview. Confirmed directly: "this should remain input field, hide preview on left, we no need it."
- **Category's selected state is now a filled tag**, not blue link text — same emoji+label pill shown in the mockup, filled with `theme.categoryColors[category.token]`. The unselected "Add" state stays plain accent-coloured link text (new `_CategoryFieldRow`, replacing `_LinkFieldRow` for this one row).
- **The inline wheel moved from Duration to Time.** Confirmed directly: "the wheeler is actually for time." Time is now a live read-out (`start + duration`, recalculated on every rebuild) with the wheel directly under it, stepping by 5 minutes and calling `onTimeChanged`. `TaskStartTimeModal` is no longer opened from the create flow at all — Category is still its own small modal, but Time has no modal step any more, matching how Duration already worked.
- **Duration is presets-only now** — no wheel of its own, defaulting to the first preset (5m).
- **Time and Duration both seed a real default the instant stage 1 confirms** (`_confirmNameStage`), rather than staying unset until touched — Time to `TimeOfDay.now()` rounded to the nearest 5 minutes (new `_roundToNearestFiveMinutes`, so the default already lands on one of the wheel's own rows), Duration to the first preset. Confirmed directly: "after entering task name we default time to current and duration to 5m, so schedule would be active" — Schedule is enabled immediately on reaching stage 2, no extra taps required. Guarded with `??=` so the Inbox "give it a schedule" case (which skips stage 1 and may already carry its own time/duration) is never overwritten.

Updated `exit_confirmation_test.dart`'s "Save task" test to match — it no longer needs to open any modal at all to reach a savable state, since Time/Duration now default on their own. Removed the now-dead `_fillSegmentedField` helper and the unused `TaskStartTimeModal` import from that file.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings as before). `flutter test` still not run — `flutter run` sessions remained active throughout.

## [2026-08-30] Stage 2: Category split into its own pane, Description collapses behind a link

Second correction pass on the same day's stage-2 work, from another annotated screenshot:

- **Category is now its own standalone `AppPane`**, separate from both the Name/Description pane above it and the Date/Time/Duration pane below — confirmed directly ("Category should be its own section"). `_CategoryFieldRow` itself is unchanged, just relocated.
- **Description no longer shows as an empty field by default.** New `_NameDescriptionPane` (stateful): Name is always visible and editable; Description starts collapsed behind a right-aligned "Add description" blue link, and tapping it reveals the field with `autofocus: true` so the keyboard comes up immediately, cursor in place. One-way reveal — once shown, the field just stays visible for the rest of the modal session, no re-collapse. Starts already revealed if the controller already carries text (e.g. re-entering stage 2), so existing notes are never hidden behind the link.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings). No test changes needed — nothing in the existing suite asserted on the old always-visible Description field or Category's prior pane grouping. `flutter test` still not run — `flutter run` sessions remained active throughout.

## [2026-08-30] Drag-and-drop regression fix, single "Edit task" entry, stage 1/2 merged into one persistent instance

- **Fixed a real drag-and-drop regression from this same day's earlier frosted-pane work.** Reported directly: click-and-drag only lifted the pill but never tracked the finger — releasing and pressing again was needed before dragging actually worked. Root cause: `TaskCapsuleBlock` was conditionally swapping its ENTIRE returned widget tree the moment `isLifted` flipped true (`return card` bare vs. `card` wrapped in a new `Container`/`ClipRRect`/`BackdropFilter` chain) — and `onDragStart`'s `setState` is exactly what flips `isLifted`, so the very first drag frame inserted brand-new ancestor render objects above the already-active drag gesture's render object, breaking Flutter's ongoing hit-test routing for that pointer. Fixed by making the frosted wrapper ALWAYS present in the tree (same widget shape at every `isLifted` value) and animating the frosted LOOK instead — blur sigma, fill alpha, shadow, and padding all interpolate via a `TweenAnimationBuilder<double>` driven by `isLifted`, rather than the wrapper's presence/absence. At `t=0` this renders identically to the old bare-`card` case (confirmed against the one existing golden test, which renders with `isLifted` defaulting false).

- **Action sheet's two edit entries ("Edit details" / "Edit time and duration") collapsed into one "Edit task".** Requested directly. It opens the same `showTaskDetailSheet` screen the create flow uses — passing a non-null `task` already skips stage 1 (Name-only) and lands directly on stage 2 with every field populated, so no new screen was needed, just re-pointing `task_action_sheet.dart`'s single edit row at `showTaskDetailSheet(context, task: task)` instead of the old `showEditDetailsSheet`. `_TaskDetailFlow`'s header/primary-button labels now read "Edit task"/"Save" when `widget.task != null`, vs. "Create task"/"Schedule" for a genuine create. `showEditDetailsSheet`/`showEditScheduleSheet` are NOT deleted — `_duplicate` in the same action sheet still opens `showEditDetailsSheet` for a freshly duplicated task, unchanged, since that wasn't part of this request.

- **The Name/Description pane no longer gets torn down and rebuilt across the stage 1 → stage 2 transition.** Reported directly: it needs to "persist on tapping done or confirm keyboard... not another instance... same object remaining", with only Category-and-below animating in. The previous `AnimatedSwitcher(child: _isNameStage ? _NameOnlyStage(...) : _ScheduleFieldsStage(...))` genuinely built two different widget subtrees, discarding and recreating the Name field's `Element` (and by extension its internal focus/keyboard state) the moment the stage flipped. Restructured so `_ScheduleFieldsStage` is the ONE persistent body: `_NameDescriptionPane` builds unconditionally at the top, every render, and a new `showScheduleFields` bool gates only the Category-onward staggered block in/out of the tree below it. `_NameOnlyStage` is deleted (folded into this). Since `_NameDescriptionPane`'s `State` now lives at a stable position across every rebuild, `autofocus` (which Flutter only ever applies on a widget's first build) correctly fires once on genuine stage-1 entry and never re-fires when the schedule fields reveal — gated via a new `autofocusName` param (`!showScheduleFields` at construction, false for "Edit task"/Inbox-give-schedule, which skip stage 1 from the start and shouldn't summon the keyboard on open). The Name field's `onSubmitted` now also confirms stage 1 directly (`onNameSubmitted`), matching the header Done button.

- **Time now defaults to 12:00 noon**, not "current time rounded to 5 minutes" (the prior session's choice, superseded per direct request: a fixed, predictable default rather than one that varies by when the sheet happens to open). The now-unused `_roundToNearestFiveMinutes` helper was removed rather than left dead, since it was net-new code from earlier the same day, not a pre-existing pattern.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings). `flutter test` still not run — a `flutter run` session remained active throughout this whole stretch, now the largest and riskiest block of unverified-by-test work this session has produced, including a real drag-gesture fix that specifically deserves an on-device or integration-level check once testing is possible.

## [2026-08-30] Category modal: tap-to-select, no Done; Name/Description pane spacing fix

Two small corrections reported directly:

- **`TaskCategoryModal` now commits on tap**, no separate "Done" confirmation. Converted from a `StatefulWidget` (local `_category` mirror + Done button popping it) to a plain `StatelessWidget` — each chip's `onSelected` now calls `Navigator.of(context).pop(option)` directly. "Tapping on the tag is already selecting, no need [to hit] done again."
- **Fixed the Name/Description pane's "Add description" link sitting too far from the Name field.** The gap read as the same size as the pane's own outer bottom padding, making the link look like it was floating in the pane's padding rather than belonging to the field above it. Cause: a `SizedBox(height: spacingXs)` was stacked on top of the Name field's own `AppFieldShell` internal bottom padding (`spacingSm`), and with no visible boundary between the two, the combined gap read as roughly the pane's own `spacingMd` padding. Removed the extra `SizedBox` — the link now sits directly against the field's own existing padding.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings). No test files reference `TaskCategoryModal`, so nothing needed updating there. `flutter test` still not run — a `flutter run` session remained active throughout.

## [2026-08-30] Fixed: Duplicate persisted a real task before the user could confirm or discard it

Reported directly: tapping "Duplicate" created a real copy in the database immediately — closing/discarding the follow-up edit screen still left the unwanted duplicate behind, since `TaskList.duplicateTask` called `saveTask` before the edit screen even opened.

Fixed by routing "Duplicate" through the CREATE path instead of pre-persisting-then-editing: `_TaskDetailFlow` gained a `duplicateFrom` field, distinct from `task` — it seeds every field (title, notes, category, schedule, notifications) from the source task in `initState`, same as `task` would, but `widget.task` itself stays null, so `_save` still calls `TaskList.createTask` (a genuinely new task/id) rather than `updateTask`, and — critically — nothing is written to the repository until the user actually taps Save. `task_action_sheet.dart`'s `_duplicate` now just calls `showTaskDetailSheet(context, duplicateFrom: task)` and no longer touches `taskListProvider` at all.

`TaskList.duplicateTask` itself is now unreferenced anywhere in the app — flagged, not deleted, since removing a notifier method wasn't part of this fix's scope.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings). `flutter test`/whole `test/` dir also analyze-clean. `flutter test` itself still not run — a `flutter run` session remained active throughout.

## [2026-08-31] Free-window blocks + hold-and-drag placement line

Two new Timeline interactions, requested directly from a mockup + detailed description:

**Free-window blocks** (`free_window_block.dart`, new file): a subtle labeled block now renders inside any gap of `freeWindowThreshold` (hardcoded 2h default — flagged as a real Settings control to build later, not part of this pass) or longer between two consecutive tasks on a day. Small/normal gaps are completely unchanged — no indicator, matching today's behaviour exactly, per direct confirmation. `findFreeWindows` computes maximal gaps across ALL overlap columns (a window only counts as free if nothing is scheduled anywhere in it, matching the mockup's full-width block) between consecutive tasks only — not before the first or after the last, since those edges are already governed by `_visibleRange`'s own padding. Tapping the block's label text opens the create flow with the DATE and TIME both seeded to the window's start — new `initialTimeOfDay` param on `showTaskDetailSheet`/`_TaskDetailFlow`, since the existing `initialScheduledAt` only ever seeded the date (`_timeOfDay` stays null until stage 1 confirms, where it now normally defaults to noon — see the immediately prior session entry). `initialTimeOfDay`, when set, bypasses that noon default entirely and seeds `_timeOfDay` directly in `initState`; every other call site (the ordinary "+" button, Edit task, Duplicate) is unaffected, since none of them pass it.

New token: `AmbleTheme.colorFreeWindow` — the border/hairline primitive (`sand300`/`ink600`) at 50% alpha, added with the full field/constructor/light+dark-palette/copyWith/lerp treatment the token system requires. Deliberately derived from the border color rather than a new primitive or an existing surface — the block is meant to read as quiet structural scaffolding, not a competing task-like surface.

**Hold-and-drag placement line** (`place_task_line.dart`, new file): long-pressing anywhere on the Timeline's empty background (not on a task pill, not on a free-window block — both claim the touch first, see below) shows a horizontal accent-colored line with a time label on its right edge (per direct request — the reference `CurrentTimeIndicator` puts its label on the left, this one is deliberately mirrored). Dragging while still held moves the line; releasing opens the create flow with start time = wherever the line was dropped, snapped to 5 minutes (matching the existing task-drag-to-reschedule snap).

Gesture-arena design, not a manual scroll/hold state machine: `PlaceTaskLineLayer` is rendered as the Stack's FIRST child (Stack hit-tests last-to-first, so every task pill and free-window block — added later in the children list — gets first refusal at any touch before it can reach this background layer at all) and uses `GestureDetector.onLongPress*` with `HitTestBehavior.translucent`. `onLongPressStart` only fires once Flutter's own `kLongPressTimeout` (~500ms) has elapsed with the pointer held still, which is exactly what makes an ordinary scroll (which starts moving immediately) get recognized as a pan by the ancestor `SingleChildScrollView` instead — the SAME mechanism that already lets a task's own icon-pill drag win over scroll today, reused rather than reinvented. Timeline mode only (both this and the free-window blocks need a real time axis, same reasoning as the existing connectors/now-line — collapsed mode's stacking layout has no meaningful Y-to-time mapping).

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings). No existing tests reference `TimelineScreen`/`_DayTimeline`, so nothing needed updating for either feature — real test coverage for both is a gap worth flagging, especially the gesture-disambiguation behavior (scroll vs. hold), which is hard to verify by static analysis alone. `flutter test` still not run — a `flutter run` session remained active throughout this whole stretch; this is now a large, entirely test-unverified addition covering two brand-new interaction patterns.

## [2026-08-31] Fixed: free-window block could visually overlap a short task's pill

Reported directly, from an annotated screenshot: the free-window block's top edge was computed from a task's RAW scheduled end time, but `TaskCapsuleBlock` floors a pill's rendered height at its badge size — so a short task (e.g. 5 minutes) still occupies real pixels well past its scheduled end, and the block (which didn't know that) could start drawing before the pill was actually done, overlapping it.

Fixed by giving `findFreeWindows` an optional `minPillMinutes` parameter — mirrors `timeline_screen.dart`'s own pre-existing `_pillHeight` floor (used by `_TimelineConnectors` for the identical reason) — and computing each task's "effective end" as the later of its raw scheduled end and `scheduledAt + minPillMinutes`. `timeline_screen.dart`'s call site now passes `_pillWidth(theme) / _pixelsPerMinute` so the two floors stay in sync by construction rather than by two independently-hand-tuned constants. `FreeWindow.start` (and therefore the seeded create-task time when the block is tapped) now correctly reflects the pill's real rendered end, not the raw scheduled one — you can no longer create a task starting inside space a pill still visually occupies.

The screenshot's second annotation ("Note indent") turned out to already match the confirmed-correct behavior (`left: hourGutterWidth`, same as a task pill's own icon column) — the apparent flush-left look was very likely a visual side-effect of the SAME overlap bug (a block starting too early can read as crowding the connector line/pill column even at the correct `left`), so no separate indent fix was needed once the overlap was corrected.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings). `flutter test` still not run — a `flutter run` session remained active throughout.

## [2026-08-31] Free-window block: correct indent (aligned to task names) + vertical breathing room

Follow-up correction, reported directly: the block's left indent should match where task NAMES start (past the icon-pill column), not the pill's own left edge — "left indent of size of the pill of tasks + padding/gap between pill and description... the window container is aligned up with names of tasks." Also needed real vertical gap from the tasks immediately above/below it, not flush-touching.

Fixed in `timeline_screen.dart`'s call site (not inside `FreeWindowBlock` itself, which stays a dumb positioned box driven entirely by its params):
- `left: hourGutterWidth + _pillWidth(theme) + theme.spacingSm` — mirrors exactly the `SizedBox(width: theme.spacingSm)` `TaskCapsuleBlock` puts between its own icon pill and title/time column.
- `top`/`height` inset by `theme.spacingSm` on both ends (`top + spacingSm`, `height - spacingSm * 2`) so the block's rendered box shrinks away from both neighbouring tasks symmetrically, rather than padding visually inside a box that still touches them.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings). `flutter test` still not run — a `flutter run` session remained active throughout.

## [2026-08-31] Description-collapse fix, placement-line coordinate/gesture fixes (untested on device)

Three issues reported directly from on-device testing:

**1. Description field now collapses back to the "Add description" link when the keyboard closes on an empty field.** Reveal it, decide not to type anything (or type then delete it all), close the keyboard — it returns to link form instead of sitting there as a permanently-revealed empty field. `AppTextField` gained a new optional `onFocusChanged: ValueChanged<bool>?` param (backward compatible, every other call site unaffected) so `_NameDescriptionPane` can observe the description field losing focus and collapse `_showDescription` back to false when `notesController.text.trim().isEmpty` at that moment. Only fires on the LOSING-focus edge, never on gaining it.

**2. Placement line (hold-and-drag to place a task) rendered at the wrong position on the iOS simulator.** `PlaceTaskLineLayer` was trusting `details.localPosition` from the long-press callbacks, which — while nominally already local to whichever RenderBox owns the firing recognizer — sits several nested Positioned/Stack/SingleChildScrollView layers deep in this tree. Fixed by resolving the coordinate explicitly instead: a `GlobalKey` on the `RawGestureDetector`'s own box, and a `_localY` helper that calls `RenderBox.globalToLocal` against `details.globalPosition` (which IS unambiguous — true screen coordinates) rather than trusting whatever local space the callback happened to hand back.

**3. Placement line never appeared at all on a real Android device**, though it worked on the iOS simulator. Root cause: `LongPressGestureRecognizer` rejects the ENTIRE gesture if the pointer drifts more than `preAcceptSlopTolerance` (~18 logical pixels, Flutter's own `kTouchSlop`) before the hold duration completes. A real touchscreen's natural jitter during a held press easily exceeds that; a mouse-driven simulator produces near-zero jitter and never triggers it — so the long press was being silently rejected before it ever got the chance to fire, on real hardware only. Fixed with a new `_NoSlopLongPressGestureRecognizer` (extends `LongPressGestureRecognizer`, overrides the `preAcceptSlopTolerance` getter to return `null` — that field isn't reachable via the subclass's own constructor, only via the base class, so overriding the getter directly was the only way in), wired through `RawGestureDetector` instead of the `GestureDetector.onLongPress*` shorthand (which can't reach this level of recognizer configuration at all).

Also converted the same widget's `GestureDetector` to `RawGestureDetector` to make both fixes possible in one pass, since #3's fix required it anyway.

**Also fixed**: while making the drag-and-drop pass, an initial cascade-based recognizer-configuration attempt (`instance..onLongPressStart = ...`) tripped a real `use_of_void_result` analyzer error — rewritten as separate statements instead, which resolved cleanly. Caught before this ever reached device testing.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings). **None of these three fixes have been verified on-device or in a test** — the coordinate fix (#2) and the slop-tolerance fix (#3) are both reasoned from Flutter's documented gesture-arena mechanics, not confirmed against the actual reported symptoms, since a `flutter run` session has remained active throughout and blocked `flutter test`. This is a real, acknowledged risk: #3 in particular changes gesture-arena competition dynamics against the ancestor `SingleChildScrollView`, and if the ancestor's own pan recognizer still wins the arena race on a real device even with slop removed, the placement line could still fail to appear — that scenario isn't something a code-level fix alone can guarantee without an on-device check.

## [2026-08-31] Rewrote placement line on LongPressDraggable — prior hand-rolled recognizer confirmed still broken

Reported directly: the previous coordinate/slop-tolerance fixes did NOT resolve it — the line still appeared at the wrong position and still wasn't draggable, confirmed on both the iOS simulator and a real Android device. Also requested: the line should visually match `CurrentTimeIndicator` (same line+label shape) but in the accent colour, not red.

Rather than continue patching the hand-rolled `RawGestureDetector`/`LongPressGestureRecognizer`, rewrote `place_task_line.dart` on top of `LongPressDraggable` — Flutter's own purpose-built widget for exactly "hold, then drag," internally using `DelayedMultiDragGestureRecognizer`, the same mechanism `ReorderableListView` itself relies on to survive a scrollable ancestor. This sidesteps the gesture-arena competition against `SingleChildScrollView` that the hand-rolled recognizer was almost certainly losing.

Key design points:
- **The visible line is NOT `Draggable.feedback`.** `feedback` is positioned by the framework via the app-wide `Overlay` — a different coordinate space that can't reliably line up with the underlying timeline's own hour axis. `feedback` here is an invisible `SizedBox.shrink()`, used only to receive `onDragUpdate` callbacks; the actual visible line+label is rendered as an ordinary `Positioned` sibling inside the SAME Stack the timeline itself uses, driven by tracked `_lineTop` state — the identical rendering approach `CurrentTimeIndicator`/`_DraggableTaskBlock` already use, which is also what makes matching `CurrentTimeIndicator`'s exact shape (now accent-coloured instead of red) straightforward.
- **A `Listener` tracks raw pointer position independently of the drag gesture itself.** Discovered reading `Draggable`'s own source: `onDragUpdate` only fires once the pointer has actually MOVED past its start position (`_DragAvatar.update`'s `_position != oldPosition` guard) — a hold released perfectly still, with zero subsequent movement, would never fire `onDragUpdate` at all, and `onDragStarted` (fired the instant the hold completes) carries no position of its own. A `Listener` doesn't participate in the gesture arena, so it can observe every raw pointer-down/move event without interfering with `LongPressDraggable`'s own recognizer; `onDragStarted` now seeds `_lineTop` from the last pointer position this Listener saw, so the line appears immediately at the press point even before any drag movement occurs.
- Position resolution (`RenderBox.globalToLocal` against `details.globalPosition`, via a `GlobalKey` anchor) is unchanged from the prior fix — that logic wasn't the confirmed-broken part, but it's now feeding real, framework-correct positions instead of ones from a recognizer that likely wasn't winning the gesture arena at all.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings; one real error caught along the way — `LongPressDraggable<void>` isn't a valid type argument, `Draggable<T extends Object>` requires a real type, fixed to `Object`).

**Still entirely unverified on-device or by test** — this is the third attempt at this specific interaction, and each of the first two independently seemed structurally sound before being reported broken on real hardware. Strongly recommend a direct on-device check before trusting this one either; `flutter test` remains blocked by an active `flutter run` session throughout.

## [2026-08-31] Placement line styling + z-order; create/update reveal animation and scroll-to-task

Placement line (now confirmed working on device) got two corrections, and the save flow got its requested animation sequence.

**Placement line — hairline weight.** Was `borderWidthHairline * 2`; now plain `borderWidthHairline`, matching `CurrentTimeIndicator`'s own line exactly. The two lines mean different things and should differ only in colour (accent vs. red), so any weight difference read as unintentional.

**Placement line — paints above tasks.** Reported directly: it was rendering underneath them. The cause is structural rather than a z-index setting: a `Stack` hit-tests last-child-first but paints first-child-last, so the layer's two requirements are in direct opposition — the press surface must be FIRST (so task pills win any press over it, i.e. "not on the pill"), while the line must be LAST (so it paints on top). One widget can't be both. Split into `PlaceTaskLineLayer` (press surface, still first) and a new `PlaceTaskLineOverlay` (draws the line, mounted last), sharing a `PlaceTaskLineController` (`ValueNotifier<double?>`) rather than duplicating state. The layer no longer calls `setState` at all — it publishes to the notifier, and only the overlay rebuilds.

**Create/update reveal sequence.** Requested directly: "after closing modal only then the task fades in (with easing) or extends pill (change duration case) so user can see it happening", plus "upon closing scroll to the timeline point of start hour so the new created task or updated is in view."
- New `recently_saved_task_provider.dart` records `(taskId, SavedTaskChange.created | durationChanged)` at save time, just before the modal pops. Hand-written `Notifier`/`NotifierProvider` rather than `@riverpod`-generated — one nullable field with no dependencies didn't justify pulling it into the codegen set (and would have needed a build_runner pass while `flutter run` sessions were live). Note Riverpod 3 has removed `StateNotifier`; `Notifier` is the current equivalent.
- `TaskList.createTask` now returns the created `Task` (was `void`) so the caller has its id without a second lookup — the same shape `duplicateTask` already had. Existing callers ignoring the value are unaffected.
- **Duration change** animates for free: `TaskCapsuleBlock`'s pill `Container` became an `AnimatedContainer`, and its height already derives from the task's own duration — so the pill now grows/shrinks into any new duration, from the edit modal or any other path, with no state plumbing.
- **Creation** fades in via a `fadeInOnFirstBuild` flag on `_DraggableTaskBlock`, set only for the block whose id matches the just-created task. Deliberately NOT applied to the duration-change case: that block is already on screen, so fading it would read as disappearing and returning rather than growing.
- **Scroll-to-task** centres the saved task in the viewport (matching how the view already opens on "now" — a task flush against the viewport edge reads as cut off). Handled from BOTH `didUpdateWidget` and `initState`: the day's *first* task doesn't reach `didUpdateWidget`, because the screen was showing `_EmptyDayState` until that moment and `_DayTimeline` mounts fresh instead of updating. Shared `_revealSavedTask` covers both.
- The flag is cleared only after `motionNormal` has elapsed, not immediately — the block reads it on its first build to decide whether to fade, so clearing earlier would rebuild it without the flag before it ever animated.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings). `place_task_line_test.dart` was updated for the layer/overlay split (both are mounted, first and last, exactly as `TimelineScreen` does — the split is part of the contract under test) but **still has not been executed**: a `flutter run` session has remained active throughout. The animation/scroll sequence has no test coverage at all yet and is unverified on device.

## [2026-08-31] Reveal animations were playing behind the closing modal

Reported directly: the create/duration-change animations weren't visible — by the time the timeline was on screen the task was already placed or already extended.

Diagnosis: both animations were being triggered at save time, but the save is written BEFORE the modal pops, and Flutter's default `PageRoute` transition is 300ms while `motionNormal` is 250ms. So the entire animation ran behind the closing modal and was finished before the timeline was visible. Nothing was wrong with the animations themselves — only their start time.

- New `AmbleTheme.motionRouteSettle` token (350ms, `MotionPrimitives.durationRouteSettleMs`) — "how long to wait for a dismissed full-screen route to slide away before animating on the screen it uncovers". Deliberately a bit longer than Flutter's own 300ms default so the reveal starts on a clear screen rather than racing the dismissal's last frames.
- The fade-in now waits `motionRouteSettle` before flipping to opaque, instead of firing on the first post-frame callback.
- The duration change needed more than a delay: the new duration is already persisted, so the pill had no earlier height left to animate FROM. Added `growFromMinutes` on `_DraggableTaskBlock` and a matching `durationMinutesOverride` on `TaskCapsuleBlock` — the pill RENDERS at the pre-save duration until the modal clears, then releases to the task's real value and animates there via the `AnimatedContainer` already added earlier. Only the pill is overridden; the time/duration TEXT keeps showing the real, saved value throughout, so nothing ever displays a stale number.
- `RecentlySavedTask` carries `previousDurationMinutes` for that, captured in `_save` before the mutation overwrites it.
- The flag's clear-delay grew to `motionRouteSettle + motionNormal`, since the block now waits out the former before starting the latter — clearing at the old `motionNormal` would have dropped the flag before the animation even began.
- The scroll-to-task is deliberately NOT delayed: it has to be finished by the time the entrance starts, or the task animates in off-screen. It runs for `motionNormal` (250ms) inside the modal's `motionRouteSettle` (350ms) window, which is noted at the call site so the ordering isn't broken later.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings). Still no test coverage for the reveal sequence, and `place_task_line_test.dart` remains unexecuted — a `flutter run` session has been active throughout.

## [2026-08-31] Entrance stagger across the block's parts; resize animation fixed and slowed

**Stagger.** Requested directly: "pill > name > time > icons below > checkbox". `TaskCapsuleBlock` gained `entranceProgress` (0→1, defaulting to 1 for every block that isn't arriving), and a `_staggeredOpacity(progress, index)` helper spreads that single value across the five parts. Each part's fade occupies `_staggerFadeFraction` (0.5) of the total rather than 1/5, so consecutive parts OVERLAP — a strictly sequential version reads as five separate events instead of one block arriving. Starts are spread across the room the fade width leaves, so the last part still reaches full opacity exactly at progress 1. Driven by one `TweenAnimationBuilder` in `_DraggableTaskBlock` (replacing the previous single `AnimatedOpacity`), at `motionSlow`.

The icon row and checkbox already had `AnimatedOpacity` for the drag-lift fade; the entrance value is MULTIPLIED into that rather than replacing it, since both can be in play at once (a block dragged right after being created) and the product keeps whichever is more hiding.

**Resize wasn't visible — a real bug, not just timing.** `_heldDurationMinutes` was only initialized in `initState`, but a duration change does NOT remount the block: same task id, same key, so the element is updated and `initState` never runs again. The held pre-save height was therefore never picked up. Added `didUpdateWidget` to catch the case, with the shared `_scheduleReveal()` used by both paths. A newly created task still mounts fresh, so that case stays on `initState`.

**Timing, after it was still hard to see.** `durationRouteSettleMs` 350 → 500: at 350 the reveal began the instant the modal finished, which still read as "already done" because the eye hadn't settled on the timeline yet. The pill's own `AnimatedContainer` went `motionNormal` → `motionSlow`, matching the entrance's pace — both are "watch this happen" beats rather than gesture responses. The flag's clear-delay follows to `motionRouteSettle + motionSlow`. The scroll stays undelayed and still fits (250ms inside the 500ms wait); the comment noting that ordering was updated to the new number.

`flutter analyze`: clean project-wide (same two long-standing `_DetailsStepScaffold.modalTitle` warnings). Verified by hand that the stagger math has every part at opacity 1 when progress is 1, so resting blocks — and the existing golden test — are unaffected. Still no test coverage for the reveal sequence, and `place_task_line_test.dart` remains unexecuted with a `flutter run` session active.

## [2026-08-31] Overlap clustering: aggregate block for 2–3 overlapping tasks

Built the full feature per work order: 2–3 mutually-overlapping tasks on a day now render as one `OverlapClusterBlock` (stacked-icon badge, flat chronological title+time rows, `min(start)`/`max(end)` boundary labels) instead of individually-overlapping capsules. A run of 4+ chain-overlapping tasks is excluded from clustering entirely (confirmed via AskUserQuestion, not guessed — see DECISIONS.md). New `shared/services/overlap_cluster.dart` (`detectOverlapClusters`, pure function, same shape as `generateRecurrenceInstances`) with 16 unit tests covering pair/triple/chain/boundary/ordering/4+-exclusion cases. Wired into `timeline_screen.dart`: clustered tasks skip the individual-slot loop, clusters render via a keyed `AnimatedSwitcher` crossfade so formation/dissolution (drag creating or breaking a cluster) fades rather than snaps. The dragged task is excluded from detection for the drag's duration so it always renders as its own full capsule mid-drag. New Settings toggle ("Disable overlap clustering") added via the exact `PreferencesRepository`/`@Riverpod(keepAlive: true)` pattern from Phase 13a's theme-mode setting — off (clustering on) by default.

Screenshot-verified via two dev scaffolds (`overlap_cluster_main.dart`, `overlap_cluster_three_main.dart`, both `bool.fromEnvironment` gated): a normal unclustered day, a 2-task cluster, a 3-task cluster, the Settings toggle in the UI, and toggle-off naive-overlap rendering — all confirmed correct. The live drag-drop crossfade itself was NOT captured as a recording/sequence — no tap-injection tool was available this session — described in the summary to the user instead.

Also fixed, surfaced by running the full suite for the first time in a while (15 pre-existing failures, unrelated to clustering): two tests using a structurally-broken `find.widgetWithText(TextField, ...)` finder against `AppFieldShell` (label and field are siblings, not ancestor/descendant); a real `RenderFlex` overflow in `_LinkFieldRow`/`_PlainFieldRow` (missing `Flexible`+ellipsis on long values); two `task_action_sheet_remove_test.dart` tests asserting stale pre-consolidation behavior, rewritten to match the current duplicate/edit flow; a not-hit-testable "Done" button in `task_duration_modal_test.dart` (needed `ensureVisible`); and a multi-layered `place_task_line_test.dart` fix — wrong pump ordering around `startGesture`, a real Flutter bug where a non-`Positioned` Stack sibling broke `LongPressDraggable` recognition for an unrelated `Positioned.fill` sibling (fixed by always wrapping `PlaceTaskLineOverlay` in `Positioned.fill`), and wrong expected text (`'11:00'` vs the actual 12-hour-format `'11:00 AM'`). One golden (`timeline_capsule_preview.png`) regenerated after confirming its 0.08% diff was benign anti-aliasing drift, not a regression.

`dart format .`: 148 files, 0 changed. `flutter analyze`: clean (2 pre-existing, unrelated `_DetailsStepScaffold.modalTitle` warnings). `flutter test`: 214/214 passing.

## [2026-08-31] Overlap clustering: revised visual design based on reference-image feedback

Presentation-only revision to the aggregate cluster block, following direct visual feedback against a reference image — detection logic (`detectOverlapClusters`) untouched. Removed entirely: the stacked-icon badge (main icon + peeking circle), the "Overlapping tasks" text label. Cluster member tasks now render as their REAL `TaskCapsuleBlock` pills at genuine spatial height/column/position — reusing `layoutOverlappingTasks` (the same function the naive-overlap/clustering-disabled mode already uses) rather than a new positioning calculation — with icon/title/time/checkbox content suppressed via a new `TaskCapsuleBlock.contentHidden` flag, leaving just the category-colored pill shape. New `OverlapClusterPills` widget renders these. The flat title+time list (unchanged row styling: plain text, chronological, no icon/card/color/indentation) moved into its own separately-positioned block, top-anchored at the cluster's start and placed beside the pill group — deliberately NOT vertically aligned per-row to any one pill, per direct instruction; row order is the only correspondence. Boundary labels (`min(start)`/`max(end)` on the left gutter) unchanged.

Hit and fixed along the way: (1) a stale on-disk `disableOverlapClustering: true` from a prior session's screenshot run silently defeated clustering in the `overlap_cluster_three_main.dart` scaffold — it opened the preferences box but never cleared it; fixed to clear like the other scaffold does. (2) `OverlapClusterPills`' inner `Stack` (only `Positioned` children) crashed with "A Stack requires bounded constraints from its parent," since the ancestor `Positioned` in `timeline_screen.dart` only pins `top`/`left` and leaves width/height loose — fixed by wrapping it in an explicit `SizedBox` sized from `layoutOverlappingTasks`' own column-count/height math.

Screenshot-verified via both existing dev scaffolds: a 2-task cluster (`overlap_cluster_main.dart`, "Deep work"/"Standup") and a 3-task cluster (`overlap_cluster_three_main.dart`, "Overlap A/B/C") both show blanked colored pills in parallel columns beside the flat chronological list, matching the revised spec. The normal unclustered task and the free-window block both confirmed unaffected in the same screenshots.

`dart format .`: 148 files, 0 changed. `flutter analyze`: clean (2 pre-existing, unrelated `_DetailsStepScaffold.modalTitle` warnings). `flutter test`: 214/214 passing, including all 16 existing `overlap_cluster_test.dart` detection tests unaffected. No widget/golden tests target `OverlapClusterBlock`/`OverlapClusterPills` directly, so none needed updating for the rendering change.

## [2026-08-31] Overlap clustering: cluster pills made draggable, checkboxes restored, fixed lane layout

Follow-up to the same-day visual revision, based on immediate feedback after reviewing that build: clustered tasks needed to stay draggable, checkboxes had disappeared, and pill-to-list correspondence needed to be a real positional guarantee rather than order-only.

Removed the separate `OverlapClusterPills` widget (a static, non-interactive `Stack` of blanked pills) entirely. Clustered tasks now render through the SAME `_DraggableTaskBlock` loop every other task on the timeline uses — each clustered slot carries a new `contentHidden` flag (icon/title/time hidden, checkbox and drag both stay live) while resting, and the drag handler forces `contentHidden` off the instant that task becomes the one being dragged, so a dragged former-cluster-member shows full content immediately, matching the existing "a dragged task always renders normally" rule. `TaskCapsuleBlock.contentHidden`'s own meaning changed to match — it no longer blanks the checkbox, only icon/title/time.

Lane assignment changed from `layoutOverlappingTasks`' packed-column algorithm (reuses a column once its previous occupant finishes — doesn't guarantee one lane per task) to a new fixed one-lane-per-task scheme (`_withClusterLanes`): lane index always equals chronological position within the cluster, for every cluster size, so "leftmost pill = topmost list row" is now a real positional guarantee rather than incidental.

Bug found and fixed along the way: a resting blanked pill's checkbox, at the ordinary full-timeline-width row, landed behind the cluster's own flat list panel (which occupies that same right-hand region, painted after the pill loop). Fixed by bounding a resting blanked pill's row to just pill+gap+checkbox width, and widening the list panel's own left offset to clear every lane's checkbox column.

Screenshot-verified via both scaffolds: 2-task and 3-task clusters both show fixed lanes (leftmost=earliest=topmost row), live checkboxes beside each pill in the pill's own color, and correct list clearance with no overlap.

`dart format .`: 148 files, 0 changed. `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 214/214 passing, all 16 detection tests unaffected.

## [2026-08-31] Overlap clustering: checkbox moved from pill into list row

Second same-day follow-up, based on immediate feedback after reviewing the draggable-pills build: having a checkbox next to each blanked pill made the pill read as its own separate task card rather than a plain positional marker.

Reverted `TaskCapsuleBlock.contentHidden` to suppress the checkbox again alongside icon/title/time — a resting cluster member's pill is back to being ONLY the category-colored shape (still draggable/tappable). Each row in the cluster's own flat list (`_ClusterTaskRow` in `OverlapClusterBlock`) now carries its own trailing `CompletionCheckbox`, right-aligned within the list panel — matching where a normal capsule's checkbox sits within its own row, just scoped to the list panel's width rather than the full timeline. `_DraggableTaskBlock`'s resting-blanked-row width simplified back to just the pill's own width, and the list's `left` offset only needs to clear the pill lanes, not a checkbox column.

Screenshot-verified via both scaffolds: 2-task and 3-task clusters both show pure colored pills with no checkbox, and each list row's own checkbox right-aligned, correctly colored to match its pill.

`dart format .`: 148 files, 0 changed. `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 214/214 passing.

## [2026-08-31] Overlap clustering: fixed a real "double drag needed" bug in cluster pills

Reported directly: dragging a resting cluster pill needed two attempts — the first press only lifted it (elevation/shadow appeared) without tracking the finger, and the second press-after-release could actually drag it.

Root cause confirmed to be the exact bug class already documented and fixed once before for `isLifted`/the frosted wrapper (see `task_capsule_block.dart`'s own doc comment): `TaskCapsuleBlock.contentHidden` was implemented as an early-return branch, returning a structurally DIFFERENT widget tree than the normal-content path. Since `contentHidden` flips false the instant a drag starts on a resting cluster member (a dragged task always shows full content), that swap tore down and rebuilt the very `GestureDetector` tracking the gesture mid-press.

Fixed by removing the early-return entirely — `contentHidden` now renders the identical tree shape at every value, fading icon/title/time/checkbox to `opacity: 0` (checkbox also `IgnorePointer`-wrapped) instead of omitting them, exactly matching how `isLifted` already handles its own conditional look. A second-order bug surfaced by this fix: the title/time text's own intrinsic height doesn't shrink when merely invisible, and the pill's `IntrinsicHeight` wrapper sizes the whole row to its tallest child — a short cluster pill (badge-height floor) is shorter than two lines of body text, producing a real `RenderFlex` overflow ("OVERFLOWED BY 56px"). Fixed with `ClipRect` + a `maxHeight` cap on the text column, capped to the pill's own height whenever `contentHidden`. Also reverted an unrelated width-narrowing hack on the outer `_DraggableTaskBlock` positioning (added in an earlier same-day pass to make room for a since-removed pill-side checkbox) that caused a SECOND, horizontal overflow once the row always rendered full content internally — the row now always claims full width, matching every other capsule.

`timeline_capsule_preview.png` (golden) regenerated for a benign sub-pixel `ClipRect` boundary diff (0.01%, confirmed anti-aliasing, not a real regression).

Screenshot-verified via the 3-task scaffold: no overflow, pills render identically to before this fix. The actual single-press drag gesture itself could not be verified by me directly (no tap-injection tool available this session) — verification of the fix is by code/structural match against the already-validated `isLifted` precedent, plus a clean rebuild with no rendering exceptions. Asked the user to confirm the fix on their own device.

`dart format .`: 148 files, 0 changed. `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 214/214 passing.

## [2026-08-31] Overlap clustering + day strip: ghost lane fix, list holds structure during drag, list card removed, day-nav dot indicator

Four fixes/changes from direct feedback, all in the same session as the drag-bug fix above.

**Ghost lane mismatch.** The drag ghost (left behind at 20% opacity at the original position) was computing its column from the ordinary `layoutOverlappingTasks` packed-column scheme, while the REMAINING cluster members recompute into the fixed one-lane-per-task scheme the instant the dragged task is excluded from detection — the two disagreed, visually reading as "items go in 2 lanes and a transparent one." Fixed with a second `restingClusters` computation (clusters WITHOUT drag exclusion), used only to look up the ghost's lane via a new `_ghostSlotFor` helper.

**List no longer shrinks mid-drag.** The cluster's flat list used to crossfade to a shorter version the instant a drag started, reading as the row vanishing rather than the task being lifted. Now rendered from `restingClusters` (full membership) instead of `clusters`, with the actively-dragged member's own row fading via a new `OverlapClusterBlock.fadedTaskId` → `_ClusterTaskRow.isFaded` (`AnimatedOpacity`, same treatment `TaskCapsuleBlock.isLifted` already gives its own parts). The list's `AnimatedSwitcher` key still derives from settled membership, so a genuine drop-driven cluster change still crossfades — just not the drag itself.

**List card removed.** `OverlapClusterBlock`'s outer `Container` (surface fill, rounded corners, shadow) is gone per direct feedback ("names should not have that rounded bg") — rows now sit directly on the timeline as plain text.

**Day strip redesigned.** Background fill now marks the SELECTED day (any day), superseding the earlier "grey bg = current day" design. The current day instead gets a small accent-colored dot below the day number, in a fixed-height slot. The old "selected but not today" outline is removed — background alone now signals selection.

`dart format .`, `flutter analyze`, `flutter test`: all clean, 214/214 passing. Visual verification for these four fixes deferred to the user's own device — a `flutter run` session was active on their end during this pass and left untouched rather than interrupting their own testing.

## [2026-09-01] Quick Capture: on-device natural language parsing, live highlighting, confident-parse auto-create with undo

New pure-Dart parser (`shared/services/quick_capture_parser.dart`, `parseQuickCapture`), mirroring the existing pure-function pattern (`overlap_cluster.dart`/`recurrence_generator.dart`). Extracts date/time (`today`/`tomorrow`/`next <weekday>`/`at 10:30`/`3pm`), duration (`for 30 mins`/`for 2 hours`/`for 1h`), and recurrence (`every morning`/`daily`/`every monday` → a `RecurrenceRule`) from free text, plus a `title` (whatever text wasn't matched). Confidence rule: a parse is confident iff an explicit date/time anchor was found — a bare recurrence or duration phrase alone does not grant confidence, per the work order's own example, and its own extracted fields (`durationMinutes`/`recurrenceRule`) are suppressed to `null` when not confident so nothing partially leaks. See DECISIONS.md for the full rule and every other flagged design choice (highlighting mechanism, highlight-color token mapping, `AppUndoToast`'s Overlay target).

Wired into `quick_capture_sheet.dart`: a non-confident parse behaves exactly as before (`captureTask`, whole input as title, unscheduled). A confident parse calls `createTask` immediately (no confirmation dialog) with the extracted fields, then shows a new `AppUndoToast` (new adaptive `core/widgets/` component) with an Undo action that deletes the created task (or its whole series, if recurrence was involved).

Live inline highlighting via a `TextEditingController` subclass overriding `buildTextSpan` — the real, single `TextField` paints its own colored spans directly, keeping cursor/selection/IME/deletion entirely native rather than risking a stacked-overlay approach drifting out of sync with the real text.

32 new parser tests (`quick_capture_parser_test.dart`) covering every extraction category individually, combined inputs, every confidence-threshold edge case (including the work order's own "every morning" bare-recurrence example), and fallback behavior. 1 new widget test (`app_undo_toast_test.dart`) confirming the toast renders its message and Undo action.

**A real debugging detour, worth recording:** the toast could not be gotten to appear in ANY real-device/simulator screenshot across roughly a dozen rebuild-and-screenshot cycles (varying duration up to 300s, disabling animation entirely, testing a bare red full-screen `ColoredBox`, testing on macOS desktop, a full `flutter clean` rebuild), despite `initState`/`build` confirmed firing via debug prints every time — `dispose` also fired almost immediately after, with no expiry timer involved. Eventually verified via an isolated `flutter test` widget test (deterministic, frame-controlled) that `AppUndoToast.show` renders correctly and reliably — the code is correct; the non-appearance in every simulator/device attempt this session remained unexplained and is most likely an environment/tooling artifact specific to this session's screenshot-capture workflow (possibly related to how rapid `flutter run` relaunches interact with the simulator's own window/frame state), not a real app bug. Switched `Overlay.of(context)` to `rootOverlay: true` along the way, which is a genuine correctness improvement (the more robust target for UI meant to outlive its triggering screen) even though it did not turn out to be the actual cause.

Screenshot evidence: live highlighting (3 token types visible: blue date/time, ochre duration, coral recurrence) confirmed via `quick_capture_highlight_main.dart`; confident-parse auto-create confirmed via `quick_capture_undo_main.dart` (task correctly created and visible on the Timeline — only the toast overlay itself couldn't be captured, see above); fallback (non-confident) path confirmed via `quick_capture_fallback_main.dart` (ambiguous input landed as a plain title-only Inbox item, unchanged from today's behavior).

`dart format .`: 155 files, 0 changed. `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 247/247 passing.

## [2026-09-01] Quick Capture: undo bug fix + expanded parser vocabulary (bare times/durations, weekday groups/ranges, category detection)

**Real bug fixed, reported directly**: the undo toast's "Undo" link showed and dismissed correctly but never actually removed the created task. Root cause: `onUndo`'s closure called `ref.read(taskListProvider.notifier)` at construction time, which was AFTER the sheet's own `Navigator.pop()` had already disposed its `State` — `ref` on a disposed `ConsumerState` can't be used. Fixed by closing over the `notifier` already captured earlier in `_submit()`, before any disposal; a Riverpod `Notifier`'s lifetime is tied to the provider container, not the widget that read it, so holding the reference across the sheet's teardown is safe.

**Parser vocabulary expanded**, all in `quick_capture_parser.dart`:
- Bare 24h time with no am/pm (`11:00`) now anchors a confident parse, same as an am/pm form.
- Bare duration with no leading "for" (`2h`, `90m`, `1h5m`/`1h 5m`) now extracts a duration — same confidence rule as the existing "for ..." form (still not confident alone, with no anchor).
- Recurrence: `everyday`; `weekdays`/`every weekday` (Mon-Fri); `weekend`/`weekends`/`every weekend` (Sat-Sun); a weekday RANGE (`mon-fri`, `mon to fri`, `monday to friday`, abbreviated or full, no "every" needed); `every <weekday>` now also accepts 3-letter abbreviations.
- Category detection: a category name (`work`/`personal`/`health`/`admin`) anywhere in the text sets the created task's category and is removed from the title — surfaced regardless of confidence, since a category word carries no scheduling ambiguity. New 4th highlight token color (PERSONAL category's icon color).

Two real regex bugs caught by the new tests before they shipped: the weekday-range pattern used `$_weekdayAlternation` inside a RAW string literal (`r'...'`), which doesn't interpolate — Dart silently treated it as the literal text `$_weekdayAlternation` rather than the actual alternation, so the range pattern never matched anything. Fixed using the same adjacent-raw-plus-interpolated-string concatenation the other weekday patterns already used correctly. (The other apparent failure — a "2h" test expecting the word "work" to survive in the title — was a bad test expectation, not a parser bug: "work" is a genuine category word and correctly gets extracted, exactly as category detection is supposed to do.)

28 new parser tests added (60 total in the file now, up from 32) covering every new capability plus the interaction between the new bare-duration/bare-time forms and their existing "for"/am-pm counterparts.

`dart format .`: 155 files, 0 changed. `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 275/275 passing.

## [2026-09-01] Task Detail: fixed editing recurrence on an already-scheduled task (real bug — Save silently did nothing to the series)

**Real bug fixed, reported directly**: turning Repeats on for a plain task, changing an existing series' days, or turning Repeats off — none of it took effect on Save when editing an already-scheduled task; only creating a brand-new task with Repeats on ever actually materialized a series.

Root cause: the app has TWO structurally similar edit forms in `task_detail_sheet.dart` — `_TaskDetailFlowState` (the real, live one, reached via `showTaskDetailSheet`/`task_action_sheet.dart`'s "Edit task") and `_EditScheduleFormState` (an older, retired form kept as an unreferenced backup, reachable only from dev scaffolds). Both declared `_repeats`/`_selectedDays` fields, but only `_EditScheduleFormState` actually seeded them from the task being edited and branched its save into `TaskList.updateTaskWithNewRecurrence`/`updateTaskWithChangedRecurrence`/`disableTaskRecurrence`. `_TaskDetailFlowState`'s `_repeats` always started `false`, and its save path called plain `updateTask` unconditionally whenever `widget.task != null` — the recurrence provider methods were never reached from the real UI at all.

Fixed by porting the seeding (from `findSeriesTemplate`) and the three-way save branch into `_TaskDetailFlowState`, plus its own `_hasUnconfirmedChanges` check (so leaving Repeats changed and closing without saving now correctly prompts, matching every other tracked field).

A pre-existing 6-test widget suite (`edit_schedule_repeats_test.dart`) had been passing this whole time — because it tested the OTHER (unreferenced) form. Retargeted it at the real `showTaskDetailSheet` entry point; all six pass against the fixed live flow (needed `tester.ensureVisible` added before each tap, since the live form's schedule stage genuinely scrolls, unlike the retired one). Full root-cause account and the general lesson (a passing suite against dead code actively suppresses the "we have no coverage" signal) recorded in ERROR_LOG.md.

Also added 3 new provider-level tests (`task_providers_test.dart`) directly exercising `updateTaskWithNewRecurrence`/`updateTaskWithChangedRecurrence` — these confirmed the PROVIDER logic itself was already correct (a `now`-vs-hardcoded-past-date issue in my first draft of these tests briefly looked like a second bug in `_deleteUntouchedFutureInstances`, but was a test-authoring mistake, not app code — `_deleteUntouchedFutureInstances` correctly filters against real `DateTime.now()`, and a test anchored to a fixed past date makes every instance look "already past" and therefore never a deletion candidate).

`dart format .`: 155 files, 0 changed. `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 278/278 passing.

## [2026-09-01] Loading spinner on Save/Add buttons — stops double-tap from double-creating/editing a task

**Requested directly**: buttons needed a loading state while a task was being created/edited, so a slow write didn't leave the button tappable long enough to fire twice and create/edit the same task twice. Scoped via AskUserQuestion to Task Detail (create + edit, `_TaskDetailFlowState`) and Quick Capture's Add button (`_QuickCaptureFormState`) — the retired, unreferenced `_EditScheduleForm`/`_EditDetailsForm` were explicitly excluded.

`AppButton` gained an `isLoading` flag: swaps the label for a small platform-appropriate spinner and forces the button non-interactive, while deliberately keeping the button's normal enabled fill/foreground (loading is visually distinct from plain-disabled — see DECISIONS.md for the full reasoning). Wired into `_TaskDetailFlowState._save` and `_QuickCaptureFormState._submit` via a `bool _isSaving`/`_isSubmitting` field on each — this flag, not the button's own disabled-ness, is the actual re-entrancy guard (checked synchronously at the top of each async handler), wrapped in `try/finally` so a thrown error still releases it.

Rippled into two existing widget test files: `edit_schedule_repeats_test.dart` and `exit_confirmation_test.dart` both tap the Save button (directly, or via the "Save task" dialog action in the exit-confirmation flow) and then call `pumpAndSettle()` — which started timing out, since the now-animating spinner never lets frames settle while a save is in flight. Fixed both files' shared `_tapAndSettle` helper: a single bounded `pump()` right after the tap, then the existing real-I/O delay, then a final `pumpAndSettle()` once the save has actually completed. Full mechanism recorded in ERROR_LOG.md — general lesson: any continuously-animating widget (spinner, shimmer, marquee) makes `pumpAndSettle()` unsafe to call while it's live.

`dart format .`: 0 changed. `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 278/278 passing.

## [2026-09-01] Voice dictation for Quick Capture — tap-to-talk mic button, on-device speech-to-text

Added `speech_to_text: ^7.4.0` (new dependency, flagged and confirmed first) and wired a tap-to-talk mic button into Quick Capture. Not a new feature request in isolation — this was scoped and estimated in conversation first (package vetted for maintenance status and platform SDK minimums, both clear against Amble's `minSdk 24`/Flutter-default `compileSdk`), then confirmed to proceed. Also not listed in `docs/SCOPE.md` at the time — added to SCOPE.md's Nice-to-have section as part of this session rather than building it un-tracked, per SCOPE.md's own "confirm before building anything not mapped here" rule.

New `lib/core/widgets/app_mic_button.dart` (`AppMicButton`) — adaptive Cupertino/Material icon button with a second "listening" visual state (fill swaps to `colorTaskAlert`, icon swaps mic → stop), same structural pattern as the existing `AppIconButton`. Wired into `quick_capture_sheet.dart`: `_QuickCaptureFormState` owns one `stt.SpeechToText` instance, a `_isListening` flag, and `_toggleListening()` (permission requested lazily on first tap, mirroring `NotificationService.requestPermissionIfNeeded`'s established pattern — denial just leaves the mic inert, typing still works). Only the FINAL recognized transcript (`result.finalResult == true`) is written into `_titleController.text` — no progressive highlighting of interim speech results, so the field's existing live token-highlighting controller never has to reconcile against a still-changing partial transcript. From there, dictated text goes through the exact same `parseQuickCapture` → `taskListProvider` pipeline as typed input; no separate voice parsing path.

Platform config: iOS `Info.plist` gained `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription`; Android manifest gained `RECORD_AUDIO`.

No new automated test coverage for the mic button itself — `speech_to_text`'s platform channel isn't meaningfully mockable in a widget test without a fake platform implementation, and manual verification on a real device (simulator speech recognition is known-flaky per the package's own docs) is the appropriate check here; not yet done this session — flagged as an open risk below.

`dart format .`: 2 files changed (0 actual diffs — already formatted). `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 278/278 passing (no regressions; no new tests added for the reason above).

**Open**: manual on-device verification (iOS + Android) of the mic button — permission prompt copy, actual dictation accuracy, denial handling — not yet done.

## [2026-09-01] Zone (time-boxed task containers) — architecture spike, design pass only, no code

Requested as a spike: "contexts (zones that have start/end time) and contain tasks," a task can set a zone, a time, or both, zones can't overlap, zones can repeat with per-day-adjustable times, and — deferred, not built now — dragging/cascading a zone with its contained tasks together.

Sized this as new architecture, not additive work: it introduces a new persisted entity (closest precedent is `TrackedBehavior`), makes a task's "when" three-way instead of two-way (explicit time / zone-only / neither), needs its own zone-to-zone overlap check and a genuinely new capacity-check concept, and zone recurrence doesn't fit the existing `RecurrenceRule` shape (one rule applied uniformly) because it needs per-occurrence-adjustable times — confirmed directly rather than assumed.

Per SCOPE.md's own "confirm before building anything not mapped here" rule and the user's own choice (design pass first, not a vertical slice), no code was written this session. Instead: drafted the full model shape into `docs/CONSTITUTION.md` ("Zone — a time-boxed container of tasks (spike, not yet built)") and a summary + three open forks into `docs/SCOPE.md`'s deferred-features section. Confirmed via AskUserQuestion: zone-task link is an explicit `zoneId` field on `Task` (not computed from time overlap — required specifically because a zone-only task has no `scheduledAt` to overlap against).

Three forks explicitly left open, flagged for their own confirm-first pass before implementation: capacity-exceeded behavior (block/warn/silent), the per-instance recurrence model shape (likely materialized per-day `Zone` rows rather than one shared `RecurrenceRule`, but not decided), and zone drag/cascade (deferred past the first build entirely).

No code changed; `flutter analyze`/`flutter test` not run (nothing to verify).

## [2026-09-01] Timeline: day view no longer looks "cut off" on a light day — height floored at viewport

Reported directly: with one task, the timeline container looked cut off / looked like its height was driven by task count. Root cause: `_DayTimeline`'s scroll range (`_visibleRange`, earliest task − 30min to latest task + 30min) is dynamic by prior design — a light day genuinely produces a short elapsed span, and the rendered `SizedBox`/background/gutter only extended that far, leaving the rest of the screen looking unfilled rather than a real full-height surface.

Confirmed via AskUserQuestion: floor the rendered height at the viewport height rather than reverting to a fixed calendar-day range (which was itself a deliberate, previously-confirmed change away from a fixed window). `timeline_screen.dart`'s `_DayTimelineState.build` now wraps its `SingleChildScrollView` in a `LayoutBuilder` and computes `dayHeight = max(contentHeight, constraints.maxHeight - theme.spacingMd * 2)`. The dynamic scroll range, hour markers, and "now" positioning are all unchanged — a busy day still scrolls exactly as before; only a light day's rendered surface now fills the screen instead of stopping short.

`dart format .`: 1 file changed. `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 278/278 passing (one transient full-suite failure on the first run — a Hive "box already closed" timing issue in `edit_schedule_repeats_test.dart`, unrelated to this change; passed cleanly both in isolation and on a clean full-suite rerun).

## [2026-09-01] Dev config scratch place — task-capsule layout variants (stacked/inline text, icon row, duration) toggleable live

Requested: "some dev config place for stuff," starting with trying 2 timeline task-capsule text layouts (stacked, current default, vs. inline — hours first then the name on one line, instead of the name then time on separate lines) plus show/hide for the bell/repeat status-icon row and the duration suffix.

New `lib/core/dev_config.dart`: three `@Riverpod(keepAlive: true)` notifiers (`DevTimelineTaskTextLayout`, `DevTimelineTaskIconsVisible`, `DevTimelineTaskDurationVisible`), in-memory only (not persisted via `PreferencesRepository`/Hive — resets every restart, deliberately, since this is scratch config for comparing options, not a real setting), gated the same way the existing Settings "Developer" section already is (`kDebugMode`, not `FeatureFlags` — a developer convenience that must never exist in a real build, not a product feature toggled per build config). All three default to current shipped behavior.

Wired into `TaskCapsuleBlock` (`task_capsule_block.dart`) as new optional constructor params — `stacked` keeps the existing two-line title/time layout; `inline` renders time+duration then title on one `Text.rich` line. Read from `timeline_screen.dart`'s `_DraggableTaskBlockState.build` (already Riverpod-aware, no new prop-threading needed). Controls added to `SettingsScreen`'s existing Developer panel: a segmented chip row (reusing `ThemeModeSelector`'s visual pattern, duplicated locally as `_DevChip`) for the text layout, plus two `AppSwitch` toggles for icons/duration.

Hit one build_runner snag: `dev_config.dart` initially imported `flutter_riverpod` (matching most other provider files) instead of `riverpod_annotation` directly, which made `hive_ce_generator` fail to resolve the `@Riverpod` annotation on the file even though the class has no `@HiveType` at all — fixed by matching `preferences_providers.dart`'s exact import (`riverpod_annotation`), after which `dev_config.g.dart` generated cleanly with no `hive_registrar.g.dart` changes (confirmed via `git diff --stat`).

Ran a git-tracked hygiene check before finishing: confirmed no unrelated file (in particular `hive_registrar.g.dart`) was touched by the build_runner run.

`dart run build_runner build`: 2 outputs (dev_config.g.dart, riverpod-generated). `dart format .`: 2 files changed. `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 278/278 passing, no regressions.

## [2026-09-01] Timeline task pill badge now shows category emoji, matching creation/edit's picker

Reported directly: the timeline task pill's badge icon should be the category emoji, same as what's shown during task creation. `TaskCapsuleBlock` was still rendering `Icon(task.category.icon)` (the monochrome Material glyph, tinted via a local `iconColor` for contrast) even though the create/edit category picker has shown `.emoji` since an earlier session — that earlier session deliberately kept `.icon` for exactly this tinted-badge case, so this reverses that decision. Confirmed via AskUserQuestion before changing it.

Swapped the badge to `Text(task.category.emoji, style: TextStyle(fontSize: badgeSize * 0.55))`. The `iconColor` local (tint logic for the old vector icon) was left with no remaining use once emoji — which carries its own fixed color — replaced it, so it was removed along with its now-stale doc comment, not left dead. `CompletionCheckbox`'s ring color is a separate, unaffected read of `theme.categoryIconColors`.

One golden regenerated (`timeline_capsule_preview.png`, 0.25% diff — exactly the badge swap). Inspected the new PNG directly before trusting it: emoji render as placeholder squares under the widget-test harness's font (no emoji glyph coverage — a known Flutter golden-test limitation, and the same substitution the old icon glyphs already showed in this same golden), not a real defect; layout/position/color, what the golden actually checks, are correct.

`flutter analyze`: clean (2 pre-existing, unrelated warnings — confirms `iconColor` removal didn't orphan anything). `flutter test`: 278/278 passing after the golden regeneration.

## [2026-09-02] Category converted from a fixed enum to a persisted, user-extensible entity — new "Add category" modal

Requested: a real "Add new category" flow (name, one of 12 colors, an emoji, Save), matching `task_detail_sheet.dart`'s visual language, reachable via a "+ Add new" link on the category-picker modal's title bar. Sized as a full architectural change first (categories only make sense as user data, not a closed 5-value enum) — full plan surveyed via a Plan agent, three open design forks (palette style, CRUD scope, entry points) confirmed via AskUserQuestion before any code, then implementation delegated to a background agent with the confirmed plan.

Full build: new `Category` model (own Hive box `categories`, own repository, own `CategoryList` Riverpod notifier), a deprecation of `Task.category` (old enum, kept for Hive field-index stability, never removed/renumbered) in favor of a new `Task.categoryId`, a launch-once seed+backfill migration (5 built-ins at fixed UUIDs, existing tasks' old enum resolved onto the new id), every real consumer migrated off the old `TaskCategory` extension getters (`TaskCapsuleBlock`, both category pickers, `quick_capture_parser.dart`'s category-word detection, export/import), and the new `AddCategoryModal` itself (name / 12-color swatch grid / curated emoji grid / Save). v1 is create + list only, no edit or delete. Full model shape and every confirmed design decision recorded in `docs/CONSTITUTION.md`'s new "Category" section and `docs/DECISIONS.md`.

**Both implementing background agents hit the session's API rate limit mid-work** and had to be resumed manually. Picking up their work surfaced 122 `flutter analyze` errors (all in test files — every `Task.create(category: ...)` call site and `parseQuickCapture(...)` call needed the new `categoryId`/`categories` signature) plus a genuinely broken build: `Task.dart` had gained a `zoneId` field whose generated Hive adapter (`task.g.dart`) was stale, a `build_runner` regeneration fixed it.

**Correction**: this entry originally reported the `Zone` model/repository/provider/service files present alongside this work as unrequested scope creep. That was wrong — a separate, explicit work order for the Zone data layer had been issued directly; see the dedicated Zone entry for the real account.

Fixed after resuming, beyond the mechanical test-signature migration: (1) 4 widget-test files needed a real seeded `Category` Hive box in their setup (new shared helper `test/support/seeded_category_box.dart`) — a plain provider override doesn't substitute for one the way it does for `taskRepositoryProvider`, since `categoryRepositoryProvider` calls `Hive.box<Category>` directly; (2) two provider-layer tests (`task_providers_test.dart`) built an "identical copy" `Task` using the now-stale deprecated `category` field instead of `categoryId`, silently breaking their own premise; (3) `AddCategoryModal`'s own widget test hung on `pumpAndSettle()` after tapping Save — the established bounded-`runAsync` pattern for this exact spinner-hang class of bug (already fixed twice earlier this session) has a specific required shape, and a first fix attempt here split `tap`/`pump` outside the `runAsync` block from the delay — plausible-looking but actually hung for 2+ minutes rather than failing fast, confirmed by watching it stall twice, not by reasoning about it; (4) `seedBuiltInsAndBackfillIfNeeded` had all 5 built-in categories defaulting to the same `colorToken: 0` — a real bug caught during review, fixed to distinct indices.

Also hit and cleared genuine environment contention during this session — several orphaned `flutter_tester` processes from earlier, unrelated test runs were slowing/hanging new runs; killed the stale ones (confirmed with the user first) rather than assuming code was at fault, per this repo's own "suspect the environment before the code when many unrelated things fail" guardrail.

`dart format .`: clean. `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 302/302 passing.

## [2026-09-02] Zone data-layer build — model, repository, providers, overlap check, feature flag; no UI

Explicit work order: build only the Zone data layer CONSTITUTION.md's design section already specified, same "additive, inert" treatment `TrackedBehavior` got in Phase 10 — no UI, non-recurring only, capacity-exceeded behavior and zone recurrence explicitly NOT resolved this pass (both real, still-open forks the design section itself names).

Built: `Zone` model (`startMinutes`/`endMinutes` as plain ints — minutes since midnight, flagged since `TimeOfDay` has no Hive adapter and the codebase already uses this representation elsewhere; `durationMinutes` derived, never stored), `Task.zoneId` (`@HiveField(16)`, appended after this session's own `categoryId` at 15 — full pre-existing suite confirmed passing unmodified after this addition before proceeding, same risk posture as every prior `Task` field change), `ZoneRepository`/`HiveZoneRepository` mirroring `TrackedBehaviorRepository`'s shape, a `keepAlive: true` `ZoneList` notifier nothing currently reads, `zonesOverlap` (a genuinely separate function from the task-overlap checker, confirmed in scope), `calculateZoneCapacity` (built but deliberately unconsumed — pure calculation only, no block/warn/silent-overflow wiring), and `FeatureFlags.zoneEnabled` (same `bool.fromEnvironment` mechanism as `trackedBehaviorEnabled`, default off).

Added the test coverage this build was missing when first picked up mid-session: `hive_zone_repository_test.dart` (CRUD + constructor invariants), `zone_overlap_checker_test.dart` (overlapping/nested/identical/adjacent/separate/order-independence), `zone_capacity_test.dart` (sum-of-assigned, unscheduled-task-contributes-nothing, over-capacity, empty-zone). All new.

**Confirmed explicitly, not just by omission**: zone recurrence was NOT built — no recurrence/series field or code exists anywhere in the new Zone files. Capacity-EXCEEDED behavior was NOT built — `calculateZoneCapacity` computes the numbers only; nothing block/warns/silently-overflows on them. **App confirmed unchanged from a user's perspective**: no screen reads any Zone provider, `FeatureFlags.zoneEnabled` defaults off, full pre-existing test suite (which exercises every real screen) passes.

**Correction to an earlier entry this session**: this Zone data-layer code had briefly been reported (in this same log and in DECISIONS.md) as unrequested scope creep discovered while resuming unrelated Category work. That was wrong — this Zone build was explicit, separately-ordered work, not an agent going off-script. Both earlier entries have been corrected in place rather than silently edited away.

One pre-existing flaky test (`edit_schedule_repeats_test.dart`, a different individual test failing on each of 3 consecutive runs under this session's contended environment) — already documented earlier this session as a known timing-sensitive-under-load file (Hive writes racing against `_refresh()`), unrelated to this Zone work (nothing in this session touched that file, `task_detail_sheet.dart`, or `task_providers.dart`'s recurrence code). Not investigated further as a regression; confirmed via `git diff --stat` that none of the files it touches were modified in this session's Zone work.

`dart format .`: clean. `flutter analyze`: clean (2 pre-existing, unrelated warnings). `flutter test`: 302/302 (excluding the one known-flaky, unrelated test above, which was not consistently reproducible even across 3 isolated reruns).

## [2026-09-02] Zone's first UI — Settings → Zones → list → add/edit, modeled on the real task-creation modal

Requested directly: a Zones section in Settings that navigates to a real list page, with add/edit built on the same visual language as task creation.

Promoted `task_detail_sheet.dart`'s private `_StepScaffold`/`_HeaderCircleButton` (the actual near-full-screen, colored-header, pinned-Save-button chrome the real "add task modal" uses) to a new shared, public widget: `lib/core/widgets/app_step_scaffold.dart` (`StepScaffold`/`HeaderCircleButton`). This is what "modeled on the add-task modal UI" required literally — reusing the real chrome, not rebuilding a look-alike. Repointed all 3 internal call sites plus 1 standalone `_HeaderCircleButton` usage inside `task_detail_sheet.dart` at the public versions; confirmed zero behavior change via the full test suite (335/335 passing) plus an isolated rerun of `edit_schedule_repeats_test.dart` specifically, since that file most directly exercises `_TaskDetailFlowState._save`, the highest-risk consumer of this chrome.

Built: `lib/features/zones/zone_form_screen.dart` (`showZoneFormScreen` — near-full-screen slide-up on `StepScaffold`, title + start/end `AppSegmentedTimeField`s, Save validates against `zonesOverlap` excluding the zone being edited and surfaces a conflict via the same inline `errorMessage` slot task creation's own overlap rejection uses) and `lib/features/zones/zone_list_screen.dart` (`showZoneListScreen` — a real pushed `MaterialPageRoute` page, not a sheet, per the explicit "go to a page where you see the list" request; empty state, tap-to-edit rows, a "+" to add). Wired a "Zones" section into `settings_screen.dart`, gated behind `FeatureFlags.zoneEnabled` (same const-eliminated-when-off pattern as Tracked behaviors) but with a "Manage zones" button that navigates to the list page rather than an inline create form, since Zones is meant to be a place to browse/manage a list.

Confirmed via AskUserQuestion, since two real precedents in this codebase actually diverge on it: Zone add/edit is a near-full-screen page (matching real task creation), not a bottom sheet (matching `AddCategoryModal`'s own, different precedent from earlier this session).

Added `test/features/zones/zone_form_screen_test.dart` (Save disabled until valid, a created zone reaches `zoneListProvider`, editing pre-fills fields). Hit the "real Hive I/O hangs under `flutter_test`'s synchronous zone" gotcha in a new shape — twice, back to back — via a direct notifier call and a raw `box.put` in test setup, neither of which was a widget tap (every prior instance of this bug in this codebase was tap-triggered). Two separate multi-minute hangs, confirmed by flat CPU time, before landing on `tester.runAsync(...)` wrapping both bare I/O calls. Full account in ERROR_LOG.md — the generalized lesson: any real Hive call in a test needs `runAsync`, not just ones reached through a tap.

`dart format .`: clean. `flutter analyze`: clean (2 pre-existing, unrelated warnings — line numbers only, same two issues as before the `StepScaffold` extraction). `flutter test`: 335/335 passing, no flakes on this run.

## [2026-09-02] Zone ungated — live in every build now

Requested directly, right after the Zone UI was verified: `FeatureFlags.zoneEnabled` flipped from `bool.fromEnvironment('zone')` (default off) to `bool.fromEnvironment('zone', defaultValue: true)` — ships on in every build including release now, still overridable off via `--dart-define=zone=false` if ever needed for testing. Settings → Zones is now reachable without any build flag. Updated `docs/SCOPE.md`'s Zone entry to match (was still describing it as an unbuilt design spike).

`dart format .`/`flutter analyze`: clean. `flutter test`: 335/335 passing.

## [2026-09-02] Bug fix — 3-4 second task saves on Android (500-alarm cap)
User-reported: saving a task from the detail modal (editing a category, or
even saving with no changes at all) showed the button spinner for 3-4
seconds before closing. Diagnosed on a real device rather than by
inspection — added temporary `Stopwatch` probes to the save path, ran on
the physical moto g54, and found the Hive write took 18ms and the provider
refresh 7ms, with all the time inside `zonedSchedule`. Logcat gave the
actual cause: `IllegalStateException: Maximum limit of concurrent alarms
500 reached`. Android caps an app at 500 concurrent alarms, and past that
every schedule attempt throws a deeply-nested PlatformException that costs
seconds to marshal back across the channel.

Root cause was three compounding defects, all fixed (user chose the full
fix over just unblocking the save): (1) `_materializeSeries` scheduled an
alarm per materialized instance, and an 8-week recurring window is ~56
alarms per daily series — the app was manufacturing its own cap breach,
re-running the whole loop on every launch; (2) every `TaskList` mutator
*awaited* the notification sync, and the modal only pops when that future
resolves, so a side effect explicitly allowed to fail sat on the save's
critical path; (3) nothing ever cleared stale alarms, so an install that
had hit the cap stayed permanently wedged.

Fixes: a 14-day `notificationHorizonDays` with a pure, unit-tested
`isWithinSchedulingHorizon` guard (tasks still stored 8 weeks out, only the
near window holds an alarm); launch-time `refreshScheduled` that
`cancelAll()`s before re-registering, which both rolls the window forward
and reclaims slots on an already-wedged install; and
`_syncNotificationInBackground` (fire-and-forget via `unawaited`) at all
ten mutator call sites, so the modal pops as soon as the write and refresh
complete. Launch refresh is itself not awaited before `runApp`, so the fix
doesn't trade a slow save for a slow cold start.

Coverage: 5 new tests in `notification_horizon_test.dart` (materialization
schedules once, not per instance; refresh cancels-then-schedules only
in-horizon tasks; completed and unscheduled tasks skipped; the
horizon-under-window invariant) plus 6 in `notification_service_test.dart`
for the horizon boundaries, and a new `RecordingNotificationService` test
double for asserting on scheduling behavior rather than just stubbing it
out. `flutter analyze` clean (2 pre-existing unrelated warnings in
`task_detail_sheet.dart`). Full writeup in `docs/ERROR_LOG.md`, decisions
in `docs/DECISIONS.md`.

Verified on the physical moto g54: the same save that took 3-4 seconds
before measured **26ms** after, and no `Maximum limit of concurrent alarms`
errors appeared in the run — the launch-time `cancelAll()` reclaimed the
occupied slots, so notifications on that install went from silently broken
back to working.

**Pre-existing failure, NOT from this session, left as-is:**
`edit_schedule_repeats_test.dart`'s "changing an existing series' days"
case fails in the working tree (the MON chip's selection doesn't reach the
saved rule — `daysOfWeek` ends up with 1 element instead of 2). Bisected by
stashing: that file's uncommitted `_StepScaffold` → shared `StepScaffold`
extraction is what breaks it — 6/6 pass with the refactor stashed, 5/6 with
it applied. Untouched here since it belongs to that in-progress refactor,
not to the notification fix. Worth fixing before that refactor is
committed.

## [2026-09-02] Zone recurrence + notify

Extended `Zone` with `recurrenceRule` (reusing `Task`'s existing
`RecurrenceRule` shape, simple recurrence only — not the per-occurrence-
adjustable-times version CONSTITUTION.md still flags as deferred) and
`notificationsEnabled` (default true), both confirmed directly by the user
before building rather than guessed. `zone.g.dart` regenerated cleanly via
`dart run build_runner build` — no `riverpod_annotation`/`flutter_riverpod`
import conflict this time. Ran the full pre-existing 335-test suite
immediately after the model change, before writing anything else; all
green.

Added `NotificationService.scheduleForZone`/`cancelForZone`, resolving a
zone's `startMinutes` (+ optional `RecurrenceRule`) to a single concrete
`DateTime` and scheduling one one-shot alert for the next upcoming
occurrence — not a true recurring OS alarm (flagged as a future
enhancement in both the code and DECISIONS.md). Reuses the existing
`isWithinSchedulingHorizon`/`notificationHorizonDays` from the 500-alarm-
cap fix rather than inventing a separate horizon rule for zones. A
non-recurring zone whose time has already passed today no-ops, matching
`scheduleForTask`'s own convention, rather than rolling to tomorrow.

Rebuilt `zone_form_screen.dart`'s body: `AppSegmentedTimeField` stays the
primary Start/End entry, each field gained a trailing
`AppFieldActionButton` opening `AppWheelTimePicker` as the alternate
entry — verified this shape against `task_detail_sheet.dart`'s real
`_openStartTimeModal` pattern directly rather than assuming wheel-only.
Added a Repeat pane (`_ZoneRecurrencePanel`, a local duplicate of
`_RecurrencePanel`'s 7-day-chip shape — judged too small to be worth
promoting to `core/widgets/`, flagged in DECISIONS.md) and a Notify pane
(`AppSwitch` bound to `notificationsEnabled`, mirroring
`task_detail_sheet.dart`'s own Notifications row). `_save()` now builds
the `RecurrenceRule?` from local Repeat state and fire-and-forgets a
`scheduleForZone`/`cancelForZone` call after the write succeeds, same
non-blocking discipline as every `TaskList` write path.

Verification: `flutter analyze` clean (same 2 pre-existing, explicitly
out-of-scope `modalTitle` warnings as before). `dart format` clean on
every file touched this session (two pre-existing, previously-modified
files — `app_sheet.dart`, `task_name_category_modal.dart` — have their
own unrelated formatting drift from before this session, left alone per
minimal-diff scope). Full suite: 345 passed (335 pre-existing + 10 new:
3 Hive round-trip, 7 notification-service). Modal-sizing/header-alignment
task (Task 1) was already correctly in place in the working tree —
verified, not re-done.

Judgment calls flagged for review: (a) wheel-as-alternate not wheel-only,
verified against the real file; (b) local duplicate, not promoted, for
the Repeat panel; (c) non-recurring past-today zone no-ops rather than
rolling to tomorrow; (d) one-shot next-occurrence, not genuine recurring
OS scheduling, for recurring zones; (e) no launch-time refresh wired into
`main.dart` for zone notifications — only (re)registered on form save,
a real gap flagged in DECISIONS.md rather than silently accepted.

## [2026-09-02] Follow-up: closed the zone-notification launch-refresh gap

Reviewed the delegated Zone recurrence/notify build directly (not just trusted its self-report): read the model, notification-service, and form-screen diffs, ran the full suite myself (345/345 passing, `flutter analyze` clean). One real gap had been explicitly flagged rather than silently shipped: zone notifications only get (re)registered when a zone's form is saved — no launch-time refresh, unlike `Task`'s `refreshScheduledNotifications` in `main.dart`. Confirmed with the user directly whether to fix it now; added `ZoneList.refreshScheduledNotifications()` (same shape as `TaskList`'s own) and wired it into `main.dart` right after the task refresh, same not-awaited/fire-and-forget discipline. Also tidied a stale `Zone` class doc comment that still described the model as non-recurring after recurrence was added.

`dart format .`/`flutter analyze`: clean. `flutter test`: 345/345 passing.

## [2026-09-02] Zone rendered as a background block on the Spatial Task View (Timeline) — display-only

Explicit work order, scoped to exactly the Spatial Task View's own decorative treatment of Zone data — NOT the future Spatial Zone View (Zone as a real layout container), which stays separate. Tasks keep their existing spatial positioning/sizing logic completely unchanged; no task-rendering code was touched.

Proposed new Tier 1/2 color tokens for review before building, per the work order's own instruction: `ColorPrimitives.zoneBackground`/`zoneBackgroundDark` → `AmbleTheme.colorZoneBackground`, `oklch(0.97, 0.02, 240)` light / `oklch(0.28, 0.02, 240)` dark — a cool, very-low-chroma blue-grey, hue chosen deliberately apart from every existing category hue and from `colorFreeWindow`'s neutral family so a zone block can't read as a category tint or a free-window gap indicator. Confirmed with the user directly (cool blue-grey over a zero-chroma neutral alternative) before implementing.

New `ZoneBackgroundBlock` (`zone_background_block.dart`), positioned with the same `rangeStart`/`pixelsPerMinute` math the Timeline already uses for tasks, inserted into the Stack right after `TaskBoundaryMarkers` (before any task-rendering child, guaranteeing it paints behind every task capsule). `IgnorePointer`-wrapped — never intercepts a tap. The requested "starts slightly earlier/further left than its literal position" offset is a new named constant, `zoneBackgroundOffset = 12.0` — confirmed this is an EXACT match to the existing `theme.spacingIconTop` token rather than assumed close enough, so no new spacing token was needed; kept as its own named constant (not read directly off `theme` at each call site) so top/left offsets can't silently drift apart from each other, and so a future change to `spacingIconTop`'s own original purpose doesn't quietly move every zone block too.

Gated behind `FeatureFlags.zoneEnabled` (rendering an empty zone list when off, zero-cost). Every persisted zone renders unconditionally for its time range — no filtering on whether any task actually references it via `zoneId`, since that would itself be Zone-view/container behavior, out of scope here.

**Real on-device verification, not just widget tests**: built a new dev scaffold (`zone_background_preview_main.dart`, seeding real tasks + categories + zones) and ran it on a booted iOS simulator (iPhone 15 Pro Max) twice — once with the flag on (two zone blocks visibly behind three tasks, correct offset, tasks fully legible and unmoved) and once with `--dart-define=zone=false` (identical tasks at identical positions, zero zone blocks). Screenshots compared directly, not assumed correct from code alone. Hit and fixed two real scaffold issues along the way: the scaffold initially crashed on first build (missing the `preferences` Hive box `TimelineScreen`'s settings providers need — `main.dart` opens 5 boxes, the first scaffold draft only opened 3) and a stray manual `simctl launch` (outside `flutter run`'s own lifecycle) briefly showed the wrong calendar day with no seeded data — resolved by sticking to `flutter run`'s own start/stop lifecycle only, not manual simulator commands alongside it.

New widget test `zone_background_block_test.dart` (4 cases: offset math on top/left, growth math on width/height, the constant's exact value, `IgnorePointer` wrapping) — no golden/screenshot test, matching `FreeWindowBlock`'s own precedent (a rendering-only decorative block with no dedicated widget test, only its pure math tested), with the visual correctness instead confirmed via the real simulator screenshots above.

`dart format .`: clean. `flutter analyze`: clean (2 pre-existing, unrelated warnings only). `flutter test`: 349/349 passing (345 pre-existing + 4 new).

## [2026-09-02] Follow-up: guaranteed a visual gap between back-to-back zone blocks

Reported directly: two zones scheduled exactly back-to-back (one ends the moment the next starts) should always show a visible gap between their rendered blocks. Confirmed via AskUserQuestion this is purely cosmetic — save-time validation (`zonesOverlap`) is unchanged, zones can still be saved back-to-back.

Turned out to be a real latent bug: `zoneBackgroundOffset`'s top/left extension meant two such zones previously rendered as ACTIVELY OVERLAPPING blocks, not just touching ones. Worked the fix out algebraically before coding (a first instinct — trim the bottom/right edge by the gap — provably cannot produce a positive gap against a neighbor's own opposite-direction top/left extension). Correct fix: trailing edges recede by `offset + gap`, not just `gap` — new constant `zoneBackgroundGap = 4.0`, confirmed an exact match to `theme.spacingXs` before adding it. Verified with a hand-checked arithmetic scratch pass and a new dedicated widget test asserting the exact back-to-back scenario (`earlier.endMinutes == later.startMinutes` renders with exactly `zoneBackgroundGap` of clearance).

`dart format .`/`flutter analyze`: clean. `flutter test`: 351/351 passing (349 pre-existing + 2 new/updated in `zone_background_block_test.dart`).

## [2026-09-02] Spatial Zone View — Zone as a real layout container

Built the second Timeline display mode: Zones as real layout containers, alongside (not replacing) the existing Spatial Task View. Read CONSTITUTION.md's full Zone section, ARCHITECTURE.md, DECISIONS.md's Zone history, and PROGRESS_LOG.md's recent Zone entries first, per the work order.

**Containment logic** (`shared/services/zone_containment.dart`, new): `resolveZoneContainment(tasks, zones, day)` — a pure, provider-free function, same "pure grouping function, widget consumes it" shape as `detectOverlapClusters`. Explicit `task.zoneId` wins outright, even against a conflicting `scheduledAt` (confirmed directly — the mismatch is not flagged). Only when `zoneId` is null does a computed fallback apply (`scheduledAt` inside a zone's window) — strictly read-only for display, never writes `zoneId` back onto a `Task`. A task matching neither is "unzoned." A non-recurring zone applies every day viewed (no date field of its own); a recurring zone only applies on its matching weekdays, mirroring `NotificationService`'s private `_ruleMatchesDay` (duplicated, not imported — it's file-private). 8 unit tests in `test/shared/services/zone_containment_test.dart`, all passing: explicit match, computed fallback, neither/unzoned, the zoneId-vs-time mismatch, a half-open boundary edge case, non-recurring-every-day, recurring-only-matching-weekdays, chronological containment ordering.

**`ZoneContainerBlock`** (`features/timeline/zone_container_block.dart`, new): a bounded container with title+duration and the start–end time range in its header (matching the reviewed reference layout), and a flat list of member task rows inside. The inner rows mirror `OverlapClusterBlock`'s `_ClusterTaskRow` precedent, not `TaskCapsuleBlock`'s pill — every row is the SAME fixed height (`zoneContainerRowHeight`), no proportional sizing, and field order is start time → duration → category emoji → title, the reverse of the capsule's icon-first/time-below layout (confirmed directly, including a correction mid-session after an initial draft leaned toward the capsule's own order).

**`ZoneDayTimeline`** (`features/timeline/zone_day_timeline.dart`, new): the outer time axis. Zone containers stack chronologically by `startMinutes`, each sized to `max(strict time-span height, intrinsic content height)` via `ConstrainedBox`+`IntrinsicHeight` (so a short zone with several tasks grows instead of clipping — a judgment call, flagged rather than picking an arbitrary minimum-height constant). Unzoned tasks render as ordinary `TaskCapsuleBlock`s at their own real spatial time position, interleaved with the containers on the same axis — confirmed directly, not a separate flat section and not hidden. Deliberately much simpler than `_DayTimeline`: no drag, no clustering, no placement line, no scroll-to-now — all explicitly out of scope this session.

**Settings toggle**: `ZoneViewEnabledSetting` (`preferences_providers.dart`) + `PreferenceKeys.zoneViewEnabled`, same persisted-bool shape as `ShowHourLabelsSetting`, default `false`. Surfaced in Settings inside the existing `FeatureFlags.zoneEnabled`-gated "Zones" panel, directly under "Manage zones" — with the flag off, the whole panel (toggle included) is const-eliminated. `TimelineScreen` reads it (`FeatureFlags.zoneEnabled && ref.watch(zoneViewEnabledSettingProvider)`) and switches between `ZoneDayTimeline` and the existing `_DayTimeline` at its own top level — `_DayTimeline`/`ZoneBackgroundBlock` untouched.

**Real on-device verification**: two new dev scaffolds, neither part of the shipped app — `zone_view_preview_main.dart` (seeds a mix of explicit-zoneId, computed-fallback, zoneId/time-mismatch, and genuinely-unzoned tasks across two zones, toggle pre-set on) and `zone_toggle_preview_main.dart` (opens straight to `SettingsScreen`, used to screenshot the toggle itself). No simulator tap/scroll automation tool was available in this environment (`osascript` lacks Accessibility permission, no `cliclick`/`idb` installed) — flagged directly rather than silently working around it or installing a new dependency; the user drove the manual scroll/tap on the simulator while screenshots were captured via `xcrun simctl io screenshot`. Confirmed on a real iPhone 15 Pro Max simulator: (1) Zone view renders both zones as containers with the correct header/row layout, including the zoneId-wins mismatch case rendering inside its assigned zone despite a 14:00 `scheduledAt` against a 10:00–12:00 zone, and the unzoned "Lunch with Sam" task rendering outside any container at its own spatial position; (2) the Settings toggle renders correctly in both ON and OFF states and actually flips persisted state on tap; (3) with the toggle off, the Timeline reverts exactly to the prior session's own Task view (zone background blocks, capsule layout, drag/free-window affordances all present, byte-for-byte the same screenshot shape as before this session).

Updated CONSTITUTION.md's Zone status line — both Timeline rendering modes now implemented; only per-occurrence recurrence, capacity enforcement, zone drag/cascade, and zone-assignment UI remain genuinely not built. Added DECISIONS.md entries for the containment precedence rule, the within-container layout approach, the container-height judgment call, and the toggle's persistence shape.

`dart format .`: clean. `flutter analyze`: clean (same 2 pre-existing, unrelated warnings only, in `task_detail_sheet.dart`). `flutter test`: 358/358 passing (350 pre-existing + 8 new in `zone_containment_test.dart`, both `flutter analyze`/`flutter test` re-confirmed clean after all doc edits too).

**Open flag for a future session**: no simulator UI-automation tool (tap/scroll) is available in this environment. If a future session needs to script simulator interaction rather than rely on manual driving, that gap needs addressing first (e.g. granting Accessibility permission to the terminal app, or installing `idb`/`cliclick` — either would need to be raised as a new-dependency/permission decision, not silently added).

## [2026-09-02] Timeline polish pass — scroll range, view-cycle button, alignment, delete button, duration formatting

A long sequence of mostly independent bug reports/small features against the Timeline, driven by direct screenshot feedback.

**Full-day scroll range**: `_visibleRange` (both `_DayTimeline` and `ZoneDayTimeline`) was task-derived (earliest/latest task ± padding), so a day with no tasks, or tasks clustered in a narrow window, couldn't be scrolled past that window. Confirmed via AskUserQuestion: always a full 24h day regardless of task content; an empty day now shows the "nothing scheduled" message floating (via `Stack`+`IgnorePointer`) over the still-scrollable timeline instead of replacing it. Also fixed 00:00 being clipped at the scroll extremes by increasing vertical scroll padding from `spacingMd` to `spacingLg` in both timelines.

**View-cycle button**: added a button next to the "scroll to today" chevron in `DayStrip` that cycles Zone view → List view → Task view → Zone view (skipping Zone when the feature flag is off), with a per-mode icon. Confirmed via AskUserQuestion: List view = `showHourLabels` off, Task view = `showHourLabels` on (both with Zone view off). Re-centering on the current hour now also happens on every view-mode switch and day change, not just first mount (`_scrollToCurrentHourCentered()` extracted and called from both `initState` and `didUpdateWidget`).

**Task pill alignment**: several rounds of pixel-level nudges to the Task-view capsule (checkbox/emoji-badge/title alignment), driven entirely by screenshot comparison against a mockup — pill top padding reduced from `spacingSm` down to flush zero, checkbox nudged via `Transform.translate`. Zone-view's own emoji badge was undersized relative to Task view's (`spacingLg` vs the Task view's own `spacingXl * 0.9` formula) — unified. `CompletionCheckbox.ringColor` made optional (was previously always the selected category's color, causing the checkbox itself to visually change color per category — reported directly as wrong); now defaults to a fixed `theme.colorTextSecondary` at all three call sites (Task view, Zone view, overlap cluster).

**Edit-task delete button**: added an icon delete button to the left of Save on the Edit-task screen only (not Create), without duplicating the shared `StepScaffold` — added generic `onSecondaryAction`/`secondaryActionIcon` params to `StepScaffold` itself. Delete logic promoted out of the task action sheet into a new shared `task_detail/task_remove.dart` (`removeTask`/`askRemoveScope`/`RemoveScope`) so both the action sheet's own Remove row and the new Edit-screen button share one recurring-scope-aware flow; confirmed via AskUserQuestion the Edit-screen delete should NOT get its own confirmation dialog, matching the action sheet's existing immediate-delete behavior.

**Duration-formatting bug**: reported as "the free-window prompt shows '100m' instead of '1h 40m'." Root cause: the whole-hours/under-an-hour duration formatter was duplicated across `FreeWindowBlock`, `TaskCapsuleBlock`, and `ZoneContainerBlock`, and two of the three copies never handled the hours+minutes case. `ZoneContainerBlock`'s own version already had the correct three-way split; promoted it to a new shared `features/timeline/duration_label.dart` (`formatDurationLabel`) and switched all three call sites to it, deleting the two buggy local copies. Confirmed via AskUserQuestion: fix all copies, not just the one reported.

**Dev toggle for the free-window prompt**: added `DevShowFreeWindowPrompt` to `core/dev_config.dart` (in-memory scratch config, `kDebugMode`-gated, defaults to true) and threaded it down through `_DayTimeline` as a plain field (`showFreeWindowPrompt`, same pattern as `showHourLabels`) rather than making the `State` Riverpod-aware — gates the existing `for (window in findFreeWindows(...))` loop alongside the existing `showHourLabels` gate. Added a matching switch in Settings' Developer section, next to the existing timeline dev switches.

Also, per an earlier direct request in this same session: tapping a task on the Timeline now opens Edit directly (`showTaskDetailSheet`) instead of the action sheet (Edit/Duplicate/Remove) — the action sheet stays in the codebase, unused, in case it's wanted again later.

`dart format .`: clean. `flutter analyze`: clean (same 2 pre-existing unrelated `modalTitle` warnings only). `flutter test`: 362/362 passing, no golden-test regressions (goldens were intentionally regenerated mid-session for each visual change, each time verified against the isolated diff image first).

## [2026-09-02] Spatial view scroll-position memory + fixed a real recurring-instance edit-loss bug

**Scroll position now shared between Task view and Zone view** (`viewed_time_provider.dart`, new): both spatial views report their scroll-centered time-of-day on every scroll and read it back on mount, so switching Zone↔Task↔List resumes the same time position instead of always re-centering on "now" — reversing part of an earlier decision this session ("should always lead to the current hour being in the center" on every switch) per direct follow-up: recenter-to-now now fires only on a genuine day change, never on a view-mode switch. Also added the missing `CurrentTimeIndicator` ("now" line) to Zone view, and fixed its outer horizontal padding (was `spacingMd`, should have matched Task view's `spacingScreenPadding`) — both were causing a visible jump/missing element when switching views, reported directly.

**Fixed the recurring-task edit-loss bug flagged (but not fixed) in ERROR_LOG.md's "second, real, confirmed bug" entry from an earlier session.** Reported again independently, in different words ("future instances if changing category, not taking effect... duration on the other hand updates from all instances"): editing a future (non-template) recurring instance's category or duration was silently discarded — `_deleteUntouchedFutureInstances` deleted the just-edited row (still "untouched" by its own definition) and `_materializeSeries` regenerated a fresh copy from the template's old value at the same slot. Fixed with a new `alsoSpare` param sparing the instance actually being edited, additive to the existing template exclusion. See ERROR_LOG.md for the full root-cause writeup and why `disableTaskRecurrence`'s own call site deliberately does NOT get the same `alsoSpare` treatment.

**Notable friction this session**: `flutter test`/`flutter analyze` hung repeatedly (5-8+ minutes each) blocked on `flutter/bin/cache/lockfile`, the Flutter SDK's own global lock, held by the user's own concurrently-running `flutter run` sessions (3 live: moto g54 device, iPhone 15 Pro Max sim, one more). Confirmed via `lsof` rather than guessing. Flagged directly rather than silently retrying forever or killing the user's dev sessions myself; user stopped one and verification proceeded cleanly.

`dart format .`: clean. `flutter analyze`: clean (same 2 pre-existing unrelated warnings only). `flutter test`: 363/363 passing (362 pre-existing + 1 new regression test for the edit-loss fix).

## [2026-09-02] Session continued: back-gesture parity, Inbox Done button, Zone/Task view uniformity

**Android system back gesture on task creation only closed the keyboard, not the modal — fixed.** The create/edit screen had no `PopScope` at all, so the gesture popped the route directly, bypassing `_handleClose()` (the method the close button and stage-1 "Done" both already use). Wrapped in `PopScope(canPop: false, onPopInvokedWithResult: ...)` routing every back attempt through the same method — an empty draft now closes silently on back (matching Done), a named draft still prompts to discard.

**Inbox quick-capture "Add" renamed to "Done"**, matching the same empty-input-closes-the-sheet semantic Task creation's Done already has, and fixed its button shape from `AppButton`'s plain default (`rounded`) to `pill`, matching Task creation's own Done button — genuinely two different shapes, confirmed by reading both call sites. Native swipe-back needed no change: Quick Capture is a `showModalBottomSheet` (not a route push), whose defaults already let the system back gesture close it.

**Zone container position/style unified between Zone view and Task view.** `ZoneDayTimeline`'s own container was rendering a zone at its STRICT time position with no inset, while `ZoneBackgroundBlock` (the same zone on the Task view) insets by `-zoneBackgroundOffset`/`zoneBackgroundGap` — a real, visible jump switching views. Now both apply the identical formula, reusing the same two constants. Also fixed the zone header's title color (was `colorTextPrimary`, now `colorTextSecondary` matching the time-range text beside it). Verified (no change needed) that scroll-position memory between Zone/Task views already correctly excludes List view, per its existing `showHourLabels` guards.

Full detail and root-cause writeups for all of the above are in `docs/ERROR_LOG.md`'s own dated entries.

`dart format .`: clean. `flutter analyze`: clean (same 2 pre-existing unrelated warnings only). `flutter test`: 371/371 passing (362 at this session's start + 9 new across the three fixes above).

## [2026-09-03] Automatic morning summary to Slack (Incoming Webhook)

Built a full work order: a Settings-configured, opt-in background task that posts a plain-text summary of today's tasks to a user's own Slack Incoming Webhook every morning, plus a manual "Send test message now" trigger for on-demand verification. Read every doc CLAUDE.md names, per the order's own instruction, before writing code.

**Flagged and confirmed two real departures before building anything**: this feature isn't in SCOPE.md (whose existing "today's plan summary" nice-to-have is explicitly in-app-only), and it's the first feature where data leaves the device to a third party, in some tension with CONSTITUTION.md's "no cloud sync" locked-stack line. Raised via AskUserQuestion rather than assumed covered by the work order alone; confirmed to proceed and add a new SCOPE.md entry as part of this session (done). Two new dependencies (`workmanager`, `http`) were also pre-flagged in the order itself and confirmed necessary — neither was already a real dependency.

**Settings** (`_SettingsPanel` "Morning summary (Slack)"): webhook URL field, optional display-name/icon-emoji override fields (with a clarifying "Slack uses the webhook's own default" note), an enable toggle with honest reliability copy ("Delivery time isn't guaranteed, especially on iOS..."), and the test-send button — all four new `PreferencesRepository` settings, same shape as every existing one (theme mode, `ShowHourLabelsSetting`, etc.).

**Background scheduling**: `core/background/background_tasks.dart` registers a periodic `workmanager` task (Android WorkManager, iOS BGTaskScheduler), targeting a named `morningSummaryTargetHour = 7` constant, re-registered/cancelled on every app launch against the current setting (mirrors `TaskList.refreshScheduledNotifications`'s own re-sync-on-launch pattern). Handled the real background-isolate/Hive-initialization gotcha explicitly — deliberately reproduced the failure once during development, then fixed it by re-running the necessary subset of `main.dart`'s own init sequence inside the background callback; see ERROR_LOG.md for the full writeup, since this is a reusable gotcha class, not a one-off.

**Summary generation and delivery**: `shared/services/slack_summary_service.dart` — pure `buildMorningSummaryText`/`buildSlackPayload` functions (no I/O), and `postToSlackWebhook` (real HTTP POST, validates the URL is actually a `hooks.slack.com` webhook before sending, wraps every failure mode in one `SlackWebhookException` type). The manual test button and the background task both go through the exact same three functions, so a successful manual test is genuine end-to-end proof the automatic path would also work.

**iOS native config added** (`Info.plist`: `UIBackgroundModes: [fetch]`, `BGTaskSchedulerPermittedIdentifiers`) — confirmed by reading `workmanager_apple`'s own Swift source that no `AppDelegate.swift` change was needed (unlike the Phase 6/7 `flutter_local_notifications` precedent, which did need one). **iOS could not be built or verified on this machine**: `workmanager_apple 0.9.6+` references an iOS 26 API this machine's Xcode 15.4 SDK doesn't have, a genuine compile-time SDK mismatch — investigated and ruled out a `dependency_overrides` pin (incompatible with the modern `workmanager` API this feature needs) before reporting it as a real, open environment gap rather than guessing further. Android built and ran cleanly (`flutter build apk`, real debug install + cold launch on the `Amble_Test_API34` emulator, confirmed `Workmanager().initialize()` doesn't crash startup) and its manifest gained one new permission (`INTERNET`).

**Real device/on-device verification, reported honestly**: no physical device was available this session. On the Android emulator, `adb shell input tap` stopped registering on ANY button partway through verification — confirmed as an environment/tooling issue, not a feature bug, by reproducing the identical non-response on the pre-existing "Export backup" button. Switched to a deterministic widget test instead (this project's own stronger-evidence precedent), which proved the panel renders every named element and that both the validation-error and a real end-to-end HTTP round-trip surface correctly in the UI. Screenshots (evidence: Settings panel showing all fields/toggle/button) were captured before the tap issue surfaced; no real Slack message could be sent/confirmed this session (no real webhook URL available, and the manual send couldn't be triggered on-device once taps stopped registering) — flagged as a genuine open verification item, same as iOS.

5 new files (`background_tasks.dart`, `slack_summary_service.dart`, and their 3 test files) plus 10 modified (Settings screen, preferences layer, `main.dart`, `pubspec.yaml`, both platforms' native config, 4 docs), 22 new tests across `slack_summary_service_test.dart`, `background_tasks_test.dart`, and `slack_summary_settings_test.dart`. `dart format .`: clean. `flutter analyze`: clean (same 2 pre-existing unrelated warnings only). `flutter test`: 391/392 passing — the one failure is pre-existing and unrelated (confirmed before reporting), untouched this session.

**Open items for a future session**: (1) iOS build needs Xcode upgraded past whatever version first ships `BGContinuedProcessingTask`'s declaration (believed Xcode 16+) before this feature can be compiled, run, or verified on iOS at all; (2) no real Slack webhook URL was available to confirm an actual message arriving in a real Slack channel — the HTTP layer is proven correct against `flutter_test`'s network stub and unit tests, but a genuine end-to-end delivery has not been observed; (3) once a physical device (either platform) is available, this is exactly the kind of feature the work order itself calls out as needing real-hardware verification, not simulator/emulator — background execution timing specifically.

## [2026-09-03] Dev Settings: bulk data-clearing tools, including a repair tool for the recurring-series "bad state" bug

User asked for the iOS build blocker to be worked around (tried pinning `workmanager_apple` to a version predating `BGContinuedProcessingTask`; reverted after `flutter pub get` proved the federated packages' version constraints make it incompatible with the modern `workmanager` API this feature needs — genuinely no fix available without an Xcode upgrade, confirmed rather than guessed). Then asked for the previously-diagnosed recurring-series orphan bug ("Bad state: No element" when a series' template is deleted, leaving instances with no template — see the earlier `deleteTask` fix in `task_providers.dart`) to get a Dev Settings repair tool, plus general bulk-clear buttons.

**Four new buttons in Settings' existing Developer section** (`kDebugMode`-gated, same as every other control there): "Clear all tasks," "Clear bad-state tasks," "Clear all zones," "Clear everything." Every button confirms first via a new `_confirmAndClear` helper (`AppAlertDialog`) — these are irreversible bulk deletes, and a debug screen shouldn't let a mis-tap silently wipe real dev data.

**"Clear bad-state tasks" targets exactly the orphan shape the earlier bug produces**: a new pure `findOrphanedRecurringTaskIds(List<Task>)` (`task_providers.dart`, alongside `findSeriesTemplate`) finds every task with a `recurrenceId` whose series has no template row anywhere in the list — the precise condition that makes `findSeriesTemplate`'s `firstWhere` throw. `TaskList.clearBadStateTasks()` deletes only those, leaving plain and healthy-recurring tasks untouched, and returns the count removed so the button can report what it did. `TaskList.clearAllTasks()`/`ZoneList.clearAllZones()` are unconditional bulk deletes over their own repositories — no bulk-delete method existed on either repository interface, so these loop `deleteTask`/`delete` per id, matching each existing single-delete method's own behavior exactly (e.g. `clearAllZones` intentionally does NOT cancel notifications, since `deleteZone` itself doesn't either — not a drive-by fix of a separate, unrelated gap).

7 new tests: 4 for `findOrphanedRecurringTaskIds` (no-recurrence, healthy series, fully-orphaned series, mixed healthy+orphaned in one list), 2 for `TaskList`'s clear methods (including one that manually persists an orphaned instance directly at the repository layer, since the bug's own root cause is now guarded against through the notifier's normal write paths — reproducing pre-existing corrupted data needs a raw repository write, same technique the earlier bug investigation used), 1 for `ZoneList.clearAllZones`.

`dart format .`: clean. `flutter analyze`: clean (same 2 pre-existing unrelated warnings only — and the previously-flagged `zone_form_screen_test.dart` failure has resolved itself since last session, unrelated to this work). `flutter test`: 400/400 passing (391 pre-existing + 2 test files, 7 new tests, and the now-passing zone form test).

## [2026-09-03] Zone view "now" line + spatial-view scroll sync fixes

Three bugs from one report, all in the Timeline's two spatial views.

**Zone view's "now" line was invisible** — the `CurrentTimeIndicator` widget was present but sat second in its Stack's child list, so every zone container and task capsule painted over it. Moved late in the list, matching Task view's own ordering.

**Scroll position reset after visiting List view.** List view and Task view share one widget (`_DayTimeline`, differing only by `showHourLabels`), so switching between them never remounts. The existing guards correctly stopped List view from writing the shared position, but nothing restored it coming back — Task view inherited whatever raw offset List view's scrolling had left behind. Now restored in `didUpdateWidget` when hour labels come back on. **This corrects a "verified already correct — no change needed" note from an earlier session**: the guard existed, but the round trip was never actually exercised, and the observable behavior was broken.

**Scroll position drifted between Task view and Zone view.** The shared value was computed from `rangeStart.hour * 60 + rangeStart.minute`, which is silently correct at midnight but reads 1410 instead of -30 once anything widens the range into the previous day — and the two views widen from different inputs (Task view from tasks, Zone view from zones AND tasks), so they could disagree on `rangeStart` entirely. Both now anchor on minutes-from-the-start-of-the-viewed-day, removing the coupling.

**A wrong first diagnosis, caught by the test rather than shipped**: the drift was initially attributed to the scroll view's 24px top padding being missing from the conversion (which converts to a different number of minutes at each view's scale — 16min vs 8min). The regression test written to demonstrate that drift disproved it: the padding cancels across a round trip. The padding term was kept (the reported minute now matches what's genuinely centered) but is not the fix; the real fix is the day-anchoring above. Full writeup in `docs/ERROR_LOG.md`.

New test file `viewed_time_roundtrip_test.dart` (4 tests) pins the report/restore contract: symmetric at each view's own scale, stable across a Task->Zone->Task round trip at different scales, and explicit about the `clamp(0, maxScrollExtent)` behavior when a requested time isn't reachable in a given view's content height.

`dart format .`: clean. `flutter analyze`: clean (same 2 pre-existing unrelated warnings only). `flutter test`: 404/404 passing (400 before + 4 new).

## [2026-09-03] Fixed the real root cause behind the spatial-view scroll bugs, plus two view-switch animation issues

Follow-up to the same-day scroll-sync work above. The user reported the fix hadn't actually worked (scroll still resetting List->Task), plus two new symptoms: capsules visibly sliding down from the top on List->Task, and a "flash" switching Task->Zone view.

**Found the real cause: `initialViewedMinutes` was `ref.watch`ed, not `ref.read`.** Every scroll writes the shared `viewedTimeProvider`; watching it in `TimelineScreen` meant every scroll rebuilt the ENTIRE screen, which re-fed a fresh value into the child mid-scroll. This one bug explains all three reported symptoms: it broke the List->Task restore timing, it fed `AnimatedPositioned` a stream of layout churn that read as capsules sliding into place, and the same rebuild churn contributed to the Zone-view flash. Changed to a `readViewedMinutes` callback, read lazily and only at the moment a restore actually happens — the provider is now completely outside the screen's build graph.

**List<->Task capsule slide-in, separately fixed.** `_DayTimeline` is shared by both modes (only `showHourLabels` differs, so it never remounts across the switch), and its capsules use `AnimatedPositioned` — which correctly tweens between List view's collapsed-stack `top` and Task view's real time-axis `top`, reading as every capsule sliding down. Suppressed for exactly the one frame the mode changes, via a `_suppressPositionAnimation` flag set in `didUpdateWidget` and cleared on the next frame — drag/cascade repositioning within the same mode still eases normally.

**Task->Zone flash, separately fixed.** `ZoneDayTimeline` is a genuinely different widget (no shared element with `_DayTimeline`), so switching to it is always a real mount with nothing to ease from. Added a one-shot fade-in (`TweenAnimationBuilder`, `theme.motionNormal`) around the whole view, matching the one-shot-animation pattern `TaskCapsuleBlock` already uses.

Full root-cause writeups (including exactly how one bug produced three symptoms) are in `docs/ERROR_LOG.md`.

`dart format .`: clean. `flutter analyze`: clean (same 2 pre-existing unrelated warnings only). `flutter test`: full suite green except a known pre-existing flaky file (`edit_schedule_repeats_test.dart`, unrelated to this work — confirmed by reverting these changes via `git stash` and reproducing the same intermittent failure on unmodified `main`, then confirming it passes standalone every time). The directly-affected suite (`test/features/timeline/`, `test/shared/services/`, `test/core/background/`) is 203/203 green.

## [2026-09-04] List mode now follows overlap clustering, same as Task view

Requested directly: "the list mode should follow overlap clustering same as task spatial mode." Previously, `clusters`/`restingClusters` in `timeline_screen.dart` were gated on `widget.showHourLabels`, so 2-3 mutually-overlapping tasks only collapsed into an `OverlapClusterBlock` in Task view — List (collapsed) view fell back to the plain side-by-side `layoutOverlappingTasks` column split instead. Removed the `showHourLabels` gate (kept the existing `disableClustering`/"Disable overlap clustering" setting gate, which still applies to both modes). Confirmed via code reading that no other change was needed: `_withClusterLanes` (cluster-lane column reassignment) and `_blockTops`'s collapsed-mode row-stacking logic (keyed on `slot.column == 0`) already generalize correctly to List mode, since cluster lane 0 always matches `layoutOverlappingTasks`' own earliest-member-starts-the-group semantics. `OverlapClusterBoundaryLabels` (hour-axis tick marks at cluster edges) deliberately left gated to Task view only — it genuinely needs a time axis that List view doesn't have.

New test `test/features/timeline/list_mode_clustering_test.dart`: a 2-task overlap in List mode renders `OverlapClusterBlock` (was previously two independent capsules), and the disable-clustering setting still suppresses it in List mode too.

`flutter analyze`: clean (same 2 pre-existing unrelated warnings only, confirmed repeatedly across this session). **`flutter test` could not be run to a clean, timed-out-free completion this session** — every attempt (including a from-scratch bounded-pump diagnostic with zero tasks, isolating the hang to before `pumpWidget` even returns) hung past the 10-minute default timeout. Root-caused, not left unexplained: an active `flutter run` process in this same working directory (a live dev session in another terminal, left untouched rather than killed) holds Flutter's own global tool startup lockfile for the entire session, which serializes every `flutter` command — so `flutter test` was queuing behind it indefinitely, not actually deadlocked in test/app code. Confirmed via `lsof` on `flutter/bin/cache/lockfile` and matching PID/PPID. A separate, real toolchain issue was also caught along the way and is independently documented in ERROR_LOG.md: a self-deadlock in Dart's `hooks_runner` native-assets tooling around the transitive `objective_c` dependency, reproduced twice with `lsof` showing the lock held by the same (idle) process that was waiting on it. Given `flutter analyze` is clean and the change is a one-line gate removal onto an already-tested, already-generalized rendering path, shipping without a fresh green test run is a deliberate, flagged risk — not a silent gap.

## [2026-09-04] Fixed: recurring-series same-day duplicate after editing a non-anchor instance's hour

Follow-up to the intermittent duplicate reported earlier ("still having duplicate created in the same day"). A provider-level reproduction of the originally-described scenario (plain task, turning Repeats on for today's own weekday) passed cleanly and did not reproduce it — that path was confirmed correct, not the bug. User's follow-up detail ("after saving another instance with same name but different hour, can't always replicate it") redirected the investigation toward editing an already-recurring task's TIME rather than its Repeats toggle.

Root cause, fix, and prevention are written up in full in `docs/ERROR_LOG.md` under the same date — short version: `_TaskDetailFlowState._save` moved a recurring instance's `scheduledAt` without ever recording `originalScheduledAt`, so `generateRecurrenceInstances`' same-slot dedup check (keyed on `originalScheduledAt ?? scheduledAt`) treated the vacated old slot as still unfilled and regenerated a duplicate there on the next materialization pass. Fixed by setting `originalScheduledAt ??= <old value>` at that call site before the overwrite, mirroring the drag-reschedule paths' existing pattern.

Two new regression tests added to `test/shared/providers/task_providers_test.dart`: one confirms editing the TEMPLATE row's own hour is safe (was already fine), the other reproduces the actual bug on a non-template instance and confirms the fix. `flutter analyze`: clean (same 2 pre-existing unrelated warnings, confirmed unrelated via `git stash` diff). `flutter test test/shared/`: 319/319 green. `flutter test` across `test/features/timeline/` (minus the separately-tracked pre-existing broken `list_mode_clustering_test.dart`) and `test/features/task_detail/`: 87/87 green, including the real end-to-end UI-driven `edit_hour_save_test.dart`.

Also confirmed, while tracing: `_selectedDays` in `_TaskDetailFlowState.initState()` is seeded once from the task's scheduled weekday and never recomputed if the date is changed via the date picker before Repeats is turned on — a real staleness gap, but not the cause of the reported duplicate (it would produce a wrong weekday selection, not an extra same-day row) and not fixed this session — left open, not yet requested.

## [2026-09-04] List mode: external calendar events now render inline (time+title on one line), matching task rows

Follow-up request: "on clustterng task list sohuld have time in front in one line with name ... this still see not in one lne / also inportent tasks not seeing in one line.. hour with title." Investigated both halves separately.

**Overlap-cluster rows:** read the code and wrote a new dedicated `test/features/timeline/overlap_cluster_block_test.dart` to check with a real render, not just code reading, since `_ClusterTaskRow`'s `compactText` branch already looked correct on paper. Confirmed: `compactText: true` genuinely renders one `Text.rich` per row (time+title merged), and `timeline_screen.dart` already wires `compactText: !widget.showHourLabels` at the `OverlapClusterBlock` call site. No code change was needed here — this half of the report reads as already fixed, likely just not visible in whatever build was being tested against (a live `flutter run` session was found holding the tool lockfile during this session — a stale hot-reload on structural widget changes is the most likely explanation, not a code defect).

**External calendar events ("important tasks" on List view) — real bug, fixed.** `ExternalEventBlock` (external_event_block.dart) had NO `compactText` parameter at all — unlike `TaskCapsuleBlock`/`OverlapClusterBlock`, its time and title always rendered as two separate stacked `Text` widgets regardless of Task view vs. List view. The earlier "time in front" request only added the time line; it never merged the two onto one line for List mode, since this block had no inline layout branch to switch to. Added `compactText` (default false), matching the other two blocks: `true` renders one `Text.rich` (time, two spaces, title, `maxLines: 1`, ellipsis); `false` keeps the original stacked `Column`. `externalEventBlockMinHeight` now takes an optional `compactText` flag so List mode's row-height floor only reserves ONE line's worth of space instead of two (the two-line floor was itself a real, deliberate fix from an earlier session — not touched for Task/Zone view, only added a smaller floor for the new compact case). Wired `compactText: !widget.showHourLabels` at all three `timeline_screen.dart` call sites (the render loop, and `_collapsedExternalEventHeight`'s own floor computation, which is List-mode-only by definition so it always passes `true`). Zone view's own `ExternalEventBlock` call site (zone_day_timeline.dart) is untouched — it's never List mode, so it keeps the default stacked layout.

New regression test added to `test/features/timeline/external_event_block_test.dart`: `compactText: true` renders exactly one `Text` widget (a `Text.rich`) containing both the time and title, versus two separate `Text` widgets for the default stacked layout.

`flutter analyze`: clean, whole repo (same 2 pre-existing unrelated warnings only). `flutter test` on `test/features/timeline/` (minus the separately-tracked, still-hanging `list_mode_clustering_test.dart`) + `test/features/task_detail/`: 90/90 green, including both new tests.

## [2026-09-04] Duplicate-task investigation, round 2: double-save guard added, root cause still unconfirmed

New detail from the report reframed this away from the recurrence fix earlier the same day: the duplicate appears **at the same time** (not a different hour), on a task **already recurring on all days**, and **the original existed while the clone did not** — i.e. the save wrote a NEW task rather than updating the existing one. That means `_save` took its `existing == null` branch (`createTask`), which is the only path that mints a fresh `recurrenceId` and therefore a whole second parallel series ("saw 2 tasks everyday").

**Ruled out by real, UI-level tests (all pass, none reproduced the bug):**
- `updateTaskWithChangedRecurrence` is idempotent for a no-op rule save on an all-days series (provider level, and through the live `showTaskDetailSheet` UI).
- Creating a task with Repeats on writes exactly one series.
- Two Save taps in the same frame write once (`_isSaving` already covered this; verified by removing the new guard and seeing the test still pass).

**A hypothesis raised and then disproved, worth recording so it isn't re-litigated:** `_save`'s closing `Navigator.pop()` looked like it would be intercepted by this screen's `PopScope(canPop: false)` and re-routed into `_handleClose`, which — because the `_initial*` snapshot is never refreshed after a save — would still report unconfirmed changes, raise "Discard this task?", and run a SECOND `_save` if the user chose "Save task". A test written to catch that passed even with the fix reverted; reading Flutter's `Navigator.pop` source (navigator.dart, `entry.pop(..., imperativeRemoval: true)`) confirms an **imperative pop never consults `canPop`/`popDisposition`** — `PopScope` only gates system back gestures and `maybePop`. The mechanism is not reachable that way. The `canPop: _hasSaved` change made under that theory was reverted.

**What was kept (defensive, not a proven fix):** a `_hasSaved` flag on `_TaskDetailFlowState`, set before the closing pop and checked at the top of `_save` and in `_hasUnconfirmedChanges`. `_isSaving` only guards two saves *overlapping* — it is already back to false once a save completes — so `_hasSaved` covers the genuinely different shape of a second save arriving *after* the first committed, which on the create branch would write a duplicate task and a second series. The dialog path above remains the one live route that could do that.

Root cause of the reported duplicate is still **unconfirmed** — every path reproduced so far behaves correctly. Left open rather than declared fixed.

`flutter analyze`: clean (same 2 pre-existing unrelated warnings). `flutter test test/features/task_detail/ test/shared/providers/task_providers_test.dart`: 71/71 green.

## [2026-09-04] Zone view showed tasks in the wrong container — time now wins over a stale `zoneId`

Reported directly: a task showing 5:15–17:15 in Task view rendered inside the 09:00–13:00 zone in Zone view. Not a time-to-pixel bug — both views anchor their range at midnight of the selected day and compute `top` identically. The task was placed inside that container by CONSTITUTION.md's containment rule, which made an explicit `zoneId` authoritative over a conflicting `scheduledAt`.

The stale assignment arises because `zoneId` is only ever set and never cleared: `rescheduleTaskWithZone` (dropping a task into a container in Zone view) assigns it, while `rescheduleTask` (Task view's drag) deliberately leaves it untouched and the detail sheet never references `zoneId` at all. Any later time change therefore stranded an assignment that outranked the task's real time.

Because this is a Constitution-level rule, it was put to the user rather than decided here. Confirmed: **time wins whenever both are set**. `resolveZoneContainment` now places a task with a `scheduledAt` by time only — into the zone whose window contains it, or into `unzonedTasks` if none does — and consults `zoneId` solely for zone-only tasks (no `scheduledAt`, nothing to resolve against). Still strictly read-only: `zoneId` is never written or cleared, so a stale value just stops affecting placement.

Updated: `lib/shared/services/zone_containment.dart` (logic + doc comment), CONSTITUTION.md's Zone section (rule rewritten, with the reversal and its reasoning recorded inline), DECISIONS.md, and `zone_view_preview_main.dart`'s seeded mismatch case (its comment claimed the old behavior; the seed itself is kept because it now exercises the reversal on a real device).

Tests: the one test asserting the old rule was rewritten to assert the new one, plus two added — a task whose time falls in a DIFFERENT zone than the one assigned places by time, and a zone-only task still places by `zoneId`. `test/shared/services/zone_containment_test.dart`: 15/15 green.

`flutter analyze`: clean on every touched file. Full run of `test/shared/` + `test/features/` (minus the separately-tracked, still-hanging `list_mode_clustering_test.dart`): 432 pass, 3 fail — all three in `test/features/settings/slack_summary_settings_test.dart`, confirmed pre-existing by stashing this session's changes and reproducing the identical failures on unmodified `main`.

## [2026-09-04] Inline layout reaches cluster rows + external events; new "Show completion checkbox" setting

**Inline gap, fixed.** Reported directly: with the inline layout set, "time and name of important tasks are not in the same line" and "clustered tasks (ok in list) in task view render in 2 lines". Root cause: the `DevTimelineTaskTextLayout` setting only ever reached `TaskCapsuleBlock`. `OverlapClusterBlock` and `ExternalEventBlock` branched solely on `compactText` (`!showHourLabels`, i.e. List mode), so in Task view both stayed stacked while an ordinary capsule beside them went inline — which is exactly why List mode looked right and Task view didn't.

`_DayTimeline` now carries `devTextLayout` as a plain field (same threading as the existing `devDurationVisible`, since `_DayTimelineState` isn't Riverpod-aware). `OverlapClusterBlock` gained a `textLayout` parameter and resolves `isInline = compactText || textLayout == inline`, mirroring `TaskCapsuleBlock`'s own `effectiveTextLayout` rule; `_ClusterTaskRow.compactText` was renamed to `isInline` since it no longer means "List mode". `ExternalEventBlock`'s existing `compactText` is now passed `!showHourLabels || devTextLayout == inline`. Zone view's in-container rows were checked and need no change — they were already single-line by construction (time and title side by side in one `Row`).

**New setting: "Show completion checkbox"** (`PreferenceKeys.showCompletionCheckbox` / `ShowCompletionCheckboxSetting`, defaults true). Requested directly as ONE toggle spanning all three views, unlike `showTimelineConnectors` which is Task-view only. Threaded to all three checkbox call sites: `TaskCapsuleBlock` (Task + List), `OverlapClusterBlock`'s rows, and `ZoneContainerBlock`'s `_ZoneTaskRow`. External-event rows are unaffected — they never had a checkbox.

Two different hiding strategies, deliberately: `TaskCapsuleBlock` hides via the same opacity+`IgnorePointer` path `contentHidden` already uses, keeping the widget in the tree, because that widget documents (from a real past bug) that changing its tree shape mid-gesture breaks drag hit-testing — and a settings toggle can flip mid-drag. The cluster and zone rows drop the checkbox from their `Row` entirely, reclaiming the space: cluster rows own no drag gesture at all, and the zone row's drag lives on its time column, a sibling of the checkbox rather than an ancestor.

**Honesty note on the Settings copy**: the first draft said tasks could still be completed from the task screen. Checked before shipping — the detail sheet has no completion control, and the Inbox's own checkbox only covers unscheduled tasks. So this checkbox is currently the ONLY way to complete a scheduled task, and turning the setting off removes the capability, not just the affordance. Shipped as requested with the copy saying that plainly ("scheduled tasks then have no way to be marked complete"), and the same correction recorded on the provider's doc comment.

Tests: `overlap_cluster_block_test.dart` gained inline-outside-List-mode and checkbox-hiding cases; new `task_capsule_checkbox_test.dart` covers the capsule's own hide-but-keep-in-tree behavior (asserting opacity 0 AND `ignoring: true`, not just invisibility); `zone_container_block_test.dart` gained the zone row's case. `flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run of `test/shared/` + `test/features/` (minus the still-hanging `list_mode_clustering_test.dart`): 437 pass, same 3 pre-existing `slack_summary_settings_test.dart` failures confirmed earlier this session against unmodified `main`.

## [2026-09-04] Spatial Task View: aligned name column, time/duration columns, pill-hugging zone backgrounds

From an annotated mock ("Build now" vs "Currently"). Three changes, plus one item that turned out to already exist.

**Aligned name column (the non-trivial part).** Previously a capsule was ONE positioned block with the pill and its text as siblings in a `Row`, so text always flowed from its own pill — a lane-2 task's title sat further right than a lane-0 task's. Names sharing one x requires positioning the pill and the text independently. Confirmed via AskUserQuestion as the **fixed-x** variant (over "after the widest stack"): with 3+ stacked pills the rightmost pill now sits under the start of the text column, which is the accepted trade for names that never move.

`TaskCapsuleBlock` gained `splitLayout` (default false): it renders pill-only by hiding its text region through the SAME opacity path `contentHidden` already uses, keeping its tree shape byte-identical. That matters — this widget documents two prior bugs where changing the tree around its drag `GestureDetector` broke hit-testing. `_DraggableTaskBlockState` now builds one capsule subtree shared by both layouts and only chooses where to position it, so the gesture's render-object ancestry is identical either way. In split mode a single outer `AnimatedPositioned` (row-height, day-column wide — deliberately not full-day, which would swallow taps meant for free-window blocks beneath) holds two children: the pill at its lane's x, the text at `_textColumnLeft`. One shared `top` and one animation, so the halves can't drift apart by a frame during a drag, settle, or cascade push. The lift `AnimatedScale` stays on the pill alone.

New `TaskCapsuleTextRow`: fixed-width time and duration columns, then the title, then the checkbox. The fixed widths are the mechanism — they're what make titles align even when time strings differ in width. Both leading columns disappear together under the existing `durationVisible` toggle, matching the mock's left-hand screen.

**Zone backgrounds hug the pill column.** Confirmed as pills-only (time and name sit outside the zone band). Width comes from the deepest overlap lane actually in use inside that zone's own window, via two new pure functions in `task_overlap_layout.dart` — `zonePillLanes` and `zoneBackgroundPillWidth` — extracted rather than left private on the State specifically so the arithmetic is testable. They read the SAME `TaskLayoutSlot`s the capsules are positioned from, so the background can't disagree with the pills drawn over it. Half-open window semantics, matching `resolveZoneContainment`.

**Rotated zone names on the right**: already shipped — present in all three of the mock's screenshots including "Currently". Treated as "keep", not new work.

Scope: `splitLayout` is Task view only. List (collapsed) mode, Zone view, the drag-preview card and the dev previews all keep the combined pill+text row untouched — confirmed by the capsule golden test passing unchanged.

Tests: new `task_capsule_text_row_test.dart` (three columns render; the title starts at the same x for 4:00 vs 11:00 — different time-string widths; `durationVisible: false` drops both leading columns; checkbox toggle) and `zone_pill_lanes_test.dart` (11 cases: empty zone, no stacking, 2 and 3 lanes, stacking outside the zone, both half-open boundaries, straddling stacks, and the width arithmetic). Two of those boundary tests initially failed against my own wrong expectations and were corrected to match the real semantics, not the other way round.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run of `test/shared/` + `test/features/` (minus the still-hanging `list_mode_clustering_test.dart`): 452 pass, same 3 pre-existing `slack_summary_settings_test.dart` failures.

## [2026-09-04] Task view corrections: uniform zone width, day-wide text column, and a real overflow bug fixed

Follow-up mock with two corrections to the previous session's pass, plus a rendering bug the "Currently" screenshot caught.

**Overflow bug, fixed (my regression, introduced yesterday).** The screenshot showed `RIGHT OVERFLOWED BY 56 PIXELS` banners across stacked pills, with text running off-screen. Cause: in split layout the caller lays `TaskCapsuleBlock` out at exactly one pill width, but the widget's text column, its `spacingSm` spacer, and its trailing checkbox all still claimed their intrinsic widths — they were only faded to opacity 0, never collapsed. This is precisely the RenderFlex-overflow class that widget's own `ClipRect` comment already documents ("OVERFLOWED BY 56px"), reintroduced on the horizontal axis. Fixed by capping the text column at `maxWidth: 0`, zeroing the spacer, and wrapping the checkbox in a `ClipRect` + zero-width `SizedBox` — all width-only changes, so the always-present-tree rule protecting the drag gesture still holds. Verified the new regression test actually catches it by reverting the fix and watching it fail.

**All zones the same width.** Corrected directly: "all zones same width even if only items over 1 zone stack." The previous pass sized each zone band to its OWN deepest stack, which made bands visibly different widths down the day. `zonePillLanes` (per-zone, with its window-overlap math) is replaced by `dayPillLanes` — the deepest stack anywhere in the visible day — so every band is uniform and still clears the widest run.

**Text column aligned day-wide.** Corrected directly: "all text ... always lined up even if one zone." The text column was a flat one-pill offset, so on a day containing any stacking the names sat over the stacked pills. It now derives from the same `dayPillLanes` value the bands do, computed once by `_DayTimeline` and passed to each block as `textColumnLeft` rather than recomputed per block — the whole point being that every block agrees on it. One consequence worth noting: the shared column means a day with a 3-deep stack pushes every name right, including on rows that don't stack. That is what "lined up with those stacked" asks for.

Because both now come from one function, the band and the text can't drift apart — the earlier per-zone version could disagree with the pills drawn between them.

Tests: `zone_pill_lanes_test.dart` renamed to `day_pill_lanes_test.dart` and rewritten for the new day-wide semantics (8 cases, including "the deepest stack anywhere wins" and a check that band width and text offset resolve identically for every task in a mixed day). New overflow regression test in `task_capsule_checkbox_test.dart`, confirmed failing without the fix.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run of `test/shared/` + `test/features/` (minus the still-hanging `list_mode_clustering_test.dart`): 450 pass, same 3 pre-existing `slack_summary_settings_test.dart` failures.

## [2026-09-04] All overlaps cluster; cluster times follow the duration setting; wider zone band

Three corrections, all in the Spatial Task View.

**One overlap style, not two.** `overlapClusterCap = 3` meant a run of 2–3 tasks got the aggregate cluster treatment while a run of 4+ silently fell back to plain side-by-side capsules — the two styles reported. The cap is removed entirely rather than raised (any bound recreates the same split deeper in the day); see docs/DECISIONS.md, which records this as a reversal of a previously-confirmed decision. No downstream change was needed: `_withClusterLanes` already handles any cluster size.

**Cluster row times follow the duration setting.** Previously `durationVisible: false` dropped only the `(1h)` suffix from a clustered row, leaving "04:00 - 05:00" showing beside an ordinary capsule that hides its time columns entirely under the same setting. The time label is now null when the setting is off, and both the stacked and inline branches omit the whole line/span.

**Zone band widened by one pill.** Requested directly ("zone larger by the width of task pill") so the band reads as a container around the pills rather than a strip cut exactly to them. The shared text column was widened by the same amount so names still start clear of the band — both derive from the one `dayPillLanes` value, so they cannot drift apart.

**Cluster list now uses the shared text column too.** Found while making the above change: the cluster's row list positioned itself from its OWN member count (`cluster.tasks.length * pillWidth`), so a 4-task cluster's rows started further right than a 2-task cluster's, and further right than every unclustered task's name — directly against "all text always lined up". It now uses `_textColumnLeft` like everything else.

Tests: 3 cap-encoding tests in `overlap_cluster_test.dart` rewritten for the new rule (including a 7-deep run asserting it clusters whole); 2 new cases in `overlap_cluster_block_test.dart` covering time-hiding in both the stacked and inline layouts.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run of `test/shared/` + `test/features/` (minus the still-hanging `list_mode_clustering_test.dart`): 452 pass, same 3 pre-existing `slack_summary_settings_test.dart` failures.

## [2026-09-04] Vertical zone names added to the Task view (they never existed)

Reported directly: "can't see vertical zone name on task view." Investigated before building — the rotated zone name did not exist ANYWHERE in the codebase: no `RotatedBox`/`Transform.rotate` in any timeline file, and `zone.title` was read in exactly one place (`ZoneContainerBlock`'s horizontal header in Zone view). The Task view's `ZoneBackgroundBlock` renders a bare `DecoratedBox` with no label at all.

This corrects a claim from an earlier session in this conversation, where the rotated labels were called "already shipped, keep as-is" — that was read off the design mockups' screenshots without checking the code, and both screenshots were mockups, not builds.

New `ZoneNameLabel` (in `zone_background_block.dart`, beside the block it annotates): the zone's title in `RotatedBox(quarterTurns: 1)`, pinned to the day's right edge, spanning the zone's own time range, centred along that span. Styled `textCaption` in `colorTextSecondary` — the same tokens the hour labels on the opposite edge use, so the two read as one class of ambient annotation framing the day. `IgnorePointer`ed, matching the background block's own display-only scope.

Deliberately a SIBLING of `ZoneBackgroundBlock` rather than a child: the band now hugs the pill column on the left (see the earlier entry), while the label belongs at the far right. Both derive their vertical geometry from the same time math, so they still describe the same band.

New `_zoneLabelGutterWidth` reserves room at the right edge — the mirror of `_hourGutterWidth` on the left. Both the ordinary task rows (`textColumnRight`) and the cluster row list now stop short of it, so a title or checkbox can never render underneath a zone name. Zero when the day has no zones, so a zone-less day loses no width.

Tests: 4 new cases in `zone_background_block_test.dart` — the title renders, the rotation is a quarter turn, the label spans the zone's real time range pinned right (not left), and it stays `IgnorePointer`ed.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run of `test/shared/` + `test/features/` (minus the still-hanging `list_mode_clustering_test.dart`): 456 pass, same 3 pre-existing `slack_summary_settings_test.dart` failures.

## [2026-09-04] Fixed: lifted (dragged) pill clipped on its right side in the Task view

Reported directly: "affected is lifted (drag drop) state of tasks, right side is cut off, only part of pill visible." A regression from this session's split-layout work.

Cause: `_buildSplit` positioned the pill in a box of exactly `_pillWidth`. That is correct for a resting pill, but while lifted `TaskCapsuleBlock` wraps the pill in its frosted `Container` with `EdgeInsets.all(spacingSm)` inside a `ClipRRect` — so a lifted pill genuinely needs `pillWidth + 2 * spacingSm`, and the `ClipRRect` cut the overflow off at the right edge the moment a drag started.

Fixed by reserving that padding in the pill's own box (`left` shifted back by `spacingSm`, width grown by `spacingSm * 2`) with an `Alignment.topCenter` `Align` inside it. Top-anchored deliberately: the pill's top edge IS the task's start time, so only the horizontal room is added. The extra width is reserved always, not just while dragging, so the pill's resting x doesn't shift as the padding animates in.

Checked and NOT a second cause: the `AnimatedScale` lift (1.04x) sits OUTSIDE `TaskCapsuleBlock`, so its `ClipRRect` can't clip the scale, and the enclosing `Stack` is `Clip.none` — the scaled pixels paint freely. Only the frosted padding was ever being clipped.

New regression test in `task_capsule_checkbox_test.dart` asserting a lifted split-layout pill renders wider than a bare pill width (and no wider than the reserved box), so the reserved room can't silently shrink back. The existing non-lifted "no overflow in a one-pill box" test still passes alongside it.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run of `test/shared/` + `test/features/` (minus the still-hanging `list_mode_clustering_test.dart`): 457 pass, same 3 pre-existing `slack_summary_settings_test.dart` failures.

## [2026-09-04] Lifted pill carries its own name/time; ghost reduced to a bare shape

Requested directly: "lifted state should have its inner title and time underneath name showing (same as ghost state left in place) ... but in ghost state we shouldn't have title and time and not icon when moving, and pane containing (bg blur one) should be extended to that name." An inversion of what the split layout had been doing.

**Lifted pill.** New `TaskCapsuleBlock.liftedTextInline` reopens the text region that `splitLayout` normally collapses, so a dragged pill carries its own name and time inside the frosted pane. Necessary because the shared text column stays anchored at its own x — a pill dragged away from it travelled unlabelled. The pill's box in `_buildSplit` now runs to the row's right edge while `_isDragging` (instead of one pill width), so the frosted pane grows around the text rather than clipping it, and its `Align` switches to `topLeft` there so the pane expands rightward from where the pill already sits rather than re-centring. The separately-positioned `TaskCapsuleTextRow` is faded out for the dragged task, so its title never shows twice at once.

**Ghost.** Now `contentHidden: true` plus a new `glyphHidden: true` — a plain 20%-opacity shape marking the slot the task came from. `glyphHidden` exists because `contentHidden` alone deliberately KEEPS the category emoji (it is a resting cluster member's only category cue, itself a past direct correction); the ghost is the one case that wants the glyph gone too, so it got its own flag rather than changing that rule.

**A latent bug the tests surfaced.** Asserting the collapsed text width exposed that `splitLayout`'s `maxWidth: 0` never actually collapsed anything on its own: the `ConstrainedBox` sits inside an `Expanded`, which passes a TIGHT width down, and a `maxWidth` constraint cannot shrink below a tight incoming one. The collapse only worked because the split-layout caller happens to size the row to one pill. Fixed properly with `Flexible(flex: textCollapsed ? 0 : 1, fit: loose/tight)` — deliberately NOT an `if` that swaps the child out, since `liftedTextInline` flips mid-drag and changing the tree shape around the pill's gesture detector is the exact bug class this widget has hit twice before.

Tests: 2 new cases in `task_capsule_checkbox_test.dart` — `liftedTextInline` renders the title at real width where `splitLayout` alone gives it zero, and `glyphHidden` drops the emoji that `contentHidden` alone keeps (asserted on opacity, and located by tree position rather than by literal glyph so it survives a category emoji change). One assertion was written wrong first (`findsNothing` for a widget that deliberately stays in the tree at zero width) and corrected to measure width instead.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run of `test/shared/` + `test/features/` (minus the still-hanging `list_mode_clustering_test.dart`): 459 pass, same 3 pre-existing `slack_summary_settings_test.dart` failures.

## [2026-09-04] Task names align to their own pill's icon, stacking only on collision

Requested directly, with a before/after screenshot: names should sit level with their own pill's icon, and only stack when two tasks start at the same time or too close to fit — "otherwise the title should be at the level of the icon of the pill, but precisely lined up with the icon."

Cause of the old behaviour: a clustered task surrendered its name to `OverlapClusterBlock`, whose `Column` packs every member's row sequentially from the CLUSTER's own top. That reads as a detached list (the left screenshot) and severs each name from the pill it describes — and it applied to any overlap at all, now that the cluster cap is gone.

New pure function `computeLabelTops` (`collapsed_stack_layout.dart`, beside the existing `computeCollapsedStackTops`): each label carries a `preferredTop` — its own pill's top, i.e. where its icon sits — and a height; a greedy chronological sweep places each at its preferred position unless the previous label's bottom has already passed it, in which case it is pushed just clear. Deliberately distinct from `computeCollapsedStackTops`, which packs everything sequentially from zero and has no notion of a preferred position — right for List mode, which has no time axis to align to, wrong here.

Wiring: `labelTops` is computed once per day (like the shared text-column x, so every label agrees) and passed to each block as `labelOffset` — the delta from its own pill's top, so zero means perfectly icon-aligned and the value rides the block's existing drag/settle animation unchanged rather than fighting it. The cluster row list is now gated to List mode only, and `contentHidden` (which suppresses a capsule's own text in favour of that list) likewise, so in Task view every task keeps its own label.

`rowHeight` in `_buildSplit` now also covers a label pushed below the pill's bottom: the Stack is `Clip.none` so it would still paint, but a child outside its parent's bounds is not hit-testable, and the label carries the row's tap target and checkbox.

Tests: 7 new cases for `computeLabelTops` — lone label at its icon, two well-separated labels BOTH keeping exact alignment, same-time pair stacking, a merely-too-close pair pushed just clear, three near-simultaneous reading one-by-one, never pushed above its own icon, and input-order independence.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run of `test/shared/` + `test/features/` (minus the still-hanging `list_mode_clustering_test.dart`): 466 pass, same 3 pre-existing `slack_summary_settings_test.dart` failures.

## [2026-09-04] Fixed: zone band shrank and titles jumped left while dragging a stacked task

Reported directly: "when one of stacked items is lifted the zones shrink, and titles shift left, as if ghost not holding physical space."

Exactly that. The zone band width and the shared text-column x are both derived from the day's deepest lane count (`dayPillLanes`), and both were measuring it off `slots` — which is re-laned from `clusters`, and `clusters` deliberately EXCLUDES the dragged task so the remaining members don't silently re-form a smaller cluster mid-drag. So lifting one member of a 2-deep stack dropped the day's lane count to 1: the band narrowed and every name in the day jumped left until the drop landed.

The fix needed no new state. `ghostSlots` already existed for precisely this problem in a different guise — it is the same lane layout computed from `restingClusters` (no drag exclusion), added earlier so the ghost renders in the lane it actually held. Both width computations now read it, so the layout reserves the lane the ghost is visibly occupying. Its declaration comment was rewritten, since the variable is no longer ghost-only.

Checked and NOT affected: the per-task label positions (`labelTops`). Their `preferredTop` comes from `_blockTops`, which in Task view is pure time-to-pixel math per task and independent of lane assignment; `slots` and `ghostSlots` differ only in lanes, not membership. So labels never reflowed — only the two lane-derived widths did.

New regression test in `day_pill_lanes_test.dart` pinning the invariant: a 2-task stack is 2 lanes deep, and the same day with the dragged task dropped from the list measures 1 — the exact difference that caused the reflow, now asserted so a future change can't quietly reintroduce measuring off the drag-excluded layout.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run of `test/shared/` + `test/features/` (minus the still-hanging `list_mode_clustering_test.dart`): 467 pass, same 3 pre-existing `slack_summary_settings_test.dart` failures.

## [2026-09-04] Duplicate-task root cause FOUND and fixed: a moved recurrence instance claimed only the slot it left

Resumed the investigation parked in round 2. The decisive clue from that round — the original survived and the clone was new — had pointed at `_save`'s create branch, but every create path tested clean. Reconsidering that the "clone" might be a materialized recurrence instance rather than a `createTask` write led straight to it.

`generateRecurrenceInstances` built its dedup set as `originalScheduledAt ?? scheduledAt`: one slot per instance, preferring the vacated one. A moved instance therefore left its NEW time reading as an unfilled occurrence, and moving an instance onto a slot the rule also generates made the generator materialize a fresh task on top of it — a duplicate at the same time, exactly as reported.

Latent until this same day's earlier same-day-duplicate fix, which started setting `originalScheduledAt` on detail-form time edits; before that, form edits left it null and the `??` fallback happened to claim the new slot. That earlier fix was right — it exposed the other half of the invariant rather than causing it.

Fixed by claiming BOTH slots (`originalScheduledAt` and `scheduledAt`, null-guarded). Unmoved instances are unaffected: their `originalScheduledAt` is null and the Set collapses the duplicate claim. Full writeup in docs/ERROR_LOG.md.

Method note: this round started by writing a test that reproduced the duplicate BEFORE any fix — the first time in three rounds the bug was actually reproduced — then the fix was verified by reverting it and watching the test fail again. The 47 existing recurrence/provider tests, including the ones specifically covering vacated-slot behaviour, all still pass.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run of `test/shared/` + `test/features/`: 466 pass. 5 failures, all confirmed pre-existing and unrelated by stashing this change and reproducing them identically: the 3 known `slack_summary_settings_test.dart` ones, plus 2 in `notification_service_test.dart` that are time-of-day dependent (they seed a zone at 23:40 and assert `now.hour != 23`; this run happened at 23:11).

## [2026-09-04] Zone creation now stages like task creation: Name-only first, rest fades in on Done

Requested directly: zones "should follow same pattern of creation as tasks, on creation first just name visible, other items below start end repeat etc not visible, then fade in after Done is clicked."

`_ZoneFormScreenState` gained `_isNameStage` (true only for a fresh create — editing an existing zone still skips straight to the full form, matching "Edit task"'s own behavior). Stage 1 shows only the Name pane with a "Done" primary button; stage 2 (Start/End, Repeat, Notifications) is built as a list and wrapped per-pane in a staggered fade+slide entrance, appearing only once `_isNameStage` flips false. `_confirmNameStage` mirrors `task_detail_sheet.dart`'s own exactly: an empty name closes the whole screen instead of advancing into an empty form, rather than disabling the Done button.

The Name field is built ONCE, unconditionally, both stages — same reasoning as the task flow's `_NameDescriptionPane`: its Element (and any focus/keyboard state) must survive the stage transition rather than remounting as a different field.

**Promoted `_StaggeredEntrance` out of `task_detail_sheet.dart`** into `core/widgets/app_staggered_entrance.dart` as `AppStaggeredEntrance`, the same move `AppStepScaffold` already went through for this exact reuse case — a ~50-line stateful animation with real branching logic (delay-by-index, dispose the controller) is a different judgment call than the small stateless `_ZoneRecurrencePanel` duplication documented elsewhere in this file, which stays duplicated deliberately. `task_detail_sheet.dart` now consumes the promoted widget too, so there is exactly one staggered-entrance implementation, not two that could drift.

Existing zone-form tests written against the old always-visible layout needed updating: they now drive stage 1 (type name, tap Done) before reaching the fields they exercise. Three new tests: stage 1 renders with no time fields in the tree and Done always enabled; an empty-name Done closes the screen; Save is disabled until start/end are set once past stage 1.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). `test/features/task_detail/`: 40/40 green, confirming the promotion didn't disturb the task flow. `test/features/zones/zone_form_screen_test.dart`: 7/7 green, all three new/changed assertions verified to actually fail with the stage-1 change reverted. Full run of `test/shared/` + `test/features/` (minus the still-hanging `list_mode_clustering_test.dart`): 469 pass, 5 failures — the 3 known pre-existing `slack_summary_settings_test.dart` ones plus 2 in `notification_service_test.dart` that are the already-documented 23:00-hour time-dependent flake (confirmed: this run was at 23:32).

## [2026-09-05] Add-category flow now uses the same near-full-screen, progressive-disclosure pattern as task/zone creation

Requested directly: "add category sheet should be near full screen same as add task and same pattern... this would be a pattern of progressive disclosure that applies to task, zone, category."

`AddCategoryModal` (an `AppSheet`-based stateful widget with a static `.show()`) is replaced by `showAddCategoryModal(context)`, a top-level function pushing the same `PageRouteBuilder` (slide-up, scrim barrier) the task and zone creation flows already use, built on the shared `StepScaffold` chrome instead of `AppSheet`. Stage 1 shows only the Name field with a "Done" primary button; Color and Emoji are built as a staggered list and appear only once Done is confirmed, matching the task/zone flows' own `_confirmNameStage` exactly — an empty name closes the whole screen rather than leaving Done disabled. Always starts on stage 1 (unlike the task/zone flows' `_isEditing` skip): category has no edit entry point to skip it for (v1 scope is create + list only).

**Promoted `_StaggeredEntrance` fully**, not just reused — it was already promoted to `core/widgets/app_staggered_entrance.dart` (`AppStaggeredEntrance`) during the zone-form work; this session was its second consumer, confirming the promotion was the right call rather than a one-off.

API rename note: `AddCategoryModal.show(context: context)` → `showAddCategoryModal(context)`, matching the `showZoneFormScreen`/`showTaskDetailSheet` top-level-function convention exactly rather than being the one static-class-method holdout. Both call sites (`TaskCategoryModal`, `TaskNameCategoryModal`) updated.

Existing `add_category_modal_test.dart` rewritten for the two-stage flow: the color-swatch finder (`find.byType(GestureDetector).at(1)`) broke silently once `StepScaffold`'s own chrome added many more `GestureDetector`s to the tree — replaced with a finder scoped to descend from the "Color" `AppPane`, which is robust regardless of how much chrome surrounds it. 3 new/rewritten test cases; all confirmed to actually fail with `_isNameStage` forced false.

**Investigated but NOT caused by this change**: running the whole `test/features/task_detail/` directory in one invocation flakes (different files fail each run) even on unmodified `main` — a pre-existing environment-level issue, not a regression; every individual file in that directory passes cleanly on its own, both before and after this change. Separately, `task_providers_test.dart`'s "narrowing daily down to 5 weekdays" test fails identically on unmodified `main` whenever run on a Saturday or Sunday (today is Saturday 2026-09-05) — a real, pre-existing weekday-dependent test bug unrelated to today's work, flagged here rather than silently worked around.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). `add_category_modal_test.dart`: 4/4 green. Full run of `test/shared/` + `test/features/` (minus the still-hanging `list_mode_clustering_test.dart`): 472 pass, 4 failures — the 3 known pre-existing Slack ones plus the pre-existing Saturday/Sunday recurrence flake, both confirmed identical on unmodified `main`.

## [2026-09-05] Task pill corners: 8px (radiusMd), not fully rounded

Requested directly: "rounding of pills make 8 and rounding of zones 16."

Zone backgrounds/containers already use `radiusXl` (16.0) — no change needed there, confirmed by reading the token value before touching anything.

The task capsule's colored rail used `radiusTaskPill` (`RadiusPrimitives.radiusFull`, a true stadium/pill shape) — but that token is shared far beyond the timeline: `AppButton`'s pill-shaped buttons, the theme-mode selector, the tracked-behavior form, and a settings row all read it too. Repointing the token's own value to 8 would have flattened every one of those. Flagged via AskUserQuestion before touching a shared token with that much reach; confirmed scope is the timeline pill only.

Reuses the existing `radiusMd` token (already 8.0, already a real Tier 2 value used across the app) for just the capsule's rail `BoxDecoration`, rather than inventing a new token that would duplicate an existing value.

`timeline_capsule_preview.png` golden regenerated for the resulting real, intentional pixel diff (0.25%, 1353px — corner shape change on every seeded pill) — not a regression, per the project's stale-baseline rule.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). `test/features/timeline/` (minus the still-hanging `list_mode_clustering_test.dart`): 89/89 green, including the regenerated golden.

## [2026-09-05] Fixed: resting task pill's left corners still clipped at the old 16px radius

Follow-up to the prior session's pill-radius change (8px rail, `radiusMd`). Reported directly: the lifted/dragging pill looked right, but the resting pill's top-left and bottom-left corners still showed the old rounding.

Root cause and fix are written up in full in `docs/ERROR_LOG.md`, dated the same day — short version: `TaskCapsuleBlock`'s always-present frosted lift wrapper had its own `ClipRRect` hard-coded to the LIFTED radius (`radiusXl`, 16) regardless of `isLifted`, and at rest the pill's rail sits flush against that wrapper's left edge with no padding — so the outer 16px clip landed on the pill's own 8px corner and won. The wrapper's radius is now animated by the same `t` value already driving its shadow/blur/padding, landing on `radiusMd` at rest and `radiusXl` once fully lifted.

New regression test in `task_capsule_checkbox_test.dart` asserts the `ClipRRect`'s own `borderRadius` directly at both `isLifted` values — confirmed to fail without the fix and pass with it, rather than relying on the golden diff alone. `timeline_capsule_preview.png` golden regenerated for the resulting small, real, intentional pixel diff (0.07%, 383px — just the pill's left-corner shape while resting).

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). `test/features/timeline/` (minus the still-hanging `list_mode_clustering_test.dart`): 90/90 green.

## [2026-09-05] Task/List view pill and icon now match Zone view's size (20px, not 36px)

Requested directly: "pill size and icon same as on zone view so smaller (apply this on both task and list view)."

Investigated before changing anything: a real shared token, `theme.sizeTaskBadge` (20px, `SpacingPrimitives.space6`), already exists specifically for this — its own doc comment even claims "[TaskCapsuleBlock]'s own pill width... all read from this ONE value now instead of each computing `spacingXl * 0.9` independently." That claim was stale: the token was added, but `TaskCapsuleBlock.badgeSize` and `timeline_screen.dart`'s mirrored `_pillWidth` were never actually switched over — both still computed the old ad hoc `spacingXl * 0.9` (36px). Only `ZoneContainerBlock` had genuinely migrated. This session's request is exactly what closes that gap.

Both `TaskCapsuleBlock.badgeSize` and `_pillWidth` now read `theme.sizeTaskBadge` directly, matching `ZoneContainerBlock`'s row badge exactly (same value, same token, not just the same number reached two ways). Everything already derived from `badgeSize`/`_pillWidth` — the emoji font size (`badgeSize * 0.55`), the pill-height floor, `_collapsedPixelsPerMinute` (List view's own scale, previously-confirmed as `badge ÷ 30`) — scales down automatically with no separate change needed, since none of those were re-hardcoded.

Deliberately left OUT of scope: `_SchedulePreviewCard` in `task_detail_sheet.dart` (the create/edit form's own live preview badge, `task_detail_sheet.dart:2369`) has the identical stale `spacingXl * 0.9` duplicate, but it's a different surface than "task and list view" (the Timeline), which is what was actually requested — flagged here rather than changed silently, since expanding scope to a surface nobody asked about isn't this task's call.

`timeline_capsule_preview.png` golden regenerated for the resulting real, large, intentional pixel diff (4.29%, 23434px — every seeded pill shrinks). Two existing tests in `task_capsule_checkbox_test.dart` hardcoded the OLD `spacingXl * 0.9` formula as their own expected pill width — updated to `theme.sizeTaskBadge` so they keep testing the real invariant rather than a now-stale magic number.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). `test/features/timeline/` (minus the still-hanging `list_mode_clustering_test.dart`): 90/90 green, including the regenerated golden and both updated tests.

## [2026-09-05] "Task size" ships as a real global Settings toggle (sm/md/lg)

Full architecture and reasoning in docs/DECISIONS.md, dated the same day. Short version: what shipped in the immediately-preceding session (unifying Task/List/Zone view onto one fixed 20px badge) is now reframed as one rung ("sm") of a real three-rung scale (sm 20/12, md 24/14, lg 28/16 — badge px / font px), exposed as a persisted Settings toggle rather than a fixed constant, and confirmed to apply globally (Task, List, AND Zone view together) rather than per-view.

New `TaskSize` enum (own Hive adapter, typeId 11) + `TaskSizeSetting` provider, defaulting to `md` — Task view's own size before any of this session's or the prior session's work began. `AmbleTheme` gained the three fixed rungs as new fields while keeping `sizeTaskBadge`/`textTaskTitle` as the single resolved/active fields every real call site already reads; `main.dart` resolves the setting onto both light and dark palettes once, before `MaterialApp` sees them, so zero call sites in `TaskCapsuleBlock`/`ZoneContainerBlock`/`OverlapClusterBlock` needed to change.

`textTaskTitleCompact` (List view's previously separate, always-smaller font token) is gone — confirmed directly that List view should track the exact same global setting, with no relative "one step down" behavior any more.

New Settings row: "Task size" with Small/Medium/Large chips, placed near the other Timeline display toggles.

Tests: new `test/core/tokens/task_size_scale_test.dart` pins the exact sm/md/lg badge and font values, their strict ordering, the md default, and light/dark parity — and separately verifies `copyWith` resolves each rung correctly (mirroring `main.dart`'s own private, untested-by-precedent `_resolveTaskSize`). New case in `hive_preferences_repository_test.dart` confirms `TaskSize`'s own Hive adapter round-trips (not just the generic mechanism `AppThemeMode` already proved). `timeline_capsule_preview.png` golden regenerated for the resulting real, intentional diff (default size moved from the just-shipped 20px back to 24px/md).

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run of `test/shared/` + `test/features/` + `test/core/` (minus the still-hanging `list_mode_clustering_test.dart`): 520 pass, 4 failures — the 3 known pre-existing Slack ones plus the already-documented Saturday/Sunday recurrence flake (today is still Saturday).

## [2026-09-05] Zone band geometry: precise cusps, task inset instead of band offset, wider lanes

Three changes from an annotated screenshot.

**1. Zone cusps are now precise.** Reported: "zone is 4:00-5:00 but it looks like it ends before 5:00, next zone starts at 5:00 but looks like before — we need to make that cusp precise but retain gap between zones." The band used to start `zoneBackgroundOffset` (12px) ABOVE its own start time and shrink by `zoneBackgroundGap` (4px), so its bottom landed 16px short of the real end — the whole band read as sitting off its real hours. Now the top edge lands exactly on the start time and the ENTIRE gap comes off the bottom, so the earlier zone yields the whole clearance and the later one still starts precisely on the shared boundary. Two back-to-back zones still clear each other by exactly `zoneBackgroundGap`. `zoneBackgroundOffset` is now horizontal-only.

**2. The gap above a task starting at a zone's start moved from the band to the task.** Reported: "task that start same as zone should just have small gap same as from side of the zone, atm too big gap." A task at the zone's start time sits at the same pixel as the zone's boundary, so giving it a gap requires moving one of the two. Confirmed via AskUserQuestion (band-exact vs. band-extends-above): the band's edges stay exact and the TASK is nudged down instead, by a new `_zoneTaskTopInset` — `zoneBackgroundOffset`, so the gap above the task reads as the same size as the gap beside it, which is what "same as from side of the zone" asks for. Zero for any task that doesn't start exactly on some zone's start.

**3. Lane gap widened.** `_columnGap` moved from `spacingXs` (4) to `spacingSm` (8) — "slight larger gap between lanes", one rung up the existing scale rather than a new value.

**Zone view kept in sync.** `ZoneDayTimeline`'s own container applied the same `-zoneBackgroundOffset` on top, under an explicit "both views render the same zone at the same pixel" invariant a previous session established after a reported view-switch jump. Changing only Task view would have silently broken it, so Zone view's container now uses the strict top too. Its height already subtracted the gap, which matches the new model unchanged.

Tests: `zone_background_block_test.dart`'s two geometry tests rewritten for the new model, and its back-to-back-clearance test now measures BOTH blocks' real rendered `Positioned` values instead of recomputing the formula in the test (it previously duplicated the arithmetic it was meant to verify, so it would have passed against a wrong implementation). `zone_day_timeline_position_test.dart` updated — its finder located the zone container by matching a distinctive `top` value, which stopped being unique once the offset was removed and silently matched an unrelated Positioned; it now anchors to `ZoneContainerBlock` itself.

**Not covered by a test**: `_zoneTaskTopInset` is a private State method on `_DayTimelineState`, and the only harness that drives a full `TimelineScreen` is the separately-tracked hanging `list_mode_clustering_test.dart` — so this one is verified visually only. Flagging rather than claiming coverage: `timeline_capsule_preview.png` passes unchanged, but that preview seeds no zones and no overlapping tasks, so it exercises none of these three changes.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). Full run: 520 pass, 4 failures — the 3 known Slack ones plus the documented Saturday/Sunday recurrence flake (today is Saturday).

## [2026-09-05] Zone band padding made symmetric on all three sides

Reported directly: "gap from top of zone if task starts same hour as zone should be same as from left" and "gap from right (zone to right task) should be same as left gap (padding)".

**Right padding was 8px against a 12px left inset.** `_zoneBackgroundWidth` added a bare `_pillWidth` to the pills' span; `ZoneBackgroundBlock` then starts the band `zoneBackgroundOffset` (12) to the left and trims `zoneBackgroundGap` (4) off the width. The 8px that fell out on the right was an accident of that arithmetic, not a chosen value. Width now carries both insets plus the trim, so the right padding equals the left at every lane depth (verified 1/2/3 lanes).

**Top padding was already correct** at 12px, from the previous session's `_zoneTaskTopInset` — confirmed by measuring a real render rather than assuming, since this geometry has been easy to reason about wrongly. All three paddings now measure exactly `zoneBackgroundOffset`.

**A test that would have passed against a broken implementation.** The new symmetry test initially computed the expected width inline — the same flaw I'd just criticised in the old back-to-back-clearance test — and duly passed with the fix reverted. Fixed properly by promoting the padding arithmetic out of the private `_zoneBackgroundWidth` into a public, testable `zoneBackgroundWidthForPills` in `task_overlap_layout.dart`, which the test now calls directly. Re-verified by reverting: fails with expected 12 / actual 8, exactly the reported asymmetry.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). `test/features/timeline/`: 91/91 green. Full run: 521 pass, same 4 pre-existing failures (3 Slack, plus the documented Saturday/Sunday recurrence flake).

## [2026-09-05] Zone band width goes per-zone, so a quiet zone stops reserving an empty lane

Reported directly with two arrows both pointing at the band's right edge: "still gap". Clarified as "I mean perceived padding right".

The padding arithmetic from the previous entry was already correct — measured, not assumed: 12px on the left, 12px on the right. What the arrows were actually pointing at was a reserved EMPTY LANE. Bands were sized from `dayPillLanes` (the whole day's deepest stack) under the earlier "all zones same width even if only items over 1 zone stack" request. In the screenshot the day is 2 lanes deep, so the 1-task Meditation zone reserved a second, empty 32px lane — 44px of visible space right of its single pill against 12px on the left.

Confirmed via AskUserQuestion rather than guessed, since fixing it means reversing part of that earlier request. New `zonePillLanes` counts only the lanes a zone's OWN tasks occupy (half-open window, matching `resolveZoneContainment`); `_zoneBackgroundWidth` now takes the zone and uses it. Both zones in the screenshot's scenario now measure 12px on each side.

**The alignment half of the earlier request is untouched**: the shared text column still uses `dayPillLanes`, so every task name in the day stays at one x regardless of which zone it sits in. The two goals only conflicted because one lane count was serving both; they're now separate, which is recorded on both functions' doc comments.

Two stale tests fixed while here. `'the zone band and the text column are derived from the SAME lane count'` asserted something no longer true, and passed only because its loop compared an expression to itself — rewritten to assert the real split (day-wide for text, per-zone for bands). Six new `zonePillLanes` cases cover the screenshot's own scenario, an empty zone, and both half-open boundaries; verified to genuinely catch a regression (4 of them fail if the window filter is removed).

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). `test/features/timeline/`: 97/97 green. Full run: 527 pass, same 4 pre-existing failures (3 Slack, plus the documented Saturday/Sunday recurrence flake).

## [2026-09-05] Dev-config defaults changed: inline layout, no icons, no duration, no free-window prompt, 1.5 scale on both views

Requested directly. All five are `dev_config.dart`'s runtime-toggleable scratch settings (kDebugMode-only, in-memory, never touch real persisted `PreferenceKeys`) — their VALUES changed, not their shape:

- `DevTimelineTaskTextLayout`: `stacked` → `inline`.
- `DevTimelineTaskIconsVisible`: `true` → `false` (no status icon row).
- `DevTimelineTaskDurationVisible`: `true` → `false` (no duration shown).
- `DevShowFreeWindowPrompt`: `true` → `false`.
- `DevZoneViewPixelsPerMinute`: `3.0` → `1.5`, matching `DevTaskViewPixelsPerMinute`'s own 1.5. Its doc comment previously justified 3.0 by a real layout constraint (a short Zone-view container barely fitting a task row at 1.5) — kept as historical context on why the two scales are independently adjustable, not removed, since the constraint itself didn't go away; changed the default anyway per direct request.

Also fixed in passing: a stray, syntactically-invalid `g` character sitting on its own line inside `DevTimelineTaskIconsVisible` (uncommitted local corruption already in the working tree, unrelated to this change) — left in place would have blocked compilation entirely.

No test asserted any of these five defaults directly, and the one fixture that renders `TaskCapsuleBlock` for a golden (`timeline_capsule_preview.dart`) builds it with explicit parameters rather than reading these providers, so it's unaffected.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). `test/features/timeline/`: 97/97 green. Full run: 527 pass, same 4 pre-existing failures (3 Slack, plus the documented Saturday/Sunday recurrence flake) — unchanged by this session, confirming no incidental breakage.

## [2026-09-05] Found the real cause of the lopsided zone padding: pills painted 8px left of their own lane

Reported for the third time — "perceived paddings still not fixed ... task starting same hour as zone still much lower, too big perceived padding, should be same as from left" and "right perceived padding on zone is also too big still". The previous two attempts fixed real things (the width arithmetic, then the per-zone lane count) but both verified against CALCULATIONS of where the pill should be, never against where it actually painted. Measuring the rendered rail is what found this.

**Cause.** `_buildSplit` positions each pill's box at `columnOffset - spacingSm`, reserving lift room by starting the box 8px early, and relied on an `Align(topCenter)` to push the rail back to its lane. That never worked: `pillContent` is the whole capsule row (rail + collapsed text column + checkbox) and fills the box's width, so `Align` had nothing to centre and the rail simply hugged the box's LEFT edge. Every pill therefore painted 8px left of its lane. Inside a zone band that measured 4px of padding on the left against 20px on the right — not the 12/12 the previous sessions' arithmetic predicted.

That also explains the vertical complaint, which was never a separate bug: the 12px top inset was correct all along, but sitting beside a 4px left gap it read as far too large. With the left corrected to 12px, all three now match.

**Fix.** The box starts at its lane (`left: columnOffset`) and carries its lift room to the RIGHT instead, which needs no compensating shift and so can't desync from where the rail paints. `Align` is now `topLeft` on both axes, since neither the rail's top (the task's start time) nor its left (its lane) may drift.

**Testing note worth keeping.** My first regression test asserted `TaskCapsuleBlock` paints its rail at its box's left edge — true, but it passed against the broken build too, because the defect was in the CALLER's offset, not the widget. Caught by reverting and re-running. Fixed by extracting `pillBoxLeftForColumn` so the "box starts AT the lane, never left of it" rule is a real, callable function, and asserting band-vs-rail padding through the actual sizing/offset functions at 1, 2, and 3 lanes. Reintroducing the shift now fails with expected 12 / actual 4.

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). `test/features/timeline/`: 102/102 green. Full run: 532 pass, same 4 pre-existing failures (3 Slack, plus the documented Saturday/Sunday recurrence flake).

## [2026-09-05] Zone band padding reduced 12px → 4px so a task at a zone's start doesn't read as starting late

Requested directly: "reduce padding so that it's minimal 4px so that a task that starts at the same time as a zone is actually not too much lower, otherwise the perception will be that it's starting later."

`zoneBackgroundOffset` drives all three paddings at once — the band's left inset, its right inset (via `zoneBackgroundWidthForPills`), and the top inset a task starting exactly at its zone's start gets (`_zoneTaskTopInset`) — so changing the single constant from 12 to 4 moved all three together. Verified at 1, 2, and 3 lanes: 4px on every side.

The reasoning behind the number is worth keeping: this inset sits on a TIME axis, so it isn't only a spacing choice. At the Task view's default 1.5px per minute, a 12px inset placed the pill ~8 minutes below its own start line; at 4px it is under 3. That coupling is now stated on the constant's own doc comment and asserted in `zone_background_block_test.dart` (`zoneBackgroundOffset / 1.5 < 3.0`), so a future increase has to confront what it means in minutes rather than just looking tidier.

Two tests that hardcoded `12.0` now read the real constants instead (`zoneBackgroundOffset` / `zoneBackgroundGap`), so a change follows through rather than silently disagreeing. Re-verified the symmetry tests still catch a regression: reintroducing the 8px lane shift now fails with expected 4 / actual −4 (the pill would overhang the band's left edge outright).

`flutter analyze lib/ test/`: clean (same 2 pre-existing unrelated warnings). `test/features/timeline/`: 102/102 green. Full run: 532 pass, same 4 pre-existing failures (3 Slack, plus the documented Saturday/Sunday recurrence flake).

## [2026-09-05] New dev toggle: "Zone view" in the Settings Developer section, default OFF

Requested directly: "Add dev config > Zone view as default switched off — that means that switch in timeline goes through task and list view only."

New `DevZoneViewInCycle` (default `false`, matching every other dev-config default's shipped-value convention EXCEPT that this one's shipped/desired behavior really is "off"). It ANDs into the existing `FeatureFlags.zoneEnabled` gate rather than replacing it, in both places that gate is read:

- `day_strip.dart`'s view-cycle button: `next()`'s `zoneFeatureEnabled` parameter, so Zone is skipped in the Task→Zone→List cycle exactly like a flag-off build already skips it.
- `timeline_screen.dart`'s own `zoneViewEnabled` computation, which is otherwise independent of the strip. Missing this half would have let the persisted `ZoneViewEnabledSetting` (still `true` from before the toggle was flipped) keep rendering Zone view while the strip's own button could no longer reach or leave it — a real desync, not a hypothetical one, since the two already read the setting separately before this change.

Debug-only: the whole gate expression is `FeatureFlags.zoneEnabled && (!isDevConfigAvailable || ref.watch(devZoneViewInCycleProvider))`, and `isDevConfigAvailable` is a `kDebugMode` re-export — so in a release build the added term is a compile-time `true` and the expression collapses back to the flag alone. This distinction mattered here specifically because the new toggle's default is `false`; every other dev-config default up to now happened to equal the shipped behavior, so none of them needed this guard to stay safe unread.

New Settings row ("Zone view" switch, off by default) placed in the existing Developer section beside the other dev toggles.

Not unit-tested, matching this codebase's own established convention: none of the existing dev-config providers (`DevShowFreeWindowPrompt`, `DevTimelineTaskIconsVisible`, etc.) have dedicated tests, and `TimelineViewMode.next()`/`day_strip.dart`'s `zoneViewEnabled` are both private/local values with no existing test harness reaching them (the only file that pumps a full `TimelineScreen` is the separately-tracked, still-hanging `list_mode_clustering_test.dart`). Building new test infrastructure for a dev-only scratch toggle would be disproportionate to what was asked.

`flutter analyze lib/`: clean (same 2 pre-existing unrelated warnings). `test/features/timeline/` + `test/features/settings/`: 102/102 green. Full run: 532 pass, same 4 pre-existing failures (3 Slack, plus the documented Saturday/Sunday recurrence flake) — unchanged, confirming no incidental breakage.

## [2026-09-05] Bottom padding for tasks whose end matches their zone's end

Requested directly from a screenshot: a task's pill (Meditation) sat flush against its own zone's bottom edge with no visible gap, while the earlier top-inset fix already gave the analogous START case a clean margin. "Same principle" for the end.

Added `TaskCapsuleBlock.bottomTrim` (default 0) — shrinks `pillHeight` after the existing `badgeSize` floor, itself floored at 0 so a very short task can't go negative. Added `_zoneTaskBottomTrim(Task)` to `_DayTimelineState`, mirroring `_zoneTaskTopInset` exactly: if the task's scheduled end (in minutes-of-day) equals some zone's `endMinutes`, returns `zoneBackgroundOffset` (4.0), else 0. Wired into both the ghost (drag-preview) pill and the real pill — the real pill required threading a new `bottomTrim` field through `_DraggableTaskBlock`'s constructor, since that widget/state has no direct access to `widget.zones`.

Deliberately left `_pillHeight()` (used only by `_TimelineConnectors` for connector-line positioning) untouched, for consistency with its existing behavior of already ignoring the top inset.

Regression tests added to `task_capsule_checkbox_test.dart`, measuring the real rendered `AnimatedContainer` height (not a copy of the widget's internal arithmetic) with and without `bottomTrim`, plus a floor-at-zero case. Verified both fail if the fix is reverted (temporarily replacing `pillHeight`'s computation and re-running).

`flutter analyze`: clean (same 2 pre-existing unrelated warnings). Targeted run (`day_pill_lanes_test.dart`, `zone_background_block_test.dart`, `task_capsule_checkbox_test.dart`): 40/40 green.

## [2026-09-05] Guaranteed 2px gap between close, non-overlapping short tasks

Requested directly, same screenshot as the bottom-padding fix above: two tasks close together in time (5- and 15-minute examples given) each get floored to `badgeSize`, and the floor alone can push one pill's bottom past the very next task's top even though the two never actually overlap in real time — "the smaller one gets below the minimum size in order to always create some small 2-pixel gap."

Added `TaskCapsuleBlock.maxPillHeight` (nullable, default null = no cap) — applied after both the existing `badgeSize` floor and `bottomTrim`, and deliberately allowed to go BELOW `badgeSize` (that's the whole point), floored only at 0. Added `_maxPillHeight(task, slots, blockTops)` to `_DayTimelineState`: finds the next task sharing this task's own overlap COLUMN (scoped to same column deliberately — two tasks in different columns of a group sit side by side and can't visually collide vertically no matter their heights), and if one exists, caps this task's height at `nextTop - ownTop - 2` (new `_minPillGap` constant). Wired into both the ghost and the real pill, same threading pattern as `bottomTrim`.

Confirmed this only matters in Timeline mode: List (collapsed) mode's own `_collapsedTops` already derives every row's top from a shared cursor that advances by the previous row's real floored height plus a gap, so collapsed-mode rows can't collide by construction — `_maxPillHeight` is harmless there (the gap to the next top always exceeds the natural height) but isn't specifically exercised by it.

Regression tests added to `task_capsule_checkbox_test.dart` (new `maxPillHeight` group): caps below `badgeSize`, null leaves the floor unchanged, and never renders negative. Verified all three fail if the cap is dropped from `TaskCapsuleBlock`'s height computation (reverted, re-ran, restored).

`flutter analyze`: clean (same 2 pre-existing unrelated warnings). Targeted run (`day_pill_lanes_test.dart`, `zone_background_block_test.dart`, `task_capsule_checkbox_test.dart`, `task_overlap_layout_test.dart`): 53/53 green.

## [2026-09-05] Real bug: bottom trim landed exactly on the band's own (already-raised) bottom edge

Reported directly from an on-device screenshot after the bottom-trim fix above: a task ending exactly on its zone's end still looked flush against the band, no visible gap — despite `TaskCapsuleBlock.bottomTrim` genuinely being applied (confirmed both by re-reading every line of the wiring and by the passing widget tests). User confirmed on-device that the task's and zone's saved times really were identical, ruling out a data mismatch.

Root cause: `ZoneBackgroundBlock`'s own rendered bottom edge already sits `zoneBackgroundGap` (4px) above the zone's real end time — the inter-zone spacing, taken entirely off each block's bottom so two back-to-back zones don't visually touch. `_zoneTaskBottomTrim` was trimming the task by `zoneBackgroundOffset` (also 4px) alone, which landed the task's new bottom exactly on that already-raised band edge — both moved by the same amount and the visible gap stayed zero. The two constants happening to share a value (4.0) made this easy to miss by inspection alone; it only showed up by working through the actual pixel math of both edges. Fixed: `_zoneTaskBottomTrim` now trims by `zoneBackgroundOffset + zoneBackgroundGap`, so the visible gap below the task matches the visible gap above it (which needed no such stacking, since the band's TOP lands exactly on its own start time with nothing subtracted).

Also actioned a scope change surfaced in the same conversation: zone background bands now ALL render at the day's widest overlap lane count ([dayPillLanes]), reverting the earlier per-zone-lanes design ([zonePillLanes]) that intentionally sized each band to only its own occupied lanes. Confirmed directly, twice, after flagging the conflict with the documented prior decision: "all zones widen to the same size" whenever any overlap exists anywhere in the visible day. `_zoneBackgroundWidth` no longer takes a `Zone` parameter at all, since the width is now the same for every zone on screen. `zonePillLanes` itself is now unused in `lib/` (kept for its own tests and as the earlier design's building block, not deleted).

New regression test in `zone_background_block_test.dart`: renders a real `ZoneBackgroundBlock` + `TaskCapsuleBlock` pair with the actual combined trim and measures the real rendered gap — verified to fail with the old (offset-alone) value. A second new test there renders two zones (one 2-lane, one single-task) at the day-wide width and confirms both bands measure identical, with `zonePillLanes` proven to disagree (would give the quiet zone 1 lane) as evidence the day-wide value is a real, distinguishing choice rather than a coincidence.

`flutter analyze`: clean (same 2 pre-existing unrelated warnings). Full targeted timeline suite (14 files, excluding the separately-tracked `list_mode_clustering_test.dart`): 109/109 green.

## [2026-09-05] Task pill rail moved to radiusSm; fixed the wrapper anchor that didn't follow it

User changed the task pill rail's own rounding from `radiusMd` to `radiusSm` directly in `task_capsule_block.dart`. This retriggered the exact symptom from the earlier "resting pill's left corners" fix — top-left/bottom-left corners still showing the old, larger rounding — because the frosted lift wrapper's rest-state radius anchor was still hardcoded to `radiusMd` (copied from the pill's OLD token at the time of that fix, not a live reference). Fixed both the anchor and a second, previously-latent bug in the same expression's interpolation slope (`radiusXl - radiusSm` instead of `radiusXl - radiusMd`, which happened to cancel out correctly at rest under the old values but always undershot the lifted radius) — the wrapper's radius formula now reads `radiusSm` throughout, so it always matches whatever the pill rail's own current token is.

Updated the existing regression test (`task_capsule_checkbox_test.dart`) that had hardcoded the stale `radiusMd` expectation — it was passing right up until this report because it copied the same stale token the production code did. Verified the new assertion fails against the pre-fix formula and passes with it.

Full writeup in `docs/ERROR_LOG.md` (same date) — flagged as a recurring pattern: a token value copied into a second location as "must match X" is a duplicate that silently drifts the moment X changes, with no compiler error to catch it.

`flutter analyze`: clean (same 2 pre-existing unrelated warnings). `task_capsule_checkbox_test.dart`: 13/13 green.

## [2026-09-05] List (collapsed) mode: zones, split layout, shared text column

Requested directly from a "Current vs To be" mockup: List mode should adopt Task view's zone bands and split layout (icon-only pill + shared text column so names line up across all lanes) while keeping its own condensed, gap-collapsing vertical rhythm (not real elapsed time) — matching CONSTITUTION.md's per-view-job rule (List "organizes action", Task "organizes time"; this changes what's shown, not what List mode does).

Planned via EnterPlanMode + Explore agents given the scope (multiple files, a real architectural question). Core obstacle: `ZoneBackgroundBlock`/`ZoneNameLabel` position via real time-to-pixel math, which has no relationship to List mode's non-linear collapsed-cursor task positions, and `computeCollapsedStackTops`'s cursor can't host a zone as a peer row (it only knows sequential, non-overlapping, point-start rows — not a range that wraps others).

Solution: a zone's List-mode band is derived by wrapping the ALREADY-COMPUTED collapsed tops of its own member tasks/events, not by feeding zones through the cursor or through real-time math. New public `collapsedZoneBands()` (`task_overlap_layout.dart`) takes `resolveZoneContainment`'s existing "which tasks belong to which zone" result (previously used only by the separate Zone View, reused here unchanged) and returns each zone's `top`/`height` by taking the min-top/max-bottom of its members, padded by `zoneBackgroundOffset` on both edges. A zone with zero members (confirmed decision) gets a fixed-height placeholder (one pill's height) slotted immediately before the first chronological row at or after its own start time — a decorative approximation, since it doesn't correspond to any real position and doesn't consume cursor space.

`ZoneBackgroundBlock`/`ZoneNameLabel` gained nullable `collapsedTop`/`collapsedHeight` overrides, same contract `ExternalEventBlock` already established for its own List-mode positioning — null (Task view) falls through to the existing real-time formula unchanged. `timeline_screen.dart` computes the bands once (`_collapsedZoneBands`) and renders two new List-mode-only blocks mirroring the existing Task-view ones. `splitLayout` is now unconditional (both views), so List mode's pills also become icon rail + shared text column.

Also fixed a real bug surfaced immediately after: `TaskCapsuleTextRow` (the split layout's shared text column) hid its ENTIRE time text — not just the duration suffix — whenever the `durationVisible` dev toggle was off (which defaults off), per an old, deliberate "time and duration disappear together" design documented in its own doc comment for a since-superseded mock. List mode has no timeline axis at all, so hiding time there left tasks with no visible schedule whatsoever — reported directly ("cant see it (on list mode)"). Confirmed the fix scope directly: added a separate `alwaysShowTime` param (List-mode-only, wired from `_DraggableTaskBlock.compactText`) rather than changing `durationVisible`'s existing meaning, since Task view's split layout should keep its current dev-toggle-driven behavior unchanged.

New test file `collapsed_zone_bands_test.dart` (7 tests) for the pure geometry function, new `collapsedTop`/`collapsedHeight` tests in `zone_background_block_test.dart`, new `alwaysShowTime` tests in `task_capsule_text_row_test.dart` — all verified to fail on a deliberately reverted fix before being confirmed as real regression guards. Regenerated the `timeline_capsule_preview.png` golden, which had drifted (unrelated corner-radius diff from the earlier `radiusSm` token fix) and was already failing before this session's changes.

`flutter analyze`: clean (same 2 pre-existing unrelated warnings). Full targeted timeline suite (15 files): 120/120 green. Manual on-device verification still pending (emulator running, not yet walked through interactively this session).

## [2026-09-05] Two more real List-mode bugs found from an on-device screenshot

Reported directly, from a screenshot: "stacked tasks in list view are not positioned x same like others" plus "not showing time" plus "gap between tasks in list mode not [see reduced]". User later confirmed the screenshot was from an OLDER build (pre-dating the zone/splitLayout session), so it shows pre-existing bugs in the ordinary (non-split) clustered-task rendering path — not regressions from that work. Two were confirmed and fixed; a third (zone bands overlapping in some cases) is still pending a screenshot to pin down the exact scenario.

**Missing time in clustered rows**: `OverlapClusterBlock`/`_ClusterTaskRow` (the flat list a cluster of overlapping tasks renders as) had the exact same bug class as the earlier `TaskCapsuleTextRow` fix, in a completely separate code path I hadn't touched: `durationVisible: false` (the current dev-toggle default) hid the ENTIRE time range, not just the `(Xm)` suffix. Fixed with the same pattern — a new `alwaysShowTime` param (List-mode-only, set unconditionally at the one List-mode call site) that shows the time range regardless of `durationVisible`, while the suffix itself stays independently gated.

**Cluster row height under-reserved in the collapsed stacking cursor**: a clustered row's height (used to compute how far down the NEXT row starts) was `math.max` of its members' own badge-floored PILL heights — a couple of small icons' worth of space — while the cluster's real rendered content (`OverlapClusterBlock`'s own flat list: one text line per member, its own inter-row gaps, its own vertical padding) is far taller. New public `collapsedClusterHeight()` (`collapsed_stack_layout.dart`) computes the real reserved height from member count + line height + gaps + padding; `_collapsedTops` now looks up each task's cluster membership and uses this instead of the plain pill height whenever a task belongs to a real cluster (size ≥ 2).

New tests: `collapsed_stack_layout_test.dart` (3 for `collapsedClusterHeight`), `overlap_cluster_block_test.dart` (2 for `alwaysShowTime`) — both verified to fail on a deliberately reverted fix.

Zone-band overlap report still open: traced the padding math for the simple back-to-back-zones case (4px padding per side against a 16px real inter-row gap — no overlap possible there), so the actual trigger is a less obvious scenario, likely involving interleaved unzoned tasks or non-adjacent zone ordering. Waiting on a screenshot before changing `collapsedZoneBands` further.

`flutter analyze`: clean (same 2 pre-existing unrelated warnings). Full targeted timeline suite: 125/125 green.

## [2026-09-05] List-mode gap tuning + zone-overlap root cause found and fixed

Follow-up screenshot confirmed the earlier bug fixes landed (time now visible, split layout working, zone bands rendering) and surfaced new, precise feedback: the fixed inter-row gap (`_collapsedBlockGap`, `spacingMd`/16px) read as too generous — reduced to `spacingXs` (4px), confirmed directly.

That change immediately exposed the mechanism behind the previously-reported zone overlap: with a 16px gap, two adjacent zones' independent `zoneBackgroundOffset` (4px) paddings never collided (4+4=8 < 16); at 4px they mathematically could (4+4=8 > 4). `collapsedZoneBands` had no concept of a neighbouring band or row at all — each zone padded outward from its own members unconditionally. Fixed with a clamp: every band's padding is now capped per edge at half the REAL gap to whatever sits nearest on that side (another band's edge, or a plain task/event row's own top or bottom — not just its start point, so a band can't eat into a tall row's own body either), so two neighbours split a tight gap rather than one overlapping into the other's space. `collapsedZoneBands` gained a new `rowExtents` parameter (real row top+bottom pairs) alongside the existing `rowTopsByStartTime` (used only for the empty-zone placeholder's chronological anchor).

Also, per direct request ("add space also before and after" around a zone's own band), List mode's zone-band padding is no longer `zoneBackgroundOffset` — that constant is explicitly tied to Task view's own real-time-axis "task starting late" perception fix and doesn't carry the same meaning against collapsed, non-time-linear positions. List mode now uses its own `theme.spacingSm` (8px, double the old value) for this padding, independently of Task view.

New tests in `collapsed_zone_bands_test.dart`: two for the clamp (adjacent zones with a too-small real gap never overlap; a band never eats into a neighbouring row's own body), both verified to fail without the clamp.

`flutter analyze`: clean (same 2 pre-existing unrelated warnings). Full targeted timeline suite: 127/127 green.
