import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/type_primitives.dart';
import '../../core/widgets/app_floating_create_button.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../core/widgets/app_swipe_actions.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../core/widgets/app_undo_toast.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_category.dart';
import '../../shared/providers/section_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/services/day_label.dart';
import '../task_detail/task_detail_sheet.dart';
import '../timeline/duration_label.dart';
import '../timeline/task_category_token_mapping.dart';
import 'inbox_section_filter_provider.dart';
import 'inbox_section_tabs.dart';
import 'inbox_tasks_provider.dart';
import 'quick_capture_sheet.dart';
import 'voice_capture_screen.dart';

/// One flattened row in the Inbox list — either a day-divider header or a
/// real task. [tasks] must already be sorted newest-first (see
/// [inboxTasksProvider]); this only groups adjacent same-day runs, it
/// never re-sorts.
sealed class _InboxRow {
  const _InboxRow();
}

class _InboxDayHeaderRow extends _InboxRow {
  const _InboxDayHeaderRow(this.label);
  final String label;
}

class _InboxTaskRow extends _InboxRow {
  const _InboxTaskRow(this.task);
  final Task task;
}

/// Inserts an [_InboxDayHeaderRow] before the first task of each new
/// calendar day — "all tab should have subtle label separating day
/// created... similar pattern to chat messaging separating messages
/// belonging to that day," requested directly. [today] is a parameter for
/// the same testability reason [dayLabel] itself takes one.
List<_InboxRow> _groupByDay(List<Task> tasks, {required DateTime today}) {
  final rows = <_InboxRow>[];
  DateTime? lastDay;
  for (final task in tasks) {
    final day = DateTime(
      task.createdAt.year,
      task.createdAt.month,
      task.createdAt.day,
    );
    if (lastDay == null || day != lastDay) {
      rows.add(_InboxDayHeaderRow(dayLabel(task.createdAt, today: today)));
      lastDay = day;
    }
    rows.add(_InboxTaskRow(task));
  }
  return rows;
}

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
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  /// The filter a live Inbox-row drag is currently hovering, or null —
  /// lifted up to this screen (rather than owned per-row) since it drives
  /// the tab row's own highlight, a sibling of whichever row is being
  /// dragged. See `_DraggableInboxRow`'s own doc comment for the drag
  /// gesture itself.
  InboxSectionFilter? _dropTargetFilter;

  /// Swipe-to-delete's own Remove action — snapshot-then-restore, same
  /// mechanism `removeTask`'s own undo uses, needed here specifically
  /// since a swipe has no confirmation step at all — the easiest task
  /// removal in the app to trigger by accident.
  Future<void> _removeTaskWithUndo(Task task, TaskList notifier) async {
    final snapshot = task.toJson();
    await notifier.deleteTask(task.id);
    if (!mounted) return;
    AppUndoToast.show(
      context: context,
      message: "Removed '${task.title}'",
      onUndo: () => notifier.updateTask(Task.fromJson(snapshot)),
    );
  }

  /// One [InboxSectionTabTargets] per distinct Section-list length —
  /// rebuilt only when the list of filters actually changes shape, not on
  /// every build, so a `GlobalKey` never churns mid-drag. `late` +
  /// manually invalidated in `didChangeDependencies`/`build` rather than
  /// a `Riverpod` provider: this is pure widget-tree bookkeeping (real
  /// `GlobalKey`s tied to THIS screen's own element tree), not app state.
  InboxSectionTabTargets? _targets;
  List<InboxSectionFilter>? _targetsFor;

  InboxSectionTabTargets _resolveTargets(List<InboxSectionFilter> filters) {
    final current = _targets;
    if (current != null && _listEquals(_targetsFor, filters)) return current;
    final built = InboxSectionTabTargets(filters);
    _targets = built;
    _targetsFor = filters;
    return built;
  }

  static bool _listEquals(
    List<InboxSectionFilter>? a,
    List<InboxSectionFilter> b,
  ) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final tasks = ref.watch(filteredInboxTasksProvider);
    final rows = _groupByDay(tasks, today: DateTime.now());
    final taskNotifier = ref.read(taskListProvider.notifier);
    final sections = ref.watch(sectionListProvider);

    final filters = <InboxSectionFilter>[
      const InboxSectionFilterAll(),
      for (final section in sections) InboxSectionFilterSection(section.id),
      const InboxSectionFilterUnfiled(),
    ];
    final targets = _resolveTargets(filters);

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
                // **2026-09-20 — page title removed.** Requested directly:
                // "Inbox and Tracked no need page title any more since
                // tab shows it" — the top nav's own "Inbox" tab label
                // already names this screen, so a second, redundant
                // "Inbox" heading directly below it was pure repetition.
                // Commented out rather than deleted, matching this
                // session's other "keep for restore" instructions.
                //
                // Padding(
                //   padding: EdgeInsets.fromLTRB(
                //     theme.spacingScreenPadding,
                //     theme.spacingLg,
                //     theme.spacingScreenPadding,
                //     theme.spacingMd,
                //   ),
                //   child: Text('Inbox', style: theme.textTitle),
                // ),
                // The Section tab row — pinned above the scrolling list
                // (a sibling in this Column, not inside the Expanded
                // Stack below), so it never scrolls away with the list
                // underneath it. Requested directly: "fixed so they
                // don't scroll vertically with content."
                InboxSectionTabs(
                  targets: targets,
                  dropTargetFilter: _dropTargetFilter,
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
                          : ListView.builder(
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
                                theme.spacingSm,
                              ),
                              // Day-divider headers replace the old
                              // ListView.separated's uniform SizedBox
                              // gap — requested directly: "all tab
                              // should have subtle label separating day
                              // created... similar pattern to chat
                              // messaging." Spacing between rows is now
                              // baked into each row's own bottom margin
                              // instead of a separate separatorBuilder,
                              // since headers and tasks need DIFFERENT
                              // amounts of it (see `_InboxDayHeader`'s
                              // and the task row's own padding below).
                              itemCount: rows.length,
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                if (row is _InboxDayHeaderRow) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      // No extra top gap before the
                                      // very first header — spacingContentTop
                                      // above already provides it; every
                                      // later header gets a bigger gap
                                      // than an ordinary inter-task one,
                                      // so a new day genuinely reads as
                                      // a new group.
                                      top: index == 0 ? 0 : theme.spacingLg,
                                      bottom: theme.spacingSm,
                                    ),
                                    child: _InboxDayHeader(
                                      theme: theme,
                                      label: row.label,
                                    ),
                                  );
                                }
                                final task = (row as _InboxTaskRow).task;
                                void onSchedule() =>
                                    showTaskDetailSheet(context, task: task);
                                // Swipe right schedules, swipe left removes
                                // — requested directly: "swipe right is
                                // schedule ... swipe left is remove."
                                //
                                // `deleteTask`, never `deleteTaskSeries`:
                                // an Inbox row is unscheduled by
                                // definition (see inboxTasksProvider's own
                                // `!task.isScheduled` filter) and a
                                // recurring instance always carries a
                                // scheduledAt, so no row reachable from
                                // this list belongs to a series at all —
                                // `deleteTaskSeries`'s own assert would
                                // fire if it were wired here.
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: theme.spacingSm,
                                  ),
                                  child: _DraggableInboxRow(
                                    key: ValueKey(task.id),
                                    theme: theme,
                                    targets: targets,
                                    onHoverChanged: (filter) => setState(
                                      () => _dropTargetFilter = filter,
                                    ),
                                    onDropped: (filter) {
                                      setState(() => _dropTargetFilter = null);
                                      final newSectionId = switch (filter) {
                                        InboxSectionFilterSection(:final id) =>
                                          id,
                                        InboxSectionFilterUnfiled() => null,
                                        InboxSectionFilterAll() =>
                                          task.sectionId,
                                      };
                                      if (newSectionId == task.sectionId) {
                                        return;
                                      }
                                      task.sectionId = newSectionId;
                                      taskNotifier.updateTask(task);
                                    },
                                    startAction: AppSwipeAction(
                                      icon: Icons.calendar_today_rounded,
                                      background: theme.colorAccent,
                                      semanticLabel: 'Schedule',
                                      onActivate: onSchedule,
                                    ),
                                    endAction: AppSwipeAction(
                                      icon: Icons.delete_outline_rounded,
                                      background: theme.colorTaskAlert,
                                      semanticLabel: 'Remove',
                                      destructive: true,
                                      onActivate: () =>
                                          _removeTaskWithUndo(
                                            task,
                                            taskNotifier,
                                          ),
                                    ),
                                    child: _InboxListItem(
                                      task: task,
                                      theme: theme,
                                      onTap: () => showQuickCaptureSheet(
                                        context,
                                        task: task,
                                      ),
                                      onToggleComplete: () =>
                                          taskNotifier.toggleComplete(task),
                                    ),
                                  ),
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
            // The voice-capture entry point — "sits next to the plus,"
            // requested directly. A sibling `Positioned` at the same
            // bottom-right corner, offset left by one button's own width
            // plus the standard gap, rather than a pixel constant, so it
            // stays correctly spaced if the create button's own size ever
            // changes.
            Positioned(
              right: theme.spacingMd + theme.sizeButtonMd + theme.spacingMd,
              bottom: theme.spacingMd,
              child: SafeArea(
                top: false,
                child: AppButton(
                  icon: Icons.mic_none_rounded,
                  shape: AppButtonShape.circle,
                  variant: AppButtonVariant.secondary,
                  tooltip: 'Speak your tasks',
                  onPressed: () => showVoiceCaptureScreen(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Long-press-then-drag an Inbox row onto one of the Section tabs at the
/// top of the screen to file it — requested directly, confirmed as the
/// ONLY assignment entry point (no picker modal, no long-press sheet, no
/// quick-capture field).
///
/// A long-press ARMS the row (a small lift) and disables its own
/// [AppSwipeActions] for the gesture's duration, passing `startAction:
/// null, endAction: null` — the same fix already established for Edit
/// Mode's own competing drag gestures (`TaskCapsuleBlock`'s own doc
/// comment: "the caller is expected to pass null while a competing drag
/// is active"; `AppSwipeActions`'s own doc comment confirms this is the
/// intended escape hatch, not a workaround). A plain quick swipe never
/// triggers this at all — it's gated behind `onLongPressStart`, so
/// swipe-right-schedule/swipe-left-delete are unaffected by a normal tap-
/// and-swipe gesture.
///
/// State (`_dragging`) lives here, in the row itself — the same shape
/// `_DraggableTaskBlockState` (`timeline/timeline_screen.dart`) already
/// establishes for the Timeline's own drag gesture: a caller-owned
/// `GestureDetector` with plain drag callbacks, not a shared "draggable
/// row" primitive (confirmed via research: no such primitive exists
/// anywhere in this codebase to reuse).
class _DraggableInboxRow extends StatefulWidget {
  const _DraggableInboxRow({
    super.key,
    required this.theme,
    required this.targets,
    required this.onHoverChanged,
    required this.onDropped,
    required this.startAction,
    required this.endAction,
    required this.child,
  });

  final AmbleTheme theme;
  final InboxSectionTabTargets targets;

  /// Reports the tab a live drag is currently over (or null once it
  /// leaves every tab) — the caller (`InboxScreen`) forwards this
  /// straight to `InboxSectionTabs.dropTargetFilter` for the highlight.
  final ValueChanged<InboxSectionFilter?> onHoverChanged;

  /// Fired once, on release, with whichever tab the drag ended over — the
  /// caller decides what that means for `Task.sectionId`. Never fired if
  /// the release wasn't over any tab (the row simply settles back, no
  /// assignment happens).
  final ValueChanged<InboxSectionFilter> onDropped;

  final AppSwipeAction startAction;
  final AppSwipeAction endAction;
  final Widget child;

  @override
  State<_DraggableInboxRow> createState() => _DraggableInboxRowState();
}

class _DraggableInboxRowState extends State<_DraggableInboxRow> {
  bool _dragging = false;

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() => _dragging = true);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    widget.onHoverChanged(widget.targets.hitTest(details.globalPosition));
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    final dropped = widget.targets.hitTest(details.globalPosition);
    setState(() => _dragging = false);
    widget.onHoverChanged(null);
    if (dropped != null) widget.onDropped(dropped);
  }

  void _onLongPressCancel() {
    setState(() => _dragging = false);
    widget.onHoverChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      // A small lift while armed — the same `motionFast`/`curveStandard`
      // quick-transition tokens used throughout this design system,
      // rather than a bespoke drag animation. Purely a visual "this is
      // now being dragged" signal; the row's own position never actually
      // follows the finger (unlike the Timeline's own drag, which
      // repositions the block in place) since a long list row dragging
      // upward across its own siblings would fight the list's scroll.
      child: AnimatedScale(
        scale: _dragging ? 1.03 : 1.0,
        duration: theme.motionFast,
        curve: theme.curveStandard,
        child: AnimatedOpacity(
          opacity: _dragging ? 0.85 : 1.0,
          duration: theme.motionFast,
          curve: theme.curveStandard,
          child: AppSwipeActions(
            // Null while armed — suspends the swipe recognizer for the
            // gesture's duration, per this class's own doc comment.
            startAction: _dragging ? null : widget.startAction,
            endAction: _dragging ? null : widget.endAction,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The chat-style date-divider between groups of same-day tasks — subtle
/// (tertiary text, caption size) and monospace, per the request: "all tab
/// should have subtle label separating day created's (Mono space font)."
/// [dayLabel]'s own doc comment covers the label text itself.
class _InboxDayHeader extends StatelessWidget {
  const _InboxDayHeader({required this.theme, required this.label});

  final AmbleTheme theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      // `textCaptionMono` — the monospace twin reserved for genuinely
      // temporal labels (see that token's own doc comment), not
      // `textCaption`'s default DM Sans.
      style: theme.textCaptionMono.copyWith(color: theme.colorTextTertiary),
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
    required this.task,
    required this.theme,
    required this.onTap,
    required this.onToggleComplete,
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
    // gap rather than by a card edge.
    //
    // **2026-09-15 — vertical padding tightened from `spacingMd` (16) to
    // `spacingSm` (8)**, requested directly: "reduce padding top bottom on
    // inbox item cards, they should be more compact." One rung down the
    // spacing scale rather than a bespoke value — the row still keeps a
    // real tap target height via its content (badge/text line height),
    // just without as much air around it.
    return AppPressFeedback(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacingSm),
        child: Row(
          children: [
            AppPressFeedback(
              onTap: onToggleComplete,
              // theme.radiusPill, not BoxShape.circle — requested
              // directly ("we have squary rounded shape of pills but
              // rounded on inbox ... this should affect globally"). Was
              // always fully round regardless of the Task/Zone view's own
              // pill shape; now tracks the same "Pill shape" setting they
              // do, via the SAME token — see radiusPill's own doc comment
              // on AmbleTheme.
              borderRadius: BorderRadius.circular(theme.radiusPill),
              // The badge is a saturated category fill, so the wash rides
              // on the light foreground its own icon uses.
              rippleColor: theme.colorSurfacePrimary,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(theme.radiusPill),
                ),
                // No glyph for General — matches the rule everywhere else
                // a category badge renders (see `TaskCategoryTokenMapping
                // .emoji`'s own doc comment: "both light dark mode default
                // should not have emoji"). This row used `.icon` instead
                // of `.emoji` and so kept showing a plain outlined circle
                // glyph on top of the badge for an uncategorised task —
                // reported directly ("there shouldn't be emoji on those
                // items, same as default task emoji without category").
                child: task.category == TaskCategory.general
                    ? null
                    : Icon(
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
          // fontFamily stays monospace — a duration value, not a title,
          // even though it borrows textTaskTitleSm for its size. Direct
          // override rather than a new token so this keeps tracking that
          // token's own size (see this class's own doc comment).
          style: theme.textTaskTitleSm.copyWith(
            color: theme.colorTextSecondary,
            fontFamily: TypePrimitives.fontFamily,
          ),
        ),
      ),
    );
  }
}
