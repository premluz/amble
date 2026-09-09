import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task_template.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/task_template_providers.dart';
import '../task_detail/category_visual.dart';

/// A horizontally scrollable strip of "mini" template cards for the
/// quick-create mini sheet.
///
/// Deliberately a separate widget from the Inbox's own [TemplateRow]
/// rather than a mode of it: same visual family (category badge + title
/// on a `colorSurfaceSecondary` rounded card), but a genuinely different
/// layout — no duration line, a smaller badge, sized to its content and
/// laid out horizontally instead of filling a vertical list row. Folding
/// both into one widget would mean threading several booleans through
/// [TemplateRow] to switch off half of what it does.
///
/// **Applying a chip sets the title and category only — never the
/// duration.** That is the whole point of the strip in this context,
/// specified directly: the user has already expressed the duration and
/// start/end by dragging and resizing the placeholder pill, so a
/// template's own `durationMinutes` (a suggestion, not an enforced
/// value — see [TaskTemplate.durationMinutes]) must not overwrite it.
/// This is the opposite of the Inbox's `useTemplate`, which DOES carry
/// duration across, because there the user has expressed no duration yet.
class TemplateChipStrip extends ConsumerWidget {
  const TemplateChipStrip({
    super.key,
    required this.onTemplateSelected,
    this.selectedTemplateId,
  });

  /// Applies the tapped template's title and category to the in-progress
  /// task. The strip itself is stateless about what it means to "apply" —
  /// the mini sheet owns that, since it holds the title controller and
  /// the draft.
  final void Function(TaskTemplate template) onTemplateSelected;

  /// Marks one chip as the applied one, so tapping a second template
  /// visibly replaces the first rather than silently swapping values in
  /// a field the user may not be looking at.
  final String? selectedTemplateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final templates = ref.watch(taskTemplateListProvider);
    final categories = ref.watch(categoryListProvider);

    // No templates saved yet is an ordinary state, not an error or an
    // empty-state worth explaining inside a 25%-height sheet — the strip
    // simply isn't there, and the rest of the sheet closes up around it.
    if (templates.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      // Deliberately shorter than the badge+padding sum would give:
      // reported directly as "templates cards smaller height." The chip's
      // own vertical padding is trimmed to match (see TemplateChip).
      height: theme.spacingXl + theme.spacingSm,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // The strip is rendered full-bleed by its caller so it can scroll
        // past both edges of the sheet; this inset keeps the first and
        // last chip aligned with the padded fields above it.
        padding: EdgeInsets.symmetric(horizontal: theme.spacingLg),
        itemCount: templates.length,
        separatorBuilder: (context, _) => SizedBox(width: theme.spacingSm),
        itemBuilder: (context, index) {
          final template = templates[index];
          return TemplateChip(
            key: ValueKey(template.id),
            theme: theme,
            template: template,
            category: categories
                .where((c) => c.id == template.categoryId)
                .firstOrNull,
            selected: template.id == selectedTemplateId,
            onTap: () => onTemplateSelected(template),
          );
        },
      ),
    );
  }
}

/// One mini template card — a small category badge and the title, sized to
/// its content. Public so a widget test can target it directly, the same
/// reason [TemplateRow] is.
class TemplateChip extends StatelessWidget {
  const TemplateChip({
    super.key,
    required this.theme,
    required this.template,
    required this.category,
    required this.onTap,
    this.selected = false,
  });

  final AmbleTheme theme;
  final TaskTemplate template;

  /// Null only if the template references a category that no longer
  /// resolves — falls back to the neutral General colour rather than
  /// failing to render, matching [TemplateRow]'s own handling.
  final Category? category;

  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final resolved = category;
    final badgeColor = resolved == null
        ? theme.categoryColors[TaskCategoryToken.general]!
        : resolveCategoryVisual(theme: theme, category: resolved).pillColor;
    // Smaller than TemplateRow's own `spacingXl` badge — these chips sit
    // in a much shorter row and carry no second line of text to balance
    // a full-size badge against.
    final badgeSize = theme.spacingLg;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // Tighter vertically than horizontally — these are short, wide
        // chips, not square cards.
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingMd,
          vertical: theme.spacingXs,
        ),
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusXl),
          border: selected ? Border.all(color: theme.colorAccent) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: badgeSize,
              height: badgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                resolved?.emoji ?? '',
                style: TextStyle(fontSize: badgeSize * 0.5),
              ),
            ),
            SizedBox(width: theme.spacingSm),
            // No duration line here, unlike TemplateRow — see
            // TemplateChipStrip's own doc comment on why duration is
            // deliberately absent from this context entirely.
            Text(
              template.title,
              style: theme.textBody.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
