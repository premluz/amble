import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/task_state_tokens.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';

/// The one resolution of how a task's pill and title look for its state, so
/// every row that draws a task (Task/List pill, Zone view row, cluster row)
/// agrees: normal, important (brand title + star), done (pale fill, receding
/// title, distinct strike) and skipped.
class TaskStateStyle {
  const TaskStateStyle._({
    required this.fill,
    required this.titleColor,
    required this.isDone,
    required this.showStar,
    required this.strikeColor,
  });

  factory TaskStateStyle.resolve({
    required AmbleTheme theme,
    required Task task,
    required Color labelColor,
  }) {
    final isDone = task.status == TaskStatus.completed;
    final isSkipped = task.status == TaskStatus.skipped;
    return TaskStateStyle._(
      fill: isSkipped
          ? theme.colorTaskSkipped
          : isDone
          ? TaskStateTokens.doneFill(theme, labelColor)
          : labelColor,
      titleColor: isDone
          ? TaskStateTokens.doneTitle(theme)
          : task.isImportant
          ? TaskStateTokens.importantTitle(theme)
          : theme.colorTextPrimary,
      isDone: isDone,
      showStar: task.isImportant,
      strikeColor: TaskStateTokens.doneTitle(theme),
    );
  }

  /// The pill (or row badge) fill.
  final Color fill;
  final Color titleColor;
  final bool isDone;
  final bool showStar;
  final Color strikeColor;

  /// [base] with this state's title colour and, when done, the strike.
  TextStyle title(TextStyle base) => base.copyWith(
    color: titleColor,
    decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
    decorationColor: strikeColor,
    decorationThickness: isDone ? TaskStateTokens.doneStrikeThickness : null,
  );
}

/// The small star an important task carries on its pill's top-right corner.
/// Paint-only: it never takes layout space or pointer events.
class TaskImportantStar extends StatelessWidget {
  const TaskImportantStar({
    super.key,
    required this.theme,
    required this.pillWidth,
    this.faded = false,
  });

  final AmbleTheme theme;
  final double pillWidth;

  /// True on a done task: the star recedes with its title. Its outline (the
  /// surface-coloured separation from the pill) stays.
  final bool faded;

  double get size => pillWidth * TaskStateTokens.importantStarScale;
  double get outlineWidth => TaskStateTokens.importantStarOutlineWidth;
  double get frameSize => size + outlineWidth * 2;

  /// Where the star's top-left sits relative to the pill's top-left.
  Offset get cornerOffset => Offset(
    pillWidth -
        size * (1 - TaskStateTokens.importantStarOverhangX) -
        outlineWidth,
    -size * TaskStateTokens.importantStarOverhangY - outlineWidth,
  );

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.star_rounded,
            size: frameSize,
            color: theme.colorSurfaceBase,
          ),
          Opacity(
            opacity: faded ? TaskStateTokens.doneStarAlpha : 1,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: TaskStateTokens.importantStarGradient(theme),
              ).createShader(bounds),
              child: Icon(Icons.star_rounded, size: size),
            ),
          ),
        ],
      ),
    ),
  );
}
