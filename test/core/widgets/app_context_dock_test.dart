import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_context_dock.dart';
import 'package:amble/core/widgets/app_dock_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget dockHost(AppContextDockConfiguration configuration) => MaterialApp(
  theme: ThemeData(extensions: [AmbleTheme.light]),
  home: Scaffold(body: AppContextDock(configuration: configuration)),
);

AppContextDockConfiguration dockConfiguration({
  required VoidCallback onSave,
  VoidCallback? onRemove,
  VoidCallback? onArchive,
  bool saveSelected = false,
}) => AppContextDockConfiguration(
  stateId: 'selection',
  groups: [
    AppContextGroup(
      id: 'primary',
      actions: [
        AppContextAction(
          id: 'save',
          icon: Icons.check,
          tooltip: 'Save',
          selected: saveSelected,
          onPressed: onSave,
        ),
        if (onRemove != null)
          AppContextAction(
            id: 'remove',
            icon: Icons.delete_outline,
            tooltip: 'Remove',
            destructive: true,
            onPressed: onRemove,
          ),
      ],
    ),
    if (onArchive != null)
      AppContextGroup(
        id: 'secondary',
        actions: [
          AppContextAction(
            id: 'archive',
            icon: Icons.archive_outlined,
            tooltip: 'Archive',
            onPressed: onArchive,
          ),
        ],
      ),
  ],
);

void main() {
  testWidgets('retains actions and animates additions and removals', (
    tester,
  ) async {
    var saves = 0;
    var archives = 0;
    final initial = dockConfiguration(onSave: () => saves++, onRemove: () {});
    await tester.pumpWidget(dockHost(initial));

    final saveElement = tester.element(find.byKey(const ValueKey('save')));
    await tester.tap(find.byTooltip('Save'));
    expect(saves, 1);

    await tester.pumpWidget(
      dockHost(
        dockConfiguration(
          onSave: () => saves++,
          onArchive: () => archives++,
          saveSelected: true,
        ),
      ),
    );
    expect(
      tester.element(find.byKey(const ValueKey('save'))),
      same(saveElement),
    );
    expect(find.byTooltip('Remove'), findsOneWidget);
    expect(find.byTooltip('Archive'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove'), findsNothing);
    await tester.tap(find.byTooltip('Archive'));
    expect(archives, 1);
    expect(
      tester
          .widget<AppDockIconButton>(
            find.ancestor(
              of: find.byTooltip('Save'),
              matching: find.byType(AppDockIconButton),
            ),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('disabled actions expose no tap callback', (tester) async {
    var taps = 0;
    final configuration = AppContextDockConfiguration(
      stateId: 'disabled',
      groups: [
        AppContextGroup(
          id: 'primary',
          actions: [
            AppContextAction(
              id: 'disabled',
              icon: Icons.block,
              tooltip: 'Disabled',
              enabled: false,
              onPressed: () => taps++,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(dockHost(configuration));
    await tester.tap(find.byTooltip('Disabled'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('retained action keeps its element when its group changes', (
    tester,
  ) async {
    final initial = AppContextDockConfiguration(
      stateId: 'day',
      groups: [
        AppContextGroup(
          id: 'views',
          actions: [
            AppContextAction(
              id: 'retained',
              icon: Icons.view_agenda_outlined,
              tooltip: 'Retained',
              onPressed: () {},
            ),
          ],
        ),
        AppContextGroup(
          id: 'edit',
          actions: [
            AppContextAction(
              id: 'edit',
              icon: Icons.edit_outlined,
              tooltip: 'Edit',
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(dockHost(initial));
    final retainedElement = tester.element(
      find.byKey(const ValueKey('retained')),
    );

    await tester.pumpWidget(
      dockHost(
        AppContextDockConfiguration(
          stateId: 'selection',
          groups: [
            AppContextGroup(
              id: 'edit',
              actions: [
                AppContextAction(
                  id: 'edit',
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onPressed: () {},
                ),
              ],
            ),
            AppContextGroup(
              id: 'selection',
              actions: [
                AppContextAction(
                  id: 'retained',
                  icon: Icons.view_agenda_outlined,
                  tooltip: 'Retained',
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(
      tester.element(find.byKey(const ValueKey('retained'))),
      same(retainedElement),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Retained'), findsOneWidget);
  });
}
