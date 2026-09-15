import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/dev_config.dart' show TimelineTaskTextLayout;
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/selected_pill_border.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_category.dart';
import '../../shared/models/task_status.dart';
import '../task_detail/category_visual.dart';
import 'completion_checkbox.dart';
import 'duration_label.dart';
import 'resize_handle.dart';
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
    this.onLongPress,
    this.onToggleComplete,
    this.dragPreviewStartsAt,
    this.maxTextWidth,
    this.durationMinutesOverride,
    this.entranceProgress = 1,
    this.isLifted = false,
    this.isResizing = false,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.contentHidden = false,
    this.textLayout = TimelineTaskTextLayout.stacked,
    this.iconsVisible = true,
    this.durationVisible = true,
    this.timeRangeVisible = true,
    this.durationIndicatedBySize = true,
    this.category,
    this.compactText = false,
    this.showCompletionCheckbox = true,
    this.splitLayout = false,
    this.glyphHidden = false,
    this.liftedTextInline = false,
    this.bottomTrim = 0,
    this.maxPillHeight,
    this.editModeEnabled = false,
    this.isSelected = false,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onResizeTopStart,
    this.onResizeTopUpdate,
    this.onResizeTopEnd,
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

  /// Long-press anywhere on the pill or the time/title area — requested
  /// directly: "long press on task should enable its edit mode (duration)
  /// wiggle." Mirrors [onTap]'s own "tap anywhere on either region" shape
  /// exactly, wired to the same two `GestureDetector`s below. Null renders
  /// no long-press behavior (e.g. the drag preview's static ghost copy,
  /// which shouldn't itself be armable).
  final VoidCallback? onLongPress;
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

  /// Whether Edit Mode is active — see `edit_mode_provider.dart`. Gates
  /// the resize handle's visibility only; drag-to-reschedule and tap stay
  /// available regardless (per CONSTITUTION.md, move is unchanged by Edit
  /// Mode). Plain `bool`, not a Riverpod watch — this is a
  /// `StatelessWidget` with no provider access, same reasoning as
  /// [category] above; the caller resolves it once and passes it down.
  final bool editModeEnabled;

  /// Whether this task is currently SELECTED (multi-task edit mode) —
  /// rendered as an accent ring on the pill's own coloured rail.
  ///
  /// Requested directly: "instead of wiggle should be same accent color
  /// border as on zones used here." Uses the identical treatment
  /// `ZoneGridBlock` gives a selected zone (`colorAccent` at
  /// `borderWidthHairline * 2`), so selection looks the same whichever
  /// kind of block you are editing. Task wiggle is gone entirely as a
  /// result — see `timeline_screen.dart`'s `editAffordanceActive`.
  final bool isSelected;

  /// The bottom-edge resize handle's own vertical drag handlers — a
  /// deliberately SEPARATE gesture channel from [onDragStart]/
  /// [onDragUpdate]/[onDragEnd] above (move), scoped to a small always-
  /// present hit target at the pill's bottom edge rather than the whole
  /// pill, so resize and move never compete for the same touch. Null
  /// (the default) renders no visible handle at all — callers pass these
  /// only when [editModeEnabled] is true, mirroring how [onDragStart] etc.
  /// are null in collapsed (List) mode to mean "not draggable there."
  ///
  /// Changes `durationMinutes` only, leaving the start time alone —
  /// unlike [onResizeTopStart] below, which moves the START and leaves
  /// the END fixed.
  final GestureDragStartCallback? onResizeStart;
  final GestureDragUpdateCallback? onResizeUpdate;
  final GestureDragEndCallback? onResizeEnd;

  /// The TOP-edge resize handle's own drag handlers — same separate-
  /// gesture-channel contract as [onResizeStart] above, mirroring
  /// `ZoneBackgroundBlock`/`ZoneContainerBlock`'s own long-standing
  /// two-handle shape (`onResizeTopStart`/`onResizeBottomStart`).
  /// Requested directly: "let's include resize up (so resize handle on
  /// top) ... we already have that in zone resize."
  ///
  /// Semantically the mirror of the bottom handle: dragging this edge
  /// moves the task's START (`scheduledAt`) while its END stays put, so
  /// it necessarily changes BOTH `scheduledAt` and `durationMinutes`.
  /// That is a deliberate, confirmed reversal of CONSTITUTION.md's
  /// earlier "Task resize does NOT touch scheduledAt" rule — see that
  /// document's own Edit Mode section for the recorded reversal.
  final GestureDragStartCallback? onResizeTopStart;
  final GestureDragUpdateCallback? onResizeTopUpdate;
  final GestureDragEndCallback? onResizeTopEnd;

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

  /// Whether a resize drag (either edge) is live on this block right now.
  ///
  /// Zeroes the pill's own height animation for the duration of the
  /// gesture — reported directly: "resize bottom is animated so pill
  /// catches up (should follow also)." The height [AnimatedContainer]
  /// exists so a duration change from the edit modal or a cascade
  /// visibly grows/shrinks the pill, which is still right for those; but
  /// under a finger it made the pill trail the drag and then settle.
  /// A gesture should track 1:1, so this flag opts that one case out
  /// rather than removing the animation everyone else depends on.
  final bool isResizing;

  /// Renders the PILL at this duration instead of the task's own, without
  /// touching the time/duration text (which keeps showing the real,
  /// already-saved value). Used for exactly one thing: holding a pill at
  /// its pre-save height while the create/edit modal is still closing, so
  /// the grow/shrink into the new duration happens where the user can
  /// actually see it — see `_DraggableTaskBlock.growFromMinutes`.
  /// **`double`, not `int` (2026-09-12).** A live resize drag drives this
  /// with a continuous, unsnapped duration so the pill tracks the finger
  /// exactly; rounding to whole minutes here would put ~1.5px of stepping
  /// back into the one path that exists to be smooth. Callers that have
  /// an `int` (a group follower's snapped preview, a held pre-save
  /// duration) simply widen it.
  final double? durationMinutesOverride;

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
  ///
  /// Only independent of [timeRangeVisible] in List (collapsed) mode
  /// (`compactText == true`) — see that field's own doc comment. In Task
  /// view (`compactText == false`), this flag alone still hides the whole
  /// time+duration line, unchanged from before [timeRangeVisible] existed:
  /// requested directly, "should not affect task spatial view (on this
  /// view we'd never show this)."
  final bool durationVisible;

  /// List (collapsed) mode only — the `04:20 - 05:20`-style time range,
  /// independent of [durationVisible]'s `(45m)` duration suffix. Requested
  /// directly: "we should add setting show time from to... these should
  /// affect list view only and should not affect task spatial view."
  ///
  /// Has no effect at all when [compactText] is false (Task view): that
  /// branch's time+duration line is governed solely by [durationVisible],
  /// exactly as it was before this field existed. Defaults to true,
  /// matching List view's existing always-shown time range.
  final bool timeRangeVisible;

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
    // List mode only: [timeRangeVisible]/[durationVisible] are independent
    // toggles there (see their own doc comments). Task view keeps its
    // original, unchanged behavior — [durationVisible] alone gates the
    // whole line, and the time range itself is always shown when it does.
    final showTimeRange = compactText ? timeRangeVisible : true;
    final timeRangeText =
        '${startTime.format(context)} - ${endTime.format(context)}';
    final durationSuffix = durationVisible ? ' ($durationLabel)' : '';
    final timeLine = showTimeRange ? '$timeRangeText$durationSuffix' : '';

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
      // stretch, NOT start — corrected directly: "task outside zone view
      // text isn't centered... on timeline view text goes higher, should
      // be aligned with icon." Measured before fixing: the row's real
      // height is set by whichever child is tallest — often the trailing
      // CompletionCheckbox's fixed 48px tap target, NOT the pill, once the
      // pill is anywhere near its badge-size floor. With `start`, every
      // child (pill, text column, checkbox) kept only its OWN intrinsic
      // height, pinned to the row's top — so a short pill's title, given a
      // fixed 4px top offset meant for a badge-height row, sat near the
      // top of a much taller (checkbox-driven) row with dead space below
      // it. `stretch` gives every child the row's real height; each one
      // then positions its own content within that height as appropriate:
      // the pill's own `AnimatedContainer.alignment: topCenter` already
      // pins its emoji to the top (unchanged, still correct — the icon
      // should stay flush with the pill's own top edge regardless of the
      // row's height), `CompletionCheckbox` already centers itself
      // internally (unchanged), and the text column below gains a new
      // `Center` wrapper so IT constructs the one thing that was actually
      // missing: centering against the row's own real height.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag-to-reschedule is scoped to just this pill — wrapping the
          // whole row (as before) made the title/time text draggable too,
          // which fought the timeline's vertical scroll gesture. See the
          // doc comment on onDragStart above.
          Opacity(
            // Step 0 of the entrance stagger — the pill leads.
            opacity: _staggeredOpacity(entranceProgress, 0),
            // Wrapped in a Stack (a genuinely NEW, always-present
            // ancestor, not a conditional swap) so the resize handle can
            // overlay the pill's bottom edge as a SIBLING of the move-drag
            // GestureDetector below, never a descendant of it — real bug,
            // caught by a widget test: nesting the handle's own
            // GestureDetector INSIDE the pill's move-drag detector put
            // both vertical-drag recognizers in the same gesture arena,
            // and a drag starting on the handle also fired the pill's own
            // onDragStart. Siblings never share an arena the same way.
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: onTap,
                  onLongPress: onLongPress,
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
                    //
                    // Zero while a resize drag is live, though — see
                    // [isResizing]. Under a finger the pill has to track the
                    // gesture exactly; the "watch this happen" pacing above is
                    // for duration changes the user did NOT drag out.
                    duration: isResizing ? Duration.zero : theme.motionSlow,
                    curve: theme.curveStandard,
                    width: badgeSize,
                    height: pillHeight,
                    alignment: Alignment.topCenter,
                    // Flush with the pill's own top edge — nudged up a
                    // further 2px per direct feedback (second alignment
                    // pass): spacingXs/2 (2px) still read as slightly low
                    // next to the title.
                    padding: EdgeInsets.zero,
                    // theme.radiusPill — the ACTIVE rung of the "Pill
                    // shape" setting (small/rounded/full), not
                    // radiusTaskPill (always fully round, used by
                    // AppButton/the theme selector/the tracked-behavior
                    // form, none of which this setting should touch —
                    // confirmed via AskUserQuestion as the wrong scope for
                    // those). Was hardcoded to radiusSm (4px) before this
                    // setting existed; requested directly ("we have squary
                    // rounded shape of pills but rounded on inbox ... this
                    // should affect globally").
                    //
                    // Selection reads as a two-ring border on the rail —
                    // requested directly, replacing the wiggle that used to
                    // signal it, then refined again: a single accent ring
                    // disappeared against a pill that happened to already be
                    // blue, so a thin dark separator ring now sits between
                    // the accent ring and the fill, regardless of the pill's
                    // own color. See [SelectedPillBorder]'s own doc comment.
                    // Unselected keeps the exact same box (color, radius, no
                    // border) as before this feature existed at all.
                    decoration: isSelected
                        ? BoxDecoration(
                            border: Border.all(
                              color: theme.colorAccent,
                              width: SelectedPillBorder.accentWidth(theme),
                            ),
                            borderRadius: BorderRadius.circular(
                              theme.radiusPill,
                            ),
                            // No shadow here any more while lifted — the
                            // shadow now belongs to the outer frosted card
                            // (see the wrapping below).
                          )
                        : BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(
                              theme.radiusPill,
                            ),
                          ), // Unselected: this is the pill's ONLY fill —
                    // the inner box below stays undecorated in that case,
                    // so the color is painted once, exactly as before this
                    // feature existed.
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
                    //
                    // The emoji itself is wrapped in the dark separator
                    // ring + fill (see [SelectedPillBorder]'s doc comment)
                    // only while selected, inset by the accent border's own
                    // width so the two rings stay concentric. Unselected,
                    // `badgeColor` already lives on the outer decoration
                    // above and this whole inner wrapper is skipped — the
                    // child is the bare emoji, same three widgets
                    // (`Opacity` -> `Text`) as before this feature existed,
                    // not extra empty layers left in the tree for a case
                    // that needs none of them.
                    child: isSelected
                        ? SizedBox.expand(
                            // `AnimatedContainer`'s own `alignment:
                            // topCenter` wraps ITS child in an `Align`,
                            // which lets that child shrink-wrap to its
                            // natural size instead of filling the box —
                            // without forcing this layer to expand, the
                            // separator ring below would hug just the
                            // emoji's own tiny bounds rather than the full
                            // pill.
                            child: Padding(
                              padding: EdgeInsets.all(
                                SelectedPillBorder.accentWidth(theme),
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  border: Border.all(
                                    color: theme.colorScrim,
                                    width: SelectedPillBorder.separatorWidth(
                                      theme,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    (theme.radiusPill -
                                            SelectedPillBorder.accentWidth(
                                              theme,
                                            ))
                                        .clamp(0.0, double.infinity),
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Opacity(
                                    opacity: glyphHidden ? 0 : 1,
                                    child: Text(
                                      categoryVisual.emoji,
                                      style: TextStyle(
                                        fontSize: badgeSize * 0.55,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Opacity(
                            opacity: glyphHidden ? 0 : 1,
                            child: Text(
                              categoryVisual.emoji,
                              style: TextStyle(fontSize: badgeSize * 0.55),
                            ),
                          ),
                  ),
                ),
                // The resize handle — visible only in Edit Mode, and only
                // when the caller actually wired resize callbacks (both
                // conditions must hold; see [onResizeStart]'s own doc
                // comment for why null callbacks mean "not resizable
                // here"). A small dedicated hit target at the pill's own
                // bottom edge — deliberately NOT the whole pill (that's
                // the move-drag's territory) and a genuine SIBLING of the
                // pill's GestureDetector above (both are direct children
                // of this Stack), never nested inside it — see the doc
                // comment on the outer Opacity/Stack wrap for the bug that
                // ordering fixes.
                // **2026-09-12 — bigger resize targets.** Requested
                // directly: "handle hit/active area should be larger
                // outward... we need affordance for all resize and move 3
                // different interactive hotspots... and sides also
                // difficult to catch." Genuinely-outward growth turned
                // out to be impossible (a box past the pill's bounds
                // paints but never hit-tests — see
                // `taskResizeHandleHeightFor` for the probe), so each
                // handle grows INWARD from its edge while its visible bar
                // stays pinned to that edge via `barAlignment`. Flush at
                // the edge now (was `-spacingXs`), since an overhanging
                // strip was dead area that only looked grabbable.
                if (editModeEnabled && onResizeTopEnd != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ResizeHandle(
                      theme: theme,
                      height: taskResizeHandleHeightFor(
                        theme: theme,
                        blockHeight: pillHeight,
                      ),
                      barAlignment: Alignment.topCenter,
                      onDragStart: onResizeTopStart,
                      onDragUpdate: onResizeTopUpdate,
                      onDragEnd: onResizeTopEnd,
                    ),
                  ),
                if (editModeEnabled && onResizeEnd != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ResizeHandle(
                      theme: theme,
                      height: taskResizeHandleHeightFor(
                        theme: theme,
                        blockHeight: pillHeight,
                      ),
                      barAlignment: Alignment.bottomCenter,
                      onDragStart: onResizeStart,
                      onDragUpdate: onResizeUpdate,
                      onDragEnd: onResizeEnd,
                    ),
                  ),
              ],
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
              onLongPress: onLongPress,
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
                              timeLine,
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
                                    text: timeLine.isEmpty ? '' : '$timeLine  ',
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
        // Anchored to a small FIXED `radiusSm`, deliberately independent of
        // `theme.radiusPill` — reported directly against a screenshot
        // ("pills are clipped, rounding is applied not directly on pills
        // but perhaps elsewhere"), and measured before fixing.
        //
        // The trap here is that a bigger radius on this wrapper makes the
        // clipping WORSE, not better. This wrapper spans the whole ROW
        // (~390px wide); the pill is a ~24px-wide rail pinned to its
        // top-left with zero inset. Flutter clamps a rounded-rect corner to
        // half the box's SHORTER side, so on a short row (e.g. a 30-minute
        // task, 390x60) a large radius clamps to a 30px arc that sweeps
        // straight through the pill's own 24px width and bites its
        // top-left and bottom-left corners off. A tall row (390x180) clamps
        // to 90px, whose arc curves away outside the pill's visible edge —
        // which is exactly why the reported screenshot showed SHORT pills
        // flat-topped while tall ones looked correct.
        //
        // An earlier attempt set this to `max(radiusSm, radiusPill)`,
        // reasoning that a wider clip could never cut into the pill. That
        // is true for a clip of the same size as the pill, and false here:
        // this box is 16x the pill's width, so "wider radius" means "arc
        // reaching further across the pill". Small and fixed is correct —
        // the wrapper has no visible shape of its own at rest anyway (no
        // fill, no blur, no shadow at t=0), so its corner only ever
        // matters for what it cuts. Still animates UP to radiusXl once
        // actually lifted, where the frosted card IS visible and wants a
        // real corner.
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
    this.onLongPress,
    this.onToggleComplete,
    this.durationVisible = true,
    this.alwaysShowTime = false,
    this.timeRangeVisible = true,
    this.showCompletionCheckbox = true,
    this.isFaded = false,
    this.compactInlineLayout = false,
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

  /// See [TaskCapsuleBlock.onLongPress]'s own doc comment — same
  /// "long-press anywhere on the task arms it" contract, wired to this
  /// row's own `GestureDetector`s since split-layout mode renders the text
  /// separately from the pill.
  final VoidCallback? onLongPress;
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

  /// List mode's own from-to time range (`04:20 - 05:20`), independent of
  /// [durationVisible]'s duration label — requested directly: "show
  /// duration dev setting should only show duration, we should add
  /// setting show time from to." Only consulted in [compactInlineLayout]
  /// mode; Task view's split layout is unaffected (it always shows its
  /// own time column via [alwaysShowTime]/[durationVisible], per that
  /// field's own doc comment on the non-`compactInlineLayout` branch).
  final bool timeRangeVisible;
  final bool showCompletionCheckbox;

  /// Fades this row out while its own pill is lifted, matching how the
  /// combined layout fades its text region mid-drag.
  final bool isFaded;

  /// List mode's own layout, matching `OverlapClusterBlock`'s inline
  /// cluster row exactly — requested directly: "There is a space between
  /// the hyphen on both sides ... and there is no large space, just a
  /// single space for the task name. That should be the same ... applied
  /// also for non-stacked items." Off (the default), this row keeps its
  /// original fixed-width [timeColumnWidth]/[durationColumnWidth] columns
  /// (Task view's split layout, where every row's title must start at the
  /// same x regardless of lane — see this class's own doc comment). On,
  /// the time/duration/title collapse into ONE inline `Text.rich` run —
  /// `'$start - $end  '` (spaced dash, two trailing spaces) then the
  /// title — with no column alignment at all, since List mode's rows
  /// don't share lanes to align across in the first place.
  final bool compactInlineLayout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isCompleted = task.status == TaskStatus.completed;
    final effectiveStart = dragPreviewStartsAt ?? task.scheduledAt!;
    final start = TimeOfDay.fromDateTime(effectiveStart);
    final end = TimeOfDay.fromDateTime(
      effectiveStart.add(Duration(minutes: task.durationMinutes!)),
    );

    // Two INDEPENDENT pieces, only actually used when `compactInlineLayout`
    // is on (List view) — the fixed-column branch below builds its own
    // (unspaced-dash) string independently, unchanged. Requested directly:
    // "show duration dev setting should only show duration, we should add
    // setting show time from to (should then show time)" — either, both,
    // or neither can be on, rather than duration being a suffix baked onto
    // the time string.
    final timeRange = timeRangeVisible
        ? '${start.format(context)} - ${end.format(context)}'
        : null;
    final durationLabel = durationVisible
        ? '(${formatDurationLabel(task.durationMinutes!)})'
        : null;
    final timeLabel = [?timeRange, ?durationLabel].join(' ');

    final titleStyle = theme.textTaskTitle.copyWith(
      color: isCompleted ? theme.colorTextSecondary : theme.colorTextPrimary,
      fontWeight: FontWeight.w700,
      decoration: isCompleted
          ? TextDecoration.lineThrough
          : TextDecoration.none,
      decorationColor: theme.colorTextSecondary,
    );
    // One rendered line of the title, derived from the type tokens rather
    // than hardcoded — the trailing completion checkbox centres itself on
    // this so it lines up with the text instead of with the row.
    final titleLineHeight =
        (titleStyle.fontSize ?? 0) * (titleStyle.height ?? 1);
    // The important marker hangs in the margin BEFORE the title rather
    // than displacing it — requested directly: "just icon in front of the
    // task (with negative margin so the task name remains aligned with all
    // other tasks)". A zero-width `WidgetSpan` whose child is translated
    // left by its own width is what achieves that: it contributes nothing
    // to the line's layout, so a marked task's title starts at exactly the
    // same x as an unmarked one's, on both this row's layouts and in every
    // view that shares this span (see [titleSpan]'s two call sites below).
    //
    // Deliberately calm, not alarm-coded (per CONSTITUTION.md's design
    // principle 1): the existing secondary text color at the title's own
    // size, never red, never a filled badge. Making important tasks
    // legible must not make every other task read as failing to matter.
    final titleSpan = TextSpan(
      children: [
        if (task.isImportant)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _ImportantMarker(theme: theme),
          ),
        TextSpan(text: task.title, style: titleStyle),
      ],
      style: titleStyle,
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
            if (compactInlineLayout) ...[
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  behavior: HitTestBehavior.opaque,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (timeLabel.isNotEmpty)
                          TextSpan(
                            text: '$timeLabel  ',
                            style: theme.textTaskTitle.copyWith(
                              color: theme.colorTextSecondary,
                            ),
                          ),
                        titleSpan,
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ] else ...[
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
                  onLongPress: onLongPress,
                  behavior: HitTestBehavior.opaque,
                  child: Text.rich(
                    titleSpan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            if (showCompletionCheckbox) ...[
              SizedBox(width: theme.spacingSm),
              // Centred on the FIRST LINE of the title, not on the row.
              // The checkbox's 48px tap target is taller than the ~18px
              // text, and under the Row's `CrossAxisAlignment.start` it
              // was the checkbox that defined the row height while the
              // text sat at the top — measured 15px apart, which reads as
              // the checkbox floating below its own task (reported
              // directly: "not in the same line as task"). Collapsing the
              // tap target's own height out of the cross-axis calculation
              // and re-centring it on one text line puts the two back on
              // the same line, at any title length and in a stacked
              // overlap cluster alike.
              SizedBox(
                height: titleLineHeight,
                width: theme.spacingMinTapTarget,
                // The 48px target still renders and still receives taps —
                // it simply stops contributing its height to the Row.
                // `OverflowBox` lets it paint outside the one-line slot
                // above/below, so WCAG 2.5.8's minimum target size is
                // preserved while the visible ring stays on the text's
                // line. Collapsing the SizedBox alone would have shrunk
                // the real tap area to ~18px.
                child: OverflowBox(
                  maxHeight: theme.spacingMinTapTarget,
                  minHeight: theme.spacingMinTapTarget,
                  child: CompletionCheckbox(
                    theme: theme,
                    isCompleted: isCompleted,
                    onToggle: onToggleComplete,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The `isImportant` marker that hangs in the margin immediately before a
/// task's title, without displacing it.
///
/// Occupies ZERO layout width (a `SizedBox.shrink` with the glyph painted
/// via a non-clipping `OverflowBox`, shifted left by its own size) — so a
/// marked and an unmarked task's titles start at the identical x, which is
/// the whole requirement: "with negative margin so the task name remains
/// aligned with all other tasks".
///
/// Visual language is deliberately quiet — [AmbleTheme.colorTextSecondary]
/// at the title's own optical size, the same treatment every other ambient
/// annotation in this codebase uses. Never red, never a filled badge: per
/// CONSTITUTION.md's design principle 1, marking a few tasks important must
/// not make the rest look like they're failing.
class _ImportantMarker extends StatelessWidget {
  const _ImportantMarker({required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    final size = theme.textTaskTitle.fontSize!;
    return SizedBox(
      width: 0,
      height: size,
      child: OverflowBox(
        // Unbounded on the left so the glyph can paint outside this
        // zero-width box rather than being clipped to nothing.
        alignment: Alignment.centerRight,
        maxWidth: double.infinity,
        child: Padding(
          // The gap between the marker and the title it precedes. Applied
          // as trailing padding INSIDE the overflowing child, so it pushes
          // the glyph further left rather than moving the title right.
          padding: EdgeInsets.only(right: theme.spacingXs),
          child: Icon(
            Icons.star_rounded,
            size: size,
            color: theme.colorTextSecondary,
          ),
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
