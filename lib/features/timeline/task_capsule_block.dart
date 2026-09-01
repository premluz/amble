import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/dev_config.dart' show TimelineTaskTextLayout;
import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_category.dart';
import '../../shared/models/task_status.dart';
import '../task_detail/category_visual.dart';
import 'completion_checkbox.dart';
import 'task_category_token_mapping.dart';

/// The capsule-shaped timeline task block — the product's signature visual
/// component. Three regions in a row: a narrow left rail (a tall rounded
/// pill in the category color, stretching for the task's full duration,
/// category icon near its top), the scheduled time and title, and a
/// trailing [CompletionCheckbox]. Consumes only Tier 2 ([AmbleTheme]) —
/// zero hardcoded values.
///
/// Status is reflected visually without shame-coding (design principle 1 —
/// no red "failure" styling for anything but what it literally is):
/// `completed` dims and strikes through the title, and fills the trailing
/// checkbox; `skipped` mutes the pill color; `rescheduled` shows a small
/// neutral "moved" indicator, not a color change.
///
/// Tapping anywhere on the pill or the time/title area opens [onTap] (the
/// detail sheet) — the pill itself is no longer a completion toggle, per
/// direct request, since the badge/name area being tap-through to "edit"
/// and completion living on the pill in the same gesture zone was
/// confusing. [onToggleComplete] now belongs solely to the trailing
/// checkbox, kept separate from [onTap] for the same reason as before: a
/// quick "done" tap shouldn't require opening the full sheet.
///
/// [pixelsPerMinute] controls the pill's height; callers size this against
/// whatever timeline scale is in effect. The pill's top edge represents the
/// task's start time — callers positioning this block should align to the
/// top, not the center, of the rendered height.
///
/// Requires a scheduled [task] (`task.isScheduled == true`) — this renders
/// the Timeline, not the Inbox, so `scheduledAt`/`durationMinutes` are
/// assumed present.
class TaskCapsuleBlock extends StatelessWidget {
  const TaskCapsuleBlock({
    super.key,
    required this.task,
    this.pixelsPerMinute = 1.5,
    this.onTap,
    this.onToggleComplete,
    this.dragPreviewStartsAt,
    this.maxTextWidth,
    this.durationMinutesOverride,
    this.entranceProgress = 1,
    this.isLifted = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.contentHidden = false,
    this.textLayout = TimelineTaskTextLayout.stacked,
    this.iconsVisible = true,
    this.durationVisible = true,
    this.category,
  });

  final Task task;

  /// The resolved [Category] row for [task.categoryId] — passed in by the
  /// caller (which has provider access this plain `StatelessWidget`
  /// doesn't) rather than looked up here. Null falls back to the
  /// deprecated `task.category` enum's own hand-tuned
  /// `categoryColors`/`categoryIconColors` tokens — the path every
  /// pre-migration task and every dev-scaffold caller (which doesn't wire
  /// up a live category list) still takes. See `_CategoryVisual.resolve`.
  final Category? category;
  final double pixelsPerMinute;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;

  /// Vertical drag-to-reschedule handlers — deliberately scoped to only the
  /// colored icon pill (not the whole row) so dragging the title/time text
  /// doesn't hijack the timeline's own vertical scroll gesture. Requested
  /// directly: the full-card drag made scrolling past a task difficult. Null
  /// means this block isn't draggable at all (e.g. the drag preview's static
  /// "ghost" copy).
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  /// While a drag is in progress, the start time the task would land on if
  /// released now. Non-null only mid-drag: the block's own time/duration
  /// line (normally the task's real scheduled time) switches to reflect
  /// THIS instead, live, as the block moves — replacing the earlier design
  /// of two floating chips above/below the pill, which could overlap a
  /// neighbouring task's own time text (reported directly, from an
  /// on-device screenshot).
  final DateTime? dragPreviewStartsAt;

  /// Whether this block is currently picked up by a drag. Applies the
  /// theme's `shadowLift` to the pill so the block reads as raised off the
  /// timeline. Defaults to false — a resting block casts no shadow.
  final bool isLifted;

  /// Renders the PILL at this duration instead of the task's own, without
  /// touching the time/duration text (which keeps showing the real,
  /// already-saved value). Used for exactly one thing: holding a pill at
  /// its pre-save height while the create/edit modal is still closing, so
  /// the grow/shrink into the new duration happens where the user can
  /// actually see it — see `_DraggableTaskBlock.growFromMinutes`.
  final int? durationMinutesOverride;

  /// 0 → 1 while a newly-created task is arriving on the Timeline; 1 (the
  /// default) for every block that isn't animating in.
  ///
  /// The block's parts don't all fade together — they come in one after
  /// another, pill first and checkbox last, per direct request ("pill >
  /// name > time > icons below > checkbox"). Each part's own opacity is
  /// derived from this single value by [_staggeredOpacity], so the whole
  /// sequence is driven by one animation rather than five.
  final double entranceProgress;

  /// Caps the time/title column's width so a task that shares its slot
  /// with an overlapping neighbour truncates rather than running its text
  /// under the next column's pill. Null means "take the remaining width",
  /// which is correct whenever the task overlaps nothing.
  final double? maxTextWidth;

  /// Renders ONLY the pill's real category-colored shape, at its real
  /// height and position — no icon, no title/time text, no checkbox. Used
  /// for a resting cluster member, whose title/time AND completion
  /// checkbox already appear in the cluster's own flat list (see
  /// docs/DECISIONS.md), so repeating any of it on the pill itself would
  /// be redundant. The pill stays draggable and tappable in this state.
  /// Defaults to false — an ordinary capsule shows its full content.
  final bool contentHidden;

  /// Dev-only layout experiment (see `core/dev_config.dart`,
  /// `DevTimelineTaskTextLayout`) — `stacked` (default, current shipped
  /// look) is title then time+duration on the line below; `inline` puts
  /// the time+duration first, followed by the title, on one line. Callers
  /// outside a `kDebugMode` context should never pass anything but the
  /// default.
  final TimelineTaskTextLayout textLayout;

  /// Dev-only toggle (`DevTimelineTaskIconsVisible`) for the bell/repeat/
  /// moved/tracked-behavior icon row. Defaults to true (current shipped
  /// behavior).
  final bool iconsVisible;

  /// Dev-only toggle (`DevTimelineTaskDurationVisible`) for the
  /// `(45m)`-style suffix on the time line. Defaults to true (current
  /// shipped behavior).
  final bool durationVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categoryVisual = _CapsuleCategoryVisual.resolve(
      theme: theme,
      // ignore: deprecated_member_use_from_same_package
      legacyCategory: task.category,
      category: category,
    );
    final categoryColor = categoryVisual.pillColor;
    final isSkipped = task.status == TaskStatus.skipped;
    final isCompleted = task.status == TaskStatus.completed;
    final isRescheduled = task.status == TaskStatus.rescheduled;
    final capsuleIcons = _capsuleIcons(
      isRescheduled: isRescheduled,
      isBehaviorInstance: task.isBehaviorInstance,
      isCompleted: isCompleted,
      isRecurring: task.isRecurring,
    );

    // Completed uses the same grey as the completed task's own title text
    // (colorTextSecondary), not the category color and not the old
    // colorTaskCompleted (sage green) token — requested directly, so a
    // completed task reads as "done, muted" consistently across both its
    // badge and its text. colorTaskCompleted is now unused — flagged
    // rather than silently deleted, since removing a Tier 2 token isn't
    // this change's call to make unprompted.
    final badgeColor = isSkipped
        ? theme.colorTaskSkipped
        : isCompleted
        ? theme.colorTextSecondary
        : categoryColor;

    // 40% smaller than the original 1.5x (spacingXl * 0.9) — requested
    // directly. Mirrored in timeline_screen.dart's _pillWidth; the two
    // must stay in sync (see that function's own doc comment).
    final badgeSize = theme.spacingXl * 0.9;
    final pillHeight = math.max(
      (durationMinutesOverride ?? task.durationMinutes!) * pixelsPerMinute,
      badgeSize,
    );

    // While dragging, the time/duration line reflects the DROP TARGET,
    // not the task's currently-saved schedule — replacing the earlier
    // pair of floating chips above/below the pill, which could overlap a
    // neighbouring task's own time text on a dense day (reported
    // directly, from an on-device screenshot). The card showing its own
    // live time line can't collide with anything else on the timeline the
    // way a chip escaping the pill's bounds could.
    final effectiveStart = dragPreviewStartsAt ?? task.scheduledAt!;
    final startTime = TimeOfDay.fromDateTime(effectiveStart);
    final endTime = TimeOfDay.fromDateTime(
      effectiveStart.add(Duration(minutes: task.durationMinutes!)),
    );
    final durationLabel = _formatDuration(task.durationMinutes!);

    // The cluster-member case: only the pill's real category-colored shape
    // (color, height, position) reads visually — no icon, no title/time
    // text, no checkbox. The task's title/time AND its completion checkbox
    // both already appear in the cluster's own flat list (each row there
    // gets its own trailing checkbox, right-aligned within that list — see
    // OverlapClusterBlock), so repeating either here would be redundant;
    // per the revised design (see docs/DECISIONS.md), a cluster member's
    // pill reads as a plain colored shape only. Still draggable and
    // tappable — while this task is the one actively being dragged, the
    // caller passes `contentHidden: false` instead (a dragged task always
    // renders fully normally, per the settled clustering design).
    //
    // Deliberately NOT an early-return branch with a different widget
    // shape: this is the exact bug class documented below for `isLifted`
    // (the frosted wrapper) — reported directly, again, as "double drag
    // needed." `contentHidden` flips true->false the instant a drag
    // starts (see the doc comment above), and an early return meant the
    // GestureDetector tracking that very drag was torn down and replaced
    // mid-gesture, so the first press only ever lifted the pill and never
    // tracked the finger. Hiding the icon/title/time/checkbox via Opacity
    // within the SAME always-present tree, like every other conditional
    // look on this widget, keeps the gesture's render object ancestry
    // stable across the whole drag.
    final card = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag-to-reschedule is scoped to just this pill — wrapping the
          // whole row (as before) made the title/time text draggable too,
          // which fought the timeline's vertical scroll gesture. See the
          // doc comment on onDragStart above.
          Opacity(
            // Step 0 of the entrance stagger — the pill leads.
            opacity: _staggeredOpacity(entranceProgress, 0),
            child: GestureDetector(
              onTap: onTap,
              onVerticalDragStart: onDragStart,
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragEnd: onDragEnd,
              behavior: HitTestBehavior.opaque,
              // Animated so a duration change GROWS or shrinks the pill
              // into its new height instead of snapping — requested
              // directly ("extends pill (change duration case) so user can
              // see it happening"). No state plumbing needed: the height
              // already derives from the task's own duration, so animating
              // this container covers every path that can change it (the
              // edit modal, a cascade reschedule, anything future).
              child: AnimatedContainer(
                // motionSlow, matching the entrance stagger's own pace:
                // both are "watch this happen" beats rather than responses
                // to a gesture, and at motionNormal the resize was over
                // almost as soon as it started (reported directly).
                duration: theme.motionSlow,
                curve: theme.curveStandard,
                width: badgeSize,
                height: pillHeight,
                alignment: Alignment.topCenter,
                // 4px above spacingIconTop's original 12px — requested
                // directly. Lands exactly on spacingSm (8px), an
                // existing token, so no new one was needed.
                padding: EdgeInsets.only(top: theme.spacingSm),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(theme.radiusTaskPill),
                  // No shadow here any more while lifted — the shadow now
                  // belongs to the outer frosted card (see the wrapping
                  // below), matching how every other pane in the app
                  // carries its OWN elevation rather than one of its
                  // children carrying it. Requested directly: "the
                  // draggable coloured icon pane would not have shadow
                  // instead the pane has shadow."
                ),
                // Deliberately NOT faded while lifted — corrected
                // directly after a first pass hid it: this glyph is the
                // pill's identity and stays visible the whole time,
                // including mid-drag. Only the indicator icons under
                // the title fade (see the row further down). It DOES fade
                // for `contentHidden` (a resting cluster member), whose
                // pill is meant to read as a plain colored shape.
                //
                // Emoji, not `Icon(task.category.icon)` — matches the
                // emoji already shown on the category picker's chips
                // during create/edit (see `.emoji`'s own doc comment).
                // Requested directly, reversing an earlier decision that
                // deliberately kept the pill on the monochrome `.icon`
                // glyph specifically because it could be tinted
                // (`iconColor`) for contrast against the pale category
                // fill — an emoji carries its own fixed color, so no
                // tinting is applied or needed here any more.
                child: Opacity(
                  opacity: contentHidden ? 0 : 1,
                  child: Text(
                    categoryVisual.emoji,
                    style: TextStyle(fontSize: badgeSize * 0.55),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: theme.spacingSm),
          // Expanded, not Flexible: Flexible let this column shrink to its
          // own content width, so the trailing checkbox sat wherever that
          // row's title happened to end — every row at a different x, and
          // shifting on tap when completing changed the text's measured
          // width (strikethrough). Expanded makes the column always claim
          // the remaining width, which pins the checkbox to a fixed
          // right-hand column. Reported directly.
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              // ClipRect + a height cap for `contentHidden`: the title/time
              // text is faded to opacity 0 below (not removed from the
              // tree — see the doc comment on the branch above for why),
              // but its own intrinsic height doesn't shrink just because
              // it's invisible. A short cluster pill (badge-height floor)
              // is often shorter than two lines of body text, and
              // IntrinsicHeight sizes the whole Row to its tallest child —
              // without capping this column, a short pill's row grew to
              // fit the hidden text and produced a real RenderFlex
              // overflow (reported directly, "OVERFLOWED BY 56px").
              child: ClipRect(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxTextWidth ?? double.infinity,
                    maxHeight: contentHidden ? pillHeight : double.infinity,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: theme.spacingXs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dev-only layout experiment (textLayout — see
                        // core/dev_config.dart): `stacked` keeps the name
                        // and time+duration on their own lines (steps 1/2
                        // of the entrance stagger, unchanged); `inline`
                        // puts the time+duration first, then the name,
                        // both in one Text.rich so they share a line.
                        if (textLayout == TimelineTaskTextLayout.stacked) ...[
                          // Step 1 of the entrance stagger — the name.
                          Opacity(
                            opacity: contentHidden
                                ? 0
                                : _staggeredOpacity(entranceProgress, 1),
                            child: Text(
                              task.title,
                              style: theme.textBody.copyWith(
                                color: isCompleted
                                    ? theme.colorTextSecondary
                                    : theme.colorTextPrimary,
                                fontWeight: FontWeight.w700,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationColor: theme.colorTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Corrected directly: this line is now the same
                          // size as the task name (textBody, not the
                          // smaller textCaption) but stays regular weight,
                          // and gains a real gap below the title. The
                          // earlier -3px Transform nudge that pulled it
                          // CLOSER to the title is gone — it was solving
                          // the opposite problem.
                          SizedBox(height: theme.spacingXs),
                          // Step 2 of the entrance stagger — the time line.
                          Opacity(
                            opacity: contentHidden
                                ? 0
                                : _staggeredOpacity(entranceProgress, 2),
                            child: Text(
                              durationVisible
                                  ? '${startTime.format(context)} - '
                                        '${endTime.format(context)} '
                                        '($durationLabel)'
                                  : '${startTime.format(context)} - '
                                        '${endTime.format(context)}',
                              style: theme.textBody.copyWith(
                                color: theme.colorTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          // `inline`: time+duration then the name, one
                          // line — requested directly ("hours first
                          // followed by task name in one line instead of
                          // stacked"). Reuses steps 1/2's opacities so the
                          // entrance stagger still reads the same, just on
                          // one Text.rich instead of two Text widgets.
                          Opacity(
                            opacity: contentHidden
                                ? 0
                                : math.min(
                                    _staggeredOpacity(entranceProgress, 1),
                                    _staggeredOpacity(entranceProgress, 2),
                                  ),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: durationVisible
                                        ? '${startTime.format(context)} - '
                                              '${endTime.format(context)} '
                                              '($durationLabel)  '
                                        : '${startTime.format(context)} - '
                                              '${endTime.format(context)}  ',
                                    style: theme.textBody.copyWith(
                                      color: theme.colorTextSecondary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: task.title,
                                    style: theme.textBody.copyWith(
                                      color: isCompleted
                                          ? theme.colorTextSecondary
                                          : theme.colorTextPrimary,
                                      fontWeight: FontWeight.w700,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      decorationColor: theme.colorTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        // Status/indicator icons: all four share one row
                        // below the time/duration line, all at the same 2x
                        // size — requested directly (moved/tracked-behavior
                        // used to sit on the time line itself at half this
                        // size; notification/repeat were already here).
                        // Neutral facts about the task, not statuses worth
                        // colouring (design principle 1).
                        //
                        // Dev-only toggle (iconsVisible — see
                        // core/dev_config.dart): hides this whole row.
                        if (iconsVisible && capsuleIcons.isNotEmpty) ...[
                          SizedBox(height: theme.spacingXs),
                          // These fade out while the block is lifted and
                          // back in on drop — requested directly: they're
                          // secondary detail that isn't useful mid-drag,
                          // unlike the category glyph in the pill, which
                          // stays visible throughout.
                          AnimatedOpacity(
                            // Step 3 of the entrance stagger, multiplied
                            // into the lift fade rather than replacing it —
                            // both can be in play at once (a block dragged
                            // immediately after being created), and taking
                            // the product keeps whichever is more hiding.
                            // Also hidden for `contentHidden` — redundant
                            // with the cluster list's own indicator icons.
                            opacity: contentHidden
                                ? 0.0
                                : (isLifted ? 0.0 : 1.0) *
                                      _staggeredOpacity(entranceProgress, 3),
                            duration: theme.motionFast,
                            curve: Curves.easeOut,
                            child: Row(
                              children: [
                                for (final (index, icon)
                                    in capsuleIcons.indexed) ...[
                                  if (index > 0)
                                    SizedBox(width: theme.spacingXs),
                                  Icon(
                                    icon,
                                    size: theme.spacingSm * 2,
                                    color: theme.colorTextSecondary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The interactive completion control — deliberately not part of
          // either tap-to-edit zone above, so a quick "done" tap doesn't
          // require opening the full sheet. Its own internal gesture
          // detector claims taps within its bounds before they reach either
          // sibling detector.
          // Fades out while lifted, same reasoning as the category glyph
          // above — requested directly. IgnorePointer while faded so a
          // stray tap can't hit an invisible control mid-reposition. Also
          // fades out (and stops accepting taps) for `contentHidden` — a
          // resting cluster member's completion control lives on its list
          // row instead (see OverlapClusterBlock).
          AnimatedOpacity(
            // Step 4 — the last of the entrance stagger. Multiplied into
            // the lift fade for the same reason as the icon row above.
            opacity: contentHidden
                ? 0.0
                : (isLifted ? 0.0 : 1.0) *
                      _staggeredOpacity(entranceProgress, 4),
            duration: theme.motionFast,
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: isLifted || contentHidden,
              child: CompletionCheckbox(
                theme: theme,
                // The category's own saturated color while unchecked (or
                // for any other status) — this ring needs to stay
                // recognizably "this task's category" at all times,
                // matching the reference design, unlike the badge above
                // (now an emoji, which carries its own fixed color and
                // needs no per-status tint).
                ringColor: categoryVisual.iconColor,
                isCompleted: isCompleted,
                // Requested directly, alongside the completed badge
                // turning the same grey: the checked ring on the Timeline
                // should read "done, muted" rather than staying
                // category-colored once completed. Only the checked FILL
                // changes (see useMutedCompletedColor's own doc comment) —
                // the ring is still the category color for every
                // non-completed status.
                useMutedCompletedColor: true,
                onToggle: onToggleComplete,
              ),
            ),
          ),
        ],
      ),
    );

    // The frosted wrapper is ALWAYS present, not conditionally built —
    // regression fixed directly: swapping between `card` bare and `card`
    // wrapped in Container/ClipRRect/BackdropFilter (only while lifted)
    // inserted new ancestor render objects mid-gesture the moment
    // `onDragStart`'s setState flipped `isLifted` to true. That broke the
    // active drag recognizer's hit-test routing — the first touch only
    // ever lifted the pill (the rebuild happened) but never tracked the
    // finger, and dragging only started working AFTER a release-and-
    // re-press, because the second press began cleanly against the now-
    // already-wrapped tree. Keeping the exact same widget shape at every
    // isLifted value, and animating the frosted LOOK instead (blur sigma,
    // fill opacity, shadow — all via AnimatedContainer/TweenAnimationBuilder
    // rather than presence/absence of the wrapper), keeps the gesture's
    // render object ancestry stable across the whole drag.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: isLifted ? 1 : 0),
      duration: theme.motionFast,
      curve: theme.curveStandard,
      builder: (context, t, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.radiusXl),
            boxShadow: t == 0
                ? const []
                : theme.shadowPane.map((shadow) => shadow.scale(t)).toList(),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.radiusXl),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: theme.blurOverlaySigma * t,
                sigmaY: theme.blurOverlaySigma * t,
              ),
              child: Container(
                padding: EdgeInsets.all(theme.spacingSm * t),
                color: theme.colorSurfaceBlurOverlay.withValues(
                  alpha: theme.colorSurfaceBlurOverlay.a * t,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: card,
    );
  }
}

/// Whole hours render as "1h"/"2h"; anything with leftover minutes (or under
/// an hour) renders as total minutes, e.g. "30m"/"90m" — matches the format
/// requested directly rather than always showing "H:MM".
/// How many parts the entrance stagger runs across — pill, name, time,
/// icon row, checkbox, in that order.
const _staggerSteps = 5;

/// How much of the whole entrance each part's own fade occupies. Greater
/// than `1 / _staggerSteps`, so consecutive parts OVERLAP rather than
/// fading strictly one-after-another — a fully sequential version reads as
/// five separate events instead of one block arriving.
const _staggerFadeFraction = 0.5;

/// One part's opacity at overall [progress], for the part at [index] in
/// the stagger order. Each part stays at 0 until its own slot begins, then
/// fades over [_staggerFadeFraction] of the total.
double _staggeredOpacity(double progress, int index) {
  // The last part must still reach full opacity at progress == 1, so the
  // starts are spread across whatever room the fade width leaves.
  final start = (index / (_staggerSteps - 1)) * (1 - _staggerFadeFraction);
  final local = (progress - start) / _staggerFadeFraction;
  return local.clamp(0.0, 1.0);
}

String _formatDuration(int minutes) {
  if (minutes % 60 == 0) return '${minutes ~/ 60}h';
  return '${minutes}m';
}

/// Which status/indicator icons apply to this task, in the order they've
/// always rendered in ("moved", tracked-behavior, notification, repeat) —
/// unchanged by the icons' move onto a shared row, since reordering them
/// wasn't asked for. Only present-icon gaps get a spacer at the call site,
/// so this list (not four independent `if`s) is the single source of
/// truth for "which icons show" both there and for the empty-row check.
List<IconData> _capsuleIcons({
  required bool isRescheduled,
  required bool isBehaviorInstance,
  required bool isCompleted,
  required bool isRecurring,
}) => [
  if (isRescheduled) Icons.update_rounded,
  if (isBehaviorInstance) Icons.track_changes_rounded,
  // Notifications sync automatically for every scheduled, non-completed
  // task (Phase 7) — no per-task mute toggle exists, so this is shown
  // unconditionally for that same set rather than gated on a field that
  // doesn't exist yet.
  if (!isCompleted) Icons.notifications_active_rounded,
  if (isRecurring) Icons.repeat_rounded,
];

/// The resolved pill fill / icon glyph / emoji for one capsule block —
/// wraps the shared [resolveCategoryVisual] (`task_detail/category_visual.dart`)
/// with a fallback for [category] being null (a pre-migration task not yet
/// backfilled, or a dev-scaffold caller with no live category list wired
/// up): the deprecated [Task.category] enum's own token mapping —
/// byte-for-byte the pre-Category rendering.
class _CapsuleCategoryVisual {
  const _CapsuleCategoryVisual({
    required this.pillColor,
    required this.iconColor,
    required this.emoji,
  });

  final Color pillColor;
  final Color iconColor;
  final String emoji;

  factory _CapsuleCategoryVisual.resolve({
    required AmbleTheme theme,
    required TaskCategory legacyCategory,
    required Category? category,
  }) {
    if (category == null) {
      return _CapsuleCategoryVisual(
        pillColor: theme.categoryColors[legacyCategory.token]!,
        iconColor: theme.categoryIconColors[legacyCategory.token]!,
        emoji: legacyCategory.emoji,
      );
    }

    final visual = resolveCategoryVisual(theme: theme, category: category);
    return _CapsuleCategoryVisual(
      pillColor: visual.pillColor,
      iconColor: visual.iconColor,
      emoji: category.emoji,
    );
  }
}
