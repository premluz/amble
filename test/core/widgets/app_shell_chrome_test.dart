import 'package:amble/core/widgets/app_context_dock_config.dart';
import 'package:amble/core/widgets/app_shell_chrome.dart';
import 'package:amble/core/widgets/app_bottom_dock.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppContextDockConfiguration _configuration(String stateId) =>
    AppContextDockConfiguration(
      stateId: stateId,
      groups: [
        AppContextGroup(
          id: 'actions',
          actions: [
            AppContextAction(
              id: 'back',
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onPressed: () {},
            ),
          ],
        ),
      ],
    );

void main() {
  testWidgets('shell dock follows selection configuration without rebuilding parent', (tester) async {
    final controller = AppShellChromeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [AmbleTheme.light]),
      home: AppShellChromeScope(controller: controller,
        child: AppBottomDock(activeView: AppBottomDockView.list,
          onSelectView: (_) {}, onEditTap: () {}, whatMattersEnabled: false,
          onWhatMattersTap: () {})),
    ));
    controller.claim('edit', _configuration('edit-zone'));
    await tester.pumpAndSettle();
    controller.claim('edit', AppContextDockConfiguration(
      stateId: 'edit-zone-selection', groups: [AppContextGroup(id: 'selection', actions: [
        AppContextAction(id: 'edit', icon: Icons.edit_outlined, tooltip: 'Edit placement', onPressed: () {}),
        AppContextAction(id: 'remove', icon: Icons.delete_outline_rounded, tooltip: 'Remove placements', onPressed: () {}),
      ])],
    ));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit placement'), findsOneWidget);
    expect(find.byTooltip('Remove placements'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  // Requested directly, for the Zones edit dock's own deselect-button
  // count badge: a config change where ONLY `badgeCount` differs (same
  // stateId, same action ids/icon/tooltip/selected/enabled/destructive)
  // must still reach the rendered dock. Real bug found and fixed here —
  // `_configurationSignature` never included `badgeCount`, so `claim`'s
  // own "signature unchanged, skip" fast path silently dropped a
  // badge-only update (1 selected -> 2 selected showed no badge at all
  // until some OTHER field also changed).
  testWidgets(
    'a badgeCount-only configuration change still reaches the dock',
    (tester) async {
      final controller = AppShellChromeController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AmbleTheme.light]),
          home: AppShellChromeScope(
            controller: controller,
            child: AppBottomDock(
              activeView: AppBottomDockView.list,
              onSelectView: (_) {},
              onEditTap: () {},
              whatMattersEnabled: false,
              onWhatMattersTap: () {},
            ),
          ),
        ),
      );

      AppContextDockConfiguration configWithBadge(int? badgeCount) =>
          AppContextDockConfiguration(
            stateId: 'edit-zone-selection',
            groups: [
              AppContextGroup(
                id: 'selection',
                actions: [
                  AppContextAction(
                    id: 'deselect',
                    icon: Icons.deselect_rounded,
                    tooltip: 'Clear selection',
                    badgeCount: badgeCount,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          );

      controller.claim('edit', configWithBadge(null));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNothing);

      controller.claim('edit', configWithBadge(2));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);

      controller.claim('edit', configWithBadge(3));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets('route owner controls the persistent shell configuration', (
    tester,
  ) async {
    final controller = AppShellChromeController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShellChromeScope(
          controller: controller,
          child: Builder(
            builder: (context) => Text(
              AppShellChromeScope.maybeOf(context)?.configuration?.stateId ??
                  'none',
            ),
          ),
        ),
      ),
    );
    expect(find.text('none'), findsOneWidget);

    controller.claim('edit', _configuration('edit-task'));
    await tester.pump();
    await tester.pump();
    expect(find.text('edit-task'), findsOneWidget);

    controller.claim('selection', _configuration('selection'));
    controller.release('edit');
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('selection'), findsOneWidget);
  });
}
