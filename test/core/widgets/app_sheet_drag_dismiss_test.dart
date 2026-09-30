import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_sheet.dart';
import 'package:amble/core/widgets/app_sheet_drag_dismiss.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final theme = AmbleTheme.light;

  Future<void> open(WidgetTester tester, {bool canPop = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: Builder(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () => AppSheet.show<void>(
                context: context,
                builder: (_) => PopScope(
                  canPop: canPop,
                  child: const SizedBox(height: 240, child: Text('Sheet body')),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsOneWidget);
  }

  double offset(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(AppSheetDragDismiss),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .getTranslation()
      .y;

  testWidgets('dragging the sheet body down far enough closes it', (
    tester,
  ) async {
    await open(tester);
    await tester.drag(find.text('Sheet body'), const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsNothing);
  });

  testWidgets('the sheet follows the finger, and a short drag settles back', (
    tester,
  ) async {
    await open(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Sheet body')),
    );
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(offset(tester), greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsOneWidget);
    expect(offset(tester), 0);
  });

  testWidgets('a PopScope that refuses keeps the sheet and eases it back', (
    tester,
  ) async {
    await open(tester, canPop: false);
    await tester.drag(find.text('Sheet body'), const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsOneWidget);
    expect(offset(tester), 0);
  });

  Future<void> openScrolling(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: Builder(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () => AppSheet.show<void>(
                context: context,
                size: AppSheetSize.half,
                builder: (_) => Column(
                  children: [
                    for (var i = 0; i < 40; i++)
                      SizedBox(height: 48, child: Text('Row $i')),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('scrolled content pulled down past its top closes the sheet', (
    tester,
  ) async {
    await openScrolling(tester);
    await tester.drag(find.text('Row 2'), const Offset(0, 220));
    await tester.pumpAndSettle();
    expect(find.text('Row 2'), findsNothing);
  });

  testWidgets('scrolled content scrolls first, and a short pull settles', (
    tester,
  ) async {
    await openScrolling(tester);
    await tester.drag(find.text('Row 4'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(find.text('Row 0').hitTestable(), findsNothing);
    // Back to the top, then a short pull: the sheet stays.
    await tester.drag(find.text('Row 6'), const Offset(0, 190));
    await tester.pumpAndSettle();
    expect(find.text('Row 6'), findsOneWidget);
    expect(offset(tester), 0);
  });

  testWidgets('tapping the scrim closes the sheet', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsNothing);
  });

  testWidgets('a scrim tap still asks a refusing PopScope', (tester) async {
    await open(tester, canPop: false);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsOneWidget);
  });
}
