# Work order: design-system coverage (Widgetbook + press feedback)

Written 2026-09-28 for a follow-up agent. Self-contained: read this file, then
the files it names. Do the tranches in order, one per session, and stop after
each for review.

## Why

The shared components in `lib/core/widgets/` are the design system. Widgetbook
(`widgetbook/`) is where they are seen and tuned in isolation, but only about
half are registered. Separately, about 20 feature widgets handle taps with a raw
`GestureDetector`. That means no press squeeze, no ripple and no haptic, so the
app feels inconsistent. `AppPressFeedback` now gives every tappable surface the
same liquid press (`LiquidPulseSpec.press`), and it only works where it is used.

## Rules (from CLAUDE.md files; violating these is a stop-and-ask)

- Read `CLAUDE.md`, `docs/CONSTITUTION.md` and `docs/DESIGN_SYSTEM.md` first.
- **No new dependencies. No new tokens.** Use existing `AmbleTheme` values
  only, with no hex colours or magic numbers. No inline style objects beyond
  what the surrounding file already does.
- **Behaviour must not change.** Same callbacks, same hit areas, same
  semantics. Visual change is limited to gaining the press feedback.
- Touch only the files listed for the tranche. Report anything else you
  notice; do not fix it.
- Run `flutter analyze` (baseline: **16 issues**; must not grow) and the tests
  named per tranche. Paste failing output; never summarise a failure as
  success. Widget tests that do real Hive I/O need `tester.runAsync`. Do not
  run `test/features/timeline/list_mode_clustering_test.dart` (known hang).
- Pass test files to `flutter test` with `find ... -print0 | xargs -0` or
  explicitly. zsh does not word-split an unquoted `$files`.
- Log each session in `docs/PROGRESS_LOG.md` (short entry) before stopping.

---

## Tranche A: Widgetbook coverage

**Pattern to copy:** `widgetbook/lib/press_feedback_demo.dart` and
`widgetbook/lib/liquid_pulse_demo.dart`. Each is one demo file per component
exporting a `Widget xDemo(BuildContext)` builder, uses `context.knobs` for any
value worth tuning, takes its colours from `AmbleTheme`, and is registered in
`widgetbook/lib/main.dart` as a `WidgetbookComponent` inside the right folder
(`Selection primitives`, `Navigation`, `Voice`, `Feedback`, …; add a folder
only if none fits). Use cases show real states: default, selected, disabled,
loading, error where the component supports them.

Register these, in this order, one commit-sized batch at a time:

1. **Everyday controls:** `AppSwitch`, `AppSlider`, `AppTextField`,
   `AppFieldShell` (empty / focused / filled-floating label),
   `AppSegmentedTimeField`, `AppWheelTimePicker`, `AppFieldActionButton`,
   `AppMicButton`, `AppFloatingCreateButton`, `AppBadge`, `AppAlertDialog`
   (a button that opens it; include the three-way variant).
2. **Motion:** `AppStaggeredEntrance` (a replay button), `AppLayoutReveal`,
   `AppTopScrollFade` (inside a scrolling list).
3. **Surfaces and selection:** `AppPane`, `GlassPillSurface`,
   `SelectedPillBorder`, `ResizeHandleDot`, `WeekdayRepeatPanel`,
   `StepScaffold` (a static example, not a pushed route).

**Out of scope for Tranche A:** internal helpers (controllers, scopes, motion
math, `SheetKeyboard*`, `AppSheetRoute`, `AppViewTransition*`,
`AppContextDock*`). The task pill already has its own page (Feedback → Task
pill); copy its smoke test (`widgetbook/test/task_pill_demo_test.dart`) for
any demo whose layout could break.

**Done when:** every listed component has a use case,
`cd widgetbook && flutter analyze lib` is clean, `flutter analyze` at the root
is at or below baseline, and each new component is added to the "Current call
sites / Widgetbook" note of its section in `docs/DESIGN_SYSTEM.md` where one
exists.

---

## Tranche B: press feedback on raw tap sites

Wrap each listed widget's tap handling in `AppPressFeedback` so it gets the
shared press, ripple and haptic. Mechanical recipe:

```dart
// Before
GestureDetector(
  onTap: onTap,
  behavior: HitTestBehavior.opaque,
  child: Container(decoration: BoxDecoration(borderRadius: r, ...), ...),
)
// After
AppPressFeedback(
  onTap: onTap,               // same callback; null still means disabled
  borderRadius: r,            // the child's own corner radius, so the ripple clips
  child: Container(decoration: BoxDecoration(borderRadius: r, ...), ...),
)
```

- Circular children: `shape: BoxShape.circle` instead of `borderRadius`.
- `AppPressFeedback` fires on finger-lift (`onTapUp`). This is intentional.
- If the child already owns its own tap (a real button), use
  `decorationOnly: true` and keep the child's handler. None of the sites below
  should need this; if one does, stop and report.
- Keep `AnimatedContainer` children as they are. Only the gesture wrapper
  changes.
- `CompletionCheckbox` already plays its own `success`/`selection` haptics.
  Pass `haptic: null` there so it doesn't double up.

**Migrate (10 sites; line numbers are approximate after 2026-09-28 edits,
find each widget by name):**

| File:line | Widget |
|---|---|
| `lib/features/settings/settings_detail_scaffold.dart:93` | `SettingsLinkRow` |
| `lib/features/task_detail/task_detail_sheet.dart:1733` | `_CategoryFieldRow` |
| `lib/features/task_detail/task_detail_sheet.dart:1803` | `_LinkFieldRow` |
| `lib/features/task_detail/task_detail_sheet.dart:3430` | `_BehaviorChip` |
| `lib/features/task_detail/multi_task_edit_sheet.dart:429` | `_BehaviorOption` |
| `lib/features/task_detail/add_category_modal.dart:304` | `_ColorSwatch` (circle) |
| `lib/features/task_detail/add_category_modal.dart:341` | `_IconOption` |
| `lib/features/zones/zone_form_screen.dart:673` | `_ExistingZoneRow` |
| `lib/features/onboarding/onboarding_quiz_screen.dart:142` | `_AnswerCard` |
| `lib/features/onboarding/onboarding_profile_browse_screen.dart:136` | `_ProfileCard` |

**Inline sites (4), same recipe:** `multi_task_edit_sheet.dart:193, :230,
:257` and `zones/multi_zone_edit_sheet.dart:298`. The first three wrap
`AppBadgeChip`s; use the chip's own radius.

**Needs care (2):** `timeline/completion_checkbox.dart:175` (use
`shape: BoxShape.circle`, `haptic: null`; run the checkbox tests) and
`timeline/overlap_cluster_block.dart:512` (an event row inside a cluster; keep
it opaque, and run `overlap_cluster_block_test.dart`).

**Do NOT migrate:** these are barriers, focus plumbing or gesture-swallowers,
not buttons:
`core/widgets/app_context_menu.dart:155`,
`core/widgets/app_context_menu_anchored.part.dart:87` (dismiss barrier and
panel tap-swallow), `core/widgets/app_field_shell.dart:133` (focus
forwarding), `core/widgets/app_step_scaffold.dart:383`,
`core/widgets/app_undo_toast.dart:190`,
`timeline/quick_create_overlay.dart:579` (restore-sheet strip),
`timeline/zone_container_block.dart:571` (shares an arena with a vertical drag),
and every `GestureDetector` used for drags, pans or long-press only.

**Tests:** after each file, run the tests that import it
(`grep -rl <WidgetOrFile> test`). If a test taps by `find.byType(GestureDetector)`,
retarget it to the widget or its text. Never loosen an assertion to make it
pass. Run `test/core/widgets/app_press_feedback_test.dart` at the end.

**Done when:** the 16 sites use `AppPressFeedback`, their tests pass, and
analyze is at baseline. Report any site where the recipe didn't fit.

---

## Not in this work order (flag only; needs a senior pass)

- **Chip consolidation — partly done 2026-09-28.** `_CategoryChip` (×2) and
  `_CategoryTag` became one `CategoryChip`; `_DevChip`/`_TypeChip` now use
  `AppSelectableChip(size: regular, variant: primary)`. Still open, because
  they differ visually: `_BehaviorChip` (radiusMd instead of the pill radius)
  and `_BehaviorOption` (different unselected fill, text colour and weight).
- **Option cards:** `_AnswerCard`/`_ProfileCard` share only an outer shell;
  their content differs, so they are not duplicates. Left as they are.
