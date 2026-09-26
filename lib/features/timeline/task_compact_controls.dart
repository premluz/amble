import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import 'resize_handle.dart';

/// Keeps the resize dot on its true edge with an accessible action name.
class TaskCompactResizeCell extends StatelessWidget {
  const TaskCompactResizeCell({
    super.key,
    required this.theme,
    required this.label,
    required this.height,
    required this.alignment,
    required this.consumeTap,
    required this.onTap,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  final AmbleTheme theme;
  final String label;
  final double height;
  final Alignment alignment;
  final bool consumeTap;
  final VoidCallback? onTap;
  final GestureDragStartCallback? onStart;
  final GestureDragUpdateCallback? onUpdate;
  final GestureDragEndCallback? onEnd;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Resize task $label',
    button: true,
    onTap: onTap,
    child: ResizeHandle(
      theme: theme,
      height: height,
      barAlignment: alignment,
      onTap: consumeTap ? () {} : null,
      onDragStart: onStart,
      onDragUpdate: onUpdate,
      onDragEnd: onEnd,
      onDragCancel: onCancel,
    ),
  );
}
