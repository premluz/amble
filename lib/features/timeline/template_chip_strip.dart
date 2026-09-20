import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_badge_chip.dart';
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
    this.edgeInset,
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

  /// Horizontal inset applied to the first/last chip so they line up with
  /// the padded fields above — defaults to `theme.spacingLg`, matching the
  /// quick-create mini sheet's own full-bleed caller (see this class's own
  /// doc comment). A caller that already sits inside its own side margin
  /// (rather than rendering this strip full-bleed) passes 0 instead of
  /// double-applying that inset.
  final double? edgeInset;

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
        padding: EdgeInsets.symmetric(horizontal: edgeInset ?? theme.spacingLg),
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
    // Smaller than TemplateRow's own `spacingXl` badge — these chips sit
    // in a much shorter row and carry no second line of text to balance
    // a full-size badge against.
    final badgeSize = theme.spacingLg;

    return AppBadgeChip(
      theme: theme,
      selected: selected,
      onTap: onTap,
      leading: CategoryBadge(
        theme: theme,
        category: category,
        size: badgeSize,
        // 0.65, not CategoryBadge's own 0.55 default — reported directly
        // ("Badge on add task sheet icons too small"): a Tabler icon's
        // thin stroke reads smaller than an emoji glyph did at the
        // identical nominal size, on this app's smallest badge
        // (`spacingLg`, vs. `sizeTaskBadge` everywhere else CategoryBadge's
        // default ratio was tuned for).
        glyphSizeRatio: 0.65,
      ),
      // No duration line here, unlike TemplateRow — see
      // TemplateChipStrip's own doc comment on why duration is
      // deliberately absent from this context entirely.
      label: template.title,
    );
  }
}
