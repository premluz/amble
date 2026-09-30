import 'dart:async';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/core/widgets/app_value_chip.dart';
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

/// Covers the compact create flow and its shared quick-task-sheet controls.
/// The edit path is also covered by `tracked_behavior_form_edit_test.dart`;
/// this file keeps the create/default-name assertions separate from it.
Finder _nameField() => find.descendant(
  of: find.widgetWithText(AppTextField, 'Add title'),
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

void main() {
  late Box<TrackedBehavior> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_tracked_behavior_form');
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

  testWidgets('a fresh create opens as a compact Create pattern sheet with the '
      'default name and a compact measured-in value chip', (tester) async {
    final navigatorKey = await _pumpHost(tester, box: box);
    unawaited(showTrackedBehaviorForm(navigatorKey.currentContext!));
    await tester.pumpAndSettle();

    expect(find.text('Create pattern'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Measured in'), findsNothing);
    expect(find.text('Time'), findsOneWidget);

    final measuredIn = tester.widget<AppValueChip>(find.byType(AppValueChip));
    expect(measuredIn.label, 'Time');
    expect(measuredIn.size, AppValueChipSize.sm);
    expect(measuredIn.hasValue, isTrue);
    expect(find.text('Times per week'), findsNothing);
    expect(find.text('Target'), findsNothing);
  });

  testWidgets('the default name can be replaced before adding', (tester) async {
    final navigatorKey = await _pumpHost(tester, box: box);
    unawaited(showTrackedBehaviorForm(navigatorKey.currentContext!));
    await tester.pumpAndSettle();

    await tester.enterText(_nameField(), 'Exercise');
    await tester.pump();

    expect(find.text('Exercise'), findsOneWidget);
    expect(find.text('Create pattern'), findsNothing);
  });

  testWidgets(
    'editing an existing behavior uses the compact Edit pattern sheet and '
    'keeps Target/Times per week hidden',
    (tester) async {
      final behavior = TrackedBehavior.create(
        title: 'Exercise',
        targetType: BehaviorTargetType.duration,
        targetAmount: 60,
        timesPerWeek: 3,
      );
      await tester.runAsync(() async {
        await box.put(behavior.id, behavior);
      });

      final navigatorKey = await _pumpHost(tester, box: box);
      showTrackedBehaviorForm(navigatorKey.currentContext!, behavior: behavior);
      await tester.pumpAndSettle();

      expect(find.text('Edit pattern'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(AppValueChip), findsOneWidget);
      expect(find.text('Times per week'), findsNothing);
      expect(find.text('Target'), findsNothing);
      // This behavior was saved WITH a 60-minute target and a 3x
      // frequency; neither leaks back into the form.
      expect(find.textContaining('60'), findsNothing);
    },
  );
}
