import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/main.dart';
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

import 'support/fake_notification_service.dart';
import 'support/seeded_category_box.dart';

/// Covers the bottom nav pill's restyle — requested directly, from a
/// reference screenshot: "match aesthetics and nav is just 5 items + its
/// outside" (i.e. the "+" is no longer part of this bar — see
/// `AppFloatingCreateButton`) and a circular selected-tab indicator using
/// a surface color rather than the accent: "match and not accent color
/// like ours now but more surface (next in order)."
void main() {
  late Box<Task> taskBox;
  late Box<dynamic> prefsBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<TaskTemplate> taskTemplateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_floating_nav_pill');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    prefsBox = await Hive.openBox<dynamic>('test_prefs_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
    zoneBox = await Hive.openBox<Zone>('test_zones_$stamp');
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_$stamp',
    );
    taskTemplateBox = await Hive.openBox<TaskTemplate>(
      'test_task_templates_$stamp',
    );
  });

  tearDown(() async {
    await taskBox.deleteFromDisk();
    await prefsBox.deleteFromDisk();
    await categoryBox.deleteFromDisk();
    await zoneBox.deleteFromDisk();
    await trackedBehaviorBox.deleteFromDisk();
    await taskTemplateBox.deleteFromDisk();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(prefsBox),
          ),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zoneBox)),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(trackedBehaviorBox),
          ),
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(taskTemplateBox),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const AmbleHome(),
        ),
      ),
    );
    // See edit_mode_hides_main_nav_test.dart's own pumpHome for why this
    // isn't pumpAndSettle — the combined IndexedStack tree never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  DecoratedBox navPaneDecoration(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(
        find.ancestor(
          of: find.byType(NavigationBar),
          matching: find.byType(DecoratedBox),
        ),
      )
      .first;

  testWidgets('the nav pane is rounded on all four corners, not just the '
      'bottom pair', (tester) async {
    await pumpHome(tester);

    final decoration = navPaneDecoration(tester).decoration as BoxDecoration;
    final radius = decoration.borderRadius!.resolve(TextDirection.ltr);

    expect(radius.topLeft, isNot(Radius.zero));
    expect(radius.topRight, isNot(Radius.zero));
    expect(radius.bottomLeft, isNot(Radius.zero));
    expect(radius.bottomRight, isNot(Radius.zero));
    expect(
      radius.topLeft,
      radius.bottomLeft,
      reason: 'a genuine pill has one uniform radius, not a top/bottom split',
    );
  });

  testWidgets('the pane is FULLY round (stadium-shaped ends), not just softly '
      'rounded corners — reported directly against the reference: "make it '
      'full round not just round corners"', (tester) async {
    await pumpHome(tester);

    final decoration = navPaneDecoration(tester).decoration as BoxDecoration;
    final radius = decoration.borderRadius!.resolve(TextDirection.ltr);
    final renderBox = tester.renderObject<RenderBox>(
      find.ancestor(
        of: find.byType(NavigationBar),
        matching: find.byType(DecoratedBox),
      ),
    );

    // A radius at or past half the pane's own height paints a true
    // stadium end (Flutter clamps it there), not a merely-rounded
    // corner short of that.
    expect(radius.topLeft.y, greaterThanOrEqualTo(renderBox.size.height / 2));
  });

  testWidgets(
    'the pane is shorter than Material\'s own 80px NavigationBar default '
    '— reported directly: "it is too big height"',
    (tester) async {
      await pumpHome(tester);

      final navigationBar = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );

      expect(navigationBar.height, isNotNull);
      expect(navigationBar.height, lessThan(80));
    },
  );

  testWidgets('the nav pane is margined on every side, not flush to any '
      'screen edge', (tester) async {
    await pumpHome(tester);

    final renderBox = tester.renderObject<RenderBox>(
      find.ancestor(
        of: find.byType(NavigationBar),
        matching: find.byType(DecoratedBox),
      ),
    );
    final topLeft = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;

    expect(topLeft.dx, greaterThan(0));
    expect(topLeft.dy + size.height, lessThan(screenSize.height));
  });

  testWidgets('the selected tab shows a circular indicator filled with a '
      'surface color, not the accent color', (tester) async {
    await pumpHome(tester);
    final theme = AmbleTheme.light;

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(navigationBar.indicatorShape, isA<CircleBorder>());
    // `colorSurfaceField`, not `colorSurfaceSecondary` (corrected
    // 2026-09-12, follow-up report: "wrong surface (selected has darker
    // surface > should have ligher)" — `colorSurfaceSecondary` is
    // actually DARKER than this pane's own `colorSurfaceOverlay` fill in
    // dark mode, the exact inversion reported).
    expect(navigationBar.indicatorColor, theme.colorSurfaceField);
    expect(
      navigationBar.indicatorColor,
      isNot(theme.colorAccent),
      reason: 'confirmed directly: surface color, not the accent',
    );
  });

  testWidgets(
    'the selected tab\'s icon renders at the SAME size as an unselected '
    'one — a since-reverted attempt to grow the selected icon stretched '
    'the circular indicator into an oval to fit it, reported directly: '
    '"active icon should not enlarge... ask was to change color, not '
    '[size]"',
    (tester) async {
      await pumpHome(tester);

      // Task view (index 0) is the default selected tab; Timeline
      // (index 1, Icons.grid_view_rounded) is unselected.
      final selectedContext = tester.element(
        find.byIcon(Icons.view_timeline_outlined),
      );
      final unselectedContext = tester.element(
        find.byIcon(Icons.grid_view_rounded),
      );
      final selectedSize = IconTheme.of(selectedContext).size!;
      final unselectedSize = IconTheme.of(unselectedContext).size!;

      expect(selectedSize, unselectedSize);
    },
  );

  test('in dark mode, the selected indicator is LIGHTER than the pane '
      'behind it — not darker', () {
    final theme = AmbleTheme.dark;
    // HSLColor is a convenient, order-preserving lightness comparator
    // for two flat (non-gradient) sRGB colors — exactly what's being
    // compared here.
    final paneLightness = HSLColor.fromColor(theme.colorSurfaceOverlay)
        .lightness;
    final indicatorLightness = HSLColor.fromColor(theme.colorSurfaceField)
        .lightness;

    expect(
      indicatorLightness,
      greaterThan(paneLightness),
      reason:
          'the reported bug: the indicator painted DARKER than the pane '
          'it sits on, inverting the "selected = lighter" cue',
    );
  });
}
