import 'dart:async';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_sheet_flow.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/core/widgets/app_value_chip.dart';
import 'package:amble/features/task_detail/task_behavior_modal.dart';
import 'package:amble/features/tracked_behavior/tracked_behavior_form.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

/// The habit form and its unit pickers are pages of ONE sheet — from the
/// task's Tracked picker, and inside the form itself (DESIGN_SYSTEM.md
/// "Sheets", rule 1: never a sheet on a sheet).
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

Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppTextField && w.label == label),
  matching: find.byType(TextField),
);

void main() {
  late Box<TrackedBehavior> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_tracked_behavior_page_flow');
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

  testWidgets('the Tracked picker\'s + opens the habit form as a page of the '
      'same sheet, and saving selects the new habit', (tester) async {
    final nav = await _pumpHost(tester, box: box);
    TaskBehaviorSelection? picked;
    unawaited(
      TaskBehaviorModal.show(
        context: nav.currentContext!,
        behaviorId: null,
      ).then((selection) => picked = selection),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add tracked behavior'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheetFlow), findsOneWidget);
    expect(find.byType(TrackedBehaviorPage), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    await tester.enterText(_field('Add title'), 'Water');
    await tester.runAsync(() async {
      await tester.tap(find.text('Add'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });
    await tester.pumpAndSettle();

    final water = box.values.singleWhere((b) => b.title == 'Water');
    expect(picked?.behaviorId, water.id);
    expect(find.byType(TaskBehaviorModal), findsNothing);
  });

  testWidgets('"Measured in" is the next page, and a choice returns to the '
      'form', (tester) async {
    final nav = await _pumpHost(tester, box: box);
    unawaited(showTrackedBehaviorForm(nav.currentContext!));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppValueChip));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheetFlow), findsOneWidget);
    expect(find.text('Measured in'), findsOneWidget);

    await tester.tap(find.text('Reps'));
    await tester.pumpAndSettle();
    expect(find.text('Measured in'), findsNothing);
    expect(
      tester.widget<AppValueChip>(find.byType(AppValueChip)).label,
      'Reps',
    );
  });

  testWidgets('a custom unit, two pages deep, returns straight to the form', (
    tester,
  ) async {
    final nav = await _pumpHost(tester, box: box);
    unawaited(showTrackedBehaviorForm(nav.currentContext!));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppValueChip));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add custom unit'));
    await tester.pumpAndSettle();
    expect(find.text('Custom unit'), findsOneWidget);

    await tester.enterText(_field('Label'), 'Water');
    await tester.enterText(
      _field('Unit (e.g. times, km, hours, glasses)'),
      'glasses',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Save custom unit'));
    await tester.pumpAndSettle();

    expect(find.text('Custom unit'), findsNothing);
    expect(find.text('Measured in'), findsNothing);
    expect(
      tester.widget<AppValueChip>(find.byType(AppValueChip)).label,
      'Water',
    );
  });
}
