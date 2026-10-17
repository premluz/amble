# Desktop / wide layout — handover

Status as of 2026-10-08. This is for the next agent or developer picking up
the wide (desktop / web / iPad landscape) layout. The individual decisions
are in `docs/DECISIONS.md` (three entries dated 2026-10-08, "Wide layout …").
The scope line is in `docs/SCOPE.md` §"Wide (desktop / web / iPad landscape)
layout". This file ties them together and lists what's left.

## Goal

A three-pane desktop layout, modelled on a desktop-calendar reference the
user supplied:

- **Left:** sidebar nav: Days / Things / Patterns, with Settings at the foot.
  A mini month calendar comes later.
- **Centre:** the current content. Later, a week grid of task pills.
- **Right:** the create/edit panel. **No modal**: clicking an item edits it
  here, and creating happens here too.

The product framing the user gave: desktop/web is a companion to the phone
app. They mentioned web-first as a possibility, but it isn't decided. See
"Open questions".

## Phases

| # | Phase | State |
|---|-------|-------|
| 1 | Shell: sidebar replaces top nav at ≥ 840 wide | **Done** |
| 2 | Right-panel task editor (edit, duplicate, create, Timeline quick-create) | **Done** |
| 2b | Pickers open as popovers beside the panel (adaptive `AppSheet`); panel settings are the phone's chips again (2026-10-11, replacing one-per-line) | **Done** |
| 3 | Day / Week / Month switch; week grid (spatial, zones); month grid (task lists) | **Done** (week editable: move across days, resize, create) |
| 4 | Mini month in sidebar; keyboard shortcuts | Not started |
| — | Web-safe startup; backend/sync for shared data | Not started, needs decisions |

The adaptive `AppSheet` recommended earlier is done (phase 2b, below).
Still unanswered: a desktop scope ceiling — companion (stop at shell +
panel + popovers + a read/edit week view) or primary (full interaction
parity: hover, right-click, shortcuts, cross-day drag, multi-select, plus
backend).

## How it works

### Breakpoint

`ShellLayoutTokens` in `lib/core/tokens/component_tokens.dart` holds the
layout constants:

- `sideNavMinWindowWidth = 840`, Material 3's "expanded" size class.
- `sideNavWidth = 240`.
- `inspectorWidth = 360`.

`AmbleHome` (`lib/main.dart`) decides with
`MediaQuery.sizeOf(context).width >= ShellLayoutTokens.sideNavMinWindowWidth`.
Below that width the phone layout is completely unchanged.

### Phase 1: shell (`lib/main.dart`, `lib/core/widgets/app_side_nav.dart`)

- `_withSideNav` builds `Row([AppSideNav, Expanded(content), TaskInspectorPanel])`.
- `AppSideNav` reuses `AppNavLabel` and `AppNavSettingsGear`, which was
  extracted from `app_top_nav.dart`. Both navs call the same
  `_selectDestination` and `_openSettings`, so they can't drift apart.
- `_wideAwareHeader` mounts the shell header only while a screen claims it
  (`_chromeController.header != null`, which today is only Edit's
  Things | Zones switch). Otherwise there would be an empty 48px band.
- The labels are wrapped in a `Row` so they left-align. `AppNavLabel`
  contains a `Center`, which otherwise expands to the full width.
- Widgetbook: an `AppSideNav` story, "Wide layout sidebar"
  (`_NavDemo(sidebar: true)`).

### Phase 2: right panel (`lib/features/task_detail/`)

**One editor, two hosts.** The editor is spread over these files:

| File | Role |
|------|------|
| `task_editor.dart` | `TaskEditor`: state, save, leave-confirm, delete. Never closes itself; calls `onFinished` and the host closes. |
| `task_editor_body.dart` | Stateless layout: header (close, trash, Add/Save) over `TaskSheetFields`. `showHandle: !inPanel`. Optional `PopScope` guard for the sheet. |
| `task_editor_actions.dart` | Trash + Add/Save buttons. |
| `task_editor_form.dart` | `taskEditorForm(...)` seeds `TaskSheetForm` defaults. |
| `task_inspector.dart` | `TaskInspectorRequest` + `TaskInspectorNotifier` (`taskInspectorProvider`). |
| `task_inspector_panel.dart` | `TaskInspectorPanel`: the right pane. Zero width while closed. |
| `draft_form_link.dart` | `DraftFormLink`: keeps a Timeline draft pill and the form in sync both ways. |
| `task_sheet.dart` | `showTaskSheet`: the single entry point that picks panel or sheet. |

**Routing.** `showTaskSheet` reads `taskInspectorProvider.notifier`:

- If `hasHost` is true (the panel is mounted, so the layout is wide), it
  calls `inspector.open(...)`.
- Otherwise it calls `AppSheet.show(TaskEditor(...))`.

Every existing caller (timeline pills, Things, Patterns, the action sheet's
Edit and Duplicate) gets the panel without changes.

**Leave guard (no silent loss).** The open editor registers
`_leaveForAnother` with `setLeaveGuard`. `open()` awaits that guard before it
replaces the editor. With unsaved edits it asks Save as thing / Discard /
Keep editing. Keep editing returns false and nothing changes.
`clearLeaveGuard` checks identity, so a disposing old editor can't clear the
new editor's guard.

**Timeline quick-create in the panel.**

- In the wide layout, `QuickCreateOverlay` is not mounted
  (`timeline_screen.dart` checks
  `!ref.read(taskInspectorProvider.notifier).hasHost`).
- `TaskInspectorPanel` listens to `pendingTaskDraftProvider` and
  `quickAddSheetVisibleProvider`. It opens the draft only when the phone
  sheet *would* appear: after the long-press is released, or after "+".
  Holding and stretching shows only the pill, as on phones.
- If the user picks Keep editing over a new draft, the new draft is cleared,
  so no orphan pill is left on the Timeline.
- `DraftFormLink.follow(draft)` updates its stored `_draft` before it
  touches the form. That stops a pill drag echoing back from the form into
  the pill.
- A draft asks before discarding only if a name was typed (`hasTypedName`),
  because its time is just where the user pressed.
- The panel passes the *live* draft (matched by id) to the editor, so
  dragging the pill updates the fields.

### Phase 2b: one setting per line, popovers (`core/widgets/`, `task_detail/`)

- `TaskEditorBody` shows the phone's `TaskSheetFields` chips in the sheet and
  the panel alike (2026-10-11). It showed `TaskPanelFields` (+
  `TaskPanelDetailRows`, core `AppFieldRow` / `AppFieldValue`) one setting per
  line until then; those files are unused.
- `TaskInspectorPanel` wraps the editor in
  `AppSheetPresentationScope(popover)`. `AppSheet.show` checks the scope and
  hands off to `showSheetAsPopover` → `AppPopoverRoute`, placed by
  `popoverOrigin` beside the panel, level with the tapped row.
  `AppSheetTopHandle` hides itself in a popover.
- Dates go through `showAppDatePicker` (month calendar in a popover; the
  platform dialog on phones).
- Details and rules: DESIGN_SYSTEM.md "Pickers in the wide layout".
- Not done: Escape to close, hover states, focus order.

### Desktop density (`core/tokens/desktop_density.dart`)

The wide shell is wrapped in `DesktopDensity.apply`: every button rung one
step smaller (md 40→32), pills unchanged. Touch-first iPad landscape also
crosses 840 and gets the smaller controls; revisit if that proves too small.

### Phase 3: Day / Week / Month (`lib/features/calendar/`)

- In the wide layout the Days page is `DesktopDaysHost`: `DesktopCalendarToolbar`
  (month title, Day | Week | Month `AppTabSwitch`, Today, ‹ ›) over the usual
  `TimelineScreen` (Day), `WeekView` or `MonthView`. Phones keep `TimelineScreen`.
- The span is `calendarSpanProvider` (in memory, defaults to Day); dates stay
  on `selectedDateProvider`, so all three views share the selected date.
- **Week**: Monday–Sunday columns on one hour axis (`CalendarGridTokens`),
  zones as the Day view's own band (`WeekZoneBands`: one band across each
  run of days with the same zone; name in the top-left corner; respects
  "Show zones"), tasks as the app's own pills (`TaskCapsuleBlock`) or
  standard blocks (Appearance › Week task style) placed by time; overlapping
  items side by side, as on the Day screen. Device-calendar events too
  (read-only). Faint day/hour lines behind an Appearance toggle
  (`CalendarGridLinesSetting`).
- **Week editing** (as on the Day screen, mouse-first): drag a task to a new
  time or another day (`WeekItemGestures` → `weekDragProvider`, a faded
  ghost where it rests and a preview where it lands); its top or bottom edge
  resizes it; landing on a task asks Overlap / Push all / Trim
  (`commitTaskMove`, `commitTaskResize`), each one undo step. Click-drag on
  empty space (or a hold) draws a draft that opens in the panel
  (`WeekCreateLayer`, the Day screen's `pendingTaskDraftProvider`). The
  pills' completion checkbox follows the Day screen's setting. Touch: hold,
  then drag.
- **Month**: whole weeks covering the month, each day listing up to 4 tasks
  then "+N more"; no zones, no time axis.
- Cmd/Ctrl + scroll zooms the Day timeline around the pointer
  (`TimelinePinchZoom`); the week zooms the same way (`WeekZoom`, plus the
  toolbar's − / +).
- A task opens in the panel (`showTaskSheet`); a day header, date number or
  "+N more" opens that day in Day view. Day tasks come from the shared
  `tasksOnDayProvider` (stored tasks + series occurrences).
- Not yet: dragging past the week's edge into the next week, auto-scroll
  while dragging near the top or bottom, multi-select in the week, editing
  in Month, a current-time line in the week, persisting the chosen span.

### Full-bleed macOS window

`MainFlutterWindow.swift` makes the title bar transparent with
`fullSizeContentView`: the app paints to the top edge and the window
buttons float over the sidebar, as in Notion Calendar. `AppWindowInsets`
(root `MaterialApp.builder`) reports the bar's height
(`ShellLayoutTokens.macTitleBarHeight`, 28) as a top safe area on macOS
only. Phone-width windows use it through the shell's `SafeArea`; the wide
layout skips that `SafeArea` top and each pane (sidebar, centre, panel)
takes the inset inside its own background, so backgrounds bleed to the
edge. Controls stay below the bar: the transparent bar still drags the
window and would swallow clicks. Web/Windows/phones are unchanged.

### Platform fix made along the way

`flutter_local_notifications` threw before `runApp` on macOS, which gave a
blank window. `notification_service.dart` now passes
`macOS: darwinSettings`. Lesson, recorded in `ERROR_LOG.md`: every
pre-`runApp` plugin init must be checked for each target platform.

## Idea parked: pen.dev-style floating panes (macOS)

Discussed 2026-10-08, not started ("not for now, good to know"). The window
buttons sit inside a small rounded pane at the top-left, and the sidebar and
side panel float as inset rounded panes over a full-bleed canvas. Plan if
picked up:
- **Native:** an empty unified `NSToolbar` makes the title bar ~52pt with the
  buttons centred ~20pt from the left (system layout, survives resize and
  full screen). Repositioning the buttons by hand is the fragile
  alternative. The top inset (`macTitleBarHeight`) grows to match.
- **Flutter:** an `AppFloatingSurface` pane drawn behind the buttons (plus
  the app name); dragging the window from the pane's empty space needs a
  small method-channel call to `performDrag`. No new package.
- Full screen hides the buttons; the pane collapses to the name.

## Running it

- **macOS:** `flutter run -d macos`. If the window is blank after a plugin
  change, press `R` (hot restart).
- **Web:** Chrome is installed as "Google Chrome 2.app", so:
  `CHROME_EXECUTABLE="/Applications/Google Chrome 2.app/Contents/MacOS/Google Chrome" flutter run -d chrome`.
  Startup isn't web-safe yet (see below), so expect failures.
- `--no-tree-shake-icons` is a `flutter build` flag only. `flutter run`
  rejects it.
- Resize the window across 840px to switch between the layouts.

## Tests

| File | Covers |
|------|--------|
| `test/wide_shell_layout_test.dart` (7) | Sidebar vs top nav at the breakpoint, no header band, a pill tap opens the panel |
| `test/features/task_detail/task_inspector_test.dart` (~11) | Open/close, leave guard (Save/Discard/Keep), draft group |
| `test/features/task_detail/draft_form_link_test.dart` (4) | Pill ↔ form sync, default name |
| `test/features/task_detail/task_panel_fields_test.dart` (4) | The phone's chips in the panel, picker beside the panel, value shows on its chip, Important chip |
| `test/core/widgets/app_sheet_popover_test.dart` (9) | Sheet vs popover, placement, outside tap, growth, date calendar, `popoverOrigin` |

The panel tests share `test/support/task_inspector_host.dart`.

Conventions:

- Real Hive I/O runs inside `tester.runAsync` with a trailing drain.
- Call `loadAppFonts()` when layout width matters. The default test font
  overflows the top nav.
- The full suite has **18 pre-existing failures** unrelated to this work.
  Two tests are flaky: `quick_task_add` and splash_carousel "tapping Skip".
  Compare against those counts, not against zero.

## Open items and risks

1. **Concurrent session.** Another session has uncommitted edits in the same
   tree, including `quick_create_overlay.dart` and `zone_grid_screen.dart`.
   Don't touch those without checking. `QuickCreateOverlay`'s own form↔pill
   link duplicates `DraftFormLink`; it should adopt `DraftFormLink` once
   those edits land.
2. **Temporary startup instrumentation** in `lib/main.dart`: the `_step(...)`
   wrapper and the `FlutterError.onError` logging. These were added to
   diagnose the on-device black screen and are marked TEMPORARY. Remove
   them once that issue is confirmed closed. An optional visible startup
   error/retry screen was discussed but not built.
3. **Web-safe startup.** `main.dart` initializes Workmanager and the
   app-intent channel, and does other mobile-only setup, before `runApp`.
   Each of these must be guarded or skipped on web and desktop. Audit every
   `_step` call.
4. **Data on web/desktop is local to that device.** Hive works on web
   (IndexedDB), but nothing syncs with the phone. Shared data needs the
   backend that `CONSTITUTION.md` defers ("no cloud sync"). That is a
   constitution-level decision for the user, not an implementation detail.
5. **Hover, right-click, keyboard and multi-select** don't exist anywhere
   yet. They make up most of the remaining desktop effort, and no single
   choke point covers them.
6. **Bottom dock and floating "+"** still float over the centre content in
   the wide layout.
7. **Taste questions from phase 1, unanswered:**
   - Should the Timeline date row align with "Days"?
   - Sidebar styling: spacing and the selected state.
8. **Unrelated but unanswered:** a hardcoded RevenueCat public key was
   flagged earlier. It conflicts with the "no secrets in code" rule, and the
   user hasn't decided yet.

## Rules that bite here

- Files ≤ 200 lines, functions ≤ 40 lines. That's why the editor is split
  into body, actions and form files.
- No `Material*`/`Cupertino*` imports in `features/` except through the
  `core/` adaptive layer.
- No magic numbers; layout constants go in `ShellLayoutTokens`.
- After each phase, append to `PROGRESS_LOG.md`, `DECISIONS.md` and
  `ERROR_LOG.md`, and run `flutter analyze` + `flutter test`.
