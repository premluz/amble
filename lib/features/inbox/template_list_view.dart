import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../core/widgets/app_swipe_actions.dart';
import '../../core/widgets/app_undo_toast.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task_template.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/task_template_providers.dart';
import '../task_detail/category_visual.dart';
import 'task_template_form.dart';

/// The Settings "Templates" list — every saved [TaskTemplate] as a flat
/// list.
///
/// **2026-09-27 — tap opens Edit; no three-dot menu; swipe left to
/// remove.** Requested directly, unifying this list with Zones/Tags'
/// own "tap opens the thing you'd manage, swipe to remove" shape (and
/// with the Inbox's own task/note rows, which already use
/// [AppSwipeActions] for exactly this): "templates should not have a
/// three dots and sheet opening each... [they] can be slided left to be
/// removed... templates tap goes to edit template not to create task
/// from that template." Superseded — a tap here used to spawn a task
/// from the template (`useTemplate`, via `showTaskDetailSheet`'s
/// `duplicateFrom`) and a separate three-dot menu
/// (`task_template_action_sheet.dart`) held Edit/Delete behind it;
/// "use a template to seed a new task" still exists, just relocated
/// entirely to `TemplateChipStrip`/`TemplateChip`
/// (`template_chip_strip.dart`), the quick-create sheet's own separate
/// template browser — this list's own job is now purely managing the
/// templates themselves, matching Zones/Tags.
class TemplateListView extends ConsumerWidget {
  const TemplateListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final templates = ref.watch(taskTemplateListProvider);
    final categories = ref.watch(categoryListProvider);

    if (templates.isEmpty) return _EmptyState(theme: theme);

    return ListView.separated(
      // spacingContentTop — real bug, reported directly: "tasks
      // templates tracked cards should all start at same y level,
      // currently templates are higher." This list had NO top padding
      // at all, so its first row sat flush under the heading. Templates'
      // OWN un-padded position (0) plus 30px became the confirmed shared
      // standard every other list/sheet now also uses: "as in templates
      // current position +30 becomes NEW for all."
      padding: EdgeInsets.fromLTRB(
        theme.spacingScreenPadding,
        theme.spacingContentTop,
        theme.spacingScreenPadding,
        0,
      ),
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
          onTap: () => showTaskTemplateForm(context, template: template),
          onRemove: () => _removeTemplate(context, ref, template),
        );
      },
    );
  }

  /// Deletes immediately, no confirmation dialog — matching Zones/Tags'
  /// own swipe-to-remove and the identical "no confirmation" contract
  /// the old three-dot menu's own Delete already had
  /// (`task_template_action_sheet.dart`'s `_delete`).
  void _removeTemplate(
    BuildContext context,
    WidgetRef ref,
    TaskTemplate template,
  ) {
    ref.read(taskTemplateListProvider.notifier).deleteTemplate(template.id);
    AppUndoToast.show(context: context, message: 'Removed template');
  }
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

/// One template row — the category badge, the title and duration. Public
/// so a widget test can target it directly. Tapping opens the template's
/// own edit form; swiping left reveals Remove, matching the shared
/// [AppSwipeActions] pattern the Inbox's own task/note rows already use.
class TemplateRow extends StatelessWidget {
  const TemplateRow({
    super.key,
    required this.theme,
    required this.template,
    required this.category,
    required this.onTap,
    required this.onRemove,
  });

  final AmbleTheme theme;
  final TaskTemplate template;

  /// Null only if the template references a category that no longer
  /// resolves — falls back to the neutral General colour rather than
  /// failing to render a row the user can still delete.
  final Category? category;

  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final badgeSize = theme.spacingXl;

    return AppSwipeActions(
      endAction: AppSwipeAction(
        icon: Icons.delete_outline_rounded,
        background: theme.colorDestructive,
        semanticLabel: 'Remove template',
        destructive: true,
        onActivate: onRemove,
      ),
      child: AppPressFeedback(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radiusXl),
        child: Container(
          padding: EdgeInsets.all(theme.spacingMd),
          decoration: BoxDecoration(
            color: theme.colorSurfaceSecondary,
            borderRadius: BorderRadius.circular(theme.radiusXl),
            // No border. Matches AppPane's own reasoning: the card and
            // page background are too close in lightness for a flat edge
            // to read softly, so a shadow carries it instead of a
            // border. Reported directly as a hard edge on task/template
            // cards.
            boxShadow: theme.shadowPane,
          ),
          child: Row(
            children: [
              CategoryBadge(theme: theme, category: category, size: badgeSize),
              SizedBox(width: theme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      style: theme.textBody.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}
