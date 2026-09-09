import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_bottom_extension_bar.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../task_detail/add_category_modal.dart';
import '../task_detail/category_list_screen.dart';
import '../task_detail/task_detail_sheet.dart';
import '../timeline/task_category_token_mapping.dart';
import '../zones/zone_form_screen.dart';
import '../zones/zone_list_screen.dart';
import 'inbox_tab_switcher.dart';
import 'inbox_tasks_provider.dart';
import 'quick_capture_sheet.dart';
import 'task_template_form.dart';
import 'template_list_view.dart';

/// "Manage" — unscheduled tasks awaiting prioritization, plus the app's
/// other standing-definition lists (Templates, Zones, Categories), all
/// under one tab. Tapping a task opens the existing task detail screen
/// ([showTaskDetailSheet]) to give it a schedule, moving it onto the
/// Timeline; no separate scheduling UI is built for this. Wired to
/// [inboxTasksProvider], derived from [taskListProvider] (Phase 1).
///
/// Four sub-tabs — requested directly: "The first tab will be 'Inbox
/// Manage,' and it will have: Tasks, Templates, Zones (list + add + edit),
/// Categories (list + add + edit)." Zones and Categories reuse their
/// existing list/form screens verbatim ([ZoneListBody]/
/// [showZoneFormScreen], [CategoryListBody]/[showAddCategoryModal]) —
/// Settings → Zones/Categories keep their own separate entry points to the
/// same underlying screens, confirmed directly as a second path rather
/// than a replacement.
///
/// Templates — reusable blueprints (see CONSTITUTION.md's "TaskTemplate"
/// section) — stay deliberately NOT mixed into the Tasks list: a template
/// is never itself schedulable or completable, so folding it into a list
/// whose every row can be ticked off or opened for scheduling would blur
/// two genuinely different kinds of row.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  /// Which sub-tab is showing. Plain local state rather than a provider —
  /// no other screen needs to read or set it, and it is deliberately not
  /// persisted across launches (this tab opens on Tasks every time, its
  /// primary job).
  InboxManageTab _tab = InboxManageTab.tasks;

  @override
  Widget build(BuildContext context) {
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
        child: Column(
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
              // "Inbox" -> "Manage" — requested directly, alongside
              // adding the Zones/Categories sub-tabs: this screen's
              // job broadened beyond just task capture.
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
                  switch (_tab) {
                    InboxManageTab.tasks =>
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
                    InboxManageTab.templates => const TemplateListView(),
                    // Zones/Categories reuse their existing list bodies
                    // verbatim — same widgets Settings -> Zones/Categories
                    // push inside a Scaffold of their own, embedded here
                    // with none of that page chrome.
                    InboxManageTab.zones => const ZoneListBody(),
                    InboxManageTab.categories => const CategoryListBody(),
                  },
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AppTopScrollFade(color: theme.colorSurfaceTimeline),
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
            // The sub-tab switch and the "+" now live in the same bottom
            // "extension" bar the Timeline's DayStrip established —
            // requested directly, so the create button sits at the exact
            // same screen position on every tab instead of floating at a
            // different spot per screen. One "+" still acts on whichever
            // sub-tab is showing, rather than a second button per tab.
            AppBottomExtensionBar(
              leading: InboxTabSwitcher(
                theme: theme,
                selected: _tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
              onCreatePressed: () => switch (_tab) {
                InboxManageTab.tasks => showQuickCaptureSheet(context),
                InboxManageTab.templates => showTaskTemplateForm(context),
                InboxManageTab.zones => showZoneFormScreen(context),
                InboxManageTab.categories => showAddCategoryModal(context),
              },
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
    final badgeSize = theme.spacingXl;

    return AppPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusXl),
      child: Container(
        padding: EdgeInsets.all(theme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusXl),
          // No border. Matches AppPane's own reasoning: the card and page
          // background are too close in lightness for a flat edge to read
          // softly, so a shadow carries it instead of a border. Reported
          // directly as a hard edge on task/template cards.
          boxShadow: theme.shadowPane,
        ),
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
                style: theme.textBody.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
