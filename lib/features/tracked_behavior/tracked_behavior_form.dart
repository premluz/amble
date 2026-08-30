import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../shared/models/behavior_target_type.dart';
import '../../shared/providers/tracked_behavior_providers.dart';

/// Opens the "create tracked behavior" sheet.
///
/// Presented via [AppSheet] rather than Phase 4's near-full-screen modal:
/// that pattern exists for the task detail screen's colored edge-to-edge
/// header and wheel/slider controls, none of which this form has. Five
/// short fields don't justify a full-screen takeover — see docs/DECISIONS.md.
///
/// All writes go through `trackedBehaviorListProvider`; this UI never
/// touches the repository or Hive directly.
Future<void> showTrackedBehaviorForm(BuildContext context) {
  return AppSheet.show(
    context: context,
    builder: (context) => const _TrackedBehaviorForm(),
  );
}

class _TrackedBehaviorForm extends ConsumerStatefulWidget {
  const _TrackedBehaviorForm();

  @override
  ConsumerState<_TrackedBehaviorForm> createState() =>
      _TrackedBehaviorFormState();
}

class _TrackedBehaviorFormState extends ConsumerState<_TrackedBehaviorForm> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _minimumController = TextEditingController();

  BehaviorTargetType _targetType = BehaviorTargetType.duration;
  int _timesPerWeek = 3;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _minimumController.dispose();
    super.dispose();
  }

  /// A binary behavior has no amount to hit, so its target field is hidden
  /// and no amount is submitted — matching the model's own invariant
  /// (`targetAmount` is required unless the type is binary).
  bool get _isBinary => _targetType == BehaviorTargetType.binary;

  bool get _canSave {
    if (_titleController.text.trim().isEmpty) return false;
    if (_isBinary) return true;
    return num.tryParse(_targetController.text.trim()) != null;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    await ref
        .read(trackedBehaviorListProvider.notifier)
        .createBehavior(
          title: _titleController.text.trim(),
          targetType: _targetType,
          targetAmount: _isBinary
              ? null
              : num.tryParse(_targetController.text.trim()),
          minimumAmount: num.tryParse(_minimumController.text.trim()),
          timesPerWeek: _timesPerWeek,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Track a behavior', style: theme.textTitle),
        SizedBox(height: theme.spacingMd),

        TextField(
          controller: _titleController,
          autofocus: true,
          style: theme.textBody.copyWith(color: theme.colorTextPrimary),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'What are you tracking?',
          ),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: theme.spacingLg),

        Text('Measured in', style: theme.textCaption),
        SizedBox(height: theme.spacingSm),
        Row(
          children: [
            for (final type in BehaviorTargetType.values) ...[
              _TypeChip(
                theme: theme,
                label: _labelFor(type),
                selected: type == _targetType,
                onTap: () => setState(() => _targetType = type),
              ),
              SizedBox(width: theme.spacingSm),
            ],
          ],
        ),
        SizedBox(height: theme.spacingLg),

        if (!_isBinary) ...[
          Row(
            children: [
              Expanded(
                child: _AmountField(
                  theme: theme,
                  controller: _targetController,
                  label: 'Target (${_unitFor(_targetType)})',
                  onChanged: () => setState(() {}),
                ),
              ),
              SizedBox(width: theme.spacingMd),
              Expanded(
                child: _AmountField(
                  theme: theme,
                  controller: _minimumController,
                  label: 'Minimum (optional)',
                  onChanged: () => setState(() {}),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacingLg),
        ],

        Row(
          children: [
            Text('Times per week', style: theme.textBody),
            const Spacer(),
            _Stepper(
              theme: theme,
              value: _timesPerWeek,
              onChanged: (value) => setState(() => _timesPerWeek = value),
            ),
          ],
        ),
        SizedBox(height: theme.spacingLg),

        SizedBox(
          width: double.infinity,
          child: AppButton(label: 'Save', onPressed: _canSave ? _save : null),
        ),
      ],
    );
  }

  String _labelFor(BehaviorTargetType type) => switch (type) {
    BehaviorTargetType.duration => 'Duration',
    BehaviorTargetType.count => 'Count',
    BehaviorTargetType.binary => 'Did it',
  };
}

/// The unit a target amount is expressed in, for labels and prompts.
String _unitFor(BehaviorTargetType type) => switch (type) {
  BehaviorTargetType.duration => 'min',
  BehaviorTargetType.count => 'reps',
  BehaviorTargetType.binary => '',
};

/// Shared so the outcome prompt labels its field the same way the create
/// form did — a "60 min" target should read back as minutes, not a bare
/// number.
String unitLabelFor(BehaviorTargetType type) => _unitFor(type);

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.theme,
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final AmbleTheme theme;
  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textCaption),
        SizedBox(height: theme.spacingXs),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: theme.textBody.copyWith(color: theme.colorTextPrimary),
          decoration: const InputDecoration(isDense: true, hintText: '—'),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
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
          borderRadius: BorderRadius.circular(theme.radiusTaskPill),
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

/// Minimal −/+ stepper, mirroring the recurrence interval stepper's shape
/// so the two settings-style controls read consistently.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  final AmbleTheme theme;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorSurfaceTimeline,
        borderRadius: BorderRadius.circular(theme.radiusTaskPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            theme: theme,
            icon: Icons.remove_rounded,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Text(
            '$value',
            style: theme.textBody.copyWith(
              color: theme.colorTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          _StepperButton(
            theme: theme,
            icon: Icons.add_rounded,
            // 7 is every day — more than that isn't a weekly frequency.
            onTap: value < 7 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.theme,
    required this.icon,
    required this.onTap,
  });

  final AmbleTheme theme;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.all(theme.spacingSm),
        child: Icon(
          icon,
          size: theme.spacingMd,
          color: onTap == null ? theme.colorTextSecondary : theme.colorAccent,
        ),
      ),
    );
  }
}
