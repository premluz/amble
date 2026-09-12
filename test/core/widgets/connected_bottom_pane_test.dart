import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_bottom_extension_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reported directly: "this should be connected visually as one connected
/// pane, no gap between also spatially to compact" and "no bottom margin."
///
/// The extension bar (day strip / tab switcher / "+") and the bottom nav
/// are two separate widgets in two separate places — this pins the
/// properties that make them read as a single object, since nothing else
/// in the tree enforces that relationship.
void main() {
  Future<void> pumpBar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              AppBottomExtensionBar(
                leading: const SizedBox(height: 40),
                onCreatePressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the extension pane leaves no gap below itself', (tester) async {
    await pumpBar(tester);

    final padding = tester.widget<Padding>(
      find
          .descendant(
            of: find.byType(AppBottomExtensionBar),
            matching: find.byType(Padding),
          )
          .first,
    );
    final insets = padding.padding.resolve(TextDirection.ltr);

    // A bottom inset here is exactly the gap that made the two halves read
    // as two stacked pills rather than one pane.
    expect(insets.bottom, 0.0);
    expect(
      insets.left,
      insets.right,
      reason: 'side insets must match the nav below',
    );
  });

  testWidgets('the extension pane rounds only its TOP corners', (tester) async {
    await pumpBar(tester);

    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppBottomExtensionBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = decorated.decoration as BoxDecoration;
    final radius = decoration.borderRadius!.resolve(TextDirection.ltr);

    // Square bottom corners are what let this pane meet the nav on a
    // shared seam instead of curving away from it.
    expect(radius.bottomLeft, Radius.zero);
    expect(radius.bottomRight, Radius.zero);
    expect(radius.topLeft, isNot(Radius.zero));
  });

  testWidgets('the extension pane casts no shadow onto the nav below it', (
    tester,
  ) async {
    await pumpBar(tester);

    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppBottomExtensionBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = decorated.decoration as BoxDecoration;

    // `shadowPane` offsets downward, so a shadow here would paint a seam
    // across the middle of the combined pane.
    expect(decoration.boxShadow, anyOf(isNull, isEmpty));
  });

  testWidgets('the pane has no border in either theme', (tester) async {
    for (final theme in [AmbleTheme.light, AmbleTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                AppBottomExtensionBar(
                  leading: const SizedBox(height: 40),
                  onCreatePressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final decorated = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppBottomExtensionBar),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (decorated.decoration as BoxDecoration).border,
        isNull,
        reason: 'borders were removed from both halves by direct request',
      );
    }
  });
}
