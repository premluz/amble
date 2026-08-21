import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../task_detail/task_detail_sheet.dart';
import '../timeline/task_category_token_mapping.dart';
import 'inbox_tasks_provider.dart';
import 'quick_capture_sheet.dart';

/// The Inbox — unscheduled, captured tasks awaiting prioritization. Tapping
/// an item opens the existing task detail screen ([showTaskDetailSheet]) to
/// give it a schedule, moving it onto the Timeline; no separate scheduling
/// UI is built for this. Wired to [inboxTasksProvider], derived from
/// [taskListProvider] (Phase 1).
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final tasks = ref.watch(inboxTasksProvider);
    final taskNotifier = ref.read(taskListProvider.notifier);

    return Container(
      color: theme.colorSurfacePrimary,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacingScreenPadding,
                    theme.spacingMd,
                    theme.spacingScreenPadding,
                    theme.spacingSm,
                  ),
                  child: Text('Inbox', style: theme.textHeadline),
                ),
                Expanded(
                  child: tasks.isEmpty
                      ? _EmptyInboxState(theme: theme)
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(
                            horizontal: theme.spacingScreenPadding,
                          ),
                          itemCount: tasks.length,
                          separatorBuilder: (context, _) =>
                              SizedBox(height: theme.spacingSm),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return _InboxListItem(
                              key: ValueKey(task.id),
                              task: task,
                              theme: theme,
                              onTap: () =>
                                  showTaskDetailSheet(context, task: task),
                              onToggleComplete: () =>
                                  taskNotifier.toggleComplete(task),
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              right: theme.spacingLg,
              bottom: theme.spacingLg,
              child: AppIconButton(
                icon: Icons.add_rounded,
                onPressed: () => showQuickCaptureSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyInboxState extends StatelessWidget {
  const _EmptyInboxState({required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacingLg),
        child: Text(
          'Nothing captured yet. Tap + to add something.',
          textAlign: TextAlign.center,
          style: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
      ),
    );
  }
}

class _InboxListItem extends StatelessWidget {
  const _InboxListItem({
    super.key,
    required this.task,
    required this.theme,
    required this.onTap,
    required this.onToggleComplete,
  });

  final Task task;
  final AmbleTheme theme;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final categoryColor = theme.categoryColors[task.category.token]!;
    final badgeSize = theme.spacingXl;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(theme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusCard),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggleComplete,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  task.category.icon,
                  size: badgeSize * 0.55,
                  color: theme.colorSurfacePrimary,
                ),
              ),
            ),
            SizedBox(width: theme.spacingSm),
            Expanded(
              child: Text(
                task.title,
                style: theme.textBody.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorTextSecondary),
          ],
        ),
      ),
    );
  }
}
