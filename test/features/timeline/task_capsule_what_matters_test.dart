import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

/// Covers `TaskCapsuleBlock.whatMattersFaded` — the Spatial (Task view)
/// half of the "What Matters" lens. Reported directly on the transition
/// this needs: "on spatial they just fade out," unlike the Zone/List
/// view's own fade-AND-reflow (`WhatMattersRow`, `zone_container_block.dart`)
/// — a spatial pill sits at a fixed time-axis position other pills must
/// NOT shift to fill, so this is fade-only, in place.
void main() {
  final task = Task.create(
    title: 'Deep work',
    scheduledAt: DateTime(2026, 9, 4, 9),
    durationMinutes: 90,
    categoryId: BuiltInCategoryIds.work,
  );

  Future<void> pump(WidgetTester tester, {required bool whatMattersFaded}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: TaskCapsuleBlock(
            task: task,
            whatMattersFaded: whatMattersFaded,
          ),
        ),
      ),
    );
  }

  testWidgets('whatMattersFaded false (default): the pill is fully '
      'opaque', (tester) async {
    await pump(tester, whatMattersFaded: false);

    final opacityWidget = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity).first,
    );
    expect(opacityWidget.opacity, 1.0);
  });

  testWidgets('whatMattersFaded true: the pill fades to 0 opacity but stays '
      'mounted, in place', (tester) async {
    await pump(tester, whatMattersFaded: true);

    final opacityWidget = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity).first,
    );
    expect(opacityWidget.opacity, 0.0);
    expect(
      find.text('Deep work'),
      findsOneWidget,
      reason:
          'the pill must stay mounted through the fade, not be '
          'removed outright',
    );
  });

  testWidgets('whatMattersFaded true: the pill is non-interactive', (
    tester,
  ) async {
    await pump(tester, whatMattersFaded: true);

    // Scoped to the outer IgnorePointer specifically — an ancestor of the
    // outer AnimatedOpacity — since the capsule's own internal machinery
    // (drag/resize handles) also uses IgnorePointer elsewhere in the
    // tree, and a bare `find.byType(...).first` can match one of those
    // instead, in whatever order the tree happens to traverse.
    final ignorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byType(AnimatedOpacity).first,
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignorePointer.ignoring, isTrue);
  });
}
