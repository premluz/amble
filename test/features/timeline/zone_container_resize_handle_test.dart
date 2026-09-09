import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/features/timeline/zone_container_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';

void main() {
  final zone = Zone.create(
    title: 'Morning ritual',
    startMinutes: 7 * 60,
    endMinutes: 12 * 60,
  );
  final task = Task.create(
    title: 'Deep work',
    scheduledAt: DateTime(2026, 9, 4, 9),
    durationMinutes: 60,
    categoryId: BuiltInCategoryIds.work,
  );
  final stackKey = GlobalKey();

  Future<void> pump(
    WidgetTester tester, {
    required bool editModeEnabled,
    GestureDragEndCallback? onResizeTopEnd,
    GestureDragEndCallback? onResizeBottomEnd,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: SizedBox(
            key: stackKey,
            width: 400,
            child: ZoneContainerBlock(
              theme: AmbleTheme.light,
              zone: zone,
              tasks: [task],
              categoriesById: const {},
              stackAncestorKey: stackKey,
              editModeEnabled: editModeEnabled,
              onResizeTopEnd: onResizeTopEnd,
              onResizeBottomEnd: onResizeBottomEnd,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('no handles render outside Edit Mode', (tester) async {
    await pump(
      tester,
      editModeEnabled: false,
      onResizeTopEnd: (_) {},
      onResizeBottomEnd: (_) {},
    );

    expect(find.byType(ResizeHandle), findsNothing);
  });

  testWidgets('no handles render in Edit Mode with no callbacks wired', (
    tester,
  ) async {
    await pump(tester, editModeEnabled: true);

    expect(find.byType(ResizeHandle), findsNothing);
  });

  testWidgets('both a top and a bottom handle render when Edit Mode is on '
      'and both callbacks are wired', (tester) async {
    await pump(
      tester,
      editModeEnabled: true,
      onResizeTopEnd: (_) {},
      onResizeBottomEnd: (_) {},
    );

    expect(find.byType(ResizeHandle), findsNWidgets(2));
  });

  testWidgets('only the top handle renders when only the top callback is '
      'wired', (tester) async {
    await pump(tester, editModeEnabled: true, onResizeTopEnd: (_) {});

    expect(find.byType(ResizeHandle), findsOneWidget);
  });

  testWidgets('dragging the bottom handle fires only the bottom callback, '
      'never the top one', (tester) async {
    var topEnded = false;
    var bottomEnded = false;
    await pump(
      tester,
      editModeEnabled: true,
      onResizeTopEnd: (_) => topEnded = true,
      onResizeBottomEnd: (_) => bottomEnded = true,
    );

    await tester.drag(find.byType(ResizeHandle).last, const Offset(0, 20));
    await tester.pump();

    expect(bottomEnded, isTrue);
    expect(topEnded, isFalse);
  });
}
