import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_bubble_burst.dart';
import 'package:amble/core/widgets/app_swipe_actions.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/zone_container_block.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final zoned in [false, true]) {
    for (final completed in [false, true]) {
      testWidgets(
        'swipe completion bubbles zoned=$zoned completed=$completed',
        (tester) async {
          final task = Task.create(
            title: 'Focus',
            categoryId: BuiltInCategoryIds.work,
            scheduledAt: DateTime(2026, 9, 27, 10),
            durationMinutes: 60,
          );
          if (completed) task.status = TaskStatus.completed;
          final stackKey = GlobalKey();
          var toggles = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(extensions: [AmbleTheme.light]),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(60),
                  child: SizedBox(
                    key: stackKey,
                    width: 300,
                    child: zoned
                        ? ZoneContainerBlock(
                            theme: AmbleTheme.light,
                            zone: Zone.create(
                              title: 'Work',
                              startMinutes: 540,
                              endMinutes: 720,
                            ),
                            tasks: [task],
                            categoriesById: const {},
                            stackAncestorKey: stackKey,
                            onToggleComplete: (_) => toggles++,
                          )
                        : TaskCapsuleBlock(
                            task: task,
                            onToggleComplete: () => toggles++,
                          ),
                  ),
                ),
              ),
            ),
          );
          final swipe = find.byType(AppSwipeActions);
          final origin =
              tester.getTopLeft(swipe) +
              Offset(
                AmbleTheme.light.sizeTaskBadge / 2,
                zoned
                    ? (zoneContainerRowHeight -
                              AmbleTheme.light.sizeTaskBadge) /
                          2
                    : 0,
              );
          await tester.drag(swipe, const Offset(-250, 0));
          await tester.pump();
          expect(toggles, 1);
          expect(
            find.byType(BubbleBurstEffect),
            completed ? findsNothing : findsOneWidget,
          );
          if (!completed) {
            expect(
              tester
                  .widget<BubbleBurstEffect>(find.byType(BubbleBurstEffect))
                  .origin,
              origin,
            );
          }
          await tester.pumpAndSettle();
          expect(find.byType(BubbleBurstEffect), findsNothing);
        },
      );
    }
  }
}
