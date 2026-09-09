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
    // Rendered without a trailing ".0" — the model stores `num`, but a
    // 60-minute target must read back as the "60" the user typed.
    expect(find.text('60'), findsOneWidget);
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
