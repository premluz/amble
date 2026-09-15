import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/resize_handle.dart';

/// Requested directly: "the resize controls should be small blue circles
/// in the center on both ends, at the moment is line, instead in the same
/// position circle/oval centered."
void main() {
  final theme = AmbleTheme.light;

  Future<void> pump(WidgetTester tester, {Alignment? barAlignment}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: ResizeHandle(
            theme: theme,
            onDragStart: (_) {},
            onDragUpdate: (_) {},
            onDragEnd: (_) {},
            barAlignment: barAlignment ?? Alignment.center,
          ),
        ),
      ),
    );
  }

  testWidgets('the visible handle is a circle, not a bar', (tester) async {
    await pump(tester);

    final decoration =
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.shape == BoxShape.circle);

    expect(decoration.shape, BoxShape.circle);
    expect(
      decoration.borderRadius,
      isNull,
      reason: 'a circle uses BoxShape.circle, not a rounded rect — the old '
          'bar used borderRadius instead',
    );
  });

  testWidgets('the handle is accent-colored, not the old grey', (
    tester,
  ) async {
    await pump(tester);

    final decoration =
        tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.shape == BoxShape.circle);

    expect(
      decoration.color,
      theme.colorAccent,
      reason: 'matches the selection border\'s own accent color, so the '
          'two read as one consistent "editable" visual language',
    );
  });

  testWidgets('the circle sits centered at the SAME position the old bar '
      'did — pinned to barAlignment, not the handle\'s geometric middle', (
    tester,
  ) async {
    await pump(tester, barAlignment: Alignment.topCenter);

    final handleRect = tester.getRect(find.byType(ResizeHandle));
    final circleRect = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is Container && (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      ),
    );

    expect(
      circleRect.center.dy,
      closeTo(handleRect.top + circleRect.height / 2, 0.5),
      reason: 'topCenter alignment must still pin the visible dot to the '
          'handle\'s OUTER edge, same contract the bar had',
    );
    expect(
      circleRect.center.dx,
      closeTo(handleRect.center.dx, 0.5),
      reason: 'horizontally centered regardless of vertical alignment',
    );
  });

  testWidgets('the circle is small — a subtle dot, not a large control', (
    tester,
  ) async {
    await pump(tester);

    final circleRect = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is Container && (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      ),
    );

    expect(circleRect.width, theme.spacingSm);
    expect(circleRect.height, theme.spacingSm);
    expect(circleRect.width, circleRect.height, reason: 'a circle, not an oval, at this size');
  });
}
