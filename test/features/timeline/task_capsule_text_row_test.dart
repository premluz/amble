import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/completion_checkbox.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

/// The Spatial Task View's split layout — pill and text positioned
/// independently so every task's NAME starts at the same x regardless of
/// its overlap lane. Requested directly ("all task names are lined up even
/// those not stacked").
void main() {
  Task taskAt(int hour, {String title = 'Stretching'}) => Task.create(
    title: title,
    scheduledAt: DateTime(2026, 9, 4, hour),
    durationMinutes: 60,
    categoryId: BuiltInCategoryIds.health,
  );

  Future<void> pumpRow(
    WidgetTester tester,
    Task task, {
    bool durationVisible = true,
    bool alwaysShowTime = false,
    bool showCompletionCheckbox = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: TaskCapsuleTextRow(
            task: task,
            timeColumnWidth: taskTimeColumnWidth(AmbleTheme.light),
            durationColumnWidth: taskDurationColumnWidth(AmbleTheme.light),
            durationVisible: durationVisible,
            alwaysShowTime: alwaysShowTime,
            showCompletionCheckbox: showCompletionCheckbox,
          ),
        ),
      ),
    );
  }

  testWidgets('renders time, duration and title as three columns', (
    tester,
  ) async {
    await pumpRow(tester, taskAt(4));

    expect(find.textContaining('4:00'), findsOneWidget);
    expect(find.text('1h'), findsOneWidget);
    expect(find.text('Stretching'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the title starts at the SAME x regardless of how long the time text '
    'is — the fixed time/duration columns are what align the names',
    (tester) async {
      // 4:00-5:00 vs 11:00-12:00: different rendered time-string widths.
      await pumpRow(tester, taskAt(4));
      final earlyTitleX = tester.getTopLeft(find.text('Stretching')).dx;

      await pumpRow(tester, taskAt(11));
      final lateTitleX = tester.getTopLeft(find.text('Stretching')).dx;

      expect(lateTitleX, earlyTitleX);
    },
  );

  testWidgets(
    'durationVisible: false drops BOTH leading columns and the title takes '
    'the row — the mock\'s left-hand screen',
    (tester) async {
      await pumpRow(tester, taskAt(4));
      final withTimeX = tester.getTopLeft(find.text('Stretching')).dx;

      await pumpRow(tester, taskAt(4), durationVisible: false);
      final withoutTimeX = tester.getTopLeft(find.text('Stretching')).dx;

      expect(find.textContaining('4:00'), findsNothing);
      expect(find.text('1h'), findsNothing);
      expect(withoutTimeX, lessThan(withTimeX));
    },
  );

  testWidgets('showCompletionCheckbox: false removes the checkbox', (
    tester,
  ) async {
    await pumpRow(tester, taskAt(4));
    expect(find.byType(CompletionCheckbox), findsOneWidget);

    await pumpRow(tester, taskAt(4), showCompletionCheckbox: false);
    expect(find.byType(CompletionCheckbox), findsNothing);
  });

  // Regression test for a real bug, reported directly from List mode: with
  // `durationVisible: false` (the current default dev-toggle value —
  // DevTimelineTaskDurationVisible defaults off), the time text disappeared
  // ENTIRELY in List mode's own split layout, since List mode has no
  // timeline axis and the shared text column is the only place time can
  // read at all. `alwaysShowTime` (List-mode-only, wired from
  // `_DraggableTaskBlock.compactText` in timeline_screen.dart) forces the
  // time column back on regardless of `durationVisible` — the duration
  // SUFFIX stays independently controlled by `durationVisible` alone.
  testWidgets('alwaysShowTime keeps the time column visible even when '
      'durationVisible is false — only the (Xm) suffix stays hidden', (
    tester,
  ) async {
    await pumpRow(
      tester,
      taskAt(4),
      durationVisible: false,
      alwaysShowTime: true,
    );

    expect(find.textContaining('4:00'), findsOneWidget);
    expect(find.text('1h'), findsNothing);
    expect(find.text('Stretching'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alwaysShowTime: false (the default) keeps durationVisible\'s '
      'existing "hide both together" behavior unchanged — Task view\'s own '
      'split layout must not be affected by this List-mode addition', (
    tester,
  ) async {
    await pumpRow(tester, taskAt(4), durationVisible: false);

    expect(find.textContaining('4:00'), findsNothing);
    expect(find.text('1h'), findsNothing);
  });
}
