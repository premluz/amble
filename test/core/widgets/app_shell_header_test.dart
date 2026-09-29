import 'package:amble/core/tokens/header_reveal_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_context_dock_config.dart';
import 'package:amble/core/widgets/app_dock_primitives.dart';
import 'package:amble/core/widgets/app_floating_tab_switch.dart';
import 'package:amble/core/widgets/app_option_switch_option.dart';
import 'package:amble/core/widgets/app_shell_chrome.dart';
import 'package:amble/core/widgets/app_shell_header.dart';
import 'package:amble/core/widgets/app_top_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppShellChromeController> pump(WidgetTester tester) async {
    final controller = AppShellChromeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AmbleTheme.light]),
        home: Column(
          children: [
            AppShellHeader(
              controller: controller,
              child: AppTopNav(
                destinations: const ['Days', 'Things'],
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                onSettingsTap: () {},
              ),
            ),
            const Text('Calendar'),
          ],
        ),
      ),
    );
    return controller;
  }

  Widget tabs(int value) => AppFloatingTabTrack<int>(
    options: const [
      AppOptionSwitchOption(value: 0, label: 'Things'),
      AppOptionSwitchOption(value: 1, label: 'Zones'),
    ],
    value: value,
    onChanged: (_) {},
  );

  double opacityOf(WidgetTester tester, Finder target) => tester
      .widget<FadeTransition>(
        find.ancestor(of: target, matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;

  testWidgets('header swap keeps calendar anchor and tabs retain identity', (
    tester,
  ) async {
    final controller = await pump(tester);
    final anchor = tester.getTopLeft(find.text('Calendar'));
    controller.updateHeader('tasks', tabs(0));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, find.text('Days')), 0);
    final element = tester.element(find.byType(AppFloatingTabTrack<int>));
    controller.updateHeader('zones', tabs(1));
    await tester.pump();
    expect(
      tester.element(find.byType(AppFloatingTabTrack<int>)),
      same(element),
    );
    expect(tester.getTopLeft(find.text('Calendar')), anchor);
    await tester.pumpAndSettle();
  });

  testWidgets('entering, the nav leaves in order — settings last — and the '
      'pane grows from the leading edge into the full header', (tester) async {
    final controller = await pump(tester);
    final gear = find.byIcon(Icons.settings_outlined);
    controller.updateHeader('tasks', tabs(0));
    await tester.pump();

    await tester.pump(
      const Duration(milliseconds: HeaderRevealSpec.itemFadeMs ~/ 2),
    );
    final days = opacityOf(tester, find.text('Days'));
    final things = opacityOf(tester, find.text('Things').first);
    expect(days, lessThan(things));
    expect(things, lessThanOrEqualTo(opacityOf(tester, gear)));
    expect(opacityOf(tester, gear), closeTo(1, 1e-9));

    await tester.pump(
      const Duration(milliseconds: HeaderRevealSpec.itemFadeMs),
    );
    final header = tester.getRect(find.byType(AppShellHeader));
    final early = tester.getRect(find.byType(AppDockSurface));
    // Still growing out of the leading edge (its pop scales it about its
    // own centre, so the left edge itself is not pinned).
    expect(early.center.dx, lessThan(header.center.dx));
    expect(early.width, lessThan(header.width));

    await tester.pumpAndSettle();
    expect(opacityOf(tester, gear), 0);
    final settled = tester.getRect(find.byType(AppDockSurface));
    expect(settled.width, closeTo(header.width, .5));
  });

  testWidgets('the nav cannot be tapped while the route header shows', (
    tester,
  ) async {
    final controller = await pump(tester);
    controller.updateHeader('tasks', tabs(0));
    await tester.pumpAndSettle();
    final ignoring = tester
        .widgetList<IgnorePointer>(
          find.ancestor(
            of: find.byType(AppTopNav),
            matching: find.byType(IgnorePointer),
          ),
        )
        .any((widget) => widget.ignoring);
    expect(ignoring, isTrue);
  });

  testWidgets('leaving plays it backwards: the pane goes, the nav returns', (
    tester,
  ) async {
    final controller = await pump(tester);
    controller.claim(
      'edit',
      const AppContextDockConfiguration(stateId: 'edit', groups: []),
    );
    controller.updateHeader('tasks', tabs(0));
    await tester.pumpAndSettle();
    controller.release('edit');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AppFloatingTabTrack<int>), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(AppFloatingTabTrack<int>), findsNothing);
    expect(opacityOf(tester, find.text('Days')), 1);
    expect(opacityOf(tester, find.byIcon(Icons.settings_outlined)), 1);
  });
}
