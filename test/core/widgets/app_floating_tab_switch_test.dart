import 'package:amble/core/tokens/floating_surface_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_dock_primitives.dart';
import 'package:amble/core/widgets/app_floating_tab_switch.dart';
import 'package:amble/core/widgets/app_liquid_slide.dart';
import 'package:amble/core/widgets/app_option_switch_option.dart';
import 'package:amble/core/widgets/app_press_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final theme = AmbleTheme.light;

  Future<List<String>> pump(WidgetTester tester, {int value = 0}) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [theme]),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: AppFloatingTabSwitch<int>(
                options: const [
                  AppOptionSwitchOption(value: 0, label: 'Things'),
                  AppOptionSwitchOption(value: 1, label: 'Zones'),
                ],
                value: value,
                onChanged: (v) => taps.add('$v'),
              ),
            ),
          ),
        ),
      ),
    );
    return taps;
  }

  testWidgets('sits on the dock\'s floating pane at the main nav\'s height', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(AppDockSurface), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppFloatingTabSwitch<int>)).height,
      theme.sizeButtonMd,
    );
  });

  testWidgets('the selection is the dock group\'s sliding highlight, label '
      'in accent', (tester) async {
    await pump(tester);
    final highlight = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(AppLiquidSlide),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      (highlight.decoration as BoxDecoration).color,
      FloatingSurfaceTokens.selected(theme),
    );
    expect(
      tester.widget<Text>(find.text('Things')).style?.color,
      theme.colorAccent,
    );
    expect(
      tester.widget<Text>(find.text('Zones')).style?.color,
      theme.colorTextSecondary,
    );
  });

  testWidgets('no tap ripple on any segment; a tap selects', (tester) async {
    final taps = await pump(tester);
    for (final press in tester.widgetList<AppPressFeedback>(
      find.byType(AppPressFeedback),
    )) {
      expect(press.ripple, isFalse);
    }
    await tester.tap(find.text('Zones'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, ['1']);
  });

  testWidgets('the sliding highlight is not clipped square by the track — '
      'only the pane\'s rounded edge bounds it', (tester) async {
    await pump(tester);
    final track = tester.widget<Stack>(
      find
          .ancestor(
            of: find.byType(AppLiquidSlide),
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(track.clipBehavior, Clip.none);
  });
}
