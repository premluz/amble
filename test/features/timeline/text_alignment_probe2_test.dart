import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/zone_container_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';

/// Probe: measure each row's title offset-from-its-own-row-top
/// independently (zoned vs unzoned), to compare without a combined-layout
/// issue.
void main() {
  final theme = AmbleTheme.light;

  testWidgets('zoned row (_ZoneTaskRow)', (tester) async {
    final zone = Zone.create(
      title: 'Zone',
      startMinutes: 9 * 60,
      endMinutes: 10 * 60,
    );
    final zonedTask = Task.create(
      title: 'In zone',
      scheduledAt: DateTime(2026, 9, 15, 9),
      durationMinutes: 20,
      categoryId: BuiltInCategoryIds.work,
    );
    final stackKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: SizedBox(
            key: stackKey,
            width: 380,
            child: ZoneContainerBlock(
              theme: theme,
              zone: zone,
              tasks: [zonedTask],
              categoriesById: const {},
              stackAncestorKey: stackKey,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The task row's own SizedBox (zoneContainerRowHeight) — the CLOSEST
    // SizedBox ancestor of the title, not the ZoneContainerBlock's outer
    // bounds (which stretch to the Scaffold).
    final rowRect = tester.getRect(
      find
          .ancestor(of: find.text('In zone'), matching: find.byType(SizedBox))
          .first,
    );
    final titleRect = tester.getRect(find.text('In zone'));
    debugPrint('PROBE zoned rowHeight=${rowRect.height} '
        'titleOffsetFromRowTop=${titleRect.top - rowRect.top} '
        'titleHeight=${titleRect.height}');
  });

  testWidgets('unzoned row (TaskCapsuleBlock, compactText)', (tester) async {
    final unzonedTask = Task.create(
      title: 'Out of zone',
      scheduledAt: DateTime(2026, 9, 15, 11),
      durationMinutes: 20,
      categoryId: BuiltInCategoryIds.work,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            child: TaskCapsuleBlock(
              task: unzonedTask,
              durationIndicatedBySize: false,
              compactText: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowRect = tester.getRect(
      find.descendant(
        of: find.byType(TaskCapsuleBlock),
        matching: find.byType(IntrinsicHeight),
      ),
    );
    final titleRect = tester.getRect(
      find.textContaining('Out of zone', findRichText: true),
    );
    debugPrint('PROBE unzoned rowHeight=${rowRect.height} '
        'titleOffsetFromRowTop=${titleRect.top - rowRect.top} '
        'titleHeight=${titleRect.height}');
  });
}
