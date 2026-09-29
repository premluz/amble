import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_context_menu.dart';
import 'package:amble/core/widgets/app_floating_surface.dart';
import 'package:amble/core/widgets/app_view_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _noop() {}

void main() {
  testWidgets('menu sits above shell chrome and closes when a route changes', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hostKey = GlobalKey<_NestedShellHostState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [AppContextMenuNavigatorObserver()],
        theme: ThemeData(extensions: [AmbleTheme.light]),
        home: _NestedShellHost(key: hostKey),
      ),
    );

    hostKey.currentState!.setAnchor(const Offset(200, 790));
    await tester.tap(find.byKey(const ValueKey('open-menu')));
    await tester.pumpAndSettle();
    final panel = find.ancestor(
      of: find.text('Remove'),
      matching: find.byType(AppFloatingSurface),
    );
    expect(
      tester.getRect(panel).overlaps(tester.getRect(find.byKey(_bottomChrome))),
      isTrue,
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(hostKey.currentState!.selectedAction, 'Remove');
    expect(hostKey.currentState!.bottomTapCount, 0);

    hostKey.currentState!.setAnchor(const Offset(200, 10));
    await tester.tap(find.byKey(const ValueKey('open-menu')));
    await tester.pumpAndSettle();
    expect(
      tester
          .getRect(
            find.ancestor(
              of: find.text('Rename'),
              matching: find.byType(AppFloatingSurface),
            ),
          )
          .overlaps(tester.getRect(find.byKey(_topChrome))),
      isTrue,
    );
    hostKey.currentState!.pushNextPage();
    await tester.pumpAndSettle();
    expect(find.text('Next page'), findsOneWidget);
    expect(find.text('Rename'), findsNothing);
  });

  testWidgets('menu closes when an AppViewTransition changes view ID', (
    tester,
  ) async {
    final hostKey = GlobalKey<_ViewHostState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [AmbleTheme.light]),
        home: _ViewHost(key: hostKey),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-view-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);

    hostKey.currentState!.changeView();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('second view'), findsOneWidget);
    expect(find.text('Rename'), findsNothing);
  });
}

const _topChrome = ValueKey('top-chrome');
const _bottomChrome = ValueKey('bottom-chrome');

class _NestedShellHost extends StatefulWidget {
  const _NestedShellHost({super.key});

  @override
  State<_NestedShellHost> createState() => _NestedShellHostState();
}

class _NestedShellHostState extends State<_NestedShellHost> {
  Offset _anchor = const Offset(200, 790);
  String? selectedAction;
  int bottomTapCount = 0;

  void setAnchor(Offset anchor) => _anchor = anchor;

  void pushNextPage() {
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Next page'))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Top navigation'), key: _topChrome),
    body: Navigator(
      observers: [AppContextMenuNavigatorObserver()],
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (context) => Center(
          child: TextButton(
            key: const ValueKey('open-menu'),
            onPressed: () => AppContextMenu.showAt(
              context,
              position: _anchor,
              actions: [
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
              ],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
    bottomNavigationBar: SizedBox(
      key: _bottomChrome,
      height: 80,
      child: TextButton(
        onPressed: () => bottomTapCount++,
        child: const Text('Bottom toolbar'),
      ),
    ),
  );
}

class _ViewHost extends StatefulWidget {
  const _ViewHost({super.key});

  @override
  State<_ViewHost> createState() => _ViewHostState();
}

class _ViewHostState extends State<_ViewHost> {
  String _viewId = 'first';

  void changeView() => setState(() => _viewId = 'second');

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        AppViewTransition(
          viewId: _viewId,
          child: Center(child: Text('$_viewId view')),
        ),
        Center(
          child: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-view-menu'),
              onPressed: () => AppContextMenu.showAt(
                context,
                position: const Offset(200, 300),
                actions: [
                  AppContextMenuAction(
                    icon: Icons.edit_outlined,
                    label: 'Rename',
                    onTap: _noop,
                  ),
                ],
              ),
              child: const Text('Open view menu'),
            ),
          ),
        ),
      ],
    ),
  );
}
