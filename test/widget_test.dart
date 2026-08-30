import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/main.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import 'support/fake_notification_service.dart';

void main() {
  late Box<Task> box;
  late Box<dynamic> prefsBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_widget');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    box = await Hive.openBox<Task>('test_tasks_$stamp');
    // AmbleApp reads the theme-mode preference at build time, so this box
    // has to exist for the same reason the task box does.
    prefsBox = await Hive.openBox<dynamic>('test_prefs_$stamp');
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await prefsBox.deleteFromDisk();
  });

  testWidgets('Amble app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(prefsBox),
          ),
        ],
        child: const AmbleApp(),
      ),
    );

    expect(find.byType(AmbleApp), findsOneWidget);
  });
}
