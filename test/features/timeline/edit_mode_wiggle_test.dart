import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/edit_mode_wiggle.dart';

void main() {
  Transform rotationOf(WidgetTester tester) =>
      tester.widget<Transform>(find.byType(Transform));

  testWidgets('renders zero rotation when disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: EditModeWiggle(enabled: false, child: Text('x'))),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(rotationOf(tester).transform.getRotation()[0], 1.0);
  });

  testWidgets('rotates away from zero once enabled and time passes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EditModeWiggle(enabled: true, child: Text('x'))),
    );
    // Let the oscillation run a partial cycle — not exactly zero or a
    // multiple of the cycle, so the sine curve is guaranteed non-zero.
    await tester.pump(const Duration(milliseconds: 60));

    final matrix = rotationOf(tester).transform;
    // A rotation matrix's [0] entry is cos(angle) — 1.0 only at angle 0.
    expect(matrix[0], isNot(1.0));
  });

  testWidgets('two blocks with different phase offsets are NOT at the '
      'same rotation at the same moment', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            EditModeWiggle(enabled: true, phaseOffset: 0, child: Text('a')),
            EditModeWiggle(enabled: true, phaseOffset: 0.3, child: Text('b')),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));

    final transforms = tester
        .widgetList<Transform>(find.byType(Transform))
        .toList();
    expect(transforms, hasLength(2));
    expect(transforms[0].transform[0], isNot(transforms[1].transform[0]));
  });

  testWidgets('toggling enabled off eases rotation back toward zero, '
      'without remounting the child', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: EditModeWiggle(enabled: true, child: Text('x', key: key)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    final elementBefore = tester.element(find.byKey(key));

    await tester.pumpWidget(
      MaterialApp(
        home: EditModeWiggle(enabled: false, child: Text('x', key: key)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 260));

    expect(tester.element(find.byKey(key)), same(elementBefore));
    expect(rotationOf(tester).transform.getRotation()[0], 1.0);
  });
}
