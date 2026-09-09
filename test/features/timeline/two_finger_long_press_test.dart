import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/two_finger_long_press.dart';

void main() {
  Future<void> pump(WidgetTester tester, VoidCallback onFired) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwoFingerLongPress(
            onTwoFingerLongPress: onFired,
            child: Container(color: Colors.white),
          ),
        ),
      ),
    );
  }

  testWidgets('two fingers held for 400ms fires the callback', (tester) async {
    var fired = false;
    await pump(tester, () => fired = true);

    final gesture1 = await tester.createGesture();
    final gesture2 = await tester.createGesture();
    await gesture1.down(const Offset(100, 100));
    await gesture2.down(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 401));

    expect(fired, isTrue);

    await gesture1.up();
    await gesture2.up();
  });

  testWidgets('a single finger never fires it, no matter how long it holds', (
    tester,
  ) async {
    var fired = false;
    await pump(tester, () => fired = true);

    final gesture = await tester.createGesture();
    await gesture.down(const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(fired, isFalse);

    await gesture.up();
  });

  testWidgets('a third finger joining before 400ms cancels it', (tester) async {
    var fired = false;
    await pump(tester, () => fired = true);

    final gesture1 = await tester.createGesture();
    final gesture2 = await tester.createGesture();
    final gesture3 = await tester.createGesture();
    await gesture1.down(const Offset(100, 100));
    await gesture2.down(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture3.down(const Offset(300, 300));
    await tester.pump(const Duration(milliseconds: 400));

    expect(fired, isFalse);

    await gesture1.up();
    await gesture2.up();
    await gesture3.up();
  });

  testWidgets('one of the two fingers lifting before 400ms cancels it', (
    tester,
  ) async {
    var fired = false;
    await pump(tester, () => fired = true);

    final gesture1 = await tester.createGesture();
    final gesture2 = await tester.createGesture();
    await gesture1.down(const Offset(100, 100));
    await gesture2.down(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture2.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(fired, isFalse);

    await gesture1.up();
  });

  testWidgets('a pointer moving past the threshold cancels it', (tester) async {
    var fired = false;
    await pump(tester, () => fired = true);

    final gesture1 = await tester.createGesture();
    final gesture2 = await tester.createGesture();
    await gesture1.down(const Offset(100, 100));
    await gesture2.down(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 50));
    // Well past the 12px threshold.
    await gesture1.moveTo(const Offset(100, 160));
    await tester.pump(const Duration(milliseconds: 400));

    expect(fired, isFalse);

    await gesture1.up();
    await gesture2.up();
  });

  testWidgets('a single-finger tap still reaches the child underneath — the '
      'gesture is passive and never intercepts a one-finger interaction', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwoFingerLongPress(
            onTwoFingerLongPress: () {},
            child: GestureDetector(
              onTap: () => tapped = true,
              child: Container(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Container));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
