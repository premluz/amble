import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_flow.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../tracked_behavior/tracked_behavior_form.dart';

/// A selected tracked behavior, including an explicit None choice. The
/// wrapper keeps None distinct from dismissing the sheet.
class TaskBehaviorSelection {
  const TaskBehaviorSelection(this.behaviorId);

  final String? behaviorId;
}

/// The focused tracked-behavior picker used by quick add.
class TaskBehaviorModal extends ConsumerStatefulWidget {
  const TaskBehaviorModal({super.key, required this.behaviorId});

  final String? behaviorId;

  static Future<TaskBehaviorSelection?> show({
    required BuildContext context,
    required String? behaviorId,
  }) {
    return AppSheet.show<TaskBehaviorSelection>(
      context: context,
      builder: (context) => AppSheetFlow(
        theme: Theme.of(context).extension<AmbleTheme>()!,
        root: TaskBehaviorModal(behaviorId: behaviorId),
      ),
    );
  }

  @override
  ConsumerState<TaskBehaviorModal> createState() => _TaskBehaviorModalState();
}

class _TaskBehaviorModalState extends ConsumerState<TaskBehaviorModal> {
  void _select(String? behaviorId) {
    Navigator.of(context).pop(TaskBehaviorSelection(behaviorId));
  }

  /// A new habit is the next page of this sheet, not a sheet on top;
  /// saving it selects it and closes.
  void _addNewBehavior() => AppSheetFlow.of(context)
      .push(TrackedBehaviorPage(onSaved: (behavior) => _select(behavior.id)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final behaviors = ref.watch(trackedBehaviorListProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetFlowHeader(
          theme: theme,
          title: 'Tracked',
          trailing: AppButton(
            icon: Icons.add_rounded,
            variant: AppButtonVariant.primary,
            shape: AppButtonShape.circle,
            tooltip: 'Add tracked behavior',
            onPressed: _addNewBehavior,
          ),
        ),
        SizedBox(height: theme.spacingMd),
        AppSheetScrollBody(
          child: Wrap(
            spacing: theme.spacingSm,
            runSpacing: theme.spacingSm,
            children: [
              AppSelectableChip(
                label: 'None',
                size: AppSelectableChipSize.regular,
                selected: widget.behaviorId == null,
                onTap: () => _select(null),
              ),
              for (final behavior in behaviors)
                AppSelectableChip(
                  label: behavior.title,
                  size: AppSelectableChipSize.regular,
                  selected: behavior.id == widget.behaviorId,
                  onTap: () => _select(behavior.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
