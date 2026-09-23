import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_badge_chip.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_switch.dart';
import '../../shared/models/task.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import 'category_visual.dart';
import 'task_category_modal.dart';
import 'task_duration_modal.dart';

/// Bulk edit for 2+ tasks selected under Edit Mode's multi-select route
/// (`editSelectionProvider`) — requested directly: "if more than 1 item
/// selected, edit opens multi edit sheet (can only tag, track, duration,
/// notification)," later widened to also include Important ("multi edit
/// tasks should have also important"). Deliberately a NARROWER field set
/// than the single-task
/// detail sheet ([showTaskDetailSheet]) — no title, no schedule (each
/// selected task keeps its own time), no repeat — since those are either
/// meaningless in bulk (a shared title) or already have their own group
/// gesture on the Timeline itself (move/resize already apply to the whole
/// selection via drag).
///
/// **A field with DIFFERING values across the selection shows a neutral
/// "Mixed" state** rather than any one task's value (confirmed via
/// AskUserQuestion) — standard bulk-edit UX, so Save can never silently
/// overwrite every task with whichever one happened to load first. Only a
/// field the user actually TOUCHES gets applied to every selected task;
/// an untouched "Mixed" field leaves each task's own existing value alone.
Future<void> showMultiTaskEditSheet(
  BuildContext context, {
  required List<String> taskIds,
}) {
  return AppSheet.show<void>(
    context: context,
    size: AppSheetSize.half,
    builder: (context) => _MultiTaskEditForm(taskIds: taskIds),
  );
}

class _MultiTaskEditForm extends ConsumerStatefulWidget {
  const _MultiTaskEditForm({required this.taskIds});

  final List<String> taskIds;

  @override
  ConsumerState<_MultiTaskEditForm> createState() =>
      _MultiTaskEditFormState();
}

class _MultiTaskEditFormState extends ConsumerState<_MultiTaskEditForm> {
  /// Null means "untouched — leave each task's own value alone," matching
  /// every field below exactly. Distinct from "mixed but user explicitly
  /// chose null" (e.g. clearing the tracked-behavior link), which sets the
  /// SAME `String?` field to an actual value rather than leaving it null
  /// here — see [_behaviorTouched].
  String? _categoryId;
  bool _categoryTouched = false;

  String? _behaviorId;
  bool _behaviorTouched = false;

  int? _durationMinutes;
  bool _durationTouched = false;

  bool? _notificationsEnabled;
  bool _notificationsTouched = false;

  bool? _isImportant;
  bool _importantTouched = false;

  bool _isSaving = false;

  List<Task> get _tasks => widget.taskIds
      .map((id) => ref.read(taskByIdProvider(id)))
      .whereType<Task>()
      .toList();

  /// The one shared value across [_tasks] for [selector], or null if they
  /// differ (or there are no tasks) — the "Mixed" trigger for every field
  /// below.
  T? _commonValue<T>(T? Function(Task) selector) {
    final tasks = _tasks;
    if (tasks.isEmpty) return null;
    final first = selector(tasks.first);
    for (final task in tasks.skip(1)) {
      if (selector(task) != first) return null;
    }
    return first;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(taskListProvider.notifier);
      for (final task in _tasks) {
        var changed = false;
        if (_categoryTouched && task.categoryId != _categoryId) {
          task.categoryId = _categoryId;
          changed = true;
        }
        if (_behaviorTouched && task.behaviorId != _behaviorId) {
          task.behaviorId = _behaviorId;
          changed = true;
        }
        if (_durationTouched &&
            _durationMinutes != null &&
            task.durationMinutes != _durationMinutes) {
          task.durationMinutes = _durationMinutes;
          changed = true;
        }
        if (_notificationsTouched &&
            _notificationsEnabled != null &&
            task.notificationsEnabled != _notificationsEnabled) {
          task.notificationsEnabled = _notificationsEnabled!;
          changed = true;
        }
        if (_importantTouched &&
            _isImportant != null &&
            task.isImportant != _isImportant) {
          task.isImportant = _isImportant!;
          changed = true;
        }
        if (changed) await notifier.updateTask(task);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categories = ref.watch(categoryListProvider);
    final behaviors = ref.watch(trackedBehaviorListProvider);

    final effectiveCategoryId = _categoryTouched
        ? _categoryId
        : _commonValue((t) => t.categoryId);
    final effectiveBehaviorId = _behaviorTouched
        ? _behaviorId
        : _commonValue((t) => t.behaviorId);
    final effectiveDuration = _durationTouched
        ? _durationMinutes
        : _commonValue((t) => t.durationMinutes);
    final effectiveNotifications = _notificationsTouched
        ? _notificationsEnabled
        : _commonValue((t) => t.notificationsEnabled);
    final effectiveImportant = _importantTouched
        ? _isImportant
        : _commonValue((t) => t.isImportant);

    final category = categories
        .where((c) => c.id == effectiveCategoryId)
        .firstOrNull;
    final behavior = behaviors
        .where((b) => b.id == effectiveBehaviorId)
        .firstOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.taskIds.length} tasks selected',
          style: theme.textTitle,
        ),
        SizedBox(height: theme.spacingMd),
        AppPane(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tag',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final result = await TaskCategoryModal.show(
                    context: context,
                    categoryId: effectiveCategoryId,
                  );
                  if (result == null) return;
                  setState(() {
                    _categoryId = result;
                    _categoryTouched = true;
                  });
                },
                child: AppBadgeChip(
                  theme: theme,
                  leading: CategoryBadge(
                    theme: theme,
                    category: category,
                    size: theme.spacingLg,
                  ),
                  label: category?.name ?? 'Mixed',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacingSm),
        AppPane(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Track',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showBehaviorPicker(behaviors, effectiveBehaviorId),
                child: AppBadgeChip(
                  theme: theme,
                  leading: Icon(
                    Icons.track_changes_rounded,
                    size: theme.spacingLg,
                    color: theme.colorTextSecondary,
                  ),
                  label: behavior?.title ?? (_behaviorTouched ? 'None' : 'Mixed'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacingSm),
        AppPane(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Duration',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final result = await TaskDurationModal.show(
                    context: context,
                    initialMinutes: effectiveDuration,
                  );
                  if (result == null) return;
                  setState(() {
                    _durationMinutes = result;
                    _durationTouched = true;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacingMd,
                    vertical: theme.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorSurfaceSecondary,
                    borderRadius: BorderRadius.circular(theme.radiusXl),
                  ),
                  child: Text(
                    effectiveDuration != null
                        ? presetLabel(effectiveDuration)
                        : 'Mixed',
                    style: theme.textBody.copyWith(
                      color: theme.colorTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacingSm),
        AppPane(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notifications',
                style: theme.textBody.copyWith(color: theme.colorTextPrimary),
              ),
              // Mixed renders as OFF (a tri-state switch doesn't exist in
              // this design system) — any toggle immediately counts as a
              // deliberate choice for every selected task, same as every
              // other field here.
              AppSwitch(
                value: effectiveNotifications ?? false,
                onChanged: (value) => setState(() {
                  _notificationsEnabled = value;
                  _notificationsTouched = true;
                }),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacingSm),
        AppPane(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Important',
                style: theme.textBody.copyWith(color: theme.colorTextPrimary),
              ),
              // Mixed renders as OFF, same reasoning as Notifications
              // above — no tri-state switch in this design system, so any
              // toggle immediately counts as a deliberate choice for
              // every selected task.
              AppSwitch(
                value: effectiveImportant ?? false,
                onChanged: (value) => setState(() {
                  _isImportant = value;
                  _importantTouched = true;
                }),
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacingLg),
        AppButton(
          label: 'Save',
          onPressed: _save,
          isLoading: _isSaving,
          shape: AppButtonShape.pill,
          size: AppButtonSize.lg,
        ),
      ],
    );
  }

  /// Wraps the picked behavior id so "explicitly chose None" (`value:
  /// null`) is distinguishable from "dismissed the sheet without
  /// choosing" (the whole wrapper itself is null) — [AppSheet.show]
  /// resolves to a bare `null` for BOTH otherwise, since a plain
  /// `Navigator.pop(null)` (None) and swiping the sheet away collapse to
  /// the identical `Future<String?>` value.
  Future<void> _showBehaviorPicker(
    List<TrackedBehavior> behaviors,
    String? currentId,
  ) async {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final result = await AppSheet.show<_BehaviorPick>(
      context: context,
      size: AppSheetSize.half,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Track', style: theme.textTitle),
          SizedBox(height: theme.spacingMd),
          Wrap(
            spacing: theme.spacingSm,
            runSpacing: theme.spacingSm,
            children: [
              _BehaviorOption(
                theme: theme,
                label: 'None',
                selected: currentId == null,
                onTap: () => Navigator.of(
                  context,
                ).pop(const _BehaviorPick(null)),
              ),
              for (final behavior in behaviors)
                _BehaviorOption(
                  theme: theme,
                  label: behavior.title,
                  selected: currentId == behavior.id,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_BehaviorPick(behavior.id)),
                ),
            ],
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _behaviorId = result.id;
      _behaviorTouched = true;
    });
  }
}

/// See [_MultiTaskEditFormState._showBehaviorPicker]'s own doc comment.
class _BehaviorPick {
  const _BehaviorPick(this.id);

  final String? id;
}

class _BehaviorOption extends StatelessWidget {
  const _BehaviorOption({
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
          color: selected ? theme.colorAccent : theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(
          label,
          style: theme.textBody.copyWith(
            color: selected ? theme.colorSurfacePrimary : theme.colorTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
