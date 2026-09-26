import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_badge_chip.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_connected_buttons.dart';
import 'package:amble/core/widgets/app_bottom_dock.dart';
import 'package:amble/core/widgets/app_context_menu.dart';
import 'package:amble/core/widgets/app_date_accordion.dart';
import 'package:amble/core/widgets/app_option_switch_option.dart';
import 'package:amble/core/widgets/app_sheet_handle.dart';
import 'package:amble/core/widgets/app_sheet_header.dart';
import 'package:amble/core/widgets/app_tab_switch.dart';
import 'package:amble/core/widgets/app_undo_toast.dart';
import 'package:amble/core/widgets/app_voice_waveform.dart';
import 'package:amble/core/widgets/app_top_nav.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

/// Amble's component gallery — requested directly to "keep consistency"
/// as the button/tab-switch/connected-buttons hierarchy grows. Renders the
/// REAL app widgets/theme (via the `amble` path dependency in this
/// package's own pubspec.yaml), never a reimplementation, so this gallery
/// can never silently drift from what actually ships.
///
/// **2026-09-19 — knobs, not a use-case-per-combination.** The first pass
/// had a separate `WidgetbookUseCase` per variant/shape/size combination
/// (11 for `AppButton` alone) — requested directly to fix instead: variant
/// and size are now live KNOBS (the right panel's dropdowns) on ONE use
/// case per component, matching how the existing theme addon already lets
/// light/dark be flipped live rather than needing a separate use case per
/// theme. Content-shape differences that a dropdown can't meaningfully
/// express (icon-only vs. label vs. both, loading, disabled) stay as
/// separate use cases, since those change WHAT is being shown, not a
/// parameter of the same thing.
void main() => runApp(const AmbleWidgetbookApp());

class AmbleWidgetbookApp extends StatelessWidget {
  const AmbleWidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: [
        WidgetbookFolder(
          name: 'Selection primitives',
          children: [
            WidgetbookComponent(
              name: 'AppButton',
              useCases: [
                WidgetbookUseCase(
                  name: 'Label',
                  builder: (context) => AppButton(
                    label: 'Get started',
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                    onPressed: _noop,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Icon + label',
                  builder: (context) => AppButton(
                    icon: Icons.add_rounded,
                    label: 'Add task',
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                    onPressed: _noop,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Icon only (circle)',
                  builder: (context) => AppButton(
                    icon: Icons.arrow_back_rounded,
                    shape: AppButtonShape.circle,
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                    onPressed: _noop,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Pill shape',
                  builder: (context) => AppButton(
                    label: 'Next',
                    shape: AppButtonShape.pill,
                    variant: context.variantKnob(),
                    size: context.sizeKnob(initial: AppButtonSize.lg),
                    onPressed: _noop,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Loading',
                  builder: (context) => AppButton(
                    label: 'Saving…',
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                    isLoading: true,
                    onPressed: _noop,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Disabled',
                  builder: (context) => AppButton(
                    label: 'Get started',
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                    onPressed: null,
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AppTabSwitch',
              useCases: [
                WidgetbookUseCase(
                  name: 'Few options',
                  builder: (context) => _TabSwitchDemo(
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Many options (filter row)',
                  builder: (context) => _TabSwitchManyOptionsDemo(
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AppConnectedButtons',
              useCases: [
                WidgetbookUseCase(
                  name: 'Two options',
                  builder: (context) => _ConnectedButtonsDemo(
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Three options',
                  builder: (context) => _ConnectedButtonsThreeOptionsDemo(
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                  ),
                ),
              ],
            ),
            // Systematized from the quick-create mini sheet's own preset/
            // template chips ("Running" / "Laundry" / "Read for class") —
            // requested directly: "component should be agnostic to
            // function... bg, text, icon or icon in colored circle, that
            // can also be selectable so interactive." Already built
            // (`app_badge_chip.dart`) before this Widgetbook entry; this
            // just catalogs it alongside its sibling selection primitives.
            WidgetbookComponent(
              name: 'AppBadgeChip',
              useCases: [
                WidgetbookUseCase(
                  name: 'Non-selectable (just displayed)',
                  builder: (context) => const _BadgeChipDemo(selectable: false),
                ),
                WidgetbookUseCase(
                  name: 'Selectable',
                  builder: (context) => const _BadgeChipDemo(selectable: true),
                ),
              ],
            ),
          ],
        ),
        WidgetbookFolder(
          name: 'Navigation',
          children: [
            // The "close (left) + primary action (right)" row shared by
            // every untitled AppSheet-based sheet (`new_section_sheet
            // .dart`, `new_zone_sheet.dart`, `quick_capture_sheet.dart`) —
            // requested directly: "this can also be added to our widget
            // book storybook as a sheet header, and this will be one of
            // the variants of it."
            WidgetbookComponent(
              name: 'AppSheetHeader',
              useCases: [
                WidgetbookUseCase(
                  name: 'Close + primary button',
                  builder: (context) => const _SheetHeaderDemo(),
                ),
                WidgetbookUseCase(
                  name: 'Close + trailing group (e.g. mic + Done)',
                  builder: (context) => const _SheetHeaderWithGroupDemo(),
                ),
                WidgetbookUseCase(
                  name: 'With drag-to-close handle behind',
                  builder: (context) => const _SheetHeaderWithHandleDemo(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AppDateAccordion',
              useCases: [
                WidgetbookUseCase(
                  name: 'Collapsed by default',
                  builder: (context) => const _DateAccordionDemo(),
                ),
                WidgetbookUseCase(
                  name: 'Expanded on load',
                  builder: (context) =>
                      const _DateAccordionDemo(initiallyExpanded: true),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AppTopNav',
              useCases: [
                WidgetbookUseCase(
                  name: 'Day / Inbox / Tracked',
                  builder: (context) => const _TopNavDemo(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AppBottomDock',
              useCases: [
                WidgetbookUseCase(
                  name: 'List / Timeline / Edit / What Matters',
                  builder: (context) => const _BottomDockDemo(),
                ),
              ],
            ),
          ],
        ),
        // Added for the voice-capture flow (`voice_capture_screen.dart`)
        // — a genuinely reusable component per direct request ("make it
        // a reusable component that we have in Storybook because we'll
        // be reusing it"). Separate use cases per state (idle/listening/
        // loud), not a knob: `level`/`isActive` together describe a
        // content-shape difference (a still, paused waveform vs. a live
        // one), the same reasoning `AppButton`'s icon-only/label/loading
        // use cases already follow — see this file's own class doc
        // comment.
        WidgetbookFolder(
          name: 'Voice',
          children: [
            WidgetbookComponent(
              name: 'AppVoiceWaveform',
              useCases: [
                WidgetbookUseCase(
                  name: 'Idle (paused)',
                  builder: (context) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppVoiceWaveform(
                      theme: AmbleTheme.light,
                      level: 0,
                      isActive: false,
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Listening (mid level)',
                  builder: (context) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppVoiceWaveform(
                      theme: AmbleTheme.light,
                      level: 0.5,
                    ),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Listening (loud)',
                  builder: (context) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppVoiceWaveform(theme: AmbleTheme.light, level: 1),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Requested directly: "let's add toast to amble widgetbook so we
        // reuse it everywhere" — added once AppUndoToast became the app's
        // shared mechanism for every delete/remove action, not just
        // quick-capture's own confident-parse creation. Demoed via a
        // trigger button (`_UndoToastDemo`), not a static `builder` return,
        // since the widget itself is imperative (`AppUndoToast.show`
        // inserts its own `OverlayEntry`) rather than a plain widget with
        // props — same "wrap a stateful demo" shape `_TabSwitchDemo`
        // already uses for a component that needs real interaction to
        // review meaningfully.
        WidgetbookFolder(
          name: 'Feedback',
          children: [
            WidgetbookComponent(
              name: 'AppUndoToast',
              useCases: [
                WidgetbookUseCase(
                  name: 'With Undo action',
                  builder: (context) =>
                      const _UndoToastDemo(withUndo: true),
                ),
                WidgetbookUseCase(
                  name: 'Message only (no Undo)',
                  builder: (context) =>
                      const _UndoToastDemo(withUndo: false),
                ),
              ],
            ),
            // Promoted from the Task action sheet / Inbox Section tab's own
            // long-press menu (`task_action_sheet.dart`,
            // `inbox_section_tabs.dart`) once a THIRD near-identical
            // hand-built "Column of ActionRow" menu appeared — same
            // "promote and replace the duplicate" call `AppTabSwitch`
            // itself got (see that component's own doc comment).
            WidgetbookComponent(
              name: 'AppContextMenu',
              useCases: [
                WidgetbookUseCase(
                  name: 'Plain actions',
                  builder: (context) => const _ContextMenuDemo(
                    withDestructive: false,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'With a destructive action',
                  builder: (context) => const _ContextMenuDemo(
                    withDestructive: true,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Anchored popover (showAt)',
                  builder: (context) => const _ContextMenuAnchoredDemo(),
                ),
                WidgetbookUseCase(
                  name: 'Long-press, drag-to-hover, release-to-select',
                  builder: (context) => const _ContextMenuLongPressDemo(),
                ),
              ],
            ),
          ],
        ),
      ],
      addons: [
        ThemeAddon<ThemeData>(
          themes: [
            WidgetbookTheme(
              name: 'Light',
              data: ThemeData(
                useMaterial3: true,
                extensions: [AmbleTheme.light],
              ),
            ),
            WidgetbookTheme(
              name: 'Dark',
              data: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                extensions: [AmbleTheme.dark],
              ),
            ),
          ],
          themeBuilder: (context, theme, child) =>
              Theme(data: theme, child: child),
        ),
      ],
    );
  }
}

void _noop() {}

/// Shared knob helpers so every use case above gets the identical
/// variant/size dropdown, in the identical order, rather than each
/// reconstructing `context.knobs.list(...)` with slightly different labels.
extension _ButtonKnobs on BuildContext {
  AppButtonVariant variantKnob() => knobs.object.dropdown<AppButtonVariant>(
    label: 'Variant',
    options: AppButtonVariant.values,
    labelBuilder: (v) => v.name,
  );

  AppButtonSize sizeKnob({AppButtonSize initial = AppButtonSize.md}) =>
      knobs.object.dropdown<AppButtonSize>(
        label: 'Size',
        options: AppButtonSize.values,
        initialOption: initial,
        labelBuilder: (v) => v.name,
      );
}

/// Stateful so tapping the chip in the gallery visibly toggles selection,
/// same reasoning as [_TabSwitchDemo] below.
class _BadgeChipDemo extends StatefulWidget {
  const _BadgeChipDemo({required this.selectable});

  final bool selectable;

  @override
  State<_BadgeChipDemo> createState() => _BadgeChipDemoState();
}

class _BadgeChipDemoState extends State<_BadgeChipDemo> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    final theme = AmbleTheme.light;
    return Center(
      child: AppBadgeChip(
        theme: theme,
        leading: Container(
          width: theme.spacingLg,
          height: theme.spacingLg,
          decoration: BoxDecoration(
            color: theme.colorAccent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.directions_run_rounded,
            size: theme.spacingLg * 0.65,
            color: theme.colorSurfacePrimary,
          ),
        ),
        label: 'Running',
        selected: widget.selectable ? _selected : null,
        onTap: widget.selectable
            ? () => setState(() => _selected = !_selected)
            : null,
      ),
    );
  }
}

/// [AppSheetHeader]'s own simplest shape — close left, one primary button
/// right.
class _SheetHeaderDemo extends StatelessWidget {
  const _SheetHeaderDemo();

  @override
  Widget build(BuildContext context) {
    final theme = AmbleTheme.light;
    return AppSheetHeader(
      theme: theme,
      onClose: () {},
      trailing: AppButton(
        label: 'Create',
        size: AppButtonSize.md,
        shape: AppButtonShape.pill,
        onPressed: () {},
      ),
    );
  }
}

/// [AppSheetHeader.trailing] holding more than one control — mirrors
/// `quick_capture_sheet.dart`'s own mic-then-Done group.
class _SheetHeaderWithGroupDemo extends StatelessWidget {
  const _SheetHeaderWithGroupDemo();

  @override
  Widget build(BuildContext context) {
    final theme = AmbleTheme.light;
    return AppSheetHeader(
      theme: theme,
      onClose: () {},
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            icon: Icons.mic_none_rounded,
            shape: AppButtonShape.circle,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.md,
            onPressed: () {},
          ),
          SizedBox(width: theme.spacingSm),
          AppButton(
            icon: Icons.check_rounded,
            shape: AppButtonShape.circle,
            size: AppButtonSize.md,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// The full shape `quick_capture_sheet.dart` uses — the drag handle
/// layered BEHIND the controls, filling the row so it drags from anywhere
/// they don't cover, top-aligned so it sits above their own centre line.
class _SheetHeaderWithHandleDemo extends StatelessWidget {
  const _SheetHeaderWithHandleDemo();

  @override
  Widget build(BuildContext context) {
    final theme = AmbleTheme.light;
    return AppSheetHeader(
      theme: theme,
      onClose: () {},
      handle: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: theme.spacingSm),
          child: AppSheetHandle(theme: theme),
        ),
      ),
      trailing: AppButton(
        label: 'Schedule',
        size: AppButtonSize.md,
        shape: AppButtonShape.pill,
        onPressed: () {},
      ),
    );
  }
}

/// Wraps a stateful demo around AppTabSwitch — a use case needs to show a
/// real, changeable selection, not a fixed prop, or tapping another option
/// in the gallery would visibly do nothing.
class _TabSwitchDemo extends StatefulWidget {
  const _TabSwitchDemo({required this.variant, required this.size});

  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  State<_TabSwitchDemo> createState() => _TabSwitchDemoState();
}

class _TabSwitchDemoState extends State<_TabSwitchDemo> {
  String _value = 'all';

  static const _options = [
    AppOptionSwitchOption(value: 'all', label: 'All'),
    AppOptionSwitchOption(value: 'crypto', label: 'Crypto'),
    AppOptionSwitchOption(value: 'stocks', label: 'Stocks'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppTabSwitch<String>(
        options: _options,
        value: _value,
        variant: widget.variant,
        size: widget.size,
        onChanged: (value) => setState(() => _value = value),
      ),
    );
  }
}

class _TabSwitchManyOptionsDemo extends StatefulWidget {
  const _TabSwitchManyOptionsDemo({required this.variant, required this.size});

  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  State<_TabSwitchManyOptionsDemo> createState() =>
      _TabSwitchManyOptionsDemoState();
}

class _TabSwitchManyOptionsDemoState extends State<_TabSwitchManyOptionsDemo> {
  String _value = 'all';

  static const _options = [
    AppOptionSwitchOption(value: 'all', label: 'All'),
    AppOptionSwitchOption(value: 'crypto', label: 'Crypto'),
    AppOptionSwitchOption(value: 'stocks', label: 'Stocks'),
    AppOptionSwitchOption(value: 'perps', label: 'Perps'),
    AppOptionSwitchOption(value: 'commodities', label: 'Commodities'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppTabSwitch<String>(
        options: _options,
        value: _value,
        variant: widget.variant,
        size: widget.size,
        onChanged: (value) => setState(() => _value = value),
      ),
    );
  }
}

class _ConnectedButtonsDemo extends StatefulWidget {
  const _ConnectedButtonsDemo({required this.variant, required this.size});

  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  State<_ConnectedButtonsDemo> createState() => _ConnectedButtonsDemoState();
}

class _ConnectedButtonsDemoState extends State<_ConnectedButtonsDemo> {
  String _value = 'money';

  static const _options = [
    AppOptionSwitchOption(value: 'money', label: 'Money'),
    AppOptionSwitchOption(value: 'investments', label: 'Investments'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppConnectedButtons<String>(
        options: _options,
        value: _value,
        variant: widget.variant,
        size: widget.size,
        onChanged: (value) => setState(() => _value = value),
      ),
    );
  }
}

class _ConnectedButtonsThreeOptionsDemo extends StatefulWidget {
  const _ConnectedButtonsThreeOptionsDemo({
    required this.variant,
    required this.size,
  });

  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  State<_ConnectedButtonsThreeOptionsDemo> createState() =>
      _ConnectedButtonsThreeOptionsDemoState();
}

class _ConnectedButtonsThreeOptionsDemoState
    extends State<_ConnectedButtonsThreeOptionsDemo> {
  String _value = 'day';

  static const _options = [
    AppOptionSwitchOption(value: 'day', label: 'Day'),
    AppOptionSwitchOption(value: 'week', label: 'Week'),
    AppOptionSwitchOption(value: 'month', label: 'Month'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppConnectedButtons<String>(
        options: _options,
        value: _value,
        variant: widget.variant,
        size: widget.size,
        onChanged: (value) => setState(() => _value = value),
      ),
    );
  }
}

/// Wraps a stateful demo around [AppDateAccordion] — the widget owns its
/// own expanded/collapsed state internally, but `selectedDate` is a real
/// caller-driven value (swiping the week strip or tapping a day cell
/// must visibly move it), so this demo holds that one piece of state the
/// same way `AppCalendarHeader` itself does.
class _DateAccordionDemo extends StatefulWidget {
  const _DateAccordionDemo({this.initiallyExpanded = false});

  final bool initiallyExpanded;

  @override
  State<_DateAccordionDemo> createState() => _DateAccordionDemoState();
}

class _DateAccordionDemoState extends State<_DateAccordionDemo> {
  late DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppDateAccordion(
        selectedDate: _selectedDate,
        initiallyExpanded: widget.initiallyExpanded,
        onDateSelected: (date) => setState(() => _selectedDate = date),
      ),
    );
  }
}

/// Wraps a stateful demo around [AppTopNav] — a use case needs a real,
/// changeable selected index (tapping a different destination must
/// visibly move the highlight), the same shape `AmbleHome` itself drives
/// it with.
class _TopNavDemo extends StatefulWidget {
  const _TopNavDemo();

  @override
  State<_TopNavDemo> createState() => _TopNavDemoState();
}

class _TopNavDemoState extends State<_TopNavDemo> {
  int _selectedIndex = 0;
  // Mirrors AmbleHome's own "Settings is a separate index outside the
  // destination row" shape — tapping the gear here deselects every
  // Day/Inbox/Tracked label instead of falling back to one of them, the
  // real bug fixed 2026-09-22 (see main.dart's own doc comment).
  bool _settingsSelected = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppTopNav(
        destinations: const ['Day', 'Inbox', 'Tracked'],
        selectedIndex: _settingsSelected ? -1 : _selectedIndex,
        settingsSelected: _settingsSelected,
        onDestinationSelected: (index) => setState(() {
          _settingsSelected = false;
          _selectedIndex = index;
        }),
        onSettingsTap: () => setState(() => _settingsSelected = true),
      ),
    );
  }
}

/// Wraps a stateful demo around [AppBottomDock] — List/Timeline need a
/// real, changeable active view, and What Matters needs a real,
/// changeable on/off state, so both are held here rather than passed as
/// fixed props (the "Edit" tap has no state of its own — it just opens a
/// screen — so it's left a no-op in this gallery context).
class _BottomDockDemo extends StatefulWidget {
  const _BottomDockDemo();

  @override
  State<_BottomDockDemo> createState() => _BottomDockDemoState();
}

class _BottomDockDemoState extends State<_BottomDockDemo> {
  AppBottomDockView _activeView = AppBottomDockView.timeline;
  bool _whatMattersEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppBottomDock(
        activeView: _activeView,
        onSelectView: (view) => setState(() => _activeView = view),
        onEditTap: () {},
        whatMattersEnabled: _whatMattersEnabled,
        onWhatMattersTap: () =>
            setState(() => _whatMattersEnabled = !_whatMattersEnabled),
      ),
    );
  }
}

/// `AppUndoToast` is imperative (`.show()` inserts its own `OverlayEntry`
/// on the app's ROOT Overlay, per its own `rootOverlay: true` doc
/// comment), not a plain widget with props — a `builder` returning it
/// directly would have nothing to render. A trigger button is the
/// natural demo shape instead, letting a reviewer see the real entrance/
/// auto-dismiss/Undo-tap behavior rather than a frozen single frame of it.
///
/// [withUndo] toggles [AppUndoToast.show]'s own optional `onUndo` —
/// matching that param's real "null renders a plain informational
/// message with no action" behavior (the Weekly Zone Authoring Grid's own
/// "this zone already exists for that day" notice), not just its more
/// common "confirm a delete" shape.
class _UndoToastDemo extends StatelessWidget {
  const _UndoToastDemo({required this.withUndo});

  final bool withUndo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppButton(
        label: 'Show toast',
        onPressed: () => AppUndoToast.show(
          context: context,
          message: withUndo
              ? "Removed 'Standup'"
              : 'This zone already exists for that day',
          onUndo: withUndo ? () {} : null,
        ),
      ),
    );
  }
}

/// Demos [AppContextMenu.showAt] — the anchored-popover alternative to
/// [AppContextMenu.show]'s bottom sheet, opening right where the trigger
/// is pressed rather than sliding up from the screen's bottom edge.
/// `onTapDown` (not a button's own `onPressed`) supplies the anchor
/// position, matching how a real long-press caller
/// (`inbox_section_tabs.dart`) reads `details.globalPosition`.
class _ContextMenuAnchoredDemo extends StatelessWidget {
  const _ContextMenuAnchoredDemo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Builder(
        builder: (context) => GestureDetector(
          onTapDown: (details) => AppContextMenu.showAt(
            context,
            position: details.globalPosition,
            actions: [
              AppContextMenuAction(
                icon: Icons.edit_outlined,
                label: 'Rename',
                onTap: () {},
              ),
              AppContextMenuAction(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                isDestructive: true,
                onTap: () {},
              ),
            ],
          ),
          child: AppButton(
            label: 'Tap to open at this point',
            // The wrapping GestureDetector's own onTapDown is what opens
            // the menu (it needs the tap's position); AppButton's own
            // onPressed is a required param but otherwise unused here.
            onPressed: () {},
          ),
        ),
      ),
    );
  }
}

/// Demos [AppLongPressContextMenu] — long-press the button, then (while
/// still holding) drag onto a row to see the live hover highlight, and
/// release to select it, the same seamless interaction
/// `inbox_section_tabs.dart`'s own Section tabs use.
class _ContextMenuLongPressDemo extends StatelessWidget {
  const _ContextMenuLongPressDemo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppLongPressContextMenu(
        actions: [
          AppContextMenuAction(
            icon: Icons.edit_outlined,
            label: 'Rename',
            onTap: () {},
          ),
          AppContextMenuAction(
            icon: Icons.delete_outline_rounded,
            label: 'Remove',
            isDestructive: true,
            onTap: () {},
          ),
        ],
        child: AppButton(
          label: 'Long-press, then drag',
          onPressed: () {},
        ),
      ),
    );
  }
}

/// Trigger-button demo, same shape as [_UndoToastDemo] — [AppContextMenu]
/// is imperative ([AppContextMenu.show] inserts a real bottom-sheet route),
/// not a plain widget with props, so a static `builder` return would show
/// nothing meaningful on its own.
class _ContextMenuDemo extends StatelessWidget {
  const _ContextMenuDemo({required this.withDestructive});

  final bool withDestructive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppButton(
        label: 'Open menu',
        onPressed: () => AppContextMenu.show(
          context,
          actions: [
            AppContextMenuAction(
              icon: Icons.edit_outlined,
              label: 'Rename',
              onTap: () => Navigator.of(context).pop(),
            ),
            if (withDestructive)
              AppContextMenuAction(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                isDestructive: true,
                onTap: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}
