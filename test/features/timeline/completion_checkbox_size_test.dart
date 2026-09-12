import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/completion_checkbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reported directly: "size of checkbox to 18px from 20."
///
/// The visible ring is deliberately a plain literal (18.0), not a shared
/// spacing token — `theme.spacingLg` (24px) is still used elsewhere for
/// unrelated layout, so reusing it here would tie the checkbox's own
/// design decision to that scale's other consumers.
void main() {
  Future<void> pumpCheckbox(WidgetTester tester, {bool isCompleted = false}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Center(
            child: CompletionCheckbox(
              theme: AmbleTheme.light,
              isCompleted: isCompleted,
              onToggle: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the visible ring is 18px, not the old 24px', (tester) async {
    await pumpCheckbox(tester);

    // The ring is the Container directly inside CompletionCheckbox's own
    // AnimatedBuilder — found by its BoxDecoration shape, since the outer
    // SizedBox (the 48px tap target) is also present in the same tree.
    final ringContainer = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere(
          (c) => (c.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        );

    expect(ringContainer.constraints?.maxWidth, 18.0);
    expect(ringContainer.constraints?.maxHeight, 18.0);
  });

  testWidgets('the 48px tap target is unaffected by the ring shrinking', (
    tester,
  ) async {
    await pumpCheckbox(tester);

    final tapTarget = tester.getSize(find.byType(CompletionCheckbox));
    expect(tapTarget.width, AmbleTheme.light.spacingMinTapTarget);
    expect(tapTarget.height, AmbleTheme.light.spacingMinTapTarget);
  });

  testWidgets('the checkmark icon still scales with the smaller ring', (
    tester,
  ) async {
    await pumpCheckbox(tester, isCompleted: true);

    final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    // ringDiameter * 0.7, same proportion as before — just against the
    // new 18px ring instead of the old 24px one.
    expect(icon.size, closeTo(18.0 * 0.7, 0.01));
  });
}
