import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_press_feedback.dart';
import 'package:amble/core/widgets/app_nav_press.dart';
import 'package:amble/core/widgets/app_sub_nav.dart';
import 'package:amble/core/widgets/app_top_nav.dart';

/// Covers [AppTopNav]'s active-state contract — in particular the real
/// bug fixed 2026-09-22 (`main.dart`'s own call site used to fall back
/// `selectedIndex` to `0` whenever it held Settings' own out-of-range
/// index, which made "Day" light up as active while Settings was
/// actually open). Reported directly: "currently when settings selected
/// (1 menu item active) > none should be, only active state for gear
/// icon (settings)."
void main() {
  final theme = AmbleTheme.light;
  const destinations = ['Days', 'Things', 'Patterns'];

  Future<void> pump(
    WidgetTester tester, {
    required int selectedIndex,
    bool settingsSelected = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [theme]),
      home: Scaffold(
        body: AppTopNav(
          destinations: destinations,
          selectedIndex: selectedIndex,
          settingsSelected: settingsSelected,
          onDestinationSelected: (_) {},
          onSettingsTap: () {},
        ),
      ),
    ),
  );

  Color? gearColor(WidgetTester tester) =>
      tester.widget<Icon>(find.byIcon(Icons.settings_outlined)).color;

  Color? labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  testWidgets(
    'an ordinary destination lights up exactly like before — the gear '
    'stays inactive',
    (tester) async {
      await pump(tester, selectedIndex: 0);

      expect(labelColor(tester, 'Days'), theme.colorTextPrimary);
      expect(labelColor(tester, 'Things'), theme.colorTextTertiary);
      expect(labelColor(tester, 'Patterns'), theme.colorTextTertiary);
      expect(gearColor(tester), theme.colorForegroundTertiary);
    },
  );

  testWidgets(
    'settingsSelected lights up ONLY the gear icon — every destination '
    'label reads as inactive, even one whose index would otherwise match',
    (tester) async {
      // index 0 is deliberately passed alongside settingsSelected: true —
      // this is exactly the shape a caller reaches when Settings' own
      // index is out of range for `destinations` and gets clamped/reused
      // rather than left genuinely unmatched. AppTopNav itself must not
      // let a coincidental index collision light up a label while
      // Settings is the one actually showing.
      await pump(tester, selectedIndex: 0, settingsSelected: true);

      expect(labelColor(tester, 'Days'), theme.colorTextPrimary);
      expect(gearColor(tester), theme.colorTextPrimary);
    },
  );

  testWidgets(
    'an out-of-range selectedIndex with settingsSelected leaves every '
    'label inactive and only the gear active',
    (tester) async {
      // The real shape main.dart now passes: Settings' own index (out of
      // range for a 3-item destinations list) together with
      // settingsSelected: true.
      await pump(tester, selectedIndex: 3, settingsSelected: true);

      expect(labelColor(tester, 'Days'), theme.colorTextTertiary);
      expect(labelColor(tester, 'Things'), theme.colorTextTertiary);
      expect(labelColor(tester, 'Patterns'), theme.colorTextTertiary);
      expect(gearColor(tester), theme.colorTextPrimary);
    },
  );

  testWidgets('settingsSelected defaults to false — existing callers are '
      'unaffected', (tester) async {
    await pump(tester, selectedIndex: 1);

    expect(gearColor(tester), theme.colorForegroundTertiary);
  });

  testWidgets('uses compact chrome styling while retaining the 40px row', (
    tester,
  ) async {
    await pump(tester, selectedIndex: 0);

    expect(
      tester.widget<Text>(find.text('Days')).style?.fontSize,
      theme.textBody.fontSize,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.settings_outlined)).size,
      TopNavTokens.settingsIconSize,
    );
    final settingsHitArea = tester.getSize(
      find.ancestor(
        of: find.byIcon(Icons.settings_outlined),
        matching: find.byType(AppPressFeedback),
      ),
    );
    expect(settingsHitArea.width, appButtonHeightFor(theme, AppButtonSize.md));
    expect(settingsHitArea.height, appButtonHeightFor(theme, AppButtonSize.md));
  });

  testWidgets('the settings gear sits optically on the right edge: its '
      'glyph, not its invisible tap box, ends where the nav ends (the '
      'screen-padding line)', (tester) async {
    await pump(tester, selectedIndex: 0);
    expect(
      tester.getRect(find.byIcon(Icons.settings_outlined)).right,
      tester.getRect(find.byType(AppTopNav)).right,
    );
  });

  // Reported directly: switching between the main shell (this bar) and
  // the merged Edit screen's `AppTabSwitch` (Tasks/Zones) visibly
  // "jumped" — this bar previously had no fixed height at all, sizing to
  // bare text with no padding, while `AppTabSwitch` reserves a deliberate
  // `appButtonHeightFor(theme, AppButtonSize.md)` track.
  group('height/hit-area matches AppTabSwitch (2026-09-26)', () {
    testWidgets('the whole bar is exactly AppButtonSize.md tall, same as '
        "AppTabSwitch's own track", (tester) async {
      await pump(tester, selectedIndex: 0);

      final barHeight = tester.getSize(find.byType(AppTopNav)).height;

      expect(barHeight, appButtonHeightFor(theme, AppButtonSize.md));
    });

    testWidgets(
      "each destination label's own tap target is the full bar height, "
      'not just its bare text bounds',
      (tester) async {
        await pump(tester, selectedIndex: 0);

        final labelHitArea = tester
            .getSize(
              find.ancestor(
                of: find.text('Days'),
                matching: find.byType(AppPressFeedback),
              ),
            )
            .height;

        expect(labelHitArea, appButtonHeightFor(theme, AppButtonSize.md));
      },
    );
  });

  group('active (pressed) state is the lighter next surface', () {
    AppNavWash washOf(WidgetTester tester, Finder target) =>
        tester.widget<AppNavWash>(
          find.ancestor(of: target, matching: find.byType(AppNavWash)).first,
        );

    testWidgets('holding a destination shows the Settings-group surface '
        'behind its label — no dark ripple over it — and clears on release', (
      tester,
    ) async {
      await pump(tester, selectedIndex: 0);
      expect(washOf(tester, find.text('Things')).visible, isFalse);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Things')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(washOf(tester, find.text('Things')).visible, isTrue);
      final fill = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(AppNavWash),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color);
      expect(fill, contains(theme.colorSurfaceSecondary));
      expect(
        find.descendant(
          of: find.byType(AppTopNav),
          matching: find.byType(ClipPath),
        ),
        findsNothing,
        reason: 'no dark wash',
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(washOf(tester, find.text('Things')).visible, isFalse);
    });

    testWidgets('the settings gear too', (tester) async {
      await pump(tester, selectedIndex: 0);
      final gear = find.byIcon(Icons.settings_outlined);
      final gesture = await tester.startGesture(tester.getCenter(gear));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(washOf(tester, gear).visible, isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a sub-nav tab hovered by a drag shows the same surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: AppSubNavLabel(
              label: 'Work',
              selected: false,
              highlighted: true,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(washOf(tester, find.text('Work')).visible, isTrue);
    });
  });
}
