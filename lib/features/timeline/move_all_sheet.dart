import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_field_action_button.dart';
import '../../core/widgets/app_option_switch_option.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_segmented_time_field.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_tab_switch.dart';
import '../../core/widgets/app_wheel_time_picker.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/services/move_all_deltas.dart';
import '../../shared/services/move_resize_undo.dart';

/// Bulk-shifts every task on [around]'s own day that falls on one side of
/// it, by a picked h:m amount — requested directly as part of the
/// hold-and-drag placement release menu's "Move all" entry: "this allows
/// to move all tasks before/or after the selected point, by selected h:m
/// from wheeler, later or earlier."
///
/// Reuses [TaskList.shiftTasksByMinutes] (the same uniform per-task-delta
/// write Zone move/resize's own cascade already uses) rather than a new
/// write path — every affected task gets the SAME delta, which is exactly
/// what that method already does. Wrapped in [commitTaskChangeWithUndo]
/// so this gets the same undo toast every other move/resize commit does.
Future<void> showMoveAllSheet(BuildContext context, {required DateTime around}) {
  return AppSheet.show<void>(
    context: context,
    builder: (sheetContext) => _MoveAllForm(around: around),
  );
}

class _MoveAllForm extends ConsumerStatefulWidget {
  const _MoveAllForm({required this.around});

  final DateTime around;

  @override
  ConsumerState<_MoveAllForm> createState() => _MoveAllFormState();
}

class _MoveAllFormState extends ConsumerState<_MoveAllForm> {
  int _hour = 0;
  int _minute = 30;
  MoveAllDirection _direction = MoveAllDirection.beforeToLater;
  bool _isSaving = false;

  int get _deltaMinutes => _hour * 60 + _minute;

  Future<void> _pickAmount() async {
    final result = await AppWheelTimePicker.show(
      context: context,
      title: 'Move by',
      initialHour: _hour,
      initialMinute: _minute,
    );
    if (result == null) return;
    setState(() {
      _hour = result.$1;
      _minute = result.$2;
    });
  }

  Future<void> _move() async {
    if (_isSaving || _deltaMinutes == 0) return;
    setState(() => _isSaving = true);

    final deltas = computeMoveAllDeltas(
      tasks: ref.read(taskListProvider),
      around: widget.around,
      direction: _direction,
      amountMinutes: _deltaMinutes,
    );

    final navigator = Navigator.of(context);
    if (deltas.isNotEmpty) {
      await commitTaskChangeWithUndo(
        context,
        ref,
        taskIds: deltas.keys,
        message: 'Moved ${deltas.length} task(s)',
        commit: () => ref
            .read(taskListProvider.notifier)
            .shiftTasksByMinutes(deltas),
      );
    }
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AppSheet's own outer padding no longer provides a top inset
        // (2026-09-23 — "top padding should be in header").
        SizedBox(height: theme.spacingLg),
        Text(
          'Move all',
          style: theme.textTitle.copyWith(color: theme.colorTextPrimary),
        ),
        SizedBox(height: theme.spacingMd),
        AppTabSwitch<MoveAllDirection>(
          value: _direction,
          options: const [
            AppOptionSwitchOption(
              value: MoveAllDirection.beforeToLater,
              label: 'Before this point',
            ),
            AppOptionSwitchOption(
              value: MoveAllDirection.afterToEarlier,
              label: 'After this point',
            ),
          ],
          onChanged: (value) => setState(() => _direction = value),
        ),
        SizedBox(height: theme.spacingSm),
        AppPane(
          child: AppSegmentedTimeField(
            label: 'Move by',
            first: _hour,
            second: _minute,
            firstMax: 23,
            trailing: AppFieldActionButton(
              icon: Icons.schedule_rounded,
              semanticLabel: 'Choose amount to move by',
              onPressed: _pickAmount,
            ),
            onChanged: (hour, minute) => setState(() {
              _hour = hour;
              _minute = minute;
            }),
          ),
        ),
        SizedBox(height: theme.spacingLg),
        AppButton(
          label: _direction == MoveAllDirection.beforeToLater
              ? 'Move earlier tasks later'
              : 'Move later tasks earlier',
          onPressed: _move,
          isLoading: _isSaving,
          shape: AppButtonShape.pill,
          size: AppButtonSize.lg,
        ),
      ],
    );
  }
}
