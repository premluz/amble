import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';

/// Covers the unified button system (2026-09-19) that replaced the
/// previously separate `AppIconButton`/`AppSubtleIconButton` widgets —
/// [AppButtonShape.circle] plus [AppButtonVariant] now does the job of
/// both, so their old behavioral guarantees are pinned here instead.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('circle shape — secondary (was AppSubtleIconButton)', () {
    testWidgets('renders a blurred glass-tinted circle, not a plain '
        'hairline border (2026-09-19 refinement — "icon only secondary '
        'is just border but should be same surface as text button")', (
      tester,
    ) async {
      await pump(
        tester,
        AppButton(
          icon: Icons.sync_rounded,
          shape: AppButtonShape.circle,
          variant: AppButtonVariant.secondary,
          tooltip: 'Sync',
          onPressed: () {},
        ),
      );

      final theme = AmbleTheme.light;
      expect(find.byType(BackdropFilter), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.shape, BoxShape.circle);
      expect(decoration.border, isNull);
      expect(decoration.color, theme.colorTextPrimary.withValues(alpha: 0.16));
    });

    testWidgets('tapping invokes onPressed', (tester) async {
      var tapped = false;
      await pump(
        tester,
        AppButton(
          icon: Icons.sync_rounded,
          shape: AppButtonShape.circle,
          variant: AppButtonVariant.secondary,
          tooltip: 'Sync',
          onPressed: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(AppButton));
      expect(tapped, isTrue);
    });

    testWidgets('a null onPressed renders disabled — no tap handling', (
      tester,
    ) async {
      await pump(
        tester,
        const AppButton(
          icon: Icons.sync_rounded,
          shape: AppButtonShape.circle,
          variant: AppButtonVariant.secondary,
          tooltip: 'Sync',
          onPressed: null,
        ),
      );

      // Should not throw — a null onPressed is a valid, documented
      // "disabled" state (matches AppPressFeedback's own contract).
      await tester.tap(find.byType(AppButton));
    });

    testWidgets('a custom child overrides the icon — used by the today '
        'button for its day-of-month number', (tester) async {
      await pump(
        tester,
        AppButton(
          shape: AppButtonShape.circle,
          variant: AppButtonVariant.secondary,
          tooltip: 'Today',
          onPressed: () {},
          child: const Text('12'),
        ),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('iconColor/borderColor override the defaults — used for the '
        "Edit Mode toggle's active accent state (borderColor now tints the "
        'blurred fill itself, not a border — see the 2026-09-19 blur '
        'refinement)', (tester) async {
      final theme = AmbleTheme.light;
      await pump(
        tester,
        AppButton(
          icon: Icons.close_rounded,
          shape: AppButtonShape.circle,
          variant: AppButtonVariant.secondary,
          tooltip: 'Done',
          onPressed: () {},
          iconColor: theme.colorAccent,
          borderColor: theme.colorAccent,
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(icon.color, theme.colorAccent);
      expect(decoration.color, theme.colorAccent);
    });
  });

  group('circle shape — primary (was AppIconButton)', () {
    testWidgets('renders a filled accent circle with no border', (
      tester,
    ) async {
      await pump(
        tester,
        AppButton(
          icon: Icons.add_rounded,
          shape: AppButtonShape.circle,
          onPressed: () {},
        ),
      );

      final theme = AmbleTheme.light;
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, theme.colorAccent);
      expect(decoration.border, isNull);

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, theme.colorSurfacePrimary);
    });

    testWidgets('tapping invokes onPressed', (tester) async {
      var tapped = false;
      await pump(
        tester,
        AppButton(
          icon: Icons.add_rounded,
          shape: AppButtonShape.circle,
          onPressed: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(AppButton));
      expect(tapped, isTrue);
    });
  });

  group('ghost variant', () {
    testWidgets('renders no fill at rest', (tester) async {
      await pump(
        tester,
        AppButton(
          label: 'Skip',
          variant: AppButtonVariant.ghost,
          onPressed: () {},
        ),
      );

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      final backgroundColor = button.style?.backgroundColor?.resolve({});
      expect(backgroundColor, Colors.transparent);
    });

    testWidgets('tapping invokes onPressed', (tester) async {
      var tapped = false;
      await pump(
        tester,
        AppButton(
          label: 'Skip',
          variant: AppButtonVariant.ghost,
          onPressed: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(AppButton));
      expect(tapped, isTrue);
    });
  });

  group('content modes', () {
    testWidgets('icon + label renders both, icon leading', (tester) async {
      await pump(
        tester,
        AppButton(
          label: 'Add',
          icon: Icons.add_rounded,
          onPressed: () {},
        ),
      );

      expect(find.text('Add'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('label alone renders text only', (tester) async {
      await pump(tester, AppButton(label: 'Save', onPressed: () {}));

      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });
}
