import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_selectable_chip.dart';
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

/// "Measured in" as a page, pushed inside the habit form's sheet; a custom
/// unit opens as the next page. [onChosen] takes the choice.
class TrackedBehaviorUnitPage extends StatelessWidget {
  const TrackedBehaviorUnitPage({
    super.key,
    required this.initial,
    required this.onChosen,
  });

  final BehaviorTargetType initial;

  final ValueChanged<TrackedBehaviorUnitChoice> onChosen;

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
                onTap: () => onChosen(TrackedBehaviorUnitChoice(type)),
              ),
          ],
        ),
      ],
    );
  }

  void _openCustomUnit(BuildContext context) {
    AppSheetFlow.of(context).push(
      CustomUnitPage(
        onSaved: (customUnit) => onChosen(
          TrackedBehaviorUnitChoice(
            BehaviorTargetType.custom,
            customUnit: customUnit,
          ),
        ),
      ),
    );
  }
}
