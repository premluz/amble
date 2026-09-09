import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_top_scroll_fade.dart';
import 'package:amble/features/tracked_behavior/tracked_behavior_list_screen.dart';
import 'package:amble/features/tracked_behavior/tracked_behavior_row.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/behavior_target_type.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Box<TrackedBehavior> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_tracked_list');
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

  // Seeding writes to a real Hive box, so it runs inside runAsync — see
  // docs/ERROR_LOG.md: Hive's disk I/O completes on the real event loop,
  // which flutter_test's synchronous pump-based zone can starve
  // indefinitely.
  Future<void> pumpList(
    WidgetTester tester, {
    List<TrackedBehavior> behaviors = const [],
  }) async {
    await tester.runAsync(() async {
      for (final behavior in behaviors) {
        await box.put(behavior.id, behavior);
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(box),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: TrackedBehaviorListScreen()),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      await tester.pumpAndSettle();
    });
  }

  // Requested directly: "cant see that 'shade' top on headers (inbox,
  // tracked..)." then "use same at the bottom" for a mirrored one.
  testWidgets(
    'shows a top scroll-fade above the list AND a mirrored bottom one',
    (tester) async {
      await pumpList(
        tester,
        behaviors: [
          TrackedBehavior.create(
            title: 'Exercise',
            targetType: BehaviorTargetType.count,
            targetAmount: 3,
            timesPerWeek: 3,
          ),
        ],
      );

      expect(find.byType(AppTopScrollFade), findsNWidgets(2));
      final fades = find
          .byType(AppTopScrollFade)
          .evaluate()
          .map((e) => e.widget as AppTopScrollFade)
          .toList();
      expect(fades.where((f) => f.fromBottom).length, 1);
      expect(fades.where((f) => !f.fromBottom).length, 1);
    },
  );

  // Requested directly: "Tracked should also be the same as the
  // timeline."
  testWidgets("the screen's background and BOTH fades' own colour match the "
      'Timeline surface, not the general card surface', (tester) async {
    await pumpList(tester);

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.color, AmbleTheme.light.colorSurfaceTimeline);

    for (final element in find.byType(AppTopScrollFade).evaluate()) {
      expect(
        (element.widget as AppTopScrollFade).color,
        AmbleTheme.light.colorSurfaceTimeline,
      );
    }
  });

  // Reversed back (2026-09-09), requested directly: "the header cuts the
  // content with a hard edge... the content slides through underneath."
  // A fade confined to the fixed heading (the shape this test used to
  // assert) can only ever blend against that heading's own flat
  // background — never the list actually scrolling underneath it. The
  // fade now overlays the scrolling content directly, matching the
  // Timeline's own fade and the Inbox screen's identical fix.
  testWidgets(
    'the top scroll-fade overlays the scrolling list directly, and the '
    '"Tracked" title never visually overlaps it',
    (tester) async {
      await pumpList(
        tester,
        behaviors: [
          TrackedBehavior.create(
            title: 'Exercise',
            targetType: BehaviorTargetType.count,
            targetAmount: 3,
            timesPerWeek: 3,
          ),
        ],
      );

      final topFade = find.byWidgetPredicate(
        (w) => w is AppTopScrollFade && !w.fromBottom,
      );

      // The fade shares a Stack with the actual scrolling content (the
      // behavior list), so it visually overlays it.
      final sharedStack = find.ancestor(
        of: topFade,
        matching: find.byType(Stack),
      );
      expect(
        find.descendant(
          of: sharedStack.first,
          matching: find.byType(TrackedBehaviorRow),
        ),
        findsWidgets,
        reason:
            'the top fade must share a Stack with the actual scrolling '
            'content, so it visually overlays it rather than only ever '
            "blending against its own separate header's flat background",
      );

      // The title and the fade occupy separate, non-overlapping regions
      // — the title in the fixed heading above, the fade over the
      // scrolling content below it.
      final titleRect = tester.getRect(find.text('Tracked'));
      final fadeRect = tester.getRect(topFade);
      expect(titleRect.overlaps(fadeRect), isFalse);
    },
  );

  testWidgets('shows an empty state when nothing is tracked', (tester) async {
    await pumpList(tester);

    expect(find.byType(TrackedBehaviorRow), findsNothing);
    expect(find.textContaining('Nothing tracked yet'), findsOneWidget);
  });

  testWidgets('renders one row per behavior, with its title', (tester) async {
    await pumpList(
      tester,
      behaviors: [
        TrackedBehavior.create(
          title: 'Exercise',
          targetType: BehaviorTargetType.duration,
          targetAmount: 60,
          timesPerWeek: 3,
        ),
        TrackedBehavior.create(
          title: 'Read',
          targetType: BehaviorTargetType.count,
          targetAmount: 20,
          timesPerWeek: 5,
        ),
      ],
    );

    expect(find.byType(TrackedBehaviorRow), findsNWidgets(2));
    expect(find.text('Exercise'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('a row shows the target amount, unit, and frequency', (
    tester,
  ) async {
    await pumpList(
      tester,
      behaviors: [
        TrackedBehavior.create(
          title: 'Exercise',
          targetType: BehaviorTargetType.duration,
          targetAmount: 60,
          timesPerWeek: 3,
        ),
      ],
    );

    expect(find.text('60 min · 3x a week'), findsOneWidget);
  });

  group('describeBehaviorTarget', () {
    test('renders an integer amount without a trailing ".0"', () {
      final behavior = TrackedBehavior.create(
        title: 'Exercise',
        targetType: BehaviorTargetType.duration,
        targetAmount: 60,
        timesPerWeek: 3,
      );

      expect(describeBehaviorTarget(behavior), '60 min · 3x a week');
    });

    test('includes the minimum when one is set', () {
      final behavior = TrackedBehavior.create(
        title: 'Exercise',
        targetType: BehaviorTargetType.duration,
        targetAmount: 60,
        minimumAmount: 15,
        timesPerWeek: 3,
      );

      expect(describeBehaviorTarget(behavior), '60 min (min 15) · 3x a week');
    });

    test('a binary behavior reads as "Did it", with no amount', () {
      final behavior = TrackedBehavior.create(
        title: 'Meditate',
        targetType: BehaviorTargetType.binary,
        timesPerWeek: 7,
      );

      expect(describeBehaviorTarget(behavior), 'Did it · 7x a week');
    });

    test('uses the count unit for a count target', () {
      final behavior = TrackedBehavior.create(
        title: 'Read',
        targetType: BehaviorTargetType.count,
        targetAmount: 20,
        timesPerWeek: 5,
      );

      expect(describeBehaviorTarget(behavior), '20 reps · 5x a week');
    });
  });
}
