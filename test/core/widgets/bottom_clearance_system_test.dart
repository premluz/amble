import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_floating_create_button.dart';
import 'package:amble/core/widgets/app_sheet.dart';
import 'package:amble/core/widgets/app_step_scaffold.dart';

void main() {
  final light = AmbleTheme.light;
  final dark = AmbleTheme.dark;

  test('bottom clearance is the same compact spacing in both themes', () {
    expect(light.spacingBottomClearance, light.spacingSm);
    expect(dark.spacingBottomClearance, dark.spacingSm);
    expect(light.spacingBottomClearance, dark.spacingBottomClearance);
  });

  testWidgets('AppSheet applies the shared bottom clearance', (tester) async {
    const bodyKey = ValueKey('sheet-body');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [light]),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => AppSheet.show<void>(
                  context: context,
                  builder: (_) =>
                      const SizedBox(key: bodyKey, width: 80, height: 80),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final sheetPadding = tester
        .widgetList<Padding>(
          find.ancestor(
            of: find.byKey(bodyKey),
            matching: find.byType(Padding),
          ),
        )
        .any(
          (padding) =>
              padding.padding.resolve(TextDirection.ltr).bottom ==
              light.spacingBottomClearance,
        );
    expect(sheetPadding, isTrue);
  });

  testWidgets('floating create button uses the shared safe-area clearance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [light]),
        home: Scaffold(
          body: Stack(children: [AppFloatingCreateButton(onPressed: () {})]),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Positioned &&
            widget.right == light.spacingMd &&
            widget.bottom == light.spacingBottomClearance,
      ),
      findsOneWidget,
    );
  });

  testWidgets('StepScaffold footer uses the shared safe-area clearance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [light]),
        home: StepScaffold(
          theme: light,
          headerColor: light.colorAccent,
          onBack: null,
          onClose: () {},
          primaryLabel: 'Done',
          onPrimaryPressed: () {},
          body: const SizedBox.expand(),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Positioned &&
            widget.left == 0 &&
            widget.right == 0 &&
            widget.bottom == light.spacingBottomClearance,
      ),
      findsOneWidget,
    );
  });
}
