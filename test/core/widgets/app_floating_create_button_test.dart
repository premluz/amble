import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_floating_create_button.dart';
import 'package:amble/core/widgets/app_icon_button.dart';

/// Replaces `AppBottomExtensionBar`'s own "+" (2026-09-12, requested
/// directly from a reference screenshot: "nav is just 5 items + its
/// outside") — the "+" is now an independently floating circle rather
/// than sharing a bar with the nav below it.
void main() {
  testWidgets('renders as a Positioned circle in the bottom-right corner '
      'of its Stack', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Stack(children: [AppFloatingCreateButton(onPressed: () {})]),
        ),
      ),
    );

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.right, isNotNull);
    expect(positioned.bottom, isNotNull);
    expect(
      positioned.left,
      isNull,
      reason: 'anchored from the right, not the left',
    );
    expect(find.byType(AppIconButton), findsOneWidget);
  });

  testWidgets('tapping invokes onPressed', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Stack(
            children: [
              AppFloatingCreateButton(onPressed: () => pressed = true),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppIconButton));
    expect(pressed, isTrue);
  });

  testWidgets('uses the add icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Stack(children: [AppFloatingCreateButton(onPressed: () {})]),
        ),
      ),
    );

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
