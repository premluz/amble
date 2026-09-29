import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_depth.dart';
import '../../core/widgets/app_press_feedback.dart';

/// One task as a list row: its pill, then its title (and an optional
/// trailing detail). The single card both the Inbox and voice mode draw, so
/// a task looks the same while it is being spoken, while it flies into the
/// Inbox, and once it is there. The pill and title take part in depth
/// emergence ([AppDepthShape], [AppDepthFade]) wherever that is running.
class TaskListRow extends StatelessWidget {
  const TaskListRow({
    super.key,
    required this.theme,
    required this.title,
    required this.pillColor,
    this.icon,
    this.iconColor,
    this.titleColor,
    this.trailing,
    this.onTap,
    this.onPillTap,
    this.pendingProgress,
  });

  final AmbleTheme theme;
  final String title;
  final Color pillColor;

  /// The category glyph; null for a task with no label yet.
  final IconData? icon;
  final Color? iconColor;

  /// Overrides the title's colour (e.g. a line still being spoken).
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onPillTap;

  /// 0..1 while the task is still being formed: a hairline traced just
  /// outside the pill's edge, filling as it completes. Null: none.
  final double? pendingProgress;

  @override
  Widget build(BuildContext context) {
    final badgeSize = theme.sizeTaskBadge;
    final radius = BorderRadius.circular(theme.radiusPill);
    final glyph = icon;
    Widget pill = Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(color: pillColor, borderRadius: radius),
      child: glyph == null
          ? null
          : Icon(
              glyph,
              size: badgeSize * TaskListRow.glyphShare,
              color: iconColor ?? theme.colorSurfacePrimary,
            ),
    );
    final pillTap = onPillTap;
    if (pillTap != null) {
      pill = AppPressFeedback(
        onTap: pillTap,
        borderRadius: radius,
        rippleColor: theme.colorSurfacePrimary,
        child: pill,
      );
    }
    final progress = pendingProgress;
    if (progress != null) {
      pill = CustomPaint(
        foregroundPainter: _PendingEdgePainter(
          progress: progress,
          color: theme.colorAccent,
          stroke: theme.borderWidthHairline,
          gap: theme.borderWidthHairline,
          radius: theme.radiusPill,
        ),
        child: pill,
      );
    }

    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacingSm),
      child: Row(
        children: [
          AppDepthShape(child: pill),
          SizedBox(width: theme.spacingSm),
          Expanded(
            child: AppDepthFade(
              child: Text(
                title,
                style: theme.textTaskTitle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (trailing case final detail?) ...[
            SizedBox(width: theme.spacingSm),
            AppDepthFade(child: detail),
          ],
        ],
      ),
    );
    final tap = onTap;
    return tap == null ? row : AppPressFeedback(onTap: tap, child: row);
  }

  /// The glyph's size as a share of the pill.
  static const glyphShare = .55;
}

/// A hairline tracing the pill's outline from the top, clockwise, just
/// outside its edge — a quiet "still forming" cue that never covers the
/// pill itself.
class _PendingEdgePainter extends CustomPainter {
  const _PendingEdgePainter({
    required this.progress,
    required this.color,
    required this.stroke,
    required this.gap,
    required this.radius,
  });

  final double progress;
  final Color color;
  final double stroke;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final share = progress.clamp(0.0, 1.0);
    if (share <= 0 || size.isEmpty) return;
    final outset = gap + stroke / 2;
    final rect = (Offset.zero & size).inflate(outset);
    final corner = math.min(radius + outset, rect.shortestSide / 2);
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(corner)));
    final metric = outline.computeMetrics().first;
    // An RRect path starts part-way along its top edge; start at the top
    // centre instead, so the trace reads as a clock hand.
    final topCentre = rect.width / 2 - corner;
    final length = metric.length;
    final traced = Path();
    final start = topCentre.clamp(0.0, length);
    final end = start + length * share;
    traced.addPath(
      metric.extractPath(start, math.min(end, length)),
      Offset.zero,
    );
    if (end > length) {
      traced.addPath(metric.extractPath(0, end - length), Offset.zero);
    }
    canvas.drawPath(
      traced,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_PendingEdgePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      stroke != oldDelegate.stroke ||
      gap != oldDelegate.gap ||
      radius != oldDelegate.radius;
}
