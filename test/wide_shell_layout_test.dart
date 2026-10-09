import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/type_primitives.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/main.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/widgets/app_view_transition.dart';
import 'package:amble/features/calendar/desktop_calendar_toolbar.dart';
import 'package:amble/features/calendar/month_view.dart';
import 'package:amble/features/calendar/week_view.dart';
import 'package:amble/core/widgets/app_shell_chrome.dart';
import 'package:amble/core/widgets/app_shell_header.dart';
import 'package:amble/features/timeline/app_calendar_header.dart';
import 'package:amble/core/widgets/app_side_nav.dart';
import 'package:amble/core/widgets/app_top_nav.dart';
import 'package:amble/features/inbox/inbox_screen.dart';
import 'package:amble/features/task_detail/task_editor.dart';
import 'package:amble/features/task_detail/task_inspector_panel.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/section.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/section_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_section_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import 'support/fake_notification_service.dart';
import 'support/load_app_fonts.dart';
import 'support/seeded_category_box.dart';

/// The wide (desktop/web/iPad landscape) shell — requested directly: "two
/// panes on the sides: one left navigation... the central area will display
/// the content." Above ShellLayoutTokens.sideNavMinWindowWidth the top nav
/// becomes a left sidebar; below it the phone layout is unchanged. Harness
/// copied from edit_mode_hides_main_nav_test.dart (AmbleHome needs every
/// repository backed by a real box).
void main() {
  // Real DM Sans metrics: the default test font is far wider and would
  // overflow the top nav at true phone width on its own.
  setUpAll(loadAppFonts);

  late Box<Task> taskBox;
  late Box<dynamic> prefsBox;
  late Box<Category> categoryBox;
  late Box<Section> sectionBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<TaskTemplate> taskTemplateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_wide_shell');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    prefsBox = await Hive.openBox<dynamic>('test_prefs_$stamp');
    // AmbleHome mounts EVERY tab (Task view, Timeline, Inbox, Tracked,
    // Settings) at
    // once via IndexedStack, so every repository provider any of them
    // reads needs a real box — not just Task/preferences.
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
    sectionBox = await Hive.openBox<Section>('test_sections_$stamp');
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

  Future<ProviderContainer> pumpHome(WidgetTester tester) async {
    late ProviderContainer container;
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
          sectionRepositoryProvider.overrideWithValue(
            HiveSectionRepository(sectionBox),
          ),
          zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zoneBox)),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(trackedBehaviorBox),
          ),
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(taskTemplateBox),
          ),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: [AmbleTheme.light],
              ),
              home: const AmbleHome(),
            );
          },
        ),
      ),
    );
    // NOT pumpAndSettle: AmbleHome mounts every tab at once via
    // IndexedStack, and something in that combined tree never settles in
    // a plain widget-test environment (not Edit Mode's own wiggle, which
    // is off by default here — this happens even before it's ever
    // toggled on). Bounded pumps are enough to mount and paint everything
    // this file's own assertions need.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  void setWindow(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('a phone-width window keeps the top nav, no sidebar', (
    tester,
  ) async {
    setWindow(tester, const Size(390, 844));
    await pumpHome(tester);

    expect(find.byType(AppTopNav), findsOneWidget);
    expect(find.byType(AppSideNav), findsNothing);
  });

  testWidgets('a wide window swaps the top nav for a left sidebar beside the '
      'content', (tester) async {
    setWindow(tester, const Size(1280, 800));
    await pumpHome(tester);

    expect(find.byType(AppSideNav), findsOneWidget);
    expect(find.byType(AppTopNav), findsNothing);
    final sideNav = tester.getRect(find.byType(AppSideNav));
    expect(sideNav.left, 0);
    expect(sideNav.width, ShellLayoutTokens.sideNavWidth);
  });

  testWidgets('buttons and reading text are one size smaller in the wide '
      'layout, phones keep theirs', (tester) async {
    AmbleTheme themeAt(Finder inside) =>
        Theme.of(tester.element(inside)).extension<AmbleTheme>()!;

    setWindow(tester, const Size(390, 844));
    await pumpHome(tester);
    final phone = themeAt(find.byType(AppTopNav));
    expect(phone.sizeButtonMd, AmbleTheme.light.sizeButtonMd);
    expect(phone.textBody.fontSize, AmbleTheme.light.textBody.fontSize);

    setWindow(tester, const Size(1280, 800));
    await pumpHome(tester);
    for (final host in [AppSideNav, TaskInspectorPanel]) {
      final wide = themeAt(find.byType(host));
      expect(wide.sizeButtonMd, AmbleTheme.light.sizeButtonSm, reason: '$host');
      // Desktop reading sizes, one step down (references: ~13-14pt).
      expect(wide.textBody.fontSize, TypePrimitives.size2, reason: '$host');
      expect(wide.textLabel.fontSize, TypePrimitives.size1Point5);
    }
    // Small sizes already match the references and stay.
    expect(
      themeAt(find.byType(AppSideNav)).textCaption,
      AmbleTheme.light.textCaption,
    );
  });

  testWidgets('Days on desktop has a Day / Week / Month switch that swaps '
      'the page; phones have none', (tester) async {
    setWindow(tester, const Size(390, 844));
    await pumpHome(tester);
    expect(find.byType(DesktopCalendarToolbar), findsNothing);

    setWindow(tester, const Size(1280, 800));
    await pumpHome(tester);
    expect(find.byType(DesktopCalendarToolbar), findsOneWidget);
    expect(find.byType(WeekView), findsNothing);

    await tester.tap(find.text('Week'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(WeekView), findsOneWidget);

    await tester.tap(find.text('Month'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MonthView), findsOneWidget);
    expect(find.byType(WeekView), findsNothing);
  });

  testWidgets('with a top inset (macOS title bar) the panes reach the top '
      'edge and their content starts below it', (tester) async {
    setWindow(tester, const Size(1280, 800));
    tester.view.padding = const FakeViewPadding(top: 28);
    addTearDown(tester.view.resetPadding);
    await pumpHome(tester);

    final sideNav = tester.getRect(find.byType(AppSideNav));
    expect(sideNav.top, 0, reason: 'background runs to the window edge');
    final firstLabel = tester.getRect(
      find.descendant(of: find.byType(AppSideNav), matching: find.text('Days')),
    );
    expect(firstLabel.top, greaterThan(28));
    final toolbar = tester.getRect(find.byType(DesktopCalendarToolbar));
    expect(toolbar.top, greaterThanOrEqualTo(28));
  });

  testWidgets('the shell dividers are 1 point (as in Notion Calendar), softened', (
    tester,
  ) async {
    // A Retina window: 2 pixels per point, so one pixel is half a point.
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpHome(tester);

    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppSideNav),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final edge = (box.decoration as BoxDecoration).border! as Border;
    expect(edge.right.width, ShellLayoutTokens.lineWidth);
    expect(edge.right.width, lessThan(AmbleTheme.light.borderWidthHairline));
    expect(edge.right.color.a, lessThan(AmbleTheme.light.colorBorder.a));
  });

  testWidgets('pages fade by default; the slide is a developer toggle', (
    tester,
  ) async {
    setWindow(tester, const Size(390, 844));
    final container = await pumpHome(tester);
    bool slides() => tester
        .widgetList<AppViewTransition>(find.byType(AppViewTransition))
        .any((t) => t.slide);
    expect(slides(), isFalse);

    container.read(devPageSlideMotionProvider.notifier).set(true);
    await tester.pump();
    expect(slides(), isTrue);
  });

  testWidgets('the sidebar labels are left-aligned, not centered', (
    tester,
  ) async {
    setWindow(tester, const Size(1280, 800));
    await pumpHome(tester);

    final sideNav = tester.getRect(find.byType(AppSideNav));
    for (final label in ['Days', 'Things', 'Patterns']) {
      final text = find.descendant(
        of: find.byType(AppSideNav),
        matching: find.text(label),
      );
      expect(
        tester.getTopLeft(text).dx,
        sideNav.left + AmbleTheme.light.spacingLg,
        reason: label,
      );
    }
  });

  testWidgets('with no screen claiming the header, the wide layout reserves '
      'no empty band for it', (tester) async {
    setWindow(tester, const Size(1280, 800));
    await pumpHome(tester);

    expect(find.byType(AppShellHeader), findsNothing);
  });

  testWidgets('a screen claiming the header still gets it in the wide '
      'layout', (tester) async {
    setWindow(tester, const Size(1280, 800));
    await pumpHome(tester);
    final controller = AppShellChromeScope.maybeOf(
      tester.element(find.byType(AppCalendarHeader)),
    )!;

    controller.updateHeader('test', const Text('Claimed header'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(AppShellHeader), findsOneWidget);
    expect(find.text('Claimed header'), findsOneWidget);
  });

  testWidgets('the sidebar navigates like the top nav', (tester) async {
    setWindow(tester, const Size(1280, 800));
    await pumpHome(tester);
    expect(find.byType(InboxScreen), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(AppSideNav),
        matching: find.text('Things'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(InboxScreen), findsOneWidget);
  });

  testWidgets('tapping a task on the wide timeline edits it in the right '
      'panel', (tester) async {
    setWindow(tester, const Size(1280, 800));
    final now = DateTime.now();
    final task = Task.create(
      title: 'Standup',
      scheduledAt: DateTime(now.year, now.month, now.day, 10),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.runAsync(() => taskBox.put(task.id, task));
    await pumpHome(tester);

    await tester.tap(find.text('Standup').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final editor = find.descendant(
      of: find.byType(TaskInspectorPanel),
      matching: find.byType(TaskEditor),
    );
    expect(editor, findsOneWidget);
    final panel = tester.getRect(find.byType(TaskInspectorPanel));
    expect(panel.right, 1280);
    expect(panel.width, ShellLayoutTokens.inspectorWidth);
  });
}
