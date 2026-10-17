import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/task_state_tokens.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/hive_registrar.g.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// The "Show time (from-to)" dev switch is Timeline (spatial) only, and
/// shows a greyed-out start-end line under each task's title — requested
/// directly. Zone view and List-style rows no longer read it.
final _theme = AmbleTheme.light;

Task _task(String title, {int? offsetMinutes}) {
  final now = DateTime.now();
  final base = (now.hour * 60 + now.minute).clamp(60, 24 * 60 - 120);
  return Task.create(
    title: title,
    scheduledAt: DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(minutes: base + (offsetMinutes ?? 0))),
    durationMinutes: 30,
    categoryId: BuiltInCategoryIds.work,
  );
}

Widget _row({required bool timeUnderTitleVisible, bool compact = false}) =>
    MaterialApp(
      theme: ThemeData(extensions: [_theme]),
      home: Scaffold(
        body: TaskCapsuleTextRow(
          task: _task('Plan the week'),
          timeColumnWidth: 80,
          durationColumnWidth: 40,
          durationVisible: false,
          compactInlineLayout: compact,
          timeRangeVisible: false,
          timeUnderTitleVisible: timeUnderTitleVisible,
        ),
      ),
    );

Finder _rangeText() => find.descendant(
  of: find.byType(TaskCapsuleTextRow),
  matching: find.textContaining(' - '),
);

void main() {
  group('TaskCapsuleTextRow', () {
    testWidgets('shows no time line by default', (tester) async {
      await tester.pumpWidget(_row(timeUnderTitleVisible: false));
      expect(_rangeText(), findsNothing);
    });

    testWidgets('timeUnderTitleVisible puts a greyed range below the title', (
      tester,
    ) async {
      await tester.pumpWidget(_row(timeUnderTitleVisible: true));

      final range = tester.widget<Text>(_rangeText());
      expect(range.style?.color, _theme.colorTextSecondary);
      expect(
        range.style!.fontSize,
        lessThan(_theme.textTaskTitle.fontSize!),
        reason: 'one size rung under the title',
      );
      expect(range.style!.fontWeight, FontWeight.w300);
      expect(
        range.style!.fontWeight!.value,
        lessThan(TaskStateTokens.titleWeight.value),
      );
      final title = find.textContaining('Plan the week', findRichText: true);
      expect(
        tester.getTopLeft(_rangeText()).dy,
        greaterThan(tester.getBottomLeft(title).dy - 1),
      );
      expect(
        tester.getTopLeft(_rangeText()).dx,
        tester.getTopLeft(title).dx,
        reason: 'the range lines up with the title, not the checkbox',
      );
    });

    testWidgets('compactInlineLayout ignores timeUnderTitleVisible', (
      tester,
    ) async {
      await tester.pumpWidget(_row(timeUnderTitleVisible: true, compact: true));
      expect(_rangeText(), findsNothing);
    });
  });

  group('Timeline (spatial) view', () {
    late Box<Task> taskBox;
    late Box<Category> categoryBox;
    late Box<Zone> zoneBox;
    late Box<TrackedBehavior> trackedBehaviorBox;
    late Box<dynamic> preferencesBox;

    setUp(() async {
      Hive.init('./.dart_tool/test_hive_time_under_title');
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

    Future<ProviderContainer> pumpTimeline(
      WidgetTester tester,
      List<Task> tasks,
    ) async {
      await tester.runAsync(() async {
        for (final task in tasks) {
          await taskBox.put(task.id, task);
        }
      });
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(
              HiveTaskRepository(taskBox),
            ),
            categoryRepositoryProvider.overrideWithValue(
              HiveCategoryRepository(categoryBox),
            ),
            zoneRepositoryProvider.overrideWithValue(
              HiveZoneRepository(zoneBox),
            ),
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
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: ThemeData(useMaterial3: true, extensions: [_theme]),
                home: const Scaffold(
                  body: TimelineScreen(mode: TimelineDisplayMode.spatial),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 1000));
      return container;
    }

    Future<void> setSwitch(
      WidgetTester tester,
      ProviderContainer container,
      bool value,
    ) async {
      container
          .read(devTimelineTaskTimeRangeVisibleProvider.notifier)
          .set(value);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
    }

    testWidgets('the switch shows and hides the line under every title', (
      tester,
    ) async {
      final container = await pumpTimeline(tester, [_task('Solo')]);
      expect(_rangeText(), findsOneWidget, reason: 'on out of the box');

      await setSwitch(tester, container, false);
      expect(_rangeText(), findsNothing);

      await setSwitch(tester, container, true);
      expect(_rangeText(), findsOneWidget);
    });

    testWidgets('a taller label pushes the next one down by exactly its '
        'extra line', (tester) async {
      final container = await pumpTimeline(tester, [
        _task('First'),
        _task('Second'),
      ]);

      double gap() {
        final tops =
            find
                .byType(TaskCapsuleTextRow)
                .evaluate()
                .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy)
                .toList()
              ..sort();
        return tops[1] - tops[0];
      }

      await setSwitch(tester, container, false);
      final off = gap();
      await setSwitch(tester, container, true);
      final on = gap();

      expect(
        on - off,
        closeTo(TaskCapsuleTextRow.timeUnderTitleExtent(_theme), 0.5),
      );
    });
  });
}
