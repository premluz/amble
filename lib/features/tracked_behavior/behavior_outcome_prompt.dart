import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../shared/models/behavior_target_type.dart';
import '../../shared/models/tracked_behavior.dart';
import 'tracked_behavior_form.dart' show unitLabelFor;

/// Asks for the actual amount achieved when completing a task linked to
/// [behavior]. Returns the recorded amount, or null if dismissed.
///
/// Deliberately amount-only: no reason, reflection, or mood field. Those
/// are a later increment per this session's non-goals — the smallest useful
/// loop is "what actually happened," not "why".
///
/// A binary behavior has nothing to quantify, so callers skip this entirely
/// (see [behaviorNeedsOutcomePrompt]) rather than showing a prompt with one
/// meaningless field.
Future<num?> showBehaviorOutcomePrompt(
  BuildContext context, {
  required TrackedBehavior behavior,
}) {
  return AppSheet.show<num>(
    context: context,
    builder: (context) => _BehaviorOutcomePrompt(behavior: behavior),
  );
}

/// Whether completing a task linked to [behavior] should ask for an amount.
///
/// False for binary behaviors — "did it happen" is already answered by the
/// completion itself, so prompting would add friction with nothing to gain.
bool behaviorNeedsOutcomePrompt(TrackedBehavior behavior) =>
    behavior.targetType != BehaviorTargetType.binary;

class _BehaviorOutcomePrompt extends StatefulWidget {
  const _BehaviorOutcomePrompt({required this.behavior});

  final TrackedBehavior behavior;

  @override
  State<_BehaviorOutcomePrompt> createState() => _BehaviorOutcomePromptState();
}

class _BehaviorOutcomePromptState extends State<_BehaviorOutcomePrompt> {
  late final TextEditingController _controller = TextEditingController(
    // Pre-filled with the target: the common case is hitting it, so the
    // fast path is "confirm", not "type a number".
    text: widget.behavior.targetAmount?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  num? get _amount => num.tryParse(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final behavior = widget.behavior;
    final unit = unitLabelFor(behavior.targetType);
    final target = behavior.targetAmount;
    final minimum = behavior.minimumAmount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How did it go?', style: theme.textTitle),
        SizedBox(height: theme.spacingXs),
        Text(
          behavior.title,
          style: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
        SizedBox(height: theme.spacingLg),

        Text('Actual ($unit)', style: theme.textCaption),
        SizedBox(height: theme.spacingXs),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: theme.textBody.copyWith(color: theme.colorTextPrimary),
          decoration: const InputDecoration(isDense: true),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: theme.spacingSm),

        // Context, stated neutrally. Per design principle 1 the plan is
        // provisional, not a verdict — this shows what was intended without
        // grading the result, so falling short is never shame-coded.
        Text(
          [
            if (target != null) 'Target $target $unit',
            if (minimum != null) 'minimum $minimum $unit',
          ].join(' · '),
          style: theme.textCaption.copyWith(color: theme.colorTextSecondary),
        ),
        SizedBox(height: theme.spacingLg),

        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Skip',
                variant: AppButtonVariant.secondary,
                // Completing without recording an amount is legitimate —
                // the task is still done, `actualAmount` simply stays null.
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: theme.spacingMd),
            Expanded(
              child: AppButton(
                label: 'Record',
                onPressed: _amount == null
                    ? null
                    : () => Navigator.of(context).pop(_amount),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
