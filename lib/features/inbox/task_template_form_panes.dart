import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../shared/models/category.dart';
import '../../shared/models/tracked_behavior.dart';

/// The optional TrackedBehavior link. A local copy of the task detail
/// sheet's own (private) behavior picker rather than a shared extraction —
/// promoting that one would mean editing a 2700-line file outside this
/// task's scope; flagged as a reuse opportunity for whichever session next
/// touches `task_detail_sheet.dart`.
class TemplateBehaviorPane extends StatelessWidget {
  const TemplateBehaviorPane({
    super.key,
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
      child: behaviors.isEmpty
          ? Text(
              'No tracked behaviors yet — create one in Settings.',
              style: theme.textBody.copyWith(color: theme.colorTextSecondary),
            )
          : Wrap(
              spacing: theme.spacingSm,
              runSpacing: theme.spacingSm,
              children: [
                AppSelectableChip(
                  label: 'None',
                  selected: selectedId == null,
                  onTap: () => onChanged(null),
                ),
                for (final behavior in behaviors)
                  AppSelectableChip(
                    label: behavior.title,
                    selected: behavior.id == selectedId,
                    onTap: () => onChanged(behavior.id),
                  ),
              ],
            ),
    );
  }
}

/// The template's category picker — the same live [Category] list and chip
/// treatment the task detail sheet's own Category pane shows, so the two
/// creation surfaces read identically.
class TemplateCategoryPane extends StatelessWidget {
  const TemplateCategoryPane({
    super.key,
    required this.theme,
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  final AmbleTheme theme;
  final List<Category> categories;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppPane(
      title: 'Category',
      child: Wrap(
        spacing: theme.spacingSm,
        runSpacing: theme.spacingSm,
        children: [
          for (final category in categories)
            AppSelectableChip(
              label: '${category.emoji} ${category.name}',
              selected: category.id == selectedId,
              onTap: () => onChanged(category.id),
            ),
        ],
      ),
    );
  }
}

/// The template's optional default duration. Reuses the task detail
/// screen's own `TaskDurationModal` (via [onPick]) rather than a second
/// duration control, so "30 min" is entered the same way everywhere.
class TemplateDurationPane extends StatelessWidget {
  const TemplateDurationPane({
    super.key,
    required this.theme,
    required this.durationMinutes,
    required this.onPick,
    required this.onClear,
  });

  final AmbleTheme theme;

  /// Null is a real, valid state — a template with no duration suggestion
  /// simply leaves the spawned task's own duration field empty.
  final int? durationMinutes;

  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final minutes = durationMinutes;
    return AppPane(
      title: 'Default duration',
      child: Row(
        children: [
          Expanded(
            child: Text(
              minutes == null ? 'Not set' : '$minutes min',
              style: theme.textBody.copyWith(
                color: minutes == null
                    ? theme.colorTextSecondary
                    : theme.colorTextPrimary,
              ),
            ),
          ),
          // "Clear" appears only once a duration exists — unset is the
          // template's own valid default, so there is nothing to clear
          // before one has been chosen.
          if (minutes != null)
            AppButton(
              label: 'Clear',
              variant: AppButtonVariant.secondary,
              onPressed: onClear,
            ),
          SizedBox(width: theme.spacingSm),
          AppButton(
            label: minutes == null ? 'Set' : 'Change',
            variant: AppButtonVariant.secondary,
            onPressed: onPick,
          ),
        ],
      ),
    );
  }
}
