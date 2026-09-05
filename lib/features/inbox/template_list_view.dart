import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_template.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/task_template_providers.dart';
import '../task_detail/category_visual.dart';
import '../task_detail/task_detail_sheet.dart';
import 'task_template_action_sheet.dart';

/// The Inbox's "Templates" tab — every saved [TaskTemplate] as a flat list.
///
/// Each row offers Use / Edit / Delete. "Use" spawns a real [Task] from the
/// template's fields and opens the EXISTING task detail screen pre-filled,
/// exactly the way the Inbox's own "give it a schedule" flow already works
/// — no second scheduling UI is built here. Nothing is persisted until the
/// user confirms in that screen (see [showTaskDetailSheet]'s
/// `duplicateFrom` contract, which this reuses for the same reason:
/// dismissing the sheet must leave no task behind).
class TemplateListView extends ConsumerWidget {
  const TemplateListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final templates = ref.watch(taskTemplateListProvider);
    final categories = ref.watch(categoryListProvider);

    if (templates.isEmpty) return _EmptyState(theme: theme);

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: theme.spacingScreenPadding),
      itemCount: templates.length,
      separatorBuilder: (context, _) => SizedBox(height: theme.spacingSm),
      itemBuilder: (context, index) {
        final template = templates[index];
        return TemplateRow(
          key: ValueKey(template.id),
          theme: theme,
          template: template,
          category: categories
              .where((c) => c.id == template.categoryId)
              .firstOrNull,
          onUse: () => useTemplate(context, template),
          onMore: () => showTaskTemplateActionSheet(context, template),
        );
      },
    );
  }
}

/// Spawns a task from [template] and opens the task detail screen
/// pre-filled with its fields, so the user can set a time and duration
/// before it lands on the Timeline.
///
/// The seed [Task] built here is deliberately NOT persisted — it exists
/// only to carry the template's values into the detail form, which creates
/// the real row on Save (recording `templateId` as its provenance). This
/// is the same non-persisting seed contract "Duplicate" already relies on,
/// so dismissing the sheet leaves nothing behind.
Future<void> useTemplate(BuildContext context, TaskTemplate template) {
  final seed = Task(
    id: template.id,
    title: template.title,
    notes: template.notes,
    durationMinutes: template.durationMinutes,
    categoryId: template.categoryId,
    behaviorId: template.behaviorId,
  );
  return showTaskDetailSheet(
    context,
    duplicateFrom: seed,
    templateId: template.id,
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacingLg),
        child: Text(
          'No templates yet. Tap + to save one — a task you add often, '
          'ready to drop onto any day.',
          textAlign: TextAlign.center,
          style: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
      ),
    );
  }
}

/// One template row — the category badge, the title and duration, and the
/// three actions. Public so a widget test can target it directly.
class TemplateRow extends StatelessWidget {
  const TemplateRow({
    super.key,
    required this.theme,
    required this.template,
    required this.category,
    required this.onUse,
    required this.onMore,
  });

  final AmbleTheme theme;
  final TaskTemplate template;

  /// Null only if the template references a category that no longer
  /// resolves — falls back to the neutral General colour rather than
  /// failing to render a row the user can still delete.
  final Category? category;

  final VoidCallback onUse;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final resolved = category;
    final badgeColor = resolved == null
        ? theme.categoryColors[TaskCategoryToken.general]!
        : resolveCategoryVisual(theme: theme, category: resolved).pillColor;
    final badgeSize = theme.spacingXl;

    return GestureDetector(
      onTap: onUse,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(theme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusXl),
        ),
        child: Row(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    style: theme.textBody.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (template.durationMinutes != null) ...[
                    SizedBox(height: theme.spacingXs),
                    Text(
                      '${template.durationMinutes} min',
                      style: theme.textBody.copyWith(
                        color: theme.colorTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Edit and Delete live behind this, in an AppSheet of
            // ActionRows — the exact pattern an ordinary task already
            // uses (`task_action_sheet.dart`), rather than a second,
            // row-local convention invented for this list. The row's own
            // tap stays the primary action (Use), same as tapping a task
            // opens its detail.
            GestureDetector(
              onTap: onMore,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(theme.spacingSm),
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: theme.colorTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
