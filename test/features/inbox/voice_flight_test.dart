import 'package:amble/core/tokens/voice_mode_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/task_state_tokens.dart';
import 'package:amble/core/widgets/app_depth.dart';
import 'package:amble/core/widgets/app_dock_primitives.dart';
import 'package:amble/core/widgets/app_floating_create_button.dart';
import 'package:amble/features/inbox/inbox_screen.dart';
import 'package:amble/features/inbox/task_list_row.dart';
import 'package:amble/features/inbox/voice_capture_provider.dart';
import 'package:amble/features/inbox/voice_capture_screen.dart';
import 'package:amble/features/inbox/voice_flight.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/section.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/section_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_section_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';
import '../../support/seeded_section_box.dart';

/// Covers the three things requested directly for Inbox notes: "notes in
/// inbox should have created timestamp if not have already... and recent
/// should be on top... and all tab should have subtle label separating
/// day created's (Mono space font) Today / Yesterday / Wednesday / Fri 12
/// Oct." `dayLabel` itself (the label TEXT for each relative day) is unit
/// tested in isolation in `test/shared/services/day_label_test.dart` —
/// this file covers the Inbox's own sort order and where headers actually
/// land in the rendered list.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Section> sectionBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_voice_flight');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
    sectionBox = await openSectionBox('test_sections_$stamp');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await sectionBox.close();
  });

  testWidgets('submitting voice mode recedes the screen while each new Inbox '
      'task flies into its row', (tester) async {
    await tester.runAsync(() async {
      final existing = Task(
        id: const Uuid().v4(),
        title: 'Existing',
        categoryId: BuiltInCategoryIds.general,
        createdAt: DateTime.now(),
      );
      await taskBox.put(existing.id, existing);
    });
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          sectionRepositoryProvider.overrideWithValue(
            HiveSectionRepository(sectionBox),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: ThemeData(extensions: [AmbleTheme.light]),
              home: Builder(
                builder: (context) => Scaffold(
                  body: const InboxScreen(),
                  floatingActionButton: TextButton(
                    // autoStartListening: false — a real SpeechToText
                    // initialise never completes under flutter_test.
                    onPressed: () => pushVoiceModeRoute(
                      context,
                      (_) =>
                          const VoiceCaptureScreen(autoStartListening: false),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // A task with no label yet ("General") wears the unassigned tone, as
    // on the timeline — not a label swatch.
    final existing = find.ancestor(
      of: find.text('Existing'),
      matching: find.byType(TaskListRow),
    );
    expect(
      tester.widget<TaskListRow>(existing).pillColor,
      TaskStateTokens.unlabeledFill(AmbleTheme.light),
    );
    // The Inbox mic is the same glass pane as the Day dock's buttons.
    expect(
      find.ancestor(
        of: find.byTooltip('Speak your tasks'),
        matching: find.byType(AppDockSurface),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    // The page under voice mode follows its transition (the rows sweep),
    // and the "+" submerges while the close pane takes its place.
    expect(container.read(voiceModeSweepProvider), isNotNull);
    await tester.pump();
    expect(
      tester
          .widget<AppFloatingCreateButton>(find.byType(AppFloatingCreateButton))
          .visible,
      isFalse,
    );
    // Let the entrance (the toolbar morphing out of the mic) finish.
    await tester.pump(VoiceModeTokens.enterDuration);
    container.read(voiceCaptureProvider.notifier).debugSetCommittedSegments([
      'Buy oat milk',
    ]);
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Submit'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });

    // Mid-exit: the screen is still receding, and the task is in flight —
    // a copy of it that belongs to neither screen (the hero shuttle).
    // Hero flights begin in the frame after the pop.
    await tester.pump(const Duration(milliseconds: 16));
    // Early in its flight the task's pill is still emerging from depth,
    // like a typed task's, while its title (already on screen) is shown.
    await tester.pump(VoiceModeTokens.exitDuration * .06);
    bool inFlight(Element e) =>
        e.findAncestorWidgetOfExactType<VoiceCaptureScreen>() == null &&
        e.findAncestorWidgetOfExactType<InboxScreen>() == null;
    final pill = find.byType(AppDepthShape).evaluate().where(inFlight);
    expect(pill, isNotEmpty, reason: 'the flying card carries its pill');
    final pillOpacity = tester
        .widget<Opacity>(
          find
              .descendant(
                of: find.byWidget(pill.first.widget),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(pillOpacity, lessThan(1), reason: 'the pill is emerging');
    final title = find.text('Buy oat milk').evaluate().where(inFlight).single;
    final fades = <double>[];
    title.visitAncestorElements((e) {
      final w = e.widget;
      if (w is FadeTransition) fades.add(w.opacity.value);
      return true;
    });
    expect(fades.where((o) => o < 1), isEmpty, reason: 'title shown');

    await tester.pump(VoiceModeTokens.exitDuration * .24);
    expect(find.byType(VoiceCaptureScreen), findsOneWidget);
    final flying = find.byWidgetPredicate(
      (w) => w is Text && w.data == 'Buy oat milk',
    );
    final outsideBoth = flying.evaluate().where(
      (e) =>
          e.findAncestorWidgetOfExactType<VoiceCaptureScreen>() == null &&
          e.findAncestorWidgetOfExactType<InboxScreen>() == null,
    );
    expect(outsideBoth, isNotEmpty, reason: 'the task is flying');

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(VoiceCaptureScreen), findsNothing);
    expect(
      tester
          .widget<AppFloatingCreateButton>(find.byType(AppFloatingCreateButton))
          .visible,
      isTrue,
      reason: 'the "+" is back',
    );
    expect(
      container.read(voiceModeSweepProvider),
      isNull,
      reason: 'released once voice mode has fully closed',
    );
    final created = container
        .read(taskListProvider)
        .singleWhere((t) => t.title == 'Buy oat milk');
    expect(container.read(voiceArrivalsProvider), {created.id});
    expect(
      find.descendant(
        of: find.byType(InboxScreen),
        matching: find.text('Buy oat milk'),
      ),
      findsOneWidget,
      reason: 'landed in its Inbox row',
    );
  });

  test('several tasks land one after another: a later one waits its turn, '
      'and the wait is capped', () {
    const begin = Rect.fromLTWH(0, 0, 10, 10);
    const end = Rect.fromLTWH(0, 100, 10, 10);
    final first = voiceFlightTween(0)(begin, end);
    final third = voiceFlightTween(2)(begin, end);
    final late = voiceFlightTween(99)(begin, end);
    final waitThird = 2 * VoiceModeTokens.flightStagger;

    expect(
      first.transform(waitThird)?.top,
      greaterThan(0),
      reason: 'first is off',
    );
    expect(third.transform(waitThird)?.top, 0, reason: 'third still waiting');
    expect(third.transform(1), end);
    expect(
      late.transform(VoiceModeTokens.flightMaxDelay + .01)?.top,
      greaterThan(0),
      reason: 'even the last one has time to land',
    );
  });

  test('on exit the page is back early — by the time the toolbar is home — '
      'and each flight has landed before the exit ends', () {
    final route = AnimationController(
      vsync: const TestVSync(),
      value: 1,
      duration: const Duration(milliseconds: 100),
    );
    addTearDown(route.dispose);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(voiceModeSweepProvider.notifier).follow(route);
    final sweep = container.read(voiceModeSweepProvider)!;
    route.reverse(from: 1);
    route.value = 1 - VoiceModeTokens.revealShare;
    expect(sweep.value, 0, reason: 'rows fully back');
    route.value = .9;
    expect(sweep.value, greaterThan(0), reason: 'but not instantly');

    const begin = Rect.fromLTWH(0, 0, 10, 10);
    const end = Rect.fromLTWH(0, 100, 10, 10);
    final last = voiceFlightTween(99)(begin, end);
    expect(last.transform(VoiceModeTokens.flightLandShare), end);
  });
}
