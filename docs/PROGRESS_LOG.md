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
