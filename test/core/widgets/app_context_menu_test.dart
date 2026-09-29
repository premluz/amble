import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_context_menu.dart';
import 'package:amble/core/widgets/app_floating_surface.dart';
import 'package:amble/core/widgets/app_liquid_morph.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _actions = [
  AppContextMenuAction(
    icon: Icons.edit_outlined,
    label: 'Rename',
    onTap: _noop,
  ),
  AppContextMenuAction(
    icon: Icons.delete_outline,
    label: 'Remove',
    isDestructive: true,
    onTap: _noop,
  ),
];

void _noop() {}

Widget _anchoredMenuHost(Offset anchor) => MaterialApp(
  theme: ThemeData(extensions: [AmbleTheme.light]),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('open-context-menu'),
          onPressed: () => AppContextMenu.showAt(
            context,
            position: anchor,
            actions: _actions,
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

Finder _menuPanel(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(AppFloatingSurface),
);

void _setTestViewport(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('popover opens above a low anchor and stays within safe bounds', (
    tester,
  ) async {
    _setTestViewport(tester);
    const anchor = Offset(390, 780);
    await tester.pumpWidget(_anchoredMenuHost(anchor));
    await tester.tap(find.byKey(const ValueKey('open-context-menu')));
    await tester.pumpAndSettle();

    final expectedRadius = BorderRadius.circular(AmbleTheme.light.radiusXxl);
    expect(
      tester.widget<AppFloatingSurface>(_menuPanel('Rename')).borderRadius,
      expectedRadius,
    );
    expect(
      tester.widget<AppLiquidMorph>(find.byType(AppLiquidMorph)).borderRadius,
      AmbleTheme.light.radiusXxl,
    );

    final panel = tester.getRect(_menuPanel('Rename'));
    expect(panel.right, lessThanOrEqualTo(400 - AmbleTheme.light.spacingSm));
    expect(panel.bottom, lessThanOrEqualTo(800 - AmbleTheme.light.spacingSm));
    expect(panel.bottom, lessThan(anchor.dy));
  });

  testWidgets('popover opens below a high anchor near the left edge', (
    tester,
  ) async {
    _setTestViewport(tester);
    const anchor = Offset(12, 20);
    await tester.pumpWidget(_anchoredMenuHost(anchor));
    await tester.tap(find.byKey(const ValueKey('open-context-menu')));
    await tester.pumpAndSettle();

    final panel = tester.getRect(_menuPanel('Rename'));
    expect(panel.left, greaterThanOrEqualTo(AmbleTheme.light.spacingSm));
    expect(panel.top, greaterThan(anchor.dy));
  });

  testWidgets('press-drag highlight follows and snaps between menu rows', (
    tester,
  ) async {
    _setTestViewport(tester);
    var selectedAction = '';
    final actions = [
      AppContextMenuAction(
        icon: Icons.edit_outlined,
        label: 'Rename',
        onTap: () => selectedAction = 'Rename',
      ),
      AppContextMenuAction(
        icon: Icons.delete_outline,
        label: 'Remove',
        isDestructive: true,
        onTap: () => selectedAction = 'Remove',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Center(
            child: AppLongPressContextMenu(
              actions: actions,
              child: const SizedBox(
                width: 120,
                height: 48,
                child: Center(child: Text('Section')),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Section')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));
    // Let the liquid entrance land before measuring rows at rest.
    await tester.pumpAndSettle();

    final renameRect = tester.getRect(find.text('Rename'));
    await gesture.moveTo(renameRect.center);
    await tester.pumpAndSettle();
    final pillFinder = find.byKey(const ValueKey('context-menu-hover-pill'));
    final renamePillRect = tester.getRect(pillFinder);
    expect(renamePillRect.center.dy, closeTo(renameRect.center.dy, 0.1));
    final decoration = tester.widget<DecoratedBox>(pillFinder).decoration;
    expect(
      decoration,
      isA<BoxDecoration>().having(
        (box) => box.borderRadius,
        'borderRadius',
        BorderRadius.circular(AmbleTheme.light.radiusPillFull),
      ),
    );

    final removeRect = tester.getRect(find.text('Remove'));
    await gesture.moveTo(removeRect.center);
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(pillFinder).dy,
      greaterThan(renamePillRect.center.dy),
    );

    await gesture.up();
    await tester.pump();
    expect(selectedAction, 'Remove');
  });
}
