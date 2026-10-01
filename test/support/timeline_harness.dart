import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/clock_provider.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
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

import 'fake_notification_service.dart';
import 'seeded_category_box.dart';

/// A spatial Timeline over real Hive boxes, with "now" pinned so fixtures
/// land on screen at any time of day.
class TimelineHarness {
  TimelineHarness._(
    this.taskBox,
    this._categoryBox,
    this._zoneBox,
    this._behaviorBox,
    this._preferencesBox,
    this.now,
  );

  static Future<TimelineHarness> open(
    String dir, {
    required DateTime now,
  }) async {
    Hive.init('./.dart_tool/$dir');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    final suffix = DateTime.now().microsecondsSinceEpoch;
    return TimelineHarness._(
      await Hive.openBox<Task>('test_tasks_$suffix'),
      await openSeededCategoryBox('test_categories_$suffix'),
      await Hive.openBox<Zone>('test_zones_$suffix'),
      await Hive.openBox<TrackedBehavior>('test_tb_$suffix'),
      await Hive.openBox<dynamic>('test_preferences_$suffix'),
      now,
    );
  }

  final Box<Task> taskBox;
  final Box<Category> _categoryBox;
  final Box<Zone> _zoneBox;
  final Box<TrackedBehavior> _behaviorBox;
  final Box<dynamic> _preferencesBox;
  final DateTime now;

  Future<void> close() async {
    await taskBox.close();
    await _categoryBox.close();
    await _zoneBox.close();
    await _behaviorBox.close();
    await _preferencesBox.close();
  }

  /// Bounded pumps, never pumpAndSettle — edit mode animates perpetually.
  Future<void> pump(
    WidgetTester tester,
    List<Task> tasks, {
    bool multiSelect = false,
  }) async {
    await tester.runAsync(() async {
      for (final task in tasks) {
        await taskBox.put(task.id, task);
      }
    });
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => now),
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(_categoryBox),
          ),
          zoneRepositoryProvider.overrideWithValue(
            HiveZoneRepository(_zoneBox),
          ),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(_behaviorBox),
          ),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(_preferencesBox),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          editModeEnabledProvider.overrideWith(() => _FixedEdit(multiSelect)),
          devMultiTaskEditModeProvider.overrideWith(
            () => _FixedMulti(multiSelect),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(
            body: TimelineScreen(mode: TimelineDisplayMode.spatial),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

class _FixedEdit extends EditModeEnabled {
  _FixedEdit(this._on);
  final bool _on;
  @override
  bool build() => _on;
}

class _FixedMulti extends DevMultiTaskEditMode {
  _FixedMulti(this._on);
  final bool _on;
  @override
  bool build() => _on;
}
