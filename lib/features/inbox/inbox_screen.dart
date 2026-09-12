import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_floating_create_button.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../task_detail/task_detail_sheet.dart';
import '../timeline/duration_label.dart';
import '../timeline/task_category_token_mapping.dart';
import 'inbox_tasks_provider.dart';
import 'quick_capture_sheet.dart';

/// "Manage" — unscheduled tasks awaiting prioritization. Tapping a task
/// opens the existing task detail screen ([showTaskDetailSheet]) to give
/// it a schedule, moving it onto the Timeline; no separate scheduling UI
/// is built for this. Wired to [inboxTasksProvider], derived from
/// [taskListProvider] (Phase 1).
///
/// **2026-09-12 — the Templates/Zones/Categories sub-tabs were removed.**
/// Requested directly: "remove tabs tasks templates zones categories...
/// only keep tasks." Confirmed those three stay reachable — Settings
/// already has its own separate entry points (`showTemplateListScreen`/
/// `showZoneListScreen`/`showCategoryListScreen`), so nothing becomes a
/// dead end; this screen just stops being a second path to them.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final tasks = ref.watch(inboxTasksProvider);
    final taskNotifier = ref.read(taskListProvider.notifier);

    return Container(
      // Matches the Timeline's own background — requested directly:
      // "Inbox background should be the same as the timeline
      // background."
      color: theme.colorSurfaceTimeline,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top/bottom bumped from spacingMd/spacingSm to spacingLg/
                // spacingMd — requested directly, alongside the Tracked
                // screen's identical header (same values there, same
                // reasoning): "for inbox and tracked also might need to
                // increase the heading section."
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacingScreenPadding,
                    theme.spacingLg,
                    theme.spacingScreenPadding,
                    theme.spacingMd,
                  ),
                  child: Text('Manage', style: theme.textHeadline),
                ),
                Expanded(
                  // Stack, so top/bottom fades overlay the list's own
                  // scrolling content directly — reversed back from an
                  // earlier attempt that moved the top fade INTO the fixed
                  // heading above instead (a separate, non-scrolling sibling
                  // box, never actually behind any real content). Reported
                  // directly: "the header cuts the content with a hard edge
                  // ... the content slides through underneath" — a fade
                  // living in its own static header can only ever blend
                  // against that header's own flat background, never the
                  // list sliding past underneath it, which is exactly the
                  // hard-cut bug this reverses. The title above stays clear
                  // of the fade by construction now: the fade is confined to
                  // this Expanded's own bounds, which start below the fixed
                  // heading, so it can never paint over the title text again
                  // (the original problem the header-embedded fade was built
                  // to solve) — the same non-overlapping-by-position fix
                  // `_DayTimeline`'s own fade/heading split already uses on
                  // the Timeline. Mirrors the bottom fade already doing this
                  // correctly in this exact Stack.
                  child: Stack(
                    children: [
                      tasks.isEmpty
                          ? _EmptyInboxState(theme: theme)
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                theme.spacingScreenPadding,
                                // spacingContentTop — the shared value
                                // every list/sheet's own first row uses,
                                // confirmed directly at 30px: "tasks
                                // templates tracked cards should all
                                // start at same y level." Unrelated to
                                // the fade above now that the fade lives
                                // in the header, not over this list —
                                // this is purely the card-alignment fix.
                                theme.spacingContentTop,
                                theme.spacingScreenPadding,
                                0,
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
                                  onTap: () => showQuickCaptureSheet(
                                    context,
                                    task: task,
                                  ),
                                  onToggleComplete: () =>
                                      taskNotifier.toggleComplete(task),
                                  onSchedule: () =>
                                      showTaskDetailSheet(context, task: task),
                                );
                              },
                            ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AppTopScrollFade(
                          color: theme.colorSurfaceTimeline,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: AppTopScrollFade(
                          color: theme.colorSurfaceTimeline,
                          fromBottom: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Floating independently above the bottom nav pill now
            // (2026-09-12, matching every other screen's own
            // `AppFloatingCreateButton` — see that widget's doc comment),
            // rather than welded into a bar shared with the nav below.
            AppFloatingCreateButton(
              onPressed: () => showQuickCaptureSheet(context),
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
    required this.onSchedule,
  });

  final Task task;
  final AmbleTheme theme;

  /// Tapping the card body — opens the note for a rename (the quick
  /// capture sheet, in its edit-note mode). Requested directly: "clicking
  /// on it doesn't open the edit task. It opens a small sheet, the same
  /// as the creation sheet, but it's in edit mode" — the card's own tap
  /// stays the lightweight rename action, never the full Schedule form.
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;

  /// The trailing "+" — promotes this note to a scheduled task via the
  /// full task detail sheet, pre-filled with its title. Replaces the old
  /// chevron, requested directly: "to the Inbox item card instead chevron
  /// we replace chevron with + icon that then opens Create task with
  /// populated details already."
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final categoryColor = theme.categoryColors[task.category.token]!;
    // `theme.sizeTaskBadge`/`theme.textTaskTitle`, NOT `spacingXl`/
    // `textBody` (corrected 2026-09-12, reported directly: "manage items
    // should have same size as zone view") — this row bypassed the
    // shared "Task size" setting entirely, rendering visibly larger than
    // every other task row in the app (Task view, Zone view) regardless
    // of what size the user had actually chosen. These are the exact
    // same resolved tokens `TaskCapsuleBlock`'s own badge/title already
    // use, so Manage now tracks that one setting like every other view.
    final badgeSize = theme.sizeTaskBadge;

    // **2026-09-12 — the card is gone.** Requested directly: "remove cards
    // from Manage." No fill, no shadow, no rounded corners — a plain row,
    // separated from its neighbours by the list's own `separatorBuilder`
    // gap rather than by a card edge. `spacingMd` vertical padding is kept
    // (the card's own padding, minus its horizontal half — the list
    // already carries the horizontal screen inset) so the row still has a
    // real tap target height, not just its own text's tight line box.
    return AppPressFeedback(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacingMd),
        child: Row(
          children: [
            AppPressFeedback(
              onTap: onToggleComplete,
              shape: BoxShape.circle,
              // The badge is a saturated category fill, so the wash rides
              // on the light foreground its own icon uses.
              rippleColor: theme.colorSurfacePrimary,
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
                style: theme.textTaskTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // The duration badge — requested directly: "duration in tasks
            // move to the right but text size 10px (smallest scale) in a
            // 'badge' surface color next to current bg." Null-safe: an
            // Inbox task is unscheduled and may genuinely have no
            // duration set yet (Task.durationMinutes is nullable), so the
            // badge only renders once one exists.
            if (task.durationMinutes case final minutes?) ...[
              SizedBox(width: theme.spacingSm),
              _DurationBadge(theme: theme, minutes: minutes),
            ],
            // A separate tap target from the card's own onTap above — same
            // "own GestureDetector, own hit area" pattern the category
            // badge (toggle-complete) already uses on this row, so tapping
            // "+" promotes to Schedule without also triggering the card's
            // rename action underneath it.
            AppPressFeedback(
              onTap: onSchedule,
              shape: BoxShape.circle,
              child: Padding(
                padding: EdgeInsets.all(theme.spacingXs),
                child: Icon(Icons.add_rounded, color: theme.colorTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Manage-screen task row's duration pill — requested directly:
/// "duration in tasks move to the right but text size 10px (smallest
/// scale) in a 'badge' surface color next to current bg."
///
/// `textTaskTitleSm` (the smallest rung of the task-title scale,
/// confirmed via AskUserQuestion to mean the existing token rather than a
/// new literal 10px primitive) at [AmbleTheme.colorSurfaceSecondary] — one
/// step up from this screen's own `colorSurfaceTimeline` background (see
/// [InboxScreen]'s own `color:`), the same "next to current bg" surface
/// direction every other nested badge in this app already uses.
class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.theme, required this.minutes});

  final AmbleTheme theme;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorSurfaceSecondary,
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingXs,
          vertical: theme.spacingXs / 2,
        ),
        child: Text(
          formatDurationLabel(minutes),
          style: theme.textTaskTitleSm.copyWith(
            color: theme.colorTextSecondary,
          ),
        ),
      ),
    );
  }
}
