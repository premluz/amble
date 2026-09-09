import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/tracked_behavior.dart';
import 'tracked_behavior_form.dart';

/// One behavior row — title, and its target read back in words. Public so
/// a widget test can target it directly.
class TrackedBehaviorRow extends StatelessWidget {
  const TrackedBehaviorRow({
    super.key,
    required this.theme,
    required this.behavior,
    required this.onTap,
  });

  final AmbleTheme theme;
  final TrackedBehavior behavior;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusXl),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(theme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusXl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    behavior.title,
                    style: theme.textBody.copyWith(
                      color: theme.colorTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: theme.spacingXs),
                  Text(
                    describeBehaviorTarget(behavior),
                    style: theme.textBody.copyWith(
                      color: theme.colorTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorTextSecondary),
          ],
        ),
      ),
    );
  }
}

/// One line describing a behavior's target type, amount, and frequency —
/// e.g. "60 min · 3x a week", or "Did it · 5x a week" for a binary
/// behavior, which has no amount by definition.
///
/// A top-level function, not a row method, so a test can exercise the
/// wording directly without mounting a widget — the same shape
/// `_zoneSummary`/`_behaviorSummary` already use in `settings_screen.dart`.
String describeBehaviorTarget(TrackedBehavior behavior) {
  final frequency = '${behavior.timesPerWeek}x a week';
  if (behavior.isBinary) return 'Did it · $frequency';

  final amount = behavior.targetAmount;
  // Defensive: the model's constructor asserts a non-binary behavior has a
  // target, but an assert is debug-only, so this must not render "null" in
  // a release build if a malformed row ever reaches here.
  if (amount == null) return frequency;

  final minimum = behavior.minimumAmount;
  final unit = unitLabelFor(behavior.targetType);
  final target = '${_formatAmount(amount)} $unit';
  if (minimum == null) return '$target · $frequency';
  return '$target (min ${_formatAmount(minimum)}) · $frequency';
}

/// Renders an amount without a trailing ".0" — a 60-minute target reads
/// "60 min", not "60.0 min".
String _formatAmount(num amount) {
  if (amount is int) return amount.toString();
  if (amount == amount.roundToDouble()) return amount.round().toString();
  return amount.toString();
}
