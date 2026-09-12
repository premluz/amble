import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/settings/settings_screen.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

// Same real-Hive-I/O discipline as every other widget test that exercises a
// save/network path — see docs/ERROR_LOG.md ("flutter test hangs
// indefinitely on real Hive disk I/O triggered from a widget interaction").
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pump();
    await Future<void>.delayed(Duration.zero);
    await tester.pumpAndSettle();
  });
}

void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_slack_settings');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final suffix = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$suffix');
    categoryBox = await openSeededCategoryBox('test_categories_$suffix');
    zoneBox = await Hive.openBox<Zone>('test_zones_$suffix');
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_$suffix',
    );
    preferencesBox = await Hive.openBox<dynamic>('test_preferences_$suffix');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await zoneBox.close();
    await trackedBehaviorBox.close();
    await preferencesBox.close();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    // Wider than exit_confirmation_test.dart's 390 — SettingsScreen renders
    // ThemeModeSelector's 3-chip Row, which overflows below ~460 logical px
    // (a real, pre-existing layout constraint unrelated to this panel; 480
    // is still an ordinary large-phone width and clears it with margin).
    tester.view.physicalSize = const Size(480, 960);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zoneBox)),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(trackedBehaviorBox),
          ),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(preferencesBox),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Slack now lives on its own pushed page (Settings restructured into
    // grouped buttons, each opening its own screen) rather than being an
    // inline section on the top-level Settings screen.
    await tester.ensureVisible(find.text('Slack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slack'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the webhook URL, display name, icon emoji fields, '
      'the enable toggle, and the test-send button', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Slack'), findsOneWidget);
    expect(find.text('Slack webhook URL'), findsOneWidget);
    expect(find.text('Display name (optional)'), findsOneWidget);
    expect(find.text('Icon emoji (optional, e.g. :sunrise:)'), findsOneWidget);
    expect(find.text('Send automatically each morning'), findsOneWidget);
    expect(find.text('Send test message now'), findsOneWidget);
    expect(
      find.textContaining(
        'Delivery time isn\'t guaranteed, especially on '
        'iOS',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Send test message now with an empty webhook URL shows the specific '
    'validation error, without making an HTTP call',
    (tester) async {
      await pumpSettings(tester);

      await _tapAndSettle(tester, find.text('Send test message now'));

      expect(find.text('No Slack webhook URL is set.'), findsOneWidget);
    },
  );

  testWidgets(
    'typing a webhook URL then Send test message now surfaces the real '
    'network result end to end',
    (tester) async {
      await pumpSettings(tester);

      final urlField = find.byType(TextField).first;
      await tester.ensureVisible(urlField);
      await tester.pumpAndSettle();
      await tester.enterText(
        urlField,
        'https://hooks.slack.com/services/T00/B00/XXX',
      );
      await tester.pumpAndSettle();

      await _tapAndSettle(tester, find.text('Send test message now'));

      // flutter_test's TestWidgetsFlutterBinding makes every real
      // HttpClient request return 400 rather than actually reaching the
      // network (a documented flutter_test behavior, not a bug in this
      // code) — so this exercises postToSlackWebhook's non-2xx branch end
      // to end, proving the UI surfaces SlackWebhookException.message via
      // _sendSlackTestMessage's own catch, not a raw/uncaught exception or
      // a silent no-op.
      expect(
        find.textContaining('Slack rejected the message (HTTP 400)'),
        findsOneWidget,
      );
    },
  );
}
