import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/pending_task_pill.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble_widgetbook/task_pill_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders each task-pill use case, so a layout break in a demo is caught
/// without opening Widgetbook.
Future<void> _render(WidgetTester tester, WidgetBuilder demo) async {
  // Tall enough that the lazy gallery list builds every state.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [AmbleTheme.light]),
      home: Scaffold(body: Builder(builder: demo)),
    ),
  );
  // Bounded: the draft pill wiggles forever.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('all states render', (tester) async {
    await _render(tester, taskPillGalleryDemo);
    expect(find.byType(TaskCapsuleBlock), findsNWidgets(7));
    expect(find.byType(PendingTaskPill), findsOneWidget);
    expect(find.text('Team sync'), findsOneWidget);
  });

  testWidgets('interactive pill selects and completes', (tester) async {
    await _render(tester, taskPillInteractiveDemo);
    await tester.tap(find.text('Tap me, then check me'));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft replays', (tester) async {
    await _render(tester, taskPillDraftDemo);
    await tester.tap(find.text('Drop again'));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byType(PendingTaskPill), findsOneWidget);
  });
}
