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

  testWidgets(
    'the primary button reads "Done", is pill-shaped and large, matching '
    "Task creation's own Done button (StepScaffold's primary action) "
    'exactly',
    (tester) async {
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
      expect(button.size, AppButtonSize.large);
    },
  );

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

      expect(find.text('New note'), findsNothing);
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

    expect(find.text('New note'), findsNothing);
    expect(box.values.single.title, 'Buy milk');
  });

  testWidgets('a fresh capture titles the sheet "New note"', (tester) async {
    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
    );
    showQuickCaptureSheet(navigatorKey.currentContext!);
    await tester.pumpAndSettle();

    expect(find.text('New note'), findsOneWidget);
    expect(find.text('Edit note'), findsNothing);
  });

  // Requested directly: tapping an existing Inbox card reuses this same
  // sheet, but in an EDIT mode that must actually read as different from
  // creating a new one — "New note"/"Edit note" plus pre-filled text.
  testWidgets(
    'editing an existing task titles the sheet "Edit note" and pre-fills '
    "its current title",
    (tester) async {
      final existing = Task(id: 'existing-1', title: 'Buy milk');
      await tester.runAsync(() => box.put(existing.id, existing));
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );

      showQuickCaptureSheet(navigatorKey.currentContext!, task: existing);
      await tester.pumpAndSettle();

      expect(find.text('Edit note'), findsOneWidget);
      expect(find.text('New note'), findsNothing);
      expect(find.text('Buy milk'), findsOneWidget);
      final button = tester.widget<AppButton>(find.byType(AppButton));
      expect(button.label, 'Save');
    },
  );

  testWidgets(
    'saving an edit renames the SAME task — no second task is created',
    (tester) async {
      final existing = Task(id: 'existing-1', title: 'Buy milk');
      await tester.runAsync(() => box.put(existing.id, existing));
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );

      showQuickCaptureSheet(navigatorKey.currentContext!, task: existing);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Buy oat milk');
      await _tapAndSettle(tester, find.text('Save'));

      expect(find.text('Edit note'), findsNothing);
      expect(box.values, hasLength(1));
      expect(box.values.single.id, 'existing-1');
      expect(box.values.single.title, 'Buy oat milk');
    },
  );

  // Requested directly: "add to inbox should be larger and should include
  // Close in the top right."
  testWidgets('the Close button dismisses the sheet without saving', (
    tester,
  ) async {
    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
    );
    showQuickCaptureSheet(navigatorKey.currentContext!);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Should not be saved');
    await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

    expect(find.text('New note'), findsNothing);
    expect(box.values, isEmpty);
  });

  // Reversed back (2026-09-09), requested directly: "since we added close
  // add note sheet has scrolling shouldn't have should automatically push
  // size to match content" — a brief AppSheetSize.half attempt (fixed
  // half-viewport height, always scrollable) was replaced back with the
  // original content-sized AppSheetSize.small once the Close button gave
  // the sheet its own way to feel roomy without a fixed height.
  testWidgets(
    'the sheet sizes to its own content — no fixed-height scroll wrapper',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsNothing);
    },
  );

  // Reported directly: "bottom overflowed" dev banner on this sheet.
  // Root cause: `showModalBottomSheet` caps a sheet at a fixed fraction
  // of the screen by default, regardless of the keyboard — a
  // content-sized sheet had no room left to grow into once the keyboard
  // opened, so the form's own `viewInsets.bottom` padding pushed it past
  // that cap. Simulates a real on-screen keyboard via `viewInsets` to
  // reproduce the exact reported condition.
  testWidgets(
    'opening the sheet with a keyboard-sized bottom inset does not overflow',
    (tester) async {
      // Simulates the OS keyboard's viewInsets — the real-world condition
      // that triggered the reported overflow (focusing the text field
      // pushes this inset in, on device).
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);

      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  // Reported directly: "when opening sheets with keyboard along seems
  // jittery not as smooth as without" — then, after a first attempt used
  // an AnimatedPadding, corrected directly: "do one motion best pattern."
  //
  // The sheet must be positioned DIRECTLY from the keyboard's own live
  // inset, so the two move as one motion with a single source of truth
  // (what native sheets on both platforms do). An AnimatedPadding here
  // would give the sheet its own separate curve and duration, leaving it
  // permanently trailing the keyboard.
  testWidgets('the keyboard inset is applied directly, not through its own '
      'animation — the sheet moves in lockstep with the keyboard', (
    tester,
  ) async {
    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
    );
    showQuickCaptureSheet(navigatorKey.currentContext!);
    await tester.pumpAndSettle();

    expect(
      find.byType(AnimatedPadding),
      findsNothing,
      reason:
          'an AnimatedPadding would run a SECOND animation against the '
          "keyboard's own, so the sheet trails it instead of moving "
          'with it',
    );
  });
  // Reported directly: "the new note sheet opens in two sequences: 1.
  // opens the actual sheet. 2. after a moment, the keyboard is pushing
  // it. While creating a task, the big sheet is opening without that kind
  // of delay. Both open at once."
  //
  // A previous version deferred focus until the sheet's slide-up had
  // finished, which is exactly what produced that two-step feel. The
  // field autofocuses as it mounts instead, matching the task-detail
  // sheet (the one that feels right), so the keyboard rises WITH the
  // sheet rather than after it.
  testWidgets('the text field takes focus as the sheet mounts, so the keyboard '
      'rises with it rather than in a second step', (tester) async {
    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
    );
    showQuickCaptureSheet(navigatorKey.currentContext!);

    // One frame in — mid-transition. Focus must ALREADY be requested,
    // so the keyboard is on its way up alongside the sheet.
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.autofocus,
      isTrue,
      reason:
          'deferring focus until after the slide-up is what made the '
          'sheet and keyboard arrive as two separate steps',
    );
    expect(field.focusNode?.hasFocus ?? false, isTrue);

    // Close before the test ends. AppSheet releases its transition
    // controller once the sheet animates OUT (see `_disposeWhenSettled`),
    // so a sheet left open at teardown would leak its ticker and trip
    // Flutter's "disposed with an active Ticker" assert — every other
    // test here already dismisses the sheet as part of what it asserts.
    await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
  });

  // Reported directly twice — "small sheet on tasks manage feels
  // sluggish", then "create note (still slow) sheet opening in manage
  // (tasks)". The first fix set only the DURATION (via a custom
  // transitionAnimationController); the sheet still felt slow because
  // Flutter shapes the motion with `Easing.legacyDecelerate` for both
  // directions regardless. `sheetAnimationStyle` sets curve AND duration,
  // which is what actually fixed it.
  testWidgets(
    'the sheet opens on the app\'s own curve and duration, not Flutter\'s '
    'slower bottom-sheet defaults',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pump();

      final route = ModalRoute.of(tester.element(find.byType(TextField)))!;
      expect(
        route.transitionDuration,
        AmbleTheme.light.motionNormal,
        reason:
            "Flutter's stock bottom-sheet duration is longer; this is the "
            'app-wide motionNormal',
      );
      expect(
        route.reverseTransitionDuration,
        AmbleTheme.light.motionFast,
        reason: 'dismissal is deliberately quicker than the entrance',
      );

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
    },
  );
}
