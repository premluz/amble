import 'package:amble/core/tokens/delete_puff_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_context_dock.dart';
import 'package:amble/core/widgets/app_delete_puff.dart';
import 'package:amble/core/widgets/delete_puff_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seeded clouds match the preset and scale with the source control', () {
    const spec = DeletePuffSpec();
    final clouds = deletePuffCloudsAt(
      seconds: .9,
      sourceWidth: 40,
      spec: spec,
    ).toList();
    final repeated = deletePuffCloudsAt(
      seconds: .9,
      sourceWidth: 40,
      spec: spec,
    ).toList();
    final larger = deletePuffCloudsAt(
      seconds: .9,
      sourceWidth: 80,
      spec: spec,
    ).toList();

    expect(spec.duration, const Duration(milliseconds: 1250));
    expect(spec.count, 11);
    expect(spec.spread, 104);
    expect(spec.lift, 34);
    expect(spec.size, 22);
    expect(spec.curl, 22);
    expect(spec.stagger, .27);
    expect(spec.fadeStart, .325);
    expect(spec.scale, .85);
    expect(spec.seed, 15);
    expect(clouds, hasLength(11));
    expect(
      clouds.map((cloud) => cloud.center),
      repeated.map((cloud) => cloud.center),
    );
    expect(larger.first.center, clouds.first.center * 2);
    expect(larger.first.size, clouds.first.size * 2);
    expect(deletePuffCloudsAt(seconds: 1.25, sourceWidth: 40), isEmpty);
  });

  testWidgets('delete dock emits above its button and overlay outlives it', (
    tester,
  ) async {
    var fallbackPressed = false;
    var showButton = true;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Stack(
              children: [
                if (showButton)
                  Center(
                    child: AppContextDock(
                      configuration: AppContextDockConfiguration(
                        stateId: 'selection',
                        groups: [
                          AppContextGroup(
                            id: 'delete',
                            actions: [
                              AppContextAction(
                                id: 'remove-selected',
                                icon: Icons.delete_outline_rounded,
                                tooltip: 'Remove selected',
                                onPressed: () => fallbackPressed = true,
                                onPressedWithContext: (buttonContext) {
                                  AppDeletePuff.show(context: buttonContext);
                                  setState(() => showButton = false);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final buttonRect = tester.getRect(find.byTooltip('Remove selected'));
    await tester.tap(find.byTooltip('Remove selected'));
    await tester.pump();

    expect(fallbackPressed, isFalse);
    expect(find.byTooltip('Remove selected'), findsNothing);
    expect(find.byType(DeletePuffEffect), findsOneWidget);
    final effect = tester.widget<DeletePuffEffect>(
      find.byType(DeletePuffEffect),
    );
    expect(effect.origin, Offset(buttonRect.center.dx, buttonRect.top));
    await tester.pumpAndSettle();
    expect(find.byType(DeletePuffEffect), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion skips the delete overlay', (tester) async {
    await tester.pumpWidget(
      _app(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: _DeleteSource(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('delete-source')));
    await tester.pump();

    expect(find.byType(DeletePuffEffect), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [AmbleTheme.light]),
  home: child,
);

class _DeleteSource extends StatelessWidget {
  const _DeleteSource();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Builder(
        builder: (buttonContext) => IconButton(
          key: const Key('delete-source'),
          onPressed: () => AppDeletePuff.show(context: buttonContext),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ),
    ),
  );
}
