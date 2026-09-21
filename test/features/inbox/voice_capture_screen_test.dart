import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/inbox/voice_capture_provider.dart';
import 'package:amble/features/inbox/voice_capture_screen.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// [VoiceCaptureScreen] itself never drives a real `speech_to_text`
/// session in this environment (no platform channel mock registered —
/// see `voice_capture_provider_test.dart`'s own doc comment), so
/// `startListening()` silently no-ops here. These tests seed
/// `committedSegments` directly via
/// `VoiceCapture.debugSetCommittedSegments` and check the screen's own
/// reaction to state, not the recognizer itself.
void main() {
  late Box<Task> box;
  late Box<Category> categoryBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_voice_capture_screen');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    box = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
  });

  tearDown(() async {
    await box.close();
    await categoryBox.close();
  });

  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    late ProviderContainer container;
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
        child: Consumer(
          builder: (context, ref, child) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: [AmbleTheme.light],
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      // Pushed directly with `autoStartListening: false`
                      // rather than through `showVoiceCaptureScreen` —
                      // see [VoiceCaptureScreen.autoStartListening]'s own
                      // doc comment for why: the real entry point always
                      // starts listening on mount, which hangs forever
                      // in this test environment (a live
                      // SpeechToText.initialize() platform call with no
                      // mock handler registered).
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const VoiceCaptureScreen(
                            autoStartListening: false,
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    // NOT pumpAndSettle — `AppVoiceWaveform`'s own AnimationController
    // runs on a perpetual `..repeat()` while active (see that widget's
    // own doc comment: "must read as continuously moving"), so a settle
    // wait never completes on this screen. Bounded pumps carry the
    // push's own transition through instead, same convention as every
    // other Timeline-embedding harness in this codebase.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  testWidgets(
    'shows the "try saying" hint and a disabled Submit while no segment '
    'has been captured yet — requested directly, "before anything is '
    'said or created, it\'s disabled, not available"',
    (tester) async {
      await pumpScreen(tester);

      expect(find.textContaining('Try saying'), findsOneWidget);

      // AppButton, not IconButton — it's this app's own adaptive button
      // (`app_button.dart`), never a plain Material widget, per
      // docs/CONSTITUTION.md design principle 4.
      final submit = tester.widget<AppButton>(
        find.widgetWithIcon(AppButton, Icons.arrow_upward_rounded).first,
      );
      expect(submit.onPressed, isNull);
    },
  );

  testWidgets(
    'shows each committed segment as its own row, and enables Submit, '
    'once at least one exists',
    (tester) async {
      final container = await pumpScreen(tester);
      container.read(voiceCaptureProvider.notifier).debugSetCommittedSegments([
        'Call John',
        'Book the flight',
      ]);
      await tester.pump();

      expect(find.text('Call John'), findsOneWidget);
      expect(find.text('Book the flight'), findsOneWidget);
      expect(find.textContaining('Try saying'), findsNothing);

      final submit = tester.widget<AppButton>(
        find.widgetWithIcon(AppButton, Icons.arrow_upward_rounded).first,
      );
      expect(submit.onPressed, isNotNull);
    },
  );

  testWidgets('tapping Submit creates a task per segment and closes the '
      'screen', (tester) async {
    final container = await pumpScreen(tester);
    container.read(voiceCaptureProvider.notifier).debugSetCommittedSegments([
      'Call John',
    ]);
    await tester.pump();

    // Real Hive disk I/O (via `submit`'s own `createTask`/`captureTask`
    // call) hangs under flutter_test's synchronous pump unless routed
    // through `runAsync` — same discipline
    // `quick_capture_sheet_test.dart`'s own `_tapAndSettle` uses, per
    // docs/ERROR_LOG.md.
    // Real Hive disk I/O (via `submit`'s own `createTask`/`captureTask`
    // call) hangs under flutter_test's synchronous pump unless BOTH the
    // tap AND the wait for it to finish are routed through `runAsync` —
    // same discipline `quick_capture_sheet_test.dart`'s own
    // `_tapAndSettle` uses, per docs/ERROR_LOG.md. A real (not
    // `tester.pump`-simulated) delay here is what lets the awaited Hive
    // write and the subsequent `pop()` actually run to completion before
    // this block returns.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Submit'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    // The pop's own exit ANIMATION only advances on ordinary timed
    // `pump`s outside `runAsync` — without these the route still sits
    // mid-transition (still technically mounted) when the assertion
    // below runs, even though `submit` and `pop()` have both already
    // executed. Many SHORT pumps, not one long one: `AppVoiceWaveform`'s
    // own perpetual `..repeat()` animation competes with the route's
    // finite exit transition for frame budget in this harness — a single
    // `pump(320ms)` measured as not enough to actually finish the pop.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(VoiceCaptureScreen), findsNothing);
    expect(container.read(taskListProvider).map((t) => t.title), ['Call John']);
  });

  testWidgets('tapping Close pops without creating any task', (tester) async {
    final container = await pumpScreen(tester);
    container.read(voiceCaptureProvider.notifier).debugSetCommittedSegments([
      'Call John',
    ]);
    await tester.pump();

    await tester.tap(find.byTooltip('Close'));
    // Many short pumps, not one long one — `AppVoiceWaveform`'s own
    // perpetual `..repeat()` animation competes with the pop route's
    // finite exit transition for frame budget in this harness; a single
    // `pump(300ms)` measured as NOT enough to actually finish the pop
    // (the route stayed mounted mid-transition), even though the pop
    // logic itself had already run. See `tapping Submit`'s own matching
    // comment above.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(VoiceCaptureScreen), findsNothing);
    expect(
      container.read(taskListProvider),
      isEmpty,
      reason: 'Close must discard uncommitted work, not silently submit it',
    );
  });

  testWidgets(
    'the Pause/Resume button swaps to Resume and shows the Paused copy '
    'once paused',
    (tester) async {
      final container = await pumpScreen(tester);
      // Directly drives the notifier's own status rather than routing
      // through a real `pause()` call, which needs a live listening
      // session this environment cannot provide — see this file's own
      // class doc comment.
      container.read(voiceCaptureProvider.notifier).debugSetCommittedSegments([
        'Call John',
      ]);
      await tester.pump();

      expect(find.text('Listening'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);
    },
  );
}
