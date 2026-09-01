import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_undo_toast.dart';

void main() {
  testWidgets('AppUndoToast.show renders the message and Undo action', (
    tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    AppUndoToast.show(
      context: capturedContext,
      message: 'Created test task',
      onUndo: () {},
      duration: const Duration(seconds: 1),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Created test task'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Let the toast's own expiry timer/animation finish cleanly so the
    // test doesn't leave a pending timer behind.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
