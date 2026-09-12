import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import 'edit_mode_wiggle.dart';
import 'resize_handle.dart';
import 'task_edge_time_label.dart';

/// The "wiggly gray default task" dropped on Timeline by tapping empty
/// space — requested directly. Not a real `Task`: no category, no status,
/// nothing persisted until the user actually saves the small/expanded
/// sheet this pill appears alongside. Styled flat neutral gray (no
/// category color exists yet) so it reads as clearly provisional, and
/// wrapped in [EditModeWiggle] (unconditionally enabled — this pill only
/// ever exists while it's actively being placed/adjusted, unlike Edit
/// Mode's own toggleable wiggle) for the requested "wiggly" look.
///
/// Presentation-only, mirroring `ExternalEventCapsuleBlock`'s own
/// precedent for "a capsule-shaped pill that isn't a real interactive
/// Task": geometry (`top`/`left`/`height`) is computed by the caller in
/// the same coordinate space every other Timeline block uses, and drag/
/// resize deltas are reported via callbacks rather than this widget
/// touching any provider/repository itself — the caller
/// (`_DayTimelineState`) owns the actual snap math and the
/// `pendingTaskDraftProvider` writes.
class PendingTaskPill extends StatelessWidget {
  const PendingTaskPill({
    super.key,
    required this.theme,
    required this.top,
    required this.left,
    required this.columnOffset,
    required this.width,
    required this.height,
    required this.startTime,
    required this.endTime,
    required this.textColumnLeft,
    required this.textColumnRight,
    this.title = 'New task',
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onResizeTopStart,
    required this.onResizeTopUpdate,
    required this.onResizeTopEnd,
  });

  final AmbleTheme theme;
  final double top;
  final double left;

  /// Horizontal shift for this block's overlap lane — kept SEPARATE from
  /// [left] rather than baked into it, matching `TaskCapsuleBlock`'s own
  /// split for the same reason: baking the lane into the outer box drags
  /// the title along with the rail, so a lane-2 block's text sat further
  /// right than a lane-1 block's. Reported directly against imported
  /// events ("all tasks text should be aligned to same x") and the same
  /// trap applies here.
  final double columnOffset;

  final double width;
  final double height;

  /// The draft's own live start/end — requested directly: "when quick
  /// new add task is dropped and wiggly showing start and end of task...
  /// until it's scheduled or closed." Rendered as two accent-coloured
  /// [TaskEdgeTimeLabel]s, one hanging off each edge, matching the
  /// long-press placement line's own "time on the right, accent bg"
  /// treatment (`PlaceTaskLineLayer`). Tracks every live drag/resize this
  /// pill's own handles drive — the caller recomputes both on each frame
  /// from its running offset, the same way `top`/`height` already do.
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  /// The shared text column the title is aligned to, and the gutter kept
  /// clear on its right — the same values every real task's name uses, so
  /// the placeholder's name lines up with theirs rather than starting
  /// wherever its own rail ends.
  final double textColumnLeft;
  final double textColumnRight;

  /// The placeholder's name. Defaults to the same "New task" the mini
  /// sheet seeds its own field with, so the pill and the sheet agree on
  /// what the task is called before the user types anything.
  final String title;

  /// Mirrors `_DraggableTaskBlockState`'s own `onDragStart` — present
  /// alongside `onVerticalDragUpdate`/`onVerticalDragEnd` on the real
  /// task's own move detector, and needed here too: a
  /// `GestureDetector` missing `onVerticalDragStart` did not reliably
  /// win the gesture arena against this pill's `SingleChildScrollView`
  /// ancestor (the day column) in testing — `onVerticalDragUpdate` never
  /// fired at all, only `onVerticalDragEnd`, even though the same-shape
  /// detector on a real `TaskCapsuleBlock` (which DOES wire `onDragStart`)
  /// drags correctly inside the identical scrollable.
  final GestureDragStartCallback onMoveStart;

  /// Fired with each frame's vertical pixel delta — mirrors
  /// `_DraggableTaskBlockState`'s own `onDragUpdate` shape
  /// (`details.delta.dy`), so the caller accumulates it into one local
  /// running offset (`_draftDragOffset += delta`) exactly the way a real
  /// task's drag preview already works.
  final ValueChanged<double> onMoveUpdate;
  final VoidCallback onMoveEnd;

  /// Bottom-edge resize — changes the draft's duration only, its start
  /// left alone.
  final GestureDragStartCallback onResizeStart;
  final ValueChanged<double> onResizeUpdate;
  final VoidCallback onResizeEnd;

  /// Top-edge resize — moves the draft's START while its END stays put,
  /// mirroring the real task capsule's own top handle (and the zone
  /// blocks' before it). Requested directly: "let's include resize up
  /// (so resize handle on top) both in this scenario and edit mode."
  final GestureDragStartCallback onResizeTopStart;
  final ValueChanged<double> onResizeTopUpdate;
  final VoidCallback onResizeTopEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: 0,
      height: height,
      // The title is a SIBLING of the wiggling rail, never inside it —
      // requested directly: the name should sit in the shared text column
      // "but not wiggly, as if it was normally a task (in edit mode the
      // selected tasks to edit, name not wiggle)". This mirrors how a real
      // task is built: `_buildSplit` positions its own text row as a
      // sibling of the `EditModeWiggle`-wrapped pill, so only the pill
      // moves. Wrapping both together would drag the name along with the
      // rail's rotation, which no real task does.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // IgnorePointer, because this box now spans the full row width
          // to reach the shared text column — without it the placeholder
          // swallows taps meant for the real tasks underneath it, which
          // broke selection across the whole multi-task suite (11 tests)
          // the moment the title moved out here. The name is decoration;
          // every gesture this pill owns belongs to the rail below.
          Positioned(
            top: 0,
            // `textColumnLeft` directly, NOT `textColumnLeft - left`.
            // A real task's own text row does exactly this (see
            // `_buildSplit`): its outer box is already positioned at
            // `left`, and the shared column x is expressed relative to
            // that box, not to the day column's origin. Subtracting
            // `left` here double-corrected and pushed the name one hour-
            // gutter width to the left of every real task's name —
            // reported directly after a first pass that a widget test
            // wrongly confirmed, because that test supplied its own
            // `left` and `textColumnLeft` and so agreed with either
            // formula.
            left: textColumnLeft,
            right: textColumnRight,
            child: IgnorePointer(
              child: Text(
                title,
                style: theme.textBody.copyWith(
                  color: theme.colorTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          EditModeWiggle(
            enabled: true,
            // The resize handle is a SIBLING of the move-drag GestureDetector
            // below, never a descendant of it — matches TaskCapsuleBlock's
            // own structure exactly, fixing a real, previously-caught bug
            // there: nesting both vertical-drag recognizers in the same
            // subtree puts them in one gesture arena, so a drag starting on
            // the handle also fires the outer move detector's own handlers.
            // Siblings never share an arena the same way.
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: onMoveStart,
                  onVerticalDragUpdate: (details) =>
                      onMoveUpdate(details.delta.dy),
                  onVerticalDragEnd: (_) => onMoveEnd(),
                  // Shaped like a REAL task capsule — a `sizeTaskBadge`-wide
                  // rail with the title beside it — rather than the plain
                  // translucent rectangle this used to be. Requested
                  // directly: "as actual pill grey but no icon, so also new
                  // task text would be there." Grey stands in for the
                  // category colour a real task's rail carries, and the
                  // badge is deliberately EMPTY: the draft has no category
                  // until the user picks one (a template chip, or the full
                  // sheet), so showing any emoji here would be inventing one.
                  // `mainAxisSize.min`, so the opaque detector covers only
                  // the rail and its lane inset — NOT the full row width.
                  // This box spans to the right edge (it has to, to reach
                  // the shared text column), and a full-width opaque
                  // detector there swallowed every tap meant for the real
                  // tasks underneath, breaking selection across the whole
                  // multi-task suite.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: columnOffset),
                      Container(
                        width: width,
                        height: height,
                        decoration: BoxDecoration(
                          color: theme.colorTextSecondary.withValues(
                            alpha: 0.30,
                          ),
                          borderRadius: BorderRadius.circular(theme.radiusSm),
                        ),
                      ),
                    ],
                  ),
                ),
                // Scoped to the RAIL, not the whole row: now that the pill
                // carries a title beside it, a full-width handle would make
                // the text area grab-to-resize and swallow taps meant for
                // the block itself. Matches TaskCapsuleBlock, whose handles
                // likewise live on its own pill rather than its text.
                Positioned(
                  left: columnOffset,
                  width: width,
                  top: 0,
                  child: ResizeHandle(
                    theme: theme,
                    // Shrinks on a short pill so the two handles never
                    // consume the whole block — see resizeHandleHeightFor.
                    height: resizeHandleHeightFor(
                      theme: theme,
                      blockHeight: height,
                    ),
                    onDragStart: onResizeTopStart,
                    onDragUpdate: (details) =>
                        onResizeTopUpdate(details.delta.dy),
                    onDragEnd: (_) => onResizeTopEnd(),
                  ),
                ),
                Positioned(
                  left: columnOffset,
                  width: width,
                  bottom: 0,
                  child: ResizeHandle(
                    theme: theme,
                    height: resizeHandleHeightFor(
                      theme: theme,
                      blockHeight: height,
                    ),
                    onDragStart: onResizeStart,
                    onDragUpdate: (details) => onResizeUpdate(details.delta.dy),
                    onDragEnd: (_) => onResizeEnd(),
                  ),
                ),
              ],
            ),
          ),
          // The draft's own start/end, one accent label per edge — see
          // this field's own doc comment. Full row width (like the title
          // above), centred on each edge via the same -0.5
          // FractionalTranslation the placement line itself uses, and
          // last in this Stack's child list so they paint above the rail
          // and the resize handles rather than underneath them.
          //
          // showLine: false — reported directly: unlike the long-press
          // placement line (which marks a drop point on otherwise-empty
          // background), this pill already IS a visible block, so a
          // second full-width line reads as noise rather than a
          // placement aid. Just the accent time badge.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FractionalTranslation(
              translation: const Offset(0, -0.5),
              child: TaskEdgeTimeLabel(
                theme: theme,
                time: startTime,
                showLine: false,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FractionalTranslation(
              translation: const Offset(0, 0.5),
              child: TaskEdgeTimeLabel(
                theme: theme,
                time: endTime,
                showLine: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
