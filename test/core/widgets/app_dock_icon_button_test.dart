import 'package:amble/core/tokens/floating_surface_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_dock_primitives.dart';
import 'package:amble/core/widgets/app_press_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The dock button's selected tint is the button's own fill, inside the
/// press, so the whole tinted circle swells when pressed — not just the
/// icon over a tint that stays put.
void main() {
  final theme = AmbleTheme.light;

  Future<void> pump(WidgetTester tester, {required bool selected}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: Center(
            child: AppDockIconButton(
              theme: theme,
              icon: Icons.edit_outlined,
              tooltip: 'Edit',
              selected: selected,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('selected tint is the button fill, inside the press', (
    tester,
  ) async {
    await pump(tester, selected: true);
    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.fillColor, FloatingSurfaceTokens.selected(theme));

    final tinted = find.descendant(
      of: find.byType(AppPressFeedback),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            (w.decoration as BoxDecoration?)?.color ==
                FloatingSurfaceTokens.selected(theme),
      ),
    );
    expect(tinted, findsOneWidget, reason: 'the tint swells with the press');
  });

  testWidgets('unselected has no fill', (tester) async {
    await pump(tester, selected: false);
    expect(tester.widget<AppButton>(find.byType(AppButton)).fillColor, isNull);
  });
}
