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
import 'duration_label.dart';
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
    this.durationIndicatedBySize = true,
    this.category,
    this.compactText = false,
    this.showCompletionCheckbox = true,
    this.splitLayout = false,
    this.glyphHidden = false,
    this.liftedTextInline = false,
    this.bottomTrim = 0,
    this.maxPillHeight,
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

  /// True in List (collapsed) mode. Previously also switched the title/
  /// time text down to a separate, smaller `textTaskTitleCompact` style —
  /// confirmed directly that List view should track the same global "Task
  /// size" setting Task/Zone view do instead, with no relative step, so
  /// this flag no longer affects font size at all; it still forces the
  /// INLINE (time+title, one line) layout `textLayout`'s own `stacked`
  /// option would otherwise pick, per "still need to make time and name
  /// sit in one line atm it sits in 2 lines." Defaults to false so a
  /// caller that doesn't wire this up (a dev scaffold, a test) keeps the
  /// dev-config layout toggle's own choice.
  final bool compactText;

  /// Whether the trailing [CompletionCheckbox] renders at all
  /// (`ShowCompletionCheckboxSetting`). Requested directly as one setting
  /// spanning all three views. Defaults to true (current shipped
  /// behavior). See the provider's own doc comment: hiding this currently
  /// removes the only way to complete a scheduled task.
  final bool showCompletionCheckbox;

  /// Renders ONLY the pill — the caller positions the time/title/checkbox
  /// itself, as a separate Stack sibling ([TaskCapsuleTextRow]).
  ///
  /// The Spatial Task View's own mode, so every task's NAME starts at the
  /// same x regardless of which overlap lane its pill sits in (requested
  /// directly: "all task names are lined up even those not stacked").
  /// Text laid out as this widget's own `Row` sibling can only ever flow
  /// from its OWN pill, so a lane-2 task's title sat further right than a
  /// lane-0 task's — the two have to be positioned independently to share
  /// one column.
  ///
  /// Deliberately a fade of the text region rather than a different widget
  /// tree: this widget's pill owns the drag `GestureDetector`, and
  /// changing the tree shape around it mid-gesture has broken drag
  /// hit-testing twice before (see the `contentHidden`/`isLifted` comments
  /// below and on the frosted wrapper). Everything stays present and
  /// identically nested; only opacity and hit-testing change.
  ///
  /// Zone view, the drag-preview card, and the dev previews leave this
  /// false — they keep the combined pill+text row.
  final bool splitLayout;

  /// Also hides the pill's category emoji, which [contentHidden] alone
  /// deliberately keeps visible (see the glyph's own comment below: a
  /// resting cluster member's pill is the ONLY place its category reads).
  ///
  /// Set only by the drag GHOST — requested directly, "in ghost state we
  /// shouldn't have title and time and not icon when moving": the ghost is
  /// a plain shape marking where the task came from, and its category
  /// already reads off the lifted pill travelling under the finger.
  final bool glyphHidden;

  /// Renders the time/title INSIDE this widget even in [splitLayout],
  /// where the caller normally positions that text itself.
  ///
  /// Set only while a split-layout pill is LIFTED — requested directly:
  /// "lifted state should have its inner title and time underneath name
  /// showing ... and pane containing (bg blur one) should be extended to
  /// that name." The shared text column stays anchored at its own x, so a
  /// pill dragged away from it would otherwise carry no label at all; this
  /// puts the task's own name and time back inside the frosted pane that
  /// travels with the finger.
  final bool liftedTextInline;

  /// Shrinks the pill's rendered height by this many pixels, floored at 0
  /// (a very short task can't be trimmed below nothing) — the bottom-edge
  /// counterpart to the top gap `_zoneTaskTopInset` already creates in
  /// `timeline_screen.dart`.
  ///
  /// Requested directly, from a screenshot showing a task's pill flush
  /// against its own zone's bottom edge with no visible margin: "the task
  /// that's matching the timing duration of a zone needs to have a bottom
  /// padding from the zone, same as the top padding (same principle)."
  /// Applies only when the caller determines this task's own END lands
  /// exactly on a zone's end — see `_zoneTaskBottomTrim` in
  /// `timeline_screen.dart`, which is the one place that decides when this
  /// is non-zero. Zero for every other task, matching every other
  /// new-parameter default in this widget.
  final double bottomTrim;

  /// Shrinks this pill BELOW its normal `badgeSize` floor when there isn't
  /// enough real time-to-pixel room before the next same-column task's own
  /// top to fit that floor and still leave a visible gap.
  ///
  /// Requested directly, from a screenshot of two close-but-non-overlapping
  /// short tasks (5- and 15-minute examples given) whose floored pills
  /// touched: "the smaller one gets below the minimum size in order to
  /// always create some small 2-pixel gap between tasks that don't
  /// effectively overlap but are too close to show." The caller (see
  /// `_maxPillHeight` in `timeline_screen.dart`) is the one place that
  /// computes this from the next same-column task's real top; null (the
  /// default) means no such neighbour exists close enough to matter, so
  /// the badgeSize floor applies exactly as before.
  ///
  /// Applied AFTER both the badgeSize floor and [bottomTrim] — the two
  /// gaps stack rather than compete, since they solve different edges
  /// (this widget's own zone boundary vs. the next task down).
  final double? maxPillHeight;

  /// Whether the pill's HEIGHT scales with the task's duration. Defaults
  /// to true, matching the Task view's own signature look. The Spatial
  /// Zone View passes false — confirmed directly: that view's own
  /// in-container rows already show duration as text at a fixed row
  /// height (`ZoneContainerBlock`'s own "no proportional sizing" rule),
  /// so a task rendered by this block while being dragged there (the
  /// floating drag visual, or an outer-axis capsule) must match that same
  /// fixed-size convention rather than suddenly growing/shrinking by
  /// duration mid-drag. When false, the pill renders at [badgeSize] —
  /// the same floor every capsule already uses for a short task.
  final bool durationIndicatedBySize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    // List view previously read a separate, always-one-step-smaller
    // textTaskTitleCompact style here regardless of Task view's own size.
    // Confirmed directly that List view should track the SAME global
    // "Task size" setting Task/Zone view do, with no relative step, so
    // this now always reads the one active textTaskTitle.
    final titleTextStyle = theme.textTaskTitle;
    // List (collapsed) mode always renders inline (time+duration then
    // title, one line) regardless of the dev-config layout toggle —
    // requested directly: "still need to make time and name sit in one
    // line atm it sits in 2 lines." `textLayout`'s `stacked` (2-line)
    // option is a real, deliberate choice for Task/Zone view's own wider
    // rows, but List mode's rows are compact by design and were
    // unconditionally inheriting whatever the dev toggle happened to be
    // set to, including `stacked`.
    final effectiveTextLayout = compactText
        ? TimelineTaskTextLayout.inline
        : textLayout;
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

    // theme.sizeTaskBadge (20px) — requested directly ("pill size and icon
    // same as on zone view so smaller"), matching ZoneContainerBlock's own
    // row badge exactly rather than this widget's own, larger 36px ad hoc
    // `spacingXl * 0.9`. Mirrored in timeline_screen.dart's _pillWidth;
    // the two must stay in sync (see that function's own doc comment).
    final badgeSize = theme.sizeTaskBadge;
    final rawPillHeight = durationIndicatedBySize
        ? math.max(
            (durationMinutesOverride ?? task.durationMinutes!) *
                pixelsPerMinute,
            badgeSize,
          )
        : badgeSize;
    // Trimmed AFTER the badgeSize floor, and floored again at 0 — a task
    // too short to trim (already at the badge-size floor) simply keeps its
    // full height rather than going negative. See [bottomTrim]'s own doc
    // comment for why this exists.
    final trimmedPillHeight = math.max(rawPillHeight - bottomTrim, 0.0);
    // maxPillHeight can go below badgeSize — that's the whole point (see
    // its own doc comment) — but never below 0.
    final pillHeight = maxPillHeight == null
        ? trimmedPillHeight
        : math.max(math.min(trimmedPillHeight, maxPillHeight!), 0.0);

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
    final durationLabel = formatDurationLabel(task.durationMinutes!);

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
    // `splitLayout` hides this widget's own text/checkbox region for the
    // same reason (and by the same mechanism) as `contentHidden` — the
    // caller renders that content itself, positioned independently. Every
    // site that hid content for a cluster member hides it here too, so the
    // two cases can't drift apart.
    // `liftedTextInline` reopens the text region that `splitLayout`
    // normally collapses — while lifted, the pill carries its own name and
    // time inside the frosted pane (see that field's doc comment).
    final textCollapsed = splitLayout && !liftedTextInline;
    final textRegionHidden = contentHidden || textCollapsed;

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
                // Flush with the pill's own top edge — nudged up a
                // further 2px per direct feedback (second alignment
                // pass): spacingXs/2 (2px) still read as slightly low
                // next to the title.
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: badgeColor,
                  // radiusSm (4px), not radiusTaskPill (fully round) —
                  // requested directly. Kept scoped to this one rail rather
                  // than repointing radiusTaskPill itself, which every
                  // pill-SHAPED button across the app (AppButton, the theme
                  // selector, the tracked-behavior form) also reads —
                  // changing that token's value would have flattened all of
                  // those too, confirmed via AskUserQuestion as the wrong
                  // scope. radiusSm already equals 4 and is a real Tier 2
                  // token, so this reuses it rather than adding a duplicate.
                  borderRadius: BorderRadius.circular(theme.radiusSm),
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
                // including mid-drag. Also stays visible for
                // `contentHidden` (a resting cluster member) — reversing
                // an earlier decision that faded it there too, per direct
                // feedback: the cluster's own row list has no icon of its
                // own (see `OverlapClusterBlock`'s doc comment), so the
                // pill is the only place a clustered task's category
                // reads at all. Only the title/time text and checkbox
                // still fade for `contentHidden` (see the row further
                // down) — those genuinely duplicate the cluster's own row
                // list, but the emoji does not.
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
                // `glyphHidden` (the drag ghost) is the ONE case that also
                // drops the emoji — see its own doc comment.
                child: Opacity(
                  opacity: glyphHidden ? 0 : 1,
                  child: Text(
                    categoryVisual.emoji,
                    style: TextStyle(fontSize: badgeSize * 0.55),
                  ),
                ),
              ),
            ),
          ),
          // Zero-width in split layout, where the whole row is exactly one
          // pill wide and every pixel past the pill overflows — unless the
          // pill is lifted and carrying its own text (liftedTextInline).
          SizedBox(width: textCollapsed ? 0 : theme.spacingSm),
          // Expanded, not Flexible: Flexible let this column shrink to its
          // own content width, so the trailing checkbox sat wherever that
          // row's title happened to end — every row at a different x, and
          // shifting on tap when completing changed the text's measured
          // width (strikethrough). Expanded makes the column always claim
          // the remaining width, which pins the checkbox to a fixed
          // right-hand column. Reported directly.
          // `flex: 0` when collapsed rather than an `if` that swaps this
          // child out: `liftedTextInline` flips mid-drag, and changing the
          // tree SHAPE around the pill's gesture detector is the exact bug
          // class this widget has already hit twice (see the tree-shape
          // comments above). A Flexible with flex 0 and a zero-width child
          // takes no space while keeping every render object in place.
          //
          // Flexible, not Expanded, for the collapsed case specifically:
          // Expanded forces a TIGHT width, which the inner ConstrainedBox's
          // `maxWidth: 0` cannot shrink below — so the collapse used to
          // work only because the split-layout caller happens to size the
          // row to one pill.
          Flexible(
            flex: textCollapsed ? 0 : 1,
            fit: textCollapsed ? FlexFit.loose : FlexFit.tight,
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
                    // `splitLayout` caps this at ZERO, not just fades it:
                    // the caller lays the pill out at exactly one pill
                    // width there, and a text column still claiming its
                    // intrinsic width overflowed that box by the width of
                    // the text — the same RenderFlex overflow this
                    // ClipRect's own comment describes, on the other axis.
                    // Reported directly, from a screenshot showing "RIGHT
                    // OVERFLOWED BY 56 PIXELS" on stacked pills.
                    maxWidth: textCollapsed
                        ? 0
                        : (maxTextWidth ?? double.infinity),
                    maxHeight: textRegionHidden ? pillHeight : double.infinity,
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
                        if (effectiveTextLayout ==
                            TimelineTaskTextLayout.stacked) ...[
                          // Step 1 of the entrance stagger — the name.
                          Opacity(
                            opacity: textRegionHidden
                                ? 0
                                : _staggeredOpacity(entranceProgress, 1),
                            child: Text(
                              task.title,
                              style: titleTextStyle.copyWith(
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
                            opacity: textRegionHidden
                                ? 0
                                : _staggeredOpacity(entranceProgress, 2),
                            child: Text(
                              durationVisible
                                  ? '${startTime.format(context)} - '
                                        '${endTime.format(context)} '
                                        '($durationLabel)'
                                  : '${startTime.format(context)} - '
                                        '${endTime.format(context)}',
                              style: titleTextStyle.copyWith(
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
                            opacity: textRegionHidden
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
                                    style: titleTextStyle.copyWith(
                                      color: theme.colorTextSecondary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: task.title,
                                    style: titleTextStyle.copyWith(
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
                            opacity: textRegionHidden
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
          // `showCompletionCheckbox: false` hides it via the SAME opacity
          // path `contentHidden` already uses, rather than dropping it
          // from the Row — this widget's always-present-tree rule (see the
          // `contentHidden`/`isLifted` comments above and on the pill)
          // exists because changing the tree shape mid-gesture broke drag
          // hit-testing, and a settings toggle can flip mid-drag just as
          // `isLifted` can. `Visibility`/`Offstage` would reclaim the
          // layout space but reintroduce exactly that shape change.
          // Split layout collapses this to zero WIDTH as well as zero
          // opacity — the caller's own TaskCapsuleTextRow renders the real
          // checkbox there, and anything claiming width here overflows a
          // row sized to exactly one pill. ClipRect + a 0-width SizedBox
          // rather than dropping the widget: the always-present-tree rule
          // below still applies.
          ClipRect(
            child: SizedBox(
              width: splitLayout ? 0 : null,
              child: AnimatedOpacity(
                // Step 4 — the last of the entrance stagger. Multiplied into
                // the lift fade for the same reason as the icon row above.
                opacity: (textRegionHidden || !showCompletionCheckbox)
                    ? 0.0
                    : (isLifted ? 0.0 : 1.0) *
                          _staggeredOpacity(entranceProgress, 4),
                duration: theme.motionFast,
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring:
                      isLifted || textRegionHidden || !showCompletionCheckbox,
                  // Nudged up 9px total (4px, then a further 5px per direct
                  // feedback on a second pass) — CompletionCheckbox centers
                  // its own 24px ring inside a 48px tap target
                  // (spacingMinTapTarget), which reads as slightly low next
                  // to the title/badge above once those were re-aligned to
                  // the title's own top inset. No existing token lands on
                  // 9px, so this is a plain literal rather than a forced
                  // token combination. A Transform here, not a change to
                  // CompletionCheckbox itself: the same widget is used
                  // unchanged (and correctly aligned) by the Zone view's own
                  // row.
                  child: Transform.translate(
                    offset: const Offset(0, -9),
                    child: CompletionCheckbox(
                      theme: theme,
                      // Fixed color (CompletionCheckbox's own default), not
                      // the category's — reversed directly from the earlier
                      // category-tinted ring: completion status should look
                      // the same regardless of what's being completed. The
                      // badge above still carries the category's own
                      // emoji/color.
                      isCompleted: isCompleted,
                      onToggle: onToggleComplete,
                    ),
                  ),
                ),
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
        // Real bug, reported directly: "all corners on elevated drag drop
        // is ok but not on [resting] view top left and bottom left still
        // older rounding." This wrapper's own `ClipRRect` is ALWAYS
        // present (see the comment above on why it can't be conditional),
        // and was always clipped at the LIFTED radius (radiusXl, 16) even
        // while resting — the pill's own rail sits flush against this
        // wrapper's left edge with zero padding at t=0, so that outer
        // clip landed right on top of the pill's own corner and overrode
        // its real shape. Its right corners never showed the same problem
        // only because the row's text content sits between the pill's
        // right edge and the wrapper's own right edge, so the outer clip
        // has nothing to visibly cut into there.
        //
        // Animating the radius itself (pill's own resting radius up to
        // radiusXl once fully lifted) is what makes REST correct without
        // undoing the lift treatment, which already looked right. Anchored
        // to radiusSm, not radiusMd — the pill's own rail reads radiusSm
        // (see its own doc comment above); this wrapper has to start from
        // the SAME value or it re-creates the identical mismatch this bug
        // report was about, just shifted between two different tokens
        // instead of two different corners.
        final wrapperRadius = BorderRadius.circular(
          theme.radiusSm + (theme.radiusXl - theme.radiusSm) * t,
        );
        return Container(
          decoration: BoxDecoration(
            borderRadius: wrapperRadius,
            boxShadow: t == 0
                ? const []
                : theme.shadowPane.map((shadow) => shadow.scale(t)).toList(),
          ),
          child: ClipRRect(
            borderRadius: wrapperRadius,
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
/// The time/duration + title + checkbox half of a capsule, as a standalone
/// widget the Spatial Task View positions itself — the counterpart to
/// [TaskCapsuleBlock.splitLayout].
///
/// Exists so every task's NAME can start at the same x regardless of which
/// overlap lane its pill occupies (requested directly: "all task names are
/// lined up even those not stacked"). Laid out as three columns — time,
/// duration, then the title — so the titles align with each other even
/// when the time strings differ in width, matching the mock. The time and
/// duration columns disappear together when [durationVisible] is false,
/// and the title then takes the full width (the mock's left-hand screen).
///
/// Deliberately NOT a second copy of [TaskCapsuleBlock]'s own text: that
/// widget still owns the combined pill+text row every other view uses, and
/// hides only its text region in split mode. This renders the same three
/// pieces with the same tokens and the same status treatment.
class TaskCapsuleTextRow extends StatelessWidget {
  const TaskCapsuleTextRow({
    super.key,
    required this.task,
    required this.timeColumnWidth,
    required this.durationColumnWidth,
    this.dragPreviewStartsAt,
    this.onTap,
    this.onToggleComplete,
    this.durationVisible = true,
    this.alwaysShowTime = false,
    this.showCompletionCheckbox = true,
    this.isFaded = false,
  });

  final Task task;

  /// Fixed widths for the leading time and duration columns, so titles
  /// share one x across every row — see [taskTimeColumnWidth]/
  /// [taskDurationColumnWidth], which the caller uses to compute the same
  /// values it positions this row's own left edge from.
  final double timeColumnWidth;
  final double durationColumnWidth;

  /// Mirrors [TaskCapsuleBlock.dragPreviewStartsAt] — the time text tracks
  /// the drop target live while its pill is being dragged.
  final DateTime? dragPreviewStartsAt;

  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;

  /// Historically hid the ENTIRE time column alongside the duration
  /// suffix when off (see this class's own doc comment: "the time and
  /// duration columns disappear together"), matching an old Task-view-only
  /// mock — deliberately left as-is for Task view's split layout.
  final bool durationVisible;

  /// List mode's own override: forces the time column visible regardless
  /// of [durationVisible], since List mode never shows a real timeline
  /// axis and the time is the only place a task's schedule reads at all —
  /// requested directly. Scoped to this flag rather than changing
  /// [durationVisible]'s existing Task-view meaning, per direct
  /// confirmation that Task view's split layout should keep its current
  /// (dev-toggle-driven) behavior unchanged.
  final bool alwaysShowTime;
  final bool showCompletionCheckbox;

  /// Fades this row out while its own pill is lifted, matching how the
  /// combined layout fades its text region mid-drag.
  final bool isFaded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isCompleted = task.status == TaskStatus.completed;
    final effectiveStart = dragPreviewStartsAt ?? task.scheduledAt!;
    final start = TimeOfDay.fromDateTime(effectiveStart);
    final end = TimeOfDay.fromDateTime(
      effectiveStart.add(Duration(minutes: task.durationMinutes!)),
    );

    return AnimatedOpacity(
      opacity: isFaded ? 0.0 : 1.0,
      duration: theme.motionFast,
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: isFaded,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alwaysShowTime || durationVisible) ...[
              SizedBox(
                width: timeColumnWidth,
                child: Text(
                  '${start.format(context)}-${end.format(context)}',
                  style: theme.textTaskTitle.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (durationVisible)
                SizedBox(
                  width: durationColumnWidth,
                  child: Text(
                    formatDurationLabel(task.durationMinutes!),
                    style: theme.textTaskTitle.copyWith(
                      color: theme.colorTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  task.title,
                  style: theme.textTaskTitle.copyWith(
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
            ),
            if (showCompletionCheckbox) ...[
              SizedBox(width: theme.spacingSm),
              CompletionCheckbox(
                theme: theme,
                isCompleted: isCompleted,
                onToggle: onToggleComplete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Width reserved for the leading "04:00-05:00" time column in
/// [TaskCapsuleTextRow]. A fixed width (not intrinsic) is the whole point —
/// it is what makes every row's title start at the same x.
double taskTimeColumnWidth(AmbleTheme theme) => theme.spacingXl * 3;

/// Width reserved for the "1h" duration column that follows the time.
double taskDurationColumnWidth(AmbleTheme theme) => theme.spacingXl;

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
