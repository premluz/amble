// SCAFFOLDING test — pumps the visual-review-only TimelineCapsulePreview and
// captures a screenshot for human review. Not a real screen test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/timeline_capsule_preview.dart';

void main() {
  testWidgets('renders 5 seeded tasks across all 4 category colors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: const Scaffold(body: TimelineCapsulePreview()),
      ),
    );

    expect(find.byType(TaskCapsuleBlock), findsNWidgets(5));
    expect(find.text('Morning run'), findsOneWidget);
    expect(find.text('Team standup'), findsOneWidget);
    expect(find.text('Deep work: Amble timeline'), findsOneWidget);
    expect(find.text('Call mom'), findsOneWidget);
    expect(find.text('Pay rent'), findsOneWidget);

    await expectLater(
      find.byType(TimelineCapsulePreview),
      matchesGoldenFile('timeline_capsule_preview.png'),
    );
  });
}
