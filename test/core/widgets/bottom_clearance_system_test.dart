import 'package:amble/core/widgets/app_top_scroll_fade.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_floating_create_button.dart';
import 'package:amble/core/widgets/app_page_toolbar.dart';
import 'package:amble/features/inbox/voice_capture_toolbar.dart';
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

    // The clearance ends the sheet's SCROLL (content can run to the phone's
    // edge), under a bottom fade exactly that tall.
    final screenBottom = tester.getBottomLeft(find.byType(MaterialApp)).dy;
    expect(
      screenBottom - tester.getBottomLeft(find.byKey(bodyKey)).dy,
      SheetTokens.contentBottomInset(light),
    );
    final fade = tester.widget<AppTopScrollFade>(
      find.byWidgetPredicate((w) => w is AppTopScrollFade && w.fromBottom),
    );
    expect(fade.height, SheetTokens.contentBottomInset(light));
    expect(
      find.ancestor(
        of: find.byKey(bodyKey),
        matching: find.byType(SingleChildScrollView),
      ),
      findsWidgets,
    );
  });

  // Requested directly: "for toolbar make same side padding as from
  // bottom." Measured with a home-indicator inset, where the two used to
  // differ (16 at the side against 34 + 8 below).
  testWidgets('floating create button sits as far from the side as from the '
      'bottom', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [light]),
        home: Scaffold(
          body: Stack(children: [AppFloatingCreateButton(onPressed: () {})]),
        ),
      ),
    );

    final button = tester.getRect(
      find.descendant(
        of: find.byType(AppFloatingCreateButton),
        matching: find.byType(AppPageToolbarItem),
      ),
    );
    final side = 430 - button.right;
    final bottom = 932 - button.bottom;
    expect(bottom, 34 + light.spacingBottomClearance);
    expect(side, bottom);
    expect(
      side,
      DockTokens.edgeInset(light, const EdgeInsets.only(bottom: 34)),
    );
  });

  test('the voice toolbar keeps the same edge on both sides and below', () {
    const size = Size(430, 932);
    const padding = EdgeInsets.only(bottom: 34);
    final (:toolbar, :close) = voiceToolbarLayout(light, size, padding);
    final edge = size.height - close.bottom;
    expect(size.width - close.right, edge);
    expect(toolbar.left, edge);
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
