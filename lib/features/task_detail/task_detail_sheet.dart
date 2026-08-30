import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_alert_dialog.dart';
import '../../core/widgets/app_button.dart';
import '../../core/feature_flags.dart';
import '../../core/widgets/app_field_action_button.dart';
import '../../core/widgets/app_field_shell.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../core/widgets/app_segmented_time_field.dart';
import '../../core/widgets/app_switch.dart';
import '../../core/widgets/app_text_field.dart';
import '../../shared/models/recurrence_frequency.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/models/task.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/models/task_category.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../../shared/services/overlap_checker.dart';
import 'task_duration_modal.dart';
import 'task_name_category_modal.dart';
import 'task_start_time_modal.dart';
import '../timeline/task_category_token_mapping.dart';


/// Pushes [child] using the same slide-up, near-full-screen presentation
/// used by every task-detail-family modal (create wizard, edit-details,
/// edit-schedule). Not [AppSheet] — the colored, edge-to-edge header these
/// screens share doesn't fit AppSheet's fixed white-background contract, per
/// docs/DECISIONS.md, Phase 4.
Future<T?> _pushDetailRoute<T>(BuildContext context, WidgetBuilder builder) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      // Dims the screen behind the sheet. Was transparent, which left the
      // page underneath at full brightness competing with the modal — the
      // sheet is inset from the top, so what's behind it is visible and
      // needs pushing back.
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
          builder(context),
    ),
  );
}

/// Opens the 2-step task **creation** wizard: step 1 (details — title,
/// category, tracked-behavior link, notes) then step 2 (schedule — date,
/// time, duration, repeats), seeded at [initialScheduledAt]. Nothing is
/// persisted until step 2's Save. All writes go through [taskListProvider]
/// — this UI never touches the repository or Hive directly.
///
/// [task] is for the Inbox's "give it a schedule" case only: an existing,
/// unscheduled (captured) task pre-fills the wizard's fields, and step 2's
/// Save fills in that same task's schedule via [TaskList.updateTask]
/// (rather than creating a second task) — moving it onto the Timeline. An
/// Inbox item has no time yet, so this is still the create-style flow, not
/// an edit of an already-scheduled task (see [showEditDetailsSheet] /
/// [showEditScheduleSheet] for that).
Future<void> showTaskDetailSheet(
  BuildContext context, {
  Task? task,
  DateTime? initialScheduledAt,
  // Scaffold-only — see _TaskDetailFlowState.debugStartWithRepeatsOn.
  bool debugStartWithRepeatsOn = false,
}) {
  return _pushDetailRoute<void>(
    context,
    (context) => _TaskDetailFlow(
      task: task,
      initialScheduledAt: initialScheduledAt ?? task?.scheduledAt ?? DateTime.now(),
      debugStartWithRepeatsOn: debugStartWithRepeatsOn,
    ),
  );
}

/// Opens the "Edit details" modal for [task] — title, category,
/// tracked-behavior link, notes only. Saves directly via
/// [TaskList.updateTask]; no step navigation, no schedule fields.
Future<void> showEditDetailsSheet(
  BuildContext context, {
  required Task task,
  // Scaffold-only params — see _EditDetailsForm's matching fields.
  bool debugAutoTriggerClose = false,
  bool? debugAutoConfirmOutcome,
  bool debugAutoTriggerSave = false,
}) {
  return _pushDetailRoute<void>(
    context,
    (context) => _EditDetailsForm(
      task: task,
      debugAutoTriggerClose: debugAutoTriggerClose,
      debugAutoConfirmOutcome: debugAutoConfirmOutcome,
      debugAutoTriggerSave: debugAutoTriggerSave,
    ),
  );
}

/// Opens the "Edit time and duration" modal for [task] — date, time,
/// duration, and (requested directly, previously create-only per
/// docs/DECISIONS.md) the fully-editable Repeats panel. For a plain task,
/// turning Repeats on and saving materializes a new series starting from
/// it ([TaskList.updateTaskWithNewRecurrence]). For a task already part of
/// a series, changing its days changes the whole series' rule
/// ([TaskList.updateTaskWithChangedRecurrence]), and turning it off
/// disables the series entirely, pruning untouched future instances
/// ([TaskList.disableTaskRecurrence]) — both resolve to the series'
/// TEMPLATE regardless of which instance [task] is. Otherwise (no
/// recurrence involvement) saves via [TaskList.updateTask].
Future<void> showEditScheduleSheet(
  BuildContext context, {
  required Task task,
  // Scaffold-only: seeds a duration different from the task's own value, so
  // a dev entry point can reach the "has unsaved changes" state without a
  // tap-injection tool. Never set outside `*_main.dart` scaffolding.
  int? debugInitialDurationOverride,
  bool debugAutoTriggerClose = false,
  bool? debugAutoConfirmOutcome,
  bool debugAutoTriggerSave = false,
}) {
  return _pushDetailRoute<void>(
    context,
    (context) => _EditScheduleForm(
      task: task,
      debugInitialDurationOverride: debugInitialDurationOverride,
      debugAutoTriggerClose: debugAutoTriggerClose,
      debugAutoConfirmOutcome: debugAutoConfirmOutcome,
      debugAutoTriggerSave: debugAutoTriggerSave,
    ),
  );
}

/// Shared field-holder for the 2-step create wizard. Owns every field the
/// wizard can touch across both steps, plus which step is showing —
/// rather than two separate stateful widgets each managing half the data,
/// so "did anything change" logic and back-navigation both fall out of one
/// state object. See docs/DECISIONS.md.
class _TaskDetailFlow extends ConsumerStatefulWidget {
  const _TaskDetailFlow({
    this.task,
    required this.initialScheduledAt,
    this.debugStartWithRepeatsOn = false,
  });

  /// Set only for the Inbox "give it a schedule" case — see
  /// [showTaskDetailSheet]'s doc comment. Null for an ordinary create.
  final Task? task;

  final DateTime initialScheduledAt;

  /// Scaffold-only: opens the form with the Repeats switch already on, so
  /// the expanded recurrence options can be screenshotted without a
  /// tap-injection tool. Never set outside `*_main.dart` scaffolding.
  @visibleForTesting
  final bool debugStartWithRepeatsOn;

  @override
  ConsumerState<_TaskDetailFlow> createState() => _TaskDetailFlowState();
}

class _TaskDetailFlowState extends ConsumerState<_TaskDetailFlow> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  /// The DATE the task lands on. Always set — it defaults to today, and
  /// the date field shows "Today" from the start.
  late DateTime _scheduledAt;

  /// The time of day, and the duration, are separately nullable because
  /// they start UNSET: their fields show a `hh : mm` placeholder until the
  /// user enters something, rather than presenting a number nobody chose.
  /// Confirm stays disabled until both are filled in.
  TimeOfDay? _timeOfDay;
  int? _durationMinutes;

  late TaskCategory _category;

  bool _repeats = false;
  late Set<int> _selectedDays;
  String? _behaviorId;

  /// Defaults to `true` — matching the persisted [Task.notificationsEnabled]
  /// default, so a fresh create is unaffected unless the user turns it off.
  bool _notificationsEnabled = true;

  /// Whether opening a field's modal should auto-advance to the NEXT one
  /// on Done — the guided first-run sequence (Name → Start time →
  /// Duration) — per direct confirmation: this happens ONLY when creating
  /// a genuinely new, never-scheduled task, and only through ONE pass.
  /// Once the sequence completes (or the user backs out of it by closing
  /// a modal without confirming, or this is actually an edit/give-a-
  /// schedule case), every later tap on a field just opens that one modal.
  late bool _autoAdvanceEligible;

  // Snapshot of the form's starting (pre-filled default) values, so closing
  // from either step can tell whether there's anything worth confirming
  // before discarding. See docs/DECISIONS.md, Phase 6.
  late final String _initialTitle;
  late final DateTime _initialScheduledAt;

  /// Nullable to match [_durationMinutes]: "unset" is the starting state
  /// for a fresh create, so the change-detection snapshot has to be able
  /// to hold it, or opening and closing the form untouched would look
  /// like an edit.
  late final int? _initialDurationMinutes;
  late final TimeOfDay? _initialTimeOfDay;
  late final TaskCategory _initialCategory;
  late final String _initialNotes;
  late final bool _initialNotificationsEnabled;

  /// Set when Save was blocked by the "Prevent overlapping tasks"
  /// preference — shown inline near the Save button per the confirmed
  /// design (sheet stays open, nothing persisted, no popup). Cleared on
  /// every fresh save attempt.
  String? _overlapError;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _scheduledAt = widget.initialScheduledAt;
    // Only an existing (Inbox) task arrives with a real time/duration; a
    // fresh create starts with both unset so the fields read as empty.
    _timeOfDay = task?.scheduledAt == null
        ? null
        : TimeOfDay.fromDateTime(task!.scheduledAt!);
    _durationMinutes = task?.durationMinutes;
    // General, not Personal — requested directly: a new task starts
    // uncategorised (the neutral grey) rather than silently pre-assigned
    // to one specific real category.
    _category = task?.category ?? TaskCategory.general;
    _behaviorId = task?.behaviorId;
    _notificationsEnabled = task?.notificationsEnabled ?? true;
    // Defaults to the task's own start weekday, so enabling Repeats with no
    // further taps produces "repeats on the day it's scheduled" rather than
    // an empty/arbitrary selection.
    _selectedDays = {_scheduledAt.weekday};
    // Eligible only for a genuinely blank task — an Inbox item already
    // has a title (and possibly a time/duration), so "give it a
    // schedule" is closer to an edit than a from-scratch create, and
    // shouldn't force the user through a guided sequence for fields it
    // may already have opinions about.
    _autoAdvanceEligible = task == null;

    _initialTitle = _titleController.text;
    _initialScheduledAt = _scheduledAt;
    _initialDurationMinutes = _durationMinutes;
    _initialTimeOfDay = _timeOfDay;
    _initialCategory = _category;
    _initialNotes = _notesController.text;
    _initialNotificationsEnabled = _notificationsEnabled;

    if (widget.debugStartWithRepeatsOn) _repeats = true;

    // Opens the Name/Category modal automatically on a genuinely new
    // task — requested directly: the first thing a fresh create shows
    // should be name entry, not the bare schedule screen waiting for the
    // pencil to be tapped. Scheduled post-frame (this screen's own route
    // needs to finish pushing/settling before another route can be
    // pushed on top of it) and gated on the same `_autoAdvanceEligible`
    // check the rest of the guided sequence uses, so an Inbox "give it a
    // schedule" task — which already has a name — does NOT auto-open it.
    if (_autoAdvanceEligible) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openNameCategoryModal(),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// The full start instant — the chosen date at the chosen time — or
  /// null while the time is still unset.
  DateTime? get _resolvedScheduledAt {
    final time = _timeOfDay;
    if (time == null) return null;
    return DateTime(
      _scheduledAt.year,
      _scheduledAt.month,
      _scheduledAt.day,
      time.hour,
      time.minute,
    );
  }

  /// Whether the schedule step has everything it needs. Drives the
  /// Confirm button's enabled state — an unset time or duration is a real
  /// state here, not a zero to silently fill in.
  bool get _canSave =>
      _titleController.text.trim().isNotEmpty &&
      _resolvedScheduledAt != null &&
      _durationMinutes != null;

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    // Resolved once, up front: the button that reaches here is disabled
    // until both are set, so a null at this point is a bug rather than a
    // case to paper over with a default.
    final scheduledAt = _resolvedScheduledAt;
    final durationMinutes = _durationMinutes;
    if (scheduledAt == null || durationMinutes == null) return;

    setState(() => _overlapError = null);
    if (ref.read(preventOverlappingTasksSettingProvider) &&
        overlapsExistingTask(
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
          existingTasks: ref.read(taskListProvider),
          excludeTaskId: widget.task?.id,
        )) {
      setState(
        () => _overlapError =
            'This overlaps another task. Choose a different time.',
      );
      return;
    }

    final notes = _notesController.text.trim();
    final notifier = ref.read(taskListProvider.notifier);
    final existing = widget.task;

    if (existing == null) {
      await notifier.createTask(
        title: title,
        notes: notes.isEmpty ? null : notes,
        scheduledAt: scheduledAt,
        durationMinutes: durationMinutes,
        category: _category,
        recurrenceRule: _repeats ? _buildRecurrenceRule() : null,
        behaviorId: _behaviorId,
        notificationsEnabled: _notificationsEnabled,
      );
    } else {
      // Moving an Inbox item onto the Timeline: fill in the same task's
      // schedule rather than creating a second one. Recurrence is not
      // offered here in practice (an Inbox item's "Repeats" panel would be
      // reachable, but this path is for giving an existing capture its
      // first schedule, not spinning up a new series from it) — the field
      // still exists on the shared state, so this mirrors the create path
      // exactly rather than special-casing it away.
      existing.title = title;
      existing.notes = notes.isEmpty ? null : notes;
      existing.scheduledAt = _scheduledAt;
      existing.durationMinutes = _durationMinutes;
      existing.category = _category;
      existing.notificationsEnabled = _notificationsEnabled;
      if (_behaviorId == null) existing.actualAmount = null;
      existing.behaviorId = _behaviorId;
      await notifier.updateTask(existing);
    }

    if (mounted) Navigator.of(context).pop();
  }

  RecurrenceRule _buildRecurrenceRule() {
    return _recurrenceRuleFromSelectedDays(_selectedDays);
  }

  /// Whether closing without an explicit save would silently lose something
  /// worth asking about, spanning both steps' combined state.
  bool get _hasUnconfirmedChanges {
    if (_titleController.text.trim().isEmpty) return false;
    return _titleController.text != _initialTitle ||
        _scheduledAt != _initialScheduledAt ||
        _timeOfDay != _initialTimeOfDay ||
        _durationMinutes != _initialDurationMinutes ||
        _category != _initialCategory ||
        _notesController.text != _initialNotes ||
        _notificationsEnabled != _initialNotificationsEnabled;
  }

  Future<void> _handleClose() async {
    if (!_hasUnconfirmedChanges) {
      Navigator.of(context).pop();
      return;
    }

    final choice = await AppAlertDialog.showThreeWay(
      context: context,
      title: 'Discard this task?',
      message: "You haven't saved this task yet. Save it with the current "
          'time and duration, or discard the draft?',
      primaryAction: const AppAlertDialogAction(label: 'Save task'),
      destructiveAction: const AppAlertDialogAction(
        label: 'Discard draft',
        isDestructive: true,
      ),
      cancelAction: const AppAlertDialogAction(label: 'Keep editing'),
    );

    if (!mounted) return;
    switch (choice) {
      case AppAlertDialogChoice.primary:
        await _save();
      case AppAlertDialogChoice.destructive:
        Navigator.of(context).pop();
      case AppAlertDialogChoice.cancel:
        // Stay exactly where the user was — no navigation, no save.
        break;
    }
  }

  /// Opens the Name/Category modal — the preview card's pencil. On the
  /// guided first-run sequence, confirming here (Done, not a bare
  /// dismiss) chains straight into the Start-time modal; every other time
  /// it's a normal open-one-modal-and-return.
  Future<void> _openNameCategoryModal() async {
    // Captured before the modal opens: this is what distinguishes the
    // very FIRST auto-opened modal (the guided first-run entry point)
    // from a later re-open via the pencil — only the former should be
    // able to abandon the whole flow below. Confirmed directly: reopening
    // the pencil after other fields are already filled in must NOT nuke
    // that progress just because the name is empty at that moment.
    final isFirstAutoOpenedModal = _autoAdvanceEligible;
    await TaskNameCategoryModal.show(
      context: context,
      titleController: _titleController,
      notesController: _notesController,
      category: _category,
      onCategoryChanged: (value) => setState(() => _category = value),
    );
    if (!mounted) return;

    if (isFirstAutoOpenedModal && _titleController.text.trim().isEmpty) {
      // Done tapped with no name entered, on the very first modal of a
      // fresh create — requested directly: "that closes both modals
      // (effectively reverses) abandon flow." Routed through the SAME
      // close path the header's × button uses rather than a bare
      // Navigator.pop: an empty title means _hasUnconfirmedChanges is
      // already false (nothing else could have been touched yet, since
      // this is the very first step), so _handleClose pops silently with
      // no confirmation dialog — exactly "abandon", not "ask to discard".
      await _handleClose();
      return;
    }

    // The preview card reads the title controller directly (not via a
    // ListenableBuilder), so closing the modal needs an explicit rebuild
    // to pick up whatever was typed — without this, a name entered here
    // wouldn't show in the preview until some UNRELATED state change
    // happened to trigger the next rebuild.
    setState(() {});
    if (!isFirstAutoOpenedModal) return;
    // A name was actually entered — proceed to the next step in the
    // guided sequence.
    await _openStartTimeModal();
  }

  Future<void> _openStartTimeModal() async {
    final wasChaining = _autoAdvanceEligible;
    final result = await TaskStartTimeModal.show(
      context: context,
      initialHour: _timeOfDay?.hour,
      initialMinute: _timeOfDay?.minute,
    );
    if (!mounted) return;
    if (result == null) {
      // Dismissed without confirming — ends the guided sequence here
      // rather than forcing Duration open next; the user gets to decide
      // what to fill in next themselves.
      if (wasChaining) setState(() => _autoAdvanceEligible = false);
      return;
    }
    setState(
      () => _timeOfDay = TimeOfDay(hour: result.$1, minute: result.$2),
    );
    if (!wasChaining) return;
    await _openDurationModal();
  }

  Future<void> _openDurationModal() async {
    final result = await TaskDurationModal.show(
      context: context,
      initialMinutes: _durationMinutes,
    );
    if (!mounted) return;
    if (result != null) setState(() => _durationMinutes = result);
    // Duration is the LAST step in the guided sequence — whether
    // confirmed or dismissed, the one-shot chain is done either way.
    if (_autoAdvanceEligible) setState(() => _autoAdvanceEligible = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return _ScheduleStepScaffold(
      modalTitle: 'Create task',
      theme: theme,
      title: _titleController.text.trim(),
      category: _category,
      date: _scheduledAt,
      timeOfDay: _timeOfDay,
      durationMinutes: _durationMinutes,
      onDateChanged: (value) => setState(() => _scheduledAt = value),
      onTimeOfDayChanged: (value) => setState(() => _timeOfDay = value),
      onDurationChanged: (value) => setState(() => _durationMinutes = value),
      notificationsEnabled: _notificationsEnabled,
      onNotificationsEnabledChanged: (value) =>
          setState(() => _notificationsEnabled = value),
      onNameCategoryTap: _openNameCategoryModal,
      showRepeats: true,
      repeats: _repeats,
      selectedDays: _selectedDays,
      onRepeatsChanged: (value) => setState(() => _repeats = value),
      onDayToggled: (day) => setState(() {
        if (_selectedDays.contains(day)) {
          if (_selectedDays.length > 1) _selectedDays.remove(day);
        } else {
          _selectedDays.add(day);
        }
      }),
      onClose: _handleClose,
      primaryLabel: 'Schedule',
      // Disabled until time AND duration are set — an empty field is
      // a real unset state, not a zero to fill in silently.
      onPrimaryPressed: _canSave ? _save : null,
      errorMessage: _overlapError,
    );
  }
}

/// "Edit details" — title, category, tracked-behavior link, notes only.
/// Single-step, no navigation. Saves directly via [TaskList.updateTask].
class _EditDetailsForm extends ConsumerStatefulWidget {
  const _EditDetailsForm({
    required this.task,
    this.debugAutoTriggerClose = false,
    this.debugAutoConfirmOutcome,
    this.debugAutoTriggerSave = false,
  });

  final Task task;

  /// Scaffold-only: calls the real close (×) handler once the form has
  /// settled, exercising the actual `_handleClose` path so a dev entry
  /// point can screenshot the exit-confirmation modal without a
  /// tap-injection tool. Never set outside `*_main.dart` scaffolding.
  @visibleForTesting
  final bool debugAutoTriggerClose;

  /// Scaffold-only: once [debugAutoTriggerClose] has opened the
  /// exit-confirmation modal, automatically resolves it as if the user
  /// tapped "Schedule this" (`true`) or the destructive action (`false`).
  /// Never set outside `*_main.dart` scaffolding.
  @visibleForTesting
  final bool? debugAutoConfirmOutcome;

  /// Scaffold-only: calls the real save handler once the form has settled.
  /// Never set outside `*_main.dart` scaffolding.
  @visibleForTesting
  final bool debugAutoTriggerSave;

  @override
  ConsumerState<_EditDetailsForm> createState() => _EditDetailsFormState();
}

class _EditDetailsFormState extends ConsumerState<_EditDetailsForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late TaskCategory _category;
  String? _behaviorId;

  late final String _initialTitle;
  late final TaskCategory _initialCategory;
  late final String _initialNotes;
  late final String? _initialBehaviorId;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task.title);
    _notesController = TextEditingController(text: task.notes ?? '');
    _category = task.category;
    _behaviorId = task.behaviorId;

    _initialTitle = _titleController.text;
    _initialCategory = _category;
    _initialNotes = _notesController.text;
    _initialBehaviorId = _behaviorId;

    if (widget.debugAutoTriggerClose) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleClose());
    }
    if (widget.debugAutoTriggerSave) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _save());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasUnconfirmedChanges {
    if (_titleController.text.trim().isEmpty) return false;
    return _titleController.text != _initialTitle ||
        _category != _initialCategory ||
        _notesController.text != _initialNotes ||
        _behaviorId != _initialBehaviorId;
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final notes = _notesController.text.trim();
    final existing = widget.task;
    existing.title = title;
    existing.notes = notes.isEmpty ? null : notes;
    existing.category = _category;
    // Unlinking clears any recorded outcome — an amount measured against a
    // behavior this task no longer belongs to would be orphaned data.
    if (_behaviorId == null) existing.actualAmount = null;
    existing.behaviorId = _behaviorId;

    await ref.read(taskListProvider.notifier).updateTask(existing);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleClose() async {
    if (!_hasUnconfirmedChanges) {
      Navigator.of(context).pop();
      return;
    }

    final outcomeOverride = widget.debugAutoConfirmOutcome;
    if (outcomeOverride != null) {
      unawaited(
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) Navigator.of(context).pop(outcomeOverride);
        }),
      );
    }
    final choice = await AppAlertDialog.showThreeWay(
      context: context,
      title: 'Discard changes?',
      message: 'You have unsaved changes to this task. Save them, or '
          'discard them?',
      primaryAction: const AppAlertDialogAction(label: 'Save changes'),
      destructiveAction: const AppAlertDialogAction(
        label: 'Discard changes',
        isDestructive: true,
      ),
      cancelAction: const AppAlertDialogAction(label: 'Keep editing'),
    );

    if (!mounted) return;
    switch (choice) {
      case AppAlertDialogChoice.primary:
        await _save();
      case AppAlertDialogChoice.destructive:
        Navigator.of(context).pop();
      case AppAlertDialogChoice.cancel:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    // Edit-details only ever opens on an already-scheduled task in
    // practice, but the model's fields are nullable (an unscheduled task
    // has neither), so this reads them the same defensive way the rest of
    // the codebase does rather than force-unwrapping.
    final start = widget.task.scheduledAt;
    final duration = widget.task.durationMinutes;
    return _DetailsStepScaffold(
      theme: theme,
      titleController: _titleController,
      notesController: _notesController,
      category: _category,
      onCategoryChanged: (category) => setState(() => _category = category),
      behaviorId: _behaviorId,
      onBehaviorChanged: (id) => setState(() => _behaviorId = id),
      startTime: start,
      endTime: (start == null || duration == null)
          ? null
          : start.add(Duration(minutes: duration)),
      durationMinutes: duration,
      onClose: _handleClose,
      primaryLabel: 'Save',
      onPrimaryPressed: _save,
      onBack: null,
    );
  }
}

/// "Edit time and duration" — date, time, duration only. Never shows
/// repeats: recurrence is create-only (CONSTITUTION.md). Saves directly via
/// [TaskList.updateTask].
class _EditScheduleForm extends ConsumerStatefulWidget {
  const _EditScheduleForm({
    required this.task,
    this.debugInitialDurationOverride,
    this.debugAutoTriggerClose = false,
    this.debugAutoConfirmOutcome,
    this.debugAutoTriggerSave = false,
  });

  final Task task;

  /// Scaffold-only: seeds a duration different from the task's own value,
  /// so a dev entry point can reach the "has unsaved changes" state
  /// without a tap-injection tool. Never set outside `*_main.dart`
  /// scaffolding.
  @visibleForTesting
  final int? debugInitialDurationOverride;

  /// Scaffold-only — see _EditDetailsForm's matching field.
  @visibleForTesting
  final bool debugAutoTriggerClose;

  /// Scaffold-only — see _EditDetailsForm's matching field.
  @visibleForTesting
  final bool? debugAutoConfirmOutcome;

  /// Scaffold-only — see _EditDetailsForm's matching field.
  @visibleForTesting
  final bool debugAutoTriggerSave;

  @override
  ConsumerState<_EditScheduleForm> createState() => _EditScheduleFormState();
}

class _EditScheduleFormState extends ConsumerState<_EditScheduleForm> {
  late DateTime _scheduledAt;
  late int _durationMinutes;

  /// Own controllers/category state so the preview card's pencil can open
  /// the same [TaskNameCategoryModal] the create flow uses — this modal
  /// previously had no way to touch name/category at all, but the pencil
  /// is now the ONLY way to reach them (there's no separate step 1 to
  /// navigate to any more), so this form needs to be able to edit them
  /// too, not just view them.
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late TaskCategory _category;
  String? _behaviorId;
  late bool _notificationsEnabled;

  late final DateTime _initialScheduledAt;
  late final int _initialDurationMinutes;
  late final Set<int> _initialSelectedDays;
  late final String _initialTitle;
  late final String _initialNotes;
  late final TaskCategory _initialCategory;
  late final bool _initialNotificationsEnabled;

  /// See _TaskDetailFlowState's matching field — same inline-error contract
  /// for the "Prevent overlapping tasks" preference.
  String? _overlapError;

  /// Repeats panel state — requested directly, alongside the create flow's
  /// own [_TaskDetailFlowState._repeats]/`_selectedDays`. Fully editable
  /// now, including for an already-recurring task (follow-up requested
  /// directly: "we sohuld be able to edit repeat settings on set items
  /// also and disable"). [_wasRecurring] captures the state as opened, so
  /// [_save] can tell which of the three recurrence-provider methods
  /// applies without re-deriving it from [widget.task], which [_save]
  /// itself mutates before the branch runs.
  late final bool _wasRecurring;
  late bool _repeats;
  late Set<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    // A materialized instance is always scheduled — see Task.isScheduled.
    _scheduledAt = task.scheduledAt!;
    _durationMinutes =
        widget.debugInitialDurationOverride ?? task.durationMinutes!;
    _titleController = TextEditingController(text: task.title);
    _notesController = TextEditingController(text: task.notes ?? '');
    _category = task.category;
    _behaviorId = task.behaviorId;
    _notificationsEnabled = task.notificationsEnabled;
    _initialTitle = task.title;
    _initialNotes = task.notes ?? '';
    _initialCategory = task.category;
    _initialNotificationsEnabled = task.notificationsEnabled;
    _wasRecurring = task.isRecurring;
    _repeats = task.isRecurring;
    // An already-recurring task seeds its REAL days from the series'
    // template (any instance edits the whole series — confirmed via
    // AskUserQuestion — so this reads the template's rule even when
    // `task` itself is a later, ruleless instance). A plain task defaults
    // to its own scheduled weekday, same reasoning the create flow uses:
    // turning Repeats on with no further taps produces "repeats on the
    // day it's scheduled" rather than an empty/arbitrary selection.
    _selectedDays = task.isRecurring
        ? _selectedDaysFromRecurrenceRule(
            findSeriesTemplate(
              task,
              ref.read(taskListProvider),
            ).recurrenceRule!,
          )
        : {_scheduledAt.weekday};
    _initialSelectedDays = Set.of(_selectedDays);

    _initialScheduledAt = _scheduledAt;
    _initialDurationMinutes = task.durationMinutes!;

    if (widget.debugAutoTriggerClose) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleClose());
    }
    if (widget.debugAutoTriggerSave) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _save());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasUnconfirmedChanges {
    return _scheduledAt != _initialScheduledAt ||
        _durationMinutes != _initialDurationMinutes ||
        _titleController.text != _initialTitle ||
        _notesController.text != _initialNotes ||
        _category != _initialCategory ||
        _notificationsEnabled != _initialNotificationsEnabled ||
        _repeats != _wasRecurring ||
        // A same-days no-op toggle doesn't count as a real edit, but a
        // genuine day-set change while already recurring does.
        (_repeats && _wasRecurring && !setEquals(_selectedDays, _initialSelectedDays));
  }

  Future<void> _save() async {
    setState(() => _overlapError = null);
    if (ref.read(preventOverlappingTasksSettingProvider) &&
        overlapsExistingTask(
          scheduledAt: _scheduledAt,
          durationMinutes: _durationMinutes,
          existingTasks: ref.read(taskListProvider),
          excludeTaskId: widget.task.id,
        )) {
      setState(
        () => _overlapError =
            'This overlaps another task. Choose a different time.',
      );
      return;
    }

    final existing = widget.task;
    existing.scheduledAt = _scheduledAt;
    existing.durationMinutes = _durationMinutes;
    existing.title = _titleController.text.trim();
    final notes = _notesController.text.trim();
    existing.notes = notes.isEmpty ? null : notes;
    existing.category = _category;
    existing.notificationsEnabled = _notificationsEnabled;
    if (_behaviorId == null) existing.actualAmount = null;
    existing.behaviorId = _behaviorId;

    final notifier = ref.read(taskListProvider.notifier);
    // Three-way branch on [_wasRecurring]/[_repeats], read BEFORE
    // `existing` is mutated below — matches the three provider methods
    // requested directly (turn on / change / disable), each confirmed via
    // its own AskUserQuestion round (see docs/DECISIONS.md):
    if (!_wasRecurring && _repeats) {
      // Plain -> recurring: materializes a new series starting from it.
      await notifier.updateTaskWithNewRecurrence(
        existing,
        _recurrenceRuleFromSelectedDays(_selectedDays),
      );
    } else if (_wasRecurring && !_repeats) {
      // Recurring -> off: detaches the TEMPLATE from the series and
      // prunes untouched future instances. `existing` itself may not be
      // the template — updateTask's own save below still needs to run
      // for `existing`'s scheduledAt/durationMinutes, which
      // disableTaskRecurrence does as part of its own contract.
      await notifier.disableTaskRecurrence(existing);
    } else if (_wasRecurring && _repeats) {
      // Recurring -> recurring, days possibly changed: always resolves
      // to the series' template regardless of which instance `existing`
      // is — a same-days save still round-trips harmlessly (the rule is
      // rebuilt identically, and _deleteUntouchedFutureInstances /
      // _materializeSeries together just regenerate the same slots).
      await notifier.updateTaskWithChangedRecurrence(
        existing,
        _recurrenceRuleFromSelectedDays(_selectedDays),
      );
    } else {
      // Plain -> plain: no recurrence involvement at all.
      await notifier.updateTask(existing);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleClose() async {
    if (!_hasUnconfirmedChanges) {
      Navigator.of(context).pop();
      return;
    }

    final outcomeOverride = widget.debugAutoConfirmOutcome;
    if (outcomeOverride != null) {
      unawaited(
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) Navigator.of(context).pop(outcomeOverride);
        }),
      );
    }
    final choice = await AppAlertDialog.showThreeWay(
      context: context,
      title: 'Discard changes?',
      message: 'You have unsaved changes to this task. Save them, or '
          'discard them?',
      primaryAction: const AppAlertDialogAction(label: 'Save changes'),
      destructiveAction: const AppAlertDialogAction(
        label: 'Discard changes',
        isDestructive: true,
      ),
      cancelAction: const AppAlertDialogAction(label: 'Keep editing'),
    );

    if (!mounted) return;
    switch (choice) {
      case AppAlertDialogChoice.primary:
        await _save();
      case AppAlertDialogChoice.destructive:
        Navigator.of(context).pop();
      case AppAlertDialogChoice.cancel:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return _ScheduleStepScaffold(
      theme: theme,
      // The task's LIVE title/category now — this form can edit them via
      // the pencil, so the preview must track the controllers rather than
      // the original widget.task snapshot.
      title: _titleController.text.trim(),
      category: _category,
      // An existing task always HAS a time and duration, so this modal
      // never shows the empty state — it splits the stored instant into
      // date + time to match the scaffold's contract, then reassembles it.
      date: _scheduledAt,
      timeOfDay: TimeOfDay.fromDateTime(_scheduledAt),
      durationMinutes: _durationMinutes,
      onDateChanged: (value) => setState(() {
        _scheduledAt = DateTime(
          value.year,
          value.month,
          value.day,
          _scheduledAt.hour,
          _scheduledAt.minute,
        );
      }),
      onTimeOfDayChanged: (value) => setState(() {
        _scheduledAt = DateTime(
          _scheduledAt.year,
          _scheduledAt.month,
          _scheduledAt.day,
          value.hour,
          value.minute,
        );
      }),
      onDurationChanged: (value) => setState(() => _durationMinutes = value),
      notificationsEnabled: _notificationsEnabled,
      onNotificationsEnabledChanged: (value) =>
          setState(() => _notificationsEnabled = value),
      onNameCategoryTap: () async {
        await TaskNameCategoryModal.show(
          context: context,
          titleController: _titleController,
          notesController: _notesController,
          category: _category,
          onCategoryChanged: (value) => setState(() => _category = value),
        );
        // The title feeds this scaffold's `title` param above, which is
        // only read on rebuild — an explicit setState makes sure editing
        // the name (a controller, not tracked state) actually triggers
        // one.
        if (mounted) setState(() {});
      },
      showRepeats: true,
      repeats: _repeats,
      selectedDays: _selectedDays,
      onRepeatsChanged: (value) => setState(() => _repeats = value),
      onDayToggled: (day) => setState(() {
        if (_selectedDays.contains(day)) {
          if (_selectedDays.length > 1) _selectedDays.remove(day);
        } else {
          _selectedDays.add(day);
        }
      }),
      // An already-recurring task's Repeats panel is fully editable here
      // (requested directly, the follow-up to the original
      // create-only/then-read-only staging).
      onClose: _handleClose,
      primaryLabel: 'Save',
      onPrimaryPressed: _save,
      errorMessage: _overlapError,
    );
  }
}

/// Shared chrome for both steps: colored header (category color) with a
/// close (×) button and an optional back arrow, a scrollable body, and a
/// sticky primary button. [titleController] is only present on the details
/// step's header per its own screen (see [_DetailsStepScaffold] vs.
/// [_ScheduleStepScaffold], which show a static time summary instead).
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.theme,
    required this.headerColor,
    this.modalTitle,
    this.titleAlignment = TextAlign.center,
    this.headerContent,
    required this.onClose,
    required this.onBack,
    required this.body,
    required this.primaryLabel,
    this.onPrimaryPressed,
    this.errorMessage,
  });

  final AmbleTheme theme;
  final Color headerColor;
  /// Null renders no coloured header banner at all — the create wizard's
  /// step 1 (mockup: name/notes/category live as ordinary body fields,
  /// no coloured wrapper). Every other caller still passes a real header.
  final Widget? headerContent;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final Widget body;
  /// The modal's own title ("Create task"), shown in the header beside
  /// the close button. Null on the single-step edit modals, which are
  /// reached from a task that already names itself.
  final String? modalTitle;

  /// [TextAlign.center] (matching every prior caller) or
  /// [TextAlign.left]. The single-screen schedule flow's title reads left
  /// as a page heading, not centred as a dialog title — the header no
  /// longer has a back arrow to balance against, so a centred title would
  /// sit in dead space rather than mirroring anything.
  final TextAlign titleAlignment;

  final String primaryLabel;

  /// Null disables the primary button (matches [AppButton.onPressed]'s own
  /// nullable-means-disabled contract) — used for "Continue" before a name
  /// has been entered.
  final VoidCallback? onPrimaryPressed;

  /// Shown inline just above the primary button — currently only used by
  /// the "Prevent overlapping tasks" rejection message. Null when there's
  /// nothing to report.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent, NOT the level-0 ground: the sheet is inset from the
      // screen edges so its 40px corners are actually visible, which only
      // reads if whatever is behind it shows through. Painting the
      // scaffold would fill those edges and flatten the sheet back into a
      // full-page surface.
      backgroundColor: Colors.transparent,
      // Edge to edge horizontally and offset only from the top, so the
      // sheet reads as a panel pulled up over the screen: full width,
      // almost full height, with the rounding visible along its top edge.
      // No shadow of its own — depth inside the sheet is carried by the
      // panes (`shadowPane`); a shadow on the sheet as well would stack
      // two elevations for one surface.
      body: Padding(
        padding: EdgeInsets.only(top: theme.spacingXl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorSurfaceBase,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radiusModal),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radiusModal),
            ),
            child: SafeArea(
              // Top handled by the offset above; the sheet owns that edge.
              top: false,
              child: Column(
                children: [
                Container(
                  width: double.infinity,
                  // No coloured banner at all when headerContent is null
                  // (mockup's step 1) — just the close/back buttons on the
                  // page's own background, at a fixed height matched to
                  // what the buttons themselves need rather than the
                  // header's usual content padding.
                  // Tall enough for the close/back buttons, plus room for
                  // the modal title when there is one — a title in a
                  // button-height strip sits cramped against the sheet's
                  // top edge.
                  height: headerContent == null
                      ? theme.spacingXl +
                            (modalTitle == null
                                ? theme.spacingLg
                                : theme.spacingXl + theme.spacingMd)
                      : null,
                  decoration: headerContent == null
                      ? null
                      : BoxDecoration(
                          color: headerColor,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(theme.radiusModal),
                          ),
                        ),
                  child: Stack(
                    children: [
                      if (modalTitle != null)
                        Positioned.fill(
                          child: Padding(
                            // Clears the close button on the right always;
                            // clears the back arrow on the left only when
                            // there is one — a left-aligned title with no
                            // back arrow can start from the sheet's own
                            // edge instead of leaving a phantom gap.
                            padding: EdgeInsets.only(
                              left: onBack != null || titleAlignment == TextAlign.center
                                  ? theme.spacingXl + theme.spacingLg
                                  : theme.spacingLg,
                              right: theme.spacingXl + theme.spacingLg,
                            ),
                            child: Align(
                              alignment: titleAlignment == TextAlign.center
                                  ? Alignment.center
                                  : Alignment.centerLeft,
                              child: Text(
                                modalTitle!,
                                textAlign: titleAlignment,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textHeadline.copyWith(
                                  color: theme.colorTextPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (headerContent != null)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            onBack != null
                                ? theme.spacingXl + theme.spacingLg
                                : theme.spacingLg,
                            theme.spacingXl + theme.spacingSm,
                            theme.spacingXl + theme.spacingLg,
                            theme.spacingLg,
                          ),
                          child: headerContent,
                        ),
                      // Both buttons are vertically centred rather than
                      // pinned to a fixed top offset: the header's height
                      // now depends on whether it carries a title, so a
                      // fixed offset would leave them sitting high in the
                      // taller variant instead of level with the title.
                      if (onBack != null)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: theme.spacingLg,
                          child: Center(
                            child: _HeaderCircleButton(
                              theme: theme,
                              icon: Icons.arrow_back_rounded,
                              onTap: onBack!,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: theme.spacingLg,
                        child: Center(
                          child: _HeaderCircleButton(
                            theme: theme,
                            icon: Icons.close_rounded,
                            onTap: onClose,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  // No surface of its own: the header strip and the body
                  // are one continuous level-0 ground. Painting the body
                  // separately was a leftover from the coloured-header
                  // design and made the top strip read as a distinct bar.
                  child: Stack(
                      children: [
                        body,
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: theme.spacingLg,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: theme.spacingLg,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (errorMessage != null) ...[
                                  Text(
                                    errorMessage!,
                                    style: theme.textBody.copyWith(
                                      color: theme.colorTaskAlert,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: theme.spacingSm),
                                ],
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      theme.radiusTaskPill,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorTextPrimary
                                            .withValues(alpha: 0.18),
                                        blurRadius: theme.spacingMd,
                                        offset: Offset(0, theme.spacingXs),
                                      ),
                                    ],
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: AppButton(
                                      label: primaryLabel,
                                      size: AppButtonSize.large,
                                      shape: AppButtonShape.pill,
                                      onPressed: onPrimaryPressed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.theme,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  final AmbleTheme theme;
  final IconData icon;
  final VoidCallback onTap;

  /// Both default to a treatment that works on the sheet's own level-0
  /// ground in EITHER palette: a level-2 circle with a primary-text glyph.
  ///
  /// These used to default to [AmbleTheme.colorSurfacePrimary] for both,
  /// which was correct only for the old coloured header — that token is
  /// white in light mode but near-black `ink900` in dark mode, so once the
  /// banner went away the dark-mode back/close glyphs became black on a
  /// dark ground and effectively vanished. Text and surface colors invert
  /// in opposite directions between palettes, so a glyph must come from a
  /// TEXT token, never a surface one.
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: theme.spacingXl,
        height: theme.spacingXl,
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorSurfaceField,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? theme.colorTextPrimary),
      ),
    );
  }
}

/// Step 1 — title, category, tracked-behavior link, notes. Used by both the
/// create wizard's first step and the standalone "Edit details" modal.
class _DetailsStepScaffold extends ConsumerWidget {
  const _DetailsStepScaffold({
    required this.theme,
    this.modalTitle,
    required this.titleController,
    required this.notesController,
    required this.category,
    required this.onCategoryChanged,
    required this.behaviorId,
    required this.onBehaviorChanged,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.onClose,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    required this.onBack,
  });

  final AmbleTheme theme;

  /// Passed straight through to [_StepScaffold] — see its own field.
  final String? modalTitle;

  final TextEditingController titleController;
  final TextEditingController notesController;
  final TaskCategory category;
  final ValueChanged<TaskCategory> onCategoryChanged;
  final String? behaviorId;
  final ValueChanged<String?> onBehaviorChanged;

  /// The task's current schedule, shown in the SAME live preview step 2
  /// uses — requested directly, so the preview is visible from the very
  /// first step rather than only appearing once schedule fields exist.
  /// Nullable because the create wizard reaches step 1 before a time or
  /// duration has been entered; the standalone "Edit details" modal always
  /// has all three, since it only ever edits an already-scheduled task.
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationMinutes;

  final VoidCallback onClose;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryColor = theme.categoryColors[category.token]!;

    // Continue stays disabled until the name has at least one real
    // character — per the mockup, and it removes the old failure mode
    // where tapping Continue with an empty title silently did nothing.
    // ListenableBuilder rather than plumbing a second controller-value
    // field through this whole widget: the button is the ONLY part of
    // the tree that needs to react per keystroke, so only it rebuilds.
    return ListenableBuilder(
      listenable: titleController,
      builder: (context, _) => _StepScaffold(
        theme: theme,
        modalTitle: modalTitle,
        headerColor: categoryColor,
        onClose: onClose,
        onBack: onBack,
        primaryLabel: primaryLabel,
        onPrimaryPressed: titleController.text.trim().isEmpty
            ? null
            : onPrimaryPressed,
      // No coloured header block on this step any more (mockup): the name
      // is now an ordinary field in the body, styled like Notes, so the
      // form reads as one consistent stack rather than a coloured banner
      // plus a form.
      headerContent: null,
      // Order per the mockup: name, then notes, then category — the name
      // used to live in the coloured header and jump straight to
      // category; now it's the first ordinary field in the body.
      body: SingleChildScrollView(
        padding: EdgeInsets.all(theme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Same live preview step 2 shows — requested directly, so the
            // task's eventual Timeline appearance is visible from the very
            // first step rather than only appearing once schedule fields
            // exist. No edit pencil here: this widget already IS step 1,
            // so a button that navigates to step 1 makes no sense on it.
            _SchedulePreviewCard(
              theme: theme,
              title: titleController.text.trim(),
              category: category,
              startTime: startTime,
              endTime: endTime,
              durationMinutes: durationMinutes,
              onEdit: null,
            ),
            SizedBox(height: theme.spacingLg),
            // Name and Notes share one pane with the section title
            // outside it, so the two fields read as a single "Name" group
            // rather than two stacked cards. autofocus only on the true
            // first entry into the wizard (onBack null means this is the
            // very first step shown, not a back-navigation into it).
            AppPane(
              title: 'Name',
              child: Column(
                children: [
                  AppTextField(
                    controller: titleController,
                    label: 'Task name',
                    autofocus: onBack == null,
                  ),
                  SizedBox(height: theme.spacingSm),
                  AppTextField(
                    controller: notesController,
                    label: 'Description',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.spacingLg),
            AppPane(
              title: 'Category',
              child: Wrap(
                spacing: theme.spacingSm,
                runSpacing: theme.spacingSm,
                // Neutral "General" first and preselected — requested
                // directly — then the four meaningful categories in their
                // existing order. TaskCategory.values would put General
                // last (it's HiveField 4, appended so persisted data for
                // existing tasks is untouched); orderedForPicker is the
                // display-only reordering.
                //
                // Wrap rather than a horizontal ListView: the chips now
                // flow onto a second line (as in the mockup) instead of
                // scrolling off-screen, so every category is visible
                // without discovery.
                children: [
                  for (final option in TaskCategoryPickerOrder.orderedForPicker)
                    _CategoryTag(
                      category: option,
                      selected: option == category,
                      onSelected: () => onCategoryChanged(option),
                    ),
                ],
              ),
            ),
            // Tracked-behavior link. Gated: with the flag off this whole
            // subtree is const-eliminated, so an ordinary build's form is
            // unchanged.
            if (FeatureFlags.trackedBehaviorEnabled) ...[
              SizedBox(height: theme.spacingLg),
              _BehaviorPickerPanel(
                theme: theme,
                behaviors: ref.watch(trackedBehaviorListProvider),
                selectedId: behaviorId,
                onChanged: onBehaviorChanged,
              ),
            ],
            // Reserves space so the last scrollable item never sits under
            // the sticky primary button, even when scrolled all the way.
            SizedBox(height: theme.spacingXl * 3),
          ],
        ),
      ),
      ),
    );
  }
}

/// Step 2 — date, time, duration, and (create-only) repeats.
class _ScheduleStepScaffold extends StatelessWidget {
  const _ScheduleStepScaffold({
    required this.theme,
    this.modalTitle,
    required this.title,
    required this.category,
    required this.date,
    required this.timeOfDay,
    required this.durationMinutes,
    required this.onDateChanged,
    required this.onTimeOfDayChanged,
    required this.onDurationChanged,
    required this.notificationsEnabled,
    required this.onNotificationsEnabledChanged,
    required this.onNameCategoryTap,
    required this.showRepeats,
    required this.repeats,
    required this.selectedDays,
    required this.onRepeatsChanged,
    required this.onDayToggled,
    required this.onClose,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.errorMessage,
  });

  final AmbleTheme theme;

  /// Passed straight through to [_StepScaffold] — see its own field. Now
  /// always left-aligned here: this is the ONLY screen in the flow (the
  /// old step 1 no longer exists as a separate page), so its title reads
  /// as a page heading rather than a dialog title balanced against a back
  /// arrow.
  final String? modalTitle;

  /// The task's own name, shown in the live preview header exactly as it
  /// will read on the Timeline — requested directly.
  final String title;
  final TaskCategory category;

  /// The DAY the task lands on — always set (defaults to today). The time
  /// of day is tracked separately because it, unlike the date, starts
  /// unset and has to be able to read as empty.
  final DateTime date;

  /// Start time, or null while unset.
  final TimeOfDay? timeOfDay;

  /// Duration in minutes, or null while unset.
  final int? durationMinutes;

  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeOfDayChanged;
  final ValueChanged<int> onDurationChanged;

  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsEnabledChanged;

  /// Opens the compact Name/Category modal — the preview card's pencil,
  /// and (per the mockup) the whole point of that field existing at all
  /// now that there's no separate step 1 to navigate back to.
  final VoidCallback onNameCategoryTap;

  final bool showRepeats;
  final bool repeats;
  final Set<int> selectedDays;
  final ValueChanged<bool> onRepeatsChanged;
  final ValueChanged<int> onDayToggled;
  final VoidCallback onClose;
  final String primaryLabel;

  /// Null disables the primary button — the create flow passes null until
  /// both time and duration are set.
  final VoidCallback? onPrimaryPressed;

  /// Shown inline just above the primary button when Save was blocked by
  /// the "Prevent overlapping tasks" preference. Null when there's nothing
  /// to report.
  final String? errorMessage;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    onDateChanged(DateTime(picked.year, picked.month, picked.day));
  }

  /// Opens the combined typed-field + wheel modal for the start time.
  Future<void> _openStartTimeModal(BuildContext context) async {
    final result = await TaskStartTimeModal.show(
      context: context,
      initialHour: timeOfDay?.hour,
      initialMinute: timeOfDay?.minute,
    );
    if (result == null) return;
    onTimeOfDayChanged(TimeOfDay(hour: result.$1, minute: result.$2));
  }

  /// Same shape, for duration.
  Future<void> _openDurationModal(BuildContext context) async {
    final result = await TaskDurationModal.show(
      context: context,
      initialMinutes: durationMinutes,
    );
    if (result == null) return;
    onDurationChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    // The preview can only show a time range once BOTH halves are set;
    // until then it shows the task without one rather than inventing a
    // start or a length.
    final time = timeOfDay;
    final duration = durationMinutes;
    final startTime = time == null
        ? null
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final endTime = (startTime == null || duration == null)
        ? null
        : startTime.add(Duration(minutes: duration));

    return _StepScaffold(
      theme: theme,
      modalTitle: modalTitle,
      titleAlignment: TextAlign.left,
      // headerColor is still required by _StepScaffold's contract (every
      // OTHER step still uses the coloured-banner path), but this step no
      // longer renders one — see headerContent below.
      headerColor: theme.categoryColors[category.token]!,
      onClose: onClose,
      // No back arrow: this is the only screen in the flow now, so there
      // is nowhere "back" to go to — the header shows only Close.
      onBack: null,
      primaryLabel: primaryLabel,
      onPrimaryPressed: onPrimaryPressed,
      errorMessage: errorMessage,
      // No coloured banner here either (mockup): the "preview" — the
      // task exactly as it will appear on the Timeline, badge/title/time
      // — now lives as an ordinary card at the top of the body instead,
      // so it can show the SAME styling TaskCapsuleBlock uses rather than
      // a different, header-only treatment.
      headerContent: null,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(theme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SchedulePreviewCard(
              theme: theme,
              title: title,
              category: category,
              startTime: startTime,
              endTime: endTime,
              durationMinutes: duration,
              // No longer "back to step 1" (step 1 doesn't exist as a
              // page any more) — the pencil now opens the compact
              // Name/Category modal directly.
              onEdit: onNameCategoryTap,
            ),
            SizedBox(height: theme.spacingLg),
            // Time, Duration, AND Date now share one pane (moved directly
            // from its own separate pane) — all three answer "when does
            // this happen", so the split into two panes was an arbitrary
            // one. No section header ABOVE this pane any more (requested
            // directly — the pane's own content is self-explanatory
            // without a "Time" label sitting over it); the fields' own
            // inline labels (Time/Duration/Date) are unaffected.
            AppPane(
              child: Column(
                children: [
                  AppSegmentedTimeField(
                    label: 'Time',
                    first: time?.hour,
                    second: time?.minute,
                    firstMax: 23,
                    // Alternative entry: the combined typed+wheel modal,
                    // matching the mockup's per-field screens rather than
                    // a bare wheel-only sheet.
                    trailing: AppFieldActionButton(
                      icon: Icons.schedule_rounded,
                      semanticLabel: 'Choose start time',
                      onPressed: () => _openStartTimeModal(context),
                    ),
                    onChanged: (hour, minute) =>
                        onTimeOfDayChanged(TimeOfDay(hour: hour, minute: minute)),
                  ),
                  SizedBox(height: theme.spacingSm),
                  AppSegmentedTimeField(
                    label: 'Duration',
                    first: duration == null ? null : duration ~/ 60,
                    second: duration == null ? null : duration % 60,
                    // No upper bound (requested directly — "no cap, any
                    // positive duration"). The mask carries a spare hour
                    // digit for that; the DISPLAY stays two digits until a
                    // value actually needs the third.
                    firstMax: null,
                    trailing: AppFieldActionButton(
                      icon: Icons.timer_outlined,
                      semanticLabel: 'Choose duration',
                      onPressed: () => _openDurationModal(context),
                    ),
                    onChanged: (hours, minutes) {
                      final total = hours * 60 + minutes;
                      // A task must have SOME duration — floor at 1
                      // minute rather than allowing 0h 0m, which every
                      // downstream consumer (pill height, end-time math,
                      // overlap checks) assumes is impossible.
                      onDurationChanged(total < 1 ? 1 : total);
                    },
                  ),
                  SizedBox(height: theme.spacingSm),
                  // The whole field is tappable (mockup: "entire field
                  // works as a button"), and it ALSO carries a calendar
                  // button, matching the clock/stopwatch on the fields
                  // above — the icon is what makes the alternative entry
                  // discoverable, since a bare row of text doesn't
                  // advertise that it opens anything.
                  AppFieldShell(
                    label: 'Date',
                    isFocused: false,
                    isFloating: true,
                    onTap: () => _pickDate(context),
                    trailing: AppFieldActionButton(
                      icon: Icons.calendar_today_rounded,
                      semanticLabel: 'Choose date',
                      onPressed: () => _pickDate(context),
                    ),
                    child: Text(
                      _formatDate(date),
                      style: theme.textBody.copyWith(
                        color: theme.colorTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.spacingLg),
            // Repeat — now standalone, its OWN bare pane matching
            // Notifications' treatment exactly (requested directly:
            // "Repeat is standalone same as notifications"). Previously
            // nested inside the Date pane; that pane no longer exists as
            // a distinct group (Date moved above, into the Time pane), so
            // Repeat gets its own rather than being orphaned into Time's.
            if (showRepeats) ...[
              AppPane(
                child: _RecurrencePanel(
                  theme: theme,
                  repeats: repeats,
                  selectedDays: selectedDays,
                  onRepeatsChanged: onRepeatsChanged,
                  onDayToggled: onDayToggled,
                ),
              ),
              SizedBox(height: theme.spacingLg),
            ],
            // Notifications — its own bare pane (no AppPane `title`), per
            // direct request: "this section has no header, just pane with
            // label and switch inside".
            AppPane(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: theme.textBody.copyWith(
                      color: theme.colorTextPrimary,
                    ),
                  ),
                  AppSwitch(
                    value: notificationsEnabled,
                    onChanged: onNotificationsEnabledChanged,
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.spacingXl * 3),
          ],
        ),
      ),
    );
  }
}

/// The schedule step's live preview — the task exactly as it will appear
/// on the Timeline (badge/title/time), updating as the user types.
/// Requested directly: "think of the top part with the icon task name as
/// the active preview that's showing how the task is gonna look like on
/// the timeline."
///
/// Deliberately NOT a [TaskCapsuleBlock] wrapping a synthetic [Task]: this
/// runs mid-creation, before a real, persisted task exists, and
/// `TaskCapsuleBlock` carries drag gestures, a completion checkbox, and
/// status logic that assume a real, saved task — none of which apply
/// here. This mirrors only the visual pieces (badge size/color/icon,
/// title/time text style) that make it read as the same design.
class _SchedulePreviewCard extends StatelessWidget {
  const _SchedulePreviewCard({
    required this.theme,
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.onEdit,
  });

  final AmbleTheme theme;
  final String title;
  final TaskCategory category;
  /// All three are null until the user has entered both a time and a
  /// duration — the preview then shows the task WITHOUT a time range
  /// rather than displaying a start or length nobody chose.
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationMinutes;

  /// Opens step 1 to edit the name/notes/category — null hides the pencil
  /// entirely (the standalone edit-schedule modal has no earlier step to
  /// return to).
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    // Same badge construction as TaskCapsuleBlock's own plain-category
    // case (no skipped/completed status exists yet at creation time, so
    // this never needs those branches).
    final badgeColor = theme.categoryColors[category.token]!;
    final iconColor = theme.categoryIconColors[category.token]!;
    final badgeSize = theme.spacingXl * 0.9;

    return AppPane(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(theme.radiusTaskPill),
            ),
            child: Icon(
              category.icon,
              size: badgeSize * 0.55,
              color: iconColor,
            ),
          ),
          SizedBox(width: theme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Task name' : title,
                  style: theme.textBody.copyWith(
                    color: title.isEmpty
                        ? theme.colorTextSecondary
                        : theme.colorTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  (startTime == null ||
                          endTime == null ||
                          durationMinutes == null)
                      ? 'Set a time and duration'
                      : '${_formatTime(startTime!)} - ${_formatTime(endTime!)} '
                            '(${_formatDuration(durationMinutes!)})',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onEdit != null)
            _HeaderCircleButton(
              theme: theme,
              icon: Icons.edit_outlined,
              onTap: onEdit!,
              // The other _HeaderCircleButton uses always sit on a
              // coloured banner (colorSurfacePrimary glyph on a tinted
              // background); this one sits on the ordinary card
              // background, so it needs the opposite contrast direction.
              backgroundColor: theme.colorSurfaceTimeline,
              iconColor: theme.colorTextSecondary,
            ),
        ],
      ),
    );
  }
}

/// Whole hours render as "1h"/"2h"; leftover minutes (or under an hour)
/// render as total minutes, e.g. "30m"/"90m" — same format
/// [TaskCapsuleBlock]'s own duration label uses on the Timeline, so the
/// preview and the real block never disagree about how a duration reads.
String _formatDuration(int minutes) {
  if (minutes % 60 == 0) return '${minutes ~/ 60}h';
  return '${minutes}m';
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final TaskCategory category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categoryColor = theme.categoryColors[category.token]!;

    // One tint-filled pill holding emoji + label (mockup), rather than a
    // separate circular icon beside loose text. Selection is carried by
    // the outline: the fill already encodes WHICH category this is, so
    // reusing it for state would make an unselected chip and a selected
    // one differ only in weight.
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: theme.motionFast,
        curve: theme.curveStandard,
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingMd,
          vertical: theme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: categoryColor,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          border: Border.all(
            color: selected ? theme.colorTextPrimary : Colors.transparent,
            width: theme.borderWidthHairline * 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.emoji, style: theme.textBody),
            SizedBox(width: theme.spacingSm),
            Text(
              category.label,
              style: theme.textBody.copyWith(
                color: theme.colorTextPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


String _formatDate(DateTime dateTime) {
  // "Today" when the date is today — requested directly for the date
  // button's label, matching the mockup exactly rather than always
  // spelling out the full date.
  final now = DateTime.now();
  if (dateTime.year == now.year &&
      dateTime.month == now.month &&
      dateTime.day == now.day) {
    return 'Today';
  }
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[dateTime.weekday - 1];
  final month = months[dateTime.month - 1];
  return '$weekday $month ${dateTime.day}, ${dateTime.year}';
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// "Repeats" control — an adaptive switch that reveals a day-of-week picker
/// only once enabled. Selecting all 7 days saves as
/// [RecurrenceFrequency.daily]; any smaller selection saves as weekly with
/// that exact [daysOfWeek] set. Shared by the create flow and the edit
/// flow's schedule step, including for an already-recurring task — turning
/// the switch off there disables the whole series (future instances
/// pruned); changing days there changes the series' rule. See
/// docs/DECISIONS.md.
class _RecurrencePanel extends StatelessWidget {
  const _RecurrencePanel({
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
    // No pane of its own — the caller wraps this in its own AppPane
    // (standalone, matching Notifications' treatment). Kept bare here
    // rather than owning its own AppPane directly, so it can still be
    // embedded inside another pane if a future layout calls for that.
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
          // Each chip is Expanded rather than fixed-width: seven chips
          // at the old fixed width came to ~328px, which overflowed the
          // panel on a normal phone (caught by a widget test as a
          // 40px RenderFlex overflow — it would have shown as the
          // yellow/black stripes on-device). Sharing the row means they
          // shrink to fit whatever width the sheet actually has.
          Row(
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++) ...[
                if (day > DateTime.monday) SizedBox(width: theme.spacingXs),
                Expanded(
                  child: AppSelectableChip(
                    label: _weekdayAbbreviations[day - 1],
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

const _weekdayAbbreviations = [
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN',
];

/// All 7 days selected maps to [RecurrenceFrequency.daily] — matching the
/// model's existing "daily" concept exactly. Any smaller selection maps to
/// weekly with that exact [daysOfWeek] set. `interval` stays 1. Shared by
/// the create flow (`_TaskDetailFlowState`) and the edit flow
/// (`_EditScheduleFormState`) — same [_RecurrencePanel], same rule shape,
/// one source of truth rather than two copies drifting apart.
RecurrenceRule _recurrenceRuleFromSelectedDays(Set<int> selectedDays) {
  if (selectedDays.length == 7) {
    return RecurrenceRule(frequency: RecurrenceFrequency.daily);
  }
  return RecurrenceRule(
    frequency: RecurrenceFrequency.weekly,
    daysOfWeek: selectedDays.toList()..sort(),
  );
}

/// The inverse of [_recurrenceRuleFromSelectedDays] — reconstructs which
/// day chips should show selected for an EXISTING rule, so opening an
/// already-recurring task's Repeats panel reflects its real days rather
/// than defaulting to just the task's own weekday. Daily has no
/// `daysOfWeek` (it means every day by definition), so that case maps back
/// to all 7.
Set<int> _selectedDaysFromRecurrenceRule(RecurrenceRule rule) {
  if (rule.frequency == RecurrenceFrequency.daily) {
    return {for (var day = DateTime.monday; day <= DateTime.sunday; day++) day};
  }
  return rule.daysOfWeek!.toSet();
}

/// Links this task to an existing tracked behavior, or to none. Only
/// rendered when [FeatureFlags.trackedBehaviorEnabled] is on.
class _BehaviorPickerPanel extends StatelessWidget {
  const _BehaviorPickerPanel({
    required this.theme,
    required this.behaviors,
    required this.selectedId,
    required this.onChanged,
  });

  final AmbleTheme theme;
  final List<TrackedBehavior> behaviors;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppPane(
      title: 'Tracked behavior',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (behaviors.isEmpty)
            Text(
              'No tracked behaviors yet — create one in Settings.',
              style: theme.textBody.copyWith(color: theme.colorTextSecondary),
            )
          else
            Wrap(
              spacing: theme.spacingSm,
              runSpacing: theme.spacingSm,
              children: [
                _BehaviorChip(
                  theme: theme,
                  label: 'None',
                  selected: selectedId == null,
                  onTap: () => onChanged(null),
                ),
                for (final behavior in behaviors)
                  _BehaviorChip(
                    theme: theme,
                    label: behavior.title,
                    selected: behavior.id == selectedId,
                    onTap: () => onChanged(behavior.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BehaviorChip extends StatelessWidget {
  const _BehaviorChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AmbleTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingMd,
          vertical: theme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: selected ? theme.colorAccent : theme.colorSurfaceTimeline,
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(
          label,
          style: theme.textBody.copyWith(
            color: selected
                ? theme.colorSurfacePrimary
                : theme.colorTextSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
