import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import 'resize_handle.dart';
import 'task_compact_controls.dart';

/// Separates the task's true duration from the space needed to manipulate it.
/// The parent must give this widget its measured width and height for hit
/// testing; painting outside a smaller parent is not enough.
class TaskManipulationTargets extends StatelessWidget {
  const TaskManipulationTargets({
    super.key,
    required this.theme,
    required this.visualWidth,
    required this.visualHeight,
    required this.visual,
    required this.active,
    this.interactionPrimary = true,
    this.onTap,
    this.onHandleActivate,
    this.onLongPress,
    this.onMoveStart,
    this.onMoveUpdate,
    this.onMoveEnd,
    this.onMoveCancel,
    this.onStartResize,
    this.onStartResizeUpdate,
    this.onStartResizeEnd,
    this.onStartResizeCancel,
    this.onEndResize,
    this.onEndResizeUpdate,
    this.onEndResizeEnd,
    this.onEndResizeCancel,
  });

  final AmbleTheme theme;
  final double visualWidth;
  final double visualHeight;
  final Widget visual;
  final bool active;
  final bool interactionPrimary;
  final VoidCallback? onTap;
  final VoidCallback? onHandleActivate;
  final VoidCallback? onLongPress;
  final GestureDragStartCallback? onMoveStart;
  final GestureDragUpdateCallback? onMoveUpdate;
  final GestureDragEndCallback? onMoveEnd;
  final VoidCallback? onMoveCancel;
  final GestureDragStartCallback? onStartResize;
  final GestureDragUpdateCallback? onStartResizeUpdate;
  final GestureDragEndCallback? onStartResizeEnd;
  final VoidCallback? onStartResizeCancel;
  final GestureDragStartCallback? onEndResize;
  final GestureDragUpdateCallback? onEndResizeUpdate;
  final GestureDragEndCallback? onEndResizeEnd;
  final VoidCallback? onEndResizeCancel;

  double get targetWidth {
    if (!active) return visualWidth;
    if (!interactionPrimary) return visualWidth;
    return math.max(visualWidth, theme.spacingMinTapTarget);
  }

  double get targetHeight => visualHeight;

  @override
  Widget build(BuildContext context) {
    final touch = theme.spacingMinTapTarget;
    final handleHeight = taskResizeHandleHeightFor(
      theme: theme,
      blockHeight: visualHeight,
    );
    // On tiny pills the side strip remains move-only, even when the
    // top and bottom resize regions occupy the entire visual height.
    final handleWidth = visualHeight < touch ? visualWidth : targetWidth;
    final dotX =
        (visualWidth - theme.spacingSm) / (handleWidth - theme.spacingSm) - 1;
    return SizedBox(
      width: targetWidth,
      height: targetHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: targetWidth,
            height: visualHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onLongPress: onLongPress,
              onVerticalDragStart: onMoveStart,
              onVerticalDragUpdate: onMoveUpdate,
              onVerticalDragEnd: onMoveEnd,
              onVerticalDragCancel: onMoveCancel,
              child: Align(alignment: Alignment.topLeft, child: visual),
            ),
          ),
          if (active) ...[
            if (onStartResizeEnd != null)
              Positioned(
                top: 0,
                left: 0,
                width: handleWidth,
                child: TaskCompactResizeCell(
                  theme: theme,
                  height: handleHeight,
                  alignment: Alignment(dotX, -1),
                  label: 'Start',
                  consumeTap: onTap != null,
                  onTap: onHandleActivate,
                  onStart: onStartResize,
                  onUpdate: onStartResizeUpdate,
                  onEnd: onStartResizeEnd,
                  onCancel: onStartResizeCancel,
                ),
              ),
            if (onEndResizeEnd != null)
              Positioned(
                bottom: 0,
                left: 0,
                width: handleWidth,
                child: TaskCompactResizeCell(
                  theme: theme,
                  height: handleHeight,
                  alignment: Alignment(dotX, 1),
                  label: 'End',
                  consumeTap: onTap != null,
                  onTap: onHandleActivate,
                  onStart: onEndResize,
                  onUpdate: onEndResizeUpdate,
                  onEnd: onEndResizeEnd,
                  onCancel: onEndResizeCancel,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
