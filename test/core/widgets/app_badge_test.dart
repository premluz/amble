import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Requested directly, for the Zones edit dock's own deselect-button
/// count badge: a new, classic circular-badge component ("it's a
/// classic comp so let's default to what Flutter has... used to show
/// number of items e.g. in tab etc"), two variants (filled/outline),
/// three sizes (xs/sm/md), token colors matching `AppButton`'s own
/// accent-fill state.
void main() {
  Future<void> pumpBadge(
    WidgetTester tester, {
    required int count,
    AppBadgeVariant variant = AppBadgeVariant.filled,
    AppBadgeSize size = AppBadgeSize.sm,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: AppBadge(count: count, variant: variant, size: size),
        ),
      ),
    );
  }

  testWidgets('shows the given count as text', (tester) async {
    await pumpBadge(tester, count: 3);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('filled variant fills with colorAccent and no border', (
    tester,
  ) async {
    await pumpBadge(tester, count: 2, variant: AppBadgeVariant.filled);

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AmbleTheme.light.colorAccent);
    expect(decoration.border, isNull);

    final text = tester.widget<Text>(find.text('2'));
    expect(text.style!.color, AmbleTheme.light.colorSurfacePrimary);
  });

  testWidgets(
    'outline variant has a transparent-center ring, no fill color',
    (tester) async {
      await pumpBadge(tester, count: 5, variant: AppBadgeVariant.outline);

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AmbleTheme.light.colorSurfacePrimary);
      expect(decoration.border, isNotNull);

      final text = tester.widget<Text>(find.text('5'));
      expect(text.style!.color, AmbleTheme.light.colorAccent);
    },
  );

  testWidgets('xs/sm/md sizes resolve to distinct, increasing diameters', (
    tester,
  ) async {
    Future<double> diameterFor(AppBadgeSize size) async {
      await pumpBadge(tester, count: 1, size: size);
      final container = tester.widget<Container>(find.byType(Container));
      return container.constraints!.maxWidth;
    }

    final xs = await diameterFor(AppBadgeSize.xs);
    final sm = await diameterFor(AppBadgeSize.sm);
    final md = await diameterFor(AppBadgeSize.md);

    expect(xs, lessThan(sm));
    expect(sm, lessThan(md));
  });

  testWidgets('renders as a circle', (tester) async {
    await pumpBadge(tester, count: 1);
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
  });
}
