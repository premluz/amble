# Component usage guide

Use this page to choose a starting component. It is an index, not a second
visual specification: settled interaction and styling rules live in
[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md), tokens and app structure in
[ARCHITECTURE.md](ARCHITECTURE.md), and exact parameters in each widget's API.
The live examples are in [Widgetbook](../widgetbook/README.md). Treat this
guide and the design-system rules as current usage; consult
[DECISIONS.md](DECISIONS.md) for the history and rationale behind choices.

## Before adding UI

1. Search for an existing use of the behavior or visual treatment in
   `lib/core/widgets/` and `lib/features/`.
2. Check the matching rule below and in `DESIGN_SYSTEM.md`; reuse the shared
   widget if it fits. Extend it when a real variation is needed.
3. Read the widget constructor and doc comments before using it. Use
   `AmbleTheme` and component tokens for theme-dependent styling; do not copy
   literal styling out of a screenshot or a Widgetbook story.
4. In feature screens, use the adaptive components rather than importing raw
   Cupertino or Material controls, as required by
   [CONSTITUTION.md](CONSTITUTION.md).

## Choose by job

| Need | Start here | Use it for | Check before choosing |
| --- | --- | --- | --- |
| Perform an action | [`AppButton`](../lib/core/widgets/app_button.dart) | Primary, secondary, or ghost action; icon, label, circle, or pill shape | Choose the variant by action hierarchy. Icon-only actions need a semantic label or tooltip. Widgetbook: **Selection primitives → AppButton** |
| Switch between a few views | [`AppTabSwitch`](../lib/core/widgets/app_tab_switch.dart) | A compact set of mutually exclusive views, such as Things/Zones | For page destinations use `AppTopNav` or `AppBottomDock`; for options within a form use a selection control. Widgetbook: **Selection primitives → AppTabSwitch** |
| Choose among adjacent fixed options | [`AppConnectedButtons`](../lib/core/widgets/app_connected_buttons.dart) | A small mutually exclusive choice shown as a connected control | Prefer `AppTabSwitch` when the control is a view switch. Widgetbook: **Selection primitives → AppConnectedButtons** |
| Select one or more options | [`AppSelectableChip`](../lib/core/widgets/app_selectable_chip.dart) | Days, presets, or picker options | Set `inMutuallyExclusiveGroup: true` only for a single-choice group; multi-select chips must not announce as radio-like. See chip rules in [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Widgetbook: **Selection primitives → Chip sizes** |
| Show or toggle a compact value | [`AppValueChip`](../lib/core/widgets/app_value_chip.dart) | Small setting/value controls in a row | It is not a general choice chip; use `AppSelectableChip` for selecting among options. Widgetbook: **Selection primitives → Chip sizes** |
| Show a label or preset | [`AppBadgeChip`](../lib/core/widgets/app_badge_chip.dart) | Category-colored label or preset badge, selectable only where the flow calls for it | Do not recreate its fill, selection ring, or sizing. See chip rules in [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Widgetbook: **Selection primitives → AppBadgeChip** |
| Enter free text | [`AppTextField`](../lib/core/widgets/app_text_field.dart) | Single- or multi-line text; choose `filled` or `bare` variant | This is the app's free-text entry point. For a custom non-text picker field, inspect `AppFieldShell`. No dedicated Widgetbook story; field behavior is tested through consuming screens, such as [template forms](../test/features/inbox/task_template_form_test.dart) and [zone forms](../test/features/zones/zone_form_screen_test.dart). |
| Present a modal picker or short form | [`AppSheet.show`](../lib/core/widgets/app_sheet.dart) | A slide-up modal that fits its content | Use `AppSheetFlow` for deeper pages inside the same sheet; do not stack modal sheets. See the Sheets section in [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Widgetbook currently shows the shared header and handle, not a full sheet flow. Inside an `AppSheetPresentationScope(popover)` (the wide layout's task panel) the same call opens a popover beside the control instead; pass the tapped control's own `context` so it anchors there. |
| Show a setting on its own line | [`AppFieldRow`](../lib/core/widgets/app_field_row.dart) | Icon + tappable values (+ optional switch), one setting per line, in the wide layout's panel | On phones the task form uses chips (`AppValueChip`). `AppFieldValue.onTap` receives its own context so a picker can anchor beside it. |
| Open a task to create, edit or duplicate | [`showTaskSheet`](../lib/features/task_detail/task_sheet.dart) | Every task-editing entry point | Opens the shared `TaskEditor` in the wide layout's right panel (`TaskInspectorPanel`) when one is on screen, else in a bottom sheet. Never call `AppSheet.show` with the task form directly, or the wide layout would get a sheet instead of the panel. The Timeline's quick-create draft also opens in the panel there (`TaskInspectorPanel`), linked to its pill via `DraftFormLink`. |
| Present a near-full form | [`AppStepScaffold`](../lib/core/widgets/app_step_scaffold.dart) | Full-screen step forms with a fixed footer action | Follow the sheet interaction and spacing rules in [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). |
| Offer contextual actions | [`AppContextMenu`](../lib/core/widgets/app_context_menu.dart) | Actions anchored to an item or touch point | Reuse its placement and interaction behavior; don't build a separate popup for the same menu pattern. Widgetbook: **Feedback → AppContextMenu** |
| Confirm a reversible change | [`AppUndoToast`](../lib/core/widgets/app_undo_toast.dart) | Brief confirmation with an Undo action | Capture the pre-change state before applying the mutation. See the toast section in [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Widgetbook: **Feedback → AppUndoToast** |

For top-level destinations and page sections, use [`AppTopNav`](../lib/core/widgets/app_top_nav.dart),
[`AppBottomDock`](../lib/core/widgets/app_bottom_dock.dart), and
[`AppSubNav`](../lib/core/widgets/app_sub_nav.dart) respectively. Their live
stories are under **Navigation** in Widgetbook.

In windows at least `ShellLayoutTokens.sideNavMinWindowWidth` wide (desktop,
web, iPad landscape) the shell swaps `AppTopNav` for
[`AppSideNav`](../lib/core/widgets/app_side_nav.dart), a left sidebar with the
same destinations, labels and Settings gear (`AppNavSettingsGear`). Never
build a third nav: a new destination goes into both through `AmbleHome`.

## Small examples

```dart
AppButton(label: 'Save', onPressed: save)

AppSelectableChip(
  label: 'Monday',
  selected: mondaySelected,
  onTap: toggleMonday,
)
```

For icon-only buttons, provide `semanticLabel` (or a tooltip where appropriate).
For a new interactive component, expose its real enabled/selected/tap semantics
and add focused coverage alongside its behavior. Existing examples of that
coverage are in
[`design_system_accessibility_test.dart`](../test/core/widgets/design_system_accessibility_test.dart);
it currently covers buttons and selection primitives, not every shared widget.

## Where to look next

- [Design system rules](DESIGN_SYSTEM.md) — canonical styling, geometry,
  navigation, chips, sheets, motion, and component-specific decisions.
- [Widgetbook](../widgetbook/README.md) — run and browse interactive stories.
- [`lib/core/widgets/`](../lib/core/widgets/) — shared widget implementations.
- [`test/core/widgets/`](../test/core/widgets/) — focused widget behavior and
  accessibility tests.
