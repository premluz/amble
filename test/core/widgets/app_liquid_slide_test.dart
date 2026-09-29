import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_bottom_dock.dart';
import 'package:amble/core/widgets/app_liquid_slide.dart';
import 'package:amble/core/widgets/app_option_switch_option.dart';
import 'package:amble/core/widgets/app_tab_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = Rect.fromLTWH(0, 0, 100, 40);
const _b = Rect.fromLTWH(100, 0, 100, 40);
const _frame = Duration(milliseconds: 16);

Widget _host(Rect target, {bool still = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: still),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 200,
      height: 40,
      child: Stack(
        children: [
          AppLiquidSlide(
            target: target,
            child: const SizedBox.expand(key: ValueKey('blob')),
          ),
        ],
      ),
    ),
  ),
);

Rect _blob(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey('blob')));

void main() {
  testWidgets('first build: simply on its target', (tester) async {
    await tester.pumpWidget(_host(_a));
    expect(_blob(tester), _a);
  });

  testWidgets('moving: the leading edge gets there first — it stretches '
      'toward the target, thinning a touch — then settles exactly', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_a));
    await tester.pumpWidget(_host(_b));
    var widest = 0.0;
    var thinnest = double.infinity;
    for (var i = 0; i < 12; i++) {
      await tester.pump(_frame);
      final rect = _blob(tester);
      if (rect.width > widest) widest = rect.width;
      if (rect.height < thinnest) thinnest = rect.height;
    }
    expect(widest, greaterThan(_a.width * 1.2), reason: 'stretches');
    expect(thinnest, lessThan(_a.height), reason: 'thins while stretched');
    await tester.pumpAndSettle();
    expect(_blob(tester), _b, reason: 'then exactly its new place');
  });

  testWidgets('moving left, the LEFT edge leads', (tester) async {
    await tester.pumpWidget(_host(_b));
    await tester.pumpWidget(_host(_a));
    await tester.pump(_frame * 4);
    final rect = _blob(tester);
    expect(
      _b.left - rect.left,
      greaterThan(_b.right - rect.right),
      reason: 'the left edge has travelled further than the right',
    );
    expect(rect.right, greaterThan(_a.right), reason: 'tail still behind');
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion: jumps', (tester) async {
    await tester.pumpWidget(_host(_a, still: true));
    await tester.pumpWidget(_host(_b, still: true));
    expect(_blob(tester), _b);
  });

  testWidgets('the Edit screen\'s tab switch uses one liquid highlight '
      'under its segments', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: AppTabSwitch<int>(
              options: const [
                AppOptionSwitchOption(value: 0, label: 'Things'),
                AppOptionSwitchOption(value: 1, label: 'Zones'),
              ],
              value: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AppLiquidSlide), findsOneWidget);
  });

  testWidgets('the Day dock\'s connected pair (Timeline | List) uses one '
      'liquid highlight, and its buttons no longer fill themselves', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: AppBottomDock(
            activeView: AppBottomDockView.timeline,
            onSelectView: (_) {},
            onEditTap: () {},
            whatMattersEnabled: false,
            onWhatMattersTap: () {},
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('dock-selection-context-navigation')),
      findsOneWidget,
    );
    final timeline = tester
        .widgetList<AppDockIconButton>(find.byType(AppDockIconButton))
        .singleWhere((button) => button.tooltip == 'Timeline');
    expect(timeline.selected, isTrue);
    expect(timeline.showsSelectedFill, isFalse);
  });
}
