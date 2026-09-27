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

  // Regression, reported directly: "when multiselecting zones and delete,
  // it deletes 1 or 2 sometimes but not all at once selected." Root cause:
  // an action newly added to an ALREADY-VISIBLE dock (e.g. a Remove button
  // appearing next to an existing Save the moment a selection becomes
  // non-empty) starts `entering: true` and stayed wrapped in
  // `IgnorePointer` for the whole ~200-270ms staggered fade-in — so a tap
  // landing in that window (an entirely ordinary "select then immediately
  // tap Remove" gesture, not an edge case) was silently swallowed with no
  // feedback. Fixed by excluding `entering` from the interactivity gates
  // (focus/semantics/pointer) while keeping it for the opacity fade —
  // see `_AppContextDockLayout`'s own doc comment on that call site.
  testWidgets('a newly-added action in an ALREADY-VISIBLE dock is tappable '
      'immediately — not blocked for the whole entrance fade', (tester) async {
    var removes = 0;
    final initial = dockConfiguration(onSave: () {});
    await tester.pumpWidget(dockHost(initial));
    await tester.pumpAndSettle();

    // Selection becomes non-empty: Remove appears alongside the
    // already-visible Save. Deliberately only ONE bare `pump()` after
    // this — no settle — mirroring a user who selects several items
    // and taps Remove right away, well before the ~200-270ms entrance
    // animation would otherwise finish.
    await tester.pumpWidget(
      dockHost(dockConfiguration(onSave: () {}, onRemove: () => removes++)),
    );
    await tester.pump();

    expect(
      find.byTooltip('Remove'),
      findsOneWidget,
      reason: 'the new action must exist in the tree immediately',
    );
    await tester.tap(find.byTooltip('Remove'));
    expect(
      removes,
      1,
      reason:
          'a tap on a newly-entering action must register immediately, '
          'not be swallowed by IgnorePointer until its fade finishes',
    );
  });

  testWidgets(
    'an EXITING action (removed from the configuration) is NOT tappable '
    'during its own fade-out — only newly-entering actions skip the gate',
    (tester) async {
      var saves = 0;
      var removes = 0;
      await tester.pumpWidget(
        dockHost(
          dockConfiguration(onSave: () => saves++, onRemove: () => removes++),
        ),
      );
      await tester.pumpAndSettle();

      // Selection clears: Remove is about to exit.
      await tester.pumpWidget(
        dockHost(dockConfiguration(onSave: () => saves++)),
      );
      await tester.pump();

      // Still present in the tree mid-fade-out (present: false, but not
      // yet pruned), but must not be tappable.
      final removeFinder = find.byTooltip('Remove');
      if (removeFinder.evaluate().isNotEmpty) {
        await tester.tap(removeFinder, warnIfMissed: false);
      }
      expect(
        removes,
        0,
        reason: 'an exiting (no longer present) action must stay inert',
      );
    },
  );
}
