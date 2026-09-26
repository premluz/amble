import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_layout_reveal.dart';
import 'package:amble/features/zone_grid/zone_grid_screen.dart';
import 'package:amble/features/zone_grid/zone_grid_tab.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/core/widgets/app_tab_switch.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/features/timeline/zone_background_block.dart';
import 'package:amble/features/timeline/current_time_indicator.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// Regression coverage for a real bug, reported directly against a
/// screenshot: "label of task on spatial view is higher than middle of
/// the smallest task and feels misaligned, should be aligned with the
/// icon, so same padding top as icon has within pill" — the SPATIAL
/// Timeline's own split-layout title (`_DayTimelineState`'s
/// `computeLabelTops` sweep + `Positioned(top: labelOffset)` in
/// `timeline_screen.dart`), not `TaskCapsuleTitleAlignmentTest`'s
/// existing coverage of `TaskCapsuleBlock`'s own NON-split internal
/// title, a different code path entirely.
///
/// Root cause: the icon is centered inside its own `badgeSize`-tall
/// square (`_PillGlyph`, `task_capsule_block.dart`), so its visual center
/// sits at `badgeSize / 2` from the pill's top — an earlier session moved
/// it there from flush-with-the-top without a matching adjustment to the
/// label's own base `top: 0` offset in `timeline_screen.dart`, leaving
/// the label aligned to where the icon USED to sit.
void main() {
  late ValueNotifier<TimelineDisplayMode> mode;
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late Box<TaskTemplate> templateBox;

  setUp(() async {
    mode = ValueNotifier(TimelineDisplayMode.spatial);
    Hive.init('./.dart_tool/test_hive_spatial_label_icon_alignment');
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
    templateBox = await Hive.openBox<TaskTemplate>('test_templates_$suffix');
  });

  tearDown(() async {
    mode.dispose();
    await taskBox.close();
    await categoryBox.close();
    await zoneBox.close();
    await trackedBehaviorBox.close();
    await preferencesBox.close();
    await templateBox.close();
  });

  void expectZoneEdges(WidgetTester tester) {
    final theme = AmbleTheme.light;
    final bandFinder = find.byType(ZoneBackgroundBlock);
    final band = tester.getRect(bandFinder);
    final context = tester.element(bandFinder);
    final firstIcon = find
        .byIcon(TablerIcons.briefcase)
        .evaluate()
        .map(
          (element) => tester.getRect(find.byWidget(element.widget)).center.dx,
        )
        .reduce((a, b) => a < b ? a : b);
    expect(
      tester.getRect(find.byType(CurrentTimeIndicator)).right,
      tester.view.physicalSize.width,
    );
    expect(band.left, theme.timelineZoneLeftFor(context));
    expect(
      band.right,
      tester.view.physicalSize.width - theme.spacingScreenPadding,
    );
    expect(firstIcon - theme.sizeTaskBadge / 2 - band.left, theme.spacingLg);
  }

  Future<void> pumpTimeline(WidgetTester tester, {required Task task}) async {
    await tester.runAsync(() async {
      await taskBox.put(task.id, task);
      final startMinutes = task.scheduledAt!.hour * 60;
      await zoneBox.put(
        'zone',
        Zone(
          id: 'zone',
          title: 'Test zone',
          startMinutes: startMinutes,
          endMinutes: startMinutes + 60,
        ),
      );
    });

    tester.view.physicalSize = const Size(430, 932);
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
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(templateBox),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: ValueListenableBuilder<TimelineDisplayMode>(
            valueListenable: mode,
            builder: (context, value, child) =>
                Scaffold(body: TimelineScreen(mode: value)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expectZoneEdges(tester);
  }

  // Anchored near `now` so the task is guaranteed to be scrolled into view
  // — the spatial Timeline centers on the current time, same convention
  // `armed_edit_task_test.dart` and others already use.
  DateTime todayAt(int hour) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour.clamp(1, 22));
  }

  // The shared `openSeededCategoryBox` built-ins are legacy/emoji-only (no
  // `iconCodePoint`), so `_PillGlyph` would render a `Text` glyph for them,
  // not the `Icon` this bug is actually about. Seed one real Tabler-icon
  // category directly so the test exercises the same glyph type the
  // screenshot showed.
  Future<Category> seedIconCategory(Box<Category> box) async {
    final category = Category.create(
      name: 'Focus',
      colorToken: 2,
      emoji: '💼',
      iconCodePoint: TablerIcons.briefcase.codePoint,
    );
    await box.put(category.id, category);
    return category;
  }

  testWidgets('both day views reveal only after positioning', (tester) async {
    late Category category;
    await tester.runAsync(() async {
      category = await seedIconCategory(categoryBox);
    });
    final task = Task.create(
      title: 'Switch test',
      scheduledAt: todayAt(DateTime.now().hour),
      durationMinutes: 15,
      categoryId: category.id,
    );
    await pumpTimeline(tester, task: task);
    for (var roundTrip = 0; roundTrip < 2; roundTrip++) {
      mode.value = TimelineDisplayMode.zone;
      await tester.pump();
      final zoneReveal = find.byKey(const ValueKey('positioned-zone-content'));
      expect(
        tester.widget<Opacity>(zoneReveal).opacity,
        roundTrip == 0 ? 0 : 1,
      );
      await tester.pump();
      expect(tester.widget<Opacity>(zoneReveal).opacity, 1);
      final zonePosition = tester.getRect(zoneReveal);
      await tester.pumpAndSettle();
      expect(tester.getRect(zoneReveal), zonePosition);
      mode.value = TimelineDisplayMode.spatial;
      await tester.pump();
      final reveal = find.byKey(const ValueKey('positioned-day-content'));
      // The spatial slot is retained by AppViewTransition, so returning to
      // it preserves its restored scroll/layout state instead of replaying
      // the mount reveal on every view switch.
      expect(tester.widget<Opacity>(reveal).opacity, 1);
      await tester.pump();
      expect(tester.widget<Opacity>(reveal).opacity, 1);
      final positioned = tester.getRect(find.byType(ZoneBackgroundBlock));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(ZoneBackgroundBlock)), positioned);
    }
  });

  testWidgets(
    'Edit entry reveals the positioned task timeline without a jump',
    (tester) async {
      late Category category;
      await tester.runAsync(() async {
        category = await seedIconCategory(categoryBox);
      });
      final task = Task.create(
        title: 'Edit entry',
        scheduledAt: todayAt(DateTime.now().hour),
        durationMinutes: 30,
        categoryId: category.id,
      );
      await pumpTimeline(tester, task: task);
      final dayContext = tester.element(find.byType(TimelineScreen));
      final dayState = ProviderScope.containerOf(dayContext);
      showEditScreen(dayContext);
      await tester.pump();
      await tester.pump();
      final reveal = find
          .descendant(
            of: find.byType(AppLayoutReveal),
            matching: find.byType(Opacity),
          )
          .first;
      expect(tester.widget<Opacity>(reveal).opacity, 0);
      final editorState = ProviderScope.containerOf(
        tester.element(find.byType(ZoneGridScreen)),
      );
      expect(editorState.read(editModeEnabledProvider), isTrue);
      expect(dayState.read(editModeEnabledProvider), isFalse);
      final tabs = find.byType(AppTabSwitch<ZoneGridTab>);
      final tabPosition = tester.getRect(tabs);
      await tester.pump();
      final zone = find
          .descendant(
            of: find.byType(ZoneGridScreen),
            matching: find.byType(ZoneBackgroundBlock),
          )
          .first;
      final positioned = tester.getRect(zone);
      await tester.pump(AmbleTheme.light.motionFast * .5);
      expect(
        tester.widget<Opacity>(reveal).opacity,
        allOf(greaterThan(0), lessThan(1)),
      );
      expect(tester.getRect(zone), positioned);
      expect(tester.getRect(tabs), tabPosition);
      expect(dayState.read(editModeEnabledProvider), isFalse);
      await tester.pump(AmbleTheme.light.motionFast);
      expect(tester.widget<Opacity>(reveal).opacity, 1);
      expect(tester.getRect(zone), positioned);
      expect(tester.getRect(tabs), tabPosition);
      Navigator.of(tester.element(find.byType(ZoneGridScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ZoneGridScreen), findsNothing);
    },
  );

  testWidgets('on the smallest (badge-floored) task, the title sits vertically '
      'centered against the icon, not above it', (tester) async {
    late Category category;
    await tester.runAsync(() async {
      category = await seedIconCategory(categoryBox);
    });
    final task = Task.create(
      title: 'Audiobook',
      scheduledAt: todayAt(DateTime.now().hour),
      // Short enough to hit the badge-size floor at the default zoom —
      // the exact case the report screenshotted.
      durationMinutes: 5,
      categoryId: category.id,
    );
    await pumpTimeline(tester, task: task);

    final icon = tester.getRect(find.byIcon(TablerIcons.briefcase).first);
    final title = tester.getRect(find.text('Audiobook'));
    expect(
      title.left - icon.center.dx,
      AmbleTheme.light.sizeTaskBadge / 2 + AmbleTheme.light.spacingLg,
    );

    // The title's own vertical center must land within 2px of the
    // icon's center. Before this fix the gap on a badge-floored pill
    // was `_labelBaseOffset` itself (~4.2px at default tokens) — a 2px
    // tolerance is tight enough to catch that regression reappearing
    // while still absorbing ordinary text-layout rounding.
    expect(
      (title.center.dy - icon.center.dy).abs(),
      lessThan(2.0),
      reason:
          'title center ${title.center.dy}, icon center ${icon.center.dy} '
          '— expected the title to read as level with the icon, not '
          'noticeably above it',
    );
  });

  testWidgets('the title never sits ABOVE the icon\'s own top edge', (
    tester,
  ) async {
    late Category category;
    await tester.runAsync(() async {
      category = await seedIconCategory(categoryBox);
    });
    final task = Task.create(
      title: 'Walk',
      scheduledAt: todayAt(DateTime.now().hour),
      durationMinutes: 5,
      categoryId: category.id,
    );
    final overlapping = Task.create(
      title: 'Concurrent task',
      scheduledAt: task.scheduledAt!,
      durationMinutes: 15,
      categoryId: category.id,
    );
    await tester.runAsync(() => taskBox.put(overlapping.id, overlapping));
    await pumpTimeline(tester, task: task);

    final icons = find.byIcon(TablerIcons.briefcase);
    final icon = tester.getRect(icons.first);
    final title = tester.getRect(find.text('Walk'));
    final rightmostCenter = icons
        .evaluate()
        .map(
          (element) => tester.getRect(find.byWidget(element.widget)).center.dx,
        )
        .reduce((a, b) => a > b ? a : b);
    expect(
      title.left - rightmostCenter,
      AmbleTheme.light.sizeTaskBadge / 2 + AmbleTheme.light.spacingLg,
    );
    expect(tester.getRect(find.text('Concurrent task')).left, title.left);

    // The icon glyph itself is inset within its own badge square (see
    // `_PillGlyph`), so its own `top` sits a few px below the pill's
    // top edge already — a couple of those same px above the icon's
    // `top` is not a bug. The real regression this guards against
    // (measured before this fix) was tens of px, a title reading as
    // sitting a whole line or more above the icon it should track.
    expect(
      title.top,
      greaterThanOrEqualTo(icon.top - title.height),
      reason:
          'a misaligned label reads as sitting ABOVE the icon it should '
          'line up with — title.top=${title.top}, icon.top=${icon.top}',
    );
  });
}
