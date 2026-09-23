import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_option_switch_option.dart';
import 'package:amble/core/widgets/app_tab_switch.dart';

/// Generalizes the previously-private, 2-option-only `_TabSwitcher`/
/// `_Segment` (zone_grid_screen.dart) into a reusable, arbitrary-length
/// primitive — see app_tab_switch.dart's own doc comment.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Scaffold(body: child),
    ),
  );

  const options = [
    AppOptionSwitchOption(value: 'all', label: 'All'),
    AppOptionSwitchOption(value: 'crypto', label: 'Crypto'),
    AppOptionSwitchOption(value: 'stocks', label: 'Stocks'),
  ];

  testWidgets('renders every option label', (tester) async {
    await pump(
      tester,
      AppTabSwitch<String>(options: options, value: 'all', onChanged: (_) {}),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Crypto'), findsOneWidget);
    expect(find.text('Stocks'), findsOneWidget);
  });

  testWidgets('tapping an unselected option calls onChanged with its value', (
    tester,
  ) async {
    String? changedTo;
    await pump(
      tester,
      AppTabSwitch<String>(
        options: options,
        value: 'all',
        onChanged: (value) => changedTo = value,
      ),
    );

    await tester.tap(find.text('Crypto'));
    expect(changedTo, 'crypto');
  });

  testWidgets('neither the selected nor unselected segment is bold — '
      'distinguished by fill/color, not weight (2026-09-19 refinement)', (
    tester,
  ) async {
    await pump(
      tester,
      AppTabSwitch<String>(
        options: options,
        value: 'crypto',
        onChanged: (_) {},
      ),
    );

    final selectedText = tester.widget<Text>(find.text('Crypto'));
    final unselectedText = tester.widget<Text>(find.text('All'));

    expect(selectedText.style!.fontWeight, FontWeight.w500);
    expect(unselectedText.style!.fontWeight, FontWeight.w500);
  });

  testWidgets('primary variant highlights the selected segment with the '
      'accent fill', (tester) async {
    final theme = AmbleTheme.light;
    await pump(
      tester,
      AppTabSwitch<String>(
        options: options,
        value: 'all',
        onChanged: (_) {},
      ),
    );

    final selectedText = tester.widget<Text>(find.text('All'));
    expect(selectedText.style!.color, theme.colorSurfacePrimary);
  });

  testWidgets('ghost variant has no track fill', (tester) async {
    await pump(
      tester,
      AppTabSwitch<String>(
        options: options,
        value: 'all',
        variant: AppButtonVariant.ghost,
        onChanged: (_) {},
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.byType(DecoratedBox).first,
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    expect(decoration.color, isNull);
  });

  // **2026-09-21 — scrolls when the option list overflows.** Added for
  // the Inbox's own Section tabs (an open-ended, user-created list) — see
  // this widget's own class doc comment.
  group('horizontal scroll (2026-09-21)', () {
    testWidgets(
      'the short 3-option list (existing caller shape) does NOT scroll — '
      'no SingleChildScrollView, segments still fill the track',
      (tester) async {
        await pump(
          tester,
          SizedBox(
            width: 400,
            child: AppTabSwitch<String>(
              options: options,
              value: 'all',
              onChanged: (_) {},
            ),
          ),
        );

        expect(find.byType(SingleChildScrollView), findsNothing);
      },
    );

    testWidgets(
      'many long-labelled options that overflow the available width DO '
      'scroll horizontally',
      (tester) async {
        final manyOptions = [
          for (var i = 0; i < 20; i++)
            AppOptionSwitchOption(
              value: 'option-$i',
              label: 'A fairly long option label $i',
            ),
        ];

        await pump(
          tester,
          SizedBox(
            width: 300,
            child: AppTabSwitch<String>(
              options: manyOptions,
              value: 'option-0',
              onChanged: (_) {},
            ),
          ),
        );

        expect(find.byType(SingleChildScrollView), findsOneWidget);
        // Every label is still in the tree (scrollable, not clipped away)
        // — confirms this is genuine horizontal scroll, not truncation.
        expect(find.text('A fairly long option label 19'), findsOneWidget);
      },
    );

    testWidgets(
      'a caller-supplied segmentKey resolves to that option\'s own '
      'rendered segment',
      (tester) async {
        final key = GlobalKey();
        await pump(
          tester,
          AppTabSwitch<String>(
            options: [
              AppOptionSwitchOption(
                value: 'all',
                label: 'All',
                segmentKey: key,
              ),
              const AppOptionSwitchOption(value: 'crypto', label: 'Crypto'),
            ],
            value: 'all',
            onChanged: (_) {},
          ),
        );

        expect(key.currentContext, isNotNull);
      },
    );

    testWidgets('isDropTarget paints a border over the segment', (
      tester,
    ) async {
      await pump(
        tester,
        AppTabSwitch<String>(
          options: [
            const AppOptionSwitchOption(
              value: 'all',
              label: 'All',
              isDropTarget: true,
            ),
            const AppOptionSwitchOption(value: 'crypto', label: 'Crypto'),
          ],
          value: 'all',
          onChanged: (_) {},
        ),
      );

      final borders = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border != null);
      expect(borders, isNotEmpty);
    });
  });
}
