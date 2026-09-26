import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_context_menu.dart';
import '../../core/widgets/app_sheet.dart';

/// The menu opened by releasing a hold-and-drag placement (see
/// `PlaceTaskLineLayer.onPlaced`) at [droppedAt] — requested directly:
/// "on release we have context menu showing from position of release,"
/// replacing the previous behavior of jumping straight into the full
/// `showTaskDetailSheet` create form.
///
/// Presented via [AppSheet], the same bottom-sheet primitive every other
/// menu in the app already uses (`showTaskActionSheet`) — confirmed via
/// AskUserQuestion over a genuinely new floating/anchored popup at the
/// release point, which would have needed its own positioning mechanism
/// this app has nowhere else.
///
/// Takes plain callbacks rather than reaching for `WidgetRef` itself —
/// [onMoveAll] and [onNewTask] are wired by the caller (`timeline_screen
/// .dart`'s own build, already Riverpod-aware) to `showMoveAllSheet` and
/// the same `pendingTaskDraftProvider.start` a plain empty-space tap
/// already uses, matching how every other field on `_DayTimeline` is a
/// callback rather than this widget owning its own `ref`.
Future<void> showPlaceTaskReleaseMenu(
  BuildContext context, {
  required DateTime droppedAt,
  required ValueChanged<DateTime> onMoveAll,
  required ValueChanged<DateTime> onNewTask,
}) {
  return AppSheet.show<void>(
    context: context,
    builder: (sheetContext) => _PlaceTaskReleaseMenuContent(
      droppedAt: droppedAt,
      onMoveAll: onMoveAll,
      onNewTask: onNewTask,
    ),
  );
}

class _PlaceTaskReleaseMenuContent extends StatelessWidget {
  const _PlaceTaskReleaseMenuContent({
    required this.droppedAt,
    required this.onMoveAll,
    required this.onNewTask,
  });

  final DateTime droppedAt;
  final ValueChanged<DateTime> onMoveAll;
  final ValueChanged<DateTime> onNewTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AppSheet's own outer padding no longer provides a top inset
        // (2026-09-23 — "top padding should be in header").
        SizedBox(height: theme.spacingLg),
        ActionRow(
          theme: theme,
          icon: Icons.swap_vert_rounded,
          label: 'Move all',
          onTap: () {
            Navigator.of(context).pop();
            onMoveAll(droppedAt);
          },
        ),
        ActionRow(
          theme: theme,
          icon: Icons.add_rounded,
          label: 'New task',
          onTap: () {
            Navigator.of(context).pop();
            onNewTask(droppedAt);
          },
        ),
      ],
    );
  }
}
