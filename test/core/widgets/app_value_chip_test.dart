import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart'
    show AppButtonSize, appButtonHeightFor;
import 'package:amble/core/widgets/app_value_chip.dart';

/// Covers the value-carrying chip behind the task composer's own
/// "Today / hh:mm / duration" row — the control that shows a placeholder
/// until its picker returns a value, then shows the value.
///
/// The footprint assertions matter for the same reason they do in
/// `app_badge_chip_test.dart`: this chip sits in a ROW of siblings, so a
/// state change that resizes one chip would shuffle every chip beside it.
/// Here the risk is specific — a set chip swaps in a `BackdropFilter`
/// wrapper and (when outlined) keeps a border, both of which are easy to
/// accidentally implement as layout-consuming rather than overlaid.
void main() {
  final theme = AmbleTheme.light;

  Future<void> pump(
    WidgetTester tester, {
    required String label,
    required bool hasValue,
    AppValueChipVariant variant = AppValueChipVariant.filled,
    AppValueChipSize size = AppValueChipSize.sm,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: Center(
            child: AppValueChip(
              label: label,
              hasValue: hasValue,
              variant: variant,
              size: size,
              icon: icon,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the placeholder when it has no value, and the '
      'value once it has one', (tester) async {
    await pump(tester, label: 'hh:mm', hasValue: false);
    expect(find.text('hh:mm'), findsOneWidget);

    await pump(tester, label: '09:30', hasValue: true);
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('hh:mm'), findsNothing);
  });

  testWidgets('a placeholder and a set value of the same length occupy '
      'the SAME footprint — a row of chips must not reflow when one is '
      'filled in', (tester) async {
    // Same glyph count either way, so any size difference is the state
    // styling itself (the BackdropFilter wrap, the weight change), not
    // the text.
    await pump(tester, label: '00:00', hasValue: false);
    final emptySize = tester.getSize(find.byType(AppValueChip));

    await pump(tester, label: '09:30', hasValue: true);
    final setSize = tester.getSize(find.byType(AppValueChip));

    expect(setSize, emptySize);
  });

  testWidgets('outlined keeps the same footprint across states too — its '
      'border must not be added only when set', (tester) async {
    await pump(
      tester,
      label: '00:00',
      hasValue: false,
      variant: AppValueChipVariant.outlined,
    );
    final emptySize = tester.getSize(find.byType(AppValueChip));

    await pump(
      tester,
      label: '09:30',
      hasValue: true,
      variant: AppValueChipVariant.outlined,
    );
    final setSize = tester.getSize(find.byType(AppValueChip));

    expect(setSize, emptySize);
  });

  testWidgets('outlined carries a border in BOTH states; filled carries '
      'one in neither', (tester) async {
    Border? borderOf(WidgetTester tester) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppValueChip),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration as BoxDecoration?)?.border as Border?;
    }

    await pump(
      tester,
      label: 'hh:mm',
      hasValue: false,
      variant: AppValueChipVariant.outlined,
    );
    expect(borderOf(tester), isNotNull);

    await pump(
      tester,
      label: '09:30',
      hasValue: true,
      variant: AppValueChipVariant.outlined,
    );
    expect(borderOf(tester), isNotNull);

    await pump(tester, label: '09:30', hasValue: true);
    expect(borderOf(tester), isNull);
  });

  testWidgets('every shipped rung matches the shared button height token, '
      'so a chip lines up with a button beside it', (tester) async {
    const rungs = {
      AppValueChipSize.xs: AppButtonSize.xs,
      AppValueChipSize.sm: AppButtonSize.sm,
      AppValueChipSize.md: AppButtonSize.md,
    };

    for (final entry in rungs.entries) {
      await pump(tester, label: '09:30', hasValue: true, size: entry.key);
      expect(
        tester.getSize(find.byType(AppValueChip)).height,
        appButtonHeightFor(theme, entry.value),
        reason: '${entry.key} should be ${entry.value}\'s own height',
      );
    }
  });

  testWidgets('hugs its own content instead of expanding to fill the '
      'space offered — a chip in a row must not claim the whole width', (
    tester,
  ) async {
    // Real bug, caught by a size probe rather than by the equal-footprint
    // assertions above (which happily compared 800px to 800px): a
    // `Container` with an `alignment` and no width expands to its
    // parent's max. A short label must therefore produce a visibly
    // narrow chip, well under the 800px test surface.
    await pump(tester, label: 'hh:mm', hasValue: false);
    final width = tester.getSize(find.byType(AppValueChip)).width;

    expect(width, lessThan(200));
  });

  testWidgets('a longer value makes a wider chip — the width really does '
      'track the content', (tester) async {
    await pump(tester, label: 'Today', hasValue: true);
    final shortWidth = tester.getSize(find.byType(AppValueChip)).width;

    await pump(tester, label: 'Thu Aug 20, 2026', hasValue: true);
    final longWidth = tester.getSize(find.byType(AppValueChip)).width;

    expect(longWidth, greaterThan(shortWidth));
  });

  testWidgets('clamps to a tight parent instead of overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: SizedBox(
            width: 60,
            child: AppValueChip(
              label: 'A very long value indeed',
              hasValue: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppValueChip)).width, 60);
  });

  testWidgets('an icon renders alongside the label when given, and is '
      'absent otherwise', (tester) async {
    await pump(tester, label: 'hh:mm', hasValue: false);
    expect(find.byType(Icon), findsNothing);

    await pump(
      tester,
      label: 'hh:mm',
      hasValue: false,
      icon: Icons.schedule_rounded,
    );
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.text('hh:mm'), findsOneWidget);
  });

  testWidgets('tapping fires onTap in both the empty and the set state — '
      'a set chip reopens its picker rather than going inert', (
    tester,
  ) async {
    var taps = 0;

    await pump(
      tester,
      label: 'hh:mm',
      hasValue: false,
      onTap: () => taps++,
    );
    await tester.tap(find.byType(AppValueChip));
    expect(taps, 1);

    await pump(
      tester,
      label: '09:30',
      hasValue: true,
      onTap: () => taps++,
    );
    await tester.tap(find.byType(AppValueChip));
    expect(taps, 2);
  });
}
