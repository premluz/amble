import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_mic_button.dart';
import 'package:amble/core/widgets/app_sheet_handle.dart';
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
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
    await Future<void>.delayed(Duration.zero);
    await tester.pumpAndSettle();
  });
}

// The header's Done button — a small HeaderCircleButton (check icon), not
// the large AppButton "Done"/"Save" pill Task creation uses. See
// quick_capture_sheet.dart's own class doc comment for why (2026-09-21:
// no title text, Close/mic/Done collapsed into one header row).
final _doneButton = find.byIcon(Icons.check_rounded);

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
    'the sheet has no title text — Close, mic and Done live in one header '
    'row instead',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      expect(find.text('New note'), findsNothing);
      expect(find.text('Edit note'), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byType(AppMicButton), findsOneWidget);
      expect(_doneButton, findsOneWidget);

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
    },
  );

  testWidgets('the mic button renders secondary (non-primary), not accent', (
    tester,
  ) async {
    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
    );
    showQuickCaptureSheet(navigatorKey.currentContext!);
    await tester.pumpAndSettle();

    final mic = tester.widget<AppMicButton>(find.byType(AppMicButton));
    expect(mic.isPrimary, isFalse);

    await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
  });

  // Requested directly: "voice record should be same size as done."
  testWidgets(
    'the mic button is sized to match the Done button (theme.spacingXl)',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      final mic = tester.widget<AppMicButton>(find.byType(AppMicButton));
      expect(mic.size, AmbleTheme.light.spacingXl);

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
    },
  );

  // Requested directly: "we should have sheet 'handle' that user can drag
  // down to close."
  testWidgets('a drag handle is shown above the header row', (tester) async {
    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
    );
    showQuickCaptureSheet(navigatorKey.currentContext!);
    await tester.pumpAndSettle();

    expect(find.byType(AppSheetHandle), findsOneWidget);

    await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
  });

  testWidgets(
    'dragging the handle down far enough closes the sheet without saving',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Should not be saved');
      await tester.runAsync(() async {
        await tester.drag(
          find.byType(AppSheetHandle),
          const Offset(0, 200),
        );
        await tester.pump();
        await Future<void>.delayed(Duration.zero);
        await tester.pumpAndSettle();
      });

      expect(_doneButton, findsNothing);
      expect(box.values, isEmpty);
    },
  );

  testWidgets(
    'a short drag on the handle does not close the sheet',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.drag(find.byType(AppSheetHandle), const Offset(0, 4));
        await tester.pump();
        await Future<void>.delayed(Duration.zero);
        await tester.pumpAndSettle();
      });

      expect(_doneButton, findsOneWidget);

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
    },
  );

  // Requested directly: "when tapping add on keyboard the sheet and
  // keyboard collapses and expands but it should remain open." Root
  // cause: EditableText unconditionally unfocuses on TextInputAction.done
  // unless `onEditingComplete` is provided — the fix is that override,
  // not anything reachable by asserting the field's focus AFTER the fact
  // (which the existing keep-open test already does, but can't catch a
  // transient drop that resolves before the assertion runs).
  testWidgets(
    'the field provides a no-op onEditingComplete, suppressing the '
    'framework default that would otherwise unfocus on every keyboard '
    'submit',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.onEditingComplete, isNotNull);

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
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

      await _tapAndSettle(tester, _doneButton);

      expect(_doneButton, findsNothing);
      expect(box.values, isEmpty);
    },
  );

  // 2026-09-22 — the header's Done button now behaves EXACTLY like the
  // keyboard's own submit (docs/DESIGN_SYSTEM.md's "Sheets" section,
  // requested directly: a sheet's primary action "should act the same
  // way as Submit in keyboard... but not close modal"), so tapping Done
  // with text keeps the sheet open rather than closing it. Only the
  // Close button or dragging the handle down actually closes this sheet
  // once something has been typed.
  testWidgets(
    'tapping Done with text captures it and keeps the sheet open, cleared '
    'and focused for another entry',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Buy milk');
      await _tapAndSettle(tester, _doneButton);

      expect(_doneButton, findsOneWidget);
      expect(box.values.single.title, 'Buy milk');

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    },
  );

  // Requested directly: submitting from the KEYBOARD's own "done" key
  // creates the task but leaves the sheet open, ready for another entry —
  // now identical to tapping the header's own Done button (see the test
  // above).
  testWidgets(
    'submitting from the keyboard captures the task but keeps the sheet '
    'open, cleared and focused for another entry',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Buy milk');
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await Future<void>.delayed(Duration.zero);
        await tester.pumpAndSettle();
      });

      // Sheet is still open — Done/mic/Close are all still present.
      expect(_doneButton, findsOneWidget);
      expect(box.values.single.title, 'Buy milk');

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(field.focusNode?.hasFocus ?? false, isTrue);

      // A second capture in the same session, still without closing —
      // exactly the "multiple tasks being added" behavior requested.
      await tester.enterText(find.byType(TextField), 'Buy eggs');
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await Future<void>.delayed(Duration.zero);
        await tester.pumpAndSettle();
      });

      expect(_doneButton, findsOneWidget);
      expect(box.values.map((t) => t.title), containsAll(['Buy milk', 'Buy eggs']));

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
    },
  );

  testWidgets(
    'submitting an empty title from the keyboard still closes the sheet — '
    'nothing to keep it open for',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await Future<void>.delayed(Duration.zero);
        await tester.pumpAndSettle();
      });

      expect(_doneButton, findsNothing);
      expect(box.values, isEmpty);
    },
  );

  // Requested directly: tapping an existing Inbox card reuses this same
  // sheet, but in an EDIT mode — pre-filled text and a different hint,
  // even with no title text to distinguish the two any more.
  testWidgets(
    'editing an existing task pre-fills its current title',
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

      expect(find.text('Buy milk'), findsOneWidget);

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
    },
  );

  testWidgets(
    'saving an edit renames the SAME task — no second task is created, and '
    'the sheet closes even via the keyboard',
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
      await tester.runAsync(() async {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await Future<void>.delayed(Duration.zero);
        await tester.pumpAndSettle();
      });

      expect(_doneButton, findsNothing);
      expect(box.values, hasLength(1));
      expect(box.values.single.id, 'existing-1');
      expect(box.values.single.title, 'Buy oat milk');
    },
  );

  // Requested directly: "add to inbox should be larger and should include
  // Close in the top right." (Close later moved top-LEFT — 2026-09-21.)
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

    expect(_doneButton, findsNothing);
    expect(box.values, isEmpty);
  });

  // Reversed back (2026-09-09), requested directly: "since we added close
  // add note sheet has scrolling shouldn't have should automatically push
  // size to match content" — a brief AppSheetSize.half attempt (fixed
  // half-viewport height, always scrollable) was replaced back with the
  // original content-sized AppSheetSize.small once the Close button gave
  // the sheet its own way to feel roomy without a fixed height.
  // **2026-09-23 — no longer asserts zero `SingleChildScrollView`
  // widgets.** `AppSheet` now wraps every `AppSheetSize.small` sheet
  // (this one included) in an unconstrained-until-the-viewport
  // `SingleChildScrollView` as an overflow safety net — see that class's
  // own doc comment; the old assertion was really checking "not a FIXED
  // half-viewport height, sizes to content" (per this test's own history
  // above), which the new scroll view still satisfies (it never engages
  // — never actually scrolls — for ordinary short content, only for
  // content genuinely taller than the viewport). Asserts that real
  // intent directly instead: the sheet's own rendered height tracks its
  // content, not a fixed fraction of the screen.
  testWidgets(
    'the sheet sizes to its own content — not a fixed half-viewport height',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final sheetHeight = tester.getSize(find.byType(SingleChildScrollView)).height;

      expect(
        sheetHeight,
        lessThan(screenHeight * 0.5),
        reason:
            'a short form like this sheet should size well under half the '
            'screen, not stretch to fill a fixed fraction of it',
      );

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
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

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
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

    await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
  });
  // Reported directly: "the new note sheet opens in two sequences: 1.
  // opens the actual sheet. 2. after a moment, the keyboard is pushing
  // it. While creating a task, the big sheet is opening without that kind
  // of delay. Both open at once."
  //
  // A previous version deferred focus until the sheet's slide-up had
  // finished, which is exactly what produced that two-step feel. The
  // field autofocuses as it mounts instead — this part is UNCHANGED by
  // the later `autofocusesKeyboard` mechanism below: the focus REQUEST
  // still fires immediately on mount, every frame. What changed
  // (2026-09-23, twice the same day) is the sheet's own VISIBLE slide-in
  // timing — first to a strict "wait the full keyboard-settle span, then
  // play," then reversed again the same day to an OVERLAP (the slide now
  // starts partway through that span, both finishing together) once the
  // strict version was reported as still reading like two discrete steps
  // rather than one gesture — see [AppSheet]'s own doc comment for the
  // final shape.
  testWidgets('the text field takes focus as the sheet mounts, so the '
      'keyboard is already rising before the sheet\'s own slide-in even '
      'starts', (tester) async {
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

  // Route duration controls the barrier/grace period. Native IME progress
  // independently drives the sheet surface; closing retains the shared slide.
  testWidgets(
    'the barrier uses the keyboard grace period and dismissal uses the slide duration',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pump();

      final theme = AmbleTheme.light;
      final route = ModalRoute.of(tester.element(find.byType(TextField)))!;
      expect(route.transitionDuration, theme.motionKeyboardSettle);
      expect(route.reverseTransitionDuration, theme.motionSheetSlide);

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
    },
  );

  // The actual behavioral guarantee behind the timing above.
  //
  // Desktop widget tests have no native IME; verify the non-Android
  // grace-period path here. Native progress is covered by app_sheet_motion_test.
  testWidgets(
    'without native IME events, the sheet slides after its grace period',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
      );
      showQuickCaptureSheet(navigatorKey.currentContext!);
      await tester.pump();

      final theme = AmbleTheme.light;
      final handleFinder = find.byType(AppSheetHandle);
      final headStart = theme.motionKeyboardSettle;

      // Still inside the head-start window: the sheet hasn't started
      // moving yet.
      await tester.pump(headStart * 0.5);
      final headStartTop = tester.getTopLeft(handleFinder).dy;
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        headStartTop,
        greaterThanOrEqualTo(screenHeight),
        reason:
            'still inside the head-start window — the sheet must not '
            'have started sliding into view yet',
      );

      // Just past the head start, into the slide itself: now visibly
      // on-screen and moving.
      await tester.pump(headStart);
      await tester.pump();
      await tester.pump(theme.motionSheetSlide * 0.5);
      final midSlideTop = tester.getTopLeft(handleFinder).dy;
      expect(
        midSlideTop,
        lessThan(headStartTop),
        reason: 'the head start has elapsed — the slide should now be moving',
      );

      // Fully settled.
      await tester.pumpAndSettle();
      final settledTop = tester.getTopLeft(handleFinder).dy;
      expect(
        settledTop,
        lessThan(midSlideTop),
        reason: 'the sheet keeps moving to its final on-screen position',
      );

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));
    },
  );
}
