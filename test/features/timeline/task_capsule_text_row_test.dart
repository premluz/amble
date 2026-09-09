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
    bool compactInlineLayout = false,
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
            compactInlineLayout: compactInlineLayout,
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

  // Reported directly: List mode's individual (non-stacked) rows used a
  // different time/title layout than the stacked cluster rows —
  // unspaced dash ("4:00-5:00") plus a large fixed-column gap before the
  // title, instead of the cluster row's spaced dash and tight single-space
  // join. `compactInlineLayout` (wired from `_DraggableTaskBlock.compactText`
  // in timeline_screen.dart, so it's on in List mode and off in Task view)
  // makes this row match `OverlapClusterBlock`'s own inline format exactly.
  testWidgets(
    'compactInlineLayout renders a single spaced-dash time+title run, '
    'matching the stacked cluster row\'s own format — no fixed column gap',
    (tester) async {
      await pumpRow(
        tester,
        taskAt(4),
        compactInlineLayout: true,
        durationVisible: false,
        alwaysShowTime: true,
      );

      expect(find.text('4:00 AM - 5:00 AM  Stretching'), findsOneWidget);
      expect(find.textContaining('4:00 AM-5:00 AM'), findsNothing);
    },
  );

  testWidgets(
    'compactInlineLayout with durationVisible shows the (Xm) suffix inside '
    'the same inline run',
    (tester) async {
      await pumpRow(
        tester,
        taskAt(4),
        compactInlineLayout: true,
        durationVisible: true,
      );

      expect(find.text('4:00 AM - 5:00 AM (1h)  Stretching'), findsOneWidget);
    },
  );

  testWidgets(
    'compactInlineLayout: false (the default) keeps the original unspaced '
    'dash and fixed-column layout unchanged for Task view',
    (tester) async {
      await pumpRow(tester, taskAt(4));

      expect(find.textContaining('4:00 AM-5:00 AM'), findsOneWidget);
      expect(find.text('Stretching'), findsOneWidget);
    },
  );

  // The `isImportant` marker (see `Task.isImportant`) renders in the
  // margin BEFORE the title — requested directly: "just icon in front of
  // the task (with negative margin so the task name remains aligned with
  // all other tasks)". The alignment half is the load-bearing assertion:
  // a marker that shifted its own title would break the shared text
  // column every other row lines up against.
  testWidgets('isImportant renders a marker without moving the title — a '
      'marked and an unmarked task\'s titles start at the SAME x', (
    tester,
  ) async {
    // Measured off the RichText's own box rather than `find.text`: the
    // title is a nested TextSpan inside a parent span once the marker
    // exists, and `find.text` only matches a Text widget's own `data`.
    double titleX(WidgetTester tester) => tester
        .getTopLeft(
          find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().contains('Stretching'),
          ),
        )
        .dx;

    await pumpRow(tester, taskAt(4), durationVisible: false);
    final plainTitleX = titleX(tester);
    expect(find.byIcon(Icons.star_rounded), findsNothing);

    final important = taskAt(4)..isImportant = true;
    await pumpRow(tester, important, durationVisible: false);
    final markedTitleX = titleX(tester);

    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(
      markedTitleX,
      plainTitleX,
      reason:
          'the marker occupies zero layout width, so it must not displace '
          'the title it precedes',
    );
  });

  testWidgets('the marker also renders in List mode\'s inline layout, '
      'still without moving the title', (tester) async {
    final important = taskAt(4)..isImportant = true;
    await pumpRow(
      tester,
      important,
      compactInlineLayout: true,
      durationVisible: false,
      alwaysShowTime: true,
    );

    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
