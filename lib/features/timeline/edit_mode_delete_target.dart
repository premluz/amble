import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';

/// The drag-to-delete target — a bar fixed to the bottom of the Timeline's
/// viewport, visible only while a Task is being dragged AND Edit Mode is
/// active (see CONSTITUTION.md's "Edit Mode" section: "same interaction
/// shape as Android/YouTube's drag-to-dismiss picture-in-picture
/// pattern"). Fades in on drag start, fades out on drag end regardless of
/// outcome.
///
/// [isArmed] additionally highlights the target once a drag is currently
/// hovering inside its hit area — the same "about to drop here" affordance
/// `ZoneContainerBlock.isDropTarget` already gives Zone-view drag targets,
/// reused for consistency rather than inventing a second highlight
/// language for what is conceptually the same "you're about to drop on
/// me" signal.
class EditModeDeleteTarget extends StatelessWidget {
  const EditModeDeleteTarget({
    super.key,
    required this.theme,
    required this.visible,
    required this.isArmed,
    required this.targetKey,
  });

  final AmbleTheme theme;
  final bool visible;
  final bool isArmed;

  /// Attached to this widget's own hit-testable [Container] so the caller
  /// can resolve its on-screen bounds via `RenderBox.localToGlobal` at
  /// drop time — the same `GlobalKey`-based hit-test pattern
  /// `ZoneDayTimeline`'s `stackAncestorKey` already establishes for
  /// resolving a drag's drop position against a target it doesn't own.
  final GlobalKey targetKey;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // The target is a drop ZONE the caller hit-tests against directly
      // (via targetKey's RenderBox bounds compared to the drag's own
      // last-known position) rather than a widget that receives pointer
      // events itself — the drag gesture is already owned by the pill's
      // own GestureDetector for the whole gesture's lifetime, so this
      // never needs to intercept anything.
      ignoring: true,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: theme.motionFast,
        curve: theme.curveStandard,
        child: Container(
          key: targetKey,
          height: theme.spacingXl * 2,
          margin: EdgeInsets.all(theme.spacingMd),
          decoration: BoxDecoration(
            color: isArmed
                ? theme.colorTaskAlert
                : theme.colorTaskAlert.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(theme.radiusXl),
            border: Border.all(
              color: theme.colorTaskAlert,
              width: isArmed ? 0 : 2,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.delete_outline_rounded,
            color: isArmed ? theme.colorSurfacePrimary : theme.colorTaskAlert,
            size: theme.spacingXl,
          ),
        ),
      ),
    );
  }
}

/// Whether [globalPosition] falls within [targetKey]'s current on-screen
/// bounds — a pure geometry check, widget-free, so the drop decision in
/// `_DraggableTaskBlockState.onDragEnd` reads as "was the drop inside the
/// target" rather than reaching into rendering internals inline.
bool isInsideDeleteTarget(GlobalKey targetKey, Offset globalPosition) {
  final renderObject = targetKey.currentContext?.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.attached) return false;
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final bounds = topLeft & renderObject.size;
  return bounds.contains(globalPosition);
}
