import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_subtle_icon_button.dart';

/// Promoted out of `AppCalendarHeader` (2026-09-12) so the Tracked tab's
/// own view-cycle switcher can use the identical "very subtle outline"
/// style. Behavior is unchanged from that widget's own private copy —
/// these tests just pin it against accidental drift now that two
/// features share it.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('renders a hairline-bordered circle with no fill', (
    tester,
  ) async {
    await pump(
      tester,
      AppSubtleIconButton(
        icon: Icons.sync_rounded,
        tooltip: 'Sync',
        onTap: () {},
      ),
    );

    final theme = AmbleTheme.light;
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;

    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, isNull);
    expect(decoration.border!.top.width, theme.borderWidthHairline);
    expect(decoration.border!.top.color, theme.colorBorder);
  });

  testWidgets('tapping invokes onTap', (tester) async {
    var tapped = false;
    await pump(
      tester,
      AppSubtleIconButton(
        icon: Icons.sync_rounded,
        tooltip: 'Sync',
        onTap: () => tapped = true,
      ),
    );

    await tester.tap(find.byType(AppSubtleIconButton));
    expect(tapped, isTrue);
  });

  testWidgets('a null onTap renders disabled — no tap handling', (
    tester,
  ) async {
    await pump(
      tester,
      const AppSubtleIconButton(
        icon: Icons.sync_rounded,
        tooltip: 'Sync',
        onTap: null,
      ),
    );

    // Should not throw — a null onTap is a valid, documented "disabled"
    // state (matches AppPressFeedback's own null-means-disabled contract).
    await tester.tap(find.byType(AppSubtleIconButton));
  });

  testWidgets('a custom child overrides the icon — used by the today '
      'button for its day-of-month number', (tester) async {
    await pump(
      tester,
      AppSubtleIconButton(
        tooltip: 'Today',
        onTap: () {},
        child: const Text('12'),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('iconColor/borderColor override the defaults — used for the '
      'Edit Mode toggle\'s active accent state', (tester) async {
    final theme = AmbleTheme.light;
    await pump(
      tester,
      AppSubtleIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Done',
        onTap: () {},
        iconColor: theme.colorAccent,
        borderColor: theme.colorAccent,
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;

    expect(icon.color, theme.colorAccent);
    expect(decoration.border!.top.color, theme.colorAccent);
  });
}
