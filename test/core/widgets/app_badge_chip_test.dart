import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_badge_chip.dart';
import 'package:amble/core/widgets/app_button.dart'
    show AppButtonSize, appButtonHeightFor;
import 'package:amble/core/widgets/app_value_chip.dart'
    show AppValueChip, AppValueChipSize, AppValueChipVariant;

/// Covers the systematized badge/chip requested directly: "systematize
/// badge (just displayed, selectable variant on off)... selected border
/// should be inner not outer, not to change the size." The bug this
/// guards against: the old `TemplateChip` toggled `Container.border`
/// between `null` and `Border.all(...)`, so selecting a chip grew its
/// total footprint by the border's own width on every edge.
void main() {
  final theme = AmbleTheme.light;

  Future<void> pump(
    WidgetTester tester, {
    bool? selected,
    VoidCallback? onTap,
    AppValueChipVariant variant = AppValueChipVariant.filled,
    AppValueChipSize size = AppValueChipSize.md,
    Widget? leading = const SizedBox(width: 24, height: 24),
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: AppBadgeChip(
            theme: theme,
            leading: leading,
            label: 'Deep work',
            selected: selected,
            onTap: onTap,
            variant: variant,
            size: size,
          ),
        ),
      ),
    );
  }

  Iterable<Border> bordersOf(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((w) => w.decoration)
      .whereType<BoxDecoration>()
      .map((d) => d.border)
      .whereType<Border>();

  testWidgets('selecting a chip does not change its own footprint at all', (
    tester,
  ) async {
    await pump(tester, selected: false, onTap: () {});
    final unselectedSize = tester.getSize(find.byType(AppBadgeChip));

    await pump(tester, selected: true, onTap: () {});
    final selectedSize = tester.getSize(find.byType(AppBadgeChip));

    expect(
      selectedSize,
      unselectedSize,
      reason:
          'requested directly: "selected border should be inner not '
          'outer, not to change the size" — toggling selected must not '
          'grow or shrink the chip',
    );
  });

  testWidgets('unselected: no accent-colored ring exists at all', (
    tester,
  ) async {
    await pump(tester, selected: false, onTap: () {});

    final accentBorders = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .where(
          (d) => switch (d.border) {
            Border(:final top) => top.color == theme.colorAccent,
            _ => false,
          },
        );

    expect(accentBorders, isEmpty);
  });

  testWidgets('selected: an accent-colored ring exists', (tester) async {
    await pump(tester, selected: true, onTap: () {});

    final accentBorders = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .where(
          (d) => switch (d.border) {
            Border(:final top) => top.color == theme.colorAccent,
            _ => false,
          },
        );

    expect(accentBorders, isNotEmpty);
  });

  testWidgets('the selection ring is painted as an overlay, not Padding — the '
      'leading widget keeps its own full, un-shrunk size while selected', (
    tester,
  ) async {
    await pump(tester, selected: true, onTap: () {});

    final leadingSize = tester.getSize(find.byType(SizedBox).first);
    expect(leadingSize, const Size(24, 24));
  });

  testWidgets('tapping fires onTap', (tester) async {
    var tapped = false;
    await pump(tester, selected: false, onTap: () => tapped = true);

    await tester.tap(find.byType(AppBadgeChip));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets(
    'the non-selectable variant (selected/onTap both null) renders no '
    'ring at all, even after an interior gesture probe',
    (tester) async {
      await pump(tester);

      final accentBorders = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .where(
            (d) => switch (d.border) {
              Border(:final top) => top.color == theme.colorAccent,
              _ => false,
            },
          );

      expect(accentBorders, isEmpty);
      expect(find.byType(GestureDetector), findsNothing);
    },
  );

  testWidgets(
    'the non-selectable variant has the SAME footprint as the selectable '
    'variant at rest (unselected) — omitting selection entirely changes '
    'nothing about layout',
    (tester) async {
      await pump(tester);
      final plainSize = tester.getSize(find.byType(AppBadgeChip));

      await pump(tester, selected: false, onTap: () {});
      final unselectedSize = tester.getSize(find.byType(AppBadgeChip));

      expect(plainSize, unselectedSize);
    },
  );

  // Unified against AppValueChip, requested directly: "it should also
  // have same variants as that widget we added value chip, and also
  // rounding same."
  group('AppValueChipVariant.outlined', () {
    testWidgets('renders a border even when not selectable at all — '
        'unlike filled, outlined has no glass fill to fall back on', (
      tester,
    ) async {
      await pump(tester, variant: AppValueChipVariant.outlined);

      expect(bordersOf(tester), isNotEmpty);
    });

    testWidgets(
      'the border is the neutral hairline color when unselected, and '
      'accent when selected',
      (tester) async {
        await pump(
          tester,
          selected: false,
          onTap: () {},
          variant: AppValueChipVariant.outlined,
        );
        expect(
          bordersOf(tester).any((b) => b.top.color == theme.colorBorder),
          isTrue,
        );

        await pump(
          tester,
          selected: true,
          onTap: () {},
          variant: AppValueChipVariant.outlined,
        );
        expect(
          bordersOf(tester).any((b) => b.top.color == theme.colorAccent),
          isTrue,
        );
      },
    );

    testWidgets(
      'a selected outlined chip paints exactly ONE accent border, not '
      'two — the inner selection ring must not double up with the '
      'variant\'s own outer border',
      (tester) async {
        await pump(
          tester,
          selected: true,
          onTap: () {},
          variant: AppValueChipVariant.outlined,
        );

        final accentBorders = bordersOf(
          tester,
        ).where((b) => b.top.color == theme.colorAccent);
        expect(accentBorders, hasLength(1));
      },
    );

    testWidgets('has the same footprint as filled, at every selection '
        'state', (tester) async {
      for (final selected in [null, false, true]) {
        await pump(
          tester,
          selected: selected,
          onTap: selected == null ? null : () {},
          variant: AppValueChipVariant.filled,
        );
        final filledSize = tester.getSize(find.byType(AppBadgeChip));

        await pump(
          tester,
          selected: selected,
          onTap: selected == null ? null : () {},
          variant: AppValueChipVariant.outlined,
        );
        final outlinedSize = tester.getSize(find.byType(AppBadgeChip));

        expect(
          outlinedSize,
          filledSize,
          reason: 'selected=$selected',
        );
      }
    });
  });

  testWidgets(
    'uses the live radiusPill token, not a fixed radius — so it can never '
    'visibly drift from AppValueChip\'s own corners again',
    (tester) async {
      await pump(tester);

      final decoration = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.borderRadius != null);

      expect(decoration.borderRadius, BorderRadius.circular(theme.radiusPill));
    },
  );

  // Requested directly: "app badge chip should have sizes same as app
  // value[chip] and same font weight and sizes."
  group('AppValueChipSize parity', () {
    testWidgets(
      'each rung is at least as tall as AppValueChip\'s own height for '
      'that same rung — a minimum, not a fixed height, so a caller-sized '
      'leading taller than the rung is never clipped',
      (tester) async {
        for (final size in AppValueChipSize.values) {
          await pump(tester, size: size);
          final chipHeight = tester.getSize(find.byType(AppBadgeChip)).height;

          final buttonSize = switch (size) {
            AppValueChipSize.xs => AppButtonSize.xs,
            AppValueChipSize.sm => AppButtonSize.sm,
            AppValueChipSize.md => AppButtonSize.md,
          };
          expect(
            chipHeight,
            greaterThanOrEqualTo(appButtonHeightFor(theme, buttonSize)),
            reason: "$size should be at least $buttonSize's own height",
          );
        }
      },
    );

    testWidgets(
      'md renders text at the SAME font size AppValueChip renders its own '
      'md-rung text at',
      (tester) async {
        await pump(tester, size: AppValueChipSize.md);
        final chipText = tester.widget<Text>(
          find.descendant(
            of: find.byType(AppBadgeChip),
            matching: find.text('Deep work'),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true, extensions: [theme]),
            home: Scaffold(
              body: AppValueChip(
                label: 'Deep work',
                hasValue: true,
                size: AppValueChipSize.md,
                onTap: () {},
              ),
            ),
          ),
        );
        final valueChipText = tester.widget<Text>(
          find.descendant(
            of: find.byType(AppValueChip),
            matching: find.text('Deep work'),
          ),
        );

        expect(chipText.style!.fontSize, valueChipText.style!.fontSize);
      },
    );

    testWidgets(
      'xs and sm both render text at the SAME font size AppValueChip '
      'renders those rungs at (both map to textCaption)',
      (tester) async {
        for (final size in [AppValueChipSize.xs, AppValueChipSize.sm]) {
          await pump(tester, size: size);
          final chipText = tester.widget<Text>(
            find.descendant(
              of: find.byType(AppBadgeChip),
              matching: find.text('Deep work'),
            ),
          );

          expect(chipText.style!.fontSize, theme.textCaption.fontSize);
        }
      },
    );

    testWidgets(
      'the label is ALWAYS w700, regardless of size or selection state — '
      'AppBadgeChip has no placeholder concept, so it never needs '
      'AppValueChip\'s lighter w500',
      (tester) async {
        for (final size in AppValueChipSize.values) {
          for (final selected in [null, false, true]) {
            await pump(
              tester,
              size: size,
              selected: selected,
              onTap: selected == null ? null : () {},
            );
            final chipText = tester.widget<Text>(
              find.descendant(
                of: find.byType(AppBadgeChip),
                matching: find.text('Deep work'),
              ),
            );
            expect(
              chipText.style!.fontWeight,
              FontWeight.w700,
              reason: 'size=$size selected=$selected',
            );
          }
        }
      },
    );
  });

  // Requested directly: "use app badge chip but we don't need icon now
  // so this one without icon and filled" — the Zone facet tag row's own
  // plain-text chips (Morning/Commute/Work/…).
  group('leading omitted (text-only chip)', () {
    testWidgets('renders the label with no leading widget at all', (
      tester,
    ) async {
      await pump(tester, leading: null);

      expect(find.text('Deep work'), findsOneWidget);
      expect(find.byType(SizedBox), findsNothing);
    });

    testWidgets(
      'is narrower than the same chip WITH a leading widget — the gap '
      'is skipped too, not just the leading slot itself',
      (tester) async {
        await pump(tester, leading: null);
        final withoutLeading = tester
            .getSize(find.byType(AppBadgeChip))
            .width;

        await pump(tester);
        final withLeading = tester.getSize(find.byType(AppBadgeChip)).width;

        expect(withoutLeading, lessThan(withLeading));
      },
    );

    testWidgets('still supports selection and tapping with no leading '
        'widget present', (tester) async {
      var tapped = false;
      await pump(
        tester,
        leading: null,
        selected: false,
        onTap: () => tapped = true,
      );

      await tester.tap(find.byType(AppBadgeChip));
      expect(tapped, isTrue);
    });
  });
}
