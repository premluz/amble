import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_shell_chrome.dart';
import 'package:amble/core/widgets/app_shell_header.dart';
import 'package:amble/core/widgets/app_top_nav.dart';
import 'package:amble/core/widgets/app_tab_switch.dart';
import 'package:amble/core/widgets/app_option_switch_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('header swap keeps calendar anchor and tabs retain identity', (tester) async {
    final controller = AppShellChromeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(theme: ThemeData(extensions: [AmbleTheme.light]),
      home: Column(children: [
        AppShellHeader(controller: controller, child: AppTopNav(
          destinations: const ['Day', 'Inbox'], selectedIndex: 0,
          onDestinationSelected: (_) {}, onSettingsTap: () {},
        )),
        const Text('Calendar'),
      ]),
    ));
    final anchor = tester.getTopLeft(find.text('Calendar'));
    Widget tabs(int value) => AppTabSwitch<int>(options: const [
      AppOptionSwitchOption(value: 0, label: 'Tasks'),
      AppOptionSwitchOption(value: 1, label: 'Zones'),
    ], value: value, onChanged: (_) {});
    controller.updateHeader('tasks', tabs(0));
    await tester.pumpAndSettle();
    expect(find.byType(AppTopNav), findsNothing);
    final element = tester.element(find.byType(AppTabSwitch<int>));
    controller.updateHeader('zones', tabs(1));
    await tester.pump();
    expect(tester.element(find.byType(AppTabSwitch<int>)), same(element));
    expect(tester.getTopLeft(find.text('Calendar')), anchor);
    await tester.pumpAndSettle();
  });
}
