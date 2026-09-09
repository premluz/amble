import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/edit_mode_delete_target.dart';

void main() {
  group('isInsideDeleteTarget', () {
    testWidgets('a position inside the target\'s on-screen bounds is inside', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(key: key, width: 200, height: 100),
            ),
          ),
        ),
      );

      final box = key.currentContext!.findRenderObject()! as RenderBox;
      final center = box.localToGlobal(box.size.center(Offset.zero));

      expect(isInsideDeleteTarget(key, center), isTrue);
    });

    testWidgets('a position outside the target\'s bounds is not inside', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(key: key, width: 200, height: 100),
            ),
          ),
        ),
      );

      expect(isInsideDeleteTarget(key, const Offset(5, 5)), isFalse);
    });

    testWidgets('a key with no attached render object (target not '
        'mounted/visible) is never inside', (tester) async {
      final key = GlobalKey();
      expect(isInsideDeleteTarget(key, const Offset(50, 50)), isFalse);
    });
  });

  group('EditModeDeleteTarget', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool visible,
      required bool isArmed,
    }) {
      final key = GlobalKey();
      return tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: EditModeDeleteTarget(
              theme: AmbleTheme.light,
              visible: visible,
              isArmed: isArmed,
              targetKey: key,
            ),
          ),
        ),
      );
    }

    testWidgets('is invisible to hit-testing even while fully opaque', (
      tester,
    ) async {
      await pump(tester, visible: true, isArmed: false);
      await tester.pump(const Duration(milliseconds: 200));

      final ignorePointer = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(EditModeDeleteTarget),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointer.ignoring, isTrue);
    });

    testWidgets('renders the delete icon', (tester) async {
      await pump(tester, visible: true, isArmed: false);

      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });
  });
}
