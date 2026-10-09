import 'package:amble/core/widgets/app_depth.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/features/timeline/selected_date_provider.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/features/timeline/viewed_time_provider.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/timeline_harness.dart';

final _day = DateTime(2026, 10, 3);

Task _task(String title, DateTime day, int hour) => Task.create(
  title: title,
  scheduledAt: day.add(Duration(hours: hour)),
  durationMinutes: 30,
  categoryId: BuiltInCategoryIds.work,
);

ScrollController _dayScrollController(WidgetTester tester) {
  final scrollView = find.descendant(
    of: find.byKey(const ValueKey('positioned-day-content')),
    matching: find.byType(SingleChildScrollView),
  );
  return tester.widget<SingleChildScrollView>(scrollView).controller!;
}

Finder _pill(Task task) => find.byWidgetPredicate(
  (widget) => widget is TaskCapsuleBlock && widget.task.id == task.id,
);

double _centerOffset(int minutes, double pixelsPerMinute, ScrollPosition p) =>
    (minutes * pixelsPerMinute +
            TimelineScrollTokens.topClearance -
            p.viewportDimension / 2)
        .clamp(0.0, p.maxScrollExtent);

void main() {
  late TimelineHarness harness;

  setUp(() async {
    harness = await TimelineHarness.open(
      'test_hive_day_navigation',
      now: _day.add(const Duration(hours: 12)),
    );
  });
  tearDown(() => harness.close());

  testWidgets('switching days keeps the viewed hour and shows the new tasks '
      'already in their final positions', (tester) async {
    final nextDay = _day.add(const Duration(days: 1));
    final nextTask = _task('Next day task', nextDay, 16);
    await harness.pump(tester, [_task('Current day task', _day, 16), nextTask]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimelineScreen)),
    );
    _dayScrollController(tester).jumpTo(1100);
    await tester.pump();
    final viewedHour = container.read(viewedTimeProvider);
    expect(viewedHour, isNotNull);

    container.read(selectedDateProvider.notifier).goToNextDay();
    await tester.pump();
    await tester.pump();

    expect(container.read(viewedTimeProvider), viewedHour);
    final nextController = _dayScrollController(tester);
    final position = nextController.position;
    final expectedOffset = _centerOffset(
      viewedHour!,
      container.read(timelinePixelsPerMinuteSettingProvider),
      position,
    );
    expect(position.pixels, closeTo(expectedOffset, 2));
    final pill = _pill(nextTask);
    expect(pill, findsOneWidget);
    final presence = tester.widget<AppDepthPresence>(
      find.ancestor(of: pill, matching: find.byType(AppDepthPresence)).first,
    );
    expect(presence.animateIn, isFalse);
    final initialTop = tester.getTopLeft(pill).dy;
    final initialOffset = nextController.position.pixels;
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(pill).dy, closeTo(initialTop, 0.1));
    expect(nextController.position.pixels, closeTo(initialOffset, 0.1));
  });
}
