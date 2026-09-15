import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/zone_container_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';

/// Probe: measure the vertical center of the pill's own emoji vs the
/// vertical center of the title text, for a normal task and a very short
/// (5-15 min) one, to see exactly how far off "centered" the title
/// currently is and how that gap changes with pill height.
void main() {
  for (final durationMinutes in [10, 30, 90]) {
    testWidgets('duration=${durationMinutes}m', (tester) async {
      final theme = AmbleTheme.light;
      final task = Task.create(
        title: 'Deep work',
        scheduledAt: DateTime(2026, 9, 15, 9),
        durationMinutes: durationMinutes,
        categoryId: BuiltInCategoryIds.work,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(body: TaskCapsuleBlock(task: task)),
        ),
      );
      await tester.pumpAndSettle();

      final pillRect = tester.getRect(find.byType(AnimatedContainer).first);
      final titleRect = tester.getRect(find.text('Deep work'));
      // The emoji is the only Text descendant of the pill AnimatedContainer.
      final emojiFinder = find.descendant(
        of: find.byType(AnimatedContainer).first,
        matching: find.byType(Text),
      );
      final emojiRect = tester.getRect(emojiFinder.first);

      debugPrint('PROBE ${durationMinutes}m pill=$pillRect '
          'pillCenterY=${pillRect.center.dy}');
      debugPrint('PROBE ${durationMinutes}m emoji=$emojiRect '
          'emojiCenterY=${emojiRect.center.dy}');
      debugPrint('PROBE ${durationMinutes}m title=$titleRect '
          'titleCenterY=${titleRect.center.dy} '
          'titleTop=${titleRect.top} rowTop=${pillRect.top}');
      debugPrint('PROBE ${durationMinutes}m offsetFromEmojiCenter='
          '${titleRect.center.dy - emojiRect.center.dy}');
    });
  }

  // Direct comparison: the ACTUAL unzoned Zone-view row config
  // (durationIndicatedBySize: false, compactText: true) vs a zoned row's
  // own _ZoneTaskRow, both holding a short (20 min) task, to see whether
  // their titles land at the same height when placed side by side.
  testWidgets('unzoned row title vs zoned row title, same row height', (
    tester,
  ) async {
    final theme = AmbleTheme.light;
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
    final unzonedTask = Task.create(
      title: 'Out of zone',
      scheduledAt: DateTime(2026, 9, 15, 11),
      durationMinutes: 20,
      categoryId: BuiltInCategoryIds.work,
    );
    final stackKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
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
              SizedBox(
                width: 380,
                child: TaskCapsuleBlock(
                  task: unzonedTask,
                  durationIndicatedBySize: false,
                  compactText: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final zonedRowRect = tester.getRect(find.byType(ZoneContainerBlock));
    final zonedTitleRect = tester.getRect(find.text('In zone'));
    final unzonedRowRect = tester.getRect(find.byType(TaskCapsuleBlock));
    final unzonedTitleRect = tester.getRect(find.text('Out of zone'));

    debugPrint('PROBE zonedRow=$zonedRowRect zonedTitle=$zonedTitleRect '
        'titleOffsetFromRowTop=${zonedTitleRect.top - zonedRowRect.top}');
    debugPrint('PROBE unzonedRow=$unzonedRowRect '
        'unzonedTitle=$unzonedTitleRect '
        'titleOffsetFromRowTop=${unzonedTitleRect.top - unzonedRowRect.top}');
    debugPrint('PROBE zonedRowHeight=${zonedRowRect.height} '
        'unzonedRowHeight=${unzonedRowRect.height}');
  });
}
