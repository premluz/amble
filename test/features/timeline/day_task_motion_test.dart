import 'package:amble/core/widgets/app_depth.dart';
import 'package:amble/features/timeline/day_task_motion.dart';
import 'package:amble/features/timeline/selected_date_provider.dart';
import 'package:amble/features/timeline/tasks_for_selected_day_provider.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 9, 29);

Task _task(String id, int hour) => Task(
  id: id,
  title: id,
  categoryId: BuiltInCategoryIds.general,
  createdAt: _day,
  scheduledAt: _day.add(Duration(hours: hour)),
);

/// The day's task list, as the test drives it.
final _dayTasks = NotifierProvider<_DayTasks, List<Task>>(_DayTasks.new);

class _DayTasks extends Notifier<List<Task>> {
  @override
  List<Task> build() => [_task('a', 9)];

  void set(List<Task> tasks) => state = tasks;
}

/// Tasks on the next day, which the day's list switches to (in the same
/// update, as the real provider does) when the date moves.
final _nextDayTasks = [_task('y', 10)];

ProviderContainer _container() => ProviderContainer(
  overrides: [
    tasksForSelectedDayProvider.overrideWith(
      (ref) => ref.watch(selectedDateProvider).day == _day.day
          ? ref.watch(_dayTasks)
          : _nextDayTasks,
    ),
    selectedDateProvider.overrideWith(_FixedDay.new),
  ],
);

class _FixedDay extends SelectedDate {
  @override
  DateTime build() => _day;
}

/// Disposes [container] and lets anything it scheduled run, inside the test.
Future<void> _done(WidgetTester tester, ProviderContainer container) async {
  container.dispose();
  await tester.pump();
}

void main() {
  testWidgets('the tasks already on the day are simply there', (tester) async {
    final container = _container();
    final motion = container.read(dayTaskMotionProvider);
    expect(motion.arriving, isEmpty);
    expect(motion.leaving, isEmpty);
    await _done(tester, container);
  });

  testWidgets('a task that arrives emerges once: marked arriving for its '
      'first frame only, so a later remount (a view switch) shows it at '
      'rest', (tester) async {
    final container = _container();
    container.read(dayTaskMotionProvider);
    container.read(_dayTasks.notifier).set([_task('a', 9), _task('b', 11)]);
    expect(container.read(dayTaskMotionProvider).arriving, {'b'});
    await tester.pump();
    expect(container.read(dayTaskMotionProvider).arriving, isEmpty);
    await _done(tester, container);
  });

  testWidgets('a task that leaves is kept (as it was) until it has receded, '
      'and is still drawn in time order meanwhile', (tester) async {
    final container = _container();
    container.read(dayTaskMotionProvider);
    container.read(_dayTasks.notifier).set([_task('a', 9), _task('b', 11)]);
    container.read(_dayTasks.notifier).set([_task('b', 11)]);
    final motion = container.read(dayTaskMotionProvider);
    expect(motion.leaving.keys, ['a']);
    expect(
      DayTaskMotion.shown(container.read(_dayTasks), motion).map((t) => t.id),
      ['a', 'b'],
    );
    container.read(dayTaskMotionProvider.notifier).settle('a');
    expect(container.read(dayTaskMotionProvider).leaving, isEmpty);
    await _done(tester, container);
  });

  testWidgets('changing the day never animates anything', (tester) async {
    final container = _container();
    container.read(dayTaskMotionProvider);
    container.read(_dayTasks.notifier).set([_task('x', 8)]);
    await tester.pump();
    container.read(selectedDateProvider.notifier).goToNextDay();
    final motion = container.read(dayTaskMotionProvider);
    expect(motion.arriving, isEmpty);
    expect(motion.leaving, isEmpty);
    expect(container.read(tasksForSelectedDayProvider), _nextDayTasks);
    await _done(tester, container);
  });

  group('DayTaskPresence', () {
    Widget host(DayTaskMotionState? motion, {ValueChanged<String>? settled}) {
      const presence = DayTaskPresence(
        taskId: 'a',
        opensSpace: false,
        child: AppDepthShape(child: SizedBox(key: ValueKey('pill'))),
      );
      return Directionality(
        textDirection: TextDirection.ltr,
        child: motion == null
            ? presence
            : DayTaskMotionScope(
                motion: motion,
                onSettled: settled ?? (_) {},
                child: presence,
              ),
      );
    }

    testWidgets('outside the Day screen it is inert', (tester) async {
      await tester.pumpWidget(host(null));
      expect(find.byType(AppDepthPresence), findsNothing);
    });

    testWidgets('arriving: the pill emerges from depth', (tester) async {
      await tester.pumpWidget(host(const DayTaskMotionState(arriving: {'a'})));
      final opacity = tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(const ValueKey('pill')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(opacity, lessThan(1));
      await tester.pumpAndSettle();
    });

    testWidgets('leaving: untouchable, recedes, then lets the day forget it', (
      tester,
    ) async {
      final settled = <String>[];
      await tester.pumpWidget(
        host(const DayTaskMotionState(), settled: settled.add),
      );
      await tester.pumpWidget(
        host(
          DayTaskMotionState(leaving: {'a': _task('a', 9)}),
          settled: settled.add,
        ),
      );
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('pill')),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring,
        isTrue,
      );
      expect(settled, isEmpty, reason: 'not before it has receded');
      await tester.pumpAndSettle();
      expect(settled, ['a']);
    });
  });
}
