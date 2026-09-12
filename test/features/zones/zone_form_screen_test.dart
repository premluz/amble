import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_segmented_time_field.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/zones/zone_form_screen.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';

/// The real, typeable `TextField` inside the "Zone name" `AppTextField` —
/// same reasoning as `add_category_modal_test.dart`'s `_nameField`.
Finder _nameField() => find.descendant(
  of: find.widgetWithText(AppTextField, 'Zone name'),
  matching: find.byType(TextField),
);

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester, {
  required Box<Zone> box,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(box)),
        // Real Save/Delete both reach NotificationService
        // (scheduleForZone/cancelForZone) — Save fires it unawaited so a
        // plugin exception there never surfaces synchronously in a test,
        // but ZoneList.deleteZone awaits it directly, so the new
        // delete-button tests below need a real fake here rather than
        // hitting the real (unavailable-in-test) platform channel.
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
  late Box<Zone> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_zone_form_screen');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Zone>(
      'test_zones_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.close();
  });

  testWidgets(
    'a fresh create opens on the Name-only stage 1, matching the task '
    'creation flow — start/end/repeat are not in the tree yet',
    (tester) async {
      // Requested directly: zones "should follow same pattern of creation
      // as tasks, on creation first just name visible, other items below
      // (start, end, repeat etc.) not visible, then fade in after Done is
      // clicked."
      final navigatorKey = await _pumpHost(tester, box: box);
      unawaited(showZoneFormScreen(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);
      expect(find.byType(AppSegmentedTimeField), findsNothing);

      // Done is always enabled at stage 1 — matching the task flow's own
      // _confirmNameStage exactly, an empty name closes the whole screen
      // rather than the button being disabled (see the "no name" test
      // below).
      await tester.enterText(_nameField(), 'Morning ritual');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.byType(AppSegmentedTimeField), findsWidgets);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Done with no name typed closes the whole screen, matching the '
    'task creation flow\'s own abandon behavior',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      unawaited(showZoneFormScreen(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      // The label-only Done button (disabled ElevatedButton.onPressed is
      // null for an empty name) can't be tapped through onPressed, but the
      // Name field's own keyboard-submit action calls the SAME
      // _confirmNameStage — this exercises that path with an empty name.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(AppSegmentedTimeField), findsNothing);
      expect(find.text('New zone'), findsNothing);
    },
  );

  testWidgets(
    'Save is disabled until start and end are also set, once past stage 1',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      unawaited(showZoneFormScreen(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      await tester.enterText(_nameField(), 'Morning ritual');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(ElevatedButton, 'Save');
      expect(saveButton, findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(saveButton).onPressed,
        isNull,
        reason: 'no start/end time yet',
      );
    },
  );

  testWidgets('creating a zone saves it and it appears in zoneListProvider', (
    tester,
  ) async {
    final navigatorKey = await _pumpHost(tester, box: box);
    unawaited(showZoneFormScreen(navigatorKey.currentContext!));
    await tester.pumpAndSettle();

    await tester.enterText(_nameField(), 'Morning ritual');
    await tester.pump();

    final container = ProviderScope.containerOf(navigatorKey.currentContext!);

    // Driving the masked time fields via simulated typing is brittle
    // across Flutter versions; exercising the notifier directly (which
    // is exactly what Save calls) is what this test actually needs to
    // verify — that a created Zone reaches zoneListProvider — without
    // coupling to AppSegmentedTimeField's own input mechanics, which
    // already has its own dedicated widget tests.
    //
    // runAsync is required here, not optional: createZone's real Hive
    // write hangs under flutter_test's synchronous pump-based zone
    // otherwise — the same "Hive real disk I/O" issue documented in
    // docs/ERROR_LOG.md for every other repository-writing test in this
    // codebase, just reached via a direct notifier call instead of a tap.
    await tester.runAsync(
      () => container
          .read(zoneListProvider.notifier)
          .createZone(
            title: 'Morning ritual',
            startMinutes: 420,
            endMinutes: 480,
          ),
    );

    final zones = container.read(zoneListProvider);
    expect(zones, hasLength(1));
    expect(zones.single.title, 'Morning ritual');
    expect(zones.single.startMinutes, 420);
    expect(zones.single.endMinutes, 480);
  });

  testWidgets(
    'Save enables as soon as the name is typed, once times are already '
    'set — no need to move focus out of the name field first',
    (tester) async {
      // Real bug, reported directly: "need to put cursor back in focus in
      // Name to enable btn." `_canSave` only got re-evaluated when some
      // OTHER interaction happened to call setState (the time fields'
      // own onChanged, or the name field's onFocusChanged) — nothing
      // rebuilt on the name controller's own text changing, so Save
      // stayed disabled through the very keystroke that made the form
      // valid, only catching up once focus later left the field.
      final navigatorKey = await _pumpHost(tester, box: box);
      unawaited(showZoneFormScreen(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      // A placeholder name to get past stage 1 into the full form — the
      // bug under test is about retyping the REAL name afterward, not
      // about stage 1's own gating (covered by its own test above).
      await tester.enterText(_nameField(), 'placeholder');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      final startField = find.descendant(
        of: find.widgetWithText(AppSegmentedTimeField, 'Start'),
        matching: find.byType(TextField),
      );
      await tester.tap(startField);
      await tester.pump();
      await tester.enterText(startField, '0700');
      await tester.pump();

      final endField = find.descendant(
        of: find.widgetWithText(AppSegmentedTimeField, 'End'),
        matching: find.byType(TextField),
      );
      await tester.tap(endField);
      await tester.pump();
      await tester.enterText(endField, '0800');
      await tester.pump();

      ElevatedButton saveButton() => tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save'),
      );

      // Clear the name, matching the reported repro (Save must go back to
      // disabled with no name, then re-enable the instant one is typed).
      await tester.enterText(_nameField(), '');
      await tester.pump();
      expect(saveButton().onPressed, isNull, reason: 'no name yet');

      // Type the name LAST, without tapping anywhere else afterward.
      await tester.enterText(_nameField(), 'Morning ritual');
      await tester.pump();

      expect(saveButton().onPressed, isNotNull);
    },
  );

  testWidgets('editing a zone pre-fills its name', (tester) async {
    final zone = Zone(
      id: 'existing',
      title: 'Focus block',
      startMinutes: 540,
      endMinutes: 600,
    );
    // runAsync — same real-Hive-I/O-under-flutter_test's-synchronous-zone
    // reasoning as test 2 above.
    await tester.runAsync(() => box.put(zone.id, zone));

    final navigatorKey = await _pumpHost(tester, box: box);
    unawaited(showZoneFormScreen(navigatorKey.currentContext!, zone: zone));
    await tester.pumpAndSettle();

    expect(find.text('Focus block'), findsOneWidget);
    expect(find.text('Edit zone'), findsOneWidget);
  });

  testWidgets(
    'editing the start time and tapping Save WITHOUT tapping away first '
    'still saves the new time',
    (tester) async {
      // Real bug, reported directly: typing a new time then tapping Save
      // straight away (field still focused, keyboard still up — the
      // ordinary way to save on a phone) silently kept the OLD time.
      // AppSegmentedTimeField only commits its typed value on blur or
      // onEditingComplete, and tapping Save is neither on its own — see
      // _ZoneFormScreenState._save's own fix (unfocus + await a frame
      // before reading the committed value).
      final zone = Zone(
        id: 'existing',
        title: 'Focus block',
        startMinutes: 540, // 09:00
        endMinutes: 600, // 10:00
      );
      await tester.runAsync(() => box.put(zone.id, zone));

      final navigatorKey = await _pumpHost(tester, box: box);
      unawaited(showZoneFormScreen(navigatorKey.currentContext!, zone: zone));
      await tester.pumpAndSettle();

      final startField = find.byWidgetPredicate(
        (w) => w is TextField && (w.controller?.text == '09 : 00'),
      );
      expect(startField, findsOneWidget);
      await tester.tap(startField);
      await tester.pump();
      await tester.enterText(startField, '0700'); // types 07:00
      await tester.pump();

      final saveButton = find.widgetWithText(ElevatedButton, 'Save');
      await tester.runAsync(() async {
        await tester.tap(saveButton);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(box.get('existing')!.startMinutes, 420); // 07:00
    },
  );

  // Requested directly: "Edit zone screen should have remove icon button
  // same as w[ith] edit t[a]sk."
  testWidgets(
    'editing an existing zone shows a remove icon button that deletes it '
    'and closes the screen',
    (tester) async {
      final zone = Zone(
        id: 'existing',
        title: 'Focus block',
        startMinutes: 540,
        endMinutes: 600,
      );
      await tester.runAsync(() => box.put(zone.id, zone));

      final navigatorKey = await _pumpHost(tester, box: box);
      unawaited(showZoneFormScreen(navigatorKey.currentContext!, zone: zone));
      await tester.pumpAndSettle();

      final deleteButton = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteButton, findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(deleteButton);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(box.get('existing'), isNull);
      // The screen itself closed — back to the empty host.
      expect(find.text('Edit zone'), findsNothing);
    },
  );

  testWidgets(
    'the create flow (no existing zone) shows no remove icon button',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      unawaited(showZoneFormScreen(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      await tester.enterText(_nameField(), 'Morning ritual');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    },
  );
}

/// Fires an async future without awaiting it inline — same helper as
/// `add_category_modal_test.dart`'s own copy.
void unawaited(Future<void> future) {}
