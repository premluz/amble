import 'package:amble/core/tokens/semantic_theme.dart';
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

/// Covers the edit path added when TrackedBehavior gained its own nav tab —
/// `showTrackedBehaviorForm` was create-only before that.
void main() {
  late Box<TrackedBehavior> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_tracked_form_edit');
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

  Future<GlobalKey<NavigatorState>> pumpHost(WidgetTester tester) async {
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

  testWidgets('opening the form for an existing behavior prefills its '
      'title and reads "Edit behavior", not "Track a behavior"', (
    tester,
  ) async {
    final behavior = TrackedBehavior.create(
      title: 'Exercise',
      targetType: BehaviorTargetType.duration,
      targetAmount: 60,
      timesPerWeek: 3,
    );
    await tester.runAsync(() async {
      await box.put(behavior.id, behavior);
    });

    final navigatorKey = await pumpHost(tester);
    showTrackedBehaviorForm(navigatorKey.currentContext!, behavior: behavior);
    await tester.pumpAndSettle();

    expect(find.text('Edit behavior'), findsOneWidget);
    expect(find.text('Track a behavior'), findsNothing);
    expect(find.text('Exercise'), findsOneWidget);
    // The saved 60-minute target does NOT read back into the form: the
    // Target field was removed directly ("hide target and times per week
    // and its dependency to be filled in order to save"). The value is
    // still on the model, and an edit preserves it rather than clearing
    // it — it just has nowhere to render.
    expect(find.text('60'), findsNothing);
  });

  // The real data risk in hiding Target/Times per week: an edit must not
  // silently wipe values the form no longer shows and the user therefore
  // has no way to re-enter.
  testWidgets('editing and saving preserves the target amount, minimum and '
      'weekly frequency the behavior was already saved with', (tester) async {
    final behavior = TrackedBehavior.create(
      title: 'Exercise',
      targetType: BehaviorTargetType.duration,
      targetAmount: 60,
      minimumAmount: 15,
      timesPerWeek: 3,
    );
    await tester.runAsync(() async {
      await box.put(behavior.id, behavior);
    });

    final navigatorKey = await pumpHost(tester);
    showTrackedBehaviorForm(navigatorKey.currentContext!, behavior: behavior);
    await tester.pumpAndSettle();

    // Change only the one field the form still offers.
    await tester.enterText(find.byType(TextField).first, 'Exercise daily');
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('Save').last);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final saved = box.get(behavior.id)!;
    expect(saved.title, 'Exercise daily');
    expect(saved.targetAmount, 60);
    expect(saved.minimumAmount, 15);
    expect(saved.timesPerWeek, 3);
  });

  testWidgets('opening the form with no behavior reads "Track a behavior" '
      'and starts blank', (tester) async {
    final navigatorKey = await pumpHost(tester);
    showTrackedBehaviorForm(navigatorKey.currentContext!);
    await tester.pumpAndSettle();

    expect(find.text('Track a behavior'), findsOneWidget);
    expect(find.text('Edit behavior'), findsNothing);
  });
}
