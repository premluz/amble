import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/inbox/quick_capture_sheet.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

// Same runAsync discipline as exit_confirmation_test.dart — Hive's real
// disk I/O hangs under flutter_test's synchronous pump unless routed
// through WidgetTester.runAsync. See docs/ERROR_LOG.md.
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pump();
    await Future<void>.delayed(Duration.zero);
    await tester.pumpAndSettle();
  });
}

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester, {
  required Box<Task> box,
  required Box<Category> categoryBox,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(categoryBox),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  return navigatorKey;
}

void main() {
  late Box<Task> box;
  late Box<Category> categoryBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_quick_capture');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_tasks_${DateTime.now().microsecondsSinceEpoch}',
    );
    categoryBox = await openSeededCategoryBox(
      'test_categories_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.close();
    await categoryBox.close();
  });

  testWidgets('the primary button reads "Done" and is pill-shaped, matching '
      "Task creation's own Done button", (tester) async {
    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
    );
    showQuickCaptureSheet(navigatorKey.currentContext!);
    await tester.pumpAndSettle();

    expect(find.text('Add'), findsNothing);
    final button = tester.widget<AppButton>(find.byType(AppButton));
    expect(button.label, 'Done');
    expect(button.shape, AppButtonShape.pill);
  });

  testWidgets(
    'tapping Done with empty input closes the sheet without capturing '
    'anything — matches Task creation\'s stage-1 Done on an empty name',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      await _tapAndSettle(tester, find.text('Done'));

      expect(find.text('Add to Inbox'), findsNothing);
      expect(box.values, isEmpty);
    },
  );

  testWidgets('tapping Done with text captures it and closes the sheet', (
    tester,
  ) async {
    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
    );
    showQuickCaptureSheet(navigatorKey.currentContext!);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Buy milk');
    await _tapAndSettle(tester, find.text('Done'));

    expect(find.text('Add to Inbox'), findsNothing);
    expect(box.values.single.title, 'Buy milk');
  });
}
