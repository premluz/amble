import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_field_action_button.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_segmented_time_field.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../core/widgets/app_staggered_entrance.dart';
import '../../core/widgets/app_step_scaffold.dart';
import '../../core/widgets/app_switch.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_wheel_time_picker.dart';
import '../../shared/models/recurrence_frequency.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/notification_providers.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/services/zone_overlap_checker.dart';

/// Opens the "add/edit zone" screen — near-full-screen, built on
/// [StepScaffold] (the same chrome the real task-creation flow uses,
/// promoted out of `task_detail_sheet.dart` specifically so this could
/// reuse it rather than build a look-alike). Null [zone] is a create;
/// a real [zone] pre-fills every field and Save updates it in place.
///
/// All writes go through `zoneListProvider` — this UI never touches
/// [ZoneRepository]/Hive directly.
Future<void> showZoneFormScreen(BuildContext context, {Zone? zone}) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      // Same slide-up, scrim-barrier presentation as
      // `task_detail_sheet.dart`'s `_pushDetailRoute` — this is the exact
      // route shape `StepScaffold` was designed to sit inside.
      barrierColor: theme.colorScrim,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) =>
          _ZoneFormScreen(zone: zone),
    ),
  );
}

class _ZoneFormScreen extends ConsumerStatefulWidget {
  const _ZoneFormScreen({this.zone});

  final Zone? zone;

  @override
  ConsumerState<_ZoneFormScreen> createState() => _ZoneFormScreenState();
}

class _ZoneFormScreenState extends ConsumerState<_ZoneFormScreen> {
  late final TextEditingController _titleController;
  int? _startHour;
  int? _startMinute;
  int? _endHour;
  int? _endMinute;

  /// Repeat/Notify local state, pre-filled from an existing zone when
  /// editing — mirrors `task_detail_sheet.dart`'s own `_repeats`/
  /// `_selectedDays`/`notificationsEnabled` shape for the identical UI.
  bool _repeats = false;
  Set<int> _selectedDays = {};
  late bool _notificationsEnabled;

  /// Set only when Save was blocked by a real overlap against another
  /// zone — cleared on every field change, matching how the task-creation
  /// flow's own `_overlapError` behaves (`task_detail_sheet.dart`).
  String? _overlapError;
  bool _isSaving = false;

  /// Stage 1 (Name only) vs. stage 2 (everything else) — matches
  /// `task_detail_sheet.dart`'s own create-flow pattern exactly, requested
  /// directly: zones "should follow same pattern of creation as tasks, on
  /// creation first just name visible, other items below (start, end,
  /// repeat etc.) not visible, then fade in after Done is clicked."
  /// Editing an existing zone skips straight to stage 2, same as "Edit
  /// task" does — there is nothing to stage for a zone that already has
  /// every field filled in.
  bool _isNameStage = false;

  bool get _isEditing => widget.zone != null;

  @override
  void initState() {
    super.initState();
    final zone = widget.zone;
    _titleController = TextEditingController(text: zone?.title ?? '')
      // Real bug, reported directly: Save stayed disabled while typing the
      // name and only re-enabled after an unrelated rebuild (e.g. focus
      // leaving the field) happened to re-evaluate `_canSave` — nothing
      // here ever rebuilt on the controller's own text changing, unlike
      // the start/end time fields, whose `onChanged` already calls
      // `setState`. `AppTextField` has no `onChanged` of its own, so this
      // listens to the controller directly instead.
      ..addListener(() => setState(() {}));
    // Create only — an edit already has a name and every other field
    // filled in, so it opens straight on the full form.
    _isNameStage = zone == null;
    _notificationsEnabled = zone?.notificationsEnabled ?? true;
    if (zone != null) {
      _startHour = zone.startMinutes ~/ 60;
      _startMinute = zone.startMinutes % 60;
      _endHour = zone.endMinutes ~/ 60;
      _endMinute = zone.endMinutes % 60;
      final rule = zone.recurrenceRule;
      if (rule != null) {
        _repeats = true;
        _selectedDays = _selectedDaysFromRecurrenceRule(rule);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  int? get _startMinutes => _startHour == null || _startMinute == null
      ? null
      : _startHour! * 60 + _startMinute!;

  int? get _endMinutes => _endHour == null || _endMinute == null
      ? null
      : _endHour! * 60 + _endMinute!;

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty &&
      _startMinutes != null &&
      _endMinutes != null &&
      _endMinutes! > _startMinutes! &&
      !_isSaving;

  Future<void> _save() async {
    if (!_canSave) return;

    // Flushes any pending, uncommitted edit in a still-focused segmented
    // time field before reading `_startMinutes`/`_endMinutes` below.
    // Reported directly and reproduced in a widget test: typing a new
    // time and tapping Save WITHOUT first tapping elsewhere (the field
    // still has focus, keyboard still up) silently saved the OLD time —
    // `AppSegmentedTimeField` only commits its typed value on blur or
    // `onEditingComplete`, and tapping the Save button is neither.
    //
    // `unfocus()` alone is NOT enough: it schedules the field's blur
    // listener (which does the actual commit + `onChanged` + `setState`)
    // rather than running it inline, so reading `_startHour`/`_startMinute`
    // immediately afterward still saw the stale value — confirmed by
    // tracing the actual call order in a widget test. Awaiting a frame
    // lets that listener's `setState` land before the values below are
    // read. Same fix `task_detail_sheet.dart`'s own schedule save would
    // need if it shares this field — flagged there too if a similar
    // report comes in.
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    setState(() => _overlapError = null);

    // A draft `Zone` purely for the overlap check below — never saved
    // itself if the check fails. The real constructor's own asserts
    // (start within a day, end after start) are already satisfied by
    // `_canSave`'s gate, so this can't throw.
    final draft = Zone(
      id: widget.zone?.id ?? 'draft',
      title: _titleController.text.trim(),
      startMinutes: _startMinutes!,
      endMinutes: _endMinutes!,
    );
    final others = ref
        .read(zoneListProvider)
        .where((z) => z.id != widget.zone?.id);
    final conflict = others.where((z) => zonesOverlap(draft, z)).firstOrNull;
    if (conflict != null) {
      setState(
        () => _overlapError =
            'This overlaps "${conflict.title}". Choose a different time.',
      );
      return;
    }

    final recurrenceRule = _repeats
        ? _recurrenceRuleFromSelectedDays(_selectedDays)
        : null;

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(zoneListProvider.notifier);
      final notificationService = ref.read(notificationServiceProvider);
      final existing = widget.zone;
      final Zone saved;
      if (existing == null) {
        saved = await notifier.createZone(
          title: draft.title,
          startMinutes: draft.startMinutes,
          endMinutes: draft.endMinutes,
          recurrenceRule: recurrenceRule,
          notificationsEnabled: _notificationsEnabled,
        );
      } else {
        existing.title = draft.title;
        existing.startMinutes = draft.startMinutes;
        existing.endMinutes = draft.endMinutes;
        existing.recurrenceRule = recurrenceRule;
        existing.notificationsEnabled = _notificationsEnabled;
        await notifier.updateZone(existing);
        saved = existing;
      }
      // Fire-and-forget, matching every TaskList write path's own
      // notification sync (docs/DECISIONS.md) — Save must never wait on a
      // notification platform call, and a scheduling failure must never
      // block the save that already succeeded.
      unawaited(
        _notificationsEnabled
            ? notificationService.scheduleForZone(saved)
            : notificationService.cancelForZone(saved.id),
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Confirms stage 1 (Name) and advances to stage 2 — fired by stage 1's
  /// own Done button or the Name field's keyboard-complete action. Mirrors
  /// `task_detail_sheet.dart`'s own `_confirmNameStage` exactly: an empty
  /// name at this point closes the whole screen instead of advancing to a
  /// form with nothing in it, rather than asking to confirm discarding a
  /// draft the user never actually started.
  void _confirmNameStage() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_titleController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isNameStage = false);
  }

  /// Alternate entry for Start: the same combined typed-field-plus-wheel
  /// pattern `task_detail_sheet.dart` uses via `AppFieldActionButton` +
  /// `AppWheelTimePicker.show` (see its `_openStartTimeModal`) — typed
  /// entry stays primary, the wheel is reached via the trailing icon.
  Future<void> _openStartTimeModal(BuildContext context) async {
    final result = await AppWheelTimePicker.show(
      context: context,
      title: 'Start time',
      initialHour: _startHour ?? 0,
      initialMinute: _startMinute ?? 0,
    );
    if (result == null) return;
    setState(() {
      _startHour = result.$1;
      _startMinute = result.$2;
      _overlapError = null;
    });
  }

  Future<void> _openEndTimeModal(BuildContext context) async {
    final result = await AppWheelTimePicker.show(
      context: context,
      title: 'End time',
      initialHour: _endHour ?? 0,
      initialMinute: _endMinute ?? 0,
    );
    if (result == null) return;
    setState(() {
      _endHour = result.$1;
      _endMinute = result.$2;
      _overlapError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // Stage 2's panes, staggered in exactly like
    // task_detail_sheet.dart's own `staggeredPanes` — built as a plain
    // list so the entrance index is each pane's position in it, not
    // hand-numbered at each call site.
    final staggeredPanes = [
      AppPane(
        child: Column(
          children: [
            AppSegmentedTimeField(
              label: 'Start',
              first: _startHour,
              second: _startMinute,
              firstMax: 23,
              trailing: AppFieldActionButton(
                icon: Icons.schedule_rounded,
                semanticLabel: 'Choose start time',
                onPressed: () => _openStartTimeModal(context),
              ),
              onChanged: (hour, minute) => setState(() {
                _startHour = hour;
                _startMinute = minute;
                _overlapError = null;
              }),
            ),
            SizedBox(height: theme.spacingSm),
            AppSegmentedTimeField(
              label: 'End',
              first: _endHour,
              second: _endMinute,
              firstMax: 23,
              trailing: AppFieldActionButton(
                icon: Icons.schedule_rounded,
                semanticLabel: 'Choose end time',
                onPressed: () => _openEndTimeModal(context),
              ),
              onChanged: (hour, minute) => setState(() {
                _endHour = hour;
                _endMinute = minute;
                _overlapError = null;
              }),
            ),
          ],
        ),
      ),
      // Repeat — standalone pane, same treatment as Notifications below,
      // mirroring task_detail_sheet.dart's own layout (docs/DECISIONS.md).
      AppPane(
        child: _ZoneRecurrencePanel(
          theme: theme,
          repeats: _repeats,
          selectedDays: _selectedDays,
          onRepeatsChanged: (value) => setState(() => _repeats = value),
          onDayToggled: (day) => setState(() {
            if (_selectedDays.contains(day)) {
              _selectedDays = {..._selectedDays}..remove(day);
            } else {
              _selectedDays = {..._selectedDays, day};
            }
          }),
        ),
      ),
      AppPane(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notifications',
              style: theme.textBody.copyWith(color: theme.colorTextPrimary),
            ),
            AppSwitch(
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
            ),
          ],
        ),
      ),
    ];

    return StepScaffold(
      theme: theme,
      modalTitle: _isEditing ? 'Edit zone' : 'New zone',
      titleAlignment: TextAlign.left,
      headerColor: theme.colorAccent,
      headerContent: null,
      onClose: () => Navigator.of(context).pop(),
      onBack: null,
      // Same stage-1/stage-2 pattern as the task-creation flow, requested
      // directly: "should follow same pattern of creation as tasks, on
      // creation first just name visible, other items below (start, end,
      // repeat etc.) not visible, then fade in after Done is clicked."
      primaryLabel: _isNameStage ? 'Done' : 'Save',
      onPrimaryPressed: _isNameStage
          ? _confirmNameStage
          : (_canSave ? _save : null),
      isPrimaryLoading: !_isNameStage && _isSaving,
      errorMessage: _isNameStage ? null : _overlapError,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          theme.spacingLg,
          theme.spacingLg,
          theme.spacingLg,
          theme.spacingXl * 3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Always in the tree, never rebuilt as a different instance —
            // same reasoning as task_detail_sheet.dart's own
            // _NameDescriptionPane: the Name field's Element (and any
            // keyboard/focus state) must survive the stage 1 -> 2
            // transition untouched, not remount as a fresh field.
            AppPane(
              title: 'Name',
              child: AppTextField(
                controller: _titleController,
                label: 'Zone name',
                autofocus: !_isEditing,
                onFocusChanged: (_) => setState(() {}),
                onSubmitted: (_) => _confirmNameStage(),
              ),
            ),
            if (!_isNameStage) ...[
              SizedBox(height: theme.spacingLg),
              for (final (index, pane) in staggeredPanes.indexed) ...[
                AppStaggeredEntrance(index: index, child: pane),
                SizedBox(height: theme.spacingLg),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Zone's own day-selection UI, matching `task_detail_sheet.dart`'s
/// private `_RecurrencePanel` exactly (same 7-chip layout, same
/// Expanded-chip overflow fix) but written locally rather than promoted to
/// a shared widget. Judgment call, not a default: the two pieces genuinely
/// shared between them are the panel's ~35 lines of layout and two trivial
/// pure helper functions below — promoting the whole panel (as
/// `StepScaffold` was promoted earlier this session) would mean carving a
/// public widget out of a 2900+-line file for a second caller that needs
/// no state beyond what it already owns locally. Small enough to duplicate
/// without real drift risk; flagged here and in docs/DECISIONS.md rather
/// than decided silently.
class _ZoneRecurrencePanel extends StatelessWidget {
  const _ZoneRecurrencePanel({
    required this.theme,
    required this.repeats,
    required this.selectedDays,
    required this.onRepeatsChanged,
    required this.onDayToggled,
  });

  final AmbleTheme theme;
  final bool repeats;
  final Set<int> selectedDays;
  final ValueChanged<bool> onRepeatsChanged;
  final ValueChanged<int> onDayToggled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacingSm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Repeat',
                style: theme.textBody.copyWith(color: theme.colorTextPrimary),
              ),
              AppSwitch(value: repeats, onChanged: onRepeatsChanged),
            ],
          ),
        ),
        if (repeats) ...[
          SizedBox(height: theme.spacingSm),
          Row(
            children: [
              for (
                var day = DateTime.monday;
                day <= DateTime.sunday;
                day++
              ) ...[
                if (day > DateTime.monday) SizedBox(width: theme.spacingXs),
                Expanded(
                  child: AppSelectableChip(
                    label: _zoneWeekdayAbbreviations[day - 1],
                    selected: selectedDays.contains(day),
                    onTap: () => onDayToggled(day),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

const _zoneWeekdayAbbreviations = [
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN',
];

/// Same rule as `task_detail_sheet.dart`'s own
/// `_recurrenceRuleFromSelectedDays` — duplicated locally rather than
/// imported, since that function is file-private (`_`-prefixed) and this
/// is a genuinely separate feature's save path, not a shared caller of the
/// same one. All 7 days maps to daily; any smaller selection maps to
/// weekly with that exact `daysOfWeek` set.
RecurrenceRule _recurrenceRuleFromSelectedDays(Set<int> selectedDays) {
  if (selectedDays.length == 7) {
    return RecurrenceRule(frequency: RecurrenceFrequency.daily);
  }
  return RecurrenceRule(
    frequency: RecurrenceFrequency.weekly,
    daysOfWeek: selectedDays.toList()..sort(),
  );
}

/// The inverse, for pre-filling an existing zone's Repeat panel. Daily has
/// no `daysOfWeek` (it means every day by definition), so that case maps
/// back to all 7.
Set<int> _selectedDaysFromRecurrenceRule(RecurrenceRule rule) {
  if (rule.frequency == RecurrenceFrequency.daily) {
    return {for (var day = DateTime.monday; day <= DateTime.sunday; day++) day};
  }
  return rule.daysOfWeek!.toSet();
}
