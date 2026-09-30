import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_flow.dart';
import '../../shared/models/behavior_target_type.dart';
import 'custom_unit_sheet.dart';

/// The order used by the compact "Measured in" picker. It is explicit so the
/// persisted enum order stays independent from the order shown to users.
const trackedBehaviorMeasuredInOrder = [
  BehaviorTargetType.duration,
  BehaviorTargetType.distance,
  BehaviorTargetType.reps,
  BehaviorTargetType.count,
  BehaviorTargetType.binary,
];

class TrackedBehaviorUnitChoice {
  const TrackedBehaviorUnitChoice(this.type, {this.customUnit});

  final BehaviorTargetType type;
  final CustomUnit? customUnit;
}

String trackedBehaviorTypeLabel(
  BehaviorTargetType type, {
  String? customLabel,
}) => switch (type) {
  BehaviorTargetType.duration => 'Time',
  BehaviorTargetType.distance => 'Distance',
  BehaviorTargetType.reps => 'Reps',
  BehaviorTargetType.count => 'Count',
  BehaviorTargetType.custom => customLabel ?? 'Custom',
  BehaviorTargetType.binary => 'Did it',
};

Future<TrackedBehaviorUnitChoice?> showTrackedBehaviorUnitSheet(
  BuildContext context, {
  required BehaviorTargetType initial,
}) {
  return AppSheet.show<TrackedBehaviorUnitChoice>(
    context: context,
    builder: (context) => AppSheetFlow(
      theme: Theme.of(context).extension<AmbleTheme>()!,
      root: _TrackedBehaviorUnitPage(initial: initial),
    ),
  );
}

class _TrackedBehaviorUnitPage extends StatelessWidget {
  const _TrackedBehaviorUnitPage({required this.initial});

  final BehaviorTargetType initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetFlowHeader(
          theme: theme,
          title: 'Measured in',
          trailing: AppButton(
            icon: Icons.add_rounded,
            variant: AppButtonVariant.primary,
            shape: AppButtonShape.circle,
            tooltip: 'Add custom unit',
            onPressed: () => _openCustomUnit(context),
          ),
        ),
        SizedBox(height: theme.spacingMd),
        Wrap(
          spacing: theme.spacingSm,
          runSpacing: theme.spacingSm,
          children: [
            for (final type in trackedBehaviorMeasuredInOrder)
              AppSelectableChip(
                label: trackedBehaviorTypeLabel(type),
                selected: type == initial,
                size: AppSelectableChipSize.regular,
                onTap: () =>
                    Navigator.of(context).pop(TrackedBehaviorUnitChoice(type)),
              ),
          ],
        ),
      ],
    );
  }

  void _openCustomUnit(BuildContext context) {
    AppSheetFlow.of(context).push(
      CustomUnitPage(
        onSaved: (customUnit) => Navigator.of(context).pop(
          TrackedBehaviorUnitChoice(
            BehaviorTargetType.custom,
            customUnit: customUnit,
          ),
        ),
      ),
    );
  }
}
