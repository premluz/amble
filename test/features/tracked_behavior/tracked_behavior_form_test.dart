import 'dart:async';

import 'package:amble/core/tokens/semantic_theme.dart';
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

/// Covers the near-full-screen, Name-first-then-reveal interaction model
/// requested directly: "add template and add tracked should follow same
/// modal UI and interaction model as add task and add zone. Near full
/// screen and disclosure first name and them reveal rest." Mirrors
/// `zone_form_screen_test.dart`'s/`task_template_form_test.dart`'s own
/// equivalent tests. The edit-skips-stage-1 path is already covered by
/// `tracked_behavior_form_edit_test.dart`, so this file focuses on the
/// create/stage-1-specific reveal behavior not covered there.
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

  testWidgets(
    'a fresh create opens on the Name-only stage 1 — Measured in/Target/'
    'Times per week are not in the tree yet, then reveal once Done is '
    'tapped',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      unawaited(showTrackedBehaviorForm(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      expect(find.text('Track a behavior'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Measured in'), findsNothing);
      expect(find.text('Times per week'), findsNothing);

      await tester.enterText(_nameField(), 'Exercise');
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Measured in'), findsOneWidget);
      expect(find.text('Times per week'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Done with no name typed closes the whole screen, matching the '
    'task/zone creation flow\'s own abandon behavior',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      unawaited(showTrackedBehaviorForm(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Track a behavior'), findsNothing);
      expect(find.text('Measured in'), findsNothing);
    },
  );

  testWidgets(
    'editing an existing behavior skips straight to stage 2 — Measured in/'
    'Times per week are already visible',
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

      expect(find.text('Edit behavior'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Measured in'), findsOneWidget);
      expect(find.text('Times per week'), findsOneWidget);
    },
  );
}
