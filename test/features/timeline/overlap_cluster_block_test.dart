import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/dev_config.dart' show TimelineTaskTextLayout;
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/completion_checkbox.dart';
import 'package:amble/features/timeline/overlap_cluster_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/services/overlap_cluster.dart';

// Regression test for a real bug, reported directly: "on clustterng task
// list sohuld have time in front in one line with name (inline is set in
// settigns) same as task not clutered ... this still see not in one lne".
// _ClusterTaskRow's compactText branch already exists and, read in
// isolation, produces one Row/Text.rich — this locks that behavior in with
// a real render rather than relying on code reading alone.
void main() {
  final tasks = [
    Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 9, 4, 9),
      durationMinutes: 90,
      categoryId: BuiltInCategoryIds.work,
    ),
    Task.create(
      title: 'Standup',
      scheduledAt: DateTime(2026, 9, 4, 9, 30),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.admin,
    ),
  ];
  final cluster = OverlapCluster(
    start: tasks.first.scheduledAt!,
    end: tasks.first.scheduledAt!.add(const Duration(minutes: 90)),
    blocks: tasks,
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool compactText,
    TimelineTaskTextLayout textLayout = TimelineTaskTextLayout.stacked,
    bool showCompletionCheckbox = true,
    bool durationVisible = true,
    bool alwaysShowTime = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: OverlapClusterBlock(
            cluster: cluster,
            compactText: compactText,
            textLayout: textLayout,
            showCompletionCheckbox: showCompletionCheckbox,
            durationVisible: durationVisible,
            alwaysShowTime: alwaysShowTime,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'compactText: true renders each row\'s time and title on ONE line '
    '(Text.rich, not a stacked Column of two Text widgets)',
    (tester) async {
      await pump(tester, compactText: true);

      // One Text.rich per task row — not title+time as two separate Text
      // widgets, which is what the stacked (Task view) layout renders.
      final texts = tester.widgetList<Text>(find.byType(Text));
      expect(texts.length, tasks.length);

      final combined = texts.map((t) => t.textSpan!.toPlainText()).join('|');
      expect(combined, contains('Deep work'));
      expect(combined, contains('Standup'));
      expect(combined, contains('9:00'));
      expect(combined, contains('9:30'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compactText: false (Task view) keeps the stacked title-then-time '
    'two-line layout',
    (tester) async {
      await pump(tester, compactText: false);

      // Title and time render as separate Text widgets in this mode — at
      // least 2 per row (title, time), not merged into one Text.rich.
      final texts = tester.widgetList<Text>(find.byType(Text));
      expect(texts.length, greaterThanOrEqualTo(tasks.length * 2));
      expect(tester.takeException(), isNull);
    },
  );

  // Reported directly: "clustered tasks (ok in list) in task view render in
  // 2 lines" — the dev inline layout toggle reached TaskCapsuleBlock but
  // never this block, so an ordinary capsule went inline while a clustered
  // row beside it stayed stacked.
  testWidgets(
    'textLayout: inline puts each row on ONE line even outside List mode',
    (tester) async {
      await pump(
        tester,
        compactText: false,
        textLayout: TimelineTaskTextLayout.inline,
      );

      final texts = tester.widgetList<Text>(find.byType(Text));
      expect(texts.length, tasks.length);
      final combined = texts.map((t) => t.textSpan!.toPlainText()).join('|');
      expect(combined, contains('Deep work'));
      expect(combined, contains('9:00'));
      expect(tester.takeException(), isNull);
    },
  );

  // Corrected directly: "cluster mode time from-to should also react to
  // setting so not showing if disabled." The setting previously dropped
  // only the `(1h)` suffix here, leaving "04:00 - 05:00" on a clustered
  // row while an ordinary capsule beside it showed no time at all.
  testWidgets('durationVisible: false hides the whole time range, not just the '
      '(duration) suffix — stacked layout', (tester) async {
    await pump(tester, compactText: false);
    expect(find.textContaining('9:00'), findsWidgets);

    await pump(tester, compactText: false, durationVisible: false);
    expect(find.textContaining('9:00'), findsNothing);
    expect(find.textContaining('1h'), findsNothing);
    // The titles are still there — only the time went away.
    expect(find.text('Deep work'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'durationVisible: false hides the time in the inline layout too',
    (tester) async {
      await pump(tester, compactText: true, durationVisible: false);

      final texts = tester.widgetList<Text>(find.byType(Text));
      final combined = texts.map((t) => t.textSpan!.toPlainText()).join('|');
      expect(combined, contains('Deep work'));
      expect(combined, isNot(contains('9:00')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('showCompletionCheckbox: false removes every row\'s checkbox', (
    tester,
  ) async {
    await pump(tester, compactText: false);
    expect(find.byType(CompletionCheckbox), findsNWidgets(tasks.length));

    await pump(tester, compactText: false, showCompletionCheckbox: false);
    expect(find.byType(CompletionCheckbox), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Regression test for a real bug, reported directly from a List-mode
  // screenshot: a clustered task's row showed its title but NO time at
  // all, because `durationVisible` (driven by a dev toggle that defaults
  // off) hides the whole time range, not just the `(45m)` suffix — see the
  // two tests above. List mode has no timeline axis at all, so the time
  // is the only place a clustered task's schedule reads — matching
  // TaskCapsuleTextRow.alwaysShowTime's identical fix for the
  // non-clustered row.
  testWidgets(
    'alwaysShowTime keeps the time range visible even when durationVisible '
    'is false — the (Xm) suffix alone stays hidden',
    (tester) async {
      await pump(
        tester,
        compactText: true,
        durationVisible: false,
        alwaysShowTime: true,
      );

      final texts = tester.widgetList<Text>(find.byType(Text));
      final combined = texts.map((t) => t.textSpan!.toPlainText()).join('|');
      expect(combined, contains('9:00'));
      expect(combined, isNot(contains('1h')));
      expect(combined, contains('Deep work'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'alwaysShowTime: false (the default) keeps durationVisible\'s existing '
    '"hide both together" behavior unchanged',
    (tester) async {
      await pump(tester, compactText: true, durationVisible: false);

      final texts = tester.widgetList<Text>(find.byType(Text));
      final combined = texts.map((t) => t.textSpan!.toPlainText()).join('|');
      expect(combined, isNot(contains('9:00')));
    },
  );

  // Reported directly: "the imported tasks should also stack in the same
  // way as native tasks... They just can't be moved, changed, or have
  // their duration, time, or name updated, but otherwise exactly the
  // same, with different styling." A cluster can now mix a real task and
  // an imported event; this covers that the event's row renders (title +
  // time, same shape) but stays read-only.
  group('a cluster mixing a task and an external event (2026-09-07)', () {
    final task = Task.create(
      title: 'Standup',
      scheduledAt: DateTime(2026, 9, 4, 9),
      durationMinutes: 60,
      categoryId: BuiltInCategoryIds.work,
    );
    final event = ExternalCalendarEvent(
      id: 'evt-1',
      title: 'Dentist',
      start: DateTime(2026, 9, 4, 9, 30),
      end: DateTime(2026, 9, 4, 10, 30),
      sourceCalendarId: 'cal-1',
    );
    final mixedCluster = OverlapCluster(
      start: task.scheduledAt!,
      end: event.end,
      blocks: [task, event],
    );

    Future<void> pumpMixed(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(body: OverlapClusterBlock(cluster: mixedCluster)),
      ),
    );

    testWidgets('both the task title and the event title render', (
      tester,
    ) async {
      await pumpMixed(tester);

      expect(find.text('Standup'), findsOneWidget);
      expect(find.text('Dentist'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the event row has no completion checkbox — only the task row does',
      (tester) async {
        await pumpMixed(tester);

        expect(find.byType(CompletionCheckbox), findsOneWidget);
      },
    );

    testWidgets('tapping the event row does not fire onTaskTap (it opens the '
        'read-only info sheet instead)', (tester) async {
      Task? tapped;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: OverlapClusterBlock(
              cluster: mixedCluster,
              onTaskTap: (t) => tapped = t,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Dentist'));
      await tester.pumpAndSettle();

      expect(tapped, isNull);
      // The read-only info sheet opened instead — its own title text
      // now appears a second time (once on the row behind it, once in
      // the sheet).
      expect(find.text('Dentist'), findsNWidgets(2));
    });
  });
}
