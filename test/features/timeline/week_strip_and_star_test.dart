import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/task_state_tokens.dart';
import 'package:amble/core/widgets/app_date_accordion.dart';
import 'package:amble/core/widgets/app_press_feedback.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/task_state_style.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
  home: Scaffold(body: child),
);

void main() {
  testWidgets("the Day week strip's days have no tap wash — the selected "
      'state answers the tap', (tester) async {
    await tester.pumpWidget(
      _host(
        AppDateAccordion(
          selectedDate: DateTime(2026, 9, 29),
          onDateSelected: (_) {},
          // The week strip is the accordion's open state.
          initiallyExpanded: true,
        ),
      ),
    );
    final days = tester
        .widgetList<AppPressFeedback>(find.byType(AppPressFeedback))
        .where((press) => !press.ripple);
    expect(days.length, 7, reason: 'all seven day pills, and only them');
  });

  Task important({required bool done}) {
    final task = Task.create(
      title: 'Ship it',
      scheduledAt: DateTime(2026, 9, 29, 9),
      durationMinutes: 60,
      categoryId: BuiltInCategoryIds.work,
      isImportant: true,
    );
    if (done) task.status = TaskStatus.completed;
    return task;
  }

  for (final done in [false, true]) {
    testWidgets('the important star is ${done ? '' : 'not '}faded when the '
        'task is ${done ? '' : 'not '}done', (tester) async {
      await tester.pumpWidget(
        _host(TaskCapsuleBlock(task: important(done: done))),
      );
      final star = tester.widget<TaskImportantStar>(
        find.byType(TaskImportantStar),
      );
      expect(star.faded, done);
      final opacity = tester
          .widget<Opacity>(
            find
                .descendant(
                  of: find.byType(TaskImportantStar),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(opacity, done ? TaskStateTokens.doneStarAlpha : 1);
    });
  }
}
