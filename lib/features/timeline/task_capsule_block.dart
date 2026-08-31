import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
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
    this.isLifted = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final Task task;
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

  /// Caps the time/title column's width so a task that shares its slot
  /// with an overlapping neighbour truncates rather than running its text
  /// under the next column's pill. Null means "take the remaining width",
  /// which is correct whenever the task overlaps nothing.
  final double? maxTextWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categoryColor = theme.categoryColors[task.category.token]!;
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

    // The Phase 13a-pastel-v2 category pill is a pale tint (L≈0.95-0.99),
    // far too light for any single glyph color — light or dark — to clear
    // real contrast against. `categoryIconColors` is a separate, deliberately
    // saturated, same-hue color designed specifically to read against its
    // own category's pale fill (see docs/DECISIONS.md for the per-category
    // contrast numbers). Only the plain-category case uses it:
    // `colorTaskSkipped`/completed badges are unrelated colors (not a
    // category tint) and stay dark enough for the original white glyph, in
    // both palettes.
    final iconColor = (!isSkipped && !isCompleted)
        ? theme.categoryIconColors[task.category.token]!
        : theme.colorSurfacePrimary;

    // 40% smaller than the original 1.5x (spacingXl * 0.9) — requested
    // directly. Mirrored in timeline_screen.dart's _pillWidth; the two
    // must stay in sync (see that function's own doc comment).
    final badgeSize = theme.spacingXl * 0.9;
    final pillHeight = math.max(
      task.durationMinutes! * pixelsPerMinute,
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

    final card = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag-to-reschedule is scoped to just this pill — wrapping the
          // whole row (as before) made the title/time text draggable too,
          // which fought the timeline's vertical scroll gesture. See the
          // doc comment on onDragStart above.
          GestureDetector(
            onTap: onTap,
            onVerticalDragStart: onDragStart,
            onVerticalDragUpdate: onDragUpdate,
            onVerticalDragEnd: onDragEnd,
            behavior: HitTestBehavior.opaque,
            child: Container(
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
              // the title fade (see the row further down).
              child: Icon(
                task.category.icon,
                size: badgeSize * 0.55,
                color: iconColor,
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxTextWidth ?? double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: theme.spacingXs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
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
                      // Corrected directly: this line is now the same size
                      // as the task name (textBody, not the smaller
                      // textCaption) but stays regular weight, and gains a
                      // real gap below the title. The earlier -3px
                      // Transform nudge that pulled it CLOSER to the title
                      // is gone — it was solving the opposite problem.
                      SizedBox(height: theme.spacingXs),
                      Text(
                        '${startTime.format(context)} - '
                        '${endTime.format(context)} '
                        '($durationLabel)',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Status/indicator icons: all four share one row
                      // below the time/duration line, all at the same 2x
                      // size — requested directly (moved/tracked-behavior
                      // used to sit on the time line itself at half this
                      // size; notification/repeat were already here).
                      // Neutral facts about the task, not statuses worth
                      // colouring (design principle 1).
                      if (capsuleIcons.isNotEmpty) ...[
                        SizedBox(height: theme.spacingXs),
                        // These fade out while the block is lifted and
                        // back in on drop — requested directly: they're
                        // secondary detail that isn't useful mid-drag,
                        // unlike the category glyph in the pill, which
                        // stays visible throughout.
                        AnimatedOpacity(
                          opacity: isLifted ? 0 : 1,
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
          // The interactive completion control — deliberately not part of
          // either tap-to-edit zone above, so a quick "done" tap doesn't
          // require opening the full sheet. Its own internal gesture
          // detector claims taps within its bounds before they reach either
          // sibling detector.
          // Fades out while lifted, same reasoning as the category glyph
          // above — requested directly. IgnorePointer while faded so a
          // stray tap can't hit an invisible control mid-reposition.
          AnimatedOpacity(
            opacity: isLifted ? 0 : 1,
            duration: theme.motionFast,
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: isLifted,
              child: CompletionCheckbox(
                theme: theme,
                // The category's own saturated color while unchecked (or
                // for any other status) — unlike `iconColor` above (which
                // is tuned for contrast against the badge fill and goes
                // white/near-black for the skipped/completed cases), this
                // ring needs to stay recognizably "this task's category"
                // at all times, matching the reference design.
                ringColor: theme.categoryIconColors[task.category.token]!,
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
                : theme.shadowPane
                      .map(
                        (shadow) => shadow.scale(t),
                      )
                      .toList(),
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

