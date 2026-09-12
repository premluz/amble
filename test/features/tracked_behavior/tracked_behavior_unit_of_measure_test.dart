import 'dart:async';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/features/tracked_behavior/tracked_behavior_form.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/behavior_target_type.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

/// Requested directly: "we add new option Unit of measure: Time, Distance,
/// Reps, Count[, Custom]." Custom opens a small sheet with a Label field
/// and a Unit field (hint text showing example units) — see
/// `custom_unit_sheet.dart`.
Finder _nameField() => find.descendant(
  of: find.widgetWithText(AppTextField, 'What are you tracking?'),
  matching: find.byType(TextField),
);

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester, {
  required Box<TrackedBehavior> box,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        trackedBehaviorRepositoryProvider.overrideWithValue(
          HiveTrackedBehaviorRepository(box),
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

Future<void> _openStage2(
  WidgetTester tester,
  GlobalKey<NavigatorState> nav,
) async {
  unawaited(showTrackedBehaviorForm(nav.currentContext!));
  await tester.pumpAndSettle();
  await tester.enterText(_nameField(), 'Water');
  await tester.pump();
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

void main() {
  late Box<TrackedBehavior> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_tracked_behavior_unit_of_measure');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<TrackedBehavior>(
      'test_behaviors_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.close();
  });

  testWidgets(
    'Measured in shows Time, Distance, Reps, Count, Custom, Did it — in '
    'that order',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      await _openStage2(tester, navigatorKey);

      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Reps'), findsOneWidget);
      expect(find.text('Count'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Did it'), findsOneWidget);

      final row = tester.getTopLeft(find.text('Time')).dx;
      final distance = tester.getTopLeft(find.text('Distance')).dx;
      final reps = tester.getTopLeft(find.text('Reps')).dx;
      final count = tester.getTopLeft(find.text('Count')).dx;
      expect(row, lessThan(distance));
      expect(distance, lessThan(reps));
      expect(reps, lessThan(count));
    },
  );

  testWidgets('Distance defaults its target unit to km', (tester) async {
    final navigatorKey = await _pumpHost(tester, box: box);
    await _openStage2(tester, navigatorKey);

    await tester.tap(find.text('Distance'));
    await tester.pump();

    expect(find.text('Target (km)'), findsOneWidget);
  });

  testWidgets(
    'tapping Custom opens the small unit sheet with a Label field, a Unit '
    'field with example hint text, and a Save button disabled until both '
    'are filled in',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      await _openStage2(tester, navigatorKey);

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      expect(find.text('Custom unit'), findsOneWidget);
      expect(find.text('Label'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);
      expect(find.text('e.g. times, km, hours, glasses'), findsOneWidget);

      // Scoped to the sheet's own content — the underlying form (still
      // mounted behind the sheet) has its own AppButton/TextField too.
      final sheetContent = find
          .ancestor(of: find.text('Custom unit'), matching: find.byType(Column))
          .first;
      Finder sheetSaveButton() =>
          find.descendant(of: sheetContent, matching: find.byType(AppButton));

      // Nothing filled in yet — Save is disabled.
      var saveButton = tester.widget<AppButton>(sheetSaveButton());
      expect(saveButton.onPressed, isNull);

      final labelField = find.descendant(
        of: find.widgetWithText(AppTextField, 'Label'),
        matching: find.byType(TextField),
      );
      await tester.enterText(labelField, 'Water');
      await tester.pump();

      // Label alone still isn't enough — Unit is also required.
      saveButton = tester.widget<AppButton>(sheetSaveButton());
      expect(saveButton.onPressed, isNull);

      final unitField = find
          .descendant(of: sheetContent, matching: find.byType(TextField))
          .last;
      await tester.enterText(unitField, 'glasses');
      await tester.pump();

      saveButton = tester.widget<AppButton>(sheetSaveButton());
      expect(saveButton.onPressed, isNotNull);
    },
  );

  testWidgets('completing the custom unit sheet with Label "Water" and Unit '
      '"glasses" saves a custom behavior with both fields set', (tester) async {
    final navigatorKey = await _pumpHost(tester, box: box);
    await _openStage2(tester, navigatorKey);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    final labelField = find.descendant(
      of: find.widgetWithText(AppTextField, 'Label'),
      matching: find.byType(TextField),
    );
    await tester.enterText(labelField, 'Water');
    await tester.pump();

    // The Unit field is a raw TextField, scoped to the sheet's own
    // "Custom unit" title so it isn't confused with the underlying
    // form's Name field (still mounted behind the sheet, both matching
    // a bare find.byType(TextField)).
    final unitField = find
        .descendant(
          of: find
              .ancestor(
                of: find.text('Custom unit'),
                matching: find.byType(Column),
              )
              .first,
          matching: find.byType(TextField),
        )
        .last;
    await tester.enterText(unitField, 'glasses');
    await tester.pump();

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    // Back on the tracked-behavior form — fill in the target and save.
    // "Water" is now the chip's own label (the custom unit's Label),
    // confirming the sheet's result actually applied.
    expect(find.text('Water'), findsWidgets);
    expect(find.text('Target (glasses)'), findsOneWidget);
    final targetField = find.descendant(
      of: find
          .ancestor(
            of: find.text('Target (glasses)'),
            matching: find.byType(Column),
          )
          .first,
      matching: find.byType(TextField),
    );
    await tester.enterText(targetField, '8');
    await tester.pump();

    // Saving does real repository I/O (`TrackedBehaviorList.
    // createBehavior` awaits `saveBehavior`) — must run inside
    // `runAsync`, same requirement every other real-Hive-write test in
    // this codebase observes (see docs/ERROR_LOG.md), or
    // `pumpAndSettle` hangs indefinitely waiting on a Future the fake
    // async zone can never resolve.
    await tester.runAsync(() async {
      await tester.tap(find.text('Save').last);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final saved = box.values.single;
    expect(saved.targetType, BehaviorTargetType.custom);
    expect(saved.customUnitLabel, 'Water');
    expect(saved.customUnitName, 'glasses');
    expect(saved.targetAmount, 8);
  });

  testWidgets(
    'editing an existing custom behavior re-opens the sheet pre-filled '
    'with its saved label/unit',
    (tester) async {
      final behavior = TrackedBehavior.create(
        title: 'Water',
        targetType: BehaviorTargetType.custom,
        targetAmount: 8,
        timesPerWeek: 7,
        customUnitLabel: 'Water',
        customUnitName: 'glasses',
      );
      await tester.runAsync(() async {
        await box.put(behavior.id, behavior);
      });

      final navigatorKey = await _pumpHost(tester, box: box);
      showTrackedBehaviorForm(navigatorKey.currentContext!, behavior: behavior);
      await tester.pumpAndSettle();

      // The chip's own label reflects the saved custom unit's Label —
      // "Water", not the generic "Custom".
      expect(find.text('Water'), findsWidgets);
      expect(find.text('Target (glasses)'), findsOneWidget);

      await tester.tap(find.text('Water').last);
      await tester.pumpAndSettle();

      expect(find.text('Custom unit'), findsOneWidget);
      final labelField = find.descendant(
        of: find.widgetWithText(AppTextField, 'Label'),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(labelField).controller?.text, 'Water');
      final unitField = find
          .descendant(
            of: find
                .ancestor(
                  of: find.text('Custom unit'),
                  matching: find.byType(Column),
                )
                .first,
            matching: find.byType(TextField),
          )
          .last;
      expect(tester.widget<TextField>(unitField).controller?.text, 'glasses');
    },
  );
}
