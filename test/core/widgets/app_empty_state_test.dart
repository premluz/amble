import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_empty_state.dart';

void main() {
  final theme = AmbleTheme.light;

  Future<void> pumpEmptyState(
    WidgetTester tester, {
    AppEmptyStateSize size = AppEmptyStateSize.md,
    Widget accessory = const Icon(Icons.self_improvement_rounded),
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: AppEmptyState(
            message: 'Nothing scheduled today',
            accessory: accessory,
            size: size,
          ),
        ),
      ),
    );
  }

  testWidgets('renders the message and the supplied accessory', (tester) async {
    await pumpEmptyState(tester);

    expect(find.text('Nothing scheduled today'), findsOneWidget);
    expect(find.byIcon(Icons.self_improvement_rounded), findsOneWidget);
  });

  testWidgets('sm, md and lg increase the accessory footprint', (tester) async {
    Future<double> accessorySizeFor(AppEmptyStateSize size) async {
      await pumpEmptyState(tester, size: size);
      return tester
          .getSize(find.byKey(const ValueKey('app-empty-state-accessory')))
          .width;
    }

    final sm = await accessorySizeFor(AppEmptyStateSize.sm);
    final md = await accessorySizeFor(AppEmptyStateSize.md);
    final lg = await accessorySizeFor(AppEmptyStateSize.lg);

    expect(sm, lessThan(md));
    expect(md, lessThan(lg));
  });

  testWidgets('uses one subdued color for the accessory and message', (
    tester,
  ) async {
    await pumpEmptyState(tester);

    final iconTheme = tester.widget<IconTheme>(
      find.descendant(
        of: find.byType(AppEmptyState),
        matching: find.byType(IconTheme),
      ),
    );
    final message = tester.widget<Text>(find.text('Nothing scheduled today'));

    expect(iconTheme.data.color, theme.colorTextSecondary);
    expect(message.style?.color, theme.colorTextSecondary);
  });

  testWidgets('accepts an image-like accessory without changing the layout', (
    tester,
  ) async {
    await pumpEmptyState(
      tester,
      accessory: const ColoredBox(color: Colors.blue),
    );

    expect(
      find.descendant(
        of: find.byType(AppEmptyState),
        matching: find.byType(ColoredBox),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('app-empty-state-accessory'))),
      Size(theme.spacingXl * 1.5, theme.spacingXl * 1.5),
    );
  });

  testWidgets('fills and centers when used as a stack overlay', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: const Center(
          child: SizedBox(
            width: 320,
            height: 480,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AppEmptyState(
                    message: 'Nothing scheduled today',
                    accessory: Icon(Icons.self_improvement_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(AppEmptyState)), const Size(320, 480));
  });
}
